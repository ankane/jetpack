context("github")

test_that("it works", {
  setup({
    jetpack::init()

    jetpack::add("dbx", remote="ankane/dbx")
    expectFileContains("DESCRIPTION", "ankane/dbx")
  })
})
