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

    setupEnv(init=TRUE)

    if (!interactive()) {
      success("Run 'jetpack add <package>' to add packages!")
    } else {
      success("Run 'jetpack::add(package)' to add packages!")
    }
    invisible()
  })
}

initRprofile <- function() {
  rprofile <- file.exists(".Rprofile")
  if (!rprofile || !any(grepl("jetpack", readLines(".Rprofile")))) {
    str <- "if (requireNamespace(\"jetpack\", quietly=TRUE)) {
  jetpack::load()
} else {
  message(\"Install Jetpack to use a virtual environment for this project\")
}"

    if (rprofile) {
      # space it out
      str <- paste0("\n", str)
    }

    write(str, file=".Rprofile", append=TRUE)
  }
}
