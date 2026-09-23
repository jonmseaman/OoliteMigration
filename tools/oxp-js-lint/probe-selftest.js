"use strict";
/*
 * Self-test for probe.js (bead oo-1gc.13) on synthetic fixtures written for it.
 * Proves the two properties the probe exists for:
 *   1. REDACTION: no word of the fixture outside the allowlist reaches stdout
 *      (every such word in the fixture contains "secret").
 *   2. FIDELITY: structure, placeholders and declaration/strictness facts are right.
 *   node tools/oxp-js-lint/probe-selftest.js     -> exit 0 and "PROBE SELFTEST OK"
 */
const assert = require("assert");
const path = require("path");
const { execFileSync } = require("child_process");

const probe = path.join(__dirname, "probe.js");
const fx = (n) => path.join(__dirname, "probe-fixtures", n);
const run = (...a) => execFileSync(process.execPath, [probe, ...a], { encoding: "utf8" });

const out = run("file", fx("sample.js"), "8", "--context", "10", "--parse");
assert.ok(!/secret/i.test(out), "REDACTION FAILED: fixture text leaked:\n" + out);
for (const want of [
  "use-strict at top of file: yes",
  "use-strict function directives at lines: 15",
  "v8 parse: ok",
  "     4: this . ID1 = NUM ;",
  "     3: this . name = STR ;",
  "    15: STR\"use strict\" ;",
  "    18: this [ STR\"oolite_manifest_identifier\" ] = this [ STR ] ;",
  "     7: var ID4 = new Vector3D ( NUM , NUM , NUM ) ;",
  ">    8: for ( ID5 in ID3 ) {",
  "     9: ID4 . add ( RE . test ( STR ) ) ;",
  "    11: player . consoleMessage ( TPL , NUM ) ;",
  "  ID1: declared=no bare=0 member=1 key=0 this-assign=1",
  "  ID3: declared=paramx1 bare=2 member=0 key=0 this-assign=0",
  "  ID4: declared=varx1 bare=2 member=0 key=0 this-assign=0",
  "  ID5: declared=no bare=1 member=0 key=0 this-assign=0",
  "  ID6: declared=functionx1 bare=1 member=0 key=0 this-assign=0",
]) assert.ok(out.includes(want + "\n"), `missing line ${JSON.stringify(want)} in:\n${out}`);
assert.ok(!out.includes("//") && !out.includes("SECRETCOMMENT"), "comment leaked");

const wh = run("file", fx("sample.js"), "7", "--context", "0", "--where", "ID4");
assert.ok(wh.includes("ID4 occurs on lines: 7,9\n") && !/secret/i.test(wh), "--where wrong:\n" + wh);

const bad = run("file", fx("unparsable.js"), "2", "--context", "0", "--parse");
assert.ok(!/secret/i.test(bad), "REDACTION FAILED on parse error:\n" + bad);
assert.ok(/v8 parse: SyntaxError at line 2 column \d+/.test(bad), "parse failure not located:\n" + bad);
assert.ok(bad.includes("use-strict at top of file: no"), bad);
assert.ok(bad.includes(">    2: this . ID2 = function ( ID3 ) ID3 * NUM ;"), bad);
process.stdout.write("PROBE SELFTEST OK: redaction holds on 2 fixtures; tokens, placeholders, declarations, directives and parse position correct\n");
