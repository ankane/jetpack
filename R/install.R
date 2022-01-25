#' Install packages for a project
#'
#' @param deployment Use deployment mode
#' @return No return value
#' @export
#' @examples \dontrun{
#'
#' jetpack::install()
#' }
install <- function(deployment=FALSE) {
  sandbox({
    prepCommand()

    if (deployment) {
      status <- getStatus()
      missing <- getMissing(status)
      if (length(missing) > 0) {
        stop(paste("Missing packages:", paste(missing, collapse=", ")))
      }
      suppressWarnings(renv::restore(prompt=FALSE))
      showStatus(status)
    } else {
      installHelper(show_status=TRUE)
    }

    success("Pack complete!")
  })
}
