# =============================================================================
# meps-highcost / R/build_feature_set.R  (v2 - refined universe)
# Design-based feature selection defining the SINGLE canonical year-1 feature
# contract. TRAIN ONLY (P21/22/23); validation panels never read here.
#
# Refined candidate universe (see docs/Methods_Justification.md §5):
#   Universe = [Y1/Y1X columns common to all 5 panels]
#            + [round-1/2 year-1 clinical constructs, allowlisted by name]
#            + [panel-invariant demographics]
#            MINUS pre-specified STRUCTURAL EXCLUSIONS:
#              - imputation/edit flags (*IMP)
#              - source-of-payment decomposition of Y1 spend (charges/$ by payer)
#              - monthly insurance-coverage cells (payer x month)
#              - income-by-source components (keep total/family income + poverty)
#              - IDs / administrative / household-structure fields
# Round 3/4/5 versions of round-based constructs are EXCLUDED (year-2 leakage).
# Then: weighted unsupervised filters -> Rao-Scott screen -> export matrix for
# design-based LASSO (wlasso attempted here; matrix also exported for local run).
# =============================================================================

suppressPackageStartupMessages({
  library(haven); library(dplyr); library(survey); library(jsonlite)
})
DIR_RAW <- "data/raw"; DIR_DER <- "data/derived"
DIR_OUT <- "outputs"; dir.create(DIR_OUT, showWarnings = FALSE)
options(survey.lonely.psu = "adjust")

RAW <- list(
  `21` = c("data/raw/HC-202/h202.dta","data/raw/h202/h202.dta"),
  `22` = c("data/raw/HC-210/h210.dta","data/raw/h210/h210.dta"),
  `23` = c("data/raw/HC-217/h217.dta","data/raw/h217/h217.dta"),
  `26` = c("data/raw/HC-244/h244.dta","data/raw/h244/h244.dta"),
  `27` = c("data/raw/HC-252/h252.dta","data/raw/h252/h252.dta"))
resolve <- function(c) { h <- c[file.exists(c)]; if(!length(h)) stop("missing ",c[1]); h[1] }
RAW_PATH <- vapply(RAW, resolve, character(1)); TRAIN <- c("21","22","23")
MEPS_NA <- c(-1,-7,-8,-9,-15); recode_na <- function(x){ x[x %in% MEPS_NA] <- NA; x }

# ---- round-1/2 (year-1) clinical constructs to ADD (never rounds 3/4/5) -----
ALLOWLIST <- c("RTHLTH1","RTHLTH2","MNHLTH1","MNHLTH2","ADGENH2","ADDAYA2",
               "ACTLIM1","COGLIM1","SOCLIM1","WLKLIM1","WRKLIM1","HSELIM1",
               "ADLHLP1","AIDHLP1","IADLHP1","HAVEUS2")
INVARIANT <- c("SEX","RACEV1X","RACETHX","HISPANX")
# force-include clinical/econ anchors (canonical f_ names)
FORCE <- c("f_totexp","f_totslf","f_age","f_sex","f_racev1x","f_racethx",
           "f_hispanx","f_povcat","f_povlev","f_ttlp","f_faminc","f_inscov","f_unins")

# ---- structural exclusion, applied to the Y1-stripped uppercase stem --------
KEEP_UTIL <- c("TOTEXP","TOTSLF","OBTOTV","OPTOTV","ERTOT","IPDIS","IPNGTD",
               "RXTOT","DVTOT","HHTOTD")   # aggregate spend + utilization COUNTS
PAYER <- "(EXP|TCH|SLF|MCR|MCD|MCA|PRV|VA|TRI|OFD|STL|WCP|OPA|OPB|OPR|OPU|OSR|PTR|MSA|OTH)$"
MONTH <- "(JA|FE|MA|AP|MY|JU|JL|AU|SE|OC|NO|DE)$"
COV_PFX <- "^(MCR|MCD|MCA|TRI|PUB|PEG|PNG|PRX|PRI|POG|PDK|POU|POE|HPE|HPN|HPR|HPX|INS|OPP|OPA|OPB|DHC|STA|OTP|PMD|GVA|GVB|VAP|PEX|PDN)"
INCOME <- c("WAGP","BUSP","INTRP","DIVDP","SALEP","PENSP","SSECP","TRSTP","IRASP",
            "CHLDP","SSIP","UNEMP","VETSP","OTHRP","RNTP","CASHP","WCMPP","REFDP",
            "PUBLP","WAG","INT","DIV","PEN","SSEC","IRA","SSI","UNE","ALMP")
ADMIN <- c("SPOUID","RESP","REFRL","ACTDT","ENDRFM","BEGRFM","SAQELI","INSCOP",
           "ELGRND","FAMID","CPSFAMID","FAMSID","FCSZ","FCRP","RULETR","PROXY",
           "ENTRND","PANEL","DUID","PID","SPOUIN","RUSIZE","KEYNESS")
is_excluded <- function(stem) {
  if (stem %in% KEEP_UTIL) return(FALSE)
  grepl("IMP$", stem) ||
  grepl(PAYER, stem) ||
  (grepl(COV_PFX, stem) && grepl(MONTH, stem) && nchar(stem) <= 7) ||
  stem %in% INCOME || stem %in% ADMIN
}

# ---- 0. candidate universe from column NAMES ---------------------------------
message("Reading column names ...")
nm <- lapply(RAW_PATH, function(p) toupper(names(haven::read_dta(p, n_max = 0))))
y1 <- Reduce(intersect, lapply(nm, function(x) x[grepl("[A-Z]Y1X?$", x)]))
y1 <- y1[!grepl("Y2X?$", y1)]
inv <- intersect(INVARIANT, Reduce(intersect, nm))
allow <- intersect(ALLOWLIST, Reduce(intersect, nm))

stem_of <- function(s) toupper(sub("Y1X?$", "", s))
keep_y1 <- y1[!vapply(y1, function(s) is_excluded(stem_of(s)), logical(1))]
universe_src <- unique(c(keep_y1, inv, allow))
canon_name <- setNames(make.unique(paste0("f_", tolower(sub("Y1X?$","",universe_src))), sep="_"),
                       universe_src)
message(sprintf("Y1 common=%d -> after structural exclusion=%d; +invariant(%d)+allowlist(%d) = universe %d",
                length(y1), length(keep_y1), length(inv), length(allow), length(universe_src)))

# ---- assemble TRAIN pool -----------------------------------------------------
load_panel <- function(p) {
  orig <- names(haven::read_dta(RAW_PATH[[p]], n_max = 0))
  sel  <- orig[toupper(orig) %in% c("DUPERSID", universe_src)]
  raw  <- haven::zap_labels(haven::read_dta(RAW_PATH[[p]], col_select = dplyr::all_of(sel)))
  names(raw) <- toupper(names(raw))
  der  <- readRDS(file.path(DIR_DER, paste0("panel_",p,".rds"))) |>
            dplyr::select(dupersid, top_decile_y2, longwt, varstr, varpsu)
  src  <- intersect(universe_src, names(raw))
  feat <- as.data.frame(lapply(src, function(v) recode_na(as.numeric(raw[[v]]))))
  names(feat) <- canon_name[src]
  merge(cbind(data.frame(dupersid=as.character(raw$DUPERSID), panel=p), feat), der, by="dupersid")
}
message("Loading train panels ...")
train <- dplyr::bind_rows(lapply(TRAIN, load_panel))
feat_cols <- grep("^f_", names(train), value = TRUE)
message("Train pool: ", nrow(train), " rows x ", length(feat_cols), " candidate features.")
w <- train$longwt

# ---- unsupervised filters (weighted) ----------------------------------------
miss <- vapply(train[feat_cols], function(x) mean(is.na(x)), numeric(1))
modal <- vapply(train[feat_cols], function(x){ ok<-!is.na(x); if(!any(ok)) return(1)
  tw<-tapply(w[ok],x[ok],sum); max(tw)/sum(tw) }, numeric(1))
keep1 <- names(miss)[miss <= 0.40 & modal <= 0.99]
message("After missingness<=40% + modal<=99%: ", length(keep1))
Xz <- scale(as.matrix(train[keep1])); cm <- suppressWarnings(cor(Xz, use="pairwise.complete.obs"))
dropr <- character(0)
for (i in seq_along(keep1)) for (j in seq_len(i-1)) { a<-keep1[i]; b<-keep1[j]
  if (a %in% dropr || b %in% dropr) next
  if (!is.na(cm[a,b]) && abs(cm[a,b])>0.90) dropr <- c(dropr,a) }
keep2 <- setdiff(keep1, dropr)
message("After redundancy |r|>0.90: ", length(keep2), " (removed ", length(dropr), ")")

# ---- Rao-Scott univariate design-based screen --------------------------------
train$str_p <- interaction(train$panel, train$varstr, drop=TRUE)
des <- svydesign(ids=~varpsu, strata=~str_p, weights=~longwt, data=train, nest=TRUE)
rs <- setNames(rep(NA_real_, length(keep2)), keep2)
for (v in keep2) rs[v] <- tryCatch(
  regTermTest(svyglm(as.formula(paste0("top_decile_y2 ~ ",v)), des, family=quasibinomial()),
              as.formula(paste0("~",v)))$p[1], error=function(e) NA_real_)
screen <- names(rs)[!is.na(rs) & rs < 0.157]
force_present <- intersect(FORCE, feat_cols)
candidate <- union(intersect(screen, keep2), intersect(force_present, keep1))
message("Rao-Scott screen (p<0.157): ", length(screen), " | + forced -> candidate set for LASSO: ", length(candidate))

# ---- export design matrix for design-based LASSO (local fallback) -----------
expo <- train[, c("dupersid","panel","top_decile_y2","longwt","varstr","varpsu","str_p", candidate)]
saveRDS(expo, file.path(DIR_OUT, "train_lasso_input.rds"))
write.csv(expo, file.path(DIR_OUT, "train_lasso_input.csv"), row.names = FALSE)

# ---- design-based LASSO for parsimony ---------------------------------------
# Preferred: wlasso (Iparragirre & Lumley 2023, design-based dCV). If absent,
# fall back to glmnet weighted LASSO with CLUSTER-RESPECTING CV folds (whole
# PSUs assigned to folds) -- a design-aware selector, to be confirmed by the
# user running wlasso locally on outputs/train_lasso_input.rds.
# Selection-stage median imputation on the candidate matrix (train only).
wlasso_status <- "not_installed"; lasso_selected <- NULL
impute_med <- function(x){ m <- median(x, na.rm=TRUE); x[is.na(x)] <- m; x }
Xg <- as.matrix(as.data.frame(lapply(train[candidate], impute_med)))
yg <- train$top_decile_y2
if (requireNamespace("wlasso", quietly = TRUE)) {
  wlasso_status <- tryCatch({
    fit <- wlasso::wlasso(data = train, col.y = "top_decile_y2", col.x = candidate,
                          family = "binomial", cluster = "varpsu", strata = "str_p",
                          weights = "longwt", method = "dCV", k = 10)
    lasso_selected <<- tryCatch(setdiff(rownames(coef(fit$model.min))[as.numeric(coef(fit$model.min))!=0],
                                        "(Intercept)"), error=function(e) NULL)
    if (is.null(lasso_selected)) "wlasso_ran_no_extract" else paste0("wlasso_selected_", length(lasso_selected))
  }, error = function(e) paste0("wlasso_error: ", conditionMessage(e)))
}
if (is.null(lasso_selected) && requireNamespace("glmnet", quietly = TRUE)) {
  clus   <- factor(paste(train$str_p, train$varpsu))
  uc     <- levels(clus); set.seed(42)
  fmap   <- setNames(sample(rep(1:10, length.out=length(uc))), uc)
  foldid <- as.integer(fmap[as.character(clus)])
  cvf    <- glmnet::cv.glmnet(Xg, yg, family="binomial", weights=train$longwt,
                              foldid=foldid, alpha=1)
  co     <- as.matrix(coef(cvf, s="lambda.1se"))
  lasso_selected <- setdiff(rownames(co)[co[,1]!=0], "(Intercept)")
  # ensure forced anchors are retained regardless of LASSO shrinkage
  lasso_selected <- union(lasso_selected, intersect(force_present, candidate))
  wlasso_status  <- paste0("glmnet_weighted_psuCV_lambda1se_selected_", length(lasso_selected))
}
message("LASSO: ", wlasso_status)

# ---- report ------------------------------------------------------------------
tab <- data.frame(canonical=feat_cols, weighted_missing=round(miss[feat_cols],4),
  weighted_modal_prop=round(modal[feat_cols],4), rao_scott_p=round(rs[feat_cols],5),
  passed_unsup=feat_cols %in% keep2, forced=feat_cols %in% force_present,
  candidate=feat_cols %in% candidate, row.names=NULL)
tab <- tab[order(-tab$candidate, tab$rao_scott_p), ]
write.csv(tab, file.path(DIR_OUT,"whitelist_candidate.csv"), row.names=FALSE)
report <- list(train_panels=TRAIN, n_train_rows=nrow(train),
  y1_common=length(y1), universe_after_exclusion=length(universe_src),
  invariant=inv, allowlist_added=allow, n_after_missing_nzv=length(keep1),
  n_after_redundancy=length(keep2), n_rao_scott=length(screen),
  n_candidate_for_lasso=length(candidate), candidate_features=sort(candidate),
  wlasso_status=wlasso_status, lasso_selected=lasso_selected)
writeLines(jsonlite::toJSON(report, auto_unbox=TRUE, pretty=TRUE, na="null"),
           file.path(DIR_OUT,"feature_selection_report.json"))
cat("\n--- REPORT ---\n"); cat(jsonlite::toJSON(report, auto_unbox=TRUE, pretty=TRUE, na="null")); cat("\n")
