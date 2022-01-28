context("remove")

test_that("it works", {
  setup({
    jetpack::init()

    expect_error(jetpack::remove("DBI"), "Cannot find package 'DBI' in DESCRIPTION file")
  })
})
