# =============================================================================
# meps-highcost / R/config.R
# Verified panel map + data-contract constants for the M1 pipeline.
# Written by the preflight agent. Do not hand-edit HC numbers without
# re-verifying against meps.ahrq.gov and updating the "verified" comment date.
# Last verified: 2026-07-08
# =============================================================================

suppressPackageStartupMessages({
  # Explicit library() calls (not just requireNamespace/::) so that
  # renv::dependencies() / renv::snapshot() detect and pin every package
  # required by the data contract, including the GitHub-sourced MEPS pkg.
  library(survey)
  library(srvyr)
  library(haven)
  library(data.table)
  library(tidyverse)
  library(MEPS)
})

# -----------------------------------------------------------------------------
# 0. Project root / directory layout (data contract §1)
# -----------------------------------------------------------------------------
# Raw files are immutable under data/raw/<hc>/
# Derived frames live at data/derived/panel_<NN>.rds with an IDENTICAL schema
# across panels.
PROJECT_ROOT   <- normalizePath(
  file.path(dirname(sys.frame(1)$ofile %||% "."), ".."),
  mustWork = FALSE
)

`%||%` <- function(a, b) if (is.null(a) || is.na(a)) b else a

DIR_RAW      <- file.path("data", "raw")
DIR_DERIVED  <- file.path("data", "derived")
DIR_OUTPUTS  <- file.path("outputs")
DIR_PROTOCOL <- file.path("protocol")
DIR_DOCS     <- file.path("docs")

dir.create(DIR_RAW,      recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_DERIVED,  recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_OUTPUTS,  recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_PROTOCOL, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_DOCS,     recursive = TRUE, showWarnings = FALSE)

# -----------------------------------------------------------------------------
# 1. Canonical schema (data contract §2)
# -----------------------------------------------------------------------------
# Every data/derived/panel_<NN>.rds must expose exactly these non-feature
# columns, plus year-1 features prefixed f_*.
CANONICAL_COLUMNS <- c(
  "dupersid",        # person id
  "panel",           # MEPS panel number (21, 22, 23, 26, 27, ...)
  "year1",           # first survey year of the panel pair
  "year2",           # second survey year of the panel pair
  "totexp_y1",       # TOTEXPY1 - total expenditure, year 1 (benchmark feature)
  "totexp_y2",       # TOTEXPY2 - total expenditure, year 2 (target SOURCE only)
  "top_decile_y2",   # binary target: weighted 90th pct of totexp_y2, per panel
  "longwt",          # LONGWT - 2-year longitudinal person weight
  "varstr",          # VARSTR - variance stratum
  "varpsu"           # VARPSU - variance PSU
  # + f_* : all year-1 predictor features (prefix mandatory)
)

# -----------------------------------------------------------------------------
# 2. GOLDEN LEAKAGE RULE (data contract §3)
# -----------------------------------------------------------------------------
# Only f_* and design columns are model-eligible. Enforce programmatically
# wherever a feature matrix is assembled.
DESIGN_COLUMNS <- c("longwt", "varstr", "varpsu")

is_model_eligible <- function(colname) {
  grepl("^f_", colname) | colname %in% DESIGN_COLUMNS
}

assert_no_leakage <- function(colnames) {
  # Any column matching *_y2 (except the target top_decile_y2) is forbidden
  # downstream of feature assembly.
  y2_like <- grepl("_y2$", colnames, ignore.case = TRUE)
  forbidden <- colnames[y2_like & colnames != "top_decile_y2"]
  if (length(forbidden) > 0) {
    stop(
      "GOLDEN LEAKAGE RULE violated. Forbidden *_y2 column(s) in model matrix: ",
      paste(forbidden, collapse = ", ")
    )
  }
  invisible(TRUE)
}

# -----------------------------------------------------------------------------
# 3. Survey weight rule (data contract §4)
# -----------------------------------------------------------------------------
# Weight = LONGWT (2-year). NEVER the annual cross-sectional weight
# (PERWT##F / SAQWT##F). Design: survey/srvyr with ids=varpsu, strata=varstr,
# weights=longwt, nest=TRUE.
FORBIDDEN_WEIGHT_PATTERN <- "^(PERWT[0-9]{2}F|SAQWT[0-9]{2}F)$"

make_survey_design <- function(df) {
  # df must already carry canonical columns: longwt, varstr, varpsu
  srvyr::as_survey_design(
    df,
    ids     = varpsu,
    strata  = varstr,
    weights = longwt,
    nest    = TRUE
  )
}

# -----------------------------------------------------------------------------
# 4. Verified panel map (data contract §5)
# -----------------------------------------------------------------------------
# Two-year longitudinal panel files - the spine. Each carries both years'
# consolidated variables with Y1/Y2 suffixes, plus LONGWT/VARSTR/VARPSU.
#
# NOTE: HC-236 (Panel 23 FOUR-YEAR file, 2018-2021) must NEVER be used.
# Panel 23 = HC-217 (the TWO-year file, 2018-2019). This is enforced by
# PANEL_MAP simply never containing HC-236.
PANEL_MAP <- list(
  `21` = list(
    years          = c(2016L, 2017L),
    longitudinal   = "HC-202",
    fyc_y1         = "2016 FYC (bundled in HC-202 source round; use HC-201 vars where needed)",
    fyc_y2         = "HC-201",
    role           = "train"
  ),
  `22` = list(
    years          = c(2017L, 2018L),
    longitudinal   = "HC-210",
    fyc_y1         = "HC-201",
    fyc_y2         = "HC-209",
    role           = "train"
  ),
  `23` = list(
    years          = c(2018L, 2019L),
    longitudinal   = "HC-217",   # NOT HC-236 (that is the 4-yr file - forbidden)
    fyc_y1         = "HC-209",
    fyc_y2         = "HC-216",
    role           = "train"
  ),
  `26` = list(
    years          = c(2021L, 2022L),
    longitudinal   = "HC-244",
    fyc_y1         = "HC-233",
    fyc_y2         = "HC-243",
    role           = "validation"
  ),
  `27` = list(
    years          = c(2022L, 2023L),
    longitudinal   = "HC-252",
    fyc_y1         = "HC-243",
    fyc_y2         = "HC-251",
    role           = "validation"
  )
)

FORBIDDEN_FILES <- c(
  "HC-236"  # Panel 23 four-year file (2018-2021); LONGWT there is a 4-yr weight.
)

# -----------------------------------------------------------------------------
# 5. Event files (year-1 predictors + PQI secondary) - LOCKED against
#    meps.ahrq.gov on 2026-07-08 by the preflight agent.
# -----------------------------------------------------------------------------
# Naming convention observed across all confirmed years:
#   <base>A = Prescribed Medicines
#   <base>D = Hospital Inpatient Stays
#   <base>I = Appendix / CLNK (condition-event link) + RXLK file
# and the Medical Conditions file is a *separate* base HC number for most
# years (only loosely related to the event-file base number).
#
# EVENT_FILES[[as.character(year)]] = list(
#   conditions = "<HC medical conditions file>",
#   rx         = "<HC prescribed medicines event file, suffix A>",
#   inpatient  = "<HC hospital inpatient stays event file, suffix D>",
#   clnk       = "<HC condition-event link / appendix file, suffix I>"
# )
EVENT_FILES <- list(
  `2016` = list(conditions = "HC-190", rx = "HC-188A", inpatient = "HC-188D", clnk = "HC-188I"),
  `2017` = list(conditions = "HC-199", rx = "HC-197A", inpatient = "HC-197D", clnk = "HC-197I"),
  `2018` = list(conditions = "HC-207", rx = "HC-206A", inpatient = "HC-206D", clnk = "HC-206I"),
  `2019` = list(conditions = "HC-214", rx = "HC-213A", inpatient = "HC-213D", clnk = "HC-213I"),
  `2021` = list(conditions = "HC-231", rx = "HC-229A", inpatient = "HC-229D", clnk = "HC-229I"),
  `2022` = list(conditions = "HC-241", rx = "HC-239A", inpatient = "HC-239D", clnk = "HC-239I"),
  `2023` = list(conditions = "HC-249", rx = "HC-248A", inpatient = "HC-248D", clnk = "HC-248I")
)

# Known documentation quirk (non-blocking): AHRQ's site also serves an
# "HC-220I: Appendix to MEPS 2021 Event Files" page whose content matches
# HC-229I (same 2021 CLNK content, references HC-229A/D-H and Conditions
# file HC-231). HC-229I is used here as canonical because it follows the
# consistent <base>+I pattern shared by every other confirmed year. If a
# prep agent encounters a checksum mismatch or missing HC-229I download,
# fall back to HC-220I and log it — do not silently substitute without a note.
KNOWN_QUIRKS <- list(
  clnk_2021_dual_listing = "AHRQ serves both HC-229I and HC-220I for the 2021 CLNK/appendix file; content matches. HC-229I chosen as canonical (base-number pattern)."
)

# -----------------------------------------------------------------------------
# 6. Target definition (locked decisions, per docs/M1_MULTIAGENT_PLAN.md §0)
# -----------------------------------------------------------------------------
TOP_DECILE_THRESHOLD_RULE <- "weighted_90th_pct_totexp_y2_per_panel"
TOP_DECILE_QUANTILE       <- 0.90

# -----------------------------------------------------------------------------
# 7. Reproducibility (data contract §6)
# -----------------------------------------------------------------------------
# - Raw downloads must be checksummed (see R/checksum_raw.R, to be authored
#   by the prep agents) with manifests under data/raw/<hc>/CHECKSUMS.txt.
# - Packages pinned with renv (renv.lock at project root).
# - All scripts deterministic and re-runnable: no interactive prompts, no
#   wall-clock-dependent logic, explicit set.seed() wherever randomness
#   is used (e.g., CV folds in M2).

REQUIRED_PACKAGES <- c(
  "survey", "srvyr", "haven", "data.table", "tidyverse", "MEPS", "renv"
)

# -----------------------------------------------------------------------------
# 8. Fail-fast package check
# -----------------------------------------------------------------------------
.check_required_packages <- function(pkgs = REQUIRED_PACKAGES) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop(
      "Missing required package(s): ", paste(missing, collapse = ", "),
      ". Install before proceeding (see renv.lock)."
    )
  }
  invisible(TRUE)
}

.check_required_packages()

message("R/config.R loaded OK. Panels: ",
        paste(names(PANEL_MAP), collapse = ", "),
        " | R ", getRversion())
