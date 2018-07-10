context("jetpack")

library(withr)

options(repos=list(CRAN="https://cloud.r-project.org/"))

Sys.setenv(TEST_JETPACK = "true")

contains <- function(file, x) {
  grepl(x, paste(readLines(file), collapse=""))
}

test_that("it works", {
  tryCatch({
    with_dir(tempdir(), {
      jetpack::init()
      expect(file.exists("DESCRIPTION"))
      expect(file.exists("packrat.lock"))
      expect(file.exists(".Rprofile"))

      jetpack::add("randomForest")
      expect(contains("DESCRIPTION", "randomForest"))
      expect(contains("packrat.lock", "randomForest"))

      check <- jetpack::check()
      expect(check)

      jetpack::install()
      jetpack::update("randomForest")

      jetpack::remove("randomForest")
      expect(!contains("DESCRIPTION", "randomForest"))
      expect(!contains("packrat.lock", "randomForest"))
    })
  }, finally={
    packrat::off()
  })
})
