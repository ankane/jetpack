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
    missing <- status[is.na(status$library.version), ]
    if (nrow(missing) > 0) {
      message(paste("Missing packages:", paste(missing$package, collapse=", ")))
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
