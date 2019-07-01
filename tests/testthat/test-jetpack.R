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
packrat_dir <- file.path(tempdir(), "packrat")

createDir(app_dir)
createDir(packrat_dir)

Sys.setenv(TEST_JETPACK="true")
Sys.setenv(R_PACKRAT_CACHE_DIR=packrat_dir)

test_that("it works", {
  tryCatch({
    with_dir(app_dir, {
      jetpack::init()
      expectFile("DESCRIPTION")
      expectFile("packrat.lock")
      expectFile(".Rprofile")

      jetpack::add("randomForest")
      expectContains("DESCRIPTION", "randomForest")
      expectContains("packrat.lock", "randomForest")

      check <- jetpack::check()
      expect(check, "Check should return true")

      jetpack::install()
      jetpack::update("randomForest")

      jetpack::remove("randomForest")
      refuteContains("DESCRIPTION", "randomForest")
      refuteContains("packrat.lock", "randomForest")
    })
  }, finally={
    packrat::off()
  })
})
