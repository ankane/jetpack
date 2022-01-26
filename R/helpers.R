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

color <- function(message, color) {
  if (interactive() || isatty(stdout())) {
    color_codes = list(red=31, green=32, yellow=33)
    paste0("\033[", color_codes[color], "m", message, "\033[0m")
  } else {
    message
  }
}

enableRenv <- function() {
  # use load (activate updates profile then calls load)
  # no need to call quiet since we already set it globally
  renv::load(renvProject())
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

getDependencies <- function() {
  renv::dependencies(path=renvProject())
}

getDesc <- function() {
  desc::desc(file=renvProject())
}

getMissing <- function(status) {
  packages <- names(status$lockfile$Package)
  dependencies <- getDependencies()$Package
  missing <- setdiff(dependencies, packages)
}

getName <- function(package) {
  parts <- strsplit(package, "@")[[1]]
  if (length(parts) != 1) {
    package <- parts[1]
  }
  package
}

getRepos <- function() {
  repos <- getOption("repos", c())
  if (!is.na(repos["CRAN"]) && repos["CRAN"] == "@CRAN@") {
    # fine to update in-place (does not propagate to option)
    repos["CRAN"] <- "https://cloud.r-project.org/"
  }
  repos
}

getStatus <- function(project=NULL) {
  tryCatch({
    quietly(renv::status(project=project))
  }, error=function(err) {
    msg <- conditionMessage(err)
    if (grepl("This project has not yet been packified", msg)) {
      stopNotPackified()
    } else {
      stop(msg)
    }
  })
}

installHelper <- function(remove=c(), desc=NULL, show_status=FALSE, update_all=FALSE) {
  if (is.null(desc)) {
    desc <- getDesc()
  }

  # use a temporary directly
  # this way, we don't update DESCRIPTION
  # until we know it was successful
  dir <- renvProject()
  temp_desc <- file.path(dir, "DESCRIPTION")
  desc$write(temp_desc)
  # strip trailing whitespace
  lines <- trimws(readLines(temp_desc), "r")
  writeLines(lines, temp_desc)

  # get status
  status <- getStatus(project=dir)
  need <- getMissing(status)

  status_updated <- FALSE

  if (!identical(status$library$Packages, status$lockfile$Packages)) {
    suppressWarnings(renv::restore(project=dir, prompt=FALSE, clean=TRUE, repos=getRepos()))

    # non-vendor approach
    # for (i in 1:nrow(restore)) {
    #   row <- restore[i, ]
    #   devtools::install_version(row$package, version=row$version, dependencies=FALSE)
    # }

    status_updated <- TRUE
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
    for (i in 1:nrow(specificDeps)) {
      row <- specificDeps[i, ]
      currentDep <- status$lockfile$Packages[[row$package]]
      if (is.null(currentDep) || currentDep$Version != row$version) {
        remotes::install_version(row$package, version=row$version, reload=FALSE, repos=getRepos())
        status_updated <- TRUE
      }
    }
  }

  # in case we're missing any deps
  # unfortunately, install_deps doesn't check version requirements
  # https://github.com/r-lib/devtools/issues/1314
  if (length(need) > 0 || length(remove) > 0 || update_all) {
    remotes::install_deps(dir, upgrade=update_all, reload=FALSE, repos=getRepos())
    status_updated <- TRUE
  }

  if (status_updated) {
    suppressMessages(renv::snapshot(project=dir, prompt=FALSE, repos=getRepos()))
  }

  # copy back after successful
  jetpack_dir <- getOption("jetpack_dir")
  file.copy(file.path(renvProject(), "DESCRIPTION"), file.path(jetpack_dir, "DESCRIPTION"), overwrite=TRUE)
  file.copy(file.path(renvProject(), "renv.lock"), file.path(jetpack_dir, "renv.lock"), overwrite=TRUE)

  if (show_status) {
    if (status_updated) {
      status <- getStatus()
    }

    showStatus(status)
  }
}

isTesting <- function() {
  identical(Sys.getenv("TEST_JETPACK"), "true")
}

isWindows <- function() {
  .Platform$OS.type != "unix"
}

keepwd <- function(code) {
  wd <- getwd()
  on.exit(setwd(wd))
  eval(code)
}

loadExternal <- function(package) {
  lib_paths <- getOption("jetpack_lib")
  loadNamespace(package, lib.loc=lib_paths)
}

oneLine <- function(x) {
  gsub("\n", " ", x)
}

noRenv <- function() {
  if (renvOn()) {
    renv::deactivate(renvProject())
  }
}

packified <- function() {
  file.exists(file.path(renvProject(), "renv"))
}

pkgVersion <- function(status, name) {
  row <- status$lockfile$Package[[name]]
  if (is.null(row)) {
    stop(paste0("Cannot find package '", name, "' in DESCRIPTION file"))
  }
  row$Version
}

pkgRemove <- function(name) {
  if (length(find.package(name, quiet=TRUE)) > 0) {
    suppressMessages(utils::remove.packages(name))
  }
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
  file.copy(file.path(dir, "renv.lock"), file.path(venv_dir, "renv.lock"), overwrite=TRUE)

  if (!renvOn()) {
    if (interactive()) {
      stop("renv must be loaded to run this. Restart your R session to continue.")
    } else {
      enableRenv()
    }
  }

  checkInsecureRepos()
}

quietly <- function(code) {
  utils::capture.output(suppressMessages({
    val <- code
  }))
  val
}

renvOn <- function() {
  !is.na(Sys.getenv("RENV_PROJECT", unset=NA))
}

renvProject <- function() {
  getOption("jetpack_venv")
}

sandbox <- function(code) {
  libs <- c("remotes", "desc", "docopt")
  for (lib in libs) {
    loadExternal(lib)
  }
  invisible(eval(code))
}

showStatus <- function(status) {
  packages <- status$library$Packages
  packages <- packages[order(names(packages))]
  for (row in packages) {
    message(paste0("Using ", row$Package, " ", row$Version))
  }
}

silenceWarnings <- function(msgs, code) {
  unsolved_error <- FALSE
  muffle <- function(w) {
    if (any(sapply(msgs, function(x) { grepl(x, conditionMessage(w), fixed=TRUE) }))) {
      unsolved_error <<- TRUE
      invokeRestart("muffleWarning")
    }
  }
  res <- withCallingHandlers(code, warning=muffle)

  if (unsolved_error) {
    warn("Command successful despite error above (unsolved Jetpack issue)")
  }

  res
}

stopNotMigrated <- function() {
  cmd <- if (!interactive()) "jetpack migrate" else "jetpack::migrate()"
  stop(paste0("This project has not yet been migrated to renv.\nRun '", cmd, "' to migrate."))
}

stopNotPackified <- function() {
  cmd <- if (!interactive()) "jetpack init" else "jetpack::init()"
  stop(paste0("This project has not yet been packified.\nRun '", cmd, "' to init."))
}

success <- function(msg) {
  cat(color(paste0(msg, "\n"), "green"))
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

warn <- function(msg) {
  cat(color(paste0(msg, "\n"), "yellow"))
}

venvDir <- function(dir) {
  # similar logic as Pipenv
  if (isTesting()) {
    venv_dir <- Sys.getenv("TEST_JETPACK_ROOT")
  } else if (isWindows()) {
    venv_dir <- "~/.renvs"
  } else {
    venv_dir <- file.path(Sys.getenv("XDG_DATA_HOME", "~/.local/share"), "renvs")
  }

  # TODO better algorithm, but keep dependency free
  dir_hash <- sum(utf8ToInt(dir)) + 1
  venv_name <- paste0(basename(dir), "-", dir_hash)
  file.path(venv_dir, venv_name)
}

setupEnv <- function(dir=getwd(), init=FALSE) {
  venv_dir <- venvDir(dir)
  if (init && file.exists(venv_dir) && !file.exists(file.path(dir, "renv.lock"))) {
    # remove previous virtual env
    unlink(venv_dir, recursive=TRUE)
  }
  if (!file.exists(venv_dir)) {
    dir.create(venv_dir, recursive=TRUE)
  }

  options(renv.verbose=FALSE, renv.config.synchronized.check=FALSE, renv.config.sandbox.enabled=TRUE, jetpack_venv=venv_dir, jetpack_lib=.libPaths())

  # initialize renv
  if (!packified()) {
    if (file.exists(file.path(dir, "packrat.lock")) && !file.exists(file.path(dir, "renv.lock"))) {
      stopNotMigrated()
    }

    message("Creating virtual environment...")

    file.copy(file.path(dir, "DESCRIPTION"), file.path(venv_dir, "DESCRIPTION"), overwrite=TRUE)

    # restore wd after init changes it
    keepwd(quietly(renv::init(project=venv_dir, bare=TRUE, restart=FALSE, repos=getRepos(), settings=list(snapshot.type = "explicit"))))
    quietly(renv::snapshot(prompt=FALSE, force=TRUE, repos=getRepos()))

    # reload desc
    if (interactive()) {
      loadExternal("desc")
    }
  }

  if (!file.exists(file.path(dir, "renv.lock"))) {
    file.copy(file.path(renvProject(), "renv.lock"), file.path(dir, "renv.lock"))
  }

  venv_dir
}
