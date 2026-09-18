"use strict";
/*
 * Integrity checks on the audited ground truth (bead oo-l7u).
 *
 * The agreement rate is only meaningful if the audit file really is what it
 * claims: a reproducible seeded sample of the ambiguity corpus, labelled by
 * hand, with known-positive controls included. Each check below has a mutant
 * that breaks exactly it (see mutation-proof.sh).
 *
 *  1. REPRODUCIBLE      - re-running the sampler at the recorded seed
 *                         reproduces the audited id set exactly. A fabricated
 *                         or hand-edited sample fails here.
 *  2. LABELS ARE REAL   - every audited record's snippet is byte-identical to
 *                         the snippet in the sample it came from, so labels
 *                         cannot have been attached to invented evidence.
 *  3. NOT SINGLE-CLASS  - the audited set contains both verdicts, so agreement
 *                         on it is not vacuous.
 *  4. CONTROLS PRESENT  - the 8 fixture constructs and the real corpus
 *                         findings are present and all labelled mozilla.
 *  5. REASONED          - every verdict carries a non-trivial distinct reason.
 */
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const HERE = __dirname;
const DIR = path.join(HERE, "data");
const SEED = 20260918, N = 50;

function readJsonl(f) { return fs.readFileSync(f, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l)); }

const audit = readJsonl(path.join(DIR, "audit.jsonl"));
const sample = readJsonl(path.join(DIR, "sample.jsonl"));
const fails = [];

/* 1. reproducible from the recorded seed */
const tmp = path.join(process.env.LOCALAPPDATA || require("os").tmpdir(), "Temp", "oxp-model-pilot", "verify-sample.jsonl");
fs.mkdirSync(path.dirname(tmp), { recursive: true });
execFileSync(process.execPath, [
  path.join(HERE, "pilot.js"), "sample",
  "--in", path.join(DIR, "ambiguous.jsonl"), "--out", tmp,
  "--seed", String(SEED), "--n", String(N),
], { stdio: "pipe" });
const regen = readJsonl(tmp);
const idsOf = (rs) => [...new Set(rs.map((r) => r.id))].sort().join(",");
if (idsOf(regen) !== idsOf(sample)) {
  fails.push(`SAMPLE IS NOT REPRODUCIBLE from seed ${SEED}: regenerating the sample yields a different id set ` +
    `(${new Set(regen.map((r) => r.id)).size} ids vs ${new Set(sample.map((r) => r.id)).size} audited)`);
}
if (idsOf(audit) !== idsOf(sample)) {
  fails.push(`AUDIT DOES NOT COVER THE SAMPLE: audited ids differ from sampled ids`);
}

/* 2. labels attached to real evidence - snippets must match the sample byte for byte */
const byId = new Map(sample.map((r) => [r.id, r]));
const drifted = audit.filter((a) => {
  const s = byId.get(a.id);
  return !s || s.snippet !== a.snippet || s.line !== a.line || s.member !== a.member || s.construct !== a.construct;
});
if (drifted.length) {
  fails.push(`FABRICATED OR DRIFTED EVIDENCE: ${drifted.length} audited record(s) do not match the sampled hit ` +
    `they claim to label (first: ${drifted[0].id} ${drifted[0].member}:${drifted[0].line})`);
}

/* 3. both classes present */
const classes = [...new Set(audit.map((a) => a.verdict))].sort();
if (classes.length < 2) {
  fails.push(`AUDITED SET IS SINGLE-CLASS (${JSON.stringify(classes)}): an agreement rate measured against it is vacuous, ` +
    `because a constant-answer classifier would score 100%`);
}
const nMoz = audit.filter((a) => a.verdict === "mozilla").length;

/* 4. controls present and all positive */
const fixtures = audit.filter((a) => a.source === "control-fixture");
const corpusCtl = audit.filter((a) => a.source === "control-corpus-finding");
if (fixtures.length !== 8) fails.push(`expected 8 fixture controls, found ${fixtures.length}`);
if (!corpusCtl.length) fails.push(`no real corpus findings among the controls`);
const badCtl = fixtures.concat(corpusCtl).filter((a) => a.verdict !== "mozilla");
if (badCtl.length) fails.push(`${badCtl.length} known-positive control(s) are not labelled mozilla`);
const ctlConstructs = [...new Set(fixtures.map((a) => a.construct))].sort();
if (ctlConstructs.length !== 8) {
  fails.push(`fixture controls cover ${ctlConstructs.length} distinct constructs, expected all 8: ${ctlConstructs.join(",")}`);
}

/* 5. every verdict reasoned */
const unreasoned = audit.filter((a) => !a.reason || a.reason.length < 40);
if (unreasoned.length) fails.push(`${unreasoned.length} verdict(s) carry no substantive reason`);
const distinctReasons = new Set(audit.map((a) => a.reason)).size;
if (distinctReasons < 4) fails.push(`only ${distinctReasons} distinct reasons across ${audit.length} verdicts - the labels look mechanical`);

console.log(`audit records      : ${audit.length} (${nMoz} mozilla, ${audit.length - nMoz} false-positive)`);
console.log(`sample seed        : ${SEED}, n=${N} + controls; reproducible: ${idsOf(regen) === idsOf(sample)}`);
console.log(`fixture controls   : ${fixtures.length} covering ${ctlConstructs.length} constructs`);
console.log(`corpus controls    : ${corpusCtl.length}`);
console.log(`distinct reasons   : ${distinctReasons}`);
if (fails.length) {
  console.log("\nFAIL:");
  for (const f of fails) console.log("  - " + f);
  process.exit(1);
}
console.log("\nGROUND TRUTH OK: reproducible from seed, labels bound to real sampled evidence, both classes present, all 8 controls positive");
