context("update")

test_that("it works", {
  setup({
    jetpack::init()

    expect_error(jetpack::update("DBI"), "Cannot find package 'DBI' in DESCRIPTION file")

    jetpack::add("DBI@1.1.2")
    expectFileContains("DESCRIPTION", "DBI (== 1.1.2)")

    expect_message(jetpack::outdated(), "DBI")

    jetpack::update()
    expectFileContains("DESCRIPTION", "DBI")
    refuteFileContains("DESCRIPTION", "1.1.2")
  })
})
