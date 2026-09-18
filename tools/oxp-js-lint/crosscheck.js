"use strict";
/*
 * Independent cross-check of the corpus scan (bead oo-ctq, validation only).
 *
 * Deliberately NOT the instrument under test: this does raw, unmasked
 * substring/regex matching over every .js member in the cache and reports
 * every candidate. Anything it finds that lint.js did not flag must be
 * explainable as a string/comment/regex occurrence; anything lint.js flagged
 * that this misses would mean lint.js is inventing hits.
 */
const fs = require("fs");
const path = require("path");
const { zipEntries, readMember, blobPath } = require("./lint");

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

const manifest = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const cacheDir = process.argv[3];
const counts = {};
const samples = {};
let files = 0;

for (const [url, entry] of Object.entries(manifest.entries || {})) {
  if (entry.status !== "ok") continue;
  const blob = blobPath(cacheDir, url);
  if (!fs.existsSync(blob)) continue;
  let buf;
  try { buf = fs.readFileSync(blob); } catch (e) { continue; }
  let members;
  try { members = zipEntries(buf).filter((e) => e.name.toLowerCase().endsWith(".js") && e.size > 0); }
  catch (e) { continue; }
  for (const m of members) {
    let text;
    try { text = readMember(buf, m).toString("latin1"); } catch (e) { continue; }
    files++;
    for (const [name, re] of Object.entries(RAW)) {
      const rx = new RegExp(re.source, "g");
      let mm;
      while ((mm = rx.exec(text)) !== null) {
        counts[name] = (counts[name] || 0) + 1;
        (samples[name] = samples[name] || []);
        if (samples[name].length < 6) {
          const start = text.lastIndexOf("\n", mm.index) + 1;
          let end = text.indexOf("\n", mm.index); if (end < 0) end = text.length;
          samples[name].push(`${path.basename(url)}!${m.name}: ${text.slice(start, end).trim().slice(0, 140)}`);
        }
      }
    }
  }
}
console.log("raw files scanned:", files);
console.log(JSON.stringify(counts, null, 1));
for (const [k, v] of Object.entries(samples)) {
  console.log("\n## " + k);
  for (const s of v) console.log("   " + s);
}
