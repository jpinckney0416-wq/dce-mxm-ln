# 03_design.R — Generate unrestricted mathematical D-efficient demo design
# LABEL: Mathematical / illustrative design only. NOT a clinically validated patient survey.
# Uses zero-prior local D-efficiency via idefix::Modfed (main effects only).

if (!exists("ATTR_LEVELS", inherits = TRUE)) {
  source(file.path(
    if (exists("PROJECT_ROOT", inherits = TRUE)) PROJECT_ROOT else ".",
    "R", "02_attributes.R"
  ), local = FALSE)
}
if (!exists("PROJECT_ROOT", inherits = TRUE)) {
  source("R/02_attributes.R", local = FALSE)
}

set.seed(REPRODUCIBLE_SEED)

N_SETS <- 10L
N_ALTS <- 2L
N_START <- 48L
MAX_ITER <- 200L

cand.set <- Profiles(lvls = as.integer(N_LEVELS), coding = CODING)
# Main-effects parameter count under dummy coding: (2-1)+(3-1)+(2-1) = 4
stopifnot(ncol(cand.set) == sum(N_LEVELS - 1L))

# Zero prior (local D-efficient): no preference information assumed.
par.draws <- rep(0, ncol(cand.set))

lvl.names <- list(
  ATTR_LEVELS$administration,
  ATTR_LEVELS$frequency,
  ATTR_LEVELS$cost
)

# Count duplicate/reversed choice sets (order-invariant profile-pair signature).
count_dup_or_reversed <- function(coded, n.alts, lvl.names, coding) {
  dec <- Decode(des = coded, n.alts = n.alts, lvl.names = lvl.names, coding = coding)
  df <- as.data.frame(dec$design, stringsAsFactors = FALSE)
  names(df)[seq_len(min(3L, ncol(df)))] <- c("administration", "frequency", "cost")[seq_len(min(3L, ncol(df)))]
  rn <- rownames(coded)
  sid <- as.integer(sub("^set([0-9]+)\\.alt[0-9]+$", "\\1", rn))
  aid <- ifelse(grepl("alt1", rn), "A", "B")
  keys <- vapply(sort(unique(sid)), function(s) {
    rows <- which(sid == s)
    aa <- paste(unlist(df[rows[aid[rows] == "A"][1], 1:3]), collapse = "|")
    bb <- paste(unlist(df[rows[aid[rows] == "B"][1], 1:3]), collapse = "|")
    paste(sort(c(aa, bb)), collapse = "||")
  }, character(1))
  length(keys) - length(unique(keys))
}

message("Generating Modfed D-efficient design (unrestricted candidate set)...")
message("n.sets=", N_SETS, " n.alts=", N_ALTS, " n.start=", N_START, " seed=", REPRODUCIBLE_SEED)

modfed_out <- Modfed(
  cand.set = cand.set,
  n.sets = N_SETS,
  n.alts = N_ALTS,
  par.draws = par.draws,
  optim = "D",
  parallel = FALSE,
  n.start = N_START,
  max.iter = MAX_ITER
)

# Prefer lowest DB-error among starts with zero duplicate/reversed sets when possible.
candidate_slots <- list()
ad <- modfed_out$AllDesigns
db_vec <- ad$DB.error
for (i in seq_along(ad)) {
  x <- ad[[i]]
  if (!(is.list(x) && !is.null(x$design))) next
  db_i <- if (!is.null(x$DB.error)) {
    unname(x$DB.error[1])
  } else {
    unname(db_vec[paste0("des", i)])
  }
  n_dup <- count_dup_or_reversed(x$design, N_ALTS, lvl.names, CODING)
  candidate_slots[[length(candidate_slots) + 1L]] <- list(
    index = i, design = x$design, DB.error = db_i, n_dup = n_dup, raw = x
  )
}

dup_free <- Filter(function(z) isTRUE(z$n_dup == 0L), candidate_slots)
raw_best_db <- unname(modfed_out$BestDesign$DB.error)
if (length(dup_free)) {
  dbs <- vapply(dup_free, function(z) z$DB.error, numeric(1))
  pick <- dup_free[[which.min(dbs)]]
  selection_note <- sprintf(
    "Selected des%d among %d duplicate-free starts (DB.error=%.6f); raw Modfed BestDesign DB.error=%.6f had duplicates.",
    pick$index, length(dup_free), pick$DB.error, raw_best_db
  )
} else {
  dbs <- vapply(candidate_slots, function(z) z$DB.error + 0.01 * z$n_dup, numeric(1))
  pick <- candidate_slots[[which.min(dbs)]]
  selection_note <- sprintf(
    "No duplicate-free start found; selected des%d (DB.error=%.6f, n_dup=%d).",
    pick$index, pick$DB.error, pick$n_dup
  )
}
message(selection_note)

# Use selected coded design; keep Modfed BestDesign metadata but overwrite design/error for reporting.
best <- modfed_out$BestDesign
design_coded <- pick$design
best$design <- design_coded
best$DB.error <- pick$DB.error
best$selection_note <- selection_note
best$n_dup_or_reversed <- pick$n_dup
# Refresh EvaluateDesign-based fields for the selected design
sel_eval <- EvaluateDesign(des = design_coded, par.draws = par.draws, n.alts = N_ALTS)
if (!is.null(sel_eval$AB.error)) best$AB.error <- unname(sel_eval$AB.error[1])
if (!is.null(sel_eval$DB.error)) best$DB.error <- unname(sel_eval$DB.error[1])
if (!is.null(sel_eval$Orthogonality)) best$Orthogonality <- unname(sel_eval$Orthogonality[1])
if (!is.null(sel_eval$SD)) best$SD <- sel_eval$SD
if (!is.null(sel_eval$level.count)) best$level.count <- sel_eval$level.count
if (!is.null(sel_eval$level.overlap)) best$level.overlap <- sel_eval$level.overlap
modfed_out$BestDesign <- best
modfed_out$SelectionNote <- selection_note
DESIGN_SELECTION_NOTE <- selection_note

decoded <- Decode(
  des = design_coded,
  n.alts = N_ALTS,
  lvl.names = lvl.names,
  coding = CODING
)

design_char <- as.data.frame(decoded$design, stringsAsFactors = FALSE)
# Decode returns columns named after attributes in order; standardize names.
if (ncol(design_char) >= 3L) {
  names(design_char)[1:3] <- c("administration", "frequency", "cost")
}

# Build tidy 20-row design table
rn <- rownames(design_coded)
choice_set_id <- as.integer(sub("^set([0-9]+)\\.alt[0-9]+$", "\\1", rn))
alternative_id <- sub("^set[0-9]+\\.(alt[0-9]+)$", "\\1", rn)
alternative_id <- ifelse(grepl("alt1", alternative_id), "A",
                         ifelse(grepl("alt2", alternative_id), "B", alternative_id))

design_df <- data.frame(
  choice_set_id = choice_set_id,
  alternative_id = alternative_id,
  administration = design_char$administration,
  frequency = design_char$frequency,
  cost = design_char$cost,
  stringsAsFactors = FALSE
)
design_df$clinically_plausible <- CLINICAL_OK(design_df$administration, design_df$frequency)
design_df$design_label <- "unrestricted_mathematical_demo"

# --- Random comparison design under same assumptions (same seed stream after Modfed) ---
message("Generating random comparison design under same coding / zero prior...")
set.seed(REPRODUCIBLE_SEED + 1L)
rand_rows <- list()
for (s in seq_len(N_SETS)) {
  # Sample two distinct candidate profiles
  idx <- sample.int(nrow(cand.set), 2L, replace = FALSE)
  block <- cand.set[idx, , drop = FALSE]
  rownames(block) <- paste0("set", s, ".alt", 1:2)
  rand_rows[[s]] <- block
}
random_coded <- do.call(rbind, rand_rows)
random_decoded <- Decode(
  des = random_coded,
  n.alts = N_ALTS,
  lvl.names = lvl.names,
  coding = CODING
)
random_char <- as.data.frame(random_decoded$design, stringsAsFactors = FALSE)
names(random_char)[1:3] <- c("administration", "frequency", "cost")
rrn <- rownames(random_coded)
random_df <- data.frame(
  choice_set_id = as.integer(sub("^set([0-9]+)\\.alt[0-9]+$", "\\1", rrn)),
  alternative_id = ifelse(grepl("alt1", rrn), "A", "B"),
  administration = random_char$administration,
  frequency = random_char$frequency,
  cost = random_char$cost,
  stringsAsFactors = FALSE
)
random_df$clinically_plausible <- CLINICAL_OK(random_df$administration, random_df$frequency)
random_df$design_label <- "random_comparison"

# Efficiency of random design (same zero prior)
random_eval <- EvaluateDesign(des = random_coded, par.draws = par.draws, n.alts = N_ALTS)
best_eval <- EvaluateDesign(des = design_coded, par.draws = par.draws, n.alts = N_ALTS)

# Persist coded matrices and metadata for diagnostics
DESIGN_CODED <- design_coded
RANDOM_CODED <- random_coded
DESIGN_DF <- design_df
RANDOM_DF <- random_df
PAR_DRAWS <- par.draws
MODFED_OUT <- modfed_out
BEST_EVAL <- best_eval
RANDOM_EVAL <- random_eval
DECODED_LEVEL_COUNT <- decoded$level.count

out_design <- file.path(PROJECT_ROOT, "outputs", "designs")
dir.create(out_design, recursive = TRUE, showWarnings = FALSE)

utils::write.csv(
  design_df[, c("choice_set_id", "alternative_id", "administration", "frequency", "cost")],
  file.path(out_design, "prep_dce_design.csv"),
  row.names = FALSE
)
# Also place a copy at outputs/ root for the task's requested path
utils::write.csv(
  design_df[, c("choice_set_id", "alternative_id", "administration", "frequency", "cost")],
  file.path(PROJECT_ROOT, "outputs", "prep_dce_design.csv"),
  row.names = FALSE
)
utils::write.csv(random_df, file.path(out_design, "prep_dce_random_comparison.csv"), row.names = FALSE)
saveRDS(
  list(
    design_coded = design_coded,
    random_coded = random_coded,
    modfed = modfed_out,
    best_eval = best_eval,
    random_eval = random_eval,
    par.draws = par.draws,
    cand.set = cand.set,
    seed = REPRODUCIBLE_SEED
  ),
  file.path(out_design, "prep_dce_design_objects.rds")
)

message("Wrote ", file.path(PROJECT_ROOT, "outputs", "prep_dce_design.csv"))
message(
  "Modfed DB.error=", unname(best$DB.error),
  " AB.error=", unname(best$AB.error),
  " Orthogonality=", unname(best$Orthogonality)
)
message(
  "Clinically plausible alts in unrestricted design: ",
  sum(design_df$clinically_plausible), "/", nrow(design_df)
)
