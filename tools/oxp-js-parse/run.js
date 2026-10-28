"use strict";
/*
 * tools/oxp-js-parse/run.js -- does QuickJS-ng parse it? (ADR-0069, layer 1)
 *
 *   node tools/oxp-js-parse/run.js scan <path|dir> ... [--json]
 *       Parse loose .js files (the fixtures, or an unpacked expansion an author is checking).
 *       Exit 1 if any file fails to parse as shipped.
 *
 *   node tools/oxp-js-parse/run.js corpus [--cache-dir D] [--manifest M] [--out F]
 *                                         [--limit N] [--progress]
 *       Parse every .js member of every cached expansion and write parse-report.json.
 *       Reads the oxp-cache only (tools/oxp_corpus.py fills it); never the network.
 *
 * Each file is compiled twice by the host (parse.c, built with build.sh from the game's pinned
 * QuickJS-ng):
 *   - "plain": the bytes as the game loads them by default. A failure here means the game logs
 *     "compilation failed" and the script does not exist: BREAKS.
 *   - "strict": with the '"use strict";\n' prefix the game adds to a script that lacks one when
 *     standards enforcement is on (OOJSScript.cpp LoadScriptWithName; OOEnforceStandards() is off
 *     unless a player or the verifier turns it on). Recorded only when plain parses and strict
 *     does not ("strict-only"), with the line shifted back to the file's own numbering.
 *
 * A failure is attributed to a rule by the oxp-js-lint detector that fires on the same line, so
 * rules.js stays the one vocabulary. A failure no detector explains is "syntax-other": a gap in
 * the guide, never a silent pass.
 *
 * The report carries file names, positions, rule ids and QuickJS-ng's own message (the host
 * truncates it). It never carries expansion source (CLAUDE.md rule 6).
 */

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const lint = require("../oxp-js-lint/lint");
const { scanText, RULE_NAMES } = require("../oxp-js-lint/rules");

const HERE = __dirname;
const REPO_ROOT = path.resolve(HERE, "..", "..");
const STRICT_PREFIX = '"use strict";\n';

function defaultBin() {
  if (process.env.OXP_JS_PARSE_BIN) return process.env.OXP_JS_PARSE_BIN;
  return path.join(REPO_ROOT, ".agent-tmp", "oxp-js-parse", "oxp-js-parse.exe");
}

function defaultCacheDir() {
  if (process.env.OXP_CACHE_DIR) return process.env.OXP_CACHE_DIR;
  const la = process.env.LOCALAPPDATA;
  if (la) return path.join(la, "OoliteMigration", "oxp-cache");
  return path.join(process.env.HOME || ".", ".cache", "oolite-migration", "oxp-cache");
}

/** The game's text decoding, as lint.js does it, with a leading BOM dropped. */
function decode(bytes) {
  const utf8 = bytes.toString("utf8");
  const text = utf8.includes("�") ? bytes.toString("latin1") : utf8;
  return text.charCodeAt(0) === 0xfeff ? text.slice(1) : text;
}

function needsStrictPrefix(text) {
  return !text.includes('"use strict";') && !text.includes("'use strict';");
}

/**
 * Parse many texts with one host process.
 * @returns {{ok:boolean,line?:number,column?:number,message?:string}[]} one per text
 */
function parseTexts(bin, texts) {
  if (!texts.length) return [];
  const chunks = [];
  for (const t of texts) {
    const b = Buffer.from(t, "utf8");
    chunks.push(Buffer.from(String(b.length) + "\n", "ascii"), b);
  }
  const r = spawnSync(bin, [], { input: Buffer.concat(chunks), maxBuffer: 64 * 1024 * 1024 });
  if (r.error) throw new Error("cannot run " + bin + ": " + r.error.message + " (run tools/oxp-js-parse/build.sh)");
  if (r.status !== 0) throw new Error("oxp-js-parse host exited " + r.status + ": " + String(r.stderr).trim());
  const lines = String(r.stdout).split("\n").filter((l) => l.length);
  if (lines.length !== texts.length) {
    throw new Error(`host answered ${lines.length} records for ${texts.length} inputs`);
  }
  return lines.map((l) => {
    if (l === "ok") return { ok: true };
    const m = /^err (\d+) (\d+) (.*)$/.exec(l);
    if (!m) throw new Error("unexpected host line: " + l.slice(0, 80));
    return { ok: false, line: Number(m[1]), column: Number(m[2]), message: m[3] };
  });
}

/** The rule that explains a parse failure: a detector firing on the failing line. */
function attribute(text, line) {
  const hits = scanText(text, RULE_NAMES).filter((f) => f.line === line);
  return hits.length ? hits[0].rule : "syntax-other";
}

/**
 * Parse a set of named texts. Returns one failure record per failing file (plain failures, and
 * strict-only failures), with positions in the file's own line numbering.
 */
function parseFiles(bin, files) {
  const inputs = [];
  const strictIndex = new Map();
  files.forEach((f, i) => {
    inputs.push(f.text);
    if (needsStrictPrefix(f.text)) {
      strictIndex.set(i, inputs.length);
      inputs.push(STRICT_PREFIX + f.text);
    }
  });
  const results = parseTexts(bin, inputs);
  const failures = [];
  let k = 0;
  files.forEach((f, i) => {
    const plain = results[k++];
    let strict = plain;
    if (strictIndex.has(i)) {
      strict = results[k++];
      if (!strict.ok && strict.line > 0) strict = { ...strict, line: strict.line - 1 };
    }
    if (!plain.ok) {
      failures.push({ file: f.name, mode: "plain", line: plain.line, column: plain.column,
                      rule: attribute(f.text, plain.line), message: plain.message });
    } else if (!strict.ok) {
      failures.push({ file: f.name, mode: "strict-only", line: strict.line, column: strict.column,
                      rule: attribute(f.text, strict.line), message: strict.message });
    }
  });
  return failures;
}

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

function scanCorpus(o) {
  const manifest = JSON.parse(fs.readFileSync(o.manifest, "utf8"));
  const entries = Object.entries(manifest.entries || {});
  const versionFile = o.bin + ".version";
  const report = {
    generated_by: "tools/oxp-js-parse/run.js",
    engine: fs.existsSync(versionFile) ? fs.readFileSync(versionFile, "utf8").trim() : "unknown",
    manifest: path.relative(REPO_ROOT, o.manifest).split(path.sep).join("/"),
    expansions: [],
  };
  const totals = { expansions: 0, parsed: 0, missing: 0, unreadable: 0, js_files: 0,
                   plain_failures: 0, strict_only_failures: 0, breaking_expansions: 0 };
  const byRule = {};
  let n = 0;
  for (const [url, entry] of entries) {
    if (o.limit && n >= o.limit) break;
    n++;
    totals.expansions++;
    const rec = { url, sha256: entry.sha256 || null, status: "ok", js_files: 0, failures: [] };
    const blob = lint.blobPath(o.cacheDir, url);
    if (entry.status !== "ok" || !fs.existsSync(blob)) {
      rec.status = entry.status !== "ok" ? "not-fetched" : "missing-blob";
      totals.missing++;
      report.expansions.push(rec);
      continue;
    }
    try {
      const buf = fs.readFileSync(blob);
      const files = [];
      for (const m of lint.zipEntries(buf)) {
        if (!m.name.toLowerCase().endsWith(".js") || m.size === 0) continue;
        files.push({ name: m.name, text: decode(lint.readMember(buf, m)) });
      }
      rec.js_files = files.length;
      totals.js_files += files.length;
      rec.failures = parseFiles(o.bin, files);
      totals.parsed++;
    } catch (e) {
      rec.status = "unreadable";
      rec.error = String(e.message || e).slice(0, 200);
      totals.unreadable++;
    }
    for (const f of rec.failures) {
      if (f.mode === "plain") totals.plain_failures++;
      else totals.strict_only_failures++;
      const key = f.mode + ":" + f.rule;
      byRule[key] = (byRule[key] || 0) + 1;
    }
    if (rec.failures.some((f) => f.mode === "plain")) totals.breaking_expansions++;
    report.expansions.push(rec);
    if (o.progress && n % 50 === 0) process.stderr.write(`  ... ${n}/${entries.length}\n`);
  }
  report.totals = totals;
  report.by_rule = byRule;
  return report;
}

function parseArgs(argv) {
  const o = { mode: argv[0], paths: [], json: false, limit: 0, progress: false, out: null };
  o.bin = defaultBin();
  o.cacheDir = defaultCacheDir();
  o.manifest = path.join(REPO_ROOT, "tools", "oxp-corpus", "manifest.json");
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--json") o.json = true;
    else if (a === "--progress") o.progress = true;
    else if (a === "--bin") o.bin = argv[++i];
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
      "  node run.js scan <path|dir> ... [--json] [--bin EXE]\n" +
      "  node run.js corpus [--cache-dir D] [--manifest M] [--out F] [--limit N] [--progress] [--bin EXE]\n"
    );
    return 0;
  }
  const o = parseArgs(argv);
  if (!fs.existsSync(o.bin)) throw new Error("no host at " + o.bin + " (run: bash tools/oxp-js-parse/build.sh)");

  if (o.mode === "scan") {
    if (!o.paths.length) throw new Error("scan needs at least one path");
    const names = [];
    for (const p of o.paths) walkJs(p, names);
    const files = names.map((f) => ({ name: f.split(path.sep).join("/"), text: decode(fs.readFileSync(f)) }));
    const failures = parseFiles(o.bin, files);
    if (o.json) {
      process.stdout.write(JSON.stringify({ files: files.length, failures }, null, 2) + "\n");
    } else {
      for (const f of failures) {
        process.stdout.write(`${f.file}:${f.line}:${f.column}: ${f.mode}: ${f.rule}: ${f.message}\n`);
      }
      process.stdout.write(`${files.length} file(s) parsed, ${failures.filter((f) => f.mode === "plain").length} ` +
                           `fail as shipped, ${failures.filter((f) => f.mode === "strict-only").length} fail only under "use strict"\n`);
    }
    return failures.some((f) => f.mode === "plain") ? 1 : 0;
  }

  if (o.mode === "corpus") {
    const t0 = Date.now();
    const report = scanCorpus(o);
    report.wall_seconds = Math.round((Date.now() - t0) / 100) / 10;
    const out = o.out || path.join(HERE, "parse-report.json");
    fs.writeFileSync(out, JSON.stringify(report, null, 1) + "\n");
    const t = report.totals;
    process.stdout.write(
      `parse: ${t.expansions} expansions (${t.parsed} parsed, ${t.missing} not cached, ${t.unreadable} unreadable), ` +
      `${t.js_files} .js members; ${t.plain_failures} fail as shipped in ${t.breaking_expansions} expansions, ` +
      `${t.strict_only_failures} fail only under "use strict"; ${report.wall_seconds}s\n` +
      Object.entries(report.by_rule).sort().map(([k, v]) => `  ${k}: ${v}`).join("\n") + "\n" +
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
    process.stderr.write("oxp-js-parse: " + (e && e.stack ? e.stack : String(e)) + "\n");
    process.exitCode = 2;
  }
}

module.exports = { parseFiles, decode, needsStrictPrefix, main };
