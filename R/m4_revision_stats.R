# =============================================================================
# meps-highcost / R/m4_revision_stats.R   (peer-review revision)
#  1. Subgroup table INCLUDING a missing/unclassified income row (reviewer:
#     income rows summed to 14,914 vs 15,033 validation total).
#  2. Decision-curve net benefit WITH design-based cluster-bootstrap 95% CIs
#     (reviewer: "add confidence intervals or state that they were not computed").
# =============================================================================
source("R/config.R"); source("R/feature_contract.R")
suppressPackageStartupMessages({ library(lightgbm); library(WeightedROC); library(survey) })
options(survey.lonely.psu = "adjust"); set.seed(42)
OUT <- "outputs/m2"

d <- readRDS("data/derived/pooled.rds"); d$panel <- as.character(d$panel)
tr <- d[d$role=="train",]; va <- d[d$role=="validation",]
model <- lgb.load(file.path(OUT,"lgb_model.txt"))
clamp <- function(p) pmin(pmax(p,1e-6),1-1e-6)
va$p <- clamp(predict(model, as.matrix(va[CANONICAL_FEATURES])))
y <- va$top_decile_y2; w <- va$longwt
wauc <- function(y,p,w) if (length(unique(y))<2) NA else WeightedROC::WeightedAUC(WeightedROC::WeightedROC(p,y,w))

# ---- 1. subgroup table with explicit missing category -----------------------
subtab <- function(g, gname){
  lv <- sort(unique(g[!is.na(g)]))
  rows <- lapply(lv, function(l){ ix <- which(!is.na(g) & g==l)
    data.frame(variable=gname, level=as.character(l), n=length(ix),
      obs=round(sum(w[ix]*y[ix])/sum(w[ix]),4), pred=round(sum(w[ix]*va$p[ix])/sum(w[ix]),4),
      auc=round(wauc(y[ix],va$p[ix],w[ix]),4)) })
  ixm <- which(is.na(g))
  if (length(ixm) > 0) rows[[length(rows)+1]] <- data.frame(variable=gname, level="missing/unclassified",
      n=length(ixm), obs=round(sum(w[ixm]*y[ixm])/sum(w[ixm]),4),
      pred=round(sum(w[ixm]*va$p[ixm])/sum(w[ixm]),4),
      auc=round(wauc(y[ixm],va$p[ixm],w[ixm]),4))
  do.call(rbind, rows)
}
sg <- rbind(subtab(va$f_povcat,"income_povcat"), subtab(va$f_racethx,"race_ethnicity"))
write.csv(sg, file.path(OUT,"subgroup_calibration.csv"), row.names=FALSE)
cat("--- SUBGROUPS (with missing row) ---\n"); print(sg, row.names=FALSE)
cat("\nincome rows n sum =", sum(sg$n[sg$variable=="income_povcat"]),
    "| race rows n sum =", sum(sg$n[sg$variable=="race_ethnicity"]),
    "| validation N =", nrow(va), "\n")

# ---- 2. DCA with cluster-bootstrap CIs --------------------------------------
tr$lprior <- log1p(pmax(tr$totexp_y1,0)); va$lprior <- log1p(pmax(va$totexp_y1,0))
des_tr <- svydesign(ids=~varpsu, strata=~interaction(panel,varstr,drop=TRUE),
                    weights=~longwt, data=tr, nest=TRUE)
pcm <- svyglm(top_decile_y2 ~ lprior, des_tr, family=quasibinomial())
va$pprior <- clamp(as.numeric(predict(pcm, newdata=va, type="response")))

pts <- seq(0.02, 0.50, 0.01)
nb_vec <- function(p, yy, ww, pts){
  vapply(pts, function(t){ f <- p >= t
    tp <- sum(ww[f & yy==1])/sum(ww); fp <- sum(ww[f & yy==0])/sum(ww)
    tp - fp*(t/(1-t)) }, numeric(1))
}
nb_model <- nb_vec(va$p, y, w, pts); nb_prior <- nb_vec(va$pprior, y, w, pts)
prev <- sum(w*y)/sum(w); nb_all <- prev - (1-prev)*(pts/(1-pts))

cl <- as.integer(factor(paste(va$panel, va$varstr, va$varpsu)))
idx_by_cl <- split(seq_along(cl), cl); ucl <- seq_along(idx_by_cl)
B <- 400
bm <- matrix(NA_real_, B, length(pts)); bp <- matrix(NA_real_, B, length(pts))
for (b in seq_len(B)) {
  ix <- unlist(idx_by_cl[sample(ucl, length(ucl), replace=TRUE)], use.names=FALSE)
  bm[b,] <- nb_vec(va$p[ix], y[ix], w[ix], pts)
  bp[b,] <- nb_vec(va$pprior[ix], y[ix], w[ix], pts)
}
q <- function(M,pr) apply(M, 2, quantile, probs=pr, na.rm=TRUE)
# PAIRED difference (model - prior cost) within each bootstrap replicate: this is
# the correct inference for the comparison; marginal CIs overlap by construction
# because both curves are estimated on the same resampled persons.
bd <- bm - bp
dca <- data.frame(pt=pts, model=nb_model, model_lo=q(bm,.025), model_hi=q(bm,.975),
                  prior_cost=nb_prior, prior_lo=q(bp,.025), prior_hi=q(bp,.975),
                  delta=nb_model-nb_prior, delta_lo=q(bd,.025), delta_hi=q(bd,.975),
                  delta_pgt0=apply(bd, 2, function(x) mean(x > 0, na.rm=TRUE)),
                  treat_all=nb_all, treat_none=0)
write.csv(dca, file.path(OUT,"dca_valid.csv"), row.names=FALSE)
cat("\n--- DCA at pt=0.10 ---\n")
r <- dca[dca$pt==0.10,]
cat(sprintf("model NB %.4f (%.4f-%.4f) | prior-cost NB %.4f (%.4f-%.4f)\n",
    r$model, r$model_lo, r$model_hi, r$prior_cost, r$prior_lo, r$prior_hi))
cat(sprintf("PAIRED delta %.4f (95%% CI %.4f to %.4f); P(delta>0)=%.3f\n",
    r$delta, r$delta_lo, r$delta_hi, r$delta_pgt0))
cat("\n--- paired delta across thresholds 0.05-0.30 ---\n")
s <- dca[dca$pt>=0.05 & dca$pt<=0.30,]
cat(sprintf("min delta %.4f | min delta_lo %.4f | min P(delta>0) %.3f\n",
    min(s$delta), min(s$delta_lo), min(s$delta_pgt0)))
