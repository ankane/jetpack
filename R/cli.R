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

windowsPath <- function(path) {
  gsub("/", "\\\\", path)
}
