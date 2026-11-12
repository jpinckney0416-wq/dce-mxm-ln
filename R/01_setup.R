# 01_setup.R — ED PrEP DCE environment bootstrap (Stage 1)
# Installs (if needed) and loads design packages; sets seed; prints session info.

.args <- commandArgs(trailingOnly = FALSE)
.file_arg <- grep("^--file=", .args, value = TRUE)
if (length(.file_arg) == 1L) {
  this_file <- sub("^--file=", "", .file_arg)
  PROJECT_ROOT <- normalizePath(file.path(dirname(this_file), ".."), mustWork = TRUE)
} else if (basename(getwd()) == "R" && file.exists(file.path("..", "README.md"))) {
  PROJECT_ROOT <- normalizePath("..", mustWork = TRUE)
} else {
  PROJECT_ROOT <- normalizePath(getwd(), mustWork = TRUE)
}

REPRODUCIBLE_SEED <- 20251112L
set.seed(REPRODUCIBLE_SEED)

cran <- getOption("repos")
if (is.null(cran) || identical(unname(cran["CRAN"]), "@CRAN@") || !nzchar(cran["CRAN"])) {
  options(repos = c(CRAN = "https://cloud.r-project.org"))
}

required_packages <- c("idefix")

ensure_packages <- function(pkgs) {
  for (pkg in pkgs) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      message("Installing missing package: ", pkg)
      install.packages(pkg, repos = getOption("repos"))
    }
    if (!requireNamespace(pkg, quietly = TRUE)) {
      stop("Failed to install or locate package: ", pkg, call. = FALSE)
    }
  }
  invisible(TRUE)
}

ensure_packages(required_packages)
library(idefix)

message("PROJECT_ROOT: ", PROJECT_ROOT)
message("REPRODUCIBLE_SEED: ", REPRODUCIBLE_SEED)
message("idefix version: ", as.character(utils::packageVersion("idefix")))
print(sessionInfo())
