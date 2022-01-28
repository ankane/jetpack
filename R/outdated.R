#' Show outdated packages
#'
#' @return No return value
#' @export
#' @examples \dontrun{
#'
#' jetpack::outdated()
#' }
outdated <- function() {
  sandbox({
    status <- getStatus()
    packages <- names(status$lockfile$Package)

    deps <- remotes::package_deps(packages, repos=getRepos())
    # TODO decide what to do about uninstalled packages
    outdated <- deps[deps$diff == -1, ]

    if (nrow(outdated) > 0) {
      for (i in seq_len(nrow(outdated))) {
        row <- outdated[i, ]
        message(paste0(row$package, " (latest ", row$available, ", installed ", row$installed, ")"))
      }
    } else {
      success("All packages are up-to-date!")
    }
  })
}
