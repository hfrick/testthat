#' Run all tests in a directory
#'
#' This function is the low-level workhorse that powers [test_local()] and
#' [test_package()]. Generally, you should not call this function directly.
#' In particular, you are responsible for ensuring that the functions to test
#' are available in the test `env` (e.g. via `load_package`).
#'
#' @section Special files:
#' There are two types of `.R` file that have special behaviour:
#'
#' * Test files start with `test` and are executed in alphabetical order.
#'
#' * Setup files start with `setup` and are executed before tests. If
#'   clean up is needed after all tests have been run, you can use
#'   `withr::defer(clean_up(), teardown_env())`. See `vignette("test-fixtures")`
#'   for more details.
#'
#' There are two other types of special file that we no longer recommend using:
#'
#' * Helper files start with `helper` and are executed before tests are
#'   run. They're also loaded by `devtools::load_all()`, so there's no
#'   real point to them and you should just put your helper code in `R/`.
#'
#' * Teardown files start with `teardown` and are executed after the tests
#'   are run. Now we recommend interleave setup and cleanup code in `setup-`
#'   files, making it easier to check that you automatically clean up every
#'   mess that you make.
#'
#' All other files are ignored by testthat.
#'
#' @section Environments:
#' Each test is run in a clean environment to keep tests as isolated as
#' possible. For package tests, that environment that inherits from the
#' package's namespace environment, so that tests can access internal functions
#' and objects.
#'
#' @param path Path to directory containing tests.
#' @param package If these tests belong to a package, the name of the package.
#' @param filter If not `NULL`, only tests with file names matching this
#'   regular expression will be executed. Matching is performed on the file
#'   name after it's stripped of `"test-"` and `".R"`.
#' @param env Environment in which to execute the tests. Expert use only.
#' @param ... Additional arguments passed to [grepl()] to control filtering.
#' @param load_helpers Source helper files before running the tests?
#'   See [source_test_helpers()] for more details.
#' @param stop_on_failure If `TRUE`, throw an error if any tests fail.
#' @param stop_on_warning If `TRUE`, throw an error if any tests generate
#'   warnings.
#' @param load_package Strategy to use for load package code:
#'   * "none", the default, doesn't load the package.
#'   * "installed", uses [library()] to load an installed package.
#'   * "source", uses [pkgload::load_all()] to a source package.
#' @param wrap DEPRECATED
#' @keywords internal
#' @return A list (invisibly) containing data about the test results.
#' @inheritParams with_reporter
#' @inheritParams source_file
#' @export
test_dir <- function(path,
                     filter = NULL,
                     reporter = NULL,
                     env = NULL,
                     ...,
                     load_helpers = TRUE,
                     stop_on_failure = TRUE,
                     stop_on_warning = FALSE,
                     wrap = lifecycle::deprecated(),
                     package = NULL,
                     load_package = c("none", "installed", "source")
                     ) {

  load_package <- arg_match(load_package)

  start_first <- find_test_start_first(path, load_package, package)
  test_paths <- find_test_scripts(
    path,
    filter = filter,
    ...,
    full.names = FALSE,
    start_first = start_first
  )
  if (length(test_paths) == 0) {
    abort("No test files found")
  }

  if (!is_missing(wrap)) {
    lifecycle::deprecate_warn("3.0.0", "test_dir(wrap = )")
  }

  want_parallel <- find_parallel(path, load_package, package)

  if (is.null(reporter)) {
    if (want_parallel) {
      reporter <- default_parallel_reporter()
    } else {
      reporter <- default_reporter()
    }
  }
  reporter <- find_reporter(reporter)
  parallel <- want_parallel && reporter$capabilities$parallel_support

  test_files(
    test_dir = path,
    test_paths = test_paths,
    test_package = package,
    reporter = reporter,
    load_helpers = load_helpers,
    env = env,
    stop_on_failure = stop_on_failure,
    stop_on_warning = stop_on_warning,
    wrap = wrap,
    load_package = load_package,
    parallel = parallel
  )
}

#' Run all tests in a single file
#'
#' Helper, setup, and teardown files located in the same directory as the
#' test will also be run.
#'
#' @inherit test_dir return params
#' @inheritSection test_dir Special files
#' @inheritSection test_dir Environments
#' @param path Path to file.
#' @param ... Additional parameters passed on to `test_dir()`
#' @export
#' @examples
#' path <- testthat_example("success")
#' test_file(path)
#' test_file(path, reporter = "minimal")
test_file <- function(path, reporter = default_compact_reporter(), package = NULL, ...) {
  if (!file.exists(path)) {
    stop("`path` does not exist", call. = FALSE)
  }

  test_files(
    test_dir = dirname(path),
    test_package = package,
    test_paths = basename(path),
    reporter = reporter,
    ...
  )
}

test_files <- function(test_dir,
                       test_package,
                       test_paths,
                       load_helpers = TRUE,
                       reporter = default_reporter(),
                       env = NULL,
                       stop_on_failure = FALSE,
                       stop_on_warning = FALSE,
                       wrap = TRUE,
                       load_package = c("none", "installed", "source"),
                       parallel = FALSE) {

  if (is_missing(wrap)) {
    wrap <- TRUE
  }
  if (!isTRUE(wrap)) {
    lifecycle::deprecate_warn("3.0.0", "test_dir(wrap = )")
  }

  if (parallel) {
    test_files <- test_files_parallel
  } else {
    test_files <- test_files_serial
  }

  test_files(
    test_dir = test_dir,
    test_package = test_package,
    test_paths = test_paths,
    load_helpers = load_helpers,
    reporter = reporter,
    env = env,
    stop_on_failure = stop_on_failure,
    stop_on_warning = stop_on_warning,
    wrap = wrap,
    load_package = load_package
  )
}

test_files_serial <- function(test_dir,
                       test_package,
                       test_paths,
                       load_helpers = TRUE,
                       reporter = default_reporter(),
                       env = NULL,
                       stop_on_failure = FALSE,
                       stop_on_warning = FALSE,
                       wrap = TRUE,
                       load_package = c("none", "installed", "source")) {

  env <- test_files_setup_env(test_package, test_dir, load_package, env)
  test_files_setup_state(test_dir, test_package, load_helpers, env)
  reporters <- test_files_reporter(reporter)

  with_reporter(reporters$multi,
    lapply(test_paths, test_one_file, env = env, wrap = wrap)
  )

  test_files_check(reporters$list$get_results(),
    stop_on_failure = stop_on_failure,
    stop_on_warning = stop_on_warning
  )
}

test_files_setup_env <- function(test_package,
                                 test_dir,
                                 load_package = c("none", "installed", "source"),
                                 env = NULL) {
  library(testthat)

  load_package <- arg_match(load_package)
  switch(load_package,
    none = {},
    installed = library(test_package, character.only = TRUE),
    source = pkgload::load_all(test_dir, helpers = FALSE, quiet = TRUE)
  )

  env %||% test_env(test_package)
}

test_files_setup_state <- function(test_dir, test_package, load_helpers, env, .env = parent.frame()) {

  # Define testing environment
  local_test_directory(test_dir, test_package, .env = .env)
  withr::local_options(
    topLevelEnvironment = env_parent(env),
    .local_envir = .env
  )

  # Load helpers, setup, and teardown (on exit)
  local_teardown_env(.env)
  if (load_helpers) {
    source_test_helpers(".", env)
  }
  source_test_setup(".", env)
  withr::defer(withr::deferred_run(teardown_env()), .env) # new school
  withr::defer(source_test_teardown(".", env), .env)      # old school
}

test_files_reporter <- function(reporter, .env = parent.frame()) {
  lister <- ListReporter$new()
  reporters <- list(
    find_reporter(reporter),
    lister, # track data
    local_snapshotter("_snaps", fail_on_new = FALSE, .env = .env) # for snapshots
  )
  list(
    multi = MultiReporter$new(reporters = compact(reporters)),
    list = lister
  )
}

test_files_check <- function(results, stop_on_failure = TRUE, stop_on_warning = FALSE) {
  if (stop_on_failure && !all_passed(results)) {
    stop("Test failures", call. = FALSE)
  }
  if (stop_on_warning && any_warnings(results)) {
    stop("Tests generated warnings", call. = FALSE)
  }

  invisible(results)
}

test_one_file <- function(path, env = test_env(), wrap = TRUE) {
  reporter <- get_reporter()
  on.exit(teardown_run(), add = TRUE)

  reporter$start_file(path)
  source_file(path, child_env(env), wrap = wrap)
  reporter$end_context_if_started()
  reporter$end_file()
}

# Helpers -----------------------------------------------------------------

#' Run code after all test files
#'
#' This environment has no purpose other than as a handle for [withr::defer()]:
#' use it when you want to run code after all tests have been run.
#' Typically, you'll use `withr::defer(cleanup(), teardown_env())`
#' immediately after you've made a mess in a `setup-*.R` file.
#'
#' @export
teardown_env <- function() {
  testthat_env$teardown_env
}

local_teardown_env <- function(env = parent.frame()) {
  old <- testthat_env$teardown_env
  testthat_env$teardown_env <- child_env(emptyenv())
  withr::defer(testthat_env$teardown_env <- old, env)

  invisible()
}

#' Find test files
#'
#' @param path path to tests
#' @param invert If `TRUE` return files which **don't** match.
#' @param ... Additional arguments passed to [grepl()] to control filtering.
#' @param start_first A character vector of file patterns (globs, see
#'   [utils::glob2rx()]). The patterns are for the file names (base names),
#'   not for the whole paths. testthat starts the files matching the
#'   first pattern first,  then the ones matching the second, etc. and then
#'   the rest of the files, alphabetically. Parallel tests tend to finish
#'   quicker if you start the slowest files first. `NULL` means alphabetical
#'   order.
#' @inheritParams test_dir
#' @return A character vector of paths
#' @keywords internal
#' @export
find_test_scripts <- function(path, filter = NULL, invert = FALSE, ..., full.names = TRUE, start_first = NULL) {
  files <- dir(path, "^test.*\\.[rR]$", full.names = full.names)
  files <- filter_test_scripts(files, filter, invert, ...)
  order_test_scripts(files, start_first)
}

filter_test_scripts <- function(files, filter = NULL, invert = FALSE, ...) {
  if (is.null(filter)) {
    return(files)
  }

  which_files <- grepl(filter, context_name(files), ...)
  if (isTRUE(invert)) {
    which_files <- !which_files
  }
  files[which_files]
}

find_test_start_first <- function(path, load_package, package) {
  # Make sure we get the local package package if not "installed"
  if (load_package != "installed") package <- NULL
  desc <- find_description(path, package)
  if (is.null(desc)) {
    return(NULL)
  }

  conf <- desc$get_field("Config/testthat/start-first", NULL)
  if (is.null(conf)) {
    return(NULL)
  }

  trimws(strsplit(conf, ",")[[1]])
}

order_test_scripts <- function(paths, start_first) {
  if (is.null(start_first)) return(paths)
  filemap <- data.frame(
    stringsAsFactors = FALSE,
    base = sub("\\.[rR]$", "", sub("^test[-_\\.]?", "", basename(paths))),
    orig = paths
  )
  rxs <- utils::glob2rx(start_first)
  mch <- lapply(rxs, function(rx) filemap$orig[grep(rx, filemap$base)])
  unique(c(unlist(mch), paths))
}
