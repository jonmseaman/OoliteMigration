"use strict";
/*
 * Ambiguity corpus for bead oo-l7u.
 *
 * oo-ctq's masked detectors found 5 findings in the 818-expansion corpus. A
 * deliberately naive UNMASKED regex cross-check (crosscheck.js) found ~218
 * additional hits, which oo-ctq inspected and judged to be entirely
 * comment/string false positives. Those extra hits are the ambiguity corpus:
 * every one is a place where "is this really Mozilla-only JS?" has a
 * non-obvious answer, and they are exactly the population a classifier would
 * have to get right.
 *
 *   extract  - re-derive the ambiguous population (raw hit NOT confirmed by
 *              the masked detector on the same line) and emit it as JSONL.
 *   sample   - take a reproducible seeded random sample of N, and append the
 *              known-positive controls (fixtures + the real corpus findings).
 *
 * BOUNDARY (CLAUDE.md hard rule 6): this tool is the sandboxed scan role. It
 * emits only the hit line plus at most CONTEXT_LINES lines either side,
 * truncated, so downstream consumers audit SNIPPETS rather than browsing
 * expansion source. Nothing else in this bead opens an expansion.
 */
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { scanText } = require("../oxp-js-lint/rules");
const { zipEntries, readMember, blobPath } = require("../oxp-js-lint/lint");

const CONTEXT_LINES = 2;
const SNIPPET_MAX = 200;

/* The unmasked detectors, verbatim from oo-ctq's crosscheck.js. */
const RAW = {
  "catch-if": /catch\s*\([^)]*\bif\b/,
  "e4x-descendant": /[A-Za-z_$][\w$]*\.\.[A-Za-z_$@*]/,
  "e4x-attr": /\.\s*@\s*[A-Za-z_$*]/,
  "quote-method": /\.\s*quote\s*\(/,
  "to-source": /toSource\s*\(/,
  uneval: /\buneval\s*\(/,
  "let-block": /\blet\s*\(/,
  "legacy-accessor": /__(?:define|lookup)(?:Getter|Setter)__/,
  "expression-closure": /function\s*(?:[A-Za-z_$][\w$]*\s*)?\([^()]*\)\s*[^\s{;]/,
};
/* raw construct name -> the masked rule that would confirm it */
const CONFIRMS = {
  "catch-if": "catch-if",
  "e4x-descendant": "e4x",
  "e4x-attr": "e4x",
  "quote-method": "quote-method",
  "to-source": "to-source",
  uneval: "uneval",
  "let-block": "let-block",
  "legacy-accessor": "legacy-accessor",
  "expression-closure": "expression-closure",
};

function defaultCacheDir() {
  if (process.env.OXP_CACHE_DIR) return process.env.OXP_CACHE_DIR;
  const la = process.env.LOCALAPPDATA;
  if (la) return path.join(la, "OoliteMigration", "oxp-cache");
  return path.join(process.env.HOME || ".", ".cache", "oolite-migration", "oxp-cache");
}

function hitId(exp, member, line, construct) {
  return crypto.createHash("sha1")
    .update([exp, member, line, construct].join("|"), "utf8")
    .digest("hex").slice(0, 16);
}

function extract(opts) {
  const manifest = JSON.parse(fs.readFileSync(opts.manifest, "utf8"));
  const out = [];
  let files = 0, expansions = 0;
  for (const [url, entry] of Object.entries(manifest.entries || {})) {
    if (entry.status !== "ok") continue;
    const blob = blobPath(opts.cacheDir, url);
    if (!fs.existsSync(blob)) continue;
    let buf, members;
    try { buf = fs.readFileSync(blob); } catch (e) { continue; }
    try {
      members = zipEntries(buf).filter((e) => e.name.toLowerCase().endsWith(".js") && e.size > 0);
    } catch (e) { continue; }
    expansions++;
    const exp = decodeURIComponent(url.split("/").pop() || url);
    for (const m of members) {
      let text;
      try { text = readMember(buf, m).toString("latin1"); } catch (e) { continue; }
      files++;
      const lines = text.split("\n");
      // masked findings, indexed by "rule@line" - these are the CONFIRMED ones
      const confirmed = new Set();
      for (const f of scanText(text)) confirmed.add(f.rule + "@" + f.line);
      const seen = new Set();
      for (const [construct, re] of Object.entries(RAW)) {
        const rx = new RegExp(re.source, "g");
        let mm;
        while ((mm = rx.exec(text)) !== null) {
          if (mm[0].length === 0) { rx.lastIndex++; continue; }
          const line = text.slice(0, mm.index).split("\n").length;
          const key = construct + "@" + line;
          if (seen.has(key)) continue;       // one record per construct per line
          seen.add(key);
          if (confirmed.has(CONFIRMS[construct] + "@" + line)) continue;  // masked agrees: not ambiguous
          const lo = Math.max(0, line - 1 - CONTEXT_LINES);
          const hi = Math.min(lines.length, line + CONTEXT_LINES);
          out.push({
            id: hitId(exp, m.name, line, construct),
            expansion: exp,
            member: m.name,
            line,
            construct,
            snippet: (lines[line - 1] || "").trim().slice(0, SNIPPET_MAX),
            context: lines.slice(lo, hi).map((s, i) => ({
              n: lo + i + 1, text: s.replace(/\r$/, "").slice(0, SNIPPET_MAX),
            })),
            source: "corpus-unmasked",
          });
        }
      }
    }
  }
  out.sort((a, b) => a.id.localeCompare(b.id));
  return { records: out, expansions, files };
}

/* mulberry32: a tiny seeded PRNG, so the sample is reproducible from its seed
 * on any Node version (Math.random cannot be seeded). */
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function sample(records, seed, n) {
  const pool = records.slice().sort((a, b) => a.id.localeCompare(b.id));
  const rnd = mulberry32(seed);
  for (let i = pool.length - 1; i > 0; i--) {         // Fisher-Yates
    const j = Math.floor(rnd() * (i + 1));
    [pool[i], pool[j]] = [pool[j], pool[i]];
  }
  return pool.slice(0, n);
}

/* Known-positive controls. The 8 fixture files are real Mozilla-only
 * constructs by construction (they are oo-ctq's positive controls), and the 5
 * genuine corpus findings survived masking. Without these the audited set is
 * ~all-negative and a constant-answer classifier scores ~100%. */
function controls(repoRoot) {
  const out = [];
  const fx = path.join(repoRoot, "tools", "oxp-js-lint", "fixtures");
  for (const name of fs.readdirSync(fx)) {
    if (!name.endsWith(".js") || name === "clean.js") continue;
    const text = fs.readFileSync(path.join(fx, name), "utf8");
    const lines = text.split("\n");
    const f = scanText(text)[0];
    if (!f) throw new Error("fixture produced no finding: " + name);
    const lo = Math.max(0, f.line - 1 - CONTEXT_LINES), hi = Math.min(lines.length, f.line + CONTEXT_LINES);
    out.push({
      id: hitId("FIXTURE", name, f.line, f.rule),
      expansion: "FIXTURE", member: "fixtures/" + name, line: f.line, construct: f.rule,
      snippet: f.snippet.slice(0, SNIPPET_MAX),
      context: lines.slice(lo, hi).map((s, i) => ({ n: lo + i + 1, text: s.replace(/\r$/, "").slice(0, SNIPPET_MAX) })),
      source: "control-fixture", control_truth: "mozilla",
    });
  }
  const rep = JSON.parse(fs.readFileSync(path.join(repoRoot, "tools", "oxp-js-lint", "corpus-report.json"), "utf8"));
  for (const e of rep.expansions) {
    for (const f of e.findings || []) {
      out.push({
        id: hitId(e.name || e.url, f.file || f.member, f.line, f.rule),
        expansion: e.name || e.url, member: f.file || f.member, line: f.line, construct: f.rule,
        snippet: (f.snippet || "").slice(0, SNIPPET_MAX), context: [],
        source: "control-corpus-finding", control_truth: "mozilla",
      });
    }
  }
  out.sort((a, b) => a.id.localeCompare(b.id));
  return out;
}

function writeJsonl(file, rows) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, rows.map((r) => JSON.stringify(r)).join("\n") + "\n");
}

function main(argv) {
  const cmd = argv[0];
  const repoRoot = path.resolve(__dirname, "..", "..");
  const o = { cacheDir: defaultCacheDir(), manifest: path.join(repoRoot, "tools", "oxp-corpus", "manifest.json"), seed: 20260918, n: 50 };
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--out") o.out = argv[++i];
    else if (a === "--in") o.in = argv[++i];
    else if (a === "--cache-dir") o.cacheDir = argv[++i];
    else if (a === "--manifest") o.manifest = argv[++i];
    else if (a === "--seed") o.seed = Number(argv[++i]);
    else if (a === "--n") o.n = Number(argv[++i]);
  }
  if (cmd === "extract") {
    const r = extract(o);
    writeJsonl(o.out, r.records);
    console.log(JSON.stringify({ ambiguous: r.records.length, expansions: r.expansions, js_files: r.files, out: o.out }));
  } else if (cmd === "sample") {
    const recs = fs.readFileSync(o.in, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
    const picked = sample(recs, o.seed, o.n);
    const ctl = controls(repoRoot);
    const all = picked.concat(ctl);
    writeJsonl(o.out, all);
    console.log(JSON.stringify({ seed: o.seed, sampled: picked.length, controls: ctl.length, total: all.length, out: o.out }));
  } else {
    console.error("usage: node pilot.js extract --out F | sample --in F --out F [--seed N] [--n N]");
    process.exit(2);
  }
}

if (require.main === module) main(process.argv.slice(2));
module.exports = { extract, sample, controls, mulberry32, RAW };
