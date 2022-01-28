context("install deployment")

test_that("it works", {
  setup({
    jetpack::init()

    write("Package: app\nImports:\n    DBI", file="DESCRIPTION")

    expect_error(jetpack::install(deployment=TRUE), "Missing packages: DBI")
  })
})
