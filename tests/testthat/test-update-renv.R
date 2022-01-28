context("update renv")

test_that("it works", {
  setup({
    jetpack::init()

    record <- list(Package="renv", Version="0.14.0", Source="CRAN")
    renv::record(list(renv=record), project=getwd())

    jetpack::install()
    expectFileContains("renv.lock", "0.14.0")

    jetpack::update("renv")
    refuteFileContains("renv.lock", "0.14.0")
  })
})
