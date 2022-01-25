#' Load Jetpack
#'
#' @return No return value
#' @export
#' @keywords internal
load <- function() {
  wd <- getwd()
  dir <- findDir(wd)

  if (is.null(dir)) {
    stopNotPackified()
  }

  tryCatch({
    venv_dir <- setupEnv(dir)

    # must source from virtualenv directory
    # for RStudio for work properly
    keepwd({
      setwd(venv_dir)
      quietly(source("renv/activate.R"))
    })
  }, error = function(e) {
    msg <- geterrmessage()
    args <- commandArgs(trailingOnly=TRUE)
    migrating <- !interactive() && identical(args, "migrate")
    if (!migrating) {
      if (interactive()) {
        stop(e)
      } else {
        message(conditionMessage(e))
        quit()
      }
    }
  })

  invisible()
}
