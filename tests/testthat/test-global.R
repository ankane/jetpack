context("global")

test_that("it works", {
  setup({
    cli <- file.path(tempdir(), "jetpack")
    jetpack::cli(file=cli)

    expectContainsStr(run(cli, "global list"), "Using")
  })
})
