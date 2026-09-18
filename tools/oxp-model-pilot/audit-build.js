"use strict";
/*
 * Hand-audit of the oo-l7u sample, encoded as data.
 *
 * Every verdict below was reached by a human-equivalent reading of the hit
 * line and its +/-2 lines of context as printed from sample.jsonl. The
 * categories are my reasoning, not a heuristic re-run of the detector: a
 * classifier is judged AGAINST this file, so nothing here may be derived from
 * the detector's own output.
 *
 * Verdict vocabulary:
 *   "mozilla"        - a real Mozilla-only (SpiderMonkey-only) construct
 *   "false-positive" - the naive unmasked regex matched comment/string text,
 *                      or matched across a comment boundary
 *
 * Run: node audit-build.js  (writes data/audit.jsonl)
 */
const fs = require("fs");
const path = require("path");

const DIR = path.join(__dirname, "data");
const sample = fs.readFileSync(path.join(DIR, "sample.jsonl"), "utf8")
  .split("\n").filter(Boolean).map((l) => JSON.parse(l));

/* Per-id verdicts. Keyed by hit id so the audit cannot silently drift onto a
 * different sample: audit-build asserts the key set equals the sample's. */
const R = {
  // ---- reason strings, written once and referenced below ----
  TRAILING_COMMENT:
    "false-positive|the parameter list is followed by a `//` line comment, not a body expression; " +
    "`function(...)` + `/` only matches because the unmasked regex sees comment text. Masked detector correctly silent.",
  COMMENTED_OUT:
    "false-positive|the whole `this.x = function(...)` line is commented out with `//`; it is not code at all, " +
    "and even uncommented it is an ordinary function expression with a `{` body.",
  JSDOC_AT:
    "false-positive|JSDoc prose inside a /** */ block: the `.` ending the previous sentence plus the next line's " +
    "`@param`-style tag satisfies /\\.\\s*@\\s*\\w/. No E4X attribute access; masked detector correctly silent.",
  STRING_AT:
    "false-positive|inside a double-quoted sentence-template string literal, where `.` + ` @token` is prose " +
    "punctuation followed by Oolite's `@` description placeholder. Not E4X.",
  CROSS_COMMENT:
    "false-positive|the literal word `function` occurs in a line comment and the regex then consumes the newline " +
    "and glues it to the NEXT statement's `(...)`; the match spans a comment boundary and describes no real construct. " +
    "This is the clearest demonstration in the sample of why masking is required.",
  COMMENT_SIG:
    "false-positive|a function signature written inside a /** */ documentation comment, describing the API rather than " +
    "declaring it.",
  LEADING_COMMENT:
    "false-positive|the matched text begins in the preceding `//` comment (which contains the word `function` and a " +
    "parenthesised aside) and runs into the real assignment on the next line.",
};

/* id -> [verdict, reasonKey] */
const VERDICTS = {
  // --- expression-closure: `function (...)` immediately followed by a // comment ---
  "62aa2dfacc21e3b7": ["false-positive", "TRAILING_COMMENT"], // Random_hits autominer:51
  "0c914fae3ce73b9a": ["false-positive", "TRAILING_COMMENT"], // ClassicShips thargoid warship:34 (comment on next line)
  "fd5b01e9f976deba": ["false-positive", "TRAILING_COMMENT"], // Thargoid Pods pods.js:348
  "fd9a99c6b127117d": ["false-positive", "TRAILING_COMMENT"], // noshaders remove_rock_chunks:15
  "cb943f656c616c15": ["false-positive", "TRAILING_COMMENT"], // Teretrurus:47
  "afbdd13c49d4c4da": ["false-positive", "TRAILING_COMMENT"], // ClassicMussurana:67
  "01390e835edd9ed6": ["false-positive", "TRAILING_COMMENT"], // Feudal challenge:40
  "5650c394638814d7": ["false-positive", "TRAILING_COMMENT"], // masslock_compensator:65
  "a1826b5a6c377032": ["false-positive", "TRAILING_COMMENT"], // assassin shipset:178
  "85bb7a1912839349": ["false-positive", "TRAILING_COMMENT"], // SunGear astro_library:179
  "3f32047f1d6392a9": ["false-positive", "TRAILING_COMMENT"], // ExtraFuelTanks:23
  "f96e2343ec2aac74": ["false-positive", "TRAILING_COMMENT"], // SunGear astro_library:201
  "1bf97ed5504d6284": ["false-positive", "TRAILING_COMMENT"], // SunGear astro_library:169
  "32eaae0e638a977d": ["false-positive", "TRAILING_COMMENT"], // Feudal mission:63
  "6ee220f024222739": ["false-positive", "TRAILING_COMMENT"], // spacecrowds script.js:161
  "5fc93790b32eefc9": ["false-positive", "TRAILING_COMMENT"], // OrbitalStations spawn_station:121
  "acd8bcbf082ed501": ["false-positive", "TRAILING_COMMENT"], // UPS_Courier ups_docs:160
  "ccd045f21814eaf8": ["false-positive", "TRAILING_COMMENT"], // EscapePodLocator beacon:29
  "7f03d5ef05ae1124": ["false-positive", "TRAILING_COMMENT"], // ClassicShips warship:16
  "a1f172bf8a0fc84d": ["false-positive", "TRAILING_COMMENT"], // SunGear astro_library:208
  "1969c07707fcf6bf": ["false-positive", "TRAILING_COMMENT"], // Thargoid Pods:463
  "6d4dd8c83ab31016": ["false-positive", "TRAILING_COMMENT"], // MiningIFFScanner:43
  "5e04d94b64e7da64": ["false-positive", "TRAILING_COMMENT"], // berthControl:13
  "a24fc43e1e1cf158": ["false-positive", "TRAILING_COMMENT"], // EscapePodLocator beacon:10
  "635dd7f6da101b7e": ["false-positive", "TRAILING_COMMENT"], // ClassicShips(Replace) warship:41
  "9cf21d97af1656db": ["false-positive", "TRAILING_COMMENT"], // GiantSpacePizza neon timer:34
  "63de199f479f58dc": ["false-positive", "TRAILING_COMMENT"], // Aquatics hammerHead:43
  "a5cd07d52c8582f7": ["false-positive", "TRAILING_COMMENT"], // ExtraFuelTanks:12
  "4c8f3b002d7414c7": ["false-positive", "TRAILING_COMMENT"], // SunGear astro_library:258
  "6658d52ace73f7a5": ["false-positive", "TRAILING_COMMENT"], // MiningIFFScanner:86
  "bcd5f851c7e0206c": ["false-positive", "TRAILING_COMMENT"], // Moons spawn_moon:163
  "eaba07f8f953175d": ["false-positive", "TRAILING_COMMENT"], // Thargoid Pods:478
  "93bd70cc2df05160": ["false-positive", "TRAILING_COMMENT"], // FuelCollector:635
  "3735dfaf55c47b1b": ["false-positive", "TRAILING_COMMENT"], // spacecrowds:167
  "65a14ff2102cdaf8": ["false-positive", "TRAILING_COMMENT"], // Thargoid Pods:472
  "98eace9178d1b98c": ["false-positive", "TRAILING_COMMENT"], // Extra_Thargoids frigatePoet:83 (stray `{` inside the comment)
  "11c40104153a8a5b": ["false-positive", "COMMENTED_OUT"],    // Ferdelance3G:284
  "d1355c37da8bae2e": ["false-positive", "COMMENTED_OUT"],    // GWunits:9
  "e7814d10d9e49399": ["false-positive", "COMMENTED_OUT"],    // FuelStation:31
  "00fd7c9f50b95ea8": ["false-positive", "COMMENTED_OUT"],    // Escort_Contracts:811
  "ac4ec85c50eca75e": ["false-positive", "CROSS_COMMENT"],    // Vortex maelstrom:929
  "d8ddc7d2ef31a27c": ["false-positive", "LEADING_COMMENT"],  // Synchronised_Torus:269
  "ed86d6c54705f13a": ["false-positive", "COMMENT_SIG"],      // Library Lib_Starmap:33
  // --- e4x-attr / e4x-descendant ---
  "f9716af36bc36991": ["false-positive", "JSDOC_AT"],  // Lib_Crypt:10
  "aa1c8d8d8d7d8174": ["false-positive", "JSDOC_AT"],  // Lib_Crypt:9
  "db8383fe4ead2504": ["false-positive", "JSDOC_AT"],  // Lib_BinSearch:68
  "848f6a367b221ec4": ["false-positive", "JSDOC_AT"],  // Lib_BinSearch:43
  "80e3ba0b672df277": ["false-positive", "JSDOC_AT"],  // Lib_BinSearch:87
  "055bc91091dc3fb5": ["false-positive", "STRING_AT"], // GNN_Words:307
  "b4ca5f3f09cc036d": ["false-positive", "STRING_AT"], // GNN_Words:330
};

/* Controls carry their truth in the record (control_truth) and are audited
 * with an explicit reason too, so the audit file is uniform. */
const CONTROL_REASON = {
  "control-fixture":
    "mozilla|committed positive-control fixture: the construct is present as executable syntax, not in a comment or string.",
  "control-corpus-finding":
    "mozilla|survived masking in the oo-ctq corpus scan: the construct appears in live code (verified against the committed snippet).",
};

function main() {
  const out = [];
  const seenIds = new Set();
  for (const rec of sample) {
    if (seenIds.has(rec.id)) continue;   // the corpus-finding controls contain exact duplicates
    seenIds.add(rec.id);
    let verdict, reason;
    if (rec.control_truth) {
      const r = CONTROL_REASON[rec.source];
      if (!r) throw new Error("no control reason for source " + rec.source);
      [verdict, reason] = r.split("|");
      if (verdict !== rec.control_truth) throw new Error("control reason disagrees with control_truth: " + rec.id);
    } else {
      const v = VERDICTS[rec.id];
      if (!v) throw new Error("UNAUDITED sample record: " + rec.id + " " + rec.expansion + "!" + rec.member + ":" + rec.line);
      verdict = v[0];
      const text = R[v[1]];
      if (!text) throw new Error("unknown reason key " + v[1]);
      const [rv, rtext] = [text.split("|")[0], text.split("|").slice(1).join("|")];
      if (rv !== verdict) throw new Error("reason text disagrees with verdict for " + rec.id);
      reason = rtext;
    }
    out.push({
      id: rec.id, expansion: rec.expansion, member: rec.member, line: rec.line,
      construct: rec.construct, source: rec.source,
      verdict, reason, snippet: rec.snippet,
      auditor: "oo-l7u", audited_at: "2026-09-18",
    });
  }
  const unknown = Object.keys(VERDICTS).filter((k) => !seenIds.has(k));
  if (unknown.length) throw new Error("VERDICTS contains ids absent from the sample: " + unknown.join(","));
  out.sort((a, b) => a.id.localeCompare(b.id));
  fs.writeFileSync(path.join(DIR, "audit.jsonl"), out.map((r) => JSON.stringify(r)).join("\n") + "\n");
  const n = { mozilla: 0, "false-positive": 0 };
  for (const r of out) n[r.verdict]++;
  console.log(JSON.stringify({ audited: out.length, ...n, out: "data/audit.jsonl" }));
}
main();
