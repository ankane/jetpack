library(withr)

setup <- function(code) {
  app_dir <- tempfile(pattern="app")
  renv_dir <- tempfile(pattern="renv")
  library_dir <- tempfile(pattern="library")

  dir.create(app_dir)
  dir.create(renv_dir)
  dir.create(library_dir)

  Sys.setenv(TEST_JETPACK="true")
  Sys.setenv(RENV_PATHS_ROOT=renv_dir)
  Sys.setenv(RENV_PATHS_LIBRARY_ROOT=library_dir)

  with_dir(app_dir, code)
}

isWindows <- function() {
  .Platform$OS.type != "unix"
}

cliFile <- function() {
  tempfile(pattern="jetpack")
}

run <- function(cli, command) {
  if (!isWindows()) {
    # https://stat.ethz.ch/pipermail/r-devel/2018-February/075507.html
    rscript <- file.path(R.home("bin"), "Rscript")
    cli <- paste(rscript, cli)
  }

  paste(system(paste(cli, command, "2>&1"), intern=TRUE), collapse="\n")
}
