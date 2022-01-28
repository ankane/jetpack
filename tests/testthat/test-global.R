context("global")

# must run before any calls to renv::deactivate()
test_that("it works", {
  skip_if(!identical(Sys.getenv("TEST_JETPACK_GLOBAL"), "true"))

  setup({
    cli <- cliFile()
    jetpack::cli(file=cli)

    output <- run(cli, "global add DBI")
    expectContains(output, "Installed DBI")

    output <- run(cli, "global list")
    expectContains(output, "Using DBI")

    output <- run(cli, "global add DBI@1.1.1")
    expectContains(output, "Installed DBI 1.1.1")

    # TODO figure out remotes error on CI
    # can't convert package rcmdcheck with RemoteType 'any' to remote
    if (!isWindows()) {
      output <- run(cli, "global outdated")
      expectContains(output, "DBI")
    }

    output <- run(cli, "global update DBI")
    expectContains(output, "Updated DBI")

    # TODO figure out remotes error on CI
    # can't convert package rcmdcheck with RemoteType 'any' to remote
    if (!isWindows()) {
      output <- run(cli, "global outdated")
      refuteContains(output, "DBI")
    }

    output <- run(cli, "global remove DBI")
    expectContains(output, "Removed DBI")

    output <- run(cli, "global list")
    refuteContains(output, "Using DBI")
  }, deactivate=FALSE)
})
