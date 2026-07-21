// Builds the cover letter and the point-by-point response to the editor.
const fs = require("fs");
const path = require("path");
const { Document, Packer, Paragraph, TextRun, AlignmentType, Footer, PageNumber } = require("docx");

const OUTDIR = path.join(__dirname, "outputs", "manuscript");
fs.mkdirSync(OUTDIR, { recursive: true });
const FONT = "Times New Roman";
const r = (t, o = {}) => new TextRun({ text: t, font: FONT, size: 22, ...o });
const P = (children, opts = {}) => new Paragraph({
  spacing: { after: opts.after ?? 160, line: 300 },
  alignment: opts.align || AlignmentType.JUSTIFIED,
  indent: opts.indent, children: Array.isArray(children) ? children : [r(children)] });
const H = (t) => new Paragraph({ spacing: { before: 220, after: 100 },
  children: [new TextRun({ text: t, font: FONT, bold: true, size: 23 })] });
const doc = (children) => new Document({
  styles: { default: { document: { run: { font: FONT, size: 22 } } } },
  sections: [{ properties: { page: { size: { width: 12240, height: 15840 } } },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER,
      children: [new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 18 })] })] }) },
    children }] });

const TITLE = "Survey-Weighted Machine Learning for Prospective Stratification of High-Cost Patients: A Design-Based Pipeline with External Temporal Validation, Decision-Curve Analysis, and Subgroup Calibration in a Nationally Representative U.S. Cohort";
const senderBlock = [
  P("Rafael dos Reis", { after: 0 }),
  P("Independent Researcher", { after: 0 }),
  P("Curitiba, Brazil", { after: 0 }),
  P("rafreis2@gmail.com", { after: 220 }),
];

// =========================== COVER LETTER ===================================
const cover = [];
cover.push(...senderBlock);
cover.push(P("The Editors", { after: 0 }));
cover.push(P("Journal of Precision Medicine and Artificial Intelligence", { after: 220 }));
cover.push(P([r("Re: ", { bold: true }), r("Submission of a revised Original Research article — "), r(`“${TITLE}”`, { italics: true })]));
cover.push(P("Dear Editors,"));
cover.push(P("Please find enclosed a revised version of the above manuscript, submitted for consideration as an Original Research article in the Journal of Precision Medicine and Artificial Intelligence."));
cover.push(P("The study addresses a problem at the centre of precision-medicine care management: identifying, prospectively and from routinely available information, the small group of patients who will account for a disproportionate share of future healthcare spending. Using the Medical Expenditure Panel Survey two-year longitudinal panels, we predict membership in the population-weighted top decile of year-2 total expenditure from year-1 features alone."));
cover.push(P("Three features distinguish the work from the existing literature on high-cost prediction. First, the complex survey design (longitudinal weights, variance strata, and primary sampling units) is carried through every analytic step, including feature selection, model training, calibration, uncertainty quantification, and each subgroup estimate, rather than being applied only to descriptive statistics. Second, the model is validated on non-overlapping later panels spanning the COVID-19 disruption, so transportability is tested as a distinct study rather than inferred from an internal split. Third, decision-curve analysis against the prior-year-cost heuristic and subgroup calibration by income and race/ethnicity are reported as primary outputs, which speaks directly to the concern that cost-based targeting can encode structural bias."));
cover.push(P("In external validation the model achieved a survey-weighted area under the ROC curve of 0.857 (95% CI 0.842–0.869), with calibration close to ideal and net benefit exceeding the prior-cost benchmark across the actionable threshold range (paired difference at a 10% threshold 0.0089, 95% CI 0.0067–0.0111). Calibration was broadly stable across income and race/ethnicity strata. We believe the combination of design-consistent estimation, external temporal validation, and decision-analytic and equity reporting will be of direct interest to the journal's readership in predictive modelling and patient stratification."));
cover.push(P("The manuscript is reported in accordance with TRIPOD+AI, and a completed checklist is supplied as a supplementary file. It is approximately 4,900 words and contains three tables and three figures, within the limits for Original Research. Figures are supplied as separate files at 400 dpi."));
cover.push(H("Declarations"));
cover.push(P("This manuscript is original, has not been published elsewhere, and is not under consideration by another journal. The author is the sole author and meets all ICMJE authorship criteria. There are no conflicts of interest and no funding to declare. The study analysed only publicly available, de-identified data from the Medical Expenditure Panel Survey and was therefore exempt from institutional review board approval; no informed consent was required. The analysis code is openly available at https://github.com/rafreis/meps-highcost, and the underlying MEPS files are freely available from the Agency for Healthcare Research and Quality."));
cover.push(P("In line with the journal's policy on the use of artificial intelligence, I disclose that an AI-based assistant was used to support analysis code development and language editing of the manuscript. All study design decisions, data handling, analyses, results, and interpretations were specified and verified by me, and I take full responsibility for the content."));
cover.push(P("Thank you for considering this work. I would be glad to respond to any further questions."));
cover.push(P("Yours sincerely,", { after: 220 }));
cover.push(P("Rafael dos Reis", { after: 0 }));
cover.push(P("Independent Researcher, Curitiba, Brazil"));

// =========================== RESPONSE LETTER ================================
const RQ = (t) => P([r("Comment. ", { bold: true }), r(t, { italics: true })], { indent: { left: 360 } });
const RA = (t) => P([r("Response. ", { bold: true }), r(t)]);
const resp = [];
resp.push(...senderBlock);
resp.push(P([r("Re: ", { bold: true }), r("Point-by-point response to editorial comments — "), r(`“${TITLE}”`, { italics: true })]));
resp.push(P("Dear Editors,"));
resp.push(P("Thank you for the constructive and unusually detailed assessment, and for the two marked-up files. The comments have materially improved the positioning and the presentation of the work. We have accepted the full language pass as supplied, and we address each substantive point below. Changes are described by section so they can be located quickly in the revised manuscript."));

resp.push(H("1. Novelty positioning"));
resp.push(RQ("Please cite and differentiate the closest prior work. Fleishman and Cohen (Health Serv Res, 2010) predict the same top-decile Year-2 expenditure from Year-1 data in MEPS with a train-early, validate-later design, so it needs to be named, with a sentence or two on what you add over it. There is also recent utility-framed ML work (Tan et al., JMIR Med Inform, 2026) worth acknowledging."));
resp.push(RA("We agree, and we are grateful for both references. The Introduction now contains a dedicated paragraph that names Fleishman and Cohen as the direct precedent for this estimand and design (now reference 8), describes their approach (logistic regression with diagnostic cost-group risk scores, an earlier development cohort and a later validation cohort), and states our advance over it explicitly: design-consistent survey-weighted machine learning in place of unweighted logistic regression; an external validation conducted as a distinct study across the COVID-19 shock rather than a later split of the same era; decision-curve analysis against the prior-cost heuristic; and subgroup calibration reported as a primary output. The Discussion opens its comparative paragraph in the same terms, so the claim is consistent in both places. Tan et al. is now reference 9 and is acknowledged as evidence that clinical-utility and economic framing is expected in this space, while noting that it used a disease-registry cohort and did not perform decision-curve analysis, so it complements rather than duplicates our contribution."));

resp.push(H("2. References"));
resp.push(RQ("Renumber into Vancouver citation order (order of first appearance); the list is currently out of sequence."));
resp.push(RA("Corrected. The reference list is now in strict order of first appearance, and all in-text superscripts have been updated accordingly. The example you identified (the MEPS data citation, previously numbered 33 but cited early in the Methods) is now reference 11. To prevent this class of error from recurring in future revisions, references in our manuscript-generation pipeline are keyed and numbered automatically on first citation, so the list cannot drift out of sequence; the revised list contains 35 references with no uncited entries."));

resp.push(H("3. Table 3 and equity language"));
resp.push(RQ("The income subgroups sum to 14,914 rather than the 15,033 validation total, so please reconcile that or add a missing-income row. And soften “uniform” a little: calibration is stable and that is your real safeguard, but discrimination does vary by about 0.05 across groups, so lean the equity claim on calibration."));
resp.push(RA("Both points are well taken. The discrepancy was 119 validation participants (0.8%) with missing or unclassified poverty category. Table 3 now includes an explicit “Income — missing/unclassified” row (n = 119; observed 7.6%, predicted 6.8%), so the income stratification sums to the full validation cohort of 15,033, matching race/ethnicity. Their subgroup area under the curve is reported as not estimable, since the small number of events does not support a reliable estimate. The table legend now states that both stratifications use the same denominator and that race/ethnicity has no missing values."));
resp.push(RA("On the equity language, we have removed “uniform” and reframed the claim around calibration throughout. The Results now read that calibration was broadly stable with predicted risks close to observed in every group, while discrimination varied modestly (0.84 to 0.91 across income; 0.84 to 0.89 across race/ethnicity), and we state explicitly that a between-group range of about 0.05 is not something we regard as negligible. The Discussion makes the rationale explicit: calibration is the property that governs whether a given risk threshold means the same thing in each group, and it is therefore where we place the weight of the equity argument. We also retain the caveat that stable calibration is a necessary but not sufficient condition for equitable deployment, because cost remains an imperfect proxy for need."));

resp.push(H("4. Figures"));
resp.push(RQ("Larger axis and label fonts for column width, a predicted-risk distribution under the calibration plot, confidence intervals (or a note) on the decision curve, and one shared font and palette across all three."));
resp.push(RA("All three figures have been redrawn from a single specification, so they now share one typeface and one colour palette (Okabe–Ito, chosen for colour-vision deficiency safety), with axis and label type sizes increased for legibility at single-column width. Figure 1 gains a lower panel showing the weighted distribution of predicted risk, and its binned points now carry 95% cluster-bootstrap intervals. Figure 2 states the validation sample size in the caption and labels the colour bar explicitly as the feature value from low to high. Figure 3 has thicker lines, larger legend and axis type, and is clipped to the actionable threshold range so the separation between the model and the benchmark is visible."));
resp.push(RA("On confidence intervals for the decision curve, we computed them rather than noting their absence. Figure 3 now shows 95% bands from a design-based cluster bootstrap over primary sampling units (400 replicates). Because the two curves are estimated on the same participants, their marginal bands overlap even where the model is consistently superior, so we also report the paired difference in net benefit, which is the appropriate comparison. At a 10% threshold the paired advantage over prior-year cost was 0.0089 (95% CI 0.0067 to 0.0111), and the model was superior in every bootstrap replicate; the interval excluded zero at every threshold from 5% to 30%. This is now reported in Results section 3.5 and referenced to your DCA citation."));

resp.push(H("5. Code availability"));
resp.push(RQ("Please consider depositing the analysis code in a public repo with a DOI rather than “available on request”."));
resp.push(RA("Done. The complete analysis pipeline is now openly available at https://github.com/rafreis/meps-highcost under an MIT licence, including the design-based selection pipeline, the validation invariants, and the figure scripts, together with the pinned computational environment. The Declarations section cites the repository directly and no longer relies on availability on request. The underlying MEPS files are public and are not redistributed; the pipeline downloads them from AHRQ, so the analysis is reproducible from source."));

resp.push(H("6. Minor points"));
resp.push(RA("Jargon. “Feature contract” has been replaced by “final set of 62 features” throughout, and the term no longer appears."));
resp.push(RA("Sensitivity and positive predictive value. We have added a half-sentence in Results section 3.3 and a note in the Table 2 legend explaining that the two coincide because the flag rate (the top decile) equals the event rate (10%), which is an arithmetic consequence of the operating point rather than an error."));
resp.push(RA("Benchmark accuracy. We verified the comparison figure against the source and now quote it precisely: Langenberger et al. report a random-forest area under the curve of 0.883 in commercial claims data. The sentence retains the framing you endorsed, namely that our result is competitive while being estimated on population-representative survey data with the design carried throughout."));
resp.push(RA("Language. We accepted the tracked-changes pass in full. In addition, we removed the remaining em dashes from the manuscript and revised the recurrent constructions you identified, including “profoundly”, “hinges on”, “far more than”, “rather than in spite of”, “precisely”, “Notably”, and “provides a template for”. En dashes are retained only in numeric ranges and reference page spans, where they are typographically correct."));

resp.push(P("We hope the revised manuscript now meets the journal's requirements, and we thank you again for an assessment that was both rigorous and generous with detail."));
resp.push(P("Yours sincerely,", { after: 220 }));
resp.push(P("Rafael dos Reis", { after: 0 }));
resp.push(P("Independent Researcher, Curitiba, Brazil"));

Promise.all([
  Packer.toBuffer(doc(cover)).then(b => fs.writeFileSync(path.join(OUTDIR, "Cover_Letter.docx"), b)),
  Packer.toBuffer(doc(resp)).then(b => fs.writeFileSync(path.join(OUTDIR, "Response_to_Editor.docx"), b)),
]).then(() => console.log("WROTE Cover_Letter.docx + Response_to_Editor.docx"));
