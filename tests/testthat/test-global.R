context("global")

test_that("it works", {
  setup({
    cli <- file.path(tempdir(), "jetpack")
    jetpack::cli(file=cli)

    expectContains(run(cli, "global list"), "Using")
  })
})
