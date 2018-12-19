#' Remove a package
#'
#' @param packages Packages to remove
#' @param remotes Remotes to remove
#' @export
#' @examples \dontrun{
#'
#' jetpack::remove("randomForest")
#'
#' jetpack::remove(c("randomForest", "DBI"))
#'
#' jetpack::remove("plyr", remote="hadley/plyr")
#' }
remove <- function(packages, remotes=c()) {
  sandbox({
    prepCommand()

    desc <- getDesc()

    for (package in packages) {
      if (!desc$has_dep(package)) {
        stop(paste0("Cannot find package '", package, "' in DESCRIPTION file"))
      }

      desc$del_dep(package)
    }

    if (length(remotes) > 0) {
      for (remote in remotes) {
        desc$del_remotes(remote)
      }
    }

    installHelper(desc=desc)

    for (package in packages) {
      success(paste0("Removed ", package, "!"))
    }
  })
}
