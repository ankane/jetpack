context("migrate")

library(packrat)

test_that("it works", {
  # fails with unreleased renv versions
  # https://github.com/ankane/jetpack/issues/23
  skip_on_cran()

  setup({
    expect_message(jetpack::migrate(), "This project has not yet been initialized.")

    write("Package: app", file="DESCRIPTION")

    expect_message(jetpack::migrate(), "packrat.lock does not exist.")

    packrat_lock <- "PackratFormat: 1.4
PackratVersion: 0.7.0
RVersion: 4.1.1
Repos: CRAN=https://cloud.r-project.org

Package: DBI
Source: CRAN
Version: 1.1.2
Hash: dd5a8ce809e086244f5cfa75cb68b340

Package: packrat
Source: CRAN
Version: 0.7.0
Hash: 3d49688287bd2246cd8a58e233be39d5
"
    write(packrat_lock, file="packrat.lock")

    expect_error(jetpack::install(), "This project has not yet been migrated to renv.\nRun 'jetpack::migrate()' to migrate.", fixed=TRUE)

    jetpack::migrate()

    expectFile("renv.lock")
    expectFileContains("renv.lock", "DBI")

    # ideally renv::migrate() would exclude packrat
    # but running jetpack::install() fixes it
    # refuteFileContains("renv.lock", "packrat")

    expect_message(jetpack::migrate(), "renv.lock already exists. You should be good to go.")

    jetpack::install()

    refuteFileContains("renv.lock", "packrat")
  })
})
