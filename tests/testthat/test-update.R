context("update")

test_that("it works", {
  # fails on CRAN r-devel-linux-x86_64-fedora-* with cannot open URL error
  # but passes on R-hub Fedora Linux, R-devel, clang, gfortran
  skip_on_cran()

  setup({
    jetpack::init()

    expect_error(jetpack::update("DBI"), "Cannot find package 'DBI' in DESCRIPTION file")

    jetpack::add("DBI@1.2.2")
    expectFileContains("DESCRIPTION", "DBI (== 1.2.2)")

    expect_message(jetpack::outdated(), "DBI")

    jetpack::update()
    expectFileContains("DESCRIPTION", "DBI")
    refuteFileContains("DESCRIPTION", "1.2.2")
  })
})
