context("cli")

# must run before any calls to renv::deactivate()
test_that("it works", {
  setup({
    cli <- cliFile()
    jetpack::cli(file=cli)

    output <- run(cli, "init")
    expectContains(output, "Creating virtual environment")
    expectFile("DESCRIPTION")
    expectFile("renv.lock")
    expectFile(".Rprofile")

    output <- run(cli, "add DBI")
    expectContains(output, "Using DBI")
    expectFileContains("DESCRIPTION", "DBI")
    expectFileContains("renv.lock", "DBI")

    output <- run(cli, "check")
    expectContains(output, "All dependencies are satisfied")

    output <- run(cli, "install")
    expectContains(output, "Pack complete")

    output <- run(cli, "install --deployment")
    expectContains(output, "Pack complete")

    output <- run(cli, "update DBI")
    expectContains(output, "Updated DBI")

    output <- run(cli, "update")
    expectContains(output, "All packages are up-to-date")

    output <- run(cli, "remove DBI")
    expectContains(output, "Removed DBI")
    refuteFileContains("DESCRIPTION", "DBI")
    refuteFileContains("renv.lock", "DBI")

    # TODO test when older version installed
    output <- run(cli, "update renv")
    expectContains(output, "Updated renv")
  }, deactivate=FALSE)
})
