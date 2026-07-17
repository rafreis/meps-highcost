# M1 — Multi-Agent Execution Plan

**Project:** MEPS High-Cost Risk Prediction — TRIPOD+AI manuscript (JPMedAI)
**Scope of this doc:** how Milestone 1 is executed by a multi-agent `Workflow`. Nothing here runs the analysis by itself — the runnable script lives at [`workflows/m1_pipeline.workflow.js`](../workflows/m1_pipeline.workflow.js).
**Status:** authored 2026-07-08, awaiting "go". Design decisions locked with the user (below).

---

## 0. Locked decisions (signed off)

| Decision | Choice |
|---|---|
| Train panels | **21 + 22 + 23** (2016–2019) |
| Validation panels | **26 + 27** (2021–2023) |
| Gap (excluded) | Panels 24 (2019–22) & 25 (2020–21) — COVID-extended, gives clean temporal separation |
| Top-decile threshold | **Weighted 90th percentile of `TOTEXPY2`, computed per panel** (handles cost inflation) |
| AHRQ-PQI secondary | **Documented CCSR / 3-digit-ICD approximation**, disclosed as a deviation from the exact v2024 spec |

## 1. Verified data map (against AHRQ docs)

Two-year longitudinal panel files (the spine — each carries both years' consolidated variables with `Y1`/`Y2` suffixes, plus `LONGWT` / `VARSTR` / `VARPSU`):

| Panel | Y1–Y2 | 2-yr longitudinal file | Linked Y1 FYC | Linked Y2 FYC | Role |
|---|---|---|---|---|---|
| 21 | 2016–2017 | **HC-202** | 2016 FYC | HC-201 | Train |
| 22 | 2017–2018 | **HC-210** | HC-201 | HC-209 | Train |
| 23 | 2018–2019 | **HC-217** | HC-209 | HC-216 | Train |
| 26 | 2021–2022 | **HC-244** | HC-233 | HC-243 | Validation |
| 27 | 2022–2023 | **HC-252** | HC-243 | HC-251 | Validation |

⚠️ **Do not use HC-236** (Panel 23 *four-year* file, 2018–2021) — its `LONGWT` is a 4-year weight, wrong for a 2-year analysis.

**Design/target variables (confirmed present):** `LONGWT` (2-yr person weight), `VARSTR`, `VARPSU`; target source `TOTEXPY2`; prior-cost benchmark `TOTEXPY1`.

**Event files (year-1 predictors + PQI secondary) — to LOCK in pre-flight:**
- Prescribed Medicines: 2018 = HC-206A, 2019 = HC-213A, 2020 = HC-220A, 2021 = HC-229A ✔ ; **confirm 2016, 2017, 2022, 2023**.
- Medical Conditions: 2016 = HC-190, 2019 = HC-214, 2022 = HC-241 ✔ ; **confirm 2017, 2018, 2021, 2023**.
- Also needed for PQI: Hospital Inpatient Stays event files + `CLNK` (condition–event link) files for the relevant years.

## 2. Orchestration architecture

Principle: **parallel authoring + verification; ordered execution** (per-panel fan-out where embarrassingly parallel, barriers where correctness needs the full set).

| Phase | Type | Agents | Output |
|---|---|---|---|
| 0. Preflight | sequential (1) | `preflight` | Verify R + CRAN pkgs (halt-fast if absent); lock event-file HC numbers vs AHRQ; write `R/config.R` + data-contract; scaffold dirs |
| 1. Prep | pipeline, fan-out 5 | `prep@<panel>` | Download longitudinal file → load → **harmonize Y1/Y2 names** vs each panel codebook → `data/derived/panel_<NN>.rds` (canonical schema) |
| 2. Target | pipeline (stage 2) | `target@<panel>` | Per-panel weighted 90th pct of `TOTEXPY2` → `top_decile_y2`; survey design object; "transition" subsample |
| 3. Pool | **barrier** (1) | `pool` | Stack panels; assert base-rate ≈10% per panel; reproduce weighted population totals vs published AHRQ counts |
| 4. Deliverables | parallel (4) | `protocol`, `litreview`, `tripod`, `mapdoc` | PROTOCOL.md, literature_review.md, TRIPOD-AI_checklist.md, panel_variable_mapping.md (overlaps phases 1–3) |
| 5. Audit | parallel (5 skeptics) | `audit:*` | Adversarial verdict on each invariant (default = FAIL if in doubt) |
| 6. Synthesis | sequential (1) | `synth` | M1 report + go/no-go verdict for M2 |

## 3. The 5 invariants audited adversarially (Phase 5)

1. **Longitudinal weight** — `LONGWT` (2-yr) is used everywhere; the annual cross-sectional weight (`PERWTxxF`/`SAQWT`) never leaks into estimation.
2. **Per-panel threshold** — top-decile = weighted 90th pct of `TOTEXPY2` computed *within* each panel; base rate ≈10% in each.
3. **Leakage firewall** — no `*Y2` variable (esp. year-2 spend) enters the feature set; every predictor is year-1.
4. **Mapping** — panel↔year↔HC matches AHRQ; HC-236 (4-yr) was **not** substituted for HC-217.
5. **Population totals** — weighted totals reproduce AHRQ's published civilian non-institutionalized counts (design sanity check).

## 4. Data contract (every agent obeys — makes parallel work compose)

- **Dirs:** `data/raw/<hc>/` (immutable) · `data/derived/panel_<NN>.rds` (identical schema across panels) · `outputs/` · `protocol/` · `docs/`.
- **Canonical columns:** `dupersid, panel, year1, year2, totexp_y1, totexp_y2, top_decile_y2, longwt, varstr, varpsu` + year-1 features prefixed `f_`.
- **Golden leakage rule:** only `f_*` and design columns (`longwt/varstr/varpsu`) are model-eligible; anything matching `*_y2` (except the target) is forbidden downstream.
- **Structured returns:** every agent returns JSON against its schema so `synth` integrates without parsing.
- **Reproducibility:** raw files checksummed; `renv.lock` pins package versions; scripts are deterministic and re-runnable.

## 5. Pre-flight checklist (before "go")

- [ ] R installed + `Rscript` on PATH; CRAN pkgs: `survey`, `srvyr`, `haven`, `data.table`, `tidyverse`, `MEPS` (HHS-AHRQ helper). Pin with `renv`.
- [ ] Lock the 8 unconfirmed event-file HC numbers (Conditions 2017/2018/2021/2023; RX 2016/2017/2022/2023) + inpatient + `CLNK` files.
- [ ] Confirm project root: `C:\Users\Rafael\Dropbox\Fiverr\Trabalhos\meps-highcost\`.
- [ ] Decide agent execution level: agents run the R (real download + target) vs author+verify only. Recommended: agents author+verify **and** run per-panel prep; pool/audit run in order.

## 6. How to launch (when ready)

Run the workflow (this triggers real downloads + R execution):

> Ask Claude: **"run the M1 workflow"** → it calls `Workflow({ scriptPath: "meps-highcost/workflows/m1_pipeline.workflow.js" })`.

To iterate the script without a full re-run, edit the file and resume with `resumeFromRunId` (unchanged `agent()` calls return cached).

## 7. Out of scope here (M2/M3)

M2 (GBT + calibration + SHAP + temporal external validation + DCA vs prior cost + subgroup calibration/DCA + PQI check) and M3 (TRIPOD+AI manuscript) get their own workflows once M1's go/no-go passes. That is where the heavy fan-out (per-model, per-subgroup, per-figure) pays off.
