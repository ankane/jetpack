## 0.5.1 (unreleased)

- Fixed CRAN note

## 0.5.0 (2021-04-10)

- Switched from Packrat to renv
- Removed dependency on crayon
- Fixed error when CRAN repo not specified

## 0.4.3 (2019-07-01)

- Made tests self-contained

## 0.4.2 (2019-02-12)

- Fixed error with empty repos
- Fixed warning messages

## 0.4.1 (2018-11-15)

- Added ability to update all packages in a project
- Added `jetpack::outdated()`
- Added `jetpack global outdated`
- Fixed issue with `jetpack::install()` updating package versions in `packrat.lock` when library gets ahead
- Fixed unnecessary downloads with specific versions

## 0.4.0 (2018-10-30)

- Greatly reduced the number of dependencies
- Added support for Bioconductor remotes
- Added ability to update all global packages

Breaking changes

- Removed `info` and `search` commands to reduce dependencies

## 0.3.1 (2018-07-10)

- First CRAN release
- Fixed issue when init interrupted
- Turn on Packrat cache for Mac and Linux

## 0.3.0 (2018-07-05)

- Greatly reduced the number of files required
- Fixed error about stale packages with remotes
- Fixed error in CLI with check command
- Fixed error in CLI with global add command for specific version

## 0.2.0 (2018-06-23)

Breaking changes

- Removed `jetpack.` prefix from commands
- Renamed `createbin` to `cli`

## 0.1.11 (2018-06-22)

- Added info and search to R interface
- Fixed bugs with R interface

## 0.1.10 (2018-06-20)

- Added info and search commands
- Fixed some segfaults
- Fixed bugs with update

## 0.1.9 (2018-06-20)

- Added global commands

## 0.1.8 (2018-06-19)

- Created script for Windows

## 0.1.7 (2018-06-19)

- Fixes for Windows

## 0.1.6 (2018-06-17)

- Added check command
- Big performance increase

## 0.1.5 (2018-06-17)

- Don't update DESCRIPTION unless commands are successful
- Trim trailing whitespace in DESCRIPTION
- No longer modifies working directory when run from R

## 0.1.4 (2018-06-16)

- Added `--deployment` flag
- Added `createbin` function
- Fixed install issues

## 0.1.3 (2018-06-14)

- Added support for local repos
- Allow commands to be run in child directories
- Don't install `Suggests` dependencies
- Fixed issue with overwriting remotes

## 0.1.2 (2018-06-14)

- Created package
- Added RStudio commands

## 0.1.1 (2018-06-13)

- Fixed remote dependencies when httr not installed
- Properly restore `DESCRIPTION` when `add` command fails

## 0.1.0 (2018-06-11)

- First release
