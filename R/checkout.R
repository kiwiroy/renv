
#' Checkout a Repository
#'
#' `renv::checkout()` can be used to install the latest packages available from
#' the requested repositories.
#'
#' @inheritParams renv-params
#'
#' @param repos The \R package repositories to check out. When `NULL` (the default),
#'   `renv` will attempt to determine the packages used in the project via
#'   a call to [renv::dependencies()].
#'
#' @param packages The packages to be installed. When `NULL` (the default),
#'   all packages currently used in the project will be installed.
#'
checkout <- function(repos = getOption("repos"),
                     ...,
                     packages = NULL,
                     clean    = FALSE,
                     project  = NULL)
{
  renv_consent_check()
  renv_scope_error_handler()
  renv_dots_check(...)

  project  <- renv_project_resolve(project)
  renv_scope_lock(project = project)

  # set new repositories
  options(repos = repos)

  # select packages to install
  packages <- packages %||% renv_checkout_packages(project = project)
  names(packages) <- packages

  # install all of these packages, effectively attempting to update
  # to the latest version of each package
  latest <- lapply(packages, function(package) {

    # ignore base packages (these are never distributed on CRAN)
    priority <- renv_package_priority(package)
    if (identical(priority, "base"))
      return(NULL)

    # try to get latest package record
    catch(renv_available_packages_latest(package))

  })

  # notify user if packages are unavailable
  unavailable <- filter(latest, inherits, "error")
  renv_pretty_print(
    values    = names(unavailable),
    preamble  = "The following package(s) are not available:",
    postamble = "These packages will be ignored.",
    wrap      = FALSE
  )

  # take only 'real' records
  records <- filter(latest, is.list)

  # ignore renv (just because someone might be using the development version
  # of renv to perform this action; we wouldn't want to downgrade here)
  records[["renv"]] <- NULL

  # create lockfile matching this request
  lockfile <- renv_lockfile_init(project = project)
  renv_records(lockfile) <- records

  # perform restore
  restore(
    project  = project,
    lockfile = lockfile,
    repos    = repos,
    clean    = clean
  )

  invisible(project)

}

renv_checkout_packages <- function(project) {

  # TODO: how should we select which packages are checked out?
  deps <- dependencies(project, progress = FALSE)
  packages <- unique(deps$Package)
  all <- renv_package_dependencies(packages, project = project)
  names(all)

}
