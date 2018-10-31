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
    jetpack update <package>... [--remote=<remote>]...
    jetpack check
    jetpack outdated
    jetpack version
    jetpack help
    jetpack global add <package>... [--remote=<remote>]...
    jetpack global remove <package>... [--remote=<remote>]...
    jetpack global update [<package>...] [--remote=<remote>]... [--verbose]
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
          globalUpdate(opts$package, opts$remote, opts$verbose)
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
