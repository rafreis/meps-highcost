# =============================================================================
# meps-highcost / R/m3_figures_pub.R   (peer-review revision)
# Publication figures, one shared font + Okabe-Ito palette across all three.
# Reviewer asks addressed: larger axis/label fonts for column width; predicted-
# risk distribution under the calibration curve; design-based CIs on the binned
# calibration points and on the decision curve; explicit colour-bar label;
# thicker DCA lines clipped to the actionable threshold range.
# =============================================================================
source("R/config.R"); source("R/feature_contract.R")
suppressPackageStartupMessages({ library(lightgbm); library(shapviz); library(ggplot2)
  library(patchwork) })
FIG <- "outputs/figures"; dir.create(FIG, showWarnings = FALSE); set.seed(42)

OK <- c(blue="#0072B2", vermillion="#D55E00", grey="#7F7F7F", ink="#222222")
BASE <- 15
theme_pub <- function(base = BASE) theme_minimal(base_size = base, base_family = "sans") +
  theme(panel.grid.minor = element_blank(),
        panel.grid.major = element_line(color = "grey92", linewidth = 0.3),
        axis.title = element_text(color = "grey20", size = base),
        axis.text  = element_text(color = "grey30", size = base - 2),
        plot.title = element_text(face = "bold", size = base + 1, color = "grey10"),
        plot.subtitle = element_text(color = "grey35", size = base - 2),
        legend.position = "top", legend.title = element_blank(),
        legend.text = element_text(size = base - 2),
        plot.title.position = "plot", plot.margin = margin(10, 14, 8, 10))

d <- readRDS("data/derived/pooled.rds"); d$panel <- as.character(d$panel)
va <- d[d$role == "validation", ]; model <- lgb.load(file.path("outputs/m2","lgb_model.txt"))
clamp <- function(p) pmin(pmax(p, 1e-6), 1 - 1e-6)
va$p <- clamp(predict(model, as.matrix(va[CANONICAL_FEATURES])))
y <- va$top_decile_y2; w <- va$longwt

## ---- Figure 1: calibration (with design-based CIs) + risk distribution ------
wq <- function(x,ww,q){o<-order(x);x<-x[o];ww<-ww[o];x[which(cumsum(ww)/sum(ww)>=q)[1]]}
brks <- unique(c(-Inf, vapply(seq(.1,.9,.1), function(q) wq(va$p,w,q), numeric(1)), Inf))
bin  <- cut(va$p, brks, include.lowest = TRUE)
obs_by_bin <- function(ix_all) vapply(levels(bin), function(b){
  ix <- ix_all[bin[ix_all]==b]; if(!length(ix)) return(NA_real_)
  sum(w[ix]*y[ix])/sum(w[ix]) }, numeric(1))
rel <- data.frame(bin = levels(bin),
  mean_pred = vapply(levels(bin), function(b){ ix<-which(bin==b); sum(w[ix]*va$p[ix])/sum(w[ix]) }, numeric(1)),
  obs_freq  = obs_by_bin(seq_len(nrow(va))),
  wn        = vapply(levels(bin), function(b) sum(w[bin==b]), numeric(1)))
# cluster bootstrap CI for the observed frequency in each fixed bin
cl <- as.integer(factor(paste(va$panel, va$varstr, va$varpsu)))
idx_by_cl <- split(seq_along(cl), cl); ucl <- seq_along(idx_by_cl)
B <- 400; boot <- matrix(NA_real_, B, length(levels(bin)))
for (b in seq_len(B)) boot[b,] <- obs_by_bin(unlist(idx_by_cl[sample(ucl, length(ucl), replace=TRUE)], use.names=FALSE))
rel$lo <- apply(boot, 2, quantile, .025, na.rm=TRUE); rel$hi <- apply(boot, 2, quantile, .975, na.rm=TRUE)
write.csv(rel, "outputs/m2/reliability_valid.csv", row.names = FALSE)

lim <- max(rel$mean_pred, rel$hi, na.rm=TRUE) * 1.02
g1a <- ggplot(rel, aes(mean_pred, obs_freq)) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey60", linewidth = 0.6) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0, color = OK[["blue"]], alpha = 0.55, linewidth = 0.8) +
  geom_line(color = OK[["blue"]], linewidth = 1.1) +
  geom_point(color = OK[["blue"]], fill = "white", shape = 21, size = 3.2, stroke = 1.3) +
  coord_equal(xlim = c(0, lim), ylim = c(0, lim)) +
  labs(x = NULL, y = "Observed frequency",
       title = "Calibration in external temporal validation",
       subtitle = "Weighted AUC 0.857 (95% CI 0.842-0.869); calibration slope 0.93") +
  annotate("text", x = lim*0.66, y = lim*0.24, label = "Perfect calibration", color = "grey50",
           angle = 38, size = 4.2) + theme_pub()
g1b <- ggplot(va, aes(p, weight = longwt)) +
  geom_histogram(bins = 60, fill = OK[["blue"]], alpha = 0.85, color = NA) +
  scale_x_continuous(limits = c(0, lim)) +
  labs(x = "Predicted probability of high cost (weighted)", y = "Persons") +
  theme_pub(BASE - 1) + theme(axis.text.y = element_blank(), panel.grid.major.y = element_blank())
ggsave(file.path(FIG,"fig1_calibration.png"), g1a / g1b + plot_layout(heights = c(3.2, 1)),
       width = 7.0, height = 7.4, dpi = 400, bg = "white")

## ---- Figure 2: SHAP beeswarm ------------------------------------------------
LAB <- c(f_totexp="Prior-year total expenditure", f_totslf="Prior-year out-of-pocket",
  f_rxtot="Prescription fills (yr 1)", f_age="Age", f_sex="Sex", f_famsze="Family size",
  f_obtotv="Office-based visits (yr 1)", f_obdrv="Office visit providers (yr 1)",
  f_optotv="Outpatient visits (yr 1)", f_ertot="Emergency visits (yr 1)",
  f_ipdis="Inpatient discharges (yr 1)", f_ipngtd="Inpatient nights (yr 1)",
  f_dvtot="Dental visits (yr 1)", f_hhtotd="Home-health days (yr 1)",
  f_rthlth1="Perceived physical health (R1)", f_rthlth2="Perceived physical health (R2)",
  f_mnhlth2="Perceived mental health (R2)", f_adgenh2="General health rating",
  f_addaya2="Days activity-limited", f_actlim1="Activity limitation",
  f_asthdx="Asthma diagnosis", f_chddx="Coronary heart disease", f_ohrtdx="Other heart disease",
  f_hibpdx="Hypertension", f_povlev="Poverty level (% FPL)", f_povcat="Poverty category",
  f_marry="Marital status", f_region="Census region", f_racethx="Race/ethnicity",
  f_inscov="Insurance coverage", f_insc="Insurance status", f_unins="Uninsured")
readable <- function(f) if (f %in% names(LAB)) unname(LAB[[f]]) else tools::toTitleCase(gsub("_"," ", sub("^f_","",f)))
sv <- shapviz(model, X_pred = as.matrix(va[CANONICAL_FEATURES]), X = as.data.frame(va[CANONICAL_FEATURES]))
S <- sv$S; X <- sv$X
nm <- make.unique(vapply(colnames(S), readable, character(1)))
colnames(S) <- nm; colnames(X) <- nm
g2 <- sv_importance(shapviz(S, X = X), kind = "beeswarm", max_display = 15,
                    viridis_args = list(option = "mako", begin = 0.1, end = 0.9,
                                        name = "Feature value (low to high)")) +
  labs(title = "Feature contributions (SHAP) in external validation",
       x = "SHAP value (impact on predicted log-odds of high cost)") +
  theme_pub() + theme(legend.position = "right", legend.title = element_text(size = BASE - 3, angle = 90))
ggsave(file.path(FIG,"fig2_shap.png"), g2, width = 9.0, height = 6.8, dpi = 400, bg = "white")

## ---- Figure 3: decision curve with CIs, clipped to actionable range ---------
dca <- read.csv("outputs/m2/dca_valid.csv")
dca <- dca[dca$pt >= 0.02 & dca$pt <= 0.30, ]
long <- rbind(
  data.frame(pt=dca$pt, nb=dca$model,      strategy="GBT model"),
  data.frame(pt=dca$pt, nb=dca$prior_cost, strategy="Prior-year cost"),
  data.frame(pt=dca$pt, nb=dca$treat_all,  strategy="Treat all"),
  data.frame(pt=dca$pt, nb=dca$treat_none, strategy="Treat none"))
long$strategy <- factor(long$strategy, levels=c("GBT model","Prior-year cost","Treat all","Treat none"))
g3 <- ggplot() +
  geom_ribbon(data=dca, aes(pt, ymin=model_lo, ymax=model_hi), fill=OK[["blue"]], alpha=0.18) +
  geom_ribbon(data=dca, aes(pt, ymin=prior_lo, ymax=prior_hi), fill=OK[["vermillion"]], alpha=0.16) +
  geom_line(data=long, aes(pt, nb, color=strategy, linetype=strategy), linewidth=1.4) +
  scale_color_manual(values=c("GBT model"=OK[["blue"]], "Prior-year cost"=OK[["vermillion"]],
                              "Treat all"=OK[["grey"]], "Treat none"=OK[["ink"]])) +
  scale_linetype_manual(values=c("GBT model"="solid","Prior-year cost"="solid",
                                 "Treat all"="dashed","Treat none"="dotted")) +
  coord_cartesian(ylim=c(-0.005, max(dca$model_hi)*1.05), xlim=c(0.02, 0.30)) +
  labs(x="Threshold probability", y="Net benefit (weighted)",
       title="Decision-curve analysis in external validation",
       subtitle="Bands: 95% CIs from a design-based cluster bootstrap (400 replicates)") +
  theme_pub()
ggsave(file.path(FIG,"fig3_dca.png"), g3, width = 7.6, height = 5.6, dpi = 400, bg = "white")
cat("Revised publication figures written (400 dpi, shared font/palette).\n")
