context("init")

test_that("keeps DESCRIPTION", {
  setup({
    write("Package: app\nImports:\n    DBI", file="DESCRIPTION")

    jetpack::init()

    expectFileContains("DESCRIPTION", "DBI")
  })
})

test_that("not packified", {
  setup({
    expect_error(jetpack::add("DBI"), "This project has not yet been packified.\nRun 'jetpack::init()' to init.", fixed=TRUE)
  })
})
