library(withr)

createDir <- function(path) {
  if (!dir.exists(path)) {
    dir.create(path)
  }
}

contains <- function(file, x) {
  grepl(x, paste(readLines(file), collapse=""))
}

expectFile <- function(name) {
  expect(file.exists(name), paste(name, "does not exist"))
}

expectContains <- function(name, str) {
  expect(contains(name, str), paste(name, "does not contain", str))
}

refuteContains <- function(name, str) {
  expect(!contains(name, str), paste(name, "contains", str))
}

setup <- function(code) {
  app_dir <- file.path(tempdir(), "app")
  renv_dir <- file.path(tempdir(), "renv")
  library_dir <- file.path(tempdir(), "library")

  createDir(app_dir)
  createDir(renv_dir)
  createDir(library_dir)

  Sys.setenv(TEST_JETPACK="true")
  Sys.setenv(RENV_PATHS_ROOT=renv_dir)
  Sys.setenv(RENV_PATHS_LIBRARY_ROOT=library_dir)

  with_dir(app_dir, code)
}

run <- function(cli, command) {
  # https://stat.ethz.ch/pipermail/r-devel/2018-February/075507.html
  rscript <- file.path(Sys.getenv("R_HOME"), "bin", "Rscript")
  system(paste(rscript, cli, command))
}
