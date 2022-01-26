library(withr)

setup <- function(code) {
  app_dir <- tempfile(pattern="app")
  renv_dir <- tempfile(pattern="renv")
  library_dir <- tempfile(pattern="library")
  venv_dir <- tempfile(pattern="venv")

  dir.create(app_dir)
  dir.create(renv_dir)
  dir.create(library_dir)
  dir.create(venv_dir)

  Sys.setenv(TEST_JETPACK="true")
  Sys.setenv(TEST_JETPACK_ROOT=venv_dir)
  Sys.setenv(RENV_PATHS_ROOT=renv_dir)
  Sys.setenv(RENV_PATHS_LIBRARY_ROOT=library_dir)

  with_dir(app_dir, code)
}

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
    print("Command:")
    print(cmd)
  }

  output <- paste(system(cmd, intern=TRUE), collapse="\n")
  if (debug) {
    print("Output:")
    print(output)
  }

  output
}
