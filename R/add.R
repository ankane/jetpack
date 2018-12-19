#' Add a package
#'
#' @param packages Packages to add
#' @param remotes Remotes to add
#' @export
#' @examples \dontrun{
#'
#' jetpack::add("randomForest")
#'
#' jetpack::add(c("randomForest", "DBI"))
#'
#' jetpack::add("DBI@1.0.0")
#'
#' jetpack::add("plyr", remote="hadley/plyr")
#'
#' jetpack::add("plyr", remote="local::/path/to/plyr")
#' }
add <- function(packages, remotes=c()) {
  sandbox({
    prepCommand()

    desc <- updateDesc(packages, remotes)

    installHelper(desc=desc, show_status=TRUE)

    success("Pack complete!")
  })
}
