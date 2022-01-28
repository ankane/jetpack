contains <- function(str, x) {
  grepl(x, str, fixed=TRUE)
}

readFile <- function(file) {
  paste(readLines(file), collapse="")
}

expectContains <- function(name, str) {
  expect(contains(name, str), paste(name, "does not contain", str))
}

refuteContains <- function(name, str) {
  expect(!contains(name, str), paste(name, "contains", str))
}

expectFile <- function(name) {
  expect(file.exists(name), paste(name, "does not exist"))
}

expectFileContains <- function(name, str) {
  expectContains(readFile(name), str)
}

refuteFileContains <- function(name, str) {
  refuteContains(readFile(name), str)
}
