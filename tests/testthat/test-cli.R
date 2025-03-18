context("cli")

# must run before any calls to renv::deactivate()
test_that("it works", {
  setup({
    cli <- cliFile()
    jetpack::cli(file=cli)

    output <- runCli(cli, "init")
    expectContains(output, "Creating virtual environment")
    expectFile("DESCRIPTION")
    expectFile("renv.lock")
    expectFile(".Rprofile")

    output <- runCli(cli, "add DBI")
    expectContains(output, "Using DBI")
    expectFileContains("DESCRIPTION", "DBI")
    expectFileContains("renv.lock", "DBI")

    output <- runCli(cli, "check")
    expectContains(output, "All dependencies are satisfied")

    output <- runCli(cli, "install")
    expectContains(output, "Pack complete")

    output <- runCli(cli, "install --deployment")
    expectContains(output, "Pack complete")

    output <- runCli(cli, "update DBI")
    expectContains(output, "Updated DBI")

    output <- runCli(cli, "update")
    expectContains(output, "All packages are up-to-date")

    # different output based on whether renv is latest
    runCli(cli, "outdated")

    output <- runCli(cli, "remove DBI")
    expectContains(output, "Removed DBI")
    refuteFileContains("DESCRIPTION", "DBI")
    refuteFileContains("renv.lock", "DBI")

    # TODO debug
    if (!isWindows()) {
      # TODO test when older version installed
      output <- runCli(cli, "update renv")
      expectContains(output, "Updated renv")

      output <- runCli(cli, "outdated")
      expectContains(output, "All packages are up-to-date")
    }

    removeVenv()

    output <- runCli(cli, "install")
    expectContains(output, "Creating virtual environment")
  }, deactivate=FALSE)
})
