context("bioconductor")

test_that("it works", {
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
