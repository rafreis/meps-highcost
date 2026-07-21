// Builds the submission-ready TRIPOD+AI checklist (Supplementary File 1).
const fs = require("fs"); const path = require("path");
const { Document, Packer, Paragraph, TextRun, AlignmentType, Table, TableRow,
  TableCell, WidthType, ShadingType, Footer, PageNumber } = require("docx");
const OUTDIR = path.join(__dirname, "outputs", "manuscript");
fs.mkdirSync(OUTDIR, { recursive: true });
const FONT = "Times New Roman";
const r = (t, o = {}) => new TextRun({ text: t, font: FONT, size: 20, ...o });
const P = (t, o = {}) => new Paragraph({ spacing: { after: o.after ?? 140, line: 280 },
  alignment: o.align || AlignmentType.JUSTIFIED, children: Array.isArray(t) ? t : [r(t, o)] });
const H = (t) => new Paragraph({ spacing: { before: 240, after: 100 },
  children: [new TextRun({ text: t, font: FONT, bold: true, size: 23 })] });

const W = [900, 3900, 4300];
const cell = (t, { bold = false, shade = false } = {}, w) => new TableCell({
  width: { size: w, type: WidthType.DXA },
  shading: shade ? { type: ShadingType.CLEAR, fill: "D9E2F3", color: "auto" } : undefined,
  margins: { top: 50, bottom: 50, left: 80, right: 80 },
  children: [new Paragraph({ spacing: { after: 0 }, children: [new TextRun({ text: String(t), font: FONT, size: 17, bold })] })] });
const section = (label) => new TableRow({ children: [new TableCell({
  columnSpan: 3, width: { size: W[0]+W[1]+W[2], type: WidthType.DXA },
  shading: { type: ShadingType.CLEAR, fill: "EDF2FA", color: "auto" },
  margins: { top: 60, bottom: 60, left: 80, right: 80 },
  children: [new Paragraph({ spacing: { after: 0 }, children: [new TextRun({ text: label, font: FONT, bold: true, size: 18 })] })] })] });
const row = (n, item, where) => new TableRow({ children: [cell(n, {}, W[0]), cell(item, {}, W[1]), cell(where, {}, W[2])] });

const rows = [
  new TableRow({ tableHeader: true, children: [cell("Item", { bold: true, shade: true }, W[0]),
    cell("TRIPOD+AI checklist item", { bold: true, shade: true }, W[1]),
    cell("Where addressed", { bold: true, shade: true }, W[2])] }),
  section("TITLE AND ABSTRACT"),
  row("1", "Identify the study as developing or validating a prediction model, the target population, and the outcome.", "Title page"),
  row("2", "Structured abstract: background, methods, results, conclusions.", "Abstract"),
  section("INTRODUCTION"),
  row("3a", "Background: rationale, existing models, and the clinical context.", "§1, paragraphs 1–2"),
  row("3b", "Objectives, including the intended use and the closest prior work.", "§1, paragraphs 3–4 (precedent and point of difference)"),
  section("METHODS — DATA"),
  row("4a", "Source of data and rationale for its use.", "§2.1"),
  row("4b", "Dates of participant accrual and of outcome determination.", "§2.1 (panels 21–23, 2016–2019; panels 26–27, 2021–2023)"),
  row("5a", "Setting, including complex sampling structure.", "§2.1, §2.3"),
  row("5b", "Eligibility criteria and exclusions.", "§2.1 (panels 24–25 excluded; rationale given)"),
  row("6a", "Outcome definition, including how and when assessed.", "§2.2 (weighted 90th percentile of year-2 expenditure, per panel)"),
  row("6b", "Steps to prevent outcome information leaking into predictors.", "§2.2 (leakage firewall); §3.2"),
  row("7a", "Predictors: definition, timing, and selection.", "§2.4; §3.2; the final feature set is defined in the code repository"),
  row("7b", "Predictor assessment blinded to the outcome.", "§2.2 (predictors restricted to year 1 by construction)"),
  row("8", "Sample size and its justification.", "§3.1 (44,225 development; 15,033 validation; all eligible respondents)"),
  row("9", "Missing data: how handled.", "§2.5 (native handling in the tree model); §2.8 (comparators)"),
  section("METHODS — ANALYSIS"),
  row("10a", "Analytical methods, including how the sampling design was accommodated.", "§2.3, §2.5"),
  row("10b", "Model-building procedure, hyperparameter selection, and internal validation.", "§2.5 (cluster-respecting five-fold cross-validation)"),
  row("11", "Class imbalance and how it was addressed.", "§2.2 (10% event rate by construction; weighted estimation; calibration assessed)"),
  row("12", "Model output and how risks are presented.", "§2.6 (predicted probability; top-decile operating point)"),
  row("13", "Performance measures, including calibration and uncertainty.", "§2.6 (weighted AUC with design-based bootstrap CIs, calibration slope, CITL, Brier)"),
  row("14", "Fairness: subgroup evaluation and rationale.", "§2.7, §3.6 (calibration and discrimination by income and race/ethnicity)"),
  row("15", "Model comparison and clinical utility.", "§2.5 (comparators), §2.7 and §3.5 (decision-curve analysis vs prior-year cost)"),
  section("OPEN SCIENCE"),
  row("16a", "Funding and role of the funder.", "Title page; Declarations (none)"),
  row("16b", "Conflicts of interest.", "Title page; Declarations (none)"),
  row("16c", "Protocol and reporting guideline.", "Declarations; Supplementary protocol"),
  row("16d", "Data availability.", "Declarations (public MEPS files, AHRQ)"),
  row("16e", "Code availability.", "Declarations (https://github.com/rafreis/meps-highcost, MIT licence)"),
  section("RESULTS"),
  row("17", "Participant flow and characteristics of development and validation cohorts.", "§3.1; Table 1"),
  row("18", "Model specification and how predictions are obtained.", "§2.5; §3.2; Supplementary code"),
  row("19a", "Model performance: discrimination and calibration, with uncertainty.", "§3.3; Table 2; Figure 1"),
  row("19b", "Performance in relevant subgroups.", "§3.6; Table 3"),
  row("19c", "Clinical utility.", "§3.5; Figure 3"),
  row("20", "Model interpretability / explanation.", "§3.4; Figure 2"),
  row("21", "Secondary and sensitivity analyses.", "§3.7 (AHRQ-PQI concordance; transition analysis)"),
  section("DISCUSSION"),
  row("22", "Interpretation, in the context of objectives and prior evidence.", "§4, paragraphs 1–3"),
  row("23", "Limitations, including data, methodological, and generalisability limits.", "§4.1"),
  row("24", "Usability and implications for practice.", "§4, paragraph 2; §4.2"),
];

const C = [];
C.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 120 },
  children: [new TextRun({ text: "Supplementary File 1. TRIPOD+AI reporting checklist", font: FONT, bold: true, size: 26 })] }));
C.push(P([r("Manuscript: ", { bold: true }), r("Survey-Weighted Machine Learning for Prospective Stratification of High-Cost Patients: A Design-Based Pipeline with External Temporal Validation, Decision-Curve Analysis, and Subgroup Calibration in a Nationally Representative U.S. Cohort", { italics: true })]));
C.push(P([r("Author: "), r("Rafael dos Reis, Independent Researcher, Curitiba, Brazil.")]));
C.push(P("This checklist maps the manuscript to the TRIPOD+AI (2024) reporting items. Section numbers refer to the numbered headings in the manuscript."));
C.push(new Table({ columnWidths: W, width: { size: W[0]+W[1]+W[2], type: WidthType.DXA }, rows }));
C.push(H("Note on study type"));
C.push(P("This study reports both the development of a prediction model and its external validation in a temporally distinct, non-overlapping sample. Items relating to model updating are not applicable, as the model was applied to the validation panels without refitting or recalibration."));
C.push(H("Note on the design-based analysis"));
C.push(P("Because the data arise from a complex probability sample, the longitudinal weight, variance stratum, and primary sampling unit were carried through every estimate, including feature selection, model fitting, calibration, uncertainty quantification, and all subgroup analyses. Where closed-form design-based variance is not established for a composite quantity (net benefit, weighted SHAP summaries), uncertainty was obtained by resampling primary sampling units, and this is stated in the manuscript."));

Packer.toBuffer(new Document({
  styles: { default: { document: { run: { font: FONT, size: 20 } } } },
  sections: [{ properties: { page: { size: { width: 12240, height: 15840 } } },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER,
      children: [new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 18 })] })] }) }, children: C }],
})).then(b => { fs.writeFileSync(path.join(OUTDIR, "Supplementary_1_TRIPOD-AI_checklist.docx"), b);
  console.log("WROTE Supplementary_1_TRIPOD-AI_checklist.docx"); });
