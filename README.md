# Jetpack

:fire: A friendly package manager for R

Uses [Packrat](https://rstudio.github.io/packrat/) to manage dependencies

## Installing

Download the Jetpack CLI

```sh
curl https://raw.githubusercontent.com/ankane/jetpack/master/jetpack > /usr/local/bin/jetpack
chmod +x /usr/local/bin/jetpack
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
jetpack
```

### Add

Add a package

```sh
jetpack add dplyr
```

Add from GitHub or another remote source

```sh
jetpack add dplyr --remote=github::tidyverse/dplyr
```

Supports [all of these remotes](https://cran.r-project.org/web/packages/devtools/vignettes/dependencies.html)

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

## Deployment

Install Jetpack on your server and run:

```R
jetpack install
```

### Heroku

There’s [ongoing work](https://github.com/virtualstaticvoid/heroku-buildpack-r/issues/110) to get Packrat working on Heroku.

## History

View the [changelog](https://github.com/ankane/jetpack/blob/master/CHANGELOG.md)

## Contributing

Everyone is encouraged to help improve this project. Here are a few ways you can help:

- [Report bugs](https://github.com/ankane/jetpack/issues)
- Fix bugs and [submit pull requests](https://github.com/ankane/jetpack/pulls)
- Write, clarify, or fix documentation
- Suggest or add new features
