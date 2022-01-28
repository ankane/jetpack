context("init")

test_that("not packified", {
  setup({
    expect_error(jetpack::add("DBI"), "This project has not yet been packified.\nRun 'jetpack::init()' to init.", fixed=TRUE)
  })
})
