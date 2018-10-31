#' Install packages for a project
#'
#' @param deployment Use deployment mode
#' @export
#' @examples \dontrun{
#'
#' jetpack::install()
#' }
install <- function(deployment=FALSE) {
  sandbox({
    prepCommand()

    if (deployment) {
      status <- getStatus()
      missing <- status[is.na(status$packrat.version), ]
      if (nrow(missing) > 0) {
        stop(paste("Missing packages:", paste(missing$package, collapse=", ")))
      }
      suppressWarnings(packrat::restore(prompt=FALSE))
      showStatus(status)
    } else {
      installHelper(show_status=TRUE)
    }

    success("Pack complete!")
  })
}

initRprofile <- function() {
  rprofile <- file.exists(".Rprofile")
  if (!rprofile || !any(grepl("jetpack", readLines(".Rprofile")))) {
    str <- "if (requireNamespace(\"jetpack\", quietly=TRUE)) {
  jetpack::load()
} else {
  message(\"Install Jetpack to use a virtual environment for this project\")
}"

    if (rprofile) {
      # space it out
      str <- paste0("\n", str)
    }

    write(str, file=".Rprofile", append=TRUE)
  }
}

venvDir <- function(dir) {
  # similar logic as Pipenv
  if (isWindows()) {
    venv_dir <- "~/.renvs"
  } else {
    venv_dir <- file.path(Sys.getenv("XDG_DATA_HOME", "~/.local/share"), "renvs")
  }

  # TODO better algorithm, but keep dependency free
  dir_hash <- sum(utf8ToInt(dir))
  venv_name <- paste0(basename(dir), "-", dir_hash)
  file.path(venv_dir, venv_name)
}

setupEnv <- function(dir=getwd()) {
  ensureRepos()

  venv_dir <- venvDir(dir)
  if (!file.exists(venv_dir)) {
    dir.create(venv_dir, recursive=TRUE)
  }

  options(packrat.project.dir=venv_dir)

  # initialize packrat
  if (!packified()) {
    message("Creating virtual environment...")

    # don't include jetpack in external.packages
    # since packrat will require it to be installed
    utils::capture.output(suppressMessages(packrat::init(venv_dir, options=list(print.banner.on.startup=FALSE, use.cache=!isWindows()), enter=FALSE, infer.dependencies=FALSE)))
    packrat::set_lockfile_metadata(repos=list(CRAN="https://cloud.r-project.org/"))
  }

  if (!file.exists("packrat.lock")) {
    file.copy(file.path(packrat::project_dir(), "packrat", "packrat.lock"), "packrat.lock")
  }

  venv_dir
}

#' Load Jetpack
#'
#' @export
#' @keywords internal
load <- function() {
  dir <- findDir(getwd())

  if (is.null(dir)) {
    stopNotPackified()
  }

  venv_dir <- setupEnv(dir)

  # must source from virtualenv directory
  # for RStudio for work properly
  # this should probably be fixed in Packrat
  wd <- getwd()
  tryCatch({
    setwd(venv_dir)
    utils::capture.output(suppressMessages(source("packrat/init.R")))
  }, finally={
    setwd(wd)
  })

  invisible()
}

#' Set up Jetpack
#'
#' @export
#' @examples \dontrun{
#'
#' jetpack::init()
#' }
init <- function() {
  sandbox({
    if (!file.exists("DESCRIPTION")) {
      write("Package: app", file="DESCRIPTION")
    }

    initRprofile()

    setupEnv()

    if (!interactive()) {
      success("Run 'jetpack add <package>' to add packages!")
    } else {
      success("Run 'jetpack::add(package)' to add packages!")
      enablePackrat()
      loadNamespace("jetpack", lib.loc=getDefaultLibPaths())
    }
    invisible()
  })
}

#' Add a package
#'
#' @param packages Packages to add
#' @param remotes Remotes to add
#' @export
#' @examples \dontrun{
#'
#' jetpack::add("randomForest")
#'
#' jetpack::add(c("randomForest", "DBI"))
#'
#' jetpack::add("DBI@1.0.0")
#'
#' jetpack::add("plyr", remote="hadley/plyr")
#'
#' jetpack::add("plyr", remote="local::/path/to/plyr")
#' }
add <- function(packages, remotes=c()) {
  sandbox({
    prepCommand()

    desc <- updateDesc(packages, remotes)

    installHelper(desc=desc, show_status=TRUE)

    success("Pack complete!")
  })
}

#' Remove a package
#'
#' @param packages Packages to remove
#' @param remotes Remotes to remove
#' @export
#' @examples \dontrun{
#'
#' jetpack::remove("randomForest")
#'
#' jetpack::remove(c("randomForest", "DBI"))
#'
#' jetpack::remove("plyr", remote="hadley/plyr")
#' }
remove <- function(packages, remotes=c()) {
  sandbox({
    prepCommand()

    desc <- getDesc()

    for (package in packages) {
      if (!desc$has_dep(package)) {
        stop(paste0("Cannot find package '", package, "' in DESCRIPTION file"))
      }

      desc$del_dep(package)
    }

    if (length(remotes) > 0) {
      for (remote in remotes) {
        desc$del_remotes(remote)
      }
    }

    installHelper(desc=desc)

    for (package in packages) {
      success(paste0("Removed ", package, "!"))
    }
  })
}

#' Update a package
#'
#' @param packages Packages to update
#' @param remotes Remotes to update
#' @export
#' @examples \dontrun{
#'
#' jetpack::update("randomForest")
#'
#' jetpack::update(c("randomForest", "DBI"))
#' }
update <- function(packages, remotes=c()) {
  sandbox({
    prepCommand()

    # store starting versions
    status <- getStatus()
    versions <- list()
    for (package in packages) {
      package <- getName(package)
      versions[package] <- pkgVersion(status, package)
    }

    desc <- updateDesc(packages, remotes)

    installHelper(remove=packages, desc=desc)

    # show updated versions
    status <- getStatus()
    for (package in packages) {
      package <- getName(package)
      currentVersion <- versions[package]
      newVersion <- pkgVersion(status, package)
      success(paste0("Updated ", package, " to ", newVersion, " (was ", currentVersion, ")"))
    }
  })
}

#' Check that all dependencies are installed
#'
#' @export
#' @examples \dontrun{
#'
#' jetpack::check()
#' }
check <- function() {
  sandbox({
    prepCommand()

    status <- getStatus()
    missing <- status[is.na(status$library.version), ]
    if (nrow(missing) > 0) {
      message(paste("Missing packages:", paste(missing$package, collapse=", ")))
      if (!interactive()) {
        warn("Run 'jetpack install' to install them")
      } else {
        warn("Run 'jetpack::install()' to install them")
      }
      invisible(FALSE)
    } else {
      success("All dependencies are satisfied")
      invisible(TRUE)
    }
  })
}

#' Show outdated dependencies
#'
#' @export
#' @examples \dontrun{
#'
#' jetpack::outdated()
#' }
outdated <- function() {
  sandbox({
    prepCommand()

    status <- getStatus()
    packages <- status[status$currently.used, ]$package

    deps <- remotes::package_deps(packages, repos=getOption("repos"), type=getOption("pkgType"))
    # TODO decide what to do about uninstalled packages
    outdated <- deps[deps$diff == -1, ]

    if (nrow(outdated) > 0) {
      for (i in 1:nrow(outdated)) {
        row <- outdated[i, ]
        message(paste0(row$package, " (latest ", row$available, ", installed ", row$installed, ")"))
      }
    } else {
      success("All packages are up-to-date!")
    }
  })
}
