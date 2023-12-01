# Jetpack

:fire: A friendly package manager for R

- Lightweight - adds just three files to your project
- Designed for reproducibility - thanks to [renv](https://rstudio.github.io/renv/), no more global installs!
- Works from both R and the command line

Inspired by [Yarn](https://yarnpkg.com/), [Bundler](https://bundler.io/), and [Pipenv](https://pipenv.pypa.io/en/latest/)

[![Build Status](https://github.com/ankane/jetpack/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/ankane/jetpack/actions) [![CRAN status](https://www.r-pkg.org/badges/version/jetpack)](https://cran.r-project.org/package=jetpack)

## Installation

Install Jetpack

```r
install.packages("jetpack")
```

## How It Works

Jetpack uses the `DESCRIPTION` file to store your project dependencies. It stores the specific version of each package in `renv.lock`. This makes it possible to have a reproducible environment. You can edit dependencies in the `DESCRIPTION` file directly, but Jetpack provides functions to help with this.

## Getting Started

Open a project and run:

```r
jetpack::init()
```

## Commands

### Install

Install packages for a project

```r
jetpack::install()
```

This ensures all the right versions are installed locally. As dependencies change, collaborators should run this command to stay synced.

> Be sure to prefix commands with `jetpack::`. Jetpack isn’t installed in your virtual environment, so `library(jetpack)` won’t work.

### Add

Add a package

```r
jetpack::add("randomForest")
```

Add multiple packages

```r
jetpack::add(c("randomForest", "DBI"))
```

Add a specific version

```r
jetpack::add("DBI@1.0.0")
```

Add from GitHub or another remote source

```r
jetpack::add("plyr", remote="hadley/plyr")
```

Supports [these remotes](https://cran.r-project.org/package=remotes/vignettes/dependencies.html)

Add from a specific tag, branch, or commit

```r
jetpack::add("plyr", remote="hadley/plyr@v1.8.4")
```

Add from a local source

```r
jetpack::add("plyr", remote="local::/path/to/plyr")
```

> The local directory must have the same name as the package

### Update

Update a package

```r
jetpack::update("randomForest")
```

> For local packages, run this anytime the package code is changed

Update multiple packages

```r
jetpack::update(c("randomForest", "DBI"))
```

Update all packages

```r
jetpack::update()
```

### Remove

Remove a package

```r
jetpack::remove("randomForest")
```

Remove multiple packages

```r
jetpack::remove(c("randomForest", "DBI"))
```

Remove remotes as well

```r
jetpack::remove("plyr", remote="hadley/plyr")
```

### Check

Check that all dependencies are installed

```r
jetpack::check()
```

### Outdated

Show outdated packages

```r
jetpack::outdated()
```

## Source Control

Be sure to commit the files Jetpack generates to source control.

## Bioconductor

For Bioconductor, add the BiocManager package first:

```r
jetpack::add("BiocManager")
```

Then add other packages:

```r
jetpack::add("Biobase", remote="bioc::release/Biobase")
```

## Deployment

### Server

Install Jetpack on the server and run:

```r
jetpack::install(deployment=TRUE)
```

### Docker

Create `init.R` with:

```r
install.packages("jetpack")
jetpack::install(deployment=TRUE)
```

And add it into your `Dockerfile`:

```Dockerfile
FROM r-base

RUN apt-get update && apt-get install -qq -y --no-install-recommends \
  libxml2-dev libssl-dev libcurl4-openssl-dev libssh2-1-dev

RUN mkdir -p /app
WORKDIR /app

COPY init.R DESCRIPTION renv.lock ./
RUN Rscript init.R

COPY . .

CMD Rscript app.R
```

### Heroku

For the [R buildpack](https://github.com/virtualstaticvoid/heroku-buildpack-r), create `init.R` with:

```r
install.packages("jetpack")
jetpack::install(deployment=TRUE)
```

Alternatively, you can use [Docker Deploys on Heroku](https://devcenter.heroku.com/articles/container-registry-and-runtime).

## Command Line

Jetpack can also be run from the command line. To install the CLI, run:

```r
jetpack::cli()
```

> On Windows, add `C:\ProgramData\jetpack\bin` to your PATH. See [instructions](https://www.howtogeek.com/118594/how-to-edit-your-system-path-for-easy-command-line-access/) for how to do this.

All the Jetpack commands are now available

```sh
jetpack init
jetpack install
jetpack add randomForest
jetpack add DBI@1.0.0
jetpack add plyr --remote=hadley/plyr
jetpack update randomForest
jetpack remove DBI
jetpack check
jetpack outdated
```

You can also use it to manage global packages

```sh
jetpack global add randomForest
jetpack global update DBI
jetpack global update
jetpack global remove plyr
jetpack global list
jetpack global outdated
```

You can even use it to update itself

```sh
jetpack global update jetpack
```

For the full list of commands, use:

```sh
jetpack help
```

## Upgrading

To upgrade, rerun the [installation instructions](#installation).

### 0.5.0

Jetpack 0.5.0 uses renv instead of Packrat. To upgrade a project:

1. Run `jetpack::migrate()`
2. Delete `packrat.lock`
3. Run `jetpack::install()`

### 0.4.0

Jetpack 0.4.0 greatly reduces the number of dependencies. As part of this, the `info` and `search` commands have been removed.

### 0.3.0

Jetpack 0.3.0 greatly reduces the number of files in your projects. To upgrade a project:

1. Move `packrat/packrat.lock` to `packrat.lock`
2. Delete the `packrat` directory
3. Delete `.Rbuildignore` and `.gitignore` if they only contain Packrat references
4. Replace all Jetpack and Packrat code in your `.Rprofile` with:

  ```r
  if (requireNamespace("jetpack", quietly=TRUE)) {
    jetpack::load()
  } else {
    message("Install Jetpack to use a virtual environment for this project")
  }
  ```

5. Open R and run:

  ```r
  jetpack::install()
  ```

## History

View the [changelog](https://github.com/ankane/jetpack/blob/master/NEWS.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/jetpack/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/jetpack/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features

To get started with development and testing:

```sh
git clone https://github.com/ankane/jetpack.git
cd jetpack
```

In R, do:

```r
install.packages("devtools")
devtools::install_deps(dependencies=TRUE)
devtools::test()
```

To test a single file, use:

```r
devtools::install() # to use latest updates
devtools::test_active_file("tests/testthat/test-jetpack.R")
```
