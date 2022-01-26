library(withr)

setup <- function(code) {
  app_dir <- tempfile(pattern="app")
  renv_dir <- tempfile(pattern="renv")
  library_dir <- tempfile(pattern="library")
  venv_dir <- tempfile(pattern="venv")

  dir.create(app_dir)
  dir.create(renv_dir)
  dir.create(library_dir)
  dir.create(venv_dir)

  Sys.setenv(TEST_JETPACK="true")
  Sys.setenv(TEST_JETPACK_ROOT=venv_dir)
  Sys.setenv(RENV_PATHS_ROOT=renv_dir)
  Sys.setenv(RENV_PATHS_LIBRARY_ROOT=library_dir)

  with_dir(app_dir, code)
}
