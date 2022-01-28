context("bioconductor")

test_that("it works", {
  # fails on R-hub Ubuntu
  # possibly due to this warning:
  # 'getOption("repos")' replaces Bioconductor standard repositories
  skip_on_cran()

  setup({
    on.exit(renv::deactivate())

    jetpack::init()

    jetpack::add("BiocManager")
    expectFileContains("DESCRIPTION", "BiocManager")
    expectFileContains("renv.lock", "Bioconductor")

    jetpack::add("Biobase", remote="bioc::release/Biobase")
    expectFileContains("DESCRIPTION", "Biobase")
    expectFileContains("DESCRIPTION", "bioc::release/Biobase")
  })
})
