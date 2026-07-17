# TRIPOD+AI 2024 Checklist: MEPS High-Cost Prediction Study

**Study Title:** Predicting Year-2 High-Cost Status (Top Decile) from Year-1 Clinical and Demographic Features in MEPS 2-Year Longitudinal Panels: A Survey-Weighted Machine Learning Approach with External Validation

**Journal Target:** JPMedAI (invited submission)

**Corresponding Author:** Rafael dos Reis (rafreis2@gmail.com)

**Date Initiated:** 2026-07-08

**Last Updated:** 2026-07-08

---

## A. Title and Abstract

### A.1 Title
**Status:** ✓ DECIDED  
**Rationale:** Explicitly names prediction target (high-cost/top decile), population (MEPS 2-yr panels), predictors (year-1 features), and design feature (survey-weighted external validation).

**Title:** Predicting Year-2 High-Cost Status from Year-1 Features in MEPS 2-Year Longitudinal Panels: A Survey-Weighted Machine Learning Study with External Temporal Validation and Subgroup Analysis

---

### A.2 Abstract Structure
**Status:** ✓ DECIDED  
- Background: Health cost prediction complexity, value of risk stratification
- Objective: Predict top-decile year-2 TOTEXP from year-1 features
- Methods: MEPS 2-yr panels; survey design; LightGBM/XGBoost; external validation
- Results: AUROC, calibration, subgroup performance, DCA
- Conclusions: Survey design + external validation critical; subgroup disparities

---

## B. Background and Objectives

### B.1 Background (Study Rationale)
**Status:** ✓ DECIDED  
**Content:**
- High-cost patients account for disproportionate healthcare spending
- Prior work: Yang & Delen 2018 (MEPS, HCHN); recent ML ensemble studies (JMIR Med Inform 2026)
- **Gap:** Most prior studies ignore survey design; limited external temporal validation; minimal fairness/subgroup calibration
- **Need:** Robust, externally validated, equitable prediction model with decision-curve guidance

**References to Include:**
- Yang et al. (2018): BioMedEngOnline, PMC6245495
- Recent ensemble work: JMIR Med Inform 2026, PMC12966819
- PLOS One claims-data high-cost studies (pending specific cites)

---

### B.2 Objectives and Hypotheses
**Status:** ✓ DECIDED

**Primary Objective:**  
Develop and externally validate a survey-weighted machine learning model to predict year-2 high-cost status (top decile of TOTEXP) from year-1 features.

**Secondary Objectives:**
1. Evaluate model calibration across income and race/ethnicity subgroups
2. Conduct decision-curve analysis (DCA) comparing prediction model to prior-year cost (TOTEXPY1) benchmark
3. Characterize feature importance via SHAP
4. Quantify temporal stability of relationships (Panel 21/22/23 → 26/27)

**Hypotheses:**
- H0: Survey-design-adjusted AUROC ≥ 0.75 (on validation set)
- H1: No material subgroup AUC disparity (max difference <0.05) by race/ethnicity
- H2: DCA demonstrates clinical benefit of model predictions over prior-cost strategy in relevant net-benefit threshold ranges

---

## C. Methods

### C.1 Study Design and Setting
**Status:** ✓ DECIDED

**Study Design:**  
Prospective/retrospective longitudinal observational study with external temporal validation.

**Data Source:**  
Medical Expenditure Panel Survey (MEPS) 2-year longitudinal panel files:
- **Training Cohort:** Panels 21 (2016–2017), 22 (2017–2018), 23 (2018–2019) → HC-202, HC-210, HC-217
- **Validation Cohort:** Panels 26 (2021–2022), 27 (2022–2023) → HC-244, HC-252
- **Exclusion Rationale:** Panels 24–25 excluded (COVID disruption + temporal gap ensures independence)

**Why no Panel 23 4-yr?**  
HC-236 is Panel 23 *four-year* file (2018–2021) with 4-yr weight; violates temporal structure. Use HC-217 (2-yr) only.

---

### C.2 Participants and Inclusion/Exclusion Criteria
**Status:** ⚠ TODO (partial)

**Inclusion Criteria:**
- Enrolled in MEPS for full 2 years (both year 1 and year 2 present)
- Non-zero LONGWT (survey-defined person-level weight)
- Complete year-1 predictor data (imputation strategy TBD)

**Exclusion Criteria:**
- Missing year-2 outcome (TOTEXPY2)
- LONGWT = 0
- TBD: Age restrictions? (e.g., all ages vs. 18+)

**Sample Size Justification:**
- TODO: Formally calculate using expected event rate (top-decile ~10%) and targeted AUROC

---

### C.3 Outcome Definition
**Status:** ✓ DECIDED

**Primary Outcome:**  
**Binary:** High-cost status in year 2 = membership in **weighted 90th percentile of TOTEXPY2** (year-2 total expenditure)

**Why Binary Classification?**
- Clinically actionable (top decile ~ resource-intensive interventions)
- Aligned with prior high-cost predictive models
- Facilitates DCA and subgroup calibration

**Threshold Calculation:**
- Computed **per panel** (not pooled) to account for cost inflation
- Panel 21: 90th pct of TOTEXPY2 (weighted)
- Panel 22: 90th pct of TOTEXPY2 (weighted)
- Panel 23: 90th pct of TOTEXPY2 (weighted)
- Panel 26: 90th pct of TOTEXPY2 (weighted)
- Panel 27: 90th pct of TOTEXPY2 (weighted)

**Rationale:** Inflation makes a frozen threshold across years clinically invalid.

---

### C.4 Predictor Variables (Year-1 Features)
**Status:** ⚠ PARTIAL

**Candidate Predictors (all year-1 variables, prefixed `f_`):**

#### Clinical/Condition Variables:
- **ICD-10-CM 3-digit codes (CCSR mapping from 2018+):**
  - CCSR codes (2018 onwards): automatic grouping into clinically meaningful conditions
  - Pre-2018 (Panel 21/22): 3-digit ICD-10-CM; approximate CCSR via published mapping
  - **LIMITATION (TRIPOD item D.5.b):** MEPS public-use files provide only 3-digit ICD-10-CM and CCSR (confidentiality constraints); exact AHRQ-PQI v2024 replication impossible
  - **Approximation disclosure:** Secondary conditions (#05 COPD, #08 HF) mapped via CCSR; disclosed in limitations

#### Demographic Variables:
- Age (continuous)
- Sex (binary)
- Race/ethnicity (5-category: NH White, NH Black, Hispanic, NH Asian, NH Other)
- Insurance type (Medicaid, Private, Uninsured, etc.)
- Income level (% of federal poverty line; 4-category: <100%, 100-125%, 125-200%, >200%)

#### Healthcare Utilization (Year-1):
- Number of office-based visits
- Number of emergency department visits
- Number of hospital inpatient episodes
- Number of prescription fills
- Any mental health visit (binary)

#### Previous Cost:
- **TOTEXPY1:** Year-1 total expenditure (log-transformed for feature; used in DCA comparison)

**Status Gaps:**
- TODO: Full variable list extraction + missingness assessment (each panel)
- TODO: Imputation strategy (MCAR, MAR, MNAR assumptions)
- TODO: Transformation/scaling (log, standardization)
- TODO: Multicollinearity screening (VIF, correlation matrix)

---

### C.5 Sample Size and Statistical Power
**Status:** ⚠ TODO

**Current Panels (Training):**
- Panel 21: ~5,000–7,000 respondents (estimated)
- Panel 22: ~5,000–7,000 respondents (estimated)
- Panel 23: ~5,000–7,000 respondents (estimated)
- **Pooled Training:** ~15,000–21,000 unique persons (exact post-deduplication: TBD)

**Validation Panels:**
- Panel 26: ~5,000–7,000 respondents
- Panel 27: ~5,000–7,000 respondents
- **Pooled Validation:** ~10,000–14,000 unique persons (TBD)

**Power Calculation:**
- TODO: Formal calculation assuming:
  - Event rate (top decile): ~10%
  - Target AUROC: ≥0.75
  - Type I error: 0.05, Type II error: 0.20
  - Use pROC or similar for minimum N

**Interim Findings (exploratory, pre-analysis):**
- Expect sufficient events (~1,500–2,100 in training, 1,000–1,400 in validation) for stable LightGBM/XGBoost

---

### C.6 Survey Design Handling
**Status:** ✓ DECIDED

**Design Variables (confirmed present in all 2-yr files):**
- **Weight:** `LONGWT` (2-year longitudinal person weight, post-matched-pair adjustment)
- **Stratum:** `VARSTR` (variance stratum)
- **PSU:** `VARPSU` (variance primary sampling unit)
- **Nesting:** Complex design (PSU within VARSTR)

**Statistical Approach:**
- **R Packages:** `survey` + `srvyr` for all population estimates
- **Survey Object Specification:**
  ```r
  design <- svydesign(
    ids = ~VARPSU,
    strata = ~VARSTR,
    weights = ~LONGWT,
    nest = TRUE,
    data = panel_data
  )
  ```

**Application in Model Development:**
1. **Outcome Threshold (Weighted 90th Percentile):**
   - Use `survey::svyquantile()` to compute weighted quantile

2. **Predictor Distributions & Missingness:**
   - Report weighted summary statistics (mean, median, prop.) + unweighted counts

3. **Model Training:**
   - Incorporate `LONGWT` as observation weight in LightGBM/XGBoost
   - Stratified cross-validation: preserve strata assignment in folds

4. **Calibration Evaluation:**
   - Weighted Hosmer–Lemeshow or loess-based calibration plots (via survey design)

5. **Subgroup Analysis:**
   - Compute subgroup-specific weighted AUROCs (race/ethnicity, income)
   - Report 95% CI (design-based, via `svycoxph` approximation or bootstrap)

---

### C.7 Statistical Methods & Model Development
**Status:** ⚠ PARTIAL

#### Feature Engineering:
- **TODO:** Derived features (e.g., multimorbidity index, recent ED utilization, continuity of care)
- **DECIDED:** f_ prefix for all eligible predictors; no y2 suffixes in feature set (golden leakage rule)

#### Missing Data Handling:
- **Status:** TODO
- **Current approach:** Use missingness as categorical flag if <5% missing; MNAR sensitivity if >5%

#### Model Algorithms:
- **Primary:** LightGBM (fast, interpretable, handles survey weights natively)
- **Secondary:** XGBoost (calibration comparison, ensemble)
- **Tertiary:** Logistic regression with survey adjustment (baseline interpretable model)

**Training Procedure:**
1. Pool training panels (P21 + P22 + P23)
2. Stratified 5-fold cross-validation (preserve panel membership and strata)
3. Hyperparameter grid (learning rate, max_depth, num_leaves, lambda, gamma)
4. Optimize: Weighted AUC (via cross-validation; weights applied within folds)
5. Final refitting on entire training set

**Validation Strategy:**
- **Internal CV:** 5-fold on pooled training → estimate generalization
- **External Temporal Validation:** P26 + P27 (non-overlapping years, separate weighting)

---

### C.8 Model Evaluation Metrics
**Status:** ✓ PARTIAL

**Primary Metrics:**
- **AUROC** (Area Under Receiver Operating Characteristic curve)
  - 95% CI (design-based; account for clustering via svyAUC or bootstrap)
  - Threshold: ≥0.75 considered acceptable
  
- **AUPRC** (Area Under Precision-Recall curve)
  - Recommended for imbalanced binary classification
  - Report alongside AUROC

**Calibration:**
- **Calibration Slope & Intercept** (weighted logistic regression of observed on predicted)
  - Ideal: slope=1, intercept=0
- **Calibration Plot** (loess-based, with design-weighted observations)
- **Hosmer–Lemeshow p-value** (survey-adjusted version, if available; otherwise note limitation)

**Subgroup Performance:**
- **Subgroup-Stratified AUROC** by:
  - Race/ethnicity (5 categories)
  - Income level (4 categories)
  - Age group (e.g., 18–44, 45–64, 65+; or TBD)
  - Sex (M/F)
  
- **Fairness Metrics:**
  - Max AUC disparity (range across subgroups)
  - Subgroup-specific calibration slopes (calibration fairness)
  - DCA net benefit by subgroup

**Decision-Curve Analysis:**
- Compare vs. prior-cost baseline (TOTEXPY1; log-transformed)
- Plot: Net Benefit (y-axis) vs. Probability Threshold (x-axis)
- Identify threshold range where model adds clinical value

---

### C.9 Feature Importance & Interpretability
**Status:** ⚠ PARTIAL

**Methods:**
- **SHAP (SHapley Additive exPlanations):**
  - Tree-based SHAP for LightGBM/XGBoost
  - Summary plots (mean |SHAP| by feature)
  - Individual prediction explanation (example case studies)
  
- **Permutation Importance** (on validation set)
  
- **Partial Dependence Plots** (marginal effect of top 5–10 features)

**Reporting:**
- TODO: Identify top 10–15 features; rank by overall & subgroup importance
- TODO: Note if importance shifts across race/ethnicity (potential equity flag)

---

## D. Results (Pre-Analysis Plan / Anticipated Outputs)

### D.1 Participant Flow
**Status:** ⚠ TODO

**Reporting:**
- STROBE flow diagram (adapted for MEPS panels)
- Panels → eligible respondents → final N (training) → final N (validation)
- Exclusion reasons (missing outcome, LONGWT=0, etc.)
- Weighted vs. unweighted counts

---

### D.2 Descriptive Statistics
**Status:** ⚠ TODO

**Training Cohort Table 1:**
- Stratified by outcome (high-cost yes/no)
- Weighted summary statistics (mean, median, %; 95% CI)
- Unweighted counts + missing %
- Standardized mean difference (SMD) for balance check

**Validation Cohort Table 1 (parallel):**
- Same structure; assess covariate shift vs. training

---

### D.3 Model Performance (Primary Results)

#### Cross-Validation (Training Cohort):
- **Metric:** Weighted AUROC, AUPRC, 95% CI
- **Expected Output:** Table with 5-fold results + pooled estimate

#### External Validation (P26 + P27):
- **Metric:** AUROC, AUPRC, 95% CI (separately by panel & pooled)
- **Interpretation:** Assessment of temporal stability + covariate shift impact

#### Comparison Models:
- Logistic regression (baseline interpretable)
- XGBoost (calibration check)
- Prior-year cost alone (TOTEXPY1)

---

### D.4 Calibration Analysis
**Status:** ⚠ TODO (detailed plan)

**Output:**
- Calibration plot (observed vs. predicted, decile-binned)
- Calibration slope, intercept, Hosmer–Lemeshow p (or alternative survey-adjusted test)
- Interpretation: Over/under-confidence in prediction probabilities

---

### D.5 Subgroup Analysis & Fairness Audit
**Status:** ⚠ PARTIAL

**Subgroup Stratification:**
1. **Race/Ethnicity** (5 categories: NH White, NH Black, Hispanic, NH Asian, NH Other)
2. **Income Level** (4-category: <100%, 100–125%, 125–200%, >200% FPL)
3. **Age Group** (TBD: 18–44, 45–64, 65+; or quartiles)
4. **Sex** (M/F)

**Metrics Per Subgroup:**
- N (weighted & unweighted)
- Event rate (%)
- AUROC (95% CI)
- Calibration slope/intercept
- DCA net benefit (at clinically relevant thresholds)

**Fairness Findings:**
- TODO: Define acceptable performance gap (e.g., AUC difference <0.05)
- TODO: If disparity found, investigate: covariate shift, feature importance patterns, recalibration by subgroup
- TODO: Report in Results + Discussion (equity-focused interpretation)

---

### D.6 Decision-Curve Analysis
**Status:** ⚠ TODO (detailed scenarios)

**Comparison Strategies:**
1. **Model Predictions** (LightGBM)
2. **Prior-Year Cost Threshold** (TOTEXPY1 ≥ 75th pct; binary baseline)
3. **Treat All / Treat None** (reference lines)

**Net Benefit Calculation:**
- Net Benefit = (TP/N) − (FP/N) × (θ / (1 − θ))
- θ = decision threshold (probability of high-cost where intervention is beneficial)

**Threshold Range:**
- TODO: Define clinically relevant range (e.g., 5%–30% estimated risk)

**Interpretation:**
- Threshold where model > prior-cost strategy
- Identify subgroups with differential benefit (if time permits)

---

### D.7 Feature Importance
**Status:** ⚠ TODO (execution)

**SHAP Results:**
- Top 10–15 features (mean |SHAP|)
- Bar plot + summary force plot (example case)
- Dependence plots for top 3 features (SHAP value vs. feature value)

**Fairness Check:**
- Compare feature importance across race/ethnicity subgroups
- Flag if top predictors differ (e.g., age-only in one group)

---

## E. Discussion

### E.1 Main Findings
**Status:** ⚠ TODO (post-analysis)

**To Address:**
- AUROC ≥0.75? Calibration adequate?
- Temporal stability (P23 → P26/P27)?
- Subgroup disparities in AUROC/calibration? Actionable explanations?
- DCA net benefit range; clinical value over prior-cost?

---

### E.2 Comparison with Prior Work
**Status:** ⚠ TODO

**Planned Comparisons:**
- Yang & Delen 2018 (MEPS HCHN; reported AUROC ~0.72–0.74)
- Recent JMIR Med Inform ensemble study (AUROC ~0.76–0.80)
- Claims-based PLOS One studies (various metrics, datasets)

**Differentiators:**
- Survey design carried through; design-based CI + subgroup inference
- External temporal validation (non-overlapping panels 5+ years apart)
- Fairness/equity audit (AUC disparity, calibration by race/ethnicity, DCA)
- TRIPOD+AI 2024 transparency + checklist reporting

---

### E.3 Limitations
**Status:** ✓ PARTIAL

**Known Limitations (Data):**
1. **Confidentiality Collapse (TRIPOD D.5.b):** MEPS public-use ICD-10-CM limited to 3-digit; AHRQ-PQI v2024 exact replication impossible. Approximation via CCSR; disclosed.

2. **Missing Predictors:** MEPS lacks some clinically relevant data (e.g., lab results, imaging, mental health severity beyond visit flag).

3. **Generalizability:** MEPS civilian non-institutionalized U.S. population; excludes veterans, long-term care residents, incarcerated individuals.

4. **Cost Inflation:** TOTEXP not inflation-adjusted within panels (between-panel comparisons are nominal; discussed in interpretation).

5. **COVID Impact (Panel 24/25):** Excluded to avoid confounding; acknowledged as temporal gap.

**Methodological Limitations:**
- TODO: Survey design limitations (imputed strata/PSU in some panels?)
- TODO: Multiple comparisons (subgroup analysis; Bonferroni correction applied? Exploratory vs. confirmatory?)
- TODO: Hyperparameter selection method (internal CV; risk of overfitting?)

---

### E.4 Implications & Future Directions
**Status:** ⚠ TODO

**Clinical Implications:**
- Feasibility of deploying prediction model in practice (data availability, computational cost)
- Decision-support vs. fully automated triage
- Equity-conscious deployment (fairness safeguards if disparities found)

**Research Implications:**
- Utility of survey design in ML prediction studies
- External validation as best practice (temporal, geographic)
- Value of subgroup audits for equitable AI/ML in health

**Future Directions:**
- Prospective validation on newer MEPS panels
- Integration with claims-based cost drivers (diagnoses, procedures)
- Fairness refinement (causal fairness, debiasing algorithms if needed)

---

## F. Data & Code Reproducibility

### F.1 Data Availability & Archiving
**Status:** ✓ DECIDED

- **Public Data:** MEPS HC-202, HC-210, HC-217, HC-244, HC-252 freely available via AHRQ MEPS website
- **Checksums:** Record SHA-256 of each downloaded HC file at ingest (reproducibility)
- **Derived Data:** Panel frames (panel_21.rds, panel_22.rds, etc.) versioned in `data/derived/`
- **Data Contract:** Golden leakage rule enforced: only f_* + design columns model-eligible

### F.2 Code & Environment
**Status:** ✓ PARTIAL

- **Language:** R
- **renv:** renv.lock captures exact package versions (reproducibility)
- **Scripts:** Organized in `R/` directory (ingest, feature engineering, model training, evaluation)
- **GitHub:** Repository with .Rprofile, renv.lock, all scripts
- **LICENSE:** TBD (likely GPL-3.0 or MIT for public share)

### F.3 Pre-Registration & Protocol
**Status:** ✓ DECIDED

- **Protocol Document:** This checklist (TRIPOD-AI 2024 transparency)
- **Pre-Registration:** TBD (OSF Registries or journal platform)
- **Analysis Plan:** Locked before model training on validation set

---

## G. Reporting Standards

### G.1 TRIPOD+AI 2024 Checklist Adherence
**Status:** ⚠ IN PROGRESS

**Checklist Items Addressed So Far:**
- ✓ A.1: Title (explicit outcome, population, design)
- ✓ A.2: Abstract (background, methods, results, conclusions structure)
- ✓ B.1: Background & rationale
- ✓ B.2: Objectives & hypotheses
- ✓ C.1: Study design & setting (2-yr longitudinal MEPS panels)
- ✓ C.2: Participants (inclusion/exclusion, TBD: formal sample size justification)
- ✓ C.3: Outcome definition (weighted 90th percentile, per-panel)
- ✓ C.4: Predictors (f_* prefix rule; clinical/demographic/utilization; year-1 only)
- ✓ C.5: Sample size (estimated; formal power TBD)
- ✓ C.6: Survey design (LONGWT, VARSTR, VARPSU; srvyr workflow)
- ⚠ C.7: Statistical methods & model development (partial; hyperparameter grid TBD)
- ⚠ C.8: Evaluation metrics (AUROC, calibration, subgroup AUROC; DCA TBD specifics)
- ⚠ C.9: Feature importance (SHAP planned; execution pending)
- ⚠ D.1–D.7: Results reporting (tables/figures templates; outputs TBD post-analysis)
- ⚠ E.1–E.4: Discussion (templates; content post-analysis)
- ✓ F.1–F.3: Reproducibility & code (renv, scripts, data contract)
- ⚠ G.1–G.2: Reporting standards & quality checklist

---

### G.2 Quality & Bias Mitigation Measures
**Status:** ⚠ PARTIAL

**Bias Handling:**
- **Selection Bias:** MEPS uses probability sampling; stratified analysis by panel + subgroup
- **Information Bias:** Outcome (TOTEXP) directly from MEPS; no misclassification expected
- **Confounding:** Year-1 features expected to capture unmeasured confounding risk (e.g., comorbidity via claims data); discussion of residual confounding
- **Fairness/Algorithmic Bias:** Explicit subgroup AUC audit; fairness metrics (calibration slopes by race/ethnicity)

**Sensitivity Analyses (Planned):**
- TODO: Imputation strategy (MCAR vs. MAR vs. MNAR)
- TODO: Threshold definition (weighted 90th vs. 85th/95th percentile)
- TODO: Temporal validation: P26 & P27 separately vs. pooled

---

## H. Milestones & Timeline

### M1: Data + Target + Protocol (Started 2026-07-08)
- ✓ Verify 2-yr panel files & LONGWT mapping
- ✓ Confirm outcome definition (weighted 90th pct per panel)
- ✓ Identify candidate predictors + data contract
- ⚠ TRIPOD-AI checklist (this document; refinement ongoing)
- ⚠ Literature review (top 10–15 citations; Yang & Delen 2018, recent ML, fairness)
- TODO: Formal sample size calculation
- TODO: Pre-registration (OSF or journal platform)

### M2: Feature Engineering + Model Development (TBD, ~3 weeks)
- Ingest & clean panels 21, 22, 23, 26, 27
- Feature engineering & missing-data handling
- LightGBM/XGBoost hyperparameter tuning (5-fold CV on training)
- Internal cross-validation performance report
- Feature importance (SHAP) exploration

### M3: Validation + Manuscript (TBD, ~4 weeks)
- External temporal validation (P26 + P27)
- Calibration analysis & subgroup AUROCs
- Decision-curve analysis
- Fairness audit report
- Manuscript write-up (Results + Discussion)
- TRIPOD-AI checklist finalized

---

## I. Study Approval & Governance

### I.1 Ethics & IRB
**Status:** TBD

- MEPS data is public-use; minimal IRB review expected
- If recontact or identifiable data used: Formal IRB submission required
- Current plan: public-use data analysis (likely exempt)

### I.2 Data Sharing & Open Science
**Status:** TBD

- Code repository: GitHub (public, unless confidential patterns emerge)
- Derived data: Shareable (no identifiable info in public MEPS; aggregate results only)
- Manuscript: Open-access target (JPMedAI, or ArXiv preprint)

---

## J. Key Assumptions & Decision Log

### Assumption 1: Temporal Independence
- **Assumption:** Panels 21–23 (training) are statistically independent of panels 26–27 (validation)
- **Rationale:** 3–4 year gap; different cohorts (limited overlap expected)
- **Risk:** If cohort overlap >20%, independence violated
- **Mitigation:** Post-hoc check: reconcile dupersid across panels; report overlap %

### Assumption 2: Stationarity of Relationships
- **Assumption:** Year-1 → Year-2 associations stable across panels
- **Rationale:** Chronic disease pathways expected to persist
- **Risk:** Policy/healthcare delivery changes, pandemic, change in data collection
- **Mitigation:** Sensitivity analysis: Panel-stratified models if interaction p < 0.05

### Assumption 3: Completeness of Cost Data
- **Assumption:** TOTEXPY2 captured with minimal missing (>95%)
- **Rationale:** MEPS uses multiple imputation for missing; public files post-imputation
- **Risk:** Non-random missingness if hospitalized/institutionalized respondents lost to follow-up
- **Mitigation:** Report missing % by panel; sensitivity analysis (multiple imputation)

### Assumption 4: Survey Design Validity
- **Assumption:** LONGWT, VARSTR, VARPSU are accurate post-matched-pair
- **Rationale:** AHRQ methodology papers; publicly vetted design
- **Risk:** Design-variable misspecification if matching strata changed
- **Mitigation:** Cross-check with MEPS documentation; report design effect (deff) by panel

---

## K. Open Questions & TODO Items

### Data & Outcome:
- [ ] Final inclusion/exclusion criteria (age limits?)
- [ ] Formal sample size power calculation
- [ ] Missingness mechanism assessment (MCAR/MAR/MNAR) by predictor
- [ ] Imputation strategy finalized (if >5% missing)

### Methods:
- [ ] Hyperparameter grid finalized (learning_rate, max_depth, num_leaves range)
- [ ] Cross-validation scheme finalized (stratification by panel + strata)
- [ ] XGBoost hyperparameters + calibration recalibration method
- [ ] LightGBM native weight incorporation verified
- [ ] Survey-adjusted AUROC computation verified (svycoxph proxy or bootstrap?)

### Analysis:
- [ ] Subgroup stratification finalized (age quartiles? <18/18-44/45-64/65+?)
- [ ] Fairness threshold defined (max AUC disparity acceptable: 0.05? 0.10?)
- [ ] DCA threshold range specified (5%–30%? clinical input needed)
- [ ] Sensitivity analyses list finalized (imputation, threshold, subgroup definitions)

### Reporting:
- [ ] Pre-registration platform selected & registered
- [ ] TRIPOD-AI checklist items D.1–D.7 templates finalized
- [ ] Discussion section outline finalized
- [ ] Figure/table mockups created (flow diagram, Table 1, calibration plot, DCA plot)

### Governance:
- [ ] IRB determination letter (likely exempt; confirm with IRB)
- [ ] GitHub repository initialized + README drafted
- [ ] Co-author list finalized (JPMedAI collaboration structure)

---

## L. References & Key Documents

### Data Sources:
- AHRQ MEPS: https://meps.ahrq.gov/
- HC-202 (Panel 21, 2016–2017): Download + verify
- HC-210 (Panel 22, 2017–2018): Download + verify
- HC-217 (Panel 23, 2018–2019): Download + verify
- HC-244 (Panel 26, 2021–2022): Download + verify
- HC-252 (Panel 27, 2022–2023): Download + verify

### Methodological References:
- Yang, Z., & Delen, D. (2018). Assessing healthcare costs through medical conditions in MEPS. BioMedical Engineering OnLine, 17(Suppl 2), 154. PMID: 30547094
- JMIR Med Inform 2026 (PMC12966819) — ensemble ML high-cost prediction
- PLOS One claims-based high-cost studies (TBD: specific citations)
- TRIPOD Statement 2015 (Moons et al.): https://www.tripod-statement.org/
- TRIPOD+AI 2024 (extension for AI/ML): https://www.tripod-statement.org/ (or recent publication)
- Survey sampling & analysis: Lumley, T. (2010). Complex Surveys: A Guide to Analysis Using R. Wiley.
- SHAP interpretability: Lundberg & Lee (2017). A unified approach to interpreting model predictions. NeurIPS.

### Previous User Work:
- [[user-profile-rafael]]: PhD data scientist, 440+ freelance projects, R/SPSS/Python
- [[meps-tripodai-highcost]]: Project overview, data verification, prior work assessment

---

## M. Version Control & Approval

| Version | Date | Author | Changes | Status |
|---------|------|--------|---------|--------|
| 1.0 | 2026-07-08 | Rafael dos Reis | Initial TRIPOD+AI checklist draft (M1) | In Progress |
| TBD | TBD | Rafael + Co-authors | Pre-registration + refinement | Pending |
| TBD | TBD | Rafael + Reviewers | Post-analysis finalization | Pending |

---

## N. Quick Summary for M1 Checkpoint

**Completed:**
- ✓ Study title & objectives (outcome, population, predictors, design)
- ✓ Data sources verified (5 panels, 2-yr files, LONGWT mapping confirmed)
- ✓ Outcome definition (weighted 90th pct per panel; binary high-cost)
- ✓ Predictor scope (f_* year-1 features; no y2 leakage)
- ✓ Survey design workflow (srvyr with LONGWT/VARSTR/VARPSU)
- ✓ Evaluation metrics (AUROC, calibration, subgroup AUC, DCA)
- ✓ Reproducibility (renv, data contract, scripts)
- ✓ TRIPOD+AI checklist structure (all sections drafted; TODO items flagged)

**In Progress:**
- ⚠ Literature review (top citations, differentiation from prior work)
- ⚠ Formal sample size justification
- ⚠ Hyperparameter specifications (LightGBM, XGBoost)
- ⚠ Pre-registration (OSF/journal platform)

**Next Steps (M2):**
- Finalize sample size & pre-register
- Ingest & clean panel data
- Feature engineering & missing-data assessment
- Hyperparameter tuning + internal CV
- SHAP importance exploration

---

**Document Status:** Living checklist; updated throughout study lifecycle.  
**Last Reviewed:** 2026-07-08  
**Next Review:** Pre-M3 (manuscript)

---

## O. M2 EXECUTED — realized results (2026-07-08)

This addendum records ACTUAL executed values, superseding the pre-analysis estimates/TODOs above. Full method justification with citations: `docs/Methods_Justification.md`.

### O.1 Realized sample (resolves C.2/C.5)
Train (P21+22+23) = 44,225 persons (15,617 / 14,541 / 14,067); external validation (P26+27) = 15,033 (6,741 / 8,292). Weighted top-decile base rate ≈ 10.0% in **every** panel (per-panel weighted 90th pct of TOTEXPY2). ALL5RDS retained; weighted totals reproduce AHRQ published figures within ±0.01%.

### O.2 Predictors — final contract (resolves C.4/C.7 feature selection)
**62 features**, `R/feature_contract.R`. Design-based selection (NOT hand-picked): universe = 685 year-1 vars common to all 5 panels → pre-specified structural exclusion (IDs/admin, imputation flags, source-of-payment decomposition, monthly coverage cells, income-by-source) + round-1/2 allowlist (perceived health, functional limitation; rounds 3–5 excluded as year-2 leakage) → 176 → weighted filters (missing ≤40%, weighted modal ≤99%, |r|≤0.90) → 99→79 → Rao–Scott Wald screen (svyglm, p<0.157) → 72 → **svyVarSel::wlasso dCV** (design-based LASSO; Iparragirre & Lumley 2023) = 64 → pruned 2 admin-ish = **62**. LightGBM handles NA natively (no imputation for the tree). Boruta rejected as primary (no valid warrant under complex survey design); retained only as labeled sensitivity.

### O.3 Model + external validation (resolves C.8/D.3/D.4)
LightGBM, survey weights = LONGWT (case weights; MacNell 2023). best_iter=223 (cluster-respecting 5-fold CV). **Weighted AUC: train 0.916, CV 0.865, external validation 0.857.** Calibration slope 0.93, CITL pred/obs 0.106/0.100, Brier 0.068. Reliability plot `outputs/m2/reliability_valid.png`. (Design-based CIs via replicate weights = declared gap, pending.)

### O.4 Explainability (resolves C.9/D.7)
TreeSHAP (validation). Top drivers: prior total spend (dominant) ≫ RX fills, age, family size, office visits, self-pay, perceived health, activity-limited days, sex, asthma. `outputs/m2/shap_*.png`.

### O.5 Decision-curve analysis (resolves D.6)
Weighted net benefit; GBT **exceeds** the prior-year-cost benchmark across the clinically relevant threshold range (ΔNB +0.009 at pt=0.10). `outputs/m2/dca_valid.png`.

### O.6 Subgroup calibration / fairness (resolves D.5)
Weighted, validation. Income (POVCAT): AUC 0.84–0.91, calibration reasonable. Race/ethnicity: AUC 0.84–0.89; mild over-prediction in the lowest-rate group. `outputs/m2/subgroup_calibration.csv`. Max AUC gap ≈ 0.05.

### O.7 Secondary AHRQ-PQI concordance (resolves secondary objective)
Proxy (disclosed deviation): any year-2 inpatient stay CLNK-linked to HF (ICD-10-CM I50) or COPD (J40–J44, age≥40); 3-digit ICD only, no principal-dx flag. Validation n(PQI)=53 (small — limitation). P(PQI | actual top-decile)=1.98% vs 0.11% (RR 17.6); 66% of PQI admissions fell in the top-cost decile. Model-flagged group captures 59% prospectively (RR 13.1). `outputs/m2/pqi_concordance.json`.

### O.8 Transition sensitivity
Among non-year-1-top-decile persons (validation, 6.3% transition to top-decile): weighted AUC 0.80 — model identifies NEW high-cost cases, not just persistence. `outputs/m2/transition_sensitivity.json`.

### O.9 Still pending for M3
Design-based CIs (BRR/jackknife replicate weights) for AUC/NB/calibration; XGBoost + survey-logistic comparators; SHAP dependence plots; STROBE/participant-flow diagram; manuscript prose + ≤8 figures + structured abstract; pre-registration.
