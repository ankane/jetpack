# Jetpack

:fire: A friendly package manager for R

- Designed for reproducibility (thanks to [Packrat](https://rstudio.github.io/packrat/), no more global installs!)
- Secure by default
- Works from both R and the command line

![Screenshot](https://gist.github.com/ankane/b6988db2802aca68a589b31e41b44195/raw/04f556bdec33ae74f0cdaec3ae2476930986fd58/jetpack.png)

Inspired by [Yarn](https://yarnpkg.com/) and [Bundler](https://bundler.io/)

[![Build Status](https://travis-ci.org/ankane/jetpack.svg?branch=master)](https://travis-ci.org/ankane/jetpack)

## Installation

Install Jetpack

```r
install.packages("devtools")
devtools::install_github("ankane/jetpack@v0.2.0")
```

## Getting Started

Open a project and run:

```r
jetpack::init()
```

This sets up Packrat and creates a `DESCRIPTION` file to store your dependencies.

If your project uses Git, `packrat/lib*/` is added to your `.gitignore`.

## Commands

### Install

Install packages for a project

```r
jetpack::install()
```

Whenever a teammate adds a new package, others just need to run this command to keep packages in sync. New members who join should run this to get set up.

### Add

Add a package

```r
jetpack::add("dplyr")
```

Add multiple packages

```r
jetpack::add(c("jsonlite", "stringr"))
```

Add a specific version

```r
jetpack::add("dplyr@0.7.5")
```

Add from GitHub or another remote source

```r
jetpack::add("dplyr", remote="tidyverse/dplyr")
```

Supports [all of these remotes](https://cran.r-project.org/web/packages/devtools/vignettes/dependencies.html)

Add from a specific tag, branch, or commit

```r
jetpack::add("dplyr", remote="tidyverse/dplyr@v0.7.5")
```

Add from a local source

```r
jetpack::add("dplyr", remote="local::/path/to/dplyr")
```

> The local directory must have the same name as the package

### Update

Update a package

```r
jetpack::update("dplyr")
```

> For local packages, run this anytime the package code is changed

Update multiple packages

```r
jetpack::update(c("jsonlite", "stringr"))
```

### Remove

Remove a package

```r
jetpack::remove("dplyr")
```

Remove multiple packages

```r
jetpack::remove(c("jsonlite", "stringr"))
```

Remove remotes as well

```r
jetpack::remove("dplyr", remote="tidyverse/dplyr")
```

### Check

Check that all dependencies are installed

```r
jetpack::check()
```

### Info

Get info for a package

```r
jetpack::info("stringr")
```

Get info for a specific version

```r
jetpack::info("stringr@1.0.0")
```

### Search

Search for packages

```r
jetpack::search("xgboost")
```

Search multiple words

```r
jetpack::search("neural network")
```

Works with title, description, authors, maintainers, and more

## Source Control

Be sure to commit all files Jetpack generates to source control, except for the `packrat/lib*/` directories.

## Deployment

### Server

Install Jetpack on the server and run:

```r
jetpack::install(deployment=TRUE)
```

### Docker

Create an `init.R` with:

```r
install.packages("packrat")
source("packrat/init.R")
packrat::restore()
```

And add it into your `Dockerfile`:

```Dockerfile
FROM r-base

RUN apt-get update && apt-get install -qq -y --no-install-recommends \
  libxml2-dev libssl-dev libcurl4-openssl-dev

RUN mkdir -p /app
WORKDIR /app

COPY packrat ./packrat
COPY init.R ./
RUN Rscript init.R

COPY . .

CMD Rscript app.R
```

(no need to install Jetpack on the image)

Also, add `packrat/lib*/` to your `.dockerignore`.

### Heroku

There’s [ongoing work](https://github.com/virtualstaticvoid/heroku-buildpack-r/issues/110) to get Packrat working on Heroku.

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
jetpack add dplyr
jetpack add dplyr@0.7.5
jetpack add dplyr --remote=tidyverse/dplyr
jetpack update jsonlite
jetpack remove stringr
jetpack check
```

You can also use it to manage global packages

```sh
jetpack global add dplyr
jetpack global update jsonlite
jetpack global remove stringr
jetpack global list
```

Or get info about packages

```sh
jetpack info stringr
jetpack info stringr@1.0.0
jetpack search xgboost
jetpack search "neural network"
```

For the full list of commands, use:

```sh
jetpack help
```

## Upgrading

To upgrade, rerun the [installation instructions](#installation).

## History

View the [changelog](https://github.com/ankane/jetpack/blob/master/NEWS.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/jetpack/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/jetpack/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
