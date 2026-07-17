# Literature Review: Prior Work on High-Cost Patient Prediction

## Purpose

This review situates the present study — top-decile year-2 total expenditure
(`totexp_y2`) prediction on non-overlapping post-COVID MEPS longitudinal
panels — against the closest published high-cost/high-need (HCHN) prediction
papers. It is intended to (a) justify why the present design is a
non-trivial extension of prior MEPS/claims-based work, and (b) ground the
TRIPOD+AI reporting choices (calibration, subgroup metrics, decision curve
analysis) made in the analysis plan.

---

## 1. Closest prior papers

### 1.1 Yang et al. (2018) — Texas Medicaid, machine learning temporal prediction

Yang C, Delcher C, Shenkman E, Ranka S. Machine learning approaches for
predicting high cost high need patient expenditures in health care. BioMed
Eng Online. 2018;17(Suppl 1):131.

- **Data**: Texas Medicaid claims, 2011–2014; ~1.7 million adults aged
  18–65; ~1,300 diagnostic/procedure/medication/demographic features.
- **Target**: Top 10% of per-member-per-month (PMPM) expenditure, i.e., a
  claims-based HCHN definition structurally analogous to our
  `top_decile_y2` flag.
- **Methods**: OLS linear regression, LASSO, gradient boosting machine,
  recurrent neural network.
- **Validation**: Sequential period-to-period (t → t+1) prediction across
  1-, 3-, 6-, and 12-month horizons — a form of temporal validation, but all
  within one continuous pre-2015 Medicaid claims stream, not across
  administratively distinct, non-overlapping survey panels.
- **Reporting**: No calibration curves/statistics; subgroup analysis limited
  to chronic-disease cohorts (diabetes, COPD, asthma, hypertension), not
  race/ethnicity or income; no decision curve analysis (DCA).
- **Headline result**: RNN reached R² > 0.7 for continuous expenditure;
  45–61% of top-decile patients persisted in the top decile across periods.

**This is the most direct methodological antecedent** to our target
definition (prior-year features → next-period top-decile spend) and is the
paper our TRIPOD+AI protocol most explicitly extends.

### 1.2 Langenberger, Schulte & Groene (2023) — German claims data, model comparison with year-to-year holdout

Langenberger B, Schulte T, Groene O. The application of machine learning to
predict high-cost patients: a performance-comparison of different models
using healthcare claims data. PLoS One. 2023;18(1):e0279540.

- **Data**: German statutory health-insurance claims, Hamburg region,
  2016–2018; ~21,000 training / ~21,000 test patients.
- **Target**: Top 5% of annual cost distribution.
- **Methods**: Random forest, gradient boosting machine, artificial neural
  network, logistic regression, compared head-to-head.
- **Validation**: 75/25 split with 5-fold cross-validation, plus a
  sequential 2016→2017 (train) / 2017→2018 (test) year-ahead evaluation —
  the closest analogue in this literature to a "next calendar period"
  external test, though still drawn from one continuous insurer's claims
  warehouse rather than independently fielded, non-overlapping national
  survey panels.
- **Reporting**: AUC with confidence intervals reported; **no calibration
  metrics**; **no subgroup analysis by demographics** (age is a predictor,
  not a stratification variable); no DCA.
- **Headline result**: Random forest best (AUC 0.883), tree ensembles
  significantly outperformed logistic regression and neural nets.

This paper is the closest recent (post-2020) methods-comparison benchmark
and the most comparable in AUC-reporting convention, but it shares the same
gap in calibration and equity reporting as Yang et al. (2018).

### 1.3 de Ruijter et al. (2022) — systematic review, HNHC prediction models

de Ruijter UW, Kaplan ZLR, Bramer WM, Eijkenaar F, Nieboer D, van der Heide
A, Lingsma HF, Bax WA. Prediction models for future high-need high-cost
healthcare use: a systematic review. J Gen Intern Med. 2022;37(7):1763–70.

- **Scope**: 60 studies of HNHC/high-cost prediction models across claims
  and survey data sources (not a single primary study, but the field-level
  benchmark for what is and is not routinely reported).
- **Key documented gaps** (used directly to motivate our design):
  - External validation was performed in only 20/60 studies (33%); most
    "validation" was internal/split-sample.
  - Calibration and discrimination were **jointly** reported in only 14/60
    studies (23%); calibration alone was frequently omitted entirely.
  - **No reviewed study reported race/ethnicity- or income-stratified
    subgroup performance or fairness diagnostics.**
  - DCA, the standard metric of clinical/decision usefulness beyond
    discrimination, was used in only 2/60 studies (3%).
  - 62% of studies were rated high risk of bias in the analysis domain
    (predictor handling, missing-data documentation).

This review is not itself a MEPS/claims prediction model but is cited
because it is the strongest available evidence that calibration reporting,
subgroup/equity analysis, and DCA are systematically absent from the HNHC
prediction literature — precisely the gap this study is designed to close.

### 1.4 (Supplementary) Tan et al. (2026) — ensemble high-usage prediction, temporal external validation

Tan JK, Quan L, Tan HY, Goh SY, Thumboo J, Au M, Bee YM, Tan JH. Ensemble
machine learning models for predicting patients with high usage: model
validation and economic impact analysis. JMIR Med Inform. 2026;14(1):e77202.

- **Data**: Singapore Health Services Diabetes Registry, 2020–2022;
  ~109,000 training / ~111,000 validation patients.
- **Target**: Multiclass strata of inpatient length-of-stay and ED-visit
  counts (a utilization proxy for cost, not top-decile total expenditure).
- **Methods**: Boosted-tree ensembles with a logistic-regression base
  learner, compared against single-model baselines.
- **Validation**: Temporal — trained on 2020–2021, validated on
  non-overlapping 2021–2022 registry data (same institution, same
  registry).
- **Reporting**: AUROC/accuracy/confusion-matrix metrics; **no calibration
  curves**; **no demographic subgroup analysis**; economic-impact
  simulation (Monte Carlo cost savings) substitutes for formal DCA.
- **Headline result**: Multiclass AUROC 0.69 (length of stay) / 0.76 (ED
  visits); projected SGD $152M annual savings under targeted intervention.

Included as a recent (2026) example confirming the pattern holds even in
the newest ensemble-ML high-utilization literature: temporal validation is
increasingly adopted, but calibration and subgroup equity reporting remain
absent, and validation cohorts are drawn from a single continuous data
source rather than independently fielded panels.

---

## 2. Explicit point of difference

Relative to the four works above, the present study (protocol governed by
the data contract in `meps-highcost/`) differs on every axis these papers
leave underspecified:

1. **Survey design carried through to calibration, not just point
   estimates.** All four prior works use claims registries with
   patient-level (not survey-weighted) records. Here, MEPS's complex survey
   design (`longwt`, `varstr`, `varpsu`; `survey`/`srvyr`, `nest = TRUE`) is
   propagated through every stage — discrimination *and* calibration *and*
   subgroup metrics — rather than being dropped once weighted estimates are
   produced, which is the more common shortcut in the applied literature.

2. **Temporal external validation on non-overlapping, independently
   fielded post-COVID panels**, not a rolling window within one continuous
   claims/registry stream. Yang et al. (2018) and Tan et al. (2026)
   validate on subsequent periods drawn from the *same* underlying data
   system; Langenberger et al. (2023) similarly re-uses one insurer's
   warehouse across adjacent years. Our design trains on one MEPS panel
   (year1→year2) and externally validates on a *later, non-overlapping*
   panel pair spanning the COVID-19 disruption in health care utilization
   (excluding the four-year HC-236 file; Panel 23 uses the two-year HC-217
   file per protocol), a materially harder generalization test than
   same-source rolling-window validation.

3. **Decision curve analysis (DCA) benchmarked against a naive prior-year-cost
   rule**, not only discrimination metrics. De Ruijter et al. (2022) found
   DCA in only 3% of the reviewed literature, and none of Yang et al.
   (2018), Langenberger et al. (2023), or Tan et al. (2026) report it. We
   report net benefit for the fitted model versus a simple "flag if prior
   year was high-cost" heuristic across a range of threshold probabilities,
   directly answering whether the model adds clinical/operational value
   over the status-quo rule.

4. **Subgroup calibration and subgroup DCA by income and race/ethnicity.**
   De Ruijter et al. (2022) found *no* study in 60 reviewed reporting
   race/ethnicity- or income-stratified performance; none of the three
   primary papers reviewed here report it either. We report calibration
   curves, calibration-in-the-large, and DCA net benefit separately by
   income category and race/ethnicity subgroups, directly targeting the
   equity-reporting gap the systematic review documents.

5. **TRIPOD+AI-conformant reporting** (Collins GS, Moons KGM, Dhiman P, et
   al. TRIPOD+AI statement: updated guidance for reporting clinical
   prediction models that use regression or machine learning methods. BMJ.
   2024;385:e078378), applied to a leakage-controlled feature set (only
   `f_*` year-1 features and design variables are model-eligible; all
   `*_y2` columns other than the target are excluded downstream), which
   none of the four papers above explicitly follow (they predate or do not
   cite the 2024 update).

---

## 3. Summary comparison table

| Study | Data source | Target | Validation | Calibration reported | Subgroup (income/race) | DCA |
|---|---|---|---|---|---|---|
| Yang et al. 2018 [1] | TX Medicaid claims, 2011–2014 | Top 10% PMPM | Sequential t→t+1, same source | No | Disease cohorts only | No |
| Langenberger et al. 2023 [2] | German claims, 2016–2018 | Top 5% annual cost | Split-sample + year-ahead, same source | No | None | No |
| de Ruijter et al. 2022 [3] (review, n=60 studies) | Mixed claims/survey | HNHC (varies) | External in 33% of studies | Reported with discrimination in 23% | None in any study | 3% of studies |
| Tan et al. 2026 [4] | Singapore diabetes registry, 2020–2022 | Utilization strata (LOS/ED) | Temporal, same registry | No | None | Economic simulation only |
| **This study** | **MEPS panels, non-overlapping, post-COVID, survey-weighted** | **Top decile `totexp_y2`** | **External, independently fielded panel pair** | **Yes, survey-weighted** | **Yes, income + race/ethnicity** | **Yes, vs. prior-year-cost rule** |

---

## References (Vancouver style)

1. Yang C, Delcher C, Shenkman E, Ranka S. Machine learning approaches for
   predicting high cost high need patient expenditures in health care.
   BioMed Eng Online. 2018;17(Suppl 1):131.
   https://biomedical-engineering-online.biomedcentral.com/articles/10.1186/s12938-018-0568-3

2. Langenberger B, Schulte T, Groene O. The application of machine learning
   to predict high-cost patients: a performance-comparison of different
   models using healthcare claims data. PLoS One. 2023;18(1):e0279540.
   https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0279540

3. de Ruijter UW, Kaplan ZLR, Bramer WM, Eijkenaar F, Nieboer D, van der
   Heide A, et al. Prediction models for future high-need high-cost
   healthcare use: a systematic review. J Gen Intern Med.
   2022;37(7):1763–70. https://pmc.ncbi.nlm.nih.gov/articles/PMC9130365/

4. Tan JK, Quan L, Tan HY, Goh SY, Thumboo J, Au M, et al. Ensemble machine
   learning models for predicting patients with high usage: model
   validation and economic impact analysis. JMIR Med Inform.
   2026;14(1):e77202. https://pmc.ncbi.nlm.nih.gov/articles/PMC12966819/

5. Collins GS, Moons KGM, Dhiman P, Riley RD, Beam AL, Van Calster B, et
   al. TRIPOD+AI statement: updated guidance for reporting clinical
   prediction models that use regression or machine learning methods. BMJ.
   2024;385:e078378. https://pmc.ncbi.nlm.nih.gov/articles/PMC11025451/
