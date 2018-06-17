context("jetpack")

library(withr)

options(repos=list(CRAN="https://cloud.r-project.org/"))

Sys.setenv(TEST_JETPACK = "true")

test_that("it works", {
  with_dir(tempdir(), {
    jetpack.init()
    jetpack.add("jsonlite")
    jetpack.install()
    jetpack.update("jsonlite")
    jetpack.remove("jsonlite")
    packrat::off()
  })
})
