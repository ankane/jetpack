## 0.3.1 [unreleased]

- Fixed issue when init interrupted

## 0.3.0

- Greatly reduced the number of files required
- Fixed error about stale packages with remotes
- Fixed error in CLI with check command
- Fixed error in CLI with global add command for specific version

## 0.2.0

Breaking changes

- Removed `jetpack.` prefix from commands
- Renamed `createbin` to `cli`

## 0.1.11

- Added info and search to R interface
- Fixed bugs with R interface

## 0.1.10

- Added info and search commands
- Fixed some segfaults
- Fixed bugs with update

## 0.1.9

- Added global commands

## 0.1.8

- Created script for Windows

## 0.1.7

- Fixes for Windows

## 0.1.6

- Added check command
- Big performance increase

## 0.1.5

- Don't update DESCRIPTION unless commands are successful
- Trim trailing whitespace in DESCRIPTION
- No longer modifies working directory when run from R

## 0.1.4

- Added `--deployment` flag
- Added `createbin` function
- Fixed install issues

## 0.1.3

- Added support for local repos
- Allow commands to be run in child directories
- Don't install `Suggests` dependencies
- Fixed issue with overwriting remotes

## 0.1.2

- Created package
- Added RStudio commands

## 0.1.1

- Fixed remote dependencies when httr not installed
- Properly restore `DESCRIPTION` when `add` command fails

## 0.1.0

- First release
