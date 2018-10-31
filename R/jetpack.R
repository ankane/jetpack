# helpers

checkInsecureRepos <- function() {
  repos <- getOption("repos")
  if (is.list(repos)) {
    repos <- unlist(repos, use.names=FALSE)
  }
  insecure_repos <- repos[startsWith(repos, "http://")]
  for (repo in insecure_repos) {
    warn(paste0("Insecure CRAN repo: ", repo))
  }
}

enablePackrat <- function() {
  clean <- !identical(Sys.getenv("TEST_JETPACK"), "true")
  suppressMessages(packrat::on(print.banner=FALSE, clean.search.path=clean))
}

findDir <- function(path) {
  if (file.exists(file.path(path, "DESCRIPTION"))) {
    path
  } else if (dirname(path) == path) {
    NULL
  } else {
    findDir(dirname(path))
  }
}

# duplicate logic from
# packrat:::getDefaultLibPaths()
getDefaultLibPaths <- function() {
  strsplit(Sys.getenv("R_PACKRAT_DEFAULT_LIBPATHS", unset = ""), .Platform$path.sep, fixed = TRUE)[[1]]
}

getDesc <- function() {
  desc::desc(file=packrat::project_dir())
}

getName <- function(package) {
  parts <- strsplit(package, "@")[[1]]
  if (length(parts) != 1) {
    package <- parts[1]
  }
  package
}

getStatus <- function(project=NULL) {
  tryCatch({
    suppressWarnings(packrat::status(project=project, quiet=TRUE))
  }, error=function(err) {
    msg <- conditionMessage(err)
    if (grepl("This project has not yet been packified", msg)) {
      stopNotPackified()
    } else {
      stop(msg)
    }
  })
}

globalAdd <- function(packages, remotes) {
  globalInstallHelper(packages, remotes)

  for (package in packages) {
    package <- getName(package)
    success(paste0("Installed ", package, " ", packageVersion(package)))
  }
}

globalInstallHelper <- function(packages, remotes=c()) {
  unversioned <- c()
  for (package in packages) {
    parts <- strsplit(package, "@")[[1]]
    if (length(parts) != 1) {
      package <- parts[1]
      version <- parts[2]
      remotes::install_version(package, version=version, reload=FALSE)
    } else {
      unversioned <- c(unversioned, package)
    }
  }

  if (length(unversioned) > 0) {
    # create temporary directory, write description, install deps
    dir <- tempDir()
    desc <- desc::desc("!new")
    for (remote in remotes) {
      desc$add_remotes(remote)
    }
    for (package in unversioned) {
      desc$set_dep(package, "Imports")
    }
    desc$write(file.path(dir, "DESCRIPTION"))

    # TODO don't remove for add command
    for (package in unversioned) {
      if (package %in% rownames(installed.packages())) {
        suppressMessages(remove.packages(package))
      }
    }

    remotes::install_deps(dir, reload=FALSE)
  }
}

globalList <- function() {
  packages <- as.data.frame(installed.packages())
  packages <- packages[order(tolower(packages$Package)), ]
  for (i in 1:nrow(packages)) {
    row <- packages[i, ]
    message(paste0("Using ", row$Package, " ", row$Version))
  }
}

globalOutdated <- function() {
  packages <- rownames(installed.packages())

  deps <- remotes::package_deps(packages)
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
}

globalRemove <- function(packages) {
  for (package in packages) {
    suppressMessages(remove.packages(package))
  }
  for (package in packages) {
    success(paste0("Removed ", package, "!"))
  }
}

globalUpdate <- function(packages, remotes, verbose) {
  if (length(packages) == 0) {
    oldPackages <- as.data.frame(utils::old.packages())
    packages <- rownames(oldPackages)

    updates <- FALSE

    for (package in packages) {
      currentVersion <- as.character(packageVersion(package))

      # double check, since old.packages() is sometimes wrong
      repoVersion <- gsub("-", ".", oldPackages$ReposVer[package])

      if (!identical(currentVersion, repoVersion)) {
        utils::install.packages(package, quiet=!verbose)
        newVersion <- as.character(packageVersion(package))
        success(paste0("Updated ", package, " to ", newVersion, " (was ", currentVersion, ")"))
        updates <- TRUE
      }
    }

    if (!updates) {
      success("All packages are up-to-date!")
    }
  } else {
    versions <- list()
    for (package in packages) {
      package <- getName(package)
      versions[package] <- as.character(packageVersion(package))
    }

    globalInstallHelper(packages, remotes)

    for (package in packages) {
      package <- getName(package)
      currentVersion <- versions[package]
      newVersion <- as.character(packageVersion(package))
      success(paste0("Updated ", package, " to ", newVersion, " (was ", currentVersion, ")"))
    }
  }
}

installHelper <- function(remove=c(), desc=NULL, show_status=FALSE, update_all=TRUE) {
  if (is.null(desc)) {
    desc <- getDesc()
  }

  # configure local repos
  remotes <- desc$get_remotes()
  local_repos <- c()
  bioc <- FALSE
  for (remote in remotes) {
    if (startsWith(remote, "local::")) {
      repo <- dirname(substring(remote, 8))
      local_repos <- c(local_repos, repo)
    } else if (startsWith(remote, "bioc::")) {
      bioc <- TRUE
    }
  }
  packrat::set_opts(local.repos=local_repos, persist=FALSE)

  repos <- getOption("repos")
  if (bioc && is.na(repos["BioCsoft"])) {
    # not ideal, will hopefully be fixed with
    # https://github.com/rstudio/packrat/issues/507
    bioc_repos <- c(
      BioCsoft="https://bioconductor.org/packages/3.7/bioc",
      BioCann="https://bioconductor.org/packages/3.7/data/annotation",
      BioCexp="https://bioconductor.org/packages/3.7/data/experiment",
      BioCworkflows="https://bioconductor.org/packages/3.7/workflows"
    )

    packrat::set_lockfile_metadata(repos=c(repos, bioc_repos))
  }

  # use a temporary directly
  # this way, we don't update DESCRIPTION
  # until we know it was successful
  dir <- packrat::project_dir()
  temp_desc <- file.path(dir, "DESCRIPTION")
  desc$write(temp_desc)
  # strip trailing whitespace
  lines <- trimws(readLines(temp_desc), "r")
  writeLines(lines, temp_desc)

  # get status
  status <- getStatus(project=dir)
  missing <- status[is.na(status$library.version), ]
  restore <- missing[!is.na(missing$packrat.version), ]
  need <- missing[is.na(missing$packrat.version), ]
  missing_packrat <- status[is.na(status$packrat.version), ]

  status_updated <- FALSE

  if (nrow(restore) > 0) {
    suppressWarnings(packrat::restore(project=dir, prompt=FALSE))

    # non-vendor approach
    # for (i in 1:nrow(restore)) {
    #   row <- restore[i, ]
    #   devtools::install_version(row$package, version=row$version, dependencies=FALSE)
    # }
  }

  if (length(remove) > 0) {
    for (name in remove) {
      pkgRemove(name)
    }
  }

  # see if any version mismatches
  # TODO expand to all version specifications
  deps <- desc$get_deps()
  specificDeps <- deps[startsWith(deps$version, "== "), ]
  if (nrow(specificDeps) > 0) {
    specificDeps$version <- sub("== ", "", specificDeps$version)
    specificDeps <- merge(specificDeps, status, by="package")
    mismatch <- specificDeps[!identical(specificDeps$version, specificDeps$packrat.version), ]
    if (nrow(mismatch) > 0) {
      for (i in 1:nrow(mismatch)) {
        row <- mismatch[i, ]
        remotes::install_version(row$package, version=row$version, reload=FALSE)
      }
    }
    status_updated <- TRUE
  }

  # in case we're missing any deps
  # unfortunately, install_deps doesn't check version requirements
  # https://github.com/r-lib/devtools/issues/1314
  if (nrow(need) > 0 || length(remove) > 0 || update_all) {
    remotes::install_deps(dir, upgrade=update_all, reload=FALSE)
    status_updated <- TRUE
  }

  if (status_updated || any(!status$currently.used)) {
    suppressMessages(packrat::clean(project=dir))
    status_updated <- TRUE
  }

  if (status_updated || length(missing_packrat) > 0) {
    # Bioconductor packages fail to download source
    suppressMessages(packrat::snapshot(project=dir, prompt=FALSE, ignore.stale=TRUE, snapshot.sources=FALSE))

    # loaded packages like curl can be missing on Windows
    # so see if we need to restore again
    status <- getStatus(project=dir)
    if (any(is.na(status$library.version))) {
      suppressWarnings(packrat::restore(project=dir, prompt=FALSE))
    }
  }

  # copy back after successful
  jetpack_dir <- getOption("jetpack_dir")
  file.copy(file.path(packrat::project_dir(), "DESCRIPTION"), file.path(jetpack_dir, "DESCRIPTION"), overwrite=TRUE)
  file.copy(file.path(packrat::project_dir(), "packrat", "packrat.lock"), file.path(jetpack_dir, "packrat.lock"), overwrite=TRUE)

  if (show_status) {
    if (status_updated) {
      status <- getStatus()
    }

    showStatus(status)
  }
}

isWindows <- function() {
  .Platform$OS.type != "unix"
}

oneLine <- function(x) {
  gsub("\n", " ", x)
}

noPackrat <- function() {
  if (packratOn()) {
    packrat::off()
  }
}

packified <- function() {
  file.exists(file.path(packrat::project_dir(), "packrat"))
}

pkgVersion <- function(status, name) {
  row <- status[status$package == name, ]
  if (nrow(row) == 0) {
    stop(paste0("Cannot find package '", name, "' in DESCRIPTION file"))
  }
  row$packrat.version
}

#' @importFrom utils installed.packages remove.packages
pkgRemove <- function(name) {
  if (name %in% rownames(installed.packages())) {
    suppressMessages(remove.packages(name))
  }
}

packratOn <- function() {
  !is.na(Sys.getenv("R_PACKRAT_MODE", unset = NA))
}

prepCommand <- function() {
  dir <- findDir(getwd())

  if (is.null(dir)) {
    stopNotPackified()
  }

  options(jetpack_dir=dir)
  venv_dir <- setupEnv(dir)

  # copy files
  file.copy(file.path(dir, "DESCRIPTION"), file.path(venv_dir, "DESCRIPTION"), overwrite=TRUE)
  file.copy(file.path(dir, "packrat.lock"), file.path(venv_dir, "packrat", "packrat.lock"), overwrite=TRUE)

  if (!packratOn()) {
    if (interactive()) {
      stop("Packrat must be on to run this. Run:\npackrat::on(); packrat::extlib(\"jetpack\")")
    } else {
      enablePackrat()
    }
  }

  packrat::set_opts(use.cache=!isWindows())

  ensureRepos()
  checkInsecureRepos()
}

ensureRepos <- function() {
  repos <- getOption("repos")
  if (repos["CRAN"] == "@CRAN@") {
    repos["CRAN"] = "https://cloud.r-project.org/"
    options(repos=repos)
  }
}

prepGlobal <- function() {
  noPackrat()
  ensureRepos()
  checkInsecureRepos()
}

sandbox <- function(code) {
  libs <- c("remotes", "desc", "docopt")

  if (!interactive()) {
    suppressMessages(packrat::extlib(libs))
    invisible(eval(code))
  } else {
    invisible(packrat::with_extlib(libs, code))
  }
}

showStatus <- function(status) {
  for (i in 1:nrow(status)) {
    row <- status[i, ]
    message(paste0("Using ", row$package, " ", row$packrat.version))
  }
}

stopNotPackified <- function() {
  cmd <- if (!interactive()) "jetpack init" else "jetpack::init()"
  stop(paste0("This project has not yet been packified.\nRun '", cmd, "' to init."))
}

success <- function(msg) {
  cat(crayon::green(paste0(msg, "\n")))
}

tempDir <- function() {
  dir <- file.path(tempdir(), sub("\\.", "", paste0("jetpack", as.numeric(Sys.time()))))
  dir.create(dir)
  dir
}

updateDesc <- function(packages, remotes) {
  desc <- getDesc()

  for (remote in remotes) {
    desc$add_remotes(remote)
  }

  for (package in packages) {
    parts <- strsplit(package, "@")[[1]]
    version <- NULL
    version_str <- "*"
    if (length(parts) != 1) {
      package <- parts[1]
      version <- parts[2]
      version_str <- paste("==", version)
    }

    desc$set_dep(package, "Imports", version=version_str)
  }

  desc
}

#' @importFrom utils packageVersion
version <- function() {
  message(paste0("Jetpack version ", packageVersion("jetpack")))
}

warn <- function(msg) {
  cat(crayon::yellow(paste0(msg, "\n")))
}

windowsPath <- function(path) {
  gsub("/", "\\\\", path)
}

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
#'
#' jetpack::update()
#' }
update <- function(packages=c(), remotes=c()) {
  sandbox({
    prepCommand()

    if (length(packages) == 0) {
      status <- getStatus()
      packages <- status[status$currently.used & status$package != "packrat", ]$package

      deps <- remotes::package_deps(packages)
      outdated <- deps[deps$diff < 0, ]

      desc <- updateDesc(packages, remotes)

      installHelper(update_all=TRUE, desc=desc)

      if (nrow(outdated) > 0) {
        for (i in 1:nrow(outdated)) {
          row <- outdated[i, ]
          if (is.na(row$installed)) {
            message(paste0("Installed ", row$package, " ", row$available))
          } else {
            message(paste0("Updated ", row$package, " to ", row$available, " (was ", row$installed, ")"))
          }
        }
      } else {
        success("All packages are up-to-date!")
      }
    } else {
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

#' Show outdated packages
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

    deps <- remotes::package_deps(packages)
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

#' Install the command line interface
#'
#' @param file The file to create
#' @export
#' @examples \dontrun{
#'
#' jetpack::cli()
#' }
cli <- function(file=NULL) {
  if (isWindows()) {
    if (is.null(file)) {
      file <- "C:/ProgramData/jetpack/bin/jetpack.cmd"
    }
    rscript <- file.path(R.home("bin"), "Rscript.exe")
    dir <- dirname(file)
    if (!file.exists(dir)) {
      dir.create(dir, recursive=TRUE)
    }
    write(paste0("@", rscript, " -e \"library(methods); jetpack::run()\" %* "), file=file)
    message(paste("Wrote", windowsPath(file)))
    message(paste0("Be sure to add '", windowsPath(dir), "' to your PATH"))
  } else {
    if (is.null(file)) {
      file <- "/usr/local/bin/jetpack"
    }
    write("#!/usr/bin/env Rscript\n\nlibrary(methods)\njetpack::run()", file=file)
    Sys.chmod(file, "755")
    message(paste("Wrote", file))
  }
}

#' Run the command line interface
#'
#' @export
#' @keywords internal
run <- function() {
  sandbox({
    doc <- "Usage:
    jetpack [install] [--deployment]
    jetpack init
    jetpack add <package>... [--remote=<remote>]...
    jetpack remove <package>... [--remote=<remote>]...
    jetpack update [<package>...] [--remote=<remote>]...
    jetpack check
    jetpack outdated
    jetpack version
    jetpack help
    jetpack global add <package>... [--remote=<remote>]...
    jetpack global remove <package>... [--remote=<remote>]...
    jetpack global update [<package>...] [--remote=<remote>]... [--verbose]
    jetpack global list
    jetpack global outdated"

    opts <- NULL
    tryCatch({
      opts <- docopt::docopt(doc)
    }, error=function(err) {
      msg <- conditionMessage(err)
      if (!grepl("usage:", msg)) {
        warn(msg)
      }
      message(doc)
      quit(status=1)
    })

    tryCatch({
      if (opts$global) {
        prepGlobal()
        if (opts$add) {
          globalAdd(opts$package, opts$remote)
        } else if (opts$remove) {
          # do nothing with remote
          # keep so it's consistent with remove
          # and easy to reverse global add
          globalRemove(opts$package)
        } else if (opts$update) {
          globalUpdate(opts$package, opts$remote, opts$verbose)
        } else if (opts$list) {
          globalList()
        } else {
          globalOutdated()
        }
      } else if (opts$init) {
        init()
      } else if (opts$add) {
        add(opts$package, opts$remote)
      } else if (opts$remove) {
        remove(opts$package, opts$remote)
      } else if (opts$update) {
        update(opts$package, opts$remote)
      } else if (opts$check) {
        if (!check()) {
          quit(status=1)
        }
      } else if (opts$outdated) {
        outdated()
      } else if (opts$version) {
        version()
      } else if (opts$help) {
        message(doc)
      } else {
        install(deployment=opts$deployment)
      }
    }, error=function(err) {
      msg <- conditionMessage(err)
      cat(crayon::red(paste0(msg, "\n")))
      quit(status=1)
    })
  })
}
