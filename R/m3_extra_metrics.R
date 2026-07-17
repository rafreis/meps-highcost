# Extra validation metrics for manuscript depth: per-panel AUC + operating-point
# (top-10% flagged) weighted sensitivity/specificity/PPV.
source("R/config.R"); source("R/feature_contract.R")
suppressPackageStartupMessages({ library(lightgbm); library(WeightedROC) })
OUT <- "outputs/m2"
d <- readRDS("data/derived/pooled.rds"); d$panel <- as.character(d$panel)
va <- d[d$role=="validation",]; model <- lgb.load(file.path(OUT,"lgb_model.txt"))
clamp <- function(p) pmin(pmax(p,1e-6),1-1e-6)
va$p <- clamp(predict(model, as.matrix(va[CANONICAL_FEATURES])))
wauc <- function(y,p,w) WeightedROC::WeightedAUC(WeightedROC::WeightedROC(p,y,w))
wq <- function(x,w,q){o<-order(x);x<-x[o];w<-w[o];x[which(cumsum(w)/sum(w)>=q)[1]]}

perpanel <- sapply(c("26","27"), function(pn){ s<-va$panel==pn
  round(wauc(va$top_decile_y2[s], va$p[s], va$longwt[s]),4) })

# operating point: flag top 10% by predicted risk (weighted)
thr <- wq(va$p, va$longwt, 0.90); f <- va$p >= thr; y <- va$top_decile_y2==1; w <- va$longwt
sens <- sum(w[f & y])/sum(w[y]); spec <- sum(w[!f & !y])/sum(w[!y]); ppv <- sum(w[f & y])/sum(w[f])
flagged <- sum(w[f])/sum(w)

res <- list(auc_panel26=perpanel[["26"]], auc_panel27=perpanel[["27"]],
  operating_point="top 10% predicted risk flagged",
  pct_flagged=round(flagged,4), sensitivity=round(sens,4),
  specificity=round(spec,4), ppv=round(ppv,4))
writeLines(jsonlite::toJSON(res, auto_unbox=TRUE, pretty=TRUE), file.path(OUT,"extra_metrics.json"))
cat(jsonlite::toJSON(res, auto_unbox=TRUE, pretty=TRUE)); cat("\n")
