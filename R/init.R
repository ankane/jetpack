#' Set up Jetpack
#'
#' @export
#' @examples \dontrun{
#'
#' jetpack::init()
#' }
init <- function() {
  sandbox({
    if (!file.exists("DESCRIPTION")) {
      write("Package: app", file="DESCRIPTION")
    }

    initRprofile()

    setupEnv()

    if (!interactive()) {
      success("Run 'jetpack add <package>' to add packages!")
    } else {
      success("Run 'jetpack::add(package)' to add packages!")
      enablePackrat()
      loadNamespace("jetpack", lib.loc=getDefaultLibPaths())
    }
    invisible()
  })
}
