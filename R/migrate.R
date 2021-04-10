#' Migrate from packrat to renv
#'
#' @export
#' @examples \dontrun{
#'
#' jetpack::migrate()
#' }
migrate <- function() {
  sandbox({
    dir <- findDir(getwd())

    renv_lockfile <- file.path(dir, "renv.lock")
    packrat_lockfile <- file.path(dir, "packrat.lock")

    if (file.exists(renv_lockfile)) {
      message("renv.lock already exists. You should be good to go.")
    } else if (!file.exists(packrat_lockfile)) {
      message("packrat.lock does not exist.")
    } else {
      temp_dir <- tempDir()
      loadExternal("packrat")
      packrat_dir <- file.path(temp_dir, "packrat")
      dir.create(packrat_dir)
      file.copy(packrat_lockfile, file.path(packrat_dir, "packrat.lock"))

      # migrate
      quietly(renv::migrate(project=temp_dir, packrat=c("lockfile")))

      # add renv to prevent renv_path_absolute(path) is not TRUE error
      renvVersion <- as.character(utils::packageVersion("renv"))
      record <- list(Package="renv", Version=renvVersion, Source="CRAN")
      renv::record(list(renv=record), project=temp_dir)

      file.copy(file.path(temp_dir, "renv.lock"), renv_lockfile)
      cmd <- if (!interactive()) "jetpack install" else "jetpack::install()"
      message(paste0("Lockfile migration successful! To finish migrating:\n1. Delete packrat.lock\n2. Run '", cmd, "'"))
    }
  })
}
