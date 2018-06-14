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

findDir <- function(path) {
  if (file.exists(file.path(path, "packrat"))) {
    path
  } else if (dirname(path) == path) {
    abortNotPackified()
  } else {
    findDir(dirname(path))
  }
}

getStatus <- function() {
  tryCatch({
    suppressWarnings(packrat::status(quiet=TRUE))
  }, error=function(err) {
    msg <- conditionMessage(err)
    if (grepl("This project has not yet been packified", msg)) {
      abortNotPackified()
    } else {
      stop(msg)
    }
  })
}

installHelper <- function(status, remove=c()) {
  extlib <- c("httr", "curl", "git2r")

  missing <- status[is.na(status$library.version), ]
  restore <- missing[!is.na(missing$packrat.version), ]
  need <- missing[is.na(missing$packrat.version), ]

  # configure local repos
  remotes <- desc::desc_get_remotes()
  repos <- c()
  for (remote in remotes) {
    if (startsWith(remote, "local::")) {
      repo <- dirname(substring(remote, 8))
      repos <- c(repos, repo)
    }
  }
  packrat::set_opts(local.repos=repos, persist=FALSE)

  if (nrow(restore) > 0) {
    suppressWarnings(packrat::restore(prompt=FALSE))

    # non-vendor approach
    # for (i in 1:nrow(restore)) {
    #   row <- restore[i, ]
    #   packrat::with_extlib(extlib, devtools::install_version(row$package, version=row$version, dependencies=FALSE))
    # }
  }

  if (length(remove) > 0) {
    for (name in remove) {
      pkgRemove(name)
    }
  }

  # in case we're missing any deps
  # unfortunately, install_deps doesn't check version requirements
  # https://github.com/r-lib/devtools/issues/1314
  if (nrow(need) > 0 || length(remove) > 0) {
    # use extlib for remote deps
    packrat::with_extlib(extlib, devtools::install_deps(".", upgrade=FALSE))
  }

  # see if any version mismatches
  deps <- desc::desc_get_deps()
  specificDeps <- deps[startsWith(deps$version, "== "), ]
  if (nrow(specificDeps) > 0) {
    specificDeps$version <- sub("== ", "", specificDeps$version)
    specificDeps <- merge(specificDeps, status, by="package")
    mismatch <- specificDeps[!identical(specificDeps$version, specificDeps$packrat.version), ]
    if (nrow(mismatch) > 0) {
      for (i in 1:nrow(mismatch)) {
        row <- mismatch[i, ]
        packrat::with_extlib(extlib, devtools::install_version(row$package, version=row$version))
      }
    }
  }

  suppressMessages(packrat::clean())
  suppressMessages(packrat::snapshot(prompt=FALSE))
}

packified <- function() {
  file.exists("packrat")
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

prepCommand <- function(init=FALSE) {
  loadNamespace("packrat")
  packrat::off(print.banner=FALSE)
  for (lib in c("devtools", "desc", "crayon")) {
    loadNamespace(lib)
  }

  # work in child directories
  if (!init) {
    setwd(findDir(getwd()))
  }

  if (packified()) {
    packrat::on(print.banner=FALSE)
  }

  # before each method
  repos <- getOption("repos")
  if (is.list(repos)) {
    repos <- unlist(repos, use.names=FALSE)
  }
  insecure_repos <- repos[startsWith(repos, "http://")]
  for (repo in insecure_repos) {
    warn(paste0("Insecure CRAN repo: ", repo))
  }
}

revertAdd <- function(err, original_deps, original_remotes) {
  desc::desc_set_deps(original_deps)
  if (length(original_remotes) == 0) {
    desc::desc_del("Remotes")
  } else {
    desc::desc_set_remotes(original_remotes)
  }
  stop(conditionMessage(err))
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

tryLoad <- function(lib) {
  requireNamespace(lib, quietly=TRUE)
}

version <- function() {
  message(paste0("Jetpack version ", packageVersion("jetpack")))
}

warn <- function(msg) {
  cat(crayon::yellow(paste0(msg, "\n")))
}

#' Install packages for a project
#'
#' @export
jetpack.install <- function(deployment=FALSE) {
  prepCommand()
  status <- getStatus()

  if (deployment) {
    missing <- status[is.na(status$packrat.version), ]
    if (nrow(missing) > 0) {
      stop(paste("Missing packages:", paste(missing$package, collapse=", ")))
    }
    suppressWarnings(packrat::restore(prompt=FALSE))
  } else {
    tryCatch({
      installHelper(status)
    }, warning=function(err) {
      abort(conditionMessage(err))
    })
  }

  showStatus()

  success("Pack complete!")
}

#' Set up Jetpack
#'
#' @export
jetpack.init <- function() {
  prepCommand(init=TRUE)

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
  installHelper(getStatus())

  success("Run 'jetpack add <package>' to add packages!")
}

#' Add a package
#'
#' @param packages Packages to add
#' @param remotes Remotes to add
#' @export
jetpack.add <- function(packages, remotes=c()) {
  prepCommand()

  original_deps <- desc::desc_get_deps()
  original_remotes <- desc::desc_get_remotes()

  for (remote in remotes) {
    desc::desc_add_remotes(remote)
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

    desc::desc_set_dep(package, "Imports", version=version_str)
  }

  tryCatch({
    installHelper(getStatus())
  }, warning=function(err) {
    revertAdd(err, original_deps, original_remotes)
  }, error=function(err) {
    revertAdd(err, original_deps, original_remotes)
  })

  showStatus()

  success("Pack complete!")
}

#' Remove a package
#'
#' @param packages Packages to remove
#' @param remotes Remotes to remove
#' @export
jetpack.remove <- function(packages, remotes=c()) {
  prepCommand()
  status <- getStatus()

  # make sure package exists
  # possibly remove for speed
  for (package in packages) {
    pkgVersion(status, package)
  }

  for (package in packages) {
    desc::desc_del_dep(package, "Imports")
  }

  if (length(remotes) > 0) {
    for (remote in remotes) {
      desc::desc_del_remotes(remote)
    }
  }

  installHelper(getStatus())

  for (package in packages) {
    success(paste0("Removed ", package, "!"))
  }
}

#' Update a package
#'
#' @param packages Packages to update
#' @importFrom utils packageVersion
#' @export
jetpack.update <- function(packages) {
  prepCommand()
  status <- getStatus()

  versions <- list()
  for (package in packages) {
    versions[package] <- pkgVersion(status, package)
  }

  installHelper(status, remove=packages)

  for (package in packages) {
    currentVersion <- versions[package]
    newVersion <- packageVersion(package)
    success(paste0("Updated ", package, " to ", newVersion, " (was ", currentVersion, ")"))
  }
}

#' Run CLI
#'
#' @export
jetpack.cli <- function() {
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
