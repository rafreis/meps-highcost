# =============================================================================
# meps-highcost / R/m2_04_transition.R
# SENSITIVITY - "transition" framing: restrict to persons NOT in the year-1
# top-cost decile, then evaluate prediction of year-2 top-decile status
# (i.e., identifying NEW high-cost cases). Weighted, validation window.
# =============================================================================
source("R/config.R"); source("R/feature_contract.R")
suppressPackageStartupMessages({ library(lightgbm); library(WeightedROC) })
OUT <- "outputs/m2"

d <- readRDS("data/derived/pooled.rds"); d$panel <- as.character(d$panel)
model <- lgb.load(file.path(OUT,"lgb_model.txt"))
clamp <- function(p) pmin(pmax(p,1e-6),1-1e-6)
wq <- function(x,w,p){o<-order(x);x<-x[o];w<-w[o];x[which(cumsum(w)/sum(w)>=p)[1]]}
wauc <- function(y,p,w) WeightedROC::WeightedAUC(WeightedROC::WeightedROC(p,y,w))

# per-panel year-1 top-decile flag (weighted), then keep NON-top-y1 persons
d$top_y1 <- 0L
for (p in unique(d$panel)){ ix <- d$panel==p
  thr1 <- wq(d$totexp_y1[ix], d$longwt[ix], 0.90)
  d$top_y1[ix] <- as.integer(d$totexp_y1[ix] >= thr1) }

res <- lapply(c("full","validation"), function(scope){
  dd <- if (scope=="full") d else d[d$role=="validation",]
  tr <- dd[dd$top_y1==0L, ]                         # transition-eligible
  p  <- clamp(predict(model, as.matrix(tr[CANONICAL_FEATURES])))
  list(scope=scope, n=nrow(tr),
       transition_rate_wtd = round(sum(tr$longwt*tr$top_decile_y2)/sum(tr$longwt),4),
       auc_wtd = round(wauc(tr$top_decile_y2, p, tr$longwt),4))
})
va <- d[d$role=="validation" & d$top_y1==0L,]
pv <- clamp(predict(model, as.matrix(va[CANONICAL_FEATURES])))
out <- list(
  note="Transition sensitivity: among persons NOT year-1 top-decile, predict year-2 top-decile (new high-cost).",
  full_sample = res[[1]], validation = res[[2]])
writeLines(jsonlite::toJSON(out, auto_unbox=TRUE, pretty=TRUE), file.path(OUT,"transition_sensitivity.json"))
cat(jsonlite::toJSON(out, auto_unbox=TRUE, pretty=TRUE)); cat("\n")
