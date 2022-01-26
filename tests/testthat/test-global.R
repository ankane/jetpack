context("global")

test_that("it works", {
  skip_on_os("windows")

  setup({
    cli <- cliFile()
    jetpack::cli(file=cli)

    expectContains(run(cli, "global list"), "Using")
  })
})
