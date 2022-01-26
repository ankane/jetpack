isWindows <- function() {
  .Platform$OS.type != "unix"
}

cliFile <- function() {
  ext <- if (isWindows()) ".cmd" else ""
  tempfile(pattern="jetpack", fileext=ext)
}

run <- function(cli, command) {
  debug <- FALSE

  args <- strsplit(command, " ", fixed=TRUE)[[1]]

  if (!isWindows()) {
    # https://stat.ethz.ch/pipermail/r-devel/2018-February/075507.html
    args <- c(cli, args)
    cli <- file.path(R.home("bin"), "Rscript")
  }

  if (debug) {
    cmd <- paste(c(cli, args), collapse=" ")
    cat("\nCommand: ")
    cat(cmd)
  }

  res <- system2(cli, args, stdout=TRUE, stderr=TRUE)
  status <- attr(res, "status")
  output <- paste(res, collapse="\n")

  if (debug) {
    cat("\nOutput:\n")
    cat(output)
  }

  if (!is.null(status)) {
    stop(paste("Command exited with status:", status, "\n", output))
  }

  output
}
