# Jetpack

:fire: A friendly package manager for R

- Easy to use
- Designed for reproducibility (thanks to [Packrat](https://rstudio.github.io/packrat/), no more global installs!)
- Great for collaboration
- Secure by default

![Screenshot](https://gist.githubusercontent.com/ankane/b6988db2802aca68a589b31e41b44195/raw/62d228452da6c0a54330de33c6068da23d271996/console.gif)

Inspired by [Yarn](https://yarnpkg.com/) and [Bundler](https://bundler.io/)

## Installing

Install the Jetpack CLI

```sh
install.packages("devtools")
devtools::install_github("ankane/jetpack")
jetpack::createbin()
```

## Getting Started

In your project directory, run:

```sh
jetpack init
```

This sets up Packrat and creates a `DESCRIPTION` file to store your dependencies.

If your project uses Git, `packrat/lib*/` is added to your `.gitignore`.

## Commands

### Install

Install packages for a project

```sh
jetpack install
```

Whenever a teammate adds a new package, others just need to run this command to keep packages in sync. Do the same when a new member joins the project.

`install` is optional.

### Add

Add a package

```sh
jetpack add dplyr
```

Add a specific version

```sh
jetpack add dplyr@0.7.5
```

Add from GitHub or another remote source

```sh
jetpack add dplyr --remote=github::tidyverse/dplyr
```

Supports [all of these remotes](https://cran.r-project.org/web/packages/devtools/vignettes/dependencies.html)

Add from a specific tag, branch, or commit

```sh
jetpack add dplyr --remote=github::tidyverse/dplyr@v0.7.5
```

Add from a local source

```sh
jetpack add dplyr --remote=local::/path/to/dplyr
```

> The local directory must have the same name as the package

### Update

Update a package

```sh
jetpack update dplyr
```

### Remove

Remove a package

```sh
jetpack remove dplyr
```

Remove remotes as well

```sh
jetpack remove dplyr --remote=github::tidyverse/dplyr
```

## Source Control

Be sure to commit all files Jetpack generates to source control, except for the `packrat/lib*/` directories.

## RStudio

Jetpack can also be used from within RStudio.

```R
jetpack.install()
jetpack.add("jsonlite")
```

## Deployment

### Server

Install Jetpack on the server and run: [master]

```sh
jetpack install --deployment
```

### Docker

Create an `init.R` with:

```R
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

## History

View the [changelog](https://github.com/ankane/jetpack/blob/master/NEWS.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/jetpack/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/jetpack/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
