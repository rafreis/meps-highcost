export const meta = {
  name: 'meps-m1-pipeline',
  description: 'MEPS high-cost M1: build weighted top-decile target + survey design across 5 longitudinal panels, author protocol/lit/TRIPOD deliverables, and adversarially verify the 5 study-invalidating invariants.',
  whenToUse: 'Run to execute Milestone 1 of the MEPS TRIPOD+AI high-cost study end-to-end. Triggers real MEPS downloads and R execution. See docs/M1_MULTIAGENT_PLAN.md.',
  phases: [
    { title: 'Preflight', detail: 'verify R+pkgs, lock event-file HC numbers, write config + data contract' },
    { title: 'Prep', detail: 'per-panel download, load, harmonize Y1/Y2 names (fan-out 5)' },
    { title: 'Target', detail: 'per-panel weighted 90th-pct target + survey design object' },
    { title: 'Pool', detail: 'stack panels, base-rate + weighted-total sanity checks' },
    { title: 'Deliverables', detail: 'protocol, literature review, TRIPOD checklist, mapping doc' },
    { title: 'Audit', detail: 'adversarial verification of the 5 invariants' },
    { title: 'Synthesis', detail: 'M1 report + go/no-go for M2' },
  ],
}

// ---------------------------------------------------------------------------
// Static, verified configuration (see docs/M1_MULTIAGENT_PLAN.md §1)
// ---------------------------------------------------------------------------
const ROOT = 'meps-highcost'
const PANELS = [
  { panel: '21', y1: 2016, y2: 2017, file: 'h202', role: 'train',      fyc_y1: '2016 FYC', fyc_y2: 'HC-201' },
  { panel: '22', y1: 2017, y2: 2018, file: 'h210', role: 'train',      fyc_y1: 'HC-201',   fyc_y2: 'HC-209' },
  { panel: '23', y1: 2018, y2: 2019, file: 'h217', role: 'train',      fyc_y1: 'HC-209',   fyc_y2: 'HC-216' },
  { panel: '26', y1: 2021, y2: 2022, file: 'h244', role: 'validation', fyc_y1: 'HC-233',   fyc_y2: 'HC-243' },
  { panel: '27', y1: 2022, y2: 2023, file: 'h252', role: 'validation', fyc_y1: 'HC-243',   fyc_y2: 'HC-251' },
]
const CONTRACT = [
  `Project root: ${ROOT}/. Raw files immutable under data/raw/<hc>/; derived frames at data/derived/panel_<NN>.rds with an IDENTICAL schema across panels.`,
  'Canonical columns: dupersid, panel, year1, year2, totexp_y1, totexp_y2, top_decile_y2, longwt, varstr, varpsu, plus year-1 features prefixed f_.',
  'GOLDEN LEAKAGE RULE: only f_* and design columns (longwt/varstr/varpsu) are model-eligible. Any column matching *_y2 (except the target top_decile_y2) is forbidden downstream.',
  'Weight = LONGWT (2-year). NEVER the annual cross-sectional weight (PERWT##F / SAQWT##F). Design: survey/srvyr with ids=varpsu, strata=varstr, weights=longwt, nest=TRUE.',
  'Do NOT use HC-236 (Panel 23 four-year file). Panel 23 = HC-217 (two-year).',
  'Reproducibility: checksum raw downloads, pin packages with renv, deterministic re-runnable scripts.',
]
const INVARIANTS = [
  { key: 'weight',    claim: 'LONGWT (2-year longitudinal weight) is used in every weighted estimate; no annual cross-sectional weight leaks into estimation.' },
  { key: 'threshold', claim: 'top_decile_y2 = weighted 90th percentile of TOTEXPY2 computed WITHIN each panel; weighted base rate is ~10% in every panel.' },
  { key: 'leakage',   claim: 'No *_y2 variable (especially year-2 expenditure) is present in the feature set; every predictor derives from year 1.' },
  { key: 'mapping',   claim: 'panel<->year<->HC file mapping matches AHRQ exactly, and HC-236 (four-year) was NOT substituted for HC-217.' },
  { key: 'totals',    claim: 'Weighted population totals reproduce AHRQ published civilian non-institutionalized counts within rounding.' },
]
const DELIVERABLES = [
  { key: 'protocol',  prompt: 'Write protocol/PROTOCOL.md: primary endpoint (top-decile TOTEXPY2, per-panel weighted threshold), transition sensitivity, secondary AHRQ-PQI #08/#05 as a documented CCSR/3-digit-ICD approximation (state the deviation), survey design, temporal external validation design (train P21/22/23, validate P26/27), leakage guard, and modeling plan for M2.' },
  { key: 'litreview', prompt: 'Write docs/literature_review.md: the 2-3 closest MEPS high-cost prediction papers (e.g., Yang & Delen 2018 BioMedEngOnline; recent ensemble ML; claims-data high-cost) and our explicit point of difference (survey design through calibration + subgroup metrics; temporal external validation on non-overlapping post-COVID panels; DCA vs prior-year cost; subgroup calibration + DCA by income and race/ethnicity; TRIPOD+AI). Use web search + fetch; cite in Vancouver style.' },
  { key: 'tripod',    prompt: 'Start protocol/TRIPOD-AI_checklist.md from the TRIPOD+AI 2024 items, pre-filling every item decided so far (design, data source, outcome, predictors policy, validation, fairness/subgroup plan) and marking the rest TODO.' },
  { key: 'mapdoc',    prompt: 'Write docs/panel_variable_mapping.md documenting the verified panel<->year<->HC-file<->variable mapping (LONGWT/VARSTR/VARPSU, TOTEXPY1/Y2), the COVID four-year-extension trap (HC-236), and the locked event-file HC numbers from preflight.' },
]

// Cost policy: never use Opus. sonnet for reasoning-heavy work, haiku for mechanical docs.
const DELIVERABLE_MODEL = { protocol: 'sonnet', litreview: 'sonnet', tripod: 'haiku', mapdoc: 'haiku' }

// ---------------------------------------------------------------------------
// Schemas (JSON Schema -> agent() returns validated objects)
// ---------------------------------------------------------------------------
const PREFLIGHT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['r_available', 'packages_ok', 'event_files_locked', 'config_written', 'blockers'],
  properties: {
    r_available: { type: 'boolean' },
    r_version: { type: 'string' },
    packages_ok: { type: 'boolean' },
    event_files_locked: { type: 'array', items: { type: 'object', additionalProperties: true } },
    config_written: { type: 'boolean' },
    blockers: { type: 'array', items: { type: 'string' } },
  },
}
const PANEL_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['panel', 'file', 'derived_path', 'n_rows', 'harmonized_ok', 'notes'],
  properties: {
    panel: { type: 'string' }, file: { type: 'string' },
    derived_path: { type: 'string' }, n_rows: { type: 'integer' },
    harmonized_ok: { type: 'boolean' },
    unresolved_vars: { type: 'array', items: { type: 'string' } },
    notes: { type: 'string' },
  },
}
const TARGET_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['panel', 'threshold', 'weighted_base_rate', 'n_top', 'design_ok', 'transition_n'],
  properties: {
    panel: { type: 'string' },
    threshold: { type: 'number' }, weighted_base_rate: { type: 'number' },
    n_top: { type: 'integer' }, transition_n: { type: 'integer' },
    design_ok: { type: 'boolean' },
  },
}
const POOL_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['panels_pooled', 'per_panel_base_rate', 'totals_match_published', 'issues'],
  properties: {
    panels_pooled: { type: 'array', items: { type: 'string' } },
    per_panel_base_rate: { type: 'array', items: { type: 'object', additionalProperties: true } },
    totals_match_published: { type: 'boolean' },
    issues: { type: 'array', items: { type: 'string' } },
  },
}
const DOC_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['deliverable', 'path', 'complete'],
  properties: {
    deliverable: { type: 'string' }, path: { type: 'string' },
    complete: { type: 'boolean' }, open_items: { type: 'array', items: { type: 'string' } },
  },
}
const VERDICT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['invariant', 'passed', 'evidence'],
  properties: {
    invariant: { type: 'string' },
    passed: { type: 'boolean' },
    evidence: { type: 'string' },
    fix_required: { type: 'string' },
  },
}
const M1_REPORT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['go_for_m2', 'summary', 'invariants_failed', 'artifacts', 'open_items'],
  properties: {
    go_for_m2: { type: 'boolean' },
    summary: { type: 'string' },
    invariants_failed: { type: 'array', items: { type: 'string' } },
    artifacts: { type: 'array', items: { type: 'string' } },
    open_items: { type: 'array', items: { type: 'string' } },
  },
}

const contractText = CONTRACT.map((c, i) => `${i + 1}. ${c}`).join('\n')

// ---------------------------------------------------------------------------
// Orchestration
// ---------------------------------------------------------------------------
phase('Preflight')
const pre = await agent(
  `You are the preflight agent for the MEPS M1 pipeline. Working from ${ROOT}/.
DATA CONTRACT (enforce everywhere):
${contractText}

Tasks:
1. Verify Rscript is on PATH and report r_version. If R is missing, install it / add to PATH; if you cannot, record a blocker and set r_available=false (do NOT fake success).
2. Ensure CRAN packages present (install if missing) and pin with renv: survey, srvyr, haven, data.table, tidyverse, and the HHS-AHRQ MEPS helper package.
3. Lock the still-unconfirmed event-file HC numbers against meps.ahrq.gov (Medical Conditions 2017/2018/2021/2023; Prescribed Medicines 2016/2017/2022/2023) plus the Hospital Inpatient Stays and CLNK link files for those years. Return them in event_files_locked.
4. Scaffold dirs (data/raw, data/derived, outputs, protocol, docs) and write R/config.R holding the verified panel map and the data-contract constants.
Return the schema. If any hard blocker exists, list it in blockers.`,
  { schema: PREFLIGHT_SCHEMA, phase: 'Preflight', model: 'sonnet' }
)

if (!pre || !pre.r_available || (pre.blockers && pre.blockers.length)) {
  log(`Preflight blocked: ${pre ? JSON.stringify(pre.blockers) : 'agent returned null'}. Halting before any download.`)
  return { go_for_m2: false, summary: 'Halted at preflight — environment not ready.', invariants_failed: [], artifacts: [], open_items: pre ? pre.blockers : ['preflight failed'] }
}

// Per-panel prep -> target as an independent pipeline (fan-out 5, no barrier between stages),
// overlapped with the independent authoring deliverables.
const pipelinePromise = pipeline(
  PANELS,
  (p) => agent(
    `Prep panel ${p.panel} (${p.y1}-${p.y2}), MEPS 2-year longitudinal file ${p.file}.
DATA CONTRACT:
${contractText}
Steps: download ${p.file} from AHRQ into data/raw/${p.file}/ (checksum), load in R, and harmonize the Y1/Y2 variable names against THIS panel's codebook (names drift year to year — reconcile carefully). Write data/derived/panel_${p.panel}.rds with the canonical schema. Report unresolved_vars for anything you could not map.`,
    { label: `prep@${p.panel}`, phase: 'Prep', schema: PANEL_SCHEMA, model: 'sonnet' }
  ),
  (prev, p) => agent(
    `Build the target + survey design for panel ${p.panel} from data/derived/panel_${p.panel}.rds.
Compute top_decile_y2 = WEIGHTED 90th percentile of TOTEXPY2 within THIS panel using LONGWT (survey/srvyr design: ids=varpsu, strata=varstr, weights=longwt, nest=TRUE). Report the threshold, the weighted base rate (must be ~10%), n_top, and the size of the "transition" subsample (not top-decile in year 1). Set design_ok only if the survey design object builds and the weighted base rate is within [0.08, 0.12].`,
    { label: `target@${p.panel}`, phase: 'Target', schema: TARGET_SCHEMA, model: 'sonnet' }
  )
)
const docsPromise = parallel(
  DELIVERABLES.map((d) => () =>
    agent(`${d.prompt}\n\nDATA CONTRACT:\n${contractText}`, { label: d.key, phase: 'Deliverables', schema: DOC_SCHEMA, model: DELIVERABLE_MODEL[d.key], effort: (d.key === 'protocol' || d.key === 'litreview') ? 'medium' : 'low' })
  )
)
const [prepped, docs] = await Promise.all([pipelinePromise, docsPromise])
const targets = prepped.filter(Boolean)

// Barrier: pool + cross-panel sanity
phase('Pool')
const pooled = await agent(
  `Pool the 5 per-panel derived frames into one stacked analysis frame (data/derived/pooled.rds), tagging train (P21/22/23) vs validation (P26/27).
Per-panel target results: ${JSON.stringify(targets)}.
Assert: (a) weighted base rate ~10% in EACH panel; (b) weighted population totals reproduce AHRQ published civilian non-institutionalized counts within rounding. List any discrepancies in issues.`,
  { schema: POOL_SCHEMA, phase: 'Pool', model: 'sonnet' }
)

// Adversarial verification of the 5 invariants (each skeptic tries to REFUTE)
phase('Audit')
const audits = (await parallel(
  INVARIANTS.map((inv) => () =>
    agent(
      `Adversarially AUDIT this invariant of the M1 build. Try to REFUTE it by inspecting the actual R code and derived data under ${ROOT}/. Default passed=false if you cannot positively confirm it.
INVARIANT [${inv.key}]: ${inv.claim}
If it fails, give the concrete evidence and the exact fix_required.`,
      { label: `audit:${inv.key}`, phase: 'Audit', schema: VERDICT_SCHEMA, model: 'sonnet', effort: 'high' }
    )
  )
)).filter(Boolean)

// Synthesis
phase('Synthesis')
const failed = audits.filter((a) => !a.passed).map((a) => a.invariant)
const report = await agent(
  `Synthesize the M1 completion report for the MEPS TRIPOD+AI high-cost study.
Preflight: ${JSON.stringify(pre)}
Per-panel targets: ${JSON.stringify(targets)}
Pool sanity: ${JSON.stringify(pooled)}
Audits: ${JSON.stringify(audits)}
Deliverables: ${JSON.stringify((docs || []).filter(Boolean))}
Set go_for_m2 = true ONLY if all 5 invariants passed and pool sanity holds. List invariants_failed (${JSON.stringify(failed)}), artifacts produced, and open_items for M2.`,
  { schema: M1_REPORT_SCHEMA, phase: 'Synthesis', model: 'sonnet' }
)
return report
