#' Load Jetpack
#'
#' @export
#' @keywords internal
load <- function() {
  dir <- findDir(getwd())

  if (is.null(dir)) {
    stopNotPackified()
  }

  venv_dir <- setupEnv(dir)

  # must source from virtualenv directory
  # for RStudio for work properly
  # this should probably be fixed in Packrat
  wd <- getwd()
  tryCatch({
    setwd(venv_dir)
    utils::capture.output(suppressMessages(source("packrat/init.R")))
  }, finally={
    setwd(wd)
  })

  invisible()
}
