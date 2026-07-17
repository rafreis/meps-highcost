# =============================================================================
# meps-highcost / R/feature_contract.R
# THE canonical year-1 feature contract, locked 2026-07-08.
# Source = design-based selection (docs/Methods_Justification.md §5):
#   universe (Y1 intersection + round-1/2 allowlist + invariant, MINUS structural
#   exclusions) -> weighted filters -> Rao-Scott screen -> svyVarSel::wlasso dCV
#   (Iparragirre & Lumley 2023). wlasso selected 64; admin-ish f_wilfil and
#   f_famrfp pruned by decision -> 62 canonical features.
# Applied IDENTICALLY to all 5 panels by R/prep_panel.R.
# =============================================================================

CANONICAL_FEATURES <- c(
  # prior spend (year 1)
  "f_totexp", "f_totslf",
  # demographics / SES / geography
  "f_age", "f_sex", "f_racethx", "f_hispanx", "f_region", "f_ruclas",
  "f_marr", "f_marry", "f_famsze", "f_povcat", "f_povlev", "f_ttlp", "f_foodst",
  # insurance (year 1)
  "f_insc", "f_ins", "f_inscov", "f_insurc", "f_unins", "f_mcrev", "f_prvev",
  "f_prvhmo", "f_pmdins", "f_trich", "f_priog", "f_pring", "f_prstx", "f_pridk",
  # self-reported health (SAQ, rounds 1-2)
  "f_rthlth1", "f_rthlth2", "f_mnhlth2", "f_adgenh2", "f_addaya2",
  # functional limitation (round 1) + usual source of care (round 2)
  "f_actlim1", "f_wlklim1", "f_coglim1", "f_soclim1",
  "f_adlhlp1", "f_aidhlp1", "f_iadlhp1", "f_haveus2",
  # chronic condition dx (year 1)
  "f_hibpdx", "f_chddx", "f_ohrtdx", "f_midx", "f_strkdx",
  "f_emphdx", "f_asthdx", "f_arthdx", "f_cancer",
  # utilization counts (year 1)
  "f_obtotv", "f_obdrv", "f_optotv", "f_opdrv", "f_ertot",
  "f_ipdis", "f_ipngtd", "f_rxtot", "f_dvtot", "f_hhtotd", "f_hhagd"
)
stopifnot(length(CANONICAL_FEATURES) == 62L, !anyDuplicated(CANONICAL_FEATURES))

# Resolve a canonical f_<name> to the raw source column for a given panel.
# Inverts the naming rule f_<x> = f_ + tolower(strip trailing Y1/Y1X). The
# candidate universe was the INTERSECTION across all 5 panels, so every
# canonical feature has exactly one source column present in every panel.
# Year-2 siblings (…Y2 / …Y2X) are explicitly excluded (leakage guard).
resolve_feature <- function(canon, raw_names_upper) {
  stem <- toupper(sub("^F_", "", toupper(canon)))
  cand <- raw_names_upper[toupper(sub("Y1X?$", "", raw_names_upper)) == stem]
  cand <- cand[!grepl("Y2X?$", cand)]
  if (!length(cand)) return(NA_character_)
  pref <- c(cand[grepl("Y1X$", cand)], cand[grepl("Y1$", cand)],
            cand[cand == stem], cand)
  pref[1]
}
