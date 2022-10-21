context("update renv")

test_that("it works", {
  # fails on CRAN r-devel-linux-x86_64-fedora-* with
  # failed to find source for 'renv 0.14.0' in package repositories
  # but passes on R-hub Fedora Linux, R-devel, clang, gfortran
  skip_on_cran()

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
