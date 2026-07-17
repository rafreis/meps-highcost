# =============================================================================
# meps-highcost / R/m2_03_pqi.R
# SECONDARY endpoint: concordance of the high-cost group with an AHRQ-PQI
# hospitalization -- PQI #08 Heart Failure (ICD-10-CM I50) and #05 COPD
# (J40-J44), age>=40 for COPD. DOCUMENTED DEVIATION from the exact AHRQ v2024
# spec: MEPS public files give only 3-digit ICD-10-CM (ICD10CDX) and have no
# clean "principal diagnosis" flag on inpatient events, so this is a
# CCSR/3-digit proxy = "any inpatient stay in year 2 linked (via CLNK) to a
# HF/COPD condition". Validation window: P26 (2022) + P27 (2023).
# =============================================================================
source("R/config.R")
suppressPackageStartupMessages({ library(haven); library(dplyr) })
OUT <- "outputs/m2"

# year -> (conditions, inpatient D, clnk I) HC numbers (verified 2026-07-08)
EVT <- list(`2022` = c(cond="h241", ip="h239d", clnk="h239i"),
            `2023` = c(cond="h249", ip="h248d", clnk="h248i"))
base_url <- "https://meps.ahrq.gov/mepsweb/data_files/pufs"   # actual DATA path (not the /data_stats/ doc path)

get_dta <- function(tag){
  dir <- file.path("data","raw", toupper(tag)); dta <- file.path(dir, paste0(tag, ".dta"))
  if (file.exists(dta)) return(dta)
  dir.create(dir, recursive=TRUE, showWarnings=FALSE)
  zip <- file.path(dir, paste0(tag, ".zip"))
  url <- sprintf("%s/%s/%sdta.zip", base_url, tag, tag)
  message("downloading ", url)
  download.file(url, zip, mode="wb", quiet=TRUE)
  unzip(zip, exdir=dir)
  f <- list.files(dir, pattern="\\.dta$", full.names=TRUE, ignore.case=TRUE)[1]
  if (is.na(f)) stop("no .dta after unzip: ", tag)
  f
}
rd <- function(tag){ x <- haven::zap_labels(haven::read_dta(get_dta(tag))); names(x) <- toupper(names(x)); x }

HF   <- c("I50")
COPD <- c("J40","J41","J42","J43","J44")

pqi_by_year <- function(y){
  e <- EVT[[y]]
  cond <- rd(e["cond"]); clnk <- rd(e["clnk"]); ip <- rd(e["ip"])
  icd <- grep("^ICD10", names(cond), value=TRUE)[1]      # ICD10CDX (3-digit)
  stopifnot(!is.na(icd), "CONDIDX" %in% names(cond), "EVNTIDX" %in% names(clnk),
            "CONDIDX" %in% names(clnk), "EVNTIDX" %in% names(ip))
  cond$code <- toupper(trimws(as.character(cond[[icd]])))
  hf_cond   <- cond$CONDIDX[cond$code %in% HF]
  copd_cond <- cond$CONDIDX[cond$code %in% COPD]
  ip_ev <- unique(as.character(ip$EVNTIDX))
  link  <- clnk[as.character(clnk$EVNTIDX) %in% ip_ev, ]   # condition-event links that are IP stays
  hf_ppl   <- unique(as.character(link$DUPERSID[as.character(link$CONDIDX) %in% as.character(hf_cond)]))
  copd_ppl <- unique(as.character(link$DUPERSID[as.character(link$CONDIDX) %in% as.character(copd_cond)]))
  list(hf=hf_ppl, copd=copd_ppl)
}

message("Building PQI flags for 2022, 2023 ...")
p22 <- pqi_by_year("2022"); p23 <- pqi_by_year("2023")
hf_all   <- unique(c(p22$hf, p23$hf))
copd_all <- unique(c(p22$copd, p23$copd))

# ---- merge to validation frame + model predictions --------------------------
d  <- readRDS("data/derived/pooled.rds"); d$panel <- as.character(d$panel)
va <- d[d$role=="validation", ]
source("R/feature_contract.R")
suppressPackageStartupMessages(library(lightgbm))
model <- lgb.load(file.path(OUT,"lgb_model.txt"))
va$pred <- pmin(pmax(predict(model, as.matrix(va[CANONICAL_FEATURES])),1e-6),1-1e-6)

va$pqi_hf   <- as.integer(va$dupersid %in% hf_all)
va$pqi_copd <- as.integer(va$dupersid %in% copd_all & !is.na(va$f_age) & va$f_age >= 40)  # PQI#05 age>=40
va$pqi_any  <- as.integer(va$pqi_hf == 1L | va$pqi_copd == 1L)
w <- va$longwt
# model-predicted top decile (weighted 90th pct of pred)
wq <- function(x,w,p){o<-order(x);x<-x[o];w<-w[o];x[which(cumsum(w)/sum(w)>=p)[1]]}
va$flag_model <- as.integer(va$pred >= wq(va$pred, w, 0.90))

wp <- function(sel) sum(w[sel])/sum(w)                    # weighted proportion
conc <- function(flagcol){
  f <- va[[flagcol]]==1
  list(
    pqi_prev              = round(wp(va$pqi_any==1),4),
    P_pqi_given_highcost  = round(sum(w[f & va$pqi_any==1])/sum(w[f]),4),
    P_pqi_given_not       = round(sum(w[!f & va$pqi_any==1])/sum(w[!f]),4),
    P_highcost_given_pqi  = round(sum(w[f & va$pqi_any==1])/sum(w[va$pqi_any==1]),4),  # capture/sens
    risk_ratio            = round((sum(w[f & va$pqi_any==1])/sum(w[f])) /
                                  (sum(w[!f & va$pqi_any==1])/sum(w[!f])),2))
}
res <- list(
  n_valid=nrow(va), n_pqi_hf=sum(va$pqi_hf), n_pqi_copd=sum(va$pqi_copd), n_pqi_any=sum(va$pqi_any),
  by_actual_top_decile = conc("top_decile_y2"),
  by_model_flag        = conc("flag_model"),
  note="Proxy: any year-2 inpatient stay CLNK-linked to HF(I50)/COPD(J40-J44) condition; 3-digit ICD-10-CM; no principal-dx flag. Deviation from AHRQ PQI v2024 disclosed.")
writeLines(jsonlite::toJSON(res, auto_unbox=TRUE, pretty=TRUE), file.path(OUT,"pqi_concordance.json"))
cat("\n--- AHRQ-PQI concordance (validation, weighted) ---\n")
cat(jsonlite::toJSON(res, auto_unbox=TRUE, pretty=TRUE)); cat("\n")
