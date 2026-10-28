"use strict";
/*
 * tools/oxp-js-parse/selftest.js -- proves the parse layer against fixtures/expected.json.
 *
 *   node tools/oxp-js-parse/selftest.js        (after: bash tools/oxp-js-parse/build.sh)
 *
 * Every fixture must fail in exactly the expected mode at the expected line, and the clean
 * fixture must parse both ways. A host that accepted everything, or a driver that dropped the
 * strict variant or forgot to shift its line numbers back, turns this red.
 */

const fs = require("fs");
const path = require("path");
const { parseFiles, decode, main } = require("./run");

const DIR = path.join(__dirname, "fixtures");
const bin = process.env.OXP_JS_PARSE_BIN ||
  path.join(__dirname, "..", "..", ".agent-tmp", "oxp-js-parse", "oxp-js-parse.exe");

const expected = JSON.parse(fs.readFileSync(path.join(DIR, "expected.json"), "utf8"));
const names = Object.keys(expected).filter((k) => !k.startsWith("_")).sort();
const onDisk = fs.readdirSync(DIR).filter((f) => f.endsWith(".js")).sort();
let bad = 0;
const fail = (msg) => { bad++; process.stdout.write("FAIL " + msg + "\n"); };

if (JSON.stringify(names) !== JSON.stringify(onDisk)) {
  fail(`expected.json lists ${names.join(",")} but fixtures/ has ${onDisk.join(",")}`);
}

const files = onDisk.map((n) => ({ name: n, text: decode(fs.readFileSync(path.join(DIR, n))) }));
const failures = parseFiles(bin, files);
for (const n of names) {
  const got = failures.filter((f) => f.file === n);
  const want = expected[n];
  if (want === null) {
    if (got.length) fail(`${n}: expected to parse, got ${got[0].mode} at line ${got[0].line}`);
    continue;
  }
  if (got.length !== 1) { fail(`${n}: expected one ${want.mode} failure, got ${got.length}`); continue; }
  if (got[0].mode !== want.mode) fail(`${n}: mode ${got[0].mode}, expected ${want.mode}`);
  if (got[0].line !== want.line) fail(`${n}: line ${got[0].line}, expected ${want.line}`);
}

// LF and CRLF copies must fail at the same lines: the host reads bytes, not text. (The fixtures
// themselves are LF or CRLF depending on core.autocrlf, so normalise before converting.)
const lf = files.map((f) => ({ name: f.name, text: f.text.replace(/\r\n/g, "\n") }));
const crlf = lf.map((f) => ({ name: f.name, text: f.text.replace(/\n/g, "\r\n") }));
const lfFailures = parseFiles(bin, lf);
const crlfFailures = parseFiles(bin, crlf);
const shape = (list) => JSON.stringify(list.map((f) => [f.file, f.mode, f.line]));
if (shape(lfFailures) !== shape(failures) || shape(crlfFailures) !== shape(failures)) {
  fail("line endings change the result");
}

// The CLI exits 1 on a breaking fixture and 0 on the clean one.
const origWrite = process.stdout.write.bind(process.stdout);
process.stdout.write = () => true;
const rcBreak = main(["scan", path.join(DIR, "for-each.js"), "--bin", bin]);
const rcClean = main(["scan", path.join(DIR, "clean.js"), "--bin", bin]);
process.stdout.write = origWrite;
if (rcBreak !== 1) fail(`scan of a breaking fixture exited ${rcBreak}, expected 1`);
if (rcClean !== 0) fail(`scan of the clean fixture exited ${rcClean}, expected 0`);

process.stdout.write(bad ? `oxp-js-parse selftest: ${bad} failure(s)\n`
                         : `oxp-js-parse selftest: ${names.length} fixtures OK (plain, strict-only, CRLF, exit codes)\n`);
process.exitCode = bad ? 1 : 0;
