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
  dir <- "."
  if (!isWindows()) {
    dir <- tempDir()
  }

  temp_desc <- file.path(dir, "DESCRIPTION")
  desc$write(temp_desc)
  # strip trailing whitespace
  lines <- trimws(readLines(temp_desc), "r")
  writeLines(lines, temp_desc)

  if (!isWindows()) {
    file.symlink(file.path(packrat::project_dir(), "packrat"), file.path(dir, "packrat"))
  }

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
    suppressMessages(packrat::snapshot(project=dir, prompt=FALSE))

    # loaded packages like curl can be missing on Windows
    # so see if we need to restore again
    status <- getStatus(project=dir)
    if (any(is.na(status$library.version))) {
      suppressWarnings(packrat::restore(project=dir, prompt=FALSE))
    }
  }

  # only write after successful
  if (!isWindows()) {
    file.copy(temp_desc, file.path(packrat::project_dir(), "DESCRIPTION"), overwrite=TRUE)
  }

  if (show_status) {
    if (statusUpdated) {
      status <- getStatus()
    }

    showStatus(status)
  }
}

isCLI <- function() {
  any(getOption("jetpack_cli"))
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

  options(packrat.project.dir=dir)
  if (!packratOn()) {
    stop("Packrat must be on to run this. Run:\npackrat::on(); packrat::extlib(\"jetpack\")")
  }

  checkInsecureRepos()
}

prepGlobal <- function() {
  noPackrat()

  repos <- getOption("repos")
  if (repos["CRAN"] == "@CRAN@") {
    options(repos=list(CRAN="https://cloud.r-project.org/"))
  }

  checkInsecureRepos()
}

sandbox <- function(code) {
  libs <- c("jsonlite", "withr", "devtools", "httr", "curl", "git2r", "desc", "docopt")
  if (isCLI()) {
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
  stop("This project has not yet been packified.\nRun 'jetpack init' to init.")
}

success <- function(msg) {
  cat(crayon::green(paste0(msg, "\n")))
}

tempDir <- function() {
  dir <- file.path(tempdir(), paste0("jetpack", as.numeric(Sys.time())))
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
      showStatus(status)
    } else {
      installHelper(show_status=TRUE)
    }

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
      packrat::init(".", options=list(print.banner.on.startup=FALSE), enter=FALSE)
      packrat::set_lockfile_metadata(repos=list(CRAN="https://cloud.r-project.org/"))
    }

    # automatically load jetpack if it's found
    # so it's convenient to run commands from RStudio
    # like jetpack.install()
    if (file.exists(".Rprofile") && !any(grepl("jetpack", readLines(".Rprofile")))) {
      write("invisible(tryCatch(packrat::extlib(\"jetpack\"), error=function(err) {}))", file=".Rprofile", append=TRUE)
    }

    if (isCLI()) {
      success("Run 'jetpack add <package>' to add packages!")
    } else {
      success("Run 'jetpack.add(package)' to add packages!")
      suppressMessages(packrat::on(print.banner=FALSE))
      packrat::extlib("jetpack")
    }
    invisible()
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
#' @param remotes Remotes to update
#' @export
jetpack.update <- function(packages, remotes) {
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
jetpack.check <- function() {
  sandbox({
    prepCommand()

    status <- getStatus()
    missing <- status[is.na(status$library.version), ]
    if (nrow(missing) > 0) {
      message(paste("Missing packages:", paste(missing$package, collapse=", ")))
      if (isCLI()) {
        warn("Run 'jetpack install' to install them")
      } else {
        warn("Run 'jetpack.install()' to install them")
      }
      invisible(FALSE)
    } else {
      success("All dependencies are satisfied")
      invisible(TRUE)
    }
  })
}

#' Run CLI
#'
#' @export
jetpack.cli <- function() {
  options(jetpack_cli=TRUE)

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
        jetpack.init()
      } else if (opts$add) {
        jetpack.add(opts$package, opts$remote)
      } else if (opts$remove) {
        jetpack.remove(opts$package, opts$remote)
      } else if (opts$update) {
        jetpack.update(opts$package, opts$remote)
      } else if (opts$check) {
        if (!jetpack.check()) {
          quit(status=1)
        }
      } else if (opts$version) {
        version()
      } else if (opts$help) {
        message(doc)
      } else if (opts$info) {
        jetpack.info(opts$package)
      } else if (opts$search) {
        jetpack.search(opts$query)
      } else {
        jetpack.install(deployment=opts$deployment)
      }
    }, error=function(err) {
      msg <- conditionMessage(err)
      cat(crayon::red(paste0(msg, "\n")))
      quit(status=1)
    })
  })
}

#' Get info for a package
#'
#' @param package Package to get info for
#' @importFrom utils URLencode
#' @export
jetpack.info <- function(package) {
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
    invisible()
  })
}

#' Search for packages
#'
#' @param query Search query
#' @export
jetpack.search <- function(query) {
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
    invisible()
  })
}

#' Create bin
#'
#' @param file The file to create
#' @export
createbin <- function(file=NULL) {
  if (isWindows()) {
    if (is.null(file)) {
      file <- "C:/ProgramData/jetpack/bin/jetpack.cmd"
    }
    rscript <- file.path(R.home("bin"), "Rscript.exe")
    dir <- dirname(file)
    if (!file.exists(dir)) {
      dir.create(dir, recursive=TRUE)
    }
    write(paste0("@", rscript, " -e \"library(methods); library(jetpack); jetpack.cli()\" %* "), file=file)
    message(paste("Wrote", windowsPath(file)))
    message(paste0("Be sure to add '", windowsPath(dir), "' to your PATH"))
  } else {
    if (is.null(file)) {
      file <- "/usr/local/bin/jetpack"
    }
    write("#!/usr/bin/env Rscript\n\nlibrary(methods)\nlibrary(jetpack)\njetpack.cli()", file=file)
    Sys.chmod(file, "755")
    message(paste("Wrote", file))
  }
}
