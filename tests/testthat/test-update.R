context("update")

test_that("it works", {
  setup({
    jetpack::init()

    jetpack::add("DBI@1.1.1")
    expectFileContains("DESCRIPTION", "DBI (== 1.1.1)")

    expect_message(jetpack::outdated(), "DBI")

    jetpack::update()
    expectFileContains("DESCRIPTION", "DBI")
    refuteFileContains("DESCRIPTION", "1.1.1")
  })
})