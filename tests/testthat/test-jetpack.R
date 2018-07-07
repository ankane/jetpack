context("jetpack")

skip_on_cran()
skip_on_travis()

library(withr)

options(repos=list(CRAN="https://cloud.r-project.org/"))

Sys.setenv(TEST_JETPACK = "true")

test_that("it works", {
  with_dir(tempdir(), {
    jetpack::init()
    jetpack::add("randomForest")
    jetpack::check()
    jetpack::install()
    jetpack::update("randomForest")
    jetpack::remove("randomForest")
    packrat::off()
  })
})
