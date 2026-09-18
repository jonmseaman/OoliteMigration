"use strict";
/*
 * tools/oxp-js-lint/lint.js - runner for the Mozilla-only-JS scan (bead oo-ctq).
 *
 * Two modes:
 *
 *   node tools/oxp-js-lint/lint.js scan <path|dir> ...
 *       Scan loose .js files / directories. Exit 1 if anything is flagged
 *       (unless --allow-hits). Used for the in-tree "zero hits" assertion and
 *       for the fixtures.
 *
 *   node tools/oxp-js-lint/lint.js corpus [--cache-dir D] [--manifest M]
 *                                        [--out report.json] [--limit N]
 *       Walk every ok entry of tools/oxp-corpus/manifest.json, open its cached
 *       blob as a zip (OXZ archives are zips), scan every .js member, and write
 *       a PER-EXPANSION report. Reads the existing cache only: it never
 *       touches the network, and an entry whose blob is absent is recorded as
 *       "missing" rather than fetched.
 *
 * No node_modules, no network: only Node's stdlib (zlib for the zip members).
 * The enabled rule set comes from eslint.config.js, so that file alone decides
 * what is flagged in both this runner and a real `eslint` invocation.
 */

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const { scanText, RULE_NAMES } = require("./rules");
const config = require("./eslint.config");

const HERE = __dirname;
const REPO_ROOT = path.resolve(HERE, "..", "..");

/* ------------------------------------------------------------------ */
/* minimal zip reader (stored + deflated members)                      */
/* ------------------------------------------------------------------ */

const EOCD_SIG = 0x06054b50;
const CD_SIG = 0x02014b50;
const EOCD64_LOC_SIG = 0x07064b50;
const EOCD64_SIG = 0x06064b50;

function findEOCD(buf) {
  const max = Math.min(buf.length, 0xffff + 22);
  for (let i = buf.length - 22; i >= buf.length - max && i >= 0; i--) {
    if (buf.readUInt32LE(i) === EOCD_SIG) return i;
  }
  return -1;
}

/** List {name, offset, compSize, size, method} for every member. */
function zipEntries(buf) {
  const eocd = findEOCD(buf);
  if (eocd < 0) throw new Error("not a zip (no end-of-central-directory record)");
  let count = buf.readUInt16LE(eocd + 10);
  let cdOffset = buf.readUInt32LE(eocd + 16);

  // ZIP64: the 32-bit fields saturate and the real values live in the ZIP64 EOCD
  if (cdOffset === 0xffffffff || count === 0xffff) {
    const locOff = eocd - 20;
    if (locOff >= 0 && buf.readUInt32LE(locOff) === EOCD64_LOC_SIG) {
      const eocd64 = Number(buf.readBigUInt64LE(locOff + 8));
      if (buf.readUInt32LE(eocd64) !== EOCD64_SIG) throw new Error("bad zip64 EOCD");
      count = Number(buf.readBigUInt64LE(eocd64 + 32));
      cdOffset = Number(buf.readBigUInt64LE(eocd64 + 48));
    } else {
      throw new Error("zip64 end-of-central-directory locator not found");
    }
  }

  const entries = [];
  let p = cdOffset;
  for (let i = 0; i < count; i++) {
    if (p + 46 > buf.length || buf.readUInt32LE(p) !== CD_SIG) break;
    const method = buf.readUInt16LE(p + 10);
    let compSize = buf.readUInt32LE(p + 20);
    let size = buf.readUInt32LE(p + 24);
    const nameLen = buf.readUInt16LE(p + 28);
    const extraLen = buf.readUInt16LE(p + 30);
    const commentLen = buf.readUInt16LE(p + 32);
    let localOff = buf.readUInt32LE(p + 42);
    const name = buf.toString("utf8", p + 46, p + 46 + nameLen);

    if (size === 0xffffffff || compSize === 0xffffffff || localOff === 0xffffffff) {
      // walk the extra field for the 0x0001 ZIP64 record
      let e = p + 46 + nameLen;
      const end = e + extraLen;
      while (e + 4 <= end) {
        const id = buf.readUInt16LE(e);
        const len = buf.readUInt16LE(e + 2);
        let q = e + 4;
        if (id === 0x0001) {
          if (size === 0xffffffff) { size = Number(buf.readBigUInt64LE(q)); q += 8; }
          if (compSize === 0xffffffff) { compSize = Number(buf.readBigUInt64LE(q)); q += 8; }
          if (localOff === 0xffffffff) { localOff = Number(buf.readBigUInt64LE(q)); q += 8; }
          break;
        }
        e += 4 + len;
      }
    }
    entries.push({ name, method, compSize, size, localOff });
    p += 46 + nameLen + extraLen + commentLen;
  }
  return entries;
}

function readMember(buf, entry) {
  const p = entry.localOff;
  if (buf.readUInt32LE(p) !== 0x04034b50) throw new Error("bad local header for " + entry.name);
  const nameLen = buf.readUInt16LE(p + 26);
  const extraLen = buf.readUInt16LE(p + 28);
  const start = p + 30 + nameLen + extraLen;
  const raw = buf.subarray(start, start + entry.compSize);
  if (entry.method === 0) return raw;
  if (entry.method === 8) return zlib.inflateRawSync(raw, { maxOutputLength: 64 * 1024 * 1024 });
  throw new Error("unsupported compression method " + entry.method + " for " + entry.name);
}

/* ------------------------------------------------------------------ */
/* scanning                                                            */
/* ------------------------------------------------------------------ */

const ENABLED = config.enabledRules();

function decode(bytes) {
  // OXPs are old and not all UTF-8; latin-1 never throws and preserves offsets
  const text = bytes.toString("utf8");
  return text.includes("\ufffd") ? bytes.toString("latin1") : text;
}

function scanFile(file) {
  return scanText(fs.readFileSync(file, "utf8"), ENABLED);
}

function walkJs(root, acc) {
  const st = fs.statSync(root);
  if (st.isFile()) {
    if (root.toLowerCase().endsWith(".js")) acc.push(root);
    return acc;
  }
  for (const name of fs.readdirSync(root)) {
    if (name === "node_modules" || name === ".git") continue;
    walkJs(path.join(root, name), acc);
  }
  return acc;
}

/* ------------------------------------------------------------------ */
/* corpus mode                                                         */
/* ------------------------------------------------------------------ */

function defaultCacheDir() {
  if (process.env.OXP_CACHE_DIR) return process.env.OXP_CACHE_DIR;
  const la = process.env.LOCALAPPDATA;
  if (la) return path.join(la, "OoliteMigration", "oxp-cache");
  return path.join(process.env.HOME || ".", ".cache", "oolite-migration", "oxp-cache");
}

function blobPath(cacheDir, url) {
  const k = require("crypto").createHash("sha256").update(url, "utf8").digest("hex");
  return path.join(cacheDir, k.slice(0, 2), k);
}

function expansionName(url) {
  try {
    return decodeURIComponent(url.split("/").pop() || url);
  } catch (e) {
    return url.split("/").pop() || url;
  }
}

function scanCorpus(opts) {
  const manifest = JSON.parse(fs.readFileSync(opts.manifest, "utf8"));
  const entries = Object.entries(manifest.entries || {});
  const cacheDir = opts.cacheDir;
  const report = {
    generated_by: "tools/oxp-js-lint/lint.js",
    rules: ENABLED,
    cache_dir: cacheDir,
    manifest: opts.manifest,
    expansions: [],
  };
  const totals = { expansions: 0, scanned: 0, missing: 0, unreadable: 0, js_files: 0, flagged_expansions: 0, findings: 0 };
  const byRule = {};
  for (const r of ENABLED) byRule[r] = 0;

  let n = 0;
  for (const [url, entry] of entries) {
    if (opts.limit && n >= opts.limit) break;
    n++;
    totals.expansions++;
    const rec = { url, name: expansionName(url), sha256: entry.sha256 || null, status: "ok", js_files: 0, findings: [], counts: {} };
    const blob = blobPath(cacheDir, url);
    if (entry.status !== "ok" || !fs.existsSync(blob)) {
      rec.status = entry.status !== "ok" ? "not-fetched" : "missing-blob";
      totals.missing++;
      report.expansions.push(rec);
      continue;
    }
    let buf;
    try {
      buf = fs.readFileSync(blob);
      const members = zipEntries(buf).filter((e) => e.name.toLowerCase().endsWith(".js") && e.size > 0);
      for (const m of members) {
        let text;
        try {
          text = decode(readMember(buf, m));
        } catch (e) {
          rec.status = "partial";
          rec.error = String(e.message || e);
          continue;
        }
        rec.js_files++;
        totals.js_files++;
        for (const f of scanText(text, ENABLED)) {
          rec.findings.push({ file: m.name, rule: f.rule, line: f.line, column: f.column, snippet: f.snippet });
          rec.counts[f.rule] = (rec.counts[f.rule] || 0) + 1;
          byRule[f.rule]++;
          totals.findings++;
        }
      }
      if (rec.status === "ok") totals.scanned++;
    } catch (e) {
      rec.status = "unreadable";
      rec.error = String(e.message || e);
      totals.unreadable++;
      report.expansions.push(rec);
      continue;
    }
    if (rec.findings.length) totals.flagged_expansions++;
    report.expansions.push(rec);
    if (opts.progress && n % 25 === 0) {
      process.stderr.write(`  ... ${n}/${entries.length} expansions, ${totals.findings} findings\n`);
    }
  }
  report.totals = totals;
  report.by_rule = byRule;
  return report;
}

/* ------------------------------------------------------------------ */
/* cli                                                                 */
/* ------------------------------------------------------------------ */

function parseArgs(argv) {
  const o = { mode: argv[0], paths: [], json: false, allowHits: false, limit: 0, progress: false };
  o.cacheDir = defaultCacheDir();
  o.manifest = path.join(REPO_ROOT, "tools", "oxp-corpus", "manifest.json");
  o.out = null;
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--json") o.json = true;
    else if (a === "--allow-hits") o.allowHits = true;
    else if (a === "--progress") o.progress = true;
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
      "  node lint.js scan <path|dir> ... [--json] [--allow-hits]\n" +
      "  node lint.js corpus [--cache-dir D] [--manifest M] [--out F] [--limit N] [--progress]\n" +
      "  node lint.js rules\n"
    );
    return 0;
  }
  const o = parseArgs(argv);

  if (o.mode === "rules") {
    process.stdout.write(JSON.stringify({ all: RULE_NAMES, enabled: ENABLED }, null, 2) + "\n");
    return 0;
  }

  if (o.mode === "scan") {
    if (!o.paths.length) throw new Error("scan needs at least one path");
    const files = [];
    for (const p of o.paths) walkJs(p, files);
    const results = [];
    let total = 0;
    for (const f of files.sort()) {
      const findings = scanFile(f);
      total += findings.length;
      results.push({ file: f.split(path.sep).join("/"), findings });
    }
    if (o.json) {
      process.stdout.write(JSON.stringify({ rules: ENABLED, files: results.length, findings: total, results }, null, 2) + "\n");
    } else {
      for (const r of results) {
        for (const f of r.findings) {
          process.stdout.write(`${r.file}:${f.line}:${f.column}: ${f.rule}: ${f.message}\n`);
        }
      }
      process.stdout.write(`${files.length} file(s) scanned, ${total} finding(s), rules: ${ENABLED.join(",") || "(none enabled)"}\n`);
    }
    return total && !o.allowHits ? 1 : 0;
  }

  if (o.mode === "corpus") {
    const t0 = Date.now();
    const report = scanCorpus(o);
    report.wall_seconds = Math.round((Date.now() - t0) / 100) / 10;
    const out = o.out || path.join(REPO_ROOT, "tools", "oxp-js-lint", "corpus-report.json");
    fs.mkdirSync(path.dirname(out), { recursive: true });
    fs.writeFileSync(out, JSON.stringify(report, null, 1) + "\n");
    const t = report.totals;
    process.stdout.write(
      `corpus scan: ${t.expansions} expansions (${t.scanned} read, ${t.missing} not cached, ${t.unreadable} unreadable), ` +
      `${t.js_files} .js members, ${t.findings} findings in ${t.flagged_expansions} expansions, ${report.wall_seconds}s\n` +
      Object.entries(report.by_rule).map(([k, v]) => `  ${k}: ${v}`).join("\n") + "\n" +
      `report: ${out.split(path.sep).join("/")}\n`
    );
    return 0;
  }

  throw new Error("unknown mode: " + o.mode);
}

if (require.main === module) {
  try {
    process.exitCode = main(process.argv.slice(2));
  } catch (e) {
    process.stderr.write("oxp-js-lint: " + (e && e.stack ? e.stack : String(e)) + "\n");
    process.exitCode = 2;
  }
}

module.exports = { scanCorpus, zipEntries, readMember, blobPath, main };
