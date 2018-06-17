# helpers

abort <- function(msg, color=TRUE) {
  if (color) {
    cat(crayon::red(paste0(msg, "\n")))
  } else {
    message(msg)
  }
  quit(status=1)
}

abortNotPackified <- function() {
  stop("This project has not yet been packified.\nRun 'jetpack init' to init.")
}

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
  if (file.exists(file.path(path, "packrat"))) {
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

getStatus <- function(project=NULL) {
  tryCatch({
    suppressWarnings(packrat::status(project=project, quiet=TRUE))
  }, error=function(err) {
    msg <- conditionMessage(err)
    if (grepl("This project has not yet been packified", msg)) {
      abortNotPackified()
    } else {
      stop(msg)
    }
  })
}

installHelper <- function(remove=c(), desc=NULL) {
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
  dir <- file.path(tempdir(), paste0("jetpack", as.numeric(Sys.time())))
  dir.create(dir)
  temp_desc <- file.path(dir, "DESCRIPTION")
  desc$write(temp_desc)
  # strip trailing whitespace
  lines <- trimws(readLines(temp_desc), "r")
  writeLines(lines, temp_desc)

  file.symlink(file.path(packrat::project_dir(), "packrat"), file.path(dir, "packrat"))

  # get status
  status <- getStatus(project=dir)
  missing <- status[is.na(status$library.version), ]
  restore <- missing[!is.na(missing$packrat.version), ]
  need <- missing[is.na(missing$packrat.version), ]

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
  desc <- getDesc()
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
  }

  # in case we're missing any deps
  # unfortunately, install_deps doesn't check version requirements
  # https://github.com/r-lib/devtools/issues/1314
  if (nrow(need) > 0 || length(remove) > 0) {
    devtools::install_deps(dir, upgrade=FALSE, reload=FALSE)
  }

  suppressMessages(packrat::clean(project=dir))
  suppressMessages(packrat::snapshot(project=dir, prompt=FALSE))

  # only write after successful
  file.copy(temp_desc, file.path(packrat::project_dir(), "DESCRIPTION"), overwrite=TRUE)
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

prepCommand <- function() {
  dir <- findDir(getwd())

  if (is.null(dir)) {
    abortNotPackified()
  }

  options(packrat.project.dir=dir)
  packrat::on(print.banner=FALSE)

  checkInsecureRepos()
}

sandbox <- function(code) {
  library(methods)
  invisible(packrat::with_extlib(c("withr", "devtools", "httr", "curl", "git2r", "desc", "docopt"), code))
}

showStatus <- function() {
  status <- packrat::status(quiet=TRUE)
  for (i in 1:nrow(status)) {
    row <- status[i, ]
    message(paste0("Using ", row$package, " ", row$packrat.version))
  }
}

success <- function(msg) {
  cat(crayon::green(paste0(msg, "\n")))
}

#' @importFrom utils packageVersion
version <- function() {
  message(paste0("Jetpack version ", packageVersion("jetpack")))
}

warn <- function(msg) {
  cat(crayon::yellow(paste0(msg, "\n")))
}

#' Install packages for a project
#'
#' @param deployment Use deployment mode
#' @export
jetpack.install <- function(deployment=FALSE) {
  sandbox({
    prepCommand()

    if (deployment) {
      status <- getStatus()
      missing <- status[is.na(status$packrat.version), ]
      if (nrow(missing) > 0) {
        stop(paste("Missing packages:", paste(missing$package, collapse=", ")))
      }
      suppressWarnings(packrat::restore(prompt=FALSE))
    } else {
      installHelper()
    }

    showStatus()

    success("Pack complete!")
  })
}

#' Set up Jetpack
#'
#' @export
jetpack.init <- function() {
  sandbox({
    # create description file
    if (!file.exists("DESCRIPTION")) {
      write("Package: app", file="DESCRIPTION")
    }

    # initialize packrat
    if (!packified()) {
      # don't include jetpack in external.packages
      # since packrat will require it to be installed
      packrat::init(".", options=list(print.banner.on.startup=FALSE))
      packrat::set_lockfile_metadata(repos=list(CRAN="https://cloud.r-project.org/"))
    }

    # automatically load jetpack if it's found
    # so it's convenient to run commands from RStudio
    # like jetpack.install()
    if (file.exists(".Rprofile") && !any(grepl("jetpack", readLines(".Rprofile")))) {
      write("invisible(tryCatch(packrat::extlib(\"jetpack\"), error=function(err) {}))", file=".Rprofile", append=TRUE)
    }

    # install in case there was a previous DESCRIPTION file
    installHelper()

    success("Run 'jetpack add <package>' to add packages!")
  })
}

#' Add a package
#'
#' @param packages Packages to add
#' @param remotes Remotes to add
#' @export
jetpack.add <- function(packages, remotes=c()) {
  sandbox({
    prepCommand()

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

    installHelper(desc=desc)

    showStatus()

    success("Pack complete!")
  })
}

#' Remove a package
#'
#' @param packages Packages to remove
#' @param remotes Remotes to remove
#' @export
jetpack.remove <- function(packages, remotes=c()) {
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
#' @export
jetpack.update <- function(packages) {
  sandbox({
    prepCommand()

    # store starting versions
    status <- getStatus()
    versions <- list()
    for (package in packages) {
      versions[package] <- pkgVersion(status, package)
    }

    installHelper(remove=packages)

    # show updated versions
    status <- getStatus()
    for (package in packages) {
      currentVersion <- versions[package]
      newVersion <- pkgVersion(status, package)
      success(paste0("Updated ", package, " to ", newVersion, " (was ", currentVersion, ")"))
    }
  })
}

#' Run CLI
#'
#' @export
jetpack.cli <- function() {
  sandbox({
    doc <- "Usage:
    jetpack [install] [--deployment]
    jetpack init
    jetpack add <package>... [--remote=<remote>]...
    jetpack remove <package>... [--remote=<remote>]...
    jetpack update <package>...
    jetpack version
    jetpack help"

    opts <- NULL
    tryCatch({
      opts <- docopt::docopt(doc)
    }, error=function(err) {
      abort(doc, color=FALSE)
    })

    tryCatch({
      if (opts$init) {
        jetpack.init()
      } else if (opts$add) {
        jetpack.add(opts$package, opts$remote)
      } else if (opts$remove) {
        jetpack.remove(opts$package, opts$remote)
      } else if (opts$update) {
        jetpack.update(opts$package)
      } else if (opts$version) {
        version()
      } else if (opts$help) {
        message(doc)
      } else {
        jetpack.install(deployment=opts$deployment)
      }
    }, error=function(err) {
      abort(conditionMessage(err))
    })
  })
}

#' Create bin
#'
#' @param file The file to create
#' @export
createbin <- function(file="/usr/local/bin/jetpack") {
  write("#!/usr/bin/env Rscript\n\nlibrary(jetpack)\njetpack.cli()", file=file)
  Sys.chmod(file, "755")
  message(paste("Wrote", file))
}
