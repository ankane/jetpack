## 0.4.2

- Fixed error with empty repos
- Fixed warning messages

## 0.4.1

- Added ability to update all packages in a project
- Added `jetpack::outdated()`
- Added `jetpack global outdated`
- Fixed issue with `jetpack::install()` updating package versions in `packrat.lock` when library gets ahead
- Fixed unnecessary downloads with specific versions

## 0.4.0

- Greatly reduced the number of dependencies
- Added support for Bioconductor remotes
- Added ability to update all global packages

Breaking changes

- Removed `info` and `search` commands to reduce dependencies

## 0.3.1

- First CRAN release
