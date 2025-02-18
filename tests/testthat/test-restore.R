
context("Restore")

test_that("library permissions are validated before restore", {
  skip_on_os("windows")
  inaccessible <- renv_scope_tempfile()
  dir.create(inaccessible, mode = "0100")
  renv_scope_options(renv.verbose = FALSE)
  expect_false(renv_install_preflight_permissions(inaccessible))
})

test_that("we can restore packages after init", {
  skip_on_cran()
  renv_tests_scope("breakfast")

  renv::init()

  libpath <- renv_paths_library()
  before <- list.files(libpath)

  unlink(renv_paths_library(), recursive = TRUE)
  renv::restore()

  after <- list.files(libpath)
  expect_setequal(before, after)

})

test_that("restore can recover when required packages are missing", {
  skip_on_cran()
  renv_tests_scope("breakfast")
  renv::init()

  local({
    renv_scope_sink()
    renv::remove("oatmeal")
    renv::snapshot(force = TRUE)
    unlink(renv_paths_library(), recursive = TRUE)
    renv::restore()
  })

  expect_true(renv_package_installed("oatmeal"))

})

test_that("restore(clean = TRUE) removes packages not in the lockfile", {

  renv_tests_scope("oatmeal")
  renv::init()

  renv_scope_options(renv.config.auto.snapshot = FALSE)
  renv::install("bread")
  expect_true(renv_package_installed("bread"))

  renv::restore(clean = TRUE)
  expect_false(renv_package_installed("bread"))

})

test_that("renv.records can be used to override records during restore", {

  renv_tests_scope("bread")
  renv::init()

  renv::install("bread@0.1.0")
  renv::snapshot()
  expect_equal(renv_package_version("bread"), "0.1.0")

  bread <- list(Package = "bread", Version = "1.0.0", Source = "CRAN")
  overrides <- list(bread = bread)
  renv_scope_options(renv.records = overrides)

  renv::restore()
  expect_equal(renv_package_version("bread"), "1.0.0")

})

test_that("install.staged works as expected", {

  renv_tests_scope("breakfast")

  init()
  library <- renv_paths_library(project = getwd())

  install.opts <- list(breakfast = "--version")

  local({

    renv_scope_options(
      renv.config.install.staged = TRUE,
      renv.config.install.transactional = TRUE,
      install.opts = install.opts
    )

    renv_scope_envvars(RENV_PATHS_CACHE = tempfile())

    unlink(renv_paths_library(), recursive = TRUE)
    expect_error(renv::restore())
    files <- list.files(library)
    expect_true(length(files) == 0L)

  })

  local({

    renv_scope_options(
      renv.config.install.staged = FALSE,
      renv.config.install.transactional = FALSE,
      install.opts = install.opts
    )

    renv_scope_envvars(RENV_PATHS_CACHE = tempfile())

    unlink(renv_paths_library(), recursive = TRUE)
    expect_error(renv::restore())
    files <- list.files(library)
    expect_true(length(files) != 0L)

  })

})

test_that("renv::restore(lockfile = '/path/to/lockfile') works", {

  renv_tests_scope("bread")

  renv::init()

  unlink(paths$library(), recursive = TRUE)
  renv::restore(lockfile = "renv.lock")
  expect_true(renv_package_installed("bread"))

  unlink(paths$library(), recursive = TRUE)
  lockfile <- renv_lockfile_load(project = getwd())
  renv::restore(lockfile = "renv.lock")
  expect_true(renv_package_installed("bread"))

})

test_that("renv::restore(packages = <...>) works", {
  renv_tests_scope("breakfast")
  renv::init()
  unlink(paths$library(), recursive = TRUE)
  renv::restore(packages = "toast")
  expect_length(list.files(paths$library()), 2L)
  expect_true(renv_package_installed("bread"))
  expect_true(renv_package_installed("toast"))
})

test_that("restore ignores packages of incompatible architecture", {

  renv_scope_options(renv.tests.verbose = FALSE)

  renv_tests_scope(c("unixonly", "windowsonly"))
  renv::init()

  if (renv_platform_unix()) {

    expect_true(renv_package_installed("unixonly"))
    expect_false(renv_package_installed("windowsonly"))

    lockfile <- renv_lockfile_read("renv.lock")
    package <- lockfile$Packages$unixonly
    expect_identical(package$OS_type, "unix")

    remove("unixonly")
    restore()
    expect_true(renv_package_installed("unixonly"))

  } else {

    expect_true(renv_package_installed("windowsonly"))
    expect_false(renv_package_installed("unixonly"))

    lockfile <- renv_lockfile_read("renv.lock")
    package <- lockfile$Packages$windowsonly
    expect_identical(package$OS_type, "windows")

    remove("windowsonly")
    restore()
    expect_true(renv_package_installed("windowsonly"))

  }

})

test_that("restore handled records without version set", {

  renv_tests_scope()

  # create dummy lockfile
  snapshot()

  # read lockfile and add record without version
  lockfile <- renv_lockfile_load(project = getwd())
  lockfile$Packages$bread <- list(Package = "bread", Source = "Repository")
  renv_lockfile_save(lockfile, project = getwd())

  # try to restore
  restore()

  # check for success
  expect_true(renv_package_installed("bread"))
  expect_equal(renv_package_version("bread"), "1.0.0")

})

test_that("restore doesn't re-use active library paths", {

  renv_tests_scope()
  renv_scope_options(renv.settings.snapshot.type = "all")

  lib1 <- file.path(tempdir(), "lib1")
  lib2 <- file.path(tempdir(), "lib2")
  ensure_directory(c(lib1, lib2))
  .libPaths(c(lib2, .libPaths()))

  renv::install("bread", library = lib2)
  expect_true(renv_package_installed("bread", lib.loc = lib2))

  lockfile <- renv::snapshot(library = lib2, lockfile = NULL)
  restore(library = lib1, lockfile = lockfile)
  expect_true(renv_package_installed("bread", lib.loc = lib1))

})

test_that("restore(exclude = <...>) excludes as expected", {

  renv_tests_scope("breakfast")
  init()

  remove(c("bread", "breakfast", "oatmeal", "toast"))
  restore(exclude = "breakfast")
  expect_false(renv_package_installed("breakfast"))

})

test_that("restore works with explicit Source", {

  renv_tests_scope("breakfast")
  init()

  locals <- Sys.getenv("RENV_PATHS_LOCAL", unset = NA)
  if (is.na(locals))
    stop("internal error: RENV_PATHS_LOCAL unset in tests")

  renv_scope_envvars(
    RENV_PATHS_LOCAL = "",
    RENV_PATHS_CACHE = ""
  )

  record <- list(
    Package = "skeleton",
    Version = "1.0.0",
    Source  = file.path(locals, "skeleton/skeleton_1.0.0.tar.gz")
  )

  renv_test_retrieve(record)

  lockfile <- renv_lockfile_init(project = getwd())
  lockfile$Packages <- list(skeleton = record)
  renv_lockfile_write(lockfile, file = "renv.lock")
  remove("skeleton")

  restore()

  expect_true(renv_package_installed("skeleton"))
  expect_true(renv_package_version("skeleton") == "1.0.0")

})

test_that("restore() restores packages with broken symlinks", {

  skip_on_cran()
  renv_scope_options(renv.settings.cache.enabled = TRUE)
  renv_scope_options(renv.tests.verbose = FALSE)
  renv_tests_scope("breakfast")
  init()

  # break the cache
  record <- list(Package = "breakfast", Version = "1.0.0")
  cachepath <- renv_cache_find(record)
  unlink(cachepath, recursive = TRUE)

  # try to restore
  restore()

  # check that we're happy again
  expect_true(renv_package_installed("breakfast"))

})
