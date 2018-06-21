context("jetpack")

skip_on_cran()
skip_on_travis()

library(withr)

options(repos=list(CRAN="https://cloud.r-project.org/"))

Sys.setenv(TEST_JETPACK = "true")

test_that("it works", {
  with_dir(tempdir(), {
    jetpack.init()
    jetpack.add("jsonlite")
    jetpack.check()
    jetpack.install()
    jetpack.update("jsonlite")
    jetpack.remove("jsonlite")
    packrat::off()
  })
})
