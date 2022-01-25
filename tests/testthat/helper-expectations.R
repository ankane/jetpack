contains <- function(str, x) {
  grepl(x, str)
}

fileContains <- function(file, x) {
  contains(paste(readLines(file), collapse=""), x)
}

expectContains <- function(name, str) {
  expect(contains(name, str), paste(name, "does not contain", str))
}

expectFile <- function(name) {
  expect(file.exists(name), paste(name, "does not exist"))
}

expectFileContains <- function(name, str) {
  expect(fileContains(name, str), paste(name, "does not contain", str))
}

refuteFileContains <- function(name, str) {
  expect(!fileContains(name, str), paste(name, "contains", str))
}
