#!/usr/bin/env Rscript
#
# Jetpack

jetpack_version <- "0.1.1"

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
  abort("This project has not yet been packified.\nRun 'jetpack init' to init.")
}

# more lightweight than getStatus
checkJetpack <- function() {
  if (!file.exists("packrat/init.R")) {
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
      abort(msg)
    }
  })
}

installHelper <- function(status, remove=c()) {
  extlib <- c("httr", "curl")

  tryCatch({
    missing <- status[is.na(status$library.version), ]
    restore <- missing[!is.na(missing$packrat.version), ]
    need <- missing[is.na(missing$packrat.version), ]

    if (nrow(restore)) {
      suppressWarnings(packrat::restore())
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
  }, error=function(err) {
    msg <- conditionMessage(err)
    if (grepl("This project has not yet been packified", msg)) {
      abort("This project has not yet been packified.\nRun 'jetpack init' to init.")
    } else {
      abort(msg)
    }
  })

  suppressMessages(packrat::clean())
  suppressMessages(packrat::snapshot())
}

loadDeps <- function() {
  if (tryLoad("packrat")) {
    packrat::off()
  }

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

  libs <- c("packrat", "devtools", "crayon", "desc", "docopt")
  for (lib in libs) {

    if (!tryLoad(lib)) {
      message(paste0("Installing Jetpack dependency: ", lib))
      # possibly use default repo if we are confident it's secure
      install.packages(lib, repos="https://cloud.r-project.org/", quiet=TRUE)
      tryLoad(lib)
    }
  }

  if (file.exists("packrat")) {
    packrat::on()
  }
}

pkgVersion <- function(status, name) {
  row <- status[status$package == name, ]
  if (nrow(row) == 0) {
    abort(paste0("Cannot find package '", name, "' in DESCRIPTION file"))
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
  abort(conditionMessage(err))
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

warn <- function(msg) {
  cat(crayon::yellow(paste0(msg, "\n")))
}

# commands

install <- function() {
  status <- getStatus()

  tryCatch({
    installHelper(status)
  }, warning=function(err) {
    abort(conditionMessage(err))
  })

  showStatus()

  success("Pack complete!")
}

init <- function() {
  # create description file
  if (!file.exists("DESCRIPTION")) {
    write("Package: app", file="DESCRIPTION")
  }

  # install packrat
  if (!file.exists("packrat")) {
    packrat::init(".", options=list(print.banner.on.startup=FALSE))
    packrat::set_lockfile_metadata(repos=list(CRAN="https://cloud.r-project.org/"))
  }

  installHelper(getStatus())

  success("Run 'jetpack add <package>' to add packages!")
}

add <- function(name, remote=NULL) {
  checkJetpack()

  remote <- c(remote)

  original_deps <- desc::desc_get_deps()
  original_remotes <- desc::desc_get_remotes()

  for (r in remote) {
    desc::desc_set_remotes(r)
  }

  for (n in name) {
    parts <- strsplit(name, "@")[[1]]
    version <- NULL
    version_str <- "*"
    if (length(parts) != 1) {
      n <- parts[1]
      version <- parts[2]
      version_str <- paste("==", version)
    }

    desc::desc_set_dep(n, "Imports", version=version_str)
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

remove <- function(name, remote) {
  status <- getStatus()

  # make sure package exists
  for (n in name) {
    pkgVersion(status, n)
  }

  remote <- c(remote)

  for (n in name) {
    desc::desc_del_dep(n, "Imports")
  }

  if (length(remote) > 0) {
    for (r in remote) {
      desc::desc_del_remotes(r)
    }
  }

  installHelper(getStatus())

  success(paste0("Removed ", name, "!"))
}

update <- function(name) {
  status <- getStatus()

  currentVersion <- pkgVersion(status, name)
  installHelper(status, remove=c(name))
  newVersion <- packageVersion(name)

  msg <- paste0("Updated ", name, " to ", newVersion, " (was ", currentVersion, ")")

  success(msg)
}

version <- function() {
  message(paste0("Jetpack version ", jetpack_version))
}

# main

main <- function() {
  loadDeps()

  doc <- "Usage:
  jetpack [install]
  jetpack init
  jetpack add <package>... [--remote=<remote>]...
  jetpack remove <package>... [--remote=<remote>]...
  jetpack update <package>
  jetpack version
  jetpack help"

  opts <- NULL
  tryCatch({
    opts <- docopt::docopt(doc)
  }, error=function(err) {
    abort(doc, color=FALSE)
  })

  if (opts$init) {
    init()
  } else if (opts$add) {
    add(opts$package, opts$remote)
  } else if (opts$remove) {
    remove(opts$package, opts$remote)
  } else if (opts$update) {
    update(opts$package)
  } else if (opts$version) {
    version()
  } else if (opts$help) {
    message(doc)
  } else {
    install()
  }
}

main()
