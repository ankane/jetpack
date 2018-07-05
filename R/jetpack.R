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

findDir <- function(path) {
  if (file.exists(file.path(path, "packrat.lock"))) {
    path
  } else if (dirname(path) == path) {
    NULL
  } else {
    findDir(dirname(path))
  }
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
      devtools::install_version(package, version=version, reload=FALSE)
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

    devtools::install_deps(dir, reload=FALSE)
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

globalRemove <- function(packages) {
  for (package in packages) {
    suppressMessages(remove.packages(package))
  }
  for (package in packages) {
    success(paste0("Removed ", package, "!"))
  }
}

globalUpdate <- function(packages, remotes) {
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

installHelper <- function(remove=c(), desc=NULL, show_status=FALSE) {
  if (is.null(desc)) {
    desc <- getDesc()
  }

  # configure local repos
  remotes <- desc$get_remotes()
  repos <- c()
  for (remote in remotes) {
    if (startsWith(remote, "local::")) {
      repo <- dirname(substring(remote, 8))
      repos <- c(repos, repo)
    }
  }
  packrat::set_opts(local.repos=repos, persist=FALSE)

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

  statusUpdated <- FALSE

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
        devtools::install_version(row$package, version=row$version, reload=FALSE)
      }
    }
    statusUpdated <- TRUE
  }

  # in case we're missing any deps
  # unfortunately, install_deps doesn't check version requirements
  # https://github.com/r-lib/devtools/issues/1314
  if (nrow(need) > 0 || length(remove) > 0) {
    devtools::install_deps(dir, upgrade=FALSE, reload=FALSE)
    statusUpdated <- TRUE
  }

  if (statusUpdated || any(!status$currently.used)) {
    suppressMessages(packrat::clean(project=dir))
    statusUpdated <- TRUE
  }

  if (statusUpdated) {
    suppressMessages(packrat::snapshot(project=dir, prompt=FALSE, ignore.stale=TRUE))

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
    if (statusUpdated) {
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
      suppressMessages(packrat::on(print.banner=FALSE))
    }
  }

  ensureRepos()
  checkInsecureRepos()
}

ensureRepos <- function() {
  repos <- getOption("repos")
  if (repos["CRAN"] == "@CRAN@") {
    options(repos=list(CRAN="https://cloud.r-project.org/"))
  }
}

prepGlobal <- function() {
  noPackrat()
  ensureRepos()
  checkInsecureRepos()
}

sandbox <- function(code) {
  libs <- c("jsonlite", "withr", "devtools", "httr", "curl", "git2r", "desc", "docopt")
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
    utils::capture.output(suppressMessages(packrat::init(venv_dir, options=list(print.banner.on.startup=FALSE), enter=FALSE)))
    packrat::set_lockfile_metadata(repos=list(CRAN="https://cloud.r-project.org/"))
  }

  if (!file.exists("packrat.lock")) {
    file.copy(file.path(packrat::project_dir(), "packrat", "packrat.lock"), "packrat.lock")
  }

  venv_dir
}

# Load Jetpack
#
#' @export
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
      suppressMessages(packrat::on(print.banner=FALSE))
      loadNamespace("jetpack", lib.loc=packrat:::getDefaultLibPaths())
    }
    invisible()
  })
}

#' Add a package
#'
#' @param packages Packages to add
#' @param remotes Remotes to add
#' @export
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

#' Get info for a package
#'
#' @param package Package to get info for
#' @importFrom utils URLencode
#' @export
info <- function(package) {
  sandbox({
    parts <- strsplit(package, "@")[[1]]
    version <- NULL
    if (length(parts) != 1) {
      package <- parts[1]
      version <- parts[2]
    }
    url <- paste0("https://crandb.r-pkg.org/", URLencode(package))
    if (!is.null(version)) {
      url <- paste0(url, "/", URLencode(version))
    }
    r <- httr::GET(url)
    error <- httr::http_error(r)
    if (error) {
      stop("Package not found")
    }
    body <- httr::content(r, "parsed")
    message(paste(body$Package, body$Version))
    message(paste("Title:", body$Title))
    message(paste("Date:", body$Date))
    message(paste("Author:", oneLine(body$Author)))
    message(paste("Maintainer:", oneLine(body$Maintainer)))
    message(paste("License:", body$License))
  })
}

#' Search for packages
#'
#' @param query Search query
#' @export
search <- function(query) {
  sandbox({
    post_body <- list(
      query=list(
        function_score=list(
          query=list(multi_match = list(query=query, fields=c("Package^10", "_all"), operator="and")),
          functions=list(list(script_score=list(script="cran_search_score")))
        )
      ),
      size=1000
    )
    r <- httr::POST("http://seer.r-pkg.org:9200/_search", body=post_body, encode="json")
    error <- httr::http_error(r)
    if (error) {
      stop("Network error")
    }
    body <- httr::content(r, "parsed")
    hits <- body$hits$hits
    if (length(hits) > 0) {
      for (i in 1:length(hits)) {
        hit <- hits[i][[1]]
        message(paste0(hit$`_id`, " ", hit$`_source`$Version, ": ", oneLine(hit$`_source`$Title)))
      }
    }
  })
}

#' Install the CLI
#'
#' @param file The file to create
#' @export
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

#' Run the CLI
#'
#' @export
run <- function() {
  sandbox({
    doc <- "Usage:
    jetpack [install] [--deployment]
    jetpack init
    jetpack add <package>... [--remote=<remote>]...
    jetpack remove <package>... [--remote=<remote>]...
    jetpack update <package>... [--remote=<remote>]...
    jetpack check
    jetpack info <package>
    jetpack search <query>
    jetpack version
    jetpack help
    jetpack global add <package>... [--remote=<remote>]...
    jetpack global remove <package>... [--remote=<remote>]...
    jetpack global update <package>... [--remote=<remote>]...
    jetpack global list"

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
          globalUpdate(opts$package, opts$remote)
        } else {
          globalList()
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
      } else if (opts$version) {
        version()
      } else if (opts$help) {
        message(doc)
      } else if (opts$info) {
        info(opts$package)
      } else if (opts$search) {
        search(opts$query)
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
