context("install")

test_that("it works", {
  setup({
    jetpack::init()

    jetpack::add("DBI")

    removeVenv()

    expect_message(jetpack::install(), "Creating virtual environment")
  })
})
