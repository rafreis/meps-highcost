# Methods Justification — theoretical applicability under complex survey design

**Purpose.** Every method in this study must be justified for its applicability to MEPS's **complex survey design** (sampling weights + stratification + clustering), not merely for general popularity. This document records that justification with citations; it feeds `protocol/PROTOCOL.md` and the TRIPOD+AI methods items. Where a method's design-based warrant is weak or the literature is thin, we say so and state the transparent handling.

**Standing rule.** Point estimates are design-based (weighted via `LONGWT`, with `VARSTR`/`VARPSU`); where closed-form design variance for a composite quantity is not established, variance/CIs come from **replicate-weight resampling (BRR/jackknife)** via the `survey` package, and the extension is disclosed as a limitation.

---

## 1. Target / estimand — survey-weighted 90th percentile, per panel
**Verdict: strong warrant.** The finite-population quantile is a valid design-based estimand with linearization/test-inversion variance under stratified cluster sampling.
- Francisco CA, Fuller WA. Quantile estimation with a complex survey design. *Ann Statist.* 1991;19(1):454–69.
- Lumley T. `survey::svyquantile` (qrule vignette), R `survey` package.

**Application:** `top_decile_y2` = weighted 90th percentile of `TOTEXPY2` computed **within each panel** (cost inflation forbids a frozen threshold). Base rate ≈10% per panel by construction.

## 2. Survey weights in the model — GBT with case weights
**Verdict: evidence-based** for targeting the finite population; weighted empirical-risk minimization. Unweighted GBT inflates performance vs. the weighted population model.
- MacNell N, et al. Implementing machine learning methods with complex survey data: lessons learned on the impacts of accounting sampling weights in gradient boosting. *PLOS ONE.* 2023;18(1):e0280387.
- Wooldridge JM. Inverse probability weighted M-estimators for sample selection, attrition, and stratification. *Portuguese Econ J.* 2002;1:141–54.

**Application:** LightGBM/XGBoost trained with `sample_weight = LONGWT`; all performance/calibration metrics computed design-based.

## 3. Pooling panels
**Verdict: AHRQ operational guidance; formal theory thin — disclosed.** When pooling *n* panels, divide the longitudinal weight by *n* for average (not cumulative) estimates; use a consistent variance structure.
- AHRQ MEPS longitudinal file documentation; IPUMS-MEPS variance user notes (`userNotes_variance`).

**Application:** train pool = P21+P22+P23; `LONGWT/3` for pooled population-level estimands. Panel-level metrics use native per-panel `LONGWT`. Caveat (differential attrition across panels) disclosed.

## 4. Missing data
**Verdict: sound theory, thinner survey-specific practice.** MEPS negative codes (−1/−7/−8/−9/−15) recoded to `NA` first. Design-based multiple imputation (impute with design variables; Rubin's rules). Avoid the **standalone** missing-indicator method (biased); MI **with** indicators is acceptable for prediction under suspected MNAR.
- Rubin DB. *Multiple Imputation for Nonresponse in Surveys.* Wiley; 1987.
- Groenwold RHH, et al. Missing covariate data in clinical research: when and when not to use the missing-indicator method. *CMAJ.* 2012;184(11):1265–9.
- Sisk R, Sperrin M, Peek N, van Smeden M, Martin GP. Imputation and missing indicators for handling missing data … clinical prediction models: a simulation study. *Stat Methods Med Res.* 2023;32(8):1461–77.

## 5. Feature selection — DESIGN-BASED (primary); Boruta rejected as primary
**Verdict: Boruta has NO valid warrant under complex survey design.** It assumes iid observations, wraps random-forest importance, and tests via a binomial over independent RF iterations — all violated by weighting, stratification, and clustering; no survey adaptation is published. Using survey weights as RF/GBT case weights for *importance-based selection* is a heuristic, not design-consistent.
- Kursa MB, Rudnicki WR. Feature selection with the Boruta package. *J Stat Softw.* 2010;36(11). *(iid basis — cited to justify why it is demoted, not used as primary.)*

**Design-valid primary selector (what we use):**
1. **Unsupervised filters (train-only, design-aware):** recode missings → drop features with >40% missing; drop features whose weighted minority-class prevalence <1% (near-zero variance); drop one of each redundant pair with |ρ|>0.90 (weighted Spearman / Cramér's V).
2. **Design-based relevance:** Rao–Scott Wald univariate screen (`survey::regTermTest` on `svyglm`) and multivariable **survey-weighted LASSO with design-based cross-validation** (replicate-weight CV, PSUs/strata kept intact).
   - Rao JNK, Scott AJ. On chi-squared tests for multiway tables with cell proportions estimated from survey data. *Ann Statist.* 1984;12(1):46–60.
   - Lumley T, Scott A. AIC and BIC for modelling with complex survey data. *J Surv Stat Methodol.* 2015;3(1):1–18.
   - Iparragirre A, Lumley T, Barrio I, Arostegui I. Variable selection with LASSO regression for complex survey data. *Stat.* 2023;12(1):e578. (`wlasso` R package.)
3. **Force-include (never dropped):** `totexp_y1` (DCA benchmark + strongest predictor), age, sex, race/ethnicity, poverty/income, insurance (clinical face validity + fairness subgroups).
4. **Boruta:** reported ONLY as a labeled **sensitivity analysis** (sample-descriptive importance), explicitly not the design-consistent selector.

**Selection guardrails:** training panels only (P21/22/23); validation panels (P26/27) locked away; selection inside CV to avoid optimism; thresholds pre-registered in `PROTOCOL.md`.

## 6. Calibration (M2) — declared gap
**Verdict: standalone methods sound; survey-weighted calibration metrics under-developed → disclosed.** Compute design-based (weighted) calibration curves / calibration-in-the-large / slope; variance via replicate weights.
- Platt J. Probabilistic outputs for support vector machines. In *Advances in Large Margin Classifiers*, MIT Press; 1999:61–74.
- Zadrozny B, Elkan C. Transforming classifier scores into accurate multiclass probability estimates. *KDD* 2002:694–9.
- Van Calster B, et al. A calibration hierarchy for risk models. *J Clin Epidemiol.* 2016;74:167–76.
- Van Calster B, et al. Calibration: the Achilles heel of predictive analytics. *BMC Med.* 2019;17:230.

## 7. Decision curve analysis (M2) — declared gap
**Verdict: net-benefit definition established; survey-weighted DCA not formally validated → disclosed.** Plug **design-based** sensitivity/specificity/prevalence into the net-benefit formula; benchmark vs. prior-year cost (`totexp_y1`); variance via replicate weights. Design-based ROC/AUC precedent supports the components.
- Vickers AJ, Elkin EB. Decision curve analysis: a novel method for evaluating prediction models. *Med Decis Making.* 2006;26(6):565–74.
- (Design-based sensitivity/specificity & AUC for complex survey data — *Survey Methodology* literature.)

## 8. SHAP (M2) — declared gap
**Verdict: attribution sound; design-based variance of population SHAP summaries is an open gap → disclosed.** TreeSHAP for the model; population importance = weighted mean |SHAP| (Σ wᵢ|SHAPᵢ|/Σ wᵢ); variance via replicate weights.
- Lundberg SM, Lee S-I. A unified approach to interpreting model predictions. *NeurIPS* 2017.
- Lundberg SM, et al. From local explanations to global understanding with explainable AI for trees. *Nat Mach Intell.* 2020;2:56–67.

## 9. Temporal external validation
**Verdict: standard, endorsed.** Train earlier panels, validate on non-overlapping later panels (post-COVID) — a strong generalizability test aligned with TRIPOD+AI. Excluded gap panels (P24/P25) give clean temporal separation.
