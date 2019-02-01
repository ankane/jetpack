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

installHelper <- function(remove=c(), desc=NULL, show_status=FALSE, update_all=FALSE) {
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
  mismatch <- status[!is.na(status$library.version) & !is.na(status$packrat.version) & status$packrat.version != status$library.version, ]

  # remove mismatch
  for (name in mismatch$package) {
    pkgRemove(name)
  }

  status_updated <- FALSE

  if (nrow(restore) > 0 || nrow(mismatch) > 0) {
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
    mismatch <- specificDeps[is.na(specificDeps$packrat.version) | specificDeps$version != specificDeps$packrat.version, ]
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

pkgRemove <- function(name) {
  if (name %in% rownames(utils::installed.packages())) {
    suppressMessages(utils::remove.packages(name))
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
  repos <- getOption("repos", list())
  if (repos["CRAN"] == "@CRAN@") {
    repos["CRAN"] = "https://cloud.r-project.org/"
    options(repos=repos)
  }
}

sandbox <- function(code) {
  libs <- c("remotes", "desc", "docopt")

  if (!interactive()) {
    suppressMessages(packrat::extlib(libs))
    invisible(eval(code))
  } else {
    invisible(silenceWarnings("so cannot be unloaded", packrat::with_extlib(libs, code)))
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

warn <- function(msg) {
  cat(crayon::yellow(paste0(msg, "\n")))
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
