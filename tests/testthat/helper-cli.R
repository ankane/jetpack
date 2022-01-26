isWindows <- function() {
  .Platform$OS.type != "unix"
}

cliFile <- function() {
  ext <- if (isWindows()) ".cmd" else ""
  tempfile(pattern="jetpack", fileext=ext)
}

run <- function(cli, command) {
  debug <- FALSE

  if (!isWindows()) {
    # https://stat.ethz.ch/pipermail/r-devel/2018-February/075507.html
    rscript <- file.path(R.home("bin"), "Rscript")
    cli <- paste(rscript, cli)
  }

  cmd <- paste(cli, command, "2>&1")
  if (debug) {
    cat("\nCommand: ")
    cat(cmd)
  }

  output <- paste(system(cmd, intern=TRUE), collapse="\n")
  if (debug) {
    cat("\nOutput:\n")
    cat(output)
  }

  output
}
