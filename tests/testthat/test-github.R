context("github")

test_that("it works", {
  # previously failed on CRAN due to network issue
  # cannot open URL 'https://api.github.com/repos/ankane/dbx/commits/HEAD'
  skip_on_cran()
  skip_on_ci()

  setup({
    jetpack::init()

    jetpack::add("dbx", remote="ankane/dbx")
    expectFileContains("DESCRIPTION", "ankane/dbx")

    jetpack::remove("dbx", remote="ankane/dbx")
    refuteFileContains("DESCRIPTION", "ankane/dbx")
  })
})
