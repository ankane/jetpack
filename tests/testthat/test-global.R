context("global")

test_that("it works", {
  setup({
    cli <- cliFile()
    jetpack::cli(file=cli)

    expectContains(run(cli, "global list"), "Using")
  })
})
