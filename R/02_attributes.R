# 02_attributes.R — Load illustrative three-attribute DCE specification
# finalized=FALSE for all rows. Not a clinically validated patient survey.

.source_setup <- function() {
  .args <- commandArgs(trailingOnly = FALSE)
  .file_arg <- grep("^--file=", .args, value = TRUE)
  if (length(.file_arg) == 1L) {
    this_file <- sub("^--file=", "", .file_arg)
    root <- normalizePath(file.path(dirname(this_file), ".."), mustWork = TRUE)
  } else if (exists("PROJECT_ROOT", inherits = TRUE)) {
    root <- get("PROJECT_ROOT", inherits = TRUE)
  } else if (basename(getwd()) == "R" && file.exists(file.path("..", "README.md"))) {
    root <- normalizePath("..", mustWork = TRUE)
  } else {
    root <- normalizePath(getwd(), mustWork = TRUE)
  }
  setup <- file.path(root, "R", "01_setup.R")
  if (!exists("REPRODUCIBLE_SEED", inherits = TRUE)) {
    source(setup, local = FALSE)
  }
  invisible(root)
}

PROJECT_ROOT <- .source_setup()
set.seed(REPRODUCIBLE_SEED)

ATTR_PATH <- file.path(PROJECT_ROOT, "config", "attributes.csv")
attrs <- utils::read.csv(ATTR_PATH, stringsAsFactors = FALSE, check.names = FALSE)

required_cols <- c("attribute", "level", "type", "coding", "clinical_rationale", "finalized")
missing_cols <- setdiff(required_cols, names(attrs))
if (length(missing_cols)) {
  stop("attributes.csv missing columns: ", paste(missing_cols, collapse = ", "), call. = FALSE)
}
if (nrow(attrs) < 1L) {
  stop("attributes.csv has no level rows.", call. = FALSE)
}

attrs$finalized <- as.logical(attrs$finalized)
if (any(is.na(attrs$finalized))) {
  stop("attributes.csv finalized column must be TRUE/FALSE.", call. = FALSE)
}
if (any(attrs$finalized)) {
  warning("One or more attributes marked finalized=TRUE; demo attributes should remain FALSE until PI lock.")
}

ATTR_ORDER <- c("administration", "frequency", "cost")
if (!identical(sort(unique(attrs$attribute)), sort(ATTR_ORDER))) {
  stop("Expected attributes: ", paste(ATTR_ORDER, collapse = ", "), call. = FALSE)
}

levels_by_attr <- lapply(ATTR_ORDER, function(a) attrs$level[attrs$attribute == a])
names(levels_by_attr) <- ATTR_ORDER

N_LEVELS <- vapply(levels_by_attr, length, integer(1))
CODING <- rep("D", length(ATTR_ORDER)) # dummy / treatment coding; first level = reference

# Clinical plausibility of administration × frequency (cost independent).
# TRUE = clinically acceptable for a real patient-facing instrument under current PrEP products.
clinically_ok_admin_freq <- function(administration, frequency) {
  ok <- (administration == "Oral" & frequency == "Daily") |
    (administration == "Injection" & frequency %in% c("Monthly", "Every 6 months"))
  as.logical(ok)
}

profile_grid <- expand.grid(
  administration = levels_by_attr$administration,
  frequency = levels_by_attr$frequency,
  cost = levels_by_attr$cost,
  stringsAsFactors = FALSE,
  KEEP.OUT.ATTRS = FALSE
)
profile_grid$profile_id <- seq_len(nrow(profile_grid))
profile_grid$clinically_plausible <- clinically_ok_admin_freq(
  profile_grid$administration,
  profile_grid$frequency
)

n_unrestricted <- nrow(profile_grid)
n_plausible <- sum(profile_grid$clinically_plausible)

message("Loaded ", nrow(attrs), " attribute levels from ", ATTR_PATH)
message("Attributes (order): ", paste(ATTR_ORDER, collapse = " | "))
message("Levels: ", paste(sprintf("%s=%d", ATTR_ORDER, N_LEVELS), collapse = ", "))
message(
  "Unrestricted profiles: ", n_unrestricted,
  "; clinically plausible (admin×freq×cost): ", n_plausible
)
message("All finalized flags FALSE: ", all(!attrs$finalized))

# Objects for downstream scripts
ATTR_LEVELS <- levels_by_attr
PROFILE_GRID <- profile_grid
CLINICAL_OK <- clinically_ok_admin_freq
