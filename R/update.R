#' Update a package
#'
#' @param packages Packages to update
#' @param remotes Remotes to update
#' @return No return value
#' @export
#' @examples \dontrun{
#'
#' jetpack::update("randomForest")
#'
#' jetpack::update(c("randomForest", "DBI"))
#'
#' jetpack::update()
#' }
update <- function(packages=c(), remotes=c()) {
  sandbox({
    if (length(packages) == 0) {
      status <- getStatus()
      packages <- names(status$lockfile$Package)
      packages <- packages[!packages %in% c("renv")]

      deps <- remotes::package_deps(packages, repos=getRepos())
      outdated <- deps[deps$diff < 0, ]

      if (nrow(outdated) > 0) {
        desc <- updateDesc(packages, remotes)

        installHelper(update_all=TRUE, desc=desc)

        for (i in 1:nrow(outdated)) {
          row <- outdated[i, ]
          if (is.na(row$installed)) {
            success(paste0("Installed ", row$package, " ", row$available))
          } else {
            success(paste0("Updated ", row$package, " to ", row$available, " (was ", row$installed, ")"))
          }
        }
      } else {
        success("All packages are up-to-date!")
      }
    } else {
      # store starting versions
      status <- getStatus()

      versions <- list()
      for (package in packages) {
        package <- getName(package)
        versions[package] <- pkgVersion(status, package)
      }

      if (packages %in% c("renv")) {
        renv::upgrade(prompt=FALSE)
      }

      desc <- updateDesc(packages[!packages %in% c("renv")], remotes)

      installHelper(remove=packages[!packages %in% c("renv")], desc=desc)

      # show updated versions
      status <- getStatus()
      for (package in packages) {
        package <- getName(package)
        currentVersion <- versions[package]
        newVersion <- pkgVersion(status, package)
        success(paste0("Updated ", package, " to ", newVersion, " (was ", currentVersion, ")"))
      }
    }
  })
}
