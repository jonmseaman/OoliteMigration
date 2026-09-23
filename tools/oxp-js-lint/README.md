# Mozilla-only-JS static scan (bead oo-ctq)

Flags SpiderMonkey-only JavaScript — the constructs that will not survive a
move to any other engine — across the cached OXP corpus and across the
in-tree scripts.

## The eight constructs

| rule | construct | removed from Firefox in |
| --- | --- | --- |
| `catch-if` | conditional catch: `catch (e if cond) {}` | 59 |
| `e4x` | E4X/ECMA-357: `<tag>` literals, `a..b`, `a.@attr` | 21 |
| `quote-method` | `String.prototype.quote()` | 37 |
| `to-source` | `Object.prototype.toSource()` | 74 |
| `uneval` | global `uneval()` | 74 |
| `let-block` | `let (x = 1) { ... }` (JS1.7) | 44 |
| `legacy-accessor` | `__defineGetter__` / `__defineSetter__` / `__lookup*__` | (deprecated) |
| `expression-closure` | `function (x) x * x` (JS1.8) | 60 |

## Why the detectors are text-based, not AST rules

Four of the eight — conditional catch, E4X, let blocks, expression closures —
are *syntax* no conforming parser accepts. espree, acorn and every ES2015+
parser raise `SyntaxError` on them, and an ESLint rule only runs on a file
that parsed. An AST rule for `catch (e if cond)` is unreachable by
construction.

So the detectors in `rules.js` run over the source text **after masking**:
comments, string literals, template literals and regex literals are replaced
by spaces of equal length (newlines preserved, so line/column stay exact).
Masking is what keeps the scan honest — it is why `fixtures/clean.js`, which
mentions every banned construct inside a string, a comment or a regex,
produces zero findings. Delete the comment-masking branch and that fixture
immediately reports three false positives (see `mutation-proof.sh`, mutant 2).

## Files

| file | role |
| --- | --- |
| `eslint.config.js` | **the** rule set: `MOZILLA_ONLY_RULES` decides what is enabled, for both consumers |
| `plugin.js` | ESLint flat-config plugin wrapping the same detectors |
| `rules.js` | masking + the eight detectors; no dependencies |
| `lint.js` | runner: `scan` (files/dirs) and `corpus` (cached OXZ archives) |
| `fixtures/*.js` | one positive fixture per rule + one clean negative fixture |
| `crosscheck.js` | validation-only: raw unmasked regex sweep, an instrument independent of `lint.js` |
| `mutation-proof.sh` | validation-only: drives each acceptance line RED then GREEN |
| `acceptance.txt` | the five stored acceptance lines, byte-identical to the bead field |
| `probe.js` | triage only (bead oo-1gc.13): a REDACTING view of one line of a corpus script (keywords, punctuators, allowlisted API names; every other identifier a placeholder, literals as STR/NUM/RE) plus declaration and `"use strict"` facts, so an agent can see a construct's shape without reading expansion content (CLAUDE.md rule 6) |
| `probe-selftest.js`, `probe-fixtures/` | the probe's test on synthetic fixtures: nothing outside the allowlist leaks, and the structure and facts are right |

Node stdlib only — no `node_modules`, no network. The corpus mode contains a
minimal zip reader (stored + deflate + ZIP64) because OXZ archives are zips.

## Usage

```sh
node tools/oxp-js-lint/lint.js rules                        # what is enabled
node tools/oxp-js-lint/lint.js scan upstream/oolite/Resources/Scripts
node tools/oxp-js-lint/lint.js corpus --progress            # whole cached corpus
node tools/oxp-js-lint/lint.js corpus --limit 60 --out /tmp/r.json
```

`corpus` reads the byte cache written by bead oo-425
(`%LOCALAPPDATA%/OoliteMigration/oxp-cache`, override with `OXP_CACHE_DIR`)
and the committed `tools/oxp-corpus/manifest.json`. **It never touches the
network**: an entry whose blob is absent is recorded `missing-blob`, not
fetched.

With ESLint installed, the same rules run as a plugin:
`eslint --config tools/oxp-js-lint/eslint.config.js <files>`. ESLint will
refuse to parse the syntax-level fixtures, which is exactly the limitation
that motivated the standalone runner.

## Corpus result (818/818 expansions, 2026-09-18)

```
818 expansions (818 read, 0 not cached, 0 unreadable), 1997 .js members,
5 findings in 2 expansions, 10s
  to-source: 3        Library_1.10.5.oxz  (Lib_Main.js, lib_test.js)
  legacy-accessor: 2  GalCopMissions_0.15.oxz  (Resources/PhraseGen.js)
  catch-if 0, e4x 0, quote-method 0, uneval 0, let-block 0, expression-closure 0
```

A full run takes **~10 seconds** and writes `corpus-report.json` (235 KB, one
record per expansion with url, sha256, status, js_file count and every
finding). Five findings in 2000 files is a low number, so it was verified
against an independent instrument: `crosscheck.js` does raw *unmasked* regex
matching and finds 167 `expression-closure`, 49 `e4x-attr` and 2
`e4x-descendant` candidates on top of the same 5 real hits. Every one of the
extras was inspected and is inside a comment — `this.shipDied = function()
// event that occurs...`, JSDoc `@property {EventType}`, and prose reading
`try..catch blocks`. That is the false-positive class masking exists to kill,
and it confirms the 5 findings are real rather than an artefact of rules that
never loaded.

## Known limits

* Template literals are masked whole, including `${...}` holes, so a banned
  construct used inside an interpolation would be missed. OXP scripts predate
  template literals; no corpus file contains one.
* `expression-closure` does not fire for `function () x` where the body starts
  with a character the detector treats as a block/terminator (`{`, `;`).
* The corpus mode only reads `.js` members of the archives; inline JS in plist
  or `.oxp` config files is out of scope for this bead.

## Acceptance

Five lines, stored in the bead's `acceptance_criteria` and mirrored in
`acceptance.txt`. All are offline; line 5 reads the existing cache and is
capped at 60 expansions so the gate costs ~1 s instead of ~10 s.

1. all 8 rules implemented and enabled (guards against a scan that flags
   nothing because its rules never loaded)
2. positive control — each of the 8 fixtures flagged by its own rule
3. negative control — the clean ES5 fixture produces 0 findings
4. the 31 in-tree scripts produce 0 hits *with all 8 rules live*
5. corpus mode produces a per-expansion report with real `.js` members read
   from the cache

Each line has a recorded mutant that drives it red; `mutation-proof.sh`
re-runs all five.
