"use strict";
/*
 * tools/oxp-js-lint/compat.js -- runner for the compat rule set (ADR-0069, layer 2).
 *
 *   node tools/oxp-js-lint/compat.js scan <path|dir> ... [--json]
 *       Scan loose .js files (the fixtures, or an unpacked expansion). Exit 1 on any BREAKS.
 *
 *   node tools/oxp-js-lint/compat.js corpus [--cache-dir D] [--manifest M] [--out F] [--limit N]
 *       Scan every .js member of every cached expansion and write compat-report.json.
 *       Cache only, never the network (lint.js's zip reader and cache layout).
 *
 * lint.js and its nine Mozilla-only rules are untouched; this is a second report. Findings carry
 * rule, severity, file, line and column: no source text (CLAUDE.md rule 6, ADR-0069).
 */

const fs = require("fs");
const path = require("path");

const lint = require("./lint");
const { COMPAT_RULE_NAMES, COMPAT_DETECTORS, SEVERITY_ORDER, scanCompat } = require("./compat-rules");

const HERE = __dirname;
const REPO_ROOT = path.resolve(HERE, "..", "..");

function walkJs(root, acc) {
  const st = fs.statSync(root);
  if (st.isFile()) {
    if (root.toLowerCase().endsWith(".js")) acc.push(root);
    return acc;
  }
  for (const name of fs.readdirSync(root).sort()) {
    if (name === "node_modules" || name === ".git") continue;
    walkJs(path.join(root, name), acc);
  }
  return acc;
}

function emptyCounts() {
  const c = {};
  for (const r of COMPAT_RULE_NAMES) c[r] = { BREAKS: 0, CHANGED: 0, INFO: 0 };
  return c;
}

function worstOf(findings) {
  let worst = null;
  for (const f of findings) {
    if (worst === null || SEVERITY_ORDER[f.severity] < SEVERITY_ORDER[worst]) worst = f.severity;
  }
  return worst;
}

function scanCorpus(o) {
  const manifest = JSON.parse(fs.readFileSync(o.manifest, "utf8"));
  const entries = Object.entries(manifest.entries || {});
  const report = {
    generated_by: "tools/oxp-js-lint/compat.js",
    rules: COMPAT_RULE_NAMES,
    manifest: path.relative(REPO_ROOT, o.manifest).split(path.sep).join("/"),
    expansions: [],
  };
  const totals = { expansions: 0, scanned: 0, missing: 0, unreadable: 0, js_files: 0, findings: 0,
                   expansions_by_worst: { BREAKS: 0, CHANGED: 0, INFO: 0, none: 0 } };
  const byRule = emptyCounts();
  let n = 0;
  for (const [url, entry] of entries) {
    if (o.limit && n >= o.limit) break;
    n++;
    totals.expansions++;
    const rec = { url, sha256: entry.sha256 || null, status: "ok", js_files: 0, worst: null, findings: [] };
    const blob = lint.blobPath(o.cacheDir, url);
    if (entry.status !== "ok" || !fs.existsSync(blob)) {
      rec.status = entry.status !== "ok" ? "not-fetched" : "missing-blob";
      totals.missing++;
      report.expansions.push(rec);
      continue;
    }
    try {
      const buf = fs.readFileSync(blob);
      for (const m of lint.zipEntries(buf)) {
        if (!m.name.toLowerCase().endsWith(".js") || m.size === 0) continue;
        rec.js_files++;
        for (const f of scanCompat(lint.decode(lint.readMember(buf, m)))) {
          rec.findings.push({ file: m.name, ...f });
          byRule[f.rule][f.severity]++;
        }
      }
      totals.js_files += rec.js_files;
      totals.scanned++;
    } catch (e) {
      rec.status = "unreadable";
      rec.error = String(e.message || e).slice(0, 200);
      totals.unreadable++;
    }
    rec.worst = worstOf(rec.findings);
    totals.findings += rec.findings.length;
    if (rec.status === "ok") totals.expansions_by_worst[rec.worst || "none"]++;
    report.expansions.push(rec);
  }
  report.totals = totals;
  report.by_rule = byRule;
  return report;
}

function parseArgs(argv) {
  const o = { mode: argv[0], paths: [], json: false, limit: 0, out: null };
  o.cacheDir = lint.defaultCacheDir();
  o.manifest = path.join(REPO_ROOT, "tools", "oxp-corpus", "manifest.json");
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--json") o.json = true;
    else if (a === "--cache-dir") o.cacheDir = argv[++i];
    else if (a === "--manifest") o.manifest = argv[++i];
    else if (a === "--out") o.out = argv[++i];
    else if (a === "--limit") o.limit = parseInt(argv[++i], 10);
    else if (a.startsWith("--")) throw new Error("unknown flag: " + a);
    else o.paths.push(a);
  }
  return o;
}

function main(argv) {
  if (!argv.length || argv[0] === "--help" || argv[0] === "-h") {
    process.stdout.write(
      "usage:\n" +
      "  node compat.js scan <path|dir> ... [--json]\n" +
      "  node compat.js corpus [--cache-dir D] [--manifest M] [--out F] [--limit N]\n" +
      "  node compat.js rules\n"
    );
    return 0;
  }
  const o = parseArgs(argv);

  if (o.mode === "rules") {
    const rules = {};
    for (const r of COMPAT_RULE_NAMES) rules[r] = COMPAT_DETECTORS[r].description;
    process.stdout.write(JSON.stringify(rules, null, 2) + "\n");
    return 0;
  }

  if (o.mode === "scan") {
    if (!o.paths.length) throw new Error("scan needs at least one path");
    const files = [];
    for (const p of o.paths) walkJs(p, files);
    const results = files.map((f) => ({
      file: f.split(path.sep).join("/"),
      findings: scanCompat(lint.decode(fs.readFileSync(f))),
    }));
    const all = results.flatMap((r) => r.findings);
    if (o.json) {
      process.stdout.write(JSON.stringify({ rules: COMPAT_RULE_NAMES, files: results.length, findings: all.length, results }, null, 2) + "\n");
    } else {
      for (const r of results) {
        for (const f of r.findings) {
          process.stdout.write(`${r.file}:${f.line}:${f.column}: ${f.severity}: ${f.rule}: ${COMPAT_DETECTORS[f.rule].message}\n`);
        }
      }
      process.stdout.write(`${files.length} file(s) scanned, ${all.length} finding(s) ` +
        `(${all.filter((f) => f.severity === "BREAKS").length} BREAKS)\n`);
    }
    return all.some((f) => f.severity === "BREAKS") ? 1 : 0;
  }

  if (o.mode === "corpus") {
    const t0 = Date.now();
    const report = scanCorpus(o);
    report.wall_seconds = Math.round((Date.now() - t0) / 100) / 10;
    const out = o.out || path.join(HERE, "compat-report.json");
    fs.writeFileSync(out, JSON.stringify(report, null, 1) + "\n");
    const t = report.totals;
    const w = t.expansions_by_worst;
    process.stdout.write(
      `compat: ${t.expansions} expansions (${t.scanned} read, ${t.missing} not cached, ${t.unreadable} unreadable), ` +
      `${t.js_files} .js members, ${t.findings} findings; worst per expansion: ` +
      `${w.BREAKS} BREAKS, ${w.CHANGED} CHANGED, ${w.INFO} INFO, ${w.none} none; ${report.wall_seconds}s\n` +
      Object.entries(report.by_rule).map(([k, v]) => `  ${k}: ${v.BREAKS} BREAKS, ${v.CHANGED} CHANGED, ${v.INFO} INFO`).join("\n") + "\n" +
      `report: ${path.relative(REPO_ROOT, out).split(path.sep).join("/")}\n`
    );
    return 0;
  }

  throw new Error("unknown mode: " + o.mode);
}

if (require.main === module) {
  try {
    process.exitCode = main(process.argv.slice(2));
  } catch (e) {
    process.stderr.write("oxp-js-lint compat: " + (e && e.stack ? e.stack : String(e)) + "\n");
    process.exitCode = 2;
  }
}

module.exports = { scanCorpus, main };
