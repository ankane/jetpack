context("jetpack")

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

app_dir <- file.path(tempdir(), "app")
renv_dir <- file.path(tempdir(), "renv")
library_dir <- file.path(tempdir(), "library")

createDir(app_dir)
createDir(renv_dir)
createDir(library_dir)

Sys.setenv(TEST_JETPACK="true")
Sys.setenv(RENV_PATHS_ROOT=renv_dir)
Sys.setenv(RENV_PATHS_LIBRARY_ROOT=library_dir)

test_that("it works", {
  with_dir(app_dir, {
    on.exit(renv::deactivate())

    jetpack::init()
    expectFile("DESCRIPTION")
    expectFile("renv.lock")
    expectFile(".Rprofile")

    jetpack::add("DBI")
    expectContains("DESCRIPTION", "DBI")
    expectContains("renv.lock", "DBI")

    check <- jetpack::check()
    expect(check, "Check should return true")

    jetpack::install()
    jetpack::update("DBI")

    jetpack::remove("DBI")
    refuteContains("DESCRIPTION", "DBI")
    refuteContains("renv.lock", "DBI")
  })
})
