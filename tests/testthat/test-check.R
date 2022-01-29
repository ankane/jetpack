context("check")

test_that("it works", {
  setup({
    jetpack::init()

    expect_equal(TRUE, jetpack::check())

    write("Package: app\nImports:\n    DBI", file="DESCRIPTION")

    expect_output(jetpack::check(), "Run 'jetpack::install()' to install them", fixed=TRUE)
    expect_equal(FALSE, jetpack::check())
  })
})
