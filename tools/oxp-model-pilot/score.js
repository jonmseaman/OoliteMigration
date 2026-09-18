"use strict";
/*
 * Score a classifier's verdicts against the hand-audited ground truth.
 *
 * THE VACUITY TRAP, IN BOTH DIRECTIONS
 * ------------------------------------
 * The ambiguous population is ~all false positives. A classifier that answers
 * "false-positive" unconditionally therefore scores ~100% agreement while
 * having learned nothing. A single agreement number cannot tell the two apart,
 * so this scorer:
 *   - reports the full confusion matrix, not one number;
 *   - requires BOTH classes to be predicted (a constant answer fails);
 *   - requires recall on the known-positive controls (the 8 fixture constructs
 *     and the real corpus findings) to clear a floor, so "always negative" is
 *     rejected on evidence rather than on the shape of the output;
 *   - requires the audited set itself to contain both classes, so the gate
 *     cannot be satisfied by an all-negative ground truth.
 *
 * Exit 0 when every check passes, 1 otherwise, naming the failure.
 */
const fs = require("fs");
const path = require("path");

function readJsonl(f) {
  return fs.readFileSync(f, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
}

function score(auditFile, verdictFile, opts) {
  const truth = new Map();
  for (const r of readJsonl(auditFile)) truth.set(r.id, r);
  const preds = new Map();
  for (const r of readJsonl(verdictFile)) preds.set(r.id, r);

  const rows = [];
  for (const [id, t] of truth) {
    const p = preds.get(id);
    rows.push({ id, truth: t.verdict, pred: p ? p.verdict : null, source: t.source, construct: t.construct });
  }
  const missing = rows.filter((r) => r.pred === null);
  /* mozilla == positive class */
  const m = { tp: 0, fp: 0, tn: 0, fn: 0 };
  for (const r of rows) {
    if (r.pred === null) continue;
    if (r.truth === "mozilla" && r.pred === "mozilla") m.tp++;
    else if (r.truth === "false-positive" && r.pred === "mozilla") m.fp++;
    else if (r.truth === "false-positive" && r.pred === "false-positive") m.tn++;
    else m.fn++;
  }
  const scored = m.tp + m.fp + m.tn + m.fn;
  const agree = scored ? (m.tp + m.tn) / scored : 0;
  const ctl = rows.filter((r) => r.source !== "corpus-unmasked");
  const ctlHit = ctl.filter((r) => r.pred === "mozilla").length;
  const ctlRecall = ctl.length ? ctlHit / ctl.length : 0;
  const predClasses = new Set(rows.filter((r) => r.pred).map((r) => r.pred));
  const truthClasses = new Set(rows.map((r) => r.truth));
  return { rows, matrix: m, scored, agreement: agree, controls: ctl.length, controlHits: ctlHit,
           controlRecall: ctlRecall, predClasses: [...predClasses], truthClasses: [...truthClasses], missing: missing.length };
}

function main(argv) {
  const o = { audit: path.join(__dirname, "data", "audit.jsonl"), minControlRecall: 0.5, minAgreement: 0.6 };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--audit") o.audit = argv[++i];
    else if (a === "--verdicts") o.verdicts = argv[++i];
    else if (a === "--min-control-recall") o.minControlRecall = Number(argv[++i]);
    else if (a === "--min-agreement") o.minAgreement = Number(argv[++i]);
    else if (a === "--json-out") o.jsonOut = argv[++i];
    else if (a === "--label") o.label = argv[++i];
  }
  if (!o.verdicts) { console.error("usage: node score.js --verdicts F [--audit F] [--min-control-recall X]"); process.exit(2); }
  const s = score(o.audit, o.verdicts, o);
  const M = s.matrix;
  const pct = (x) => (100 * x).toFixed(1) + "%";
  console.log(`classifier: ${o.label || path.basename(o.verdicts)}`);
  console.log(`audited=${s.rows.length} scored=${s.scored} missing_predictions=${s.missing}`);
  console.log("confusion matrix (positive class = mozilla):");
  console.log(`                 pred:mozilla  pred:false-positive`);
  console.log(`  truth:mozilla        ${String(M.tp).padStart(4)}               ${String(M.fn).padStart(4)}`);
  console.log(`  truth:false-pos      ${String(M.fp).padStart(4)}               ${String(M.tn).padStart(4)}`);
  const prec = (M.tp + M.fp) ? M.tp / (M.tp + M.fp) : 0;
  const rec = (M.tp + M.fn) ? M.tp / (M.tp + M.fn) : 0;
  console.log(`agreement=${pct(s.agreement)}  precision=${pct(prec)}  recall=${pct(rec)}`);
  console.log(`known-positive controls: ${s.controlHits}/${s.controls} recovered (${pct(s.controlRecall)})`);
  console.log(`classes predicted: ${JSON.stringify(s.predClasses)}`);

  const fails = [];
  if (s.truthClasses.length < 2)
    fails.push(`GROUND TRUTH IS SINGLE-CLASS (${JSON.stringify(s.truthClasses)}) - agreement on it is meaningless; the audited set must contain known positives`);
  if (s.missing > 0) fails.push(`${s.missing} audited records have no prediction`);
  if (s.predClasses.length < 2)
    fails.push(`CONSTANT-ANSWER CLASSIFIER: every prediction is ${JSON.stringify(s.predClasses)} - it scores ${pct(s.agreement)} agreement on a ${pct(1 - (M.tp + M.fn) / s.scored)}-negative population while having learned nothing`);
  if (s.controlRecall < o.minControlRecall)
    fails.push(`CONTROL RECALL ${pct(s.controlRecall)} < required ${pct(o.minControlRecall)}: the classifier missed known-real Mozilla constructs, so high agreement is an artifact of the negative-heavy population`);
  if (s.agreement < o.minAgreement)
    fails.push(`AGREEMENT ${pct(s.agreement)} < required ${pct(o.minAgreement)}`);

  if (o.jsonOut) {
    fs.mkdirSync(path.dirname(o.jsonOut), { recursive: true });
    fs.writeFileSync(o.jsonOut, JSON.stringify({
      label: o.label || null, audited: s.rows.length, scored: s.scored, matrix: M,
      agreement: s.agreement, precision: prec, recall: rec,
      control_recall: s.controlRecall, controls: s.controls, control_hits: s.controlHits,
      classes_predicted: s.predClasses, passed: fails.length === 0, failures: fails,
    }, null, 2) + "\n");
  }
  if (fails.length) { console.log("\nFAIL:"); for (const f of fails) console.log("  - " + f); process.exit(1); }
  console.log("\nPASS: both classes predicted, controls recovered, agreement above floor");
}

if (require.main === module) main(process.argv.slice(2));
module.exports = { score };
