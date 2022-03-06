library(testthat)
library(jetpack)

# for renv reverse dependency check
# https://github.com/ankane/jetpack/pull/25
requireNamespace("renv", quietly=TRUE)

test_check("jetpack")
