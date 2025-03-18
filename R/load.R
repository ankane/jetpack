#' Load Jetpack
#'
#' @return No return value
#' @export
#' @keywords internal
load <- function() {
  dir <- findDir(getwd())

  if (is.null(dir)) {
    stopNotPackified()
  }

  tryCatch({
    configureRenv({
      setupEnv(dir)

      # must source from virtualenv directory
      # for RStudio for work properly
      wd <- getwd()
      on.exit(setwd(wd))
      setwd(renvProject())

      quietly(source("renv/activate.R"))
    })
  }, error=function(e) {
    if (interactive()) {
      stop(e)
    } else {
      message(conditionMessage(e))
      quit()
    }
  })

  invisible()
}
