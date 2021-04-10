#' Check that all dependencies are installed
#'
#' @export
#' @examples \dontrun{
#'
#' jetpack::check()
#' }
check <- function() {
  sandbox({
    prepCommand()

    status <- getStatus()
    missing <- getMissing(status)
    if (length(missing) > 0) {
      message(paste("Missing packages:", paste(missing, collapse=", ")))
      if (!interactive()) {
        warn("Run 'jetpack install' to install them")
      } else {
        warn("Run 'jetpack::install()' to install them")
      }
      invisible(FALSE)
    } else {
      success("All dependencies are satisfied")
      invisible(TRUE)
    }
  })
}
