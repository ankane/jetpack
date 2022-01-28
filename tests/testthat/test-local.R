context("local")

test_that("it works", {
  local_path <- Sys.getenv("TEST_JETPACK_LOCAL_PATH", "")
  skip_if(local_path == "")

  setup({
    jetpack::init()

    jetpack::add("dbx", remote=paste0("local::", local_path))
    expectFileContains("DESCRIPTION", "dbx")
  })
})
