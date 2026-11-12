# 04_evaluate_design.R — Diagnostics, HTML survey export, design report
# No patient findings, coefficients, or preference weights are invented.

if (!exists("DESIGN_DF", inherits = TRUE)) {
  source(file.path(
    if (exists("PROJECT_ROOT", inherits = TRUE)) get("PROJECT_ROOT") else ".",
    "R", "03_design.R"
  ), local = FALSE)
}

set.seed(REPRODUCIBLE_SEED)

out_diag <- file.path(PROJECT_ROOT, "outputs", "diagnostics")
out_root <- file.path(PROJECT_ROOT, "outputs")
dir.create(out_diag, recursive = TRUE, showWarnings = FALSE)

# ---------- Helper: dummy-coded main-effects design matrix for clogit differences ----------
# Reference levels: Oral, Daily, $0 (first level of each attribute)
code_row <- function(administration, frequency, cost) {
  c(
    admin_Injection = as.numeric(administration == "Injection"),
    freq_Monthly = as.numeric(frequency == "Monthly"),
    freq_Every6mo = as.numeric(frequency == "Every 6 months"),
    cost_30 = as.numeric(cost == "$30")
  )
}

X <- t(mapply(
  code_row,
  DESIGN_DF$administration,
  DESIGN_DF$frequency,
  DESIGN_DF$cost,
  SIMPLIFY = TRUE
))
rownames(X) <- paste0("set", DESIGN_DF$choice_set_id, "_", DESIGN_DF$alternative_id)
colnames(X) <- c("admin_Injection", "freq_Monthly", "freq_Every6mo", "cost_30")

# Within-choice-set differences (A - B), clogit-relevant
diff_list <- lapply(sort(unique(DESIGN_DF$choice_set_id)), function(s) {
  rows <- DESIGN_DF$choice_set_id == s
  xa <- X[DESIGN_DF$choice_set_id == s & DESIGN_DF$alternative_id == "A", , drop = FALSE]
  xb <- X[DESIGN_DF$choice_set_id == s & DESIGN_DF$alternative_id == "B", , drop = FALSE]
  as.numeric(xa - xb)
})
D <- do.call(rbind, diff_list)
colnames(D) <- colnames(X)
rownames(D) <- paste0("set", sort(unique(DESIGN_DF$choice_set_id)))

rank_D <- qr(D)$rank
rank_X <- qr(X)$rank
n_params <- ncol(X)
estimable <- rank_D >= n_params

# Attribute correlations on within-set differences
cor_D <- stats::cor(D)
cor_D[!is.finite(cor_D)] <- NA_real_

# Level balance across 20 alternatives
balance_admin <- table(factor(DESIGN_DF$administration, levels = ATTR_LEVELS$administration))
balance_freq <- table(factor(DESIGN_DF$frequency, levels = ATTR_LEVELS$frequency))
balance_cost <- table(factor(DESIGN_DF$cost, levels = ATTR_LEVELS$cost))

# Identical alternatives within a set
identical_alts <- vapply(sort(unique(DESIGN_DF$choice_set_id)), function(s) {
  sub <- DESIGN_DF[DESIGN_DF$choice_set_id == s, c("administration", "frequency", "cost")]
  identical(as.list(sub[1, ]), as.list(sub[2, ]))
}, logical(1))

# Duplicate / reversed sets
set_key <- function(df) {
  vapply(sort(unique(df$choice_set_id)), function(s) {
    sub <- df[df$choice_set_id == s, c("administration", "frequency", "cost", "alternative_id")]
    a <- paste(unlist(sub[sub$alternative_id == "A", 1:3]), collapse = "|")
    b <- paste(unlist(sub[sub$alternative_id == "B", 1:3]), collapse = "|")
    paste(sort(c(a, b)), collapse = "||") # order-invariant key (treats reverse as duplicate)
  }, character(1))
}
keys <- set_key(DESIGN_DF)
n_duplicate_or_reversed <- length(keys) - length(unique(keys))

# Dominance under stated illustrative prefs (NOT estimated from patients):
# Assume (for QC only): prefer Oral > Injection; Daily > Monthly > Every 6 months; $0 > $30
# Dominance if one alt is weakly better on all attributes and strictly better on ≥1.
pref_rank <- list(
  administration = c(Oral = 2, Injection = 1),
  frequency = c(Daily = 3, Monthly = 2, `Every 6 months` = 1),
  cost = c(`$0` = 2, `$30` = 1)
)
dominates <- function(row_a, row_b) {
  scores_a <- c(
    pref_rank$administration[[row_a$administration]],
    pref_rank$frequency[[row_a$frequency]],
    pref_rank$cost[[row_a$cost]]
  )
  scores_b <- c(
    pref_rank$administration[[row_b$administration]],
    pref_rank$frequency[[row_b$frequency]],
    pref_rank$cost[[row_b$cost]]
  )
  all(scores_a >= scores_b) && any(scores_a > scores_b)
}
dominance_flags <- vapply(sort(unique(DESIGN_DF$choice_set_id)), function(s) {
  sub <- DESIGN_DF[DESIGN_DF$choice_set_id == s, ]
  a <- sub[sub$alternative_id == "A", ]
  b <- sub[sub$alternative_id == "B", ]
  dominates(a, b) || dominates(b, a)
}, logical(1))

n_clinical_invalid_alts <- sum(!DESIGN_DF$clinically_plausible)
n_sets_with_invalid <- sum(vapply(sort(unique(DESIGN_DF$choice_set_id)), function(s) {
  any(!DESIGN_DF$clinically_plausible[DESIGN_DF$choice_set_id == s])
}, logical(1)))

# Efficiency metrics from idefix
db_eff <- unname(MODFED_OUT$BestDesign$DB.error)
ab_eff <- unname(MODFED_OUT$BestDesign$AB.error)
orthog <- unname(MODFED_OUT$BestDesign$Orthogonality)

# EvaluateDesign may return list with D-error etc.
extract_err <- function(ev, name_candidates) {
  if (is.null(ev)) return(NA_real_)
  if (is.numeric(ev) && length(ev) == 1L) return(unname(ev))
  nms <- names(ev)
  for (nm in name_candidates) {
    if (!is.null(nms) && nm %in% nms) return(unname(ev[[nm]][1]))
  }
  # try common fields
  for (nm in c("DB.error", "D.error", "error", "AB.error")) {
    if (!is.null(ev[[nm]])) return(unname(ev[[nm]][1]))
  }
  NA_real_
}

random_db <- if (!is.null(RANDOM_EVAL$DB.error)) unname(RANDOM_EVAL$DB.error[1]) else extract_err(RANDOM_EVAL, c("DB.error"))
best_db_eval <- if (!is.null(BEST_EVAL$DB.error)) unname(BEST_EVAL$DB.error[1]) else db_eff

# ---------- Diagnostics CSV (long key-value + balance rows) ----------
diag_rows <- list(
  data.frame(metric = "design_label", value = "unrestricted_mathematical_demo", detail = "NOT clinically validated patient survey", stringsAsFactors = FALSE),
  data.frame(metric = "seed", value = as.character(REPRODUCIBLE_SEED), detail = "REPRODUCIBLE_SEED", stringsAsFactors = FALSE),
  data.frame(metric = "n_choice_sets", value = "10", detail = "", stringsAsFactors = FALSE),
  data.frame(metric = "n_alternatives_per_set", value = "2", detail = "", stringsAsFactors = FALSE),
  data.frame(metric = "n_main_effect_params", value = as.character(n_params), detail = "admin1 + freq2 + cost1", stringsAsFactors = FALSE),
  data.frame(metric = "rank_profile_matrix_X", value = as.character(rank_X), detail = "20x4 coded profiles", stringsAsFactors = FALSE),
  data.frame(metric = "rank_difference_matrix_D", value = as.character(rank_D), detail = "10x4 within-set A-B differences", stringsAsFactors = FALSE),
  data.frame(metric = "main_effects_estimable", value = as.character(estimable), detail = "rank(D) >= 4 under unrestricted coding", stringsAsFactors = FALSE),
  data.frame(metric = "DB_error_modfed", value = sprintf("%.6f", db_eff), detail = "zero-prior local D(B); lower is better; not global optimality claim", stringsAsFactors = FALSE),
  data.frame(metric = "AB_error_modfed", value = sprintf("%.6f", ab_eff), detail = "zero-prior", stringsAsFactors = FALSE),
  data.frame(metric = "orthogonality_modfed", value = sprintf("%.6f", orthog), detail = "idefix Orthogonality", stringsAsFactors = FALSE),
  data.frame(metric = "DB_error_random_comparison", value = sprintf("%.6f", random_db), detail = "same coding/zero prior; comparison only", stringsAsFactors = FALSE),
  data.frame(metric = "n_identical_alt_sets", value = as.character(sum(identical_alts)), detail = "", stringsAsFactors = FALSE),
  data.frame(metric = "n_duplicate_or_reversed_sets", value = as.character(n_duplicate_or_reversed), detail = "order-invariant set signature", stringsAsFactors = FALSE),
  data.frame(metric = "n_dominated_sets_under_stated_prefs", value = as.character(sum(dominance_flags)), detail = "illustrative prefs Oral>Injection; Daily>Monthly>Every6mo; $0>$30 — NOT patient data", stringsAsFactors = FALSE),
  data.frame(metric = "n_clinically_implausible_alternatives", value = as.character(n_clinical_invalid_alts), detail = "of 20 unrestricted alternatives", stringsAsFactors = FALSE),
  data.frame(metric = "n_sets_with_any_implausible_alt", value = as.character(n_sets_with_invalid), detail = "", stringsAsFactors = FALSE)
)

# Balance rows
for (nm in names(balance_admin)) {
  diag_rows[[length(diag_rows) + 1L]] <- data.frame(
    metric = "level_balance_administration", value = as.character(as.integer(balance_admin[[nm]])),
    detail = nm, stringsAsFactors = FALSE
  )
}
for (nm in names(balance_freq)) {
  diag_rows[[length(diag_rows) + 1L]] <- data.frame(
    metric = "level_balance_frequency", value = as.character(as.integer(balance_freq[[nm]])),
    detail = nm, stringsAsFactors = FALSE
  )
}
for (nm in names(balance_cost)) {
  diag_rows[[length(diag_rows) + 1L]] <- data.frame(
    metric = "level_balance_cost", value = as.character(as.integer(balance_cost[[nm]])),
    detail = nm, stringsAsFactors = FALSE
  )
}

# Correlation rows (upper triangle)
cn <- colnames(cor_D)
for (i in seq_len(ncol(cor_D))) {
  for (j in seq_len(ncol(cor_D))) {
    if (j <= i) next
    diag_rows[[length(diag_rows) + 1L]] <- data.frame(
      metric = "diff_attr_correlation",
      value = sprintf("%.4f", cor_D[i, j]),
      detail = paste(cn[i], "vs", cn[j]),
      stringsAsFactors = FALSE
    )
  }
}

diagnostics_df <- do.call(rbind, diag_rows)
utils::write.csv(diagnostics_df, file.path(out_diag, "prep_dce_diagnostics.csv"), row.names = FALSE)
utils::write.csv(diagnostics_df, file.path(out_root, "prep_dce_diagnostics.csv"), row.names = FALSE)

# Also save difference matrix and correlations
utils::write.csv(D, file.path(out_diag, "difference_matrix.csv"), row.names = TRUE)
utils::write.csv(cor_D, file.path(out_diag, "difference_correlations.csv"), row.names = TRUE)

# ---------- HTML survey (static, selectable A/B, no backend) ----------
esc <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  x <- gsub(">", "&gt;", x, fixed = TRUE)
  x <- gsub('"', "&quot;", x, fixed = TRUE)
  x
}

html_parts <- c(
  "<!DOCTYPE html>",
  "<html lang=\"en\">",
  "<head>",
  "<meta charset=\"utf-8\"/>",
  "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>",
  "<title>PrEP DCE Mathematical Demo (NOT a clinical survey)</title>",
  "<style>",
  "body{font-family:Georgia,serif;max-width:880px;margin:2rem auto;padding:0 1rem;line-height:1.45;color:#1a1a1a;background:#f7f4ef;}",
  "h1{font-size:1.6rem;margin-bottom:0.25rem;}",
  ".banner{background:#5c1a1a;color:#fff;padding:0.75rem 1rem;border-radius:4px;margin:1rem 0 1.5rem;}",
  ".banner strong{display:block;font-size:1.05rem;}",
  ".q{margin:1.5rem 0;padding:1rem;border:1px solid #cfc7b8;background:#fff;}",
  "table{width:100%;border-collapse:collapse;margin:0.75rem 0;}",
  "th,td{border:1px solid #bbb;padding:0.5rem 0.65rem;text-align:left;}",
  "th{background:#eee8dc;}",
  "label.choice{display:inline-block;margin-right:1.25rem;cursor:pointer;}",
  ".note{font-size:0.9rem;color:#444;}",
  "</style>",
  "</head>",
  "<body>",
  "<h1>ED PrEP Discrete Choice Experiment — Mathematical Demo</h1>",
  "<div class=\"banner\"><strong>NOT a clinically validated patient survey.</strong>",
  "This instrument uses an <em>unrestricted mathematical design</em> that may include clinically implausible PrEP combinations ",
  "(e.g., oral every 6 months; injectable daily). It demonstrates DCE design principles only. ",
  "Do not administer to patients. No preference weights or patient findings are implied.</div>",
  "<p class=\"note\">Illustrative attributes: administration method, medication frequency, out-of-pocket cost. ",
  "Select Alternative A or B for each question. Responses are not stored (no backend).</p>"
)

for (s in sort(unique(DESIGN_DF$choice_set_id))) {
  sub <- DESIGN_DF[DESIGN_DF$choice_set_id == s, ]
  a <- sub[sub$alternative_id == "A", ][1, ]
  b <- sub[sub$alternative_id == "B", ][1, ]
  flag_a <- if (!a$clinically_plausible) " <em>(clinically implausible combo)</em>" else ""
  flag_b <- if (!b$clinically_plausible) " <em>(clinically implausible combo)</em>" else ""
  html_parts <- c(
    html_parts,
    sprintf("<div class=\"q\" id=\"q%d\">", s),
    sprintf("<h2>Question %d of 10</h2>", s),
    "<p>If these were the only two PrEP options, which would you prefer?</p>",
    "<table>",
    "<thead><tr><th>Attribute</th><th>Alternative A</th><th>Alternative B</th></tr></thead>",
    "<tbody>",
    sprintf("<tr><td>Administration method</td><td>%s%s</td><td>%s%s</td></tr>",
            esc(a$administration), flag_a, esc(b$administration), flag_b),
    sprintf("<tr><td>Medication frequency</td><td>%s</td><td>%s</td></tr>",
            esc(a$frequency), esc(b$frequency)),
    sprintf("<tr><td>Out-of-pocket cost</td><td>%s</td><td>%s</td></tr>",
            esc(a$cost), esc(b$cost)),
    "</tbody></table>",
    sprintf("<label class=\"choice\"><input type=\"radio\" name=\"q%d\" value=\"A\"/> Alternative A</label>", s),
    sprintf("<label class=\"choice\"><input type=\"radio\" name=\"q%d\" value=\"B\"/> Alternative B</label>", s),
    "</div>"
  )
}

html_parts <- c(
  html_parts,
  "<p class=\"note\">End of mathematical demo. Seed ", REPRODUCIBLE_SEED,
  ". Generated with idefix Modfed (zero-prior D-efficiency). No data are submitted.</p>",
  "</body></html>"
)

html_path <- file.path(out_root, "prep_dce_survey.html")
writeLines(html_parts, html_path, useBytes = TRUE)

# ---------- Design report ----------
cor_txt <- paste(
  apply(which(upper.tri(cor_D), arr.ind = TRUE), 1, function(ij) {
    sprintf("%s vs %s: %.3f", cn[ij[1]], cn[ij[2]], cor_D[ij[1], ij[2]])
  }),
  collapse = "; "
)

report <- c(
  "# PrEP DCE Design Report — Three-Attribute Mathematical Demo",
  "",
  "**Label:** Unrestricted mathematical / illustrative design. **Not** a clinically validated patient survey.",
  "**Seed:** `20251112`. **No patient data, findings, or preference weights.**",
  "",
  "## 1. How the 10 choice sets were selected",
  "",
  paste0(
    "Candidate profiles were the full factorial of 2×3×2 = 12 unrestricted profiles ",
    "(administration × frequency × cost), coded with dummy (treatment) coding and reference levels ",
    "Oral / Daily / $0 (4 main-effect parameters)."
  ),
  "",
  paste0(
    "An efficient design with 10 choice sets × 2 alternatives was generated using `idefix::Modfed` ",
    "(modified Fedorov / coordinate-exchange style swap search) minimizing the **local D-error** ",
    "under a **zero prior** (`par.draws = 0` for all 4 parameters). ",
    sprintf("Search used n.start = %d random starts, max.iter = %d, parallel = FALSE, optim = \"D\". ", N_START, MAX_ITER),
    "Among starts, the pipeline **prefers the lowest DB-error design with zero duplicate/reversed choice sets** when available ",
    "(hygiene over a marginally lower D-error with repeated sets). ",
    "**This is not a claim of global optimality** across all algorithms, priors, or constrained candidate sets."
  ),
  "",
  if (exists("DESIGN_SELECTION_NOTE", inherits = TRUE)) {
    paste0("Selection note: ", DESIGN_SELECTION_NOTE)
  } else if (!is.null(MODFED_OUT$SelectionNote)) {
    paste0("Selection note: ", MODFED_OUT$SelectionNote)
  } else {
    "Selection note: Modfed BestDesign used as-is."
  },
  "",
  sprintf(
    "Selected design summary: DB.error = %.6f; AB.error = %.6f; Orthogonality = %.6f; infinite-error draws = %.0f%%.",
    db_eff, ab_eff, orthog, MODFED_OUT$BestDesign$inf.error
  ),
  "",
  "## 2. Clinical plausibility and confounding",
  "",
  "Administration method and medication frequency **cannot vary independently** while remaining clinically plausible with current PrEP products:",
  "",
  "| Administration | Frequency | Plausible? | Rationale |",
  "|---|---|---|---|",
  "| Oral | Daily | Yes | Standard oral PrEP (e.g., TDF/FTC, TAF/FTC) |",
  "| Oral | Monthly | No / problematic | No standard monthly oral HIV PrEP regimen as a labeled product schedule |",
  "| Oral | Every 6 months | No | Oral pills are not dosed every 6 months |",
  "| Injection | Daily | No | Injectables are not administered daily |",
  "| Injection | Monthly | Yes | Cabotegravir-like long-acting injectable |",
  "| Injection | Every 6 months | Yes | Lenacapavir-like twice-yearly injectable |",
  "",
  paste0(
    "Of ", nrow(PROFILE_GRID), " unrestricted profiles, ",
    sum(PROFILE_GRID$clinically_plausible),
    " are clinically plausible (cost varies freely). ",
    "In the generated unrestricted design, ",
    n_clinical_invalid_alts, " of 20 alternatives are clinically implausible; ",
    n_sets_with_invalid, " of 10 sets contain at least one implausible alternative. ",
    "These combinations were **not** manufactured as recommended survey content; they appear because the demo uses an unrestricted candidate set to illustrate design mathematics."
  ),
  "",
  "### Constrained-design identifiability",
  "",
  paste0(
    "If only clinically plausible profiles are allowed, administration and frequency travel together as **regimens** ",
    "(Oral+Daily; Injection+Monthly; Injection+Every 6 months). ",
    "Separate main effects for administration and frequency are then **not independently estimable** from choice data: ",
    "contrasts that would isolate admin from frequency require implausible cells."
  ),
  "",
  "### Proposed combined attribute (not silently adopted)",
  "",
  "For a patient-facing instrument, **propose** replacing separate administration + frequency with a single **PrEP regimen** attribute, e.g.:",
  "",
  "1. Oral, daily",
  "2. Injectable, monthly (cabotegravir-like)",
  "3. Injectable, every 6 months (lenacapavir-like)",
  "",
  "plus cost ($0, $30) or a richer insurance/reimbursement attribute from the protocol.",
  "",
  "**What is no longer separately estimable:** the independent main effects of administration method vs medication frequency (and their interaction as separable constructs). ",
  "What remains estimable: relative preferences among clinically real regimens, and cost (or insurance) effects conditional on regimen.",
  "",
  "**Decision needed (PI / clinical / statistician):** adopt combined regimen attribute vs keep separate attributes with explicit constraints and accept confounding.",
  "",
  "## 3. Are effects independently estimable in this unrestricted demo?",
  "",
  sprintf(
    "Under the unrestricted dummy-coded main-effects model, the within-choice-set difference matrix D is %d×%d with rank **%d**. ",
    nrow(D), ncol(D), rank_D
  ),
  sprintf(
    "Main effects are mathematically estimable in this demo: rank(D) %s 4 (`%s`). ",
    if (estimable) ">=" else "<", as.character(estimable)
  ),
  "**Caveat:** estimability here is algebraic under unrestricted profiles; it does **not** imply clinical validity or that the same parameters remain identifiable after imposing clinical constraints.",
  "",
  "## 4. Remaining confounding / correlations",
  "",
  paste0("Correlations among within-set attribute differences (clogit-relevant): ", cor_txt, "."),
  "",
  "Even when rank is full, nonzero correlations among difference columns imply partial confounding / shared information across attributes; precision will be uneven. Under clinical constraints these correlations become structural (admin↔frequency).",
  "",
  "## 5. Level balance (20 alternatives)",
  "",
  paste0("- Administration: ", paste(sprintf("%s=%d", names(balance_admin), as.integer(balance_admin)), collapse = ", ")),
  paste0("- Frequency: ", paste(sprintf("%s=%d", names(balance_freq), as.integer(balance_freq)), collapse = ", ")),
  paste0("- Cost: ", paste(sprintf("%s=%d", names(balance_cost), as.integer(balance_cost)), collapse = ", ")),
  "",
  "## 6. Design hygiene checks",
  "",
  sprintf("- Identical alternatives within a set: **%d**", sum(identical_alts)),
  sprintf("- Duplicate or reversed choice sets: **%d**", n_duplicate_or_reversed),
  sprintf(
    "- Dominated sets under stated illustrative prefs (Oral>Injection; Daily>Monthly>Every 6 months; $0>$30): **%d** — these prefs are QC assumptions only, **not** patient results",
    sum(dominance_flags)
  ),
  sprintf("- Clinically implausible alternatives: **%d** / 20", n_clinical_invalid_alts),
  "",
  "## 7. Comparison vs random design",
  "",
  sprintf(
    "A random 10×2 design was drawn from the same unrestricted candidate set (seed %d+1) and evaluated under the same zero prior.",
    REPRODUCIBLE_SEED
  ),
  sprintf("- Modfed DB.error: **%.6f**", db_eff),
  sprintf("- Random DB.error: **%.6f**", random_db),
  paste0(
    if (is.finite(db_eff) && is.finite(random_db) && db_eff < random_db) {
      "Modfed achieved a lower DB-error than this random draw under identical assumptions (better by this criterion)."
    } else if (is.finite(db_eff) && is.finite(random_db)) {
      "Under this single random comparator, Modfed DB-error was not lower; interpret cautiously (one random draw; zero prior)."
    } else {
      "Random comparison DB-error could not be fully extracted; see diagnostics CSV and RDS objects."
    }
  ),
  "",
  "This comparison is valid only as a same-assumption check; it is not a proof of optimality.",
  "",
  "## 8. Decisions still needed before a real patient survey",
  "",
  "1. PI/clinical lock on attribute list (protocol candidates vs demo stand-ins).",
  "2. Adopt **combined PrEP regimen** attribute vs constrained separate admin/frequency (statistician review of estimability).",
  "3. Replace illustrative cost with protocol insurance/reimbursement levels as appropriate.",
  "4. Priors: keep zero-prior D-efficiency vs Bayesian D-efficiency with informed priors from mixed methods / literature.",
  "5. Dominance and implausible-profile rules for the patient-facing instrument.",
  "6. eIRB amendment after mixed methods before any patient administration.",
  "7. REDCap implementation, consent language, and pilot testing.",
  "",
  "## 9. Outputs",
  "",
  "- `outputs/prep_dce_design.csv`",
  "- `outputs/prep_dce_survey.html`",
  "- `outputs/prep_dce_diagnostics.csv`",
  "- `outputs/designs/prep_dce_design_objects.rds`",
  "- `docs/design_report.md` (this file)",
  "",
  "## 10. Limitations",
  "",
  "- Unrestricted design includes clinically invalid PrEP combinations.",
  "- Zero prior ignores likely preference directionality.",
  "- Main-effects-only; no interactions modeled.",
  "- Local D-efficiency search with finite random starts — not a global optimum guarantee.",
  "- Dominance check uses researcher-stated illustrative preferences, not data.",
  "- No patient responses analyzed; none exist in this repository."
)

report_path <- file.path(PROJECT_ROOT, "docs", "design_report.md")
writeLines(report, report_path)
writeLines(report, file.path(out_root, "design_report.md"))

message("Diagnostics written: ", file.path(out_root, "prep_dce_diagnostics.csv"))
message("Survey HTML written: ", html_path)
message("Design report written: ", report_path)
message("Rank(D)=", rank_D, " estimable=", estimable, " DB.error=", db_eff)
message("Balance admin: ", paste(balance_admin, collapse = ","))
message("Balance freq: ", paste(balance_freq, collapse = ","))
message("Balance cost: ", paste(balance_cost, collapse = ","))
message("Implausible alts: ", n_clinical_invalid_alts)
