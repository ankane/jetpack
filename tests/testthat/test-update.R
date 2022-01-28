context("update")

test_that("it works", {
  setup({
    on.exit(renv::deactivate())

    jetpack::init()

    jetpack::add("DBI@1.1.1")
    expectFileContains("DESCRIPTION", "DBI (== 1.1.1)")

    jetpack::update()
    expectFileContains("DESCRIPTION", "DBI")
    refuteFileContains("DESCRIPTION", "1.1.1")
  })
})
