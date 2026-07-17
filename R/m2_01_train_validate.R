# =============================================================================
# meps-highcost / R/m2_01_train_validate.R
# M2 core: survey-weighted LightGBM to predict top_decile_y2 from 62 year-1
# features. Train = panels 21/22/23; TEMPORAL EXTERNAL validation = 26/27.
# Weights = LONGWT throughout (MacNell 2023). Design-based weighted metrics:
# AUC (WeightedROC), Brier, calibration-in-the-large, calibration slope
# (svyglm), + 10-bin reliability table & plot. LightGBM handles NA natively.
# =============================================================================
source("R/config.R"); source("R/feature_contract.R")
suppressPackageStartupMessages({ library(lightgbm); library(WeightedROC); library(survey) })
options(survey.lonely.psu = "adjust")
OUT <- "outputs/m2"; dir.create(OUT, recursive = TRUE, showWarnings = FALSE)
set.seed(42)

d <- readRDS("data/derived/pooled.rds")
d$panel <- as.character(d$panel)
tr <- d[d$role == "train", ]; va <- d[d$role == "validation", ]
FEAT <- CANONICAL_FEATURES
Xtr <- as.matrix(tr[FEAT]); Xva <- as.matrix(va[FEAT])
ytr <- tr$top_decile_y2;    yva <- va$top_decile_y2
wtr <- tr$longwt;           wva <- va$longwt

# cluster-respecting CV folds (whole panel x stratum x PSU -> fold) for n_rounds
clus <- factor(paste(tr$panel, tr$varstr, tr$varpsu)); uc <- levels(clus)
fmap <- setNames(sample(rep(1:5, length.out = length(uc))), uc)
foldid <- as.integer(fmap[as.character(clus)])
folds <- lapply(1:5, function(k) which(foldid == k))

dtrain <- lgb.Dataset(Xtr, label = ytr, weight = wtr)
params <- list(objective = "binary", metric = "auc", learning_rate = 0.03,
               num_leaves = 31, min_data_in_leaf = 200, feature_fraction = 0.8,
               bagging_fraction = 0.8, bagging_freq = 1, lambda_l2 = 1.0,
               num_threads = 4, verbosity = -1)
cv <- lgb.cv(params, dtrain, nrounds = 3000, folds = folds,
             early_stopping_rounds = 100, eval_freq = 200)
best <- cv$best_iter
message("best_iter = ", best, " | CV weighted AUC = ", round(cv$best_score, 4))

model <- lgb.train(params, dtrain, nrounds = best)
lgb.save(model, file.path(OUT, "lgb_model.txt"))

clamp <- function(p) pmin(pmax(p, 1e-6), 1 - 1e-6)
ptr <- clamp(predict(model, Xtr)); pva <- clamp(predict(model, Xva))

# ---- weighted metrics --------------------------------------------------------
wauc <- function(y, p, w) WeightedROC::WeightedAUC(WeightedROC::WeightedROC(p, y, w))
wbrier <- function(y, p, w) sum(w * (p - y)^2) / sum(w)
citl <- function(y, p, w) c(mean_pred = sum(w*p)/sum(w), mean_obs = sum(w*y)/sum(w))

va$pred <- pva; va$lp <- qlogis(pva)
des_va <- svydesign(ids=~varpsu, strata=~interaction(panel,varstr,drop=TRUE),
                    weights=~longwt, data=va, nest=TRUE)
slope <- coef(svyglm(top_decile_y2 ~ lp, des_va, family = quasibinomial()))[["lp"]]

metrics <- list(
  n_train = nrow(tr), n_valid = nrow(va), best_iter = best,
  auc_train = round(wauc(ytr, ptr, wtr), 4),
  auc_valid = round(wauc(yva, pva, wva), 4),
  brier_valid = round(wbrier(yva, pva, wva), 5),
  citl_valid = round(citl(yva, pva, wva), 4),
  calib_slope_valid = round(slope, 3))
writeLines(jsonlite::toJSON(metrics, auto_unbox=TRUE, pretty=TRUE), file.path(OUT,"metrics_primary.json"))

# ---- 10-bin weighted reliability (validation) --------------------------------
wq <- function(x,w,p){o<-order(x);x<-x[o];w<-w[o];x[which(cumsum(w)/sum(w)>=p)[1]]}
brks <- unique(c(-Inf, vapply(seq(.1,.9,.1), function(q) wq(pva,wva,q), numeric(1)), Inf))
bin <- cut(pva, brks, include.lowest = TRUE)
rel <- do.call(rbind, lapply(split(seq_along(pva), bin), function(ix)
  data.frame(mean_pred = sum(wva[ix]*pva[ix])/sum(wva[ix]),
             obs_freq  = sum(wva[ix]*yva[ix])/sum(wva[ix]),
             wn        = sum(wva[ix]))))
write.csv(rel, file.path(OUT,"reliability_valid.csv"), row.names = FALSE)

png(file.path(OUT,"reliability_valid.png"), width=1100, height=1000, res=150)
plot(rel$mean_pred, rel$obs_freq, type="b", pch=19, col="#2166AC", lwd=2,
     xlim=c(0,max(rel$mean_pred,rel$obs_freq)), ylim=c(0,max(rel$mean_pred,rel$obs_freq)),
     xlab="Predicted probability (weighted)", ylab="Observed frequency (weighted)",
     main=sprintf("Reliability - temporal external validation (P26+27)\nweighted AUC=%.3f  slope=%.2f  CITL pred/obs=%.3f/%.3f",
                  metrics$auc_valid, metrics$calib_slope_valid, metrics$citl_valid[[1]], metrics$citl_valid[[2]]))
abline(0,1,lty=2,col="grey40"); grid()
dev.off()

cat("\n--- M2 PRIMARY METRICS ---\n")
cat(jsonlite::toJSON(metrics, auto_unbox=TRUE, pretty=TRUE)); cat("\n")
