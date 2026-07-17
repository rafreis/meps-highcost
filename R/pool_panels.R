# =============================================================================
# meps-highcost / R/pool_panels.R
# Pool agent: stack the 5 per-panel derived frames into one analysis frame,
# tagging train (P21/22/23) vs validation (P26/27).
#
# IMPORTANT SCHEMA CAVEAT (see docs/panel_variable_mapping.md data contract
# and R/config.R CANONICAL_COLUMNS): the prep scripts for panels 21/23/26
# emitted a curated ~50-column f_* feature set, while panels 22/27 emitted
# a near-raw passthrough of the full HC longitudinal file (819 and 708
# columns respectively, mostly lower-cased raw MEPS variable names WITHOUT
# the f_ prefix and WITHOUT harmonized naming). This violates the "IDENTICAL
# schema across panels" contract in R/config.R. Consequently:
#   - The CANONICAL columns (id/design/target: dupersid, panel, year1, year2,
#     totexp_y1, totexp_y2, top_decile_y2, longwt, varstr, varpsu) are present
#     and consistently named in all 5 panels and are pooled directly.
#   - The engineered f_* feature sets are NOT consistently named across
#     panels (e.g. panel 21 has f_hibp_dx, panel 22 has f_hibpdx - no
#     underscore, different token). True column-by-column feature alignment
#     across all 5 panels was NOT attempted here (out of scope for the pool
#     step) and is flagged in the issues list below / in the run log.
#   - The pooled frame therefore carries the full canonical spine + role tag
#     for every row, plus f_* columns unioned with an explicit per-panel
#     provenance so downstream modeling code can select a common subset or
#     handle per-panel feature sets deliberately, rather than silently
#     rbind-ing misaligned columns into look-alike names.
#
# Output: data/derived/pooled.rds
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(purrr)
  library(survey)
  library(srvyr)
  library(jsonlite)
})

source(file.path("R", "config.R"))

# MEPS panels routinely contain strata with a single sampled PSU (esp. in
# smaller / more recent panels). Use AHRQ's documented "adjust" convention
# for lonely PSUs rather than letting svymean() error out.
options(survey.lonely.psu = "adjust")

PANELS <- c("21", "22", "23", "26", "27")
ROLE_MAP <- c(`21` = "train", `22` = "train", `23` = "train",
              `26` = "validation", `27` = "validation")

DERIVED_DIR <- file.path("data", "derived")
OUT_PATH    <- file.path(DERIVED_DIR, "pooled.rds")

CANONICAL_SPINE <- c("dupersid", "panel", "year1", "year2",
                      "totexp_y1", "totexp_y2", "top_decile_y2",
                      "longwt", "varstr", "varpsu")

# AHRQ-published LONGWT population estimates, verified 2026-07-08 against each
# 2-year longitudinal file's own documentation (h202/h210/h217/h244/h252 .shtml).
# These are the weighted totals over the ALL5RDS==1 subset (persons present in
# all five rounds) -- the exact estimand AHRQ states LONGWT reproduces, e.g.
# HC-217: "LONGWT applied to the 13,044 cases where ALL5RDS=1 produces a
# weighted population estimate of 305.7 million." The full-file sum(LONGWT)
# legitimately EXCEEDS this (includes partial-period persons with positive
# LONGWT), so the check MUST subset ALL5RDS==1 before comparing.
# (Prior values 244-247M were unsourced/fabricated -- corrected here.)
EXPECTED_TOTALS <- c(`21` = 303.3e6, `22` = 304.9e6, `23` = 305.7e6,
                     `26` = 311.5e6, `27` = 316.7e6)
TOTALS_TOLERANCE <- 0.01  # published figures rounded to 0.1M; ~1% is ample

# -----------------------------------------------------------------------------
# 1. Load each panel, verify canonical spine, tag role, record schema notes
# -----------------------------------------------------------------------------
panel_frames <- list()
schema_report <- list()
per_panel_results <- list()

for (p in PANELS) {
  f <- file.path(DERIVED_DIR, paste0("panel_", p, ".rds"))
  stopifnot(file.exists(f))
  df <- readRDS(f)

  missing_spine <- setdiff(CANONICAL_SPINE, names(df))
  if (length(missing_spine) > 0) {
    stop("Panel ", p, " is missing canonical spine column(s): ",
         paste(missing_spine, collapse = ", "))
  }
  stopifnot(all(as.character(df$panel) == p | df$panel == as.integer(p)))
  stopifnot(!anyNA(df$top_decile_y2))
  stopifnot(!anyNA(df$longwt), !anyNA(df$varstr), !anyNA(df$varpsu))
  stopifnot(all(df$longwt >= 0))

  feat_cols <- grep("^f_", names(df), value = TRUE)
  non_spine_non_feat <- setdiff(names(df), c(CANONICAL_SPINE, feat_cols))

  df$role <- ROLE_MAP[[p]]

  schema_report[[p]] <- list(
    panel = p,
    role = ROLE_MAP[[p]],
    n_cols_total = ncol(df),
    n_feat_cols = length(feat_cols),
    n_unprefixed_extra_cols = length(non_spine_non_feat),
    unprefixed_extra_cols_sample = head(non_spine_non_feat, 10)
  )

  panel_frames[[p]] <- df
}

# -----------------------------------------------------------------------------
# 2. Per-panel design-based checks (base rate ~10%, thresholds, transition n)
#    Recomputed independently here (not copy-pasted from upstream target
#    scripts) so the pool step is a genuine check, not a rubber stamp.
# -----------------------------------------------------------------------------
issues <- character(0)

for (p in PANELS) {
  df  <- panel_frames[[p]]
  des <- make_survey_design(df)

  rate_tbl <- des %>% srvyr::summarise(rate = srvyr::survey_mean(top_decile_y2, vartype = NULL))
  weighted_base_rate <- as.numeric(rate_tbl$rate)

  n_top   <- sum(df$top_decile_y2 == 1L, na.rm = TRUE)
  n_rows  <- nrow(df)
  sum_wt  <- sum(df$longwt)

  threshold_approx <- suppressWarnings(min(df$totexp_y2[df$top_decile_y2 == 1L], na.rm = TRUE))

  if ("transition_eligible" %in% names(df)) {
    transition_n <- sum(df$transition_eligible == 1L, na.rm = TRUE)
  } else if ("top_decile_y1" %in% names(df)) {
    transition_n <- sum(df$top_decile_y1 == 0L, na.rm = TRUE)
  } else {
    q1  <- des %>% srvyr::summarise(q90 = srvyr::survey_quantile(totexp_y1, 0.90, vartype = NULL))
    thr1 <- as.numeric(q1[[grep("^q90", names(q1), value = TRUE)[1]]])
    transition_n <- sum(df$totexp_y1 < thr1, na.rm = TRUE)
  }

  design_ok <- weighted_base_rate >= 0.08 && weighted_base_rate <= 0.12

  # --- Assertion (a): weighted base rate ~10% in EACH panel ---
  if (!design_ok) {
    issues <- c(issues, sprintf(
      "Panel %s: weighted base rate %.4f%% falls OUTSIDE the [8%%, 12%%] design_ok band.",
      p, weighted_base_rate * 100))
  }

  # --- Assertion (b): weighted population total vs published AHRQ estimate ---
  # AHRQ documents the LONGWT estimate over the ALL5RDS==1 subset; reproduce
  # THAT estimand, not the full-file sum. Requires prep to retain 'all5rds'
  # as a non-feature admin column.
  expected <- EXPECTED_TOTALS[[p]]
  if ("all5rds" %in% names(df)) {
    sub          <- df[!is.na(df$all5rds) & df$all5rds == 1L, ]
    sum_wt_all5  <- sum(sub$longwt)
    n_all5       <- nrow(sub)
    pct_diff     <- (sum_wt_all5 - expected) / expected
    if (abs(pct_diff) > TOTALS_TOLERANCE) {
      issues <- c(issues, sprintf(
        paste0("Panel %s: ALL5RDS=1 weighted total (sum LONGWT = %s over n=%d) is %.2f%% from ",
               "the AHRQ-published estimate (%s) -- OUTSIDE +/-%.1f%%."),
        p, format(round(sum_wt_all5), big.mark = ","), n_all5, pct_diff * 100,
        format(expected, big.mark = ",", scientific = FALSE), TOTALS_TOLERANCE * 100))
    }
  } else {
    sum_wt_all5 <- NA_real_; n_all5 <- NA_integer_; pct_diff <- NA_real_
    issues <- c(issues, sprintf(
      paste0("Panel %s: cannot verify population total -- derived frame lacks 'all5rds'. Prep ",
             "must retain ALL5RDS (non-feature admin col) so the AHRQ ALL5RDS=1 benchmark (%s) ",
             "is reproducible."),
      p, format(expected, big.mark = ",", scientific = FALSE)))
  }

  per_panel_results[[p]] <- list(
    panel = p,
    role = ROLE_MAP[[p]],
    n_rows = n_rows,
    threshold = round(threshold_approx),
    weighted_base_rate = round(weighted_base_rate, 5),
    n_top = n_top,
    design_ok = design_ok,
    transition_n = transition_n,
    sum_longwt_full = sum_wt,
    sum_longwt_all5rds = sum_wt_all5,
    n_all5rds = n_all5,
    expected_population_total = expected,
    population_total_pct_diff = round(pct_diff * 100, 2)
  )
}

# -----------------------------------------------------------------------------
# 3. Build the pooled analysis frame: canonical spine + role, stacked.
#    f_* feature columns are NOT safely union-rbind-able across panels given
#    the schema drift documented above (panel 22/27 use unprefixed raw MEPS
#    names, not the f_-prefixed harmonized names used by 21/23/26), so the
#    pooled frame carries the canonical spine (model target + design columns)
#    for every row, which is what pooled base-rate / population-total
#    assertions require. Per-panel f_* columns remain available by loading
#    the individual panel_<NN>.rds files, keyed on dupersid+panel.
# -----------------------------------------------------------------------------
# Schema is now unified across panels (single R/prep_panel.R): pool the
# canonical spine + all5rds + the 62 f_* features for a ready M2 matrix.
FEAT <- grep("^f_", names(panel_frames[[1]]), value = TRUE)
stopifnot(length(FEAT) == 62L,
          all(vapply(panel_frames, function(d) setequal(grep("^f_", names(d), value=TRUE), FEAT), logical(1))))
pooled <- purrr::map_dfr(panel_frames, function(df) {
  df %>%
    dplyr::select(dplyr::all_of(c(CANONICAL_SPINE, "all5rds", FEAT)), role) %>%
    dplyr::mutate(panel = as.character(panel))
})

stopifnot(nrow(pooled) == sum(vapply(panel_frames, nrow, integer(1))))
stopifnot(all(pooled$role %in% c("train", "validation")))
stopifnot(setequal(unique(pooled$panel[pooled$role == "train"]), c("21","22","23")))
stopifnot(setequal(unique(pooled$panel[pooled$role == "validation"]), c("26","27")))

dir.create(DERIVED_DIR, recursive = TRUE, showWarnings = FALSE)
saveRDS(pooled, OUT_PATH)
message("Wrote ", OUT_PATH, " | n_rows = ", nrow(pooled), " | n_cols = ", ncol(pooled))

# -----------------------------------------------------------------------------
# 4. Schema-drift issue (always emitted - this is a real contract violation,
#    independent of the base-rate / population-total assertions above)
# -----------------------------------------------------------------------------
drift_cols <- vapply(schema_report, function(x) x$n_cols_total, integer(1))
if (length(unique(drift_cols)) > 1) {
  issues <- c(issues, sprintf(
    paste0("Schema drift across panels violates R/config.R's 'IDENTICAL schema across panels' ",
           "data contract: column counts are %s (panels %s respectively). Panels 22 and 27 carry ",
           "a near-raw passthrough of hundreds of unprefixed MEPS variables instead of the curated ",
           "f_-prefixed feature set used by panels 21/23/26. Pooled frame therefore includes only ",
           "the canonical spine + role tag; f_* features were NOT pooled across panels."),
    paste(drift_cols, collapse = ", "), paste(PANELS, collapse = ", ")))
}

# -----------------------------------------------------------------------------
# 5. Report
# -----------------------------------------------------------------------------
totals_match_published <- !any(grepl("weighted total|population total|ALL5RDS", issues))

result <- list(
  panels_pooled = PANELS,
  out_path = OUT_PATH,
  n_rows_pooled = nrow(pooled),
  per_panel = per_panel_results,
  schema_report = schema_report,
  totals_match_published = totals_match_published,
  issues = issues
)

writeLines(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE, na = "null"),
           file.path("outputs", "pool_audit_result.json"))
cat("\n--- RESULT (JSON) ---\n")
cat(jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE, na = "null"))
cat("\n")
