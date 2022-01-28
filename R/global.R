prepGlobal <- function() {
  noRenv()
  checkInsecureRepos()
}

globalAdd <- function(packages, remotes) {
  globalInstallHelper(packages, remotes)

  for (package in packages) {
    package <- getName(package)
    success(paste0("Installed ", package, " ", utils::packageVersion(package)))
  }
}

globalInstallHelper <- function(packages, remotes=c()) {
  unversioned <- c()
  for (package in packages) {
    parts <- strsplit(package, "@")[[1]]
    if (length(parts) != 1) {
      package <- parts[1]
      version <- parts[2]
      remotes::install_version(package, version=version, reload=FALSE, repos=getRepos())
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
      pkgRemove(package)
    }

    remotes::install_deps(dir, reload=FALSE, repos=getRepos())
  }
}

globalList <- function() {
  packages <- as.data.frame(utils::installed.packages())
  packages <- packages[order(tolower(packages$Package)), ]
  for (i in seq_len(nrow(packages))) {
    row <- packages[i, ]
    message(paste0("Using ", row$Package, " ", row$Version))
  }
}

globalOutdatedPackages <- function() {
  packages <- rownames(utils::installed.packages())

  deps <- remotes::package_deps(packages, repos=getRepos())

  # TODO decide what to do about uninstalled packages
  deps[deps$diff == -1, ]
}

globalOutdated <- function() {
  outdated <- globalOutdatedPackages()

  if (nrow(outdated) > 0) {
    for (i in seq_len(nrow(outdated))) {
      row <- outdated[i, ]
      message(paste0(row$package, " (latest ", row$available, ", installed ", row$installed, ")"))
    }
  } else {
    success("All packages are up-to-date!")
  }
}

globalRemove <- function(packages) {
  for (package in packages) {
    suppressMessages(utils::remove.packages(package))
  }
  for (package in packages) {
    success(paste0("Removed ", package, "!"))
  }
}

globalUpdate <- function(packages, remotes, verbose) {
  if (length(packages) == 0) {
    outdated <- globalOutdatedPackages()

    if (nrow(outdated) > 0) {
      for (i in seq_len(nrow(outdated))) {
        row <- outdated[i, ]
        package <- row$package
        utils::install.packages(package, quiet=!verbose, repos=getRepos())
        newVersion <- as.character(utils::packageVersion(package))
        success(paste0("Updated ", package, " to ", newVersion, " (was ", row$installed, ")"))
      }
    } else {
      success("All packages are up-to-date!")
    }
  } else {
    versions <- list()
    for (package in packages) {
      package <- getName(package)
      versions[package] <- as.character(utils::packageVersion(package))
    }

    globalInstallHelper(packages, remotes)

    for (package in packages) {
      package <- getName(package)
      currentVersion <- versions[package]
      newVersion <- as.character(utils::packageVersion(package))
      success(paste0("Updated ", package, " to ", newVersion, " (was ", currentVersion, ")"))
    }
  }
}
