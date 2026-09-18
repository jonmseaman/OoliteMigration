"use strict";
/*
 * Assert that the numbers published in docs/fleet/LEARNINGS.md are the numbers
 * the committed artifacts actually produce (bead oo-l7u).
 *
 * A report is only evidence if it cannot drift from its data. This recomputes
 * the confusion matrices from data/audit.jsonl + each committed verdicts file
 * and requires every figure quoted in the LEARNINGS entry to match. Edit the
 * text without rerunning the pilot and this line goes red.
 */
const fs = require("fs");
const path = require("path");
const { score } = require("./score");

const HERE = __dirname;
const REPO = path.resolve(HERE, "..", "..");
const DOC = path.join(REPO, "docs", "fleet", "LEARNINGS.md");
const AUDIT = path.join(HERE, "data", "audit.jsonl");

const MODELS = [
  ["qwen3-4b-2507", "verdicts-model.jsonl"],
  ["deepseek-r1-8b", "verdicts-deepseek.jsonl"],
  ["constant-stub", "verdicts-constant.jsonl"],
];

const doc = fs.readFileSync(DOC, "utf8");
const start = doc.indexOf("[oo-l7u]");
if (start < 0) { console.error("no [oo-l7u] entry in " + DOC); process.exit(1); }
let end = doc.indexOf("\n- 20", start);
if (end < 0) end = doc.length;
const entry = doc.slice(start, end);

const pct1 = (x) => (100 * x).toFixed(1);
const missing = [];
for (const [label, file] of MODELS) {
  const s = score(AUDIT, path.join(HERE, "data", file), {});
  const M = s.matrix;
  const toks = [
    [`${label} agreement`, `${pct1(s.agreement)}%`],
    [`${label} matrix`, `TP=${M.tp} FN=${M.fn} FP=${M.fp} TN=${M.tn}`],
    [`${label} control recall`, `${s.controlHits}/${s.controls}`],
  ];
  console.log(`${label.padEnd(16)} agreement=${pct1(s.agreement)}% TP=${M.tp} FN=${M.fn} FP=${M.fp} TN=${M.tn} controls=${s.controlHits}/${s.controls}`);
  for (const [what, tok] of toks) if (!entry.includes(tok)) missing.push([what, tok]);
}

/* The audited ground truth's own shape must be published too, or the
 * agreement rate cannot be interpreted. */
const audit = fs.readFileSync(AUDIT, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
const nMoz = audit.filter((a) => a.verdict === "mozilla").length;
for (const [what, tok] of [
  ["audited count", `${audit.length} audited`],
  ["positives in truth", `${nMoz} mozilla`],
  ["sample seed", "20260918"],
]) if (!entry.includes(tok)) missing.push([what, tok]);

console.log(`LEARNINGS entry length: ${entry.length} chars`);
if (missing.length) {
  console.log("\nFAIL: the published report does not match the committed data:");
  for (const [what, tok] of missing) console.log(`  - ${what}: expected the entry to contain "${tok}"`);
  process.exit(1);
}
console.log("\nREPORT OK: every published figure recomputed from data/audit.jsonl + the committed verdicts files");
