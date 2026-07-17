# =============================================================================
# meps-highcost / R/m2_05_cis_comparators.R
# Design-based 95% CIs (replicate weights) for validation AUC, and comparator
# models: XGBoost (weighted), survey logistic regression, prior-year-cost only.
# =============================================================================
source("R/config.R"); source("R/feature_contract.R")
suppressPackageStartupMessages({ library(lightgbm); library(xgboost)
  library(WeightedROC); library(survey) })
options(survey.lonely.psu = "adjust"); set.seed(42)
OUT <- "outputs/m2"

d <- readRDS("data/derived/pooled.rds"); d$panel <- as.character(d$panel)
tr <- d[d$role=="train",]; va <- d[d$role=="validation",]
FEAT <- CANONICAL_FEATURES
Xtr <- as.matrix(tr[FEAT]); Xva <- as.matrix(va[FEAT])
ytr <- tr$top_decile_y2; yva <- va$top_decile_y2; wtr <- tr$longwt; wva <- va$longwt
clamp <- function(p) pmin(pmax(p,1e-6),1-1e-6)
wauc <- function(y,p,w) WeightedROC::WeightedAUC(WeightedROC::WeightedROC(p,y,w))

# ---- LightGBM predictions (primary) ------------------------------------------
lgbm <- lgb.load(file.path(OUT,"lgb_model.txt")); p_lgb <- clamp(predict(lgbm, Xva))

# ---- design-based 95% CI for validation AUC: PSU cluster bootstrap -----------
# Resample whole PSUs (panel x varstr x varpsu) with replacement -> respects the
# clustering variance without the svrepdesign lonely-PSU failure. B=400.
cl <- as.integer(factor(paste(va$panel, va$varstr, va$varpsu)))
idx_by_cl <- split(seq_along(cl), cl); ucl <- seq_along(idx_by_cl)
auc_reps <- replicate(400, {
  idx <- unlist(idx_by_cl[sample(ucl, length(ucl), replace=TRUE)], use.names=FALSE)
  tryCatch(wauc(yva[idx], p_lgb[idx], wva[idx]), error=function(e) NA_real_) })
auc_ci <- round(quantile(auc_reps, c(.025,.975), na.rm=TRUE), 4)

# ---- comparator 1: XGBoost (weighted) ----------------------------------------
dtr <- xgb.DMatrix(Xtr, label=ytr, weight=wtr, missing=NA)
dva <- xgb.DMatrix(Xva, label=yva, weight=wva, missing=NA)
xgbm <- xgb.train(list(objective="binary:logistic", eval_metric="auc", eta=0.05,
                       max_depth=5, subsample=0.8, colsample_bytree=0.8, lambda=1,
                       nthread=4), dtr, nrounds=300, verbose=0)
p_xgb <- clamp(predict(xgbm, dva))

# ---- comparator 2: survey logistic regression (median-imputed) ---------------
imp <- function(m){ for(j in seq_len(ncol(m))){ x<-m[,j]; x[is.na(x)]<-median(x,na.rm=TRUE); m[,j]<-x }; m }
tri <- as.data.frame(imp(Xtr)); tri$y<-ytr; tri$longwt<-wtr; tri$varstr<-tr$varstr
tri$varpsu<-tr$varpsu; tri$panel<-tr$panel
des_tr <- svydesign(ids=~varpsu, strata=~interaction(panel,varstr,drop=TRUE),
                    weights=~longwt, data=tri, nest=TRUE)
f <- as.formula(paste("y ~", paste(FEAT, collapse="+")))
slr <- svyglm(f, des_tr, family=quasibinomial())
vai <- as.data.frame(imp(Xva)); p_slr <- clamp(as.numeric(predict(slr, newdata=vai, type="response")))

# ---- comparator 3: prior-year-cost only --------------------------------------
tri$lprior <- log1p(pmax(tr$totexp_y1,0)); des_tr2 <- svydesign(ids=~varpsu,
  strata=~interaction(panel,varstr,drop=TRUE), weights=~longwt, data=tri, nest=TRUE)
pcm <- svyglm(y ~ lprior, des_tr2, family=quasibinomial())
p_pc <- clamp(as.numeric(predict(pcm, newdata=data.frame(lprior=log1p(pmax(va$totexp_y1,0))), type="response")))

res <- list(
  auc_valid = list(
    lightgbm      = list(auc=round(wauc(yva,p_lgb,wva),4), ci95=unname(auc_ci)),
    xgboost       = round(wauc(yva,p_xgb,wva),4),
    survey_logit  = round(wauc(yva,p_slr,wva),4),
    prior_cost_only = round(wauc(yva,p_pc,wva),4)),
  ci_method="design-based PSU cluster bootstrap, 400 replicates (resample panel x varstr x varpsu with replacement)")
writeLines(jsonlite::toJSON(res, auto_unbox=TRUE, pretty=TRUE), file.path(OUT,"cis_comparators.json"))
cat(jsonlite::toJSON(res, auto_unbox=TRUE, pretty=TRUE)); cat("\n")
