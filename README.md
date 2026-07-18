# Survey-weighted machine learning for prospective stratification of high-cost patients

Analysis code for the study *"Survey-Weighted Machine Learning for Prospective Stratification of
High-Cost Patients: A Design-Based Pipeline with External Temporal Validation, Decision-Curve
Analysis, and Subgroup Calibration in a Nationally Representative U.S. Cohort"* (submitted to the
*Journal of Precision Medicine and Artificial Intelligence*).

We predict membership in the **population-weighted top decile of year-2 total expenditure** from
**year-1 features only** in the Medical Expenditure Panel Survey (MEPS) two-year longitudinal panels.
The complex survey design (longitudinal weight, variance strata, primary sampling units) is carried
through **every** step: feature selection, model training, calibration, uncertainty quantification,
and all subgroup estimates.

| | |
|---|---|
| **Development** | Panels 21–23 (2016–2019), n = 44,225 |
| **External temporal validation** | Panels 26–27 (2021–2023), n = 15,033 |
| **Excluded** | Panels 24–25 (COVID four-year extensions; create a clean temporal gap) |
| **Headline** | Weighted AUC 0.857 (95% CI 0.842–0.869); calibration slope 0.93; net benefit above the prior-year-cost benchmark (paired Δ at 10% threshold 0.0089, 95% CI 0.0067–0.0111) |

## Data

All data are **public** MEPS Household Component files from AHRQ (<https://meps.ahrq.gov>) and are
**not** redistributed here. `R/prep_panel.R` downloads and prepares them.

| Panel | Years | Two-year longitudinal file |
|---|---|---|
| 21 | 2016–2017 | HC-202 |
| 22 | 2017–2018 | HC-210 |
| 23 | 2018–2019 | HC-217 |
| 26 | 2021–2022 | HC-244 |
| 27 | 2022–2023 | HC-252 |

> **Note.** Panel 23 uses the **two-year** file (HC-217). The four-year Panel 23 file (HC-236) carries a
> four-year weight targeting a different population and must not be substituted.

Secondary (AHRQ Prevention Quality Indicator) analysis additionally uses the 2022/2023 Medical
Conditions, Hospital Inpatient Stays, and condition–event link files.

## Reproducing

Requires R (≥ 4.5). Package versions are pinned with `renv`.

```r
renv::restore()                       # restore the pinned environment
```

Then run, from the project root:

```bash
Rscript R/prep_panel.R 21             # repeat for 22, 23, 26, 27
Rscript R/pool_panels.R               # pool + design checks vs AHRQ published totals
Rscript R/m2_01_train_validate.R      # survey-weighted LightGBM + external validation
Rscript R/m2_02_shap_dca_subgroups.R  # SHAP, decision curve, subgroup calibration
Rscript R/m2_03_pqi.R                 # secondary: AHRQ-PQI concordance
Rscript R/m2_04_transition.R          # sensitivity: incident ("transition") high cost
Rscript R/m2_05_cis_comparators.R     # design-based CIs + XGBoost / survey-logistic comparators
Rscript R/m4_revision_stats.R         # subgroup table incl. missing income; DCA paired-difference CIs
Rscript R/m3_figures_pub.R            # publication figures (400 dpi)
```

### Key scripts

| File | Purpose |
|---|---|
| `R/config.R` | Verified panel↔year↔file map, survey-design helpers, leakage guard |
| `R/feature_contract.R` | The locked set of **62 year-1 features** + per-panel source resolution |
| `R/prep_panel.R` | One code path for all five panels: download → harmonize → weighted target |
| `R/build_feature_set.R`, `R/run_wlasso.R` | How the 62 features were derived (design-based selection) |
| `R/pool_panels.R` | Pooling + verification that Σ LONGWT reproduces AHRQ published totals |

### Design-based feature selection

685 year-1 variables common to all five panels → 176 (pre-specified structural exclusion + round-1/2
allowlist) → 79 (weighted filters) → 72 (Rao–Scott Wald screen) → **62** (survey-weighted LASSO with
design-based cross-validation, `svyVarSel::wlasso`).

## Validation invariants

`R/pool_panels.R` enforces the checks the study depends on:

1. **LONGWT** (two-year longitudinal weight) used throughout; annual cross-sectional weights are forbidden.
2. Top-decile threshold = **weighted 90th percentile of `TOTEXPY2`, computed per panel** (cost inflation).
3. **Leakage firewall**: no year-2-derived variable may enter the feature set.
4. Panel↔file map matches AHRQ; HC-236 never substituted for HC-217.
5. Σ LONGWT over `ALL5RDS == 1` reproduces AHRQ's published population estimates (within ±0.01%).

## Reporting

The study is reported per **TRIPOD+AI**; the completed checklist is in `protocol/`.
Method-by-method justification of applicability under a complex survey design, with citations, is in
`docs/Methods_Justification.md`.

## Citation

If you use this code, please cite the accompanying article (details to follow on publication).

## License

Code released under the MIT License (`LICENSE`).
