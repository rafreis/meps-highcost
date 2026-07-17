# =============================================================================
# meps-highcost / R/m3_tables_figures.R
# Table 1 (weighted cohort characteristics, train vs validation) + regenerate
# the 3 primary figures at 300 dpi for JPMedAI submission.
# =============================================================================
source("R/config.R"); source("R/feature_contract.R")
suppressPackageStartupMessages({ library(srvyr); library(survey); library(lightgbm)
  library(shapviz); library(ggplot2) })
options(survey.lonely.psu="adjust")
OUT <- "outputs/m2"; FIG <- "outputs/figures"; dir.create(FIG, showWarnings=FALSE)

d <- readRDS("data/derived/pooled.rds"); d$panel <- as.character(d$panel)

# ---- Table 1 (weighted) ------------------------------------------------------
t1_one <- function(df){
  des <- svydesign(ids=~varpsu, strata=~interaction(panel,varstr,drop=TRUE),
                   weights=~longwt, data=df, nest=TRUE)
  # coerce indicators to numeric so svymean returns a single proportion
  wm <- function(f) as.numeric(svymean(f, des, na.rm=TRUE))[1]
  wmed<- function(v) as.numeric(svyquantile(reformulate(v), des, 0.5, ci=FALSE)[[1]][1])
  npan <- length(unique(df$panel))
  data.frame(
    n_unweighted            = nrow(df),
    weighted_pop_avg_annual = round(sum(df$longwt)/npan),   # /n panels (pooling convention)
    top_decile_rate         = round(wm(~top_decile_y2),4),
    age_mean                = round(wm(~f_age),1),
    female_pct              = round(wm(~as.numeric(f_sex==2)),4),
    hispanic_pct            = round(wm(~as.numeric(f_racethx==1)),4),
    nhwhite_pct             = round(wm(~as.numeric(f_racethx==2)),4),
    nhblack_pct             = round(wm(~as.numeric(f_racethx==3)),4),
    nhasian_pct             = round(wm(~as.numeric(f_racethx==4)),4),
    private_ins_pct         = round(wm(~as.numeric(f_inscov==1)),4),
    public_only_pct         = round(wm(~as.numeric(f_inscov==2)),4),
    uninsured_pct           = round(wm(~as.numeric(f_inscov==3)),4),
    poor_nearpoor_pct       = round(wm(~as.numeric(f_povcat %in% c(1,2))),4),
    high_income_pct         = round(wm(~as.numeric(f_povcat==5)),4),
    prior_totexp_median     = round(wmed("totexp_y1")),
    prior_rxfills_mean      = round(wm(~f_rxtot),1))
}
t1 <- rbind(cbind(cohort="Train (P21-23, 2016-19)",  t1_one(d[d$role=="train",])),
            cbind(cohort="Validation (P26-27, 2021-23)", t1_one(d[d$role=="validation",])))
write.csv(t1, file.path(OUT,"table1_characteristics.csv"), row.names=FALSE)
cat("--- TABLE 1 ---\n"); print(t(t1))

# ---- Figures @300 dpi --------------------------------------------------------
# Fig 1: reliability (from saved CSV)
rel <- read.csv(file.path(OUT,"reliability_valid.csv"))
m <- jsonlite::fromJSON(file.path(OUT,"metrics_primary.json"))
png(file.path(FIG,"fig1_calibration.png"), width=1800, height=1650, res=300)
par(mar=c(4.5,4.5,3,1))
plot(rel$mean_pred, rel$obs_freq, type="b", pch=19, col="#2166AC", lwd=2,
     xlim=c(0,max(rel$mean_pred,rel$obs_freq)), ylim=c(0,max(rel$mean_pred,rel$obs_freq)),
     xlab="Predicted probability (weighted)", ylab="Observed frequency (weighted)",
     main="Calibration - external temporal validation")
abline(0,1,lty=2,col="grey40"); grid()
legend("topleft", bty="n", legend=sprintf("AUC %.3f | slope %.2f", m$auc_valid, m$calib_slope_valid))
dev.off()

# Fig 3: DCA (from saved CSV)
dca <- read.csv(file.path(OUT,"dca_valid.csv"))
png(file.path(FIG,"fig3_dca.png"), width=1900, height=1500, res=300)
par(mar=c(4.5,4.5,3,1))
plot(dca$pt, dca$model, type="l", lwd=2.5, col="#2166AC", ylim=c(-0.01,max(dca$model)*1.1),
     xlab="Threshold probability", ylab="Net benefit (weighted)", main="Decision curve analysis")
lines(dca$pt, dca$prior_cost, lwd=2.5, col="#D6604D")
lines(dca$pt, dca$treat_all, lwd=1.5, col="grey50", lty=2); abline(h=0, col="grey30", lty=3)
legend("topright", c("GBT model","Prior-year cost","Treat all","Treat none"),
       col=c("#2166AC","#D6604D","grey50","grey30"), lwd=c(2.5,2.5,1.5,1), lty=c(1,1,2,3), bty="n")
dev.off()

# Fig 2: SHAP importance (recompute)
va <- d[d$role=="validation",]; model <- lgb.load(file.path(OUT,"lgb_model.txt"))
sv <- shapviz(model, X_pred=as.matrix(va[CANONICAL_FEATURES]), X=as.data.frame(va[CANONICAL_FEATURES]))
ggsave(file.path(FIG,"fig2_shap.png"), sv_importance(sv, kind="bar", max_display=15)+
         ggtitle("SHAP feature importance (validation)")+theme_minimal(base_size=11),
       width=6.5, height=6, dpi=300)
cat("\nFigures written to outputs/figures/ at 300 dpi.\n")
