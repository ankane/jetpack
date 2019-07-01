context("jetpack")

library(withr)

app_dir <- file.path(tempdir(), "app")
packrat_dir <- file.path(tempdir(), "packrat")

dir.create(app_dir)
dir.create(packrat_dir)

Sys.setenv(TEST_JETPACK="true")
Sys.setenv(R_PACKRAT_CACHE_DIR=packrat_dir)

contains <- function(file, x) {
  grepl(x, paste(readLines(file), collapse=""))
}

test_that("it works", {
  tryCatch({
    with_dir(app_dir, {
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
