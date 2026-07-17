# =============================================================================
# meps-highcost / R/m2_02_shap_dca_subgroups.R
# M2 explainability + clinical utility + fairness (all survey-weighted):
#   1. SHAP (TreeSHAP via lightgbm) global importance + beeswarm.
#   2. Decision-curve analysis: model vs PRIOR-YEAR-COST benchmark, weighted
#      net benefit (Vickers & Elkin 2006) with design-based components.
#   3. Subgroup calibration + AUC by income (f_povcat) and race/ethnicity
#      (f_racethx) -- fairness check.
# =============================================================================
source("R/config.R"); source("R/feature_contract.R")
suppressPackageStartupMessages({ library(lightgbm); library(WeightedROC)
  library(survey); library(shapviz); library(ggplot2) })
options(survey.lonely.psu = "adjust")
OUT <- "outputs/m2"; set.seed(42)

d <- readRDS("data/derived/pooled.rds"); d$panel <- as.character(d$panel)
tr <- d[d$role=="train",]; va <- d[d$role=="validation",]
FEAT <- CANONICAL_FEATURES
Xtr <- as.matrix(tr[FEAT]); Xva <- as.matrix(va[FEAT])
model <- lgb.load(file.path(OUT,"lgb_model.txt"))
clamp <- function(p) pmin(pmax(p,1e-6),1-1e-6)
pva <- clamp(predict(model, Xva)); yva <- va$top_decile_y2; wva <- va$longwt

# ---- 1. SHAP (validation) ----------------------------------------------------
sv <- shapviz(model, X_pred = Xva, X = as.data.frame(Xva))
ggsave(file.path(OUT,"shap_importance.png"),
       sv_importance(sv, kind="bar", max_display=20) + ggtitle("SHAP importance (validation)"),
       width=8, height=7, dpi=150)
ggsave(file.path(OUT,"shap_beeswarm.png"),
       sv_importance(sv, kind="beeswarm", max_display=18) + ggtitle("SHAP beeswarm (validation)"),
       width=9, height=7, dpi=150)
imp <- sort(colMeans(abs(sv$S)), decreasing=TRUE)
write.csv(data.frame(feature=names(imp), mean_abs_shap=as.numeric(imp)),
          file.path(OUT,"shap_importance.csv"), row.names=FALSE)

# ---- 2. Decision curve analysis (weighted) -----------------------------------
# Prior-year-cost benchmark: survey-weighted logistic of outcome on log prior spend.
fin0 <- function(x){ x[!is.finite(x)] <- 0; x }
tr$lprior <- fin0(log1p(pmax(tr$totexp_y1, 0))); va$lprior <- fin0(log1p(pmax(va$totexp_y1, 0)))
des_tr <- svydesign(ids=~varpsu, strata=~interaction(panel,varstr,drop=TRUE),
                    weights=~longwt, data=tr, nest=TRUE)
pcm <- svyglm(top_decile_y2 ~ lprior, des_tr, family=quasibinomial())
pprior <- clamp(as.numeric(predict(pcm, newdata=va, type="response")))

nb <- function(p,y,w,pt){ tp<-sum(w*(p>=pt & y==1))/sum(w); fp<-sum(w*(p>=pt & y==0))/sum(w)
  tp - fp*(pt/(1-pt)) }
prev <- sum(wva*yva)/sum(wva)
pts <- seq(0.02,0.50,0.01)
dca <- data.frame(pt=pts,
  model     = vapply(pts, function(t) nb(pva,yva,wva,t), numeric(1)),
  prior_cost= vapply(pts, function(t) nb(pprior,yva,wva,t), numeric(1)),
  treat_all = vapply(pts, function(t) prev-(1-prev)*(t/(1-t)), numeric(1)),
  treat_none= 0)
write.csv(dca, file.path(OUT,"dca_valid.csv"), row.names=FALSE)
png(file.path(OUT,"dca_valid.png"), width=1200, height=950, res=150)
plot(dca$pt, dca$model, type="l", lwd=2.5, col="#2166AC", ylim=c(-0.02, max(dca$model)*1.1),
     xlab="Threshold probability", ylab="Net benefit (weighted)",
     main="Decision curve - external validation (P26+27)")
lines(dca$pt, dca$prior_cost, lwd=2.5, col="#D6604D")
lines(dca$pt, dca$treat_all, lwd=1.5, col="grey50", lty=2)
abline(h=0, col="grey30", lty=3); grid()
legend("topright", c("GBT model","Prior-year cost","Treat all","Treat none"),
       col=c("#2166AC","#D6604D","grey50","grey30"), lwd=c(2.5,2.5,1.5,1), lty=c(1,1,2,3), bty="n")
dev.off()

# ---- 3. Subgroup calibration + AUC (income, race/ethnicity) ------------------
wauc <- function(y,p,w){ if(length(unique(y))<2) return(NA); WeightedROC::WeightedAUC(WeightedROC::WeightedROC(p,y,w)) }
subgroup_tbl <- function(g, gname){
  do.call(rbind, lapply(sort(unique(g[!is.na(g)])), function(lv){
    ix <- which(g==lv & !is.na(g)); if(length(ix)<100) return(NULL)
    data.frame(variable=gname, level=lv, n=length(ix), wn=round(sum(wva[ix])),
      obs_rate=round(sum(wva[ix]*yva[ix])/sum(wva[ix]),4),
      mean_pred=round(sum(wva[ix]*pva[ix])/sum(wva[ix]),4),
      auc=round(wauc(yva[ix],pva[ix],wva[ix]),4)) }))
}
subg <- rbind(subgroup_tbl(va$f_povcat,"income_povcat"),
              subgroup_tbl(va$f_racethx,"race_ethnicity"))
write.csv(subg, file.path(OUT,"subgroup_calibration.csv"), row.names=FALSE)

cat("\n--- SHAP top 10 ---\n"); print(head(imp,10))
cat("\n--- DCA: model NB advantage over prior-cost at pt=0.10 ---\n")
cat(round(dca$model[dca$pt==0.10]-dca$prior_cost[dca$pt==0.10],4), "\n")
cat("\n--- Subgroup calibration ---\n"); print(subg, row.names=FALSE)
