# Regenerate Figure 2 (SHAP) with human-readable feature labels, 300 dpi.
source("R/config.R"); source("R/feature_contract.R")
suppressPackageStartupMessages({ library(lightgbm); library(shapviz); library(ggplot2) })
FIG <- "outputs/figures"

LAB <- c(
  f_totexp="Prior-year total expenditure", f_totslf="Prior-year out-of-pocket spending",
  f_rxtot="Prescription fills (yr 1)", f_age="Age", f_sex="Sex", f_famsze="Family size",
  f_obtotv="Office-based visits (yr 1)", f_obdrv="Office visit providers (yr 1)",
  f_optotv="Outpatient visits (yr 1)", f_ertot="Emergency visits (yr 1)",
  f_ipdis="Inpatient discharges (yr 1)", f_ipngtd="Inpatient nights (yr 1)",
  f_dvtot="Dental visits (yr 1)", f_hhtotd="Home-health days (yr 1)",
  f_rthlth1="Perceived physical health (R1)", f_rthlth2="Perceived physical health (R2)",
  f_mnhlth2="Perceived mental health (R2)", f_adgenh2="General health rating (R2)",
  f_addaya2="Days activity-limited (R2)", f_actlim1="Activity limitation",
  f_wlklim1="Walking limitation", f_coglim1="Cognitive limitation", f_soclim1="Social limitation",
  f_aidhlp1="Needs help with ADLs", f_iadlhp1="Needs help with IADLs", f_haveus2="Usual source of care",
  f_asthdx="Asthma diagnosis", f_chddx="Coronary heart disease dx", f_ohrtdx="Other heart disease dx",
  f_hibpdx="Hypertension diagnosis", f_midx="Prior myocardial infarction", f_strkdx="Prior stroke",
  f_emphdx="Emphysema/COPD diagnosis", f_arthdx="Arthritis diagnosis", f_cancer="Cancer diagnosis",
  f_povcat="Poverty category", f_povlev="Poverty level (% FPL)", f_faminc="Family income",
  f_ttlp="Total personal income", f_foodst="Food-stamp receipt", f_marry="Marital status",
  f_region="Census region", f_ruclas="Rural/urban class", f_racethx="Race/ethnicity", f_hispanx="Hispanic ethnicity",
  f_inscov="Insurance coverage", f_insurc="Insurance type", f_insc="Insurance status", f_ins="Any insurance",
  f_unins="Uninsured", f_mcrev="Medicare (ever)", f_prvev="Private (ever)", f_trich="TRICARE/CHAMPVA",
  f_prvhmo="Private HMO", f_pmdins="Private managed care")
readable <- function(f) if (f %in% names(LAB)) unname(LAB[[f]]) else tools::toTitleCase(gsub("_"," ", sub("^f_","",f)))

d <- readRDS("data/derived/pooled.rds"); va <- d[d$role=="validation",]
model <- lgb.load(file.path("outputs/m2","lgb_model.txt"))
sv <- shapviz(model, X_pred=as.matrix(va[CANONICAL_FEATURES]), X=as.data.frame(va[CANONICAL_FEATURES]))
S <- sv$S; X <- sv$X
nm <- make.unique(vapply(colnames(S), readable, character(1)))
colnames(S) <- nm; colnames(X) <- nm
sv2 <- shapviz(S, X = X)
ggsave(file.path(FIG,"fig2_shap.png"),
       sv_importance(sv2, kind="bar", max_display=15) +
         ggtitle("SHAP feature importance (external validation)") +
         xlab("Mean(|SHAP value|)") + theme_minimal(base_size=11),
       width=7.2, height=6, dpi=300)
cat("fig2_shap.png regenerated with readable labels.\n")
