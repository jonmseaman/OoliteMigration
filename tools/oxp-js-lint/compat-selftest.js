"use strict";
/*
 * tools/oxp-js-lint/compat-selftest.js -- proves the compat rule set (ADR-0069, layer 2).
 *
 *   node tools/oxp-js-lint/compat-selftest.js
 *
 * 1. Each fixture in fixtures-compat/ produces exactly the [rule, severity, line] list in
 *    expected.json; the clean fixture produces none.
 * 2. Anti-vacuity for the negative control: with masking switched off, the clean fixture's
 *    near-misses (constructs inside strings, comments and a regex) DO fire. So "clean.js has no
 *    hits" proves the masking works, not that the detectors are blind.
 * 3. The read-only table is really read from oxp-contract/js-api-1.93.json: known read-only
 *    properties are in it, and known writable ones are not.
 * 4. Every detector fires on at least one fixture, so no rule ships untested.
 * No game build, no corpus, no network.
 */

const fs = require("fs");
const path = require("path");
const { COMPAT_DETECTORS, COMPAT_RULE_NAMES, scanCompat } = require("./compat-rules");
const lint = require("./lint");

const DIR = path.join(__dirname, "fixtures-compat");
const expected = JSON.parse(fs.readFileSync(path.join(DIR, "expected.json"), "utf8"));
let bad = 0;
const fail = (msg) => { bad++; process.stdout.write("FAIL " + msg + "\n"); };

const names = Object.keys(expected).filter((k) => !k.startsWith("_")).sort();
const onDisk = fs.readdirSync(DIR).filter((f) => f.endsWith(".js")).sort();
if (JSON.stringify(names) !== JSON.stringify(onDisk)) {
  fail(`expected.json lists ${names.join(",")} but fixtures-compat/ has ${onDisk.join(",")}`);
}

// 1. exact findings
const fired = new Set();
for (const n of onDisk) {
  const src = lint.decode(fs.readFileSync(path.join(DIR, n)));
  const got = scanCompat(src).map((f) => [f.rule, f.severity, f.line]);
  got.forEach((g) => fired.add(g[0]));
  const want = expected[n] || [];
  const key = (l) => JSON.stringify(l.map((x) => x.join(":")).sort());
  if (key(got) !== key(want)) fail(`${n}: got ${JSON.stringify(got)}, expected ${JSON.stringify(want)}`);
}

// 2. clean fixture's near-misses fire without masking
const clean = lint.decode(fs.readFileSync(path.join(DIR, "clean.js")));
let unmasked = 0;
for (const r of COMPAT_RULE_NAMES) unmasked += COMPAT_DETECTORS[r].detect(clean, clean).length;
if (unmasked === 0) fail("clean.js has no near-misses: with masking off it still produces 0 hits, so it proves nothing");

// 3. the read-only table
const probe = (recv, prop) => scanCompat(`${recv}.${prop} = 1;`).some((f) => f.rule === "readonly-native-write");
for (const [recv, prop] of [["this.ship", "isPirate"], ["player.ship", "cargoSpaceAvailable"], ["system.mainStation", "isStation"]]) {
  if (!probe(recv, prop)) fail(`${recv}.${prop} should be read-only per js-api-1.93.json`);
}
for (const [recv, prop] of [["player", "credits"], ["player.ship", "fuel"], ["this.ship", "displayName"]]) {
  if (probe(recv, prop)) fail(`${recv}.${prop} is writable in js-api-1.93.json but was flagged`);
}

// 4. no untested detector
for (const r of COMPAT_RULE_NAMES) if (!fired.has(r)) fail(`rule ${r} fires on no fixture`);

process.stdout.write(bad ? `compat selftest: ${bad} failure(s)\n`
  : `compat selftest: ${onDisk.length} fixtures exact, ${COMPAT_RULE_NAMES.length} rules each exercised, ` +
    `clean.js has ${unmasked} unmasked near-misses, read-only table checked\n`);
process.exitCode = bad ? 1 : 0;
