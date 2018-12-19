#' Show outdated packages
#'
#' @export
#' @examples \dontrun{
#'
#' jetpack::outdated()
#' }
outdated <- function() {
  sandbox({
    prepCommand()

    status <- getStatus()
    packages <- status[status$currently.used, ]$package

    deps <- remotes::package_deps(packages)
    # TODO decide what to do about uninstalled packages
    outdated <- deps[deps$diff == -1, ]

    if (nrow(outdated) > 0) {
      for (i in 1:nrow(outdated)) {
        row <- outdated[i, ]
        message(paste0(row$package, " (latest ", row$available, ", installed ", row$installed, ")"))
      }
    } else {
      success("All packages are up-to-date!")
    }
  })
}
