context("migrate")

test_that("it works", {
  setup({
    expect_message(jetpack::migrate(), "This project has not yet been packified.")
  })
})
