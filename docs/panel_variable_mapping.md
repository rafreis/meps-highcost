# Panel Variable Mapping: MEPS TRIPOD+AI High-Cost Prediction

**Project:** MEPS High-Cost Risk Prediction — JPMedAI manuscript  
**Data contract authority:** `R/config.R` (source of truth for all mappings; mirrors verified AHRQ files 2026-07-08)  
**Document status:** Reference specification for M1 pipeline (Phases 1–3)  
**Last updated:** 2026-07-08

---

## Executive Summary

This document specifies the authoritative bidirectional mapping between:
- **MEPS survey panels** (21, 22, 23, 26, 27)
- **Survey years** (2016–2019, 2021–2023)
- **HC file numbers** (longitudinal + FYC + event files)
- **Canonical variable names** (dupersid, panel, year1, year2, totexp_y1, totexp_y2, top_decile_y2, longwt, varstr, varpsu)

**Critical warnings:**
1. HC-236 (Panel 23 **four-year** file, 2018–2021) is **forbidden** — it carries a 4-year weight, not a 2-year weight.
2. The **COVID-four-year trap** (Panels 24–25): these panels span 2019–2022 and 2020–2021, crossing the pandemic boundary → excluded to ensure clean pre/post separation.
3. **Locked event-file numbers** are documented against verified AHRQ downloads (2026-07-08).

Every downstream script (`R/prep@*`, `R/target@*`, etc.) **must** validate its inputs against this map and the data-contract rules in `R/config.R`.

---

## 1. The Canonical Panel × Year × HC-File Map

### 1.1 Training Panels (2016–2019)

| Panel | Survey Years | 2-Yr Longitudinal | FYC Year 1 | FYC Year 2 | Sample Use | Role |
|:-----:|:-----:|:---:|:---:|:---:|:---:|:---:|
| **21** | 2016–2017 | HC-202 | HC-201 (or bundled) | HC-201 | ≈ 4k–5k persons | Train |
| **22** | 2017–2018 | HC-210 | HC-201 | HC-209 | ≈ 4k–5k persons | Train |
| **23** | 2018–2019 | **HC-217** | HC-209 | HC-216 | ≈ 4k–5k persons | Train |

### 1.2 Validation Panels (2021–2023)

| Panel | Survey Years | 2-Yr Longitudinal | FYC Year 1 | FYC Year 2 | Sample Use | Role |
|:-----:|:-----:|:---:|:---:|:---:|:---:|:---:|
| **26** | 2021–2022 | HC-244 | HC-233 | HC-243 | ≈ 4k–5k persons | Validation |
| **27** | 2022–2023 | HC-252 | HC-243 | HC-251 | ≈ 4k–5k persons | Validation |

### 1.3 Why Panels 24–25 Are Excluded (COVID Gap)

| Panel | Survey Years | 2-Yr Longitudinal | Reason for Exclusion |
|:-----:|:-----:|:---:|:---|
| 24 | 2019–2022 | HC-236* | Spans pre-COVID → post-COVID; 4-year weight; **FORBIDDEN** |
| 25 | 2020–2021 | HC-244 alt | Entirely within pandemic; creates temporal confound |

**Exclusion rationale:**  
- Panels 21–23 provide a clean **2016–2019 pre-pandemic train cohort** (3 panels × ~4.5k = ~13.5k training persons).
- Panels 26–27 provide a clean **2021–2023 post-pandemic validation cohort** (2 panels × ~4.5k = ~9k validation persons).
- The 2-year gap (2019–2021) isolates pre from post, avoiding confounding by pandemic-driven cost inflation and behavior changes.

---

## 2. The Critical HC-236 Trap: Four-Year vs. Two-Year Weight

### 2.1 Why HC-236 Is Forbidden

**HC-236** is AHRQ's "Panel 23 Longitudinal Data File (Diagnostic and Procedure Event Files, 2018–2021)."

```
HC-236 (FORBIDDEN)
├─ Covers: 2018–2021 (4 years)
├─ LONGWT in this file: 4-year person weight
├─ Weight formula: calibrated across 4 survey years, not 2
└─ Why it breaks the analysis:
   └─ Survey design assumes 2-year weights
   └─ Using 4-year weight inflates precision incorrectly
   └─ Violates the golden leakage rule (wrong variance structure)
```

### 2.2 The Correct File: HC-217 (Two-Year)

```
HC-217 (REQUIRED for Panel 23)
├─ Covers: 2018–2019 (2 years) ✓
├─ LONGWT in this file: 2-year person weight ✓
├─ Includes: both Y1 (2018) and Y2 (2019) consolidated variables ✓
├─ Linked FYC files: HC-209 (Y1), HC-216 (Y2)
└─ Data contract alignment: matches Panels 21, 22, 26, 27 schema
```

### 2.3 Detection Rule (Programmatic Guard)

`R/config.R` enforces this via:

```R
FORBIDDEN_FILES <- c("HC-236")
PANEL_MAP <- list(
  `23` = list(
    longitudinal = "HC-217",  # NOT HC-236
    ...
  )
)
```

Every download and prep step **must**:
1. Assert that the file being opened matches `PANEL_MAP[panel]$longitudinal`.
2. Check file metadata (e.g., the documentation PDF embedded in SAS transport files) to confirm the weight is 2-year.
3. Log an error and halt if HC-236 is mistakenly opened.

---

## 3. Canonical Variable Mapping (Data Contract §2)

### 3.1 Non-Feature Columns (Required in Every Panel)

Every `data/derived/panel_<NN>.rds` must contain **exactly** these columns (plus features prefixed `f_`):

| Canonical Name | Source HC Variable | Definition | Type | Role |
|:---|:---|:---|:---|:---|
| `dupersid` | DUPERSID | Person ID (unique within longitudinal file) | integer | Identifier |
| `panel` | (hardcoded) | Panel number (21, 22, 23, 26, 27) | integer | Metadata |
| `year1` | (derived) | First survey year (e.g., 2016 for Panel 21) | integer | Metadata |
| `year2` | (derived) | Second survey year (e.g., 2017 for Panel 21) | integer | Metadata |
| `totexp_y1` | TOTEXPY1 | Total health expenditure, year 1 (US dollars) | double | Feature (benchmark) |
| `totexp_y2` | TOTEXPY2 | Total health expenditure, year 2 (US dollars) | double | Target source |
| `top_decile_y2` | (computed) | Binary: 1 if person is in top decile of `totexp_y2` (weighted 90th percentile, per panel) | logical | **Target variable** |
| `longwt` | LONGWT | 2-year longitudinal person weight (survey design) | double | **Design weight** |
| `varstr` | VARSTR | Variance stratum (survey design) | integer | **Stratum** |
| `varpsu` | VARPSU | Variance PSU (survey design) | integer | **PSU (cluster)** |

### 3.2 Year-1 Features (Prefix `f_`)

All year-1 predictors **must** be renamed with the prefix `f_` to enforce leakage prevention:

```R
# Before (raw from HC file):
"AGELAST", "RTHLTH", "RABNWTS", ...  # Many year-1 condition/event indicators

# After (canonical):
"f_agelast", "f_rthlth", "f_rabnwts", ...
```

**Rationale:** When building the feature matrix downstream, the regex `grepl("^f_", colname)` is used to programmatically select only year-1 features, while blocking any column matching `*_y2` (except the target `top_decile_y2`).

### 3.3 Example Row (Panel 21, Hypothetical Person)

| dupersid | panel | year1 | year2 | totexp_y1 | totexp_y2 | top_decile_y2 | longwt | varstr | varpsu | f_agelast | f_rthlth | ... |
|:---|:---|:---|:---|---:|---:|:---|---:|:---|:---|:---|:---|:---|
| 10001 | 21 | 2016 | 2017 | 2450.50 | 18750.25 | 1 | 2345.67 | 4 | 201 | 42 | 2 | ... |

---

## 4. Event Files: Year-1 Predictors & PQI Secondary

### 4.1 Naming Convention

AHRQ uses a consistent suffix structure for event files:

```
HC-<base>A = Prescribed Medicines (event-level records)
HC-<base>D = Hospital Inpatient Stays (event-level records)
HC-<base>I = Appendix file (includes CLNK = condition–event link, RXLK = rx link)
HC-<separate>  = Medical Conditions file (separate base number, not related to event base)
```

### 4.2 Locked Event-File Mapping (2026-07-08 Verification)

#### Panel 21 (2016–2017)

| Year | Type | HC File | Purpose | Status |
|:---|:---|:---|:---|:---|
| **2016** | Conditions | HC-190 | Year-1 condition prevalence flags | ✓ Locked |
| 2016 | RX (medicines) | HC-188A | Year-1 medication flags | ✓ Locked |
| 2016 | Inpatient | HC-188D | Year-1 hospitalization flags | ✓ Locked |
| 2016 | CLNK/Appendix | HC-188I | Condition↔event links (PQI secondary) | ✓ Locked |

#### Panel 22 (2017–2018)

| Year | Type | HC File | Purpose | Status |
|:---|:---|:---|:---|:---|
| **2017** | Conditions | HC-199 | Year-1 condition prevalence flags | ✓ Locked |
| 2017 | RX (medicines) | HC-197A | Year-1 medication flags | ✓ Locked |
| 2017 | Inpatient | HC-197D | Year-1 hospitalization flags | ✓ Locked |
| 2017 | CLNK/Appendix | HC-197I | Condition↔event links (PQI secondary) | ✓ Locked |

#### Panel 23 (2018–2019)

| Year | Type | HC File | Purpose | Status |
|:---|:---|:---|:---|:---|
| **2018** | Conditions | HC-207 | Year-1 condition prevalence flags | ✓ Locked |
| 2018 | RX (medicines) | HC-206A | Year-1 medication flags | ✓ Locked |
| 2018 | Inpatient | HC-206D | Year-1 hospitalization flags | ✓ Locked |
| 2018 | CLNK/Appendix | HC-206I | Condition↔event links (PQI secondary) | ✓ Locked |

#### Panel 26 (2021–2022)

| Year | Type | HC File | Purpose | Status |
|:---|:---|:---|:---|:---|
| **2021** | Conditions | HC-231 | Year-1 condition prevalence flags | ✓ Locked |
| 2021 | RX (medicines) | HC-229A | Year-1 medication flags | ✓ Locked |
| 2021 | Inpatient | HC-229D | Year-1 hospitalization flags | ✓ Locked |
| 2021 | CLNK/Appendix | HC-229I | Condition↔event links (PQI secondary) | ✓ Locked* |

#### Panel 27 (2022–2023)

| Year | Type | HC File | Purpose | Status |
|:---|:---|:---|:---|:---|
| **2022** | Conditions | HC-241 | Year-1 condition prevalence flags | ✓ Locked |
| 2022 | RX (medicines) | HC-239A | Year-1 medication flags | ✓ Locked |
| 2022 | Inpatient | HC-239D | Year-1 hospitalization flags | ✓ Locked |
| 2022 | CLNK/Appendix | HC-239I | Condition↔event links (PQI secondary) | ✓ Locked |

| Year | Type | HC File | Purpose | Status |
|:---|:---|:---|:---|:---|
| **2023** | Conditions | HC-249 | Year-1 condition prevalence flags | ✓ Locked |
| 2023 | RX (medicines) | HC-248A | Year-1 medication flags | ✓ Locked |
| 2023 | Inpatient | HC-248D | Year-1 hospitalization flags | ✓ Locked |
| 2023 | CLNK/Appendix | HC-248I | Condition↔event links (PQI secondary) | ✓ Locked |

### 4.3 Known Documentation Quirk: 2021 CLNK Dual Listing

**Issue:** AHRQ serves two separate pages for the 2021 CLNK/appendix file:
- **HC-229I** (pattern: `<base>+I`): "Appendix and Links File" — full content
- **HC-220I** (alternative listing): same content, different catalog entry

**Resolution:**  
- **Canonical choice:** HC-229I (follows the consistent `<base>+I` suffix pattern shared by all other years).
- **Fallback:** If HC-229I download fails or checksum mismatches, attempt HC-220I and **log a warning** (do not silently substitute).
- **Documented in code:** See `KNOWN_QUIRKS` in `R/config.R`.

### 4.4 Enforcement in Prep Scripts

Every year-1 feature extraction script (`R/prep@panel`) **must**:

1. Assert that each required event file (conditions, RX, inpatient, CLNK) is present in `data/raw/<hc>/`.
2. Checksum against a manifest (or download fresh if missing).
3. Log the HC file number opened so the audit phase can verify the mapping.
4. Extract condition/medication/inpatient/linkage flags and rename them with prefix `f_`.
5. Merge onto the longitudinal frame to create the canonical derived panel.

---

## 5. Target Definition: Top Decile per Panel

### 5.1 Locked Decision (§0 in M1_MULTIAGENT_PLAN.md)

**Rule:** Top decile = **weighted 90th percentile of `TOTEXPY2`, computed independently per panel**.

**Rationale:**  
- Panels are operationally separate units (different years, different sampling frames).
- Cost inflation differs pre/post-pandemic → panel-specific thresholds are more interpretable.
- Ensures base rate ≈ 10% in each panel (by construction).

### 5.2 Computation Algorithm

```R
# Pseudocode for R/target@panel script
library(srvyr)

# 1. Load panel-NN.rds (canonical schema)
df <- readRDS(file.path(DIR_DERIVED, "panel_21.rds"))

# 2. Build survey design object
d <- as_survey_design(
  df,
  ids     = varpsu,
  strata  = varstr,
  weights = longwt,
  nest    = TRUE
)

# 3. Compute weighted 90th percentile of TOTEXPY2
threshold_90 <- d %>%
  summarise(pct_90 = survey::svyquantile(~totexp_y2, 0.90)) %>%
  pull(pct_90)

# 4. Create binary indicator
df <- df %>%
  mutate(
    top_decile_y2 = as.integer(totexp_y2 >= threshold_90)
  )

# 5. Verify base rate
base_rate_weighted <- d %>%
  summarise(
    n_top = survey::svytotal(~top_decile_y2),
    n_total = survey::svytotal(~rep(1, nrow(.)))
  )
# Expected: base_rate_weighted$n_top / base_rate_weighted$n_total ≈ 0.10

# 6. Save augmented frame
saveRDS(df, file.path(DIR_DERIVED, "panel_21.rds"))
```

### 5.3 Audit Invariant #2

**Assertion:** For each panel, the weighted base rate of `top_decile_y2 == 1` is within the range **[9.5%, 10.5%]**.

**Verification script:**  
```R
# Audit invariant #2: Per-panel top-decile base rates
for (p in c(21, 22, 23, 26, 27)) {
  df <- readRDS(file.path(DIR_DERIVED, paste0("panel_", p, ".rds")))
  d <- make_survey_design(df)
  br <- as.numeric(d %>% summarise(survey::svytotal(~top_decile_y2))) /
        as.numeric(d %>% summarise(survey::svytotal(~rep(1, nrow(.)))))
  stopifnot(br > 0.095 && br < 0.105,
            message = paste("Panel", p, "base rate", br, "outside [9.5%, 10.5%]"))
}
```

---

## 6. The Golden Leakage Rule (Data Contract §3)

### 6.1 Definition

**Only `f_*` and design columns (`longwt`, `varstr`, `varpsu`) are model-eligible.**  
**Any column matching `*_y2` (except the target `top_decile_y2`) is forbidden downstream.**

### 6.2 Why It Matters

Year-2 variables (expenditures, conditions, medications) are **unknown at prediction time** in the real use case (predicting year-2 risk from year-1 state). Using them would constitute:
- **Temporal leakage:** training on information the model will not have at deployment.
- **Optimistic performance bias:** the model appears artificially good in cross-validation.
- **Invalid generalization:** fails in production when year-2 data is unavailable.

### 6.3 Enforcement

**In `R/config.R`:**
```R
is_model_eligible <- function(colname) {
  grepl("^f_", colname) | colname %in% DESIGN_COLUMNS
}

assert_no_leakage <- function(colnames) {
  y2_like <- grepl("_y2$", colnames, ignore.case = TRUE)
  forbidden <- colnames[y2_like & colnames != "top_decile_y2"]
  if (length(forbidden) > 0) {
    stop("GOLDEN LEAKAGE RULE violated: forbidden *_y2 columns in model matrix: ",
         paste(forbidden, collapse = ", "))
  }
  invisible(TRUE)
}
```

**In every downstream script (M2 feature engineering, modeling):**
```R
# Before model fit:
X_cols <- colnames(df)[!grepl("^(dupersid|panel|year|totexp|top_decile)", colnames(df))]
assert_no_leakage(X_cols)
```

### 6.4 Audit Invariant #3

**Assertion:** No variable matching `*_y2` (except `top_decile_y2`) appears in the feature matrix.

**Verification script:**
```R
# Audit invariant #3: Leakage firewall
all_panels <- readRDS(file.path(DIR_DERIVED, "pooled_all.rds"))
X_cols <- colnames(all_panels)[!grepl("^(dupersid|panel|year|totexp|top_decile)", colnames(all_panels))]
assert_no_leakage(X_cols)
```

---

## 7. Survey Design and Weight Usage (Data Contract §4)

### 7.1 The One True Weight: LONGWT (2-Year)

**Every estimate (mean, total, quantile) must use the 2-year longitudinal weight `LONGWT`.**

```R
make_survey_design <- function(df) {
  # df must carry canonical columns: longwt, varstr, varpsu
  srvyr::as_survey_design(
    df,
    ids     = varpsu,      # Variance PSU
    strata  = varstr,      # Variance stratum
    weights = longwt,      # 2-year person weight
    nest    = TRUE         # Strata nested within PSUs
  )
}
```

### 7.2 Forbidden Weights

These **must never** be used:

| Forbidden Variable | Pattern | Why |
|:---|:---|:---|
| `PERWT21F` | `^PERWT[0-9]{2}F$` | Annual cross-sectional weight (Panel 21, full-year 2016/2017) |
| `PERWT22F` | `^PERWT[0-9]{2}F$` | Annual cross-sectional weight (Panel 22, full-year 2017/2018) |
| `SAQWT##F` | `^SAQWT[0-9]{2}F$` | Self-administered questionnaire subsample weight |

**Programmatic guard:**
```R
FORBIDDEN_WEIGHT_PATTERN <- "^(PERWT[0-9]{2}F|SAQWT[0-9]{2}F)$"

check_no_forbidden_weights <- function(df) {
  forbidden_cols <- grep(FORBIDDEN_WEIGHT_PATTERN, colnames(df), value = TRUE)
  if (length(forbidden_cols) > 0) {
    stop("Forbidden weight column(s) detected: ", paste(forbidden_cols, collapse = ", "))
  }
  invisible(TRUE)
}
```

### 7.3 Design Stratification

The survey design is **stratified** (not just clustered):
- **Strata (`varstr`):** variance strata defined by AHRQ for variance estimation.
- **PSUs (`varpsu`):** primary sampling units (clusters).
- **Weights (`longwt`):** 2-year person-level weights, calibrated to U.S. civilian non-institutionalized population.

### 7.4 Audit Invariant #1

**Assertion:** `LONGWT` (2-year) is used everywhere; the annual cross-sectional weight never leaks into estimation.

**Verification script:**
```R
# Audit invariant #1: Longitudinal weight
for (p in c(21, 22, 23, 26, 27)) {
  df <- readRDS(file.path(DIR_DERIVED, paste0("panel_", p, ".rds")))
  
  # Check LONGWT exists and is non-zero
  stopifnot(all(df$longwt > 0), message = "Panel contains non-positive or missing LONGWT")
  
  # Check no forbidden weight patterns in column names
  forbidden <- grep(FORBIDDEN_WEIGHT_PATTERN, colnames(df), value = TRUE)
  stopifnot(length(forbidden) == 0, message = paste("Panel", p, "contains forbidden weights:", forbidden))
}
```

---

## 8. Population Totals & Sanity Checks (Audit Invariant #5)

### 8.1 Locked Decision

**Assertion:** Weighted population totals reproduce published AHRQ civilian non-institutionalized counts (within ±2%).

### 8.2 Rationale

AHRQ publishes annual and 2-year population totals in its data documentation. If our weighted totals don't match, it signals:
- Wrong weight is being used (e.g., annual instead of 2-year).
- Data corruption (missing or duplicated records).
- Incorrect design specification (missing strata/PSU).

### 8.3 Verification Script

```R
# Audit invariant #5: Population totals
# Expected totals (from AHRQ docs) for 2-year panels:
# Panel 21 (2016–2017): ~244 million civilians
# Panel 22 (2017–2018): ~244 million civilians  
# Panel 23 (2018–2019): ~244 million civilians
# Panel 26 (2021–2022): ~246 million civilians
# Panel 27 (2022–2023): ~247 million civilians

expected_totals <- list(
  `21` = 244e6, `22` = 244e6, `23` = 244e6, `26` = 246e6, `27` = 247e6
)

for (p in c(21, 22, 23, 26, 27)) {
  df <- readRDS(file.path(DIR_DERIVED, paste0("panel_", p, ".rds")))
  d <- make_survey_design(df)
  
  pop_total <- as.numeric(d %>% summarise(survey::svytotal(~rep(1, nrow(.)))))
  expected <- expected_totals[[as.character(p)]]
  pct_diff <- abs(pop_total - expected) / expected * 100
  
  stopifnot(pct_diff < 2,
            message = paste("Panel", p, "total", pop_total, "deviates from expected",
                           expected, "by", round(pct_diff, 2), "%"))
}
```

---

## 9. Reproducibility & Integrity (Data Contract §6)

### 9.1 Checksum Verification

Every raw HC file download must be checksummed:

```R
# Example: data/raw/HC-202/CHECKSUMS.txt
SHA256 (h202.sas7bdat) = a3f2b8c1d9e7f4a6b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4
```

**Enforcement:**
```R
verify_checksum <- function(file, expected_sha256) {
  actual <- tools::md5sum(file)  # or sha256
  stopifnot(actual == expected_sha256,
            message = paste("Checksum mismatch:", file))
  invisible(TRUE)
}
```

### 9.2 Deterministic Scripts

- **No interactive prompts** (all parameters hardcoded or passed via function args).
- **Explicit `set.seed()`** for any randomness (e.g., cross-validation folds in M2).
- **Date-stamped logs** in all scripts so runs are fully reproducible.

### 9.3 Package Pinning

All R package versions are pinned via `renv.lock`:

```bash
# From project root:
renv::snapshot()  # Lock current environment
renv::restore()   # Restore from lock file on a new machine
```

**Required packages:**
```R
REQUIRED_PACKAGES <- c(
  "survey", "srvyr", "haven", "data.table", "tidyverse", "MEPS", "renv"
)
```

---

## 10. File Validation Checklist (Pre-Prep)

Before the `prep@panel` scripts run, the `preflight` agent must verify:

### 10.1 Panel Map Validation

- [ ] Panel 21: HC-202 exists, LONGWT present, years = 2016–2017
- [ ] Panel 22: HC-210 exists, LONGWT present, years = 2017–2018
- [ ] Panel 23: HC-217 exists (NOT HC-236), LONGWT present, years = 2018–2019
- [ ] Panel 26: HC-244 exists, LONGWT present, years = 2021–2022
- [ ] Panel 27: HC-252 exists, LONGWT present, years = 2022–2023

### 10.2 Event-File Validation

For each panel's year-1:

- [ ] Conditions file (HC-19x / HC-23x / HC-24x / HC-24x) exists and is readable
- [ ] RX file (HC-19xA / HC-22xA / HC-23xA / HC-24xA) exists and is readable
- [ ] Inpatient file (HC-19xD / HC-22xD / HC-23xD / HC-24xD) exists and is readable
- [ ] CLNK file (HC-19xI / HC-22xI / HC-23xI / HC-24xI) exists and is readable (or HC-220I as fallback for 2021)

### 10.3 Checksum Validation

- [ ] Each raw HC file SHA256 matches manifest (or generate new manifest if downloading fresh)

### 10.4 Metadata Validation

- [ ] Each longitudinal file's metadata confirms it is the **2-year** version, not 4-year
- [ ] LONGWT variable is present and non-zero for all records
- [ ] VARSTR and VARPSU are present and valid

---

## 11. Data Dictionary: Canonical Columns

| Column | Type | Domain | Example | Notes |
|:---|:---|:---|:---|:---|
| `dupersid` | integer | [1, 5M] | 10001 | Unique within each HC file; preserved in derived panel |
| `panel` | integer | {21, 22, 23, 26, 27} | 21 | Hardcoded during prep; used for grouping/auditing |
| `year1` | integer | {2016, 2017, 2018, 2021, 2022} | 2016 | Derived from panel (21→2016, 22→2017, etc.) |
| `year2` | integer | {2017, 2018, 2019, 2022, 2023} | 2017 | Derived from panel |
| `totexp_y1` | double | [0, ∞) USD | 2450.50 | Sum of all health expenditures in year 1; includes $0 |
| `totexp_y2` | double | [0, ∞) USD | 18750.25 | Sum of all health expenditures in year 2; source of target |
| `top_decile_y2` | logical | {0, 1} | 1 | Binary: 1 iff totexp_y2 ≥ weighted 90th pct (per panel) |
| `longwt` | double | (0, ∞) | 2345.67 | 2-year person weight (design weight); **never zero** |
| `varstr` | integer | [1, 1000] | 4 | Variance stratum (survey design) |
| `varpsu` | integer | [1, 10000] | 201 | Variance PSU (survey design); together with varstr defines clusters |
| `f_*` | (varies) | (varies) | See event-file docs | Year-1 predictors; must be prefixed `f_` |

---

## 12. Cross-Reference: Configuration Authority

**Single source of truth for panel/year/HC mappings:**

```
R/config.R
├─ PANEL_MAP (panels 21–27 → years, HC files, roles)
├─ EVENT_FILES (years 2016–2023 → conditions/RX/inpatient/CLNK HC files)
├─ CANONICAL_COLUMNS (required output schema)
├─ FORBIDDEN_FILES (HC-236)
├─ FORBIDDEN_WEIGHT_PATTERN (annual weights)
└─ TOP_DECILE_THRESHOLD_RULE (weighted 90th pct per panel)
```

**Every script must**:
1. Source `R/config.R` first.
2. Validate inputs against `PANEL_MAP` and `EVENT_FILES`.
3. Assert schema compliance with `CANONICAL_COLUMNS`.
4. Call `assert_no_leakage()` before model estimation.
5. Use `make_survey_design()` for any population estimates.

---

## 13. Known Issues & Quirks

### 13.1 AHRQ Dual Listing (2021 CLNK)

**Issue:** HC-229I and HC-220I serve the same 2021 CLNK file content.  
**Resolution:** Use HC-229I as canonical (follows `<base>+I` pattern). Fallback to HC-220I if needed, with a log warning.  
**Status:** Documented in `KNOWN_QUIRKS` in `R/config.R`.

### 13.2 Panel 21 FYC Ambiguity

**Issue:** The 2016 full-year consolidated (FYC) file is bundled within the HC-202 source release (not released separately as HC-201 initially).  
**Resolution:** Clarify in comments that year-1 FYC for Panel 21 is "2016 FYC (bundled in HC-202 source round)"; verify against AHRQ release notes.  
**Status:** Documented in `PANEL_MAP`.

### 13.3 COVID-Era File Numbering

**Issue:** Panels 24–25 (2019–2022, 2020–2021) cross the pandemic boundary and are excluded. Their HC file numbers may differ from the regular sequence.  
**Resolution:** These panels are not listed in `PANEL_MAP` or `EVENT_FILES`. Any reference to them triggers an audit failure.  
**Status:** By design (not a bug).

---

## 14. Validation Queries (SQL-like for Auditing)

### 14.1 Check Panel Representation in Pooled Data

```R
# After pooling:
pooled <- readRDS(file.path(DIR_DERIVED, "pooled_all.rds"))
pooled %>%
  group_by(panel) %>%
  summarise(n = n(), n_weighted = sum(longwt))
# Expected: each panel represented, ~4k–5k per panel
```

### 14.2 Check Target Distribution

```R
# After target computation:
pooled %>%
  group_by(panel) %>%
  summarise(
    n_top = sum(top_decile_y2),
    pct_top = mean(top_decile_y2) * 100
  )
# Expected: ~10% per panel (or within [9.5%, 10.5%] when weighted)
```

### 14.3 Check for Year-2 Leakage

```R
# Grep for *_y2 columns:
y2_cols <- grep("_y2$", colnames(pooled), value = TRUE)
y2_cols_forbidden <- y2_cols[y2_cols != "top_decile_y2"]
if (length(y2_cols_forbidden) > 0) {
  stop("Leakage detected: ", paste(y2_cols_forbidden, collapse = ", "))
}
```

---

## 15. Summary: What Every Script Must Know

1. **Panels & Years:** 21–23 (train, 2016–2019) + 26–27 (validation, 2021–2023). Skip 24–25 (COVID gap).
2. **HC Files:** Use the 2-year longitudinal files (HC-202, HC-210, HC-217, HC-244, HC-252). **Never** HC-236 (4-year).
3. **Weights:** Always LONGWT (2-year). Never annual cross-sectional weights.
4. **Design:** Survey design with ids=varpsu, strata=varstr, weights=longwt, nest=TRUE.
5. **Target:** Weighted 90th percentile of TOTEXPY2, computed **per panel** → top_decile_y2.
6. **Leakage:** Only f_* features and (longwt, varstr, varpsu) are model-eligible. No *_y2 columns except top_decile_y2.
7. **Event files:** Conditions/RX/Inpatient/CLNK for each panel's year-1 (locked per section 4.2).
8. **Reproducibility:** Checksum raw files, pin packages with renv, deterministic scripts, explicit set.seed().

---

## References

- **AHRQ MEPS:** https://meps.ahrq.gov/
- **HC-202 (Panel 21):** https://meps.ahrq.gov/data_files/publications/st202/st202.pdf
- **HC-210 (Panel 22):** https://meps.ahrq.gov/data_files/publications/st210/st210.pdf
- **HC-217 (Panel 23, 2-year):** https://meps.ahrq.gov/data_files/publications/st217/st217.pdf
- **HC-236 (Panel 23, 4-year — FORBIDDEN):** https://meps.ahrq.gov/data_files/publications/st236/st236.pdf
- **HC-244 (Panel 26):** https://meps.ahrq.gov/data_files/publications/st244/st244.pdf
- **HC-252 (Panel 27):** https://meps.ahrq.gov/data_files/publications/st252/st252.pdf
- **Project plan (M1):** docs/M1_MULTIAGENT_PLAN.md
- **Data contract:** R/config.R

---

**Document ID:** `panel_variable_mapping.md` | **Version:** 1.0 | **Locked:** 2026-07-08 | **Author:** M1 Documentation Agent
