## Resubmission

This is a resubmission. In this version I have:

* Added `\value` to exported methods
* Used `on.exit` to restore working directory and options
* Switched from `installed.packages()` to `find.package()`

## Test environments

* local OS X install, R 4.1.1
* ubuntu 20.04 (on GitHub Actions), R 4.1.2
* win-builder

## R CMD check results

There were no ERRORs or WARNINGs.

There was 1 NOTE:

```
New submission

Package was archived on CRAN

CRAN repository db overrides:
  X-CRAN-Comment: Archived on 2022-01-19 as check problems were not
    corrected in time.

  Random failures, usually involving a missing DBI Does not clean up
    use of ~/.cache/R/renv
```

Both issues were due to changes in renv 0.15.0 and have been fixed.

## Downstream dependencies

There are currently no downstream dependencies for this package.
