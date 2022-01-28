context("migrate")

test_that("it works", {
  setup({
    expect_message(jetpack::migrate(), "This project has not yet been packified.")

    write("Package: app", file="DESCRIPTION")

    expect_message(jetpack::migrate(), "packrat.lock does not exist.")

    # write("todo", file="packrat.lock")

    # jetpack::migrate()

    # expectFile("renv.lock")

    # expect_message(jetpack::migrate(), "renv.lock already exists. You should be good to go.")
  })
})
