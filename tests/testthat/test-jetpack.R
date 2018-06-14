test_that("init works", {
  jetpack.init()
  jetpack.add("jsonlite")
  jetpack.install()
  jetpack.update("jsonlite")
  jetpack.remove("jsonlite")
})
