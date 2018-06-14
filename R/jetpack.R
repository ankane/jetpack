# helpers

tryLoad <- function(lib) {
  requireNamespace(lib, quietly=TRUE)
}

abortNotPackified <- function() {
  stop("This project has not yet been packified.\nRun 'jetpack init' to init.")
}

packified <- function() {
  file.exists("packrat")
}

# more lightweight than getStatus
checkJetpack <- function() {
  if (!packified()) {
    abortNotPackified()
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

prepCommand <- function() {
  # before each method
  repos <- getOption("repos")
  insecure_repos <- repos[startsWith(repos, "http://")]
  for (repo in insecure_repos) {
    msg <- paste0("Insecure CRAN repo: ", repo)
    if (tryLoad("crayon")) {
      warn(msg)
    } else {
      message(msg)
    }
  }

  tryLoad("packrat")
  tryLoad("devtools")
  tryLoad("desc")
  tryLoad("crayon")

  if (packified()) {
    packrat::on()
  }
}

installHelper <- function(status, remove=c()) {
  extlib <- c("httr", "curl")

  missing <- status[is.na(status$library.version), ]
  restore <- missing[!is.na(missing$packrat.version), ]
  need <- missing[is.na(missing$packrat.version), ]

  if (nrow(restore) > 0) {
    suppressWarnings(packrat::restore(prompt=FALSE))
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
    packrat::with_extlib(extlib, devtools::install_deps(".", dependencies=TRUE, upgrade=FALSE))
  }

  # see if any version mismatches
  deps <- desc::desc_get_deps()
  specificDeps <- deps[startsWith(deps$version, "== "), ]
  specificDeps$version <- sub("== ", "", specificDeps$version)
  specificDeps <- merge(specificDeps, status, by="package")
  mismatch <- specificDeps[!identical(specificDeps$version, specificDeps$packrat.version), ]
  if (nrow(mismatch) > 0) {
    for (i in 1:nrow(mismatch)) {
      row <- mismatch[i, ]
      packrat::with_extlib(extlib, devtools::install_version(row$package, version=row$version))

      # remove from need
      # need <- need[!identical(need$package, row$package), ]
    }
  }

  suppressMessages(packrat::clean())
  suppressMessages(packrat::snapshot(prompt=FALSE))
}

pkgVersion <- function(status, name) {
  row <- status[status$package == name, ]
  if (nrow(row) == 0) {
    stop(paste0("Cannot find package '", name, "' in DESCRIPTION file"))
  }
  row$packrat.version
}

pkgInstalled <- function(name) {
  name %in% rownames(installed.packages())
}

pkgRemove <- function(name) {
  if (pkgInstalled(name)) {
    suppressMessages(remove.packages(name))
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

warn <- function(msg) {
  cat(crayon::yellow(paste0(msg, "\n")))
}

# commands

#' Install packages for a project
#'
#' @export
jetpack.install <- function() {
  prepCommand()
  status <- getStatus()

  tryCatch({
    installHelper(status)
  }, warning=function(err) {
    abort(conditionMessage(err))
  })

  showStatus()

  success("Pack complete!")
}

#' Set up Jetpack
#'
#' @export
jetpack.init <- function() {
  prepCommand()

  # create description file
  if (!file.exists("DESCRIPTION")) {
    write("Package: app", file="DESCRIPTION")
  }

  # install packrat
  if (!packified()) {
    packrat::init(".", options=list(external.packages=c("jetpack"), print.banner.on.startup=FALSE))
    packrat::set_lockfile_metadata(repos=list(CRAN="https://cloud.r-project.org/"))
  }

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
  checkJetpack()

  original_deps <- desc::desc_get_deps()
  original_remotes <- desc::desc_get_remotes()

  for (remote in remotes) {
    desc::desc_set_remotes(remote)
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
