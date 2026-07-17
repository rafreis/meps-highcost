# =============================================================================
# meps-highcost / R/prep_panel.R   (UNIFIED prep - replaces prep_panel_XX.R +
# build_target_panel_XX.R). One code path for all 5 panels => no schema drift.
# Usage:  Rscript R/prep_panel.R <PANEL>     e.g.  Rscript R/prep_panel.R 21
# Emits data/derived/panel_<PANEL>.rds with:
#   canonical spine (dupersid, panel, year1, year2, totexp_y1, totexp_y2,
#   top_decile_y2, longwt, varstr, varpsu), admin col all5rds, and the 62
#   canonical f_* features (identical schema across panels).
# =============================================================================
source("R/config.R")
source("R/feature_contract.R")
options(survey.lonely.psu = "adjust")

PANEL <- commandArgs(trailingOnly = TRUE)[1]
stopifnot(PANEL %in% names(PANEL_MAP))
pm <- PANEL_MAP[[PANEL]]; YEAR1 <- pm$years[1]; YEAR2 <- pm$years[2]
hc <- pm$longitudinal; base <- tolower(sub("HC-", "h", hc))
RAWc <- c(file.path("data/raw", hc, paste0(base, ".dta")),
          file.path("data/raw", base, paste0(base, ".dta")))
RAW <- RAWc[file.exists(RAWc)][1]; stopifnot(!is.na(RAW))

# 1. resolve source columns from the header, then read only what we need
hdr <- toupper(names(haven::read_dta(RAW, n_max = 0)))
src <- vapply(CANONICAL_FEATURES, resolve_feature, character(1), raw_names_upper = hdr)
missing_feat <- CANONICAL_FEATURES[is.na(src)]
if (length(missing_feat)) stop("Panel ", PANEL, " has no source for: ",
                               paste(missing_feat, collapse = ", "))
SPINE_SRC <- c("DUPERSID","TOTEXPY1","TOTEXPY2","LONGWT","VARSTR","VARPSU","ALL5RDS")
need <- unique(c(SPINE_SRC, unname(src)))
orig <- names(haven::read_dta(RAW, n_max = 0))
sel  <- orig[toupper(orig) %in% need]
raw  <- haven::zap_labels(haven::read_dta(RAW, col_select = dplyr::all_of(sel)))
names(raw) <- toupper(names(raw))

recode_na <- function(x){ x <- as.numeric(x); x[x %in% c(-1,-7,-8,-9,-15)] <- NA; x }

out <- tibble::tibble(
  dupersid      = as.character(raw$DUPERSID),
  panel         = as.integer(PANEL),
  year1         = YEAR1, year2 = YEAR2,
  totexp_y1     = as.numeric(raw$TOTEXPY1),
  totexp_y2     = as.numeric(raw$TOTEXPY2),
  top_decile_y2 = NA_integer_,
  longwt        = as.numeric(raw$LONGWT),
  varstr        = as.numeric(raw$VARSTR),
  varpsu        = as.numeric(raw$VARPSU),
  all5rds       = if ("ALL5RDS" %in% names(raw)) as.integer(raw$ALL5RDS) else NA_integer_
)
for (i in seq_along(CANONICAL_FEATURES))
  out[[CANONICAL_FEATURES[i]]] <- recode_na(raw[[toupper(src[i])]])

# 2. target: WEIGHTED 90th percentile of totexp_y2 within THIS panel (LONGWT).
#    Design-based weighted quantile (Francisco & Fuller 1991 estimand).
wtd_quantile <- function(x, w, p){ o <- order(x); x <- x[o]; w <- w[o]
  x[which(cumsum(w)/sum(w) >= p)[1]] }
thr <- wtd_quantile(out$totexp_y2, out$longwt, TOP_DECILE_QUANTILE)
out$top_decile_y2 <- as.integer(out$totexp_y2 >= thr)

# weighted base rate check (~10%)
des  <- make_survey_design(out)
brate <- as.numeric(srvyr::summarise(des,
           r = srvyr::survey_mean(top_decile_y2, vartype = NULL))$r)

# 3. leakage guard: no *_y2 among features/design
assert_no_leakage(setdiff(names(out),
  c("dupersid","panel","year1","year2","totexp_y1","totexp_y2")))
stopifnot(sum(grepl("^f_", names(out))) == 62L)

saveRDS(out, file.path("data/derived", paste0("panel_", PANEL, ".rds")))
cat(sprintf("panel %s | n=%d | features=%d | thr(90pct wtd totexp_y2)=%.0f | wtd_base_rate=%.4f | all5rds=%s\n",
            PANEL, nrow(out), sum(grepl("^f_", names(out))), thr, brate,
            if (all(is.na(out$all5rds))) "MISSING" else "present"))
