context("all")

test_that("it works", {
  setup({
    jetpack::init()
    expectFile("DESCRIPTION")
    expectFile("renv.lock")
    expectFile(".Rprofile")

    jetpack::add("DBI")
    expectFileContains("DESCRIPTION", "DBI")
    expectFileContains("renv.lock", "DBI")

    check <- jetpack::check()
    expect(check, "Check should return true")

    jetpack::install()
    jetpack::install(deployment=TRUE)
    jetpack::update("DBI")

    jetpack::remove("DBI")
    refuteFileContains("DESCRIPTION", "DBI")
    refuteFileContains("renv.lock", "DBI")
  })
})
