context("bioconductor")

test_that("it works", {
  # fails on R-hub Ubuntu
  # possibly due to this warning:
  # 'getOption("repos")' replaces Bioconductor standard repositories
  skip_on_cran()
  skip_if(contains(R.version$status, "devel"))

  setup({
    jetpack::init()

    jetpack::add("BiocManager")
    expectFileContains("DESCRIPTION", "BiocManager")

    # needed for Biobase
    jetpack::add("BiocVersion", remote="bioc::release/BiocVersion")

    jetpack::add("Biobase", remote="bioc::release/Biobase")
    expectFileContains("DESCRIPTION", "Biobase")
    expectFileContains("DESCRIPTION", "bioc::release/Biobase")

    jetpack::remove("Biobase", remote="bioc::release/Biobase")
    jetpack::remove("BiocVersion", remote="bioc::release/BiocVersion")
    jetpack::remove("BiocManager")
  })
})
