context("jetpack")

library(withr)

options(repos=list(CRAN="https://cloud.r-project.org/"))

Sys.setenv(TEST_JETPACK = "true")

test_that("it works", {
  tryCatch({
    with_dir(tempdir(), {
      jetpack::init()
      expect(file.exists("DESCRIPTION"))
      expect(file.exists("packrat.lock"))

      jetpack::add("randomForest")
      expect(grepl("randomForest", paste(readLines("DESCRIPTION"), collapse="")))
      expect(grepl("randomForest", paste(readLines("packrat.lock"), collapse="")))

      check <- jetpack::check()
      expect(check)

      jetpack::install()
      jetpack::update("randomForest")

      jetpack::remove("randomForest")
      expect(!grepl("randomForest", paste(readLines("packrat.lock"), collapse="")))
      expect(!grepl("randomForest", paste(readLines("packrat.lock"), collapse="")))
    })
  }, finally={
    packrat::off()
  })
})
