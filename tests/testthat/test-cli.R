context("cli")

test_that("it works", {
  setup({
    cli <- file.path(tempdir(), "jetpack")
    jetpack::cli(file=cli)

    run(cli, "init")
    expectFile("DESCRIPTION")
    expectFile("renv.lock")
    expectFile(".Rprofile")

    run(cli, "add DBI")
    expectContains("DESCRIPTION", "DBI")
    expectContains("renv.lock", "DBI")

    run(cli, "check")

    run(cli, "install")
    run(cli, "update DBI")

    run(cli, "remove DBI")
    refuteContains("DESCRIPTION", "DBI")
    refuteContains("renv.lock", "DBI")
  })
})
