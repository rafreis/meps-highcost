# PROTOCOL — MEPS High-Cost Risk Prediction (Milestone 1)

**Project:** Predicting Top-Decile Year-2 Health Expenditure from Year-1 MEPS Panel Data
**Target manuscript type:** TRIPOD+AI (2024) prediction-model development and external validation study
**Data source:** Medical Expenditure Panel Survey (MEPS), Household Component, AHRQ
**Document status:** Milestone 1 (M1) protocol — locked design decisions, pre-modeling
**Authored:** 2026-07-08
**Companion documents:** `docs/M1_MULTIAGENT_PLAN.md` (execution plan), `docs/panel_variable_mapping.md` (verified HC-file map), `protocol/TRIPOD-AI_checklist.md`, `docs/literature_review.md`, `R/config.R` (data contract as code)

---

## 1. Objective

To develop and temporally externally validate a prediction model that estimates, using only year-1 (baseline) information, an MEPS panel member's probability of falling into the **top decile of total healthcare expenditure in year 2** — a standard operational definition of "high-cost" status used for care-management targeting and risk-adjustment applications.

Secondary aim: characterize the same year-1 predictors' ability to flag an approximate AHRQ Prevention Quality Indicator (PQI) potentially-avoidable hospitalization signal in year 2, as a clinically interpretable, policy-relevant secondary endpoint, with explicit disclosure of measurement deviations from the exact PQI technical specification (§5).

---

## 2. Design

Retrospective, longitudinal, registry-based (survey) prediction-model study using the MEPS two-year longitudinal panel files. Model development uses three temporally contiguous, pre-pandemic panels; external validation uses two temporally contiguous, post-pandemic panels separated from development by an explicit COVID-era gap (§4). This is a **temporal external validation** design in the TRIPOD+AI sense: the validation panels are disjoint in calendar time from the development panels, sourced from the same underlying survey program but distinct annual samples, sampling frames refreshes, and (for panels 26–27) a materially different healthcare-utilization environment (post-acute-COVID).

---

## 3. Population, unit of analysis, and eligibility

- **Unit of analysis:** MEPS sampled person (`DUPERSID`), observed across the two rounds of a single panel.
- **Eligibility:** any person present in both year-1 and year-2 rounds of a given panel's two-year longitudinal file (i.e., has a non-missing, valid `LONGWT` > 0). Persons who died, were institutionalized, or attrited mid-panel and consequently received `LONGWT = 0` or were dropped from the longitudinal file by AHRQ are excluded, consistent with AHRQ's own longitudinal-weight construction (this is a design property of the data source, not an investigator-imposed exclusion).
- **No additional age, insurance, or condition-based exclusions** are applied at M1. Any such exclusions considered later for clinical-plausibility reasons (e.g., analyzing a subgroup) must be pre-registered as a *sensitivity* analysis, not substituted for the primary analysis.
- **Panels used (§4):** 21, 22, 23 (development); 26, 27 (validation). See `R/config.R::PANEL_MAP` for the authoritative panel-to-file mapping; `HC-236` (the panel-23 four-year file) is explicitly forbidden (§6.4).

---

## 4. Temporal external validation design

| Set | Panels | Years (Y1–Y2) | Role |
|---|---|---|---|
| Development (train) | 21, 22, 23 | 2016–17, 2017–18, 2018–19 | Model fitting, tuning, internal CV |
| **Gap (excluded)** | 24, 25 | 2019–22, 2020–21 | COVID-extended / disrupted panels — deliberately excluded to create a clean temporal break and to avoid contaminating development with pandemic-disrupted utilization patterns |
| External validation (test) | 26, 27 | 2021–22, 2022–23 | Held out entirely from development; used once, at the end, for final performance reporting |

**Rationale for the gap:** Panels 24–25 span the acute COVID-19 disruption (deferred care, telehealth shift, field-collection interruptions) and are structurally different in both AHRQ's data collection (panel 24 was extended to four rounds) and in underlying utilization behavior. Excluding them avoids two failure modes: (a) training on a discontinuous panel that mixes pre- and mid-pandemic behavior, and (b) creating a validation set that is only one year removed from training and could look artificially well-calibrated due to shared secular trend. The chosen gap yields a validation window (2021–2023) that is 2–4 years removed from the end of development (2019), the standard interpretation of "temporal external validation" under TRIPOD+AI item 6b/12.

**Pooling within each set:** Development panels are stacked (person-panel rows) with panel-specific design metadata retained (`panel`, `varstr`, `varpsu`, `longwt`) so that panel-clustered variance can still be recovered; panels are **not** treated as literal replicates of one identical population — panel is available as a covariate/stratifier for sensitivity checks. Validation panels 26 and 27 are pooled the same way and additionally reported panel-by-panel to check validation stability is not driven by one panel alone.

---

## 5. Outcomes

### 5.1 Primary endpoint — top-decile year-2 total expenditure

`top_decile_y2` (binary): 1 if the person's year-2 total healthcare expenditure (`TOTEXPY2`, sourced into canonical column `totexp_y2`) is at or above the **weighted 90th percentile of `TOTEXPY2`, computed separately within each panel**, using that panel's `LONGWT`; 0 otherwise.

**Why per-panel and weighted, not pooled or unweighted:**
- **Per-panel:** nominal healthcare cost inflates over the 2016–2023 window covered by development + validation. A single pooled dollar threshold would let secular cost inflation alone drift the base rate over time (mechanically increasing "high-cost" prevalence in later panels for reasons unrelated to model discrimination). Computing the threshold within each panel makes "top decile" a *relative, within-cohort* definition, so a validation-period base-rate drift would have to come from a genuine change in the *shape* of the cost distribution, not simple inflation.
- **Weighted:** MEPS is a complex probability sample; an unweighted percentile would not estimate the population 90th percentile and would bias the operational threshold toward whatever demographic groups are oversampled in the person-level file.

**Formal definition, panel *p*:**
```
threshold_p = weighted_quantile(TOTEXPY2 | panel = p, weights = LONGWT, prob = 0.90)
top_decile_y2_i = 1[ TOTEXPY2_i >= threshold_p ]   for person i in panel p
```
Implemented via `survey`/`srvyr`'s `svyquantile()` on the panel's survey design object (`R/config.R::make_survey_design()`), not a naive `Hmisc::wtd.quantile()`-style call, so that the quantile estimator is consistent with the complex design (stratification + clustering) used everywhere else in the study.

**Expected base rate check:** by construction, the weighted base rate of `top_decile_y2` should be ≈10% in *every* panel (development and validation alike). This is audited as invariant 2 in M1 (§9) and re-checked as a standing sanity check whenever a new panel is added.

### 5.2 Transition sensitivity analysis

Because the primary endpoint is a *relative* (within-panel-percentile) definition, it is insensitive to overall cost-level shifts by design — which is a feature for the primary analysis but means it cannot, by itself, tell us whether a validation-panel member who is "top decile" would also have cleared an *absolute*, inflation-adjusted cost bar. We therefore report a secondary/sensitivity version of the outcome:

- **Absolute-threshold transition indicator:** using the development-panel-pooled weighted 90th percentile of `TOTEXPY2` (single dollar threshold, computed once on panels 21–23 pooled, weighted), converted to validation-panel dollars using the Consumer Price Index for Medical Care (CPI-M, U.S. BLS) to the validation panel's midpoint year. Applied to panels 26–27 to produce `top_decile_y2_abs`.
- **Transition analysis:** cross-tabulate `top_decile_y2` (relative, per-panel) against `top_decile_y2_abs` (absolute, inflation-adjusted) within panels 26–27, weighted, to quantify how many people are "top decile" under one definition but not the other (i.e., whether the relative definition is being driven by real distributional change vs. pure price-level drift). Report weighted percent agreement, weighted kappa, and the count/percent in each of the four transition cells (relative+/abs+, relative+/abs−, relative−/abs+, relative−/abs−).
- **Model performance is reported against the primary (relative, per-panel) endpoint.** The transition analysis is descriptive/diagnostic only — it is not used to retrain or re-threshold the model — and is reported alongside validation results so a reader can judge whether "high cost" in the validation panels means the same thing in absolute-dollar terms as it did in development.

### 5.3 Secondary endpoint — approximate AHRQ Prevention Quality Indicator (PQI) signal

**Endpoints of interest:** AHRQ PQI #08 (Heart Failure Admission Rate) and PQI #05 (COPD or Asthma in Older Adults Admission Rate), the two PQIs most directly tied to chronic-condition management that a year-1 feature set (conditions + prior utilization) is plausible to predict.

**⚠️ Documented deviation from the exact AHRQ PQI v2024 technical specification.** The official PQI algorithm is defined on ICD-10-CM diagnosis codes at full specificity, applied to *inpatient claims/discharge* records with precise principal-diagnosis and exclusion logic (e.g., transfers, obstetric exclusions, specific comorbidity exclusion lists), typically computed from hospital discharge data (e.g., HCUP SID) rather than household-survey self-report. MEPS Household Component data cannot reproduce this exactly because:

1. MEPS condition and event files provide **CCSR (Clinical Classifications Software Refined) categories and/or 3-digit ICD-10-CM roots**, not full 5–7 character ICD-10-CM codes with the granularity the PQI numerator/denominator/exclusion logic requires.
2. MEPS Hospital Inpatient Stays event files identify *that* a hospitalization occurred and link to condition records via the `CLNK`/appendix files (`R/config.R::EVENT_FILES`), but do not carry a discharge abstract with principal-diagnosis-vs-secondary-diagnosis distinction the way discharge-record data does.
3. Person-level, self-reported/interview-collected condition ascertainment in MEPS is not a substitute for the claims/discharge-abstract-level exclusion criteria (e.g., PQI's exclusions for patients with specific comorbid conditions, transfers from other institutions) that the official algorithm applies at the *stay* level.

**Our approximation, precisely stated:** a year-2 hospital inpatient stay is flagged as an **approximate PQI-08 event** if (a) the stay's linked condition record (via `CLNK`) maps to a CCSR category corresponding to heart failure (CCSR `CIR019`) or a 3-digit ICD-10-CM root in `I50`, and as an **approximate PQI-05 event** if the linked condition maps to CCSR respiratory categories for COPD/asthma (CCSR `RSP002`/`RSP008`, or 3-digit roots in `J44`, `J45`) — **without** applying the official specification's admission-type restriction, transfer exclusion, age-conditioned denominator (PQI-05 is nominally "older adults," conventionally 40+ in the official spec), or comorbidity-exclusion list beyond what is directly reconstructible from available condition/event linkage. This is disclosed in the manuscript as an explicit **measurement deviation**, not presented as the certified AHRQ PQI rate, and will be labeled throughout as "CCSR/3-digit-ICD **approximate** PQI-08/05 flag" — never as "PQI-08/05" unqualified. `protocol/TRIPOD-AI_checklist.md` documents this under the outcome-definition items, and `docs/panel_variable_mapping.md` documents the exact CCSR/ICD-root crosswalk used per panel-year.

The secondary endpoint is reported for descriptive/exploratory purposes (discrimination of the approximate flag by the same year-1 feature set) and is **not** used for any go/no-go decision in M1 or for primary-model selection in M2.

---

## 6. Predictors and the leakage firewall

### 6.1 Predictor window

All candidate predictors are drawn **exclusively from year-1** (baseline) MEPS files: person/demographic and Full-Year Consolidated (FYC) variables, year-1 medical conditions (CCSR-coded), year-1 prescribed-medicine event counts/classes, year-1 inpatient-stay counts, and `totexp_y1` (year-1 total expenditure) as a prior-cost benchmark feature. No year-2 information of any kind is eligible as a predictor.

### 6.2 Canonical schema and naming convention

Every derived per-panel file (`data/derived/panel_<NN>.rds`) exposes an identical schema (`R/config.R::CANONICAL_COLUMNS`):

```
dupersid, panel, year1, year2, totexp_y1, totexp_y2, top_decile_y2,
longwt, varstr, varpsu,  f_*  (all year-1 predictor features)
```

All model-eligible predictors **must** carry the `f_` prefix. This is enforced, not just documented: `R/config.R::is_model_eligible()` returns `TRUE` only for columns matching `^f_` or in `DESIGN_COLUMNS` (`longwt`, `varstr`, `varpsu`).

### 6.3 GOLDEN LEAKAGE RULE

> Only `f_*` (year-1 feature) and design columns (`longwt`, `varstr`, `varpsu`) are model-eligible. Any column matching `*_y2` — with the single exception of the target `top_decile_y2` itself — is forbidden from ever entering a model matrix, feature-importance computation, or SHAP explanation downstream of feature assembly.

**Programmatic guard:** `R/config.R::assert_no_leakage(colnames)` scans candidate model-matrix column names with `grepl("_y2$", ..., ignore.case = TRUE)` and throws a hard error naming any forbidden column, excluding only `top_decile_y2`. This function **must** be called immediately before any `model.matrix()`/`recipe()`/training-data assembly step in M2, in both the development pipeline and the validation-scoring pipeline (a validation-set leak is just as disqualifying as a training-set leak). Any change to the feature-engineering script that adds a new `_y2`-suffixed column must pass through this guard before the pipeline is considered mergeable.

**Rationale for a hard runtime assertion over a code-review convention alone:** feature engineering in M2 will fan out per-domain (conditions, RX, inpatient, demographics) and be authored/edited iteratively; a naming-convention-only safeguard is fragile to a single careless join. A failing assertion that halts the pipeline is the cheapest possible catch for the single most damaging error class in a prediction-model study (an inflated, non-reproducible AUC from outcome leakage).

### 6.4 Forbidden files

`HC-236` (the panel-23 **four-year** longitudinal file, 2018–2021) must never be substituted for `HC-217` (panel 23's correct two-year file). `HC-236`'s `LONGWT` is a four-year longitudinal weight, incompatible with the two-year design used everywhere else in this study; mixing it in would silently corrupt both the survey design and the panel-23 target definition. `R/config.R::FORBIDDEN_FILES` encodes this, and `PANEL_MAP` simply never references it. Invariant 4 (§9) is an adversarial re-check of this specifically.

---

## 7. Survey design

MEPS is a complex, multistage, stratified, clustered probability sample. All descriptive statistics, the target-threshold computation (§5.1), and all model performance metrics reported for the primary manuscript (AUC, calibration, PPV/NPV at threshold, DCA net benefit) must be computed under the survey design — never as naive unweighted / non-clustered statistics — because:

1. Ignoring clustering (`VARPSU`) understates standard errors (repeated PSU sampling induces positive intra-cluster correlation for expenditure and utilization outcomes).
2. Ignoring stratification (`VARSTR`) forfeits the variance reduction the design provides and, if mishandled, can misstate degrees of freedom.
3. Ignoring the person weight biases point estimates away from the U.S. civilian non-institutionalized population MEPS is designed to represent.

**Weight:** `LONGWT`, the **two-year longitudinal person weight**, exclusively. `R/config.R::FORBIDDEN_WEIGHT_PATTERN` (`^(PERWT[0-9]{2}F|SAQWT[0-9]{2}F)$`) documents the annual cross-sectional weights that must **never** be used in this study — they are calibrated to a single year's cross-section and are not the correct weight for a two-year longitudinal analytic file. This is invariant 1 in the M1 audit (§9): every weighted estimate in every deliverable is checked to confirm `LONGWT` was the weight actually passed to `svydesign`/`as_survey_design`.

**Design object:** built via `R/config.R::make_survey_design()`:
```r
srvyr::as_survey_design(df, ids = varpsu, strata = varstr, weights = longwt, nest = TRUE)
```
`nest = TRUE` because PSU codes are only unique within strata across MEPS panels/years, per AHRQ guidance.

**Pooled development design:** panels 21–23 are stacked before constructing the design object, retaining `panel` as an available stratifying/covariate column; AHRQ's standard guidance for pooling multiple panels' longitudinal files (rescaling weights by number of panels combined, or leaving `LONGWT` as-is and treating `panel` as an additional design factor) will be finalized in M2 and stated explicitly in the analysis code and manuscript methods — this protocol commits only to *never* dropping the design (ids/strata/weights) when pooling, not yet to the specific pooling/rescaling convention, which depends on which pooled-estimation guidance AHRQ publishes for the specific panel-set combination used here.

**Validation design:** panels 26–27 get their own pooled survey design object, built and used identically, and kept strictly separate from the development design object (no design object, model object, or derived threshold computed on development data is allowed to touch validation rows before the single final validation scoring pass).

---

## 8. Modeling plan for M2 (scope preview — not executed in M1)

M1 delivers the target, features, and validated data contract; M2 executes modeling. This protocol commits M2 to the following, subject to refinement in the M2 planning doc:

1. **Candidate model:** gradient-boosted trees (GBT) as the primary model class, chosen for its established strong performance on tabular MEPS-scale prediction tasks and native handling of mixed categorical/continuous, sparse condition/RX indicator features, plus a simple logistic-regression baseline (survey-weighted) for interpretability comparison.
2. **Internal validation:** cross-validation within the pooled development panels (21–23), respecting panel and, where feasible, PSU-level grouping to avoid within-cluster leakage between folds.
3. **Calibration:** report calibration curves/slope/intercept on both internal CV and external validation; recalibration (e.g., Platt scaling or isotonic) considered only if development-panel calibration is materially off and must be fit on development data only, then frozen before touching validation panels.
4. **Explainability:** SHAP values computed only on `f_*`/design-eligible features (the same leakage guard applies to any SHAP feature matrix).
5. **External validation (temporal):** a single, final scoring pass of the frozen development-fitted model on panels 26–27 (§4); no re-fitting, re-thresholding, or feature selection is permitted after this pass.
6. **Decision-curve analysis (DCA):** primary model vs. a simple prior-year-cost-only baseline (`totexp_y1`-based rule), across a clinically plausible range of threshold probabilities, on the external validation set.
7. **Subgroup performance:** calibration and DCA reported by income category and race/ethnicity subgroups (as available in MEPS demographic variables), consistent with TRIPOD+AI's fairness-reporting expectations; subgroup analyses are descriptive/monitoring, not used to alter the single frozen model.
8. **Secondary-endpoint modeling** (approximate PQI-08/05 flags, §5.3): discrimination-only reporting (e.d., AUC) using the same frozen feature set; explicitly not optimized or tuned as a separate target.

Full M2 modeling detail (hyperparameter search space, exact recalibration method, exact subgroup cut-points) is deferred to the M2 planning document, produced only after M1's go/no-go (§9) passes.

---

## 9. M1 go/no-go: adversarially audited invariants

Milestone 1 is not considered complete until each of the following five invariants is checked by an adversarial audit pass (default verdict = FAIL when evidence is ambiguous), per `docs/M1_MULTIAGENT_PLAN.md` §3:

1. **Longitudinal weight** — `LONGWT` used in every weighted estimate; no `PERWTxxF`/`SAQWTxxF` leak anywhere.
2. **Per-panel threshold** — `top_decile_y2` = weighted 90th percentile of `TOTEXPY2` computed *within* each panel; weighted base rate ≈10% in every panel.
3. **Leakage firewall** — no `*_y2` column (besides the target) reachable from any model-matrix assembly point; `assert_no_leakage()` passes on both development and validation pipelines.
4. **Mapping fidelity** — panel↔year↔HC-file mapping matches AHRQ's published documentation; `HC-236` was not substituted for `HC-217`.
5. **Population totals** — weighted totals from the derived panel files reproduce AHRQ's published civilian non-institutionalized population counts within rounding, for each panel.

M2 does not start until all five pass (or documented, user-accepted exceptions are recorded here with rationale).

---

## 10. Reproducibility

- Raw MEPS downloads are checksummed on receipt (`data/raw/<hc>/CHECKSUMS.txt`, produced by the prep stage).
- Package versions pinned via `renv.lock`; `R/config.R` fails fast (`.check_required_packages()`) if a required package is missing rather than silently proceeding with an unpinned version.
- All pipeline scripts are deterministic and re-runnable: no interactive prompts, no wall-clock-dependent branching, explicit `set.seed()` wherever randomness is introduced (e.g., CV fold assignment in M2).
- Every derived file's schema is validated against `CANONICAL_COLUMNS` before being written, so a downstream script can assume identical structure across all five panels without defensive re-checking.

---

## 11. Change control

This protocol reflects the design decisions locked with the user as of 2026-07-08 (`docs/M1_MULTIAGENT_PLAN.md` §0). Any change to the outcome definition, panel set, weight variable, or leakage rule after M2 modeling begins must be recorded as a dated amendment in this file (new "§12 Amendments" section, appended — not silently edited into the sections above) to preserve an auditable protocol history, consistent with TRIPOD+AI's expectation that pre-specified analysis choices are distinguishable from post-hoc ones.
