# Data model: Adopt Google Test

The entities from the spec's *Key Entities*, as the scripts and the build see them.

## Test program

| Field | Value |
|---|---|
| `source` | `tests/unit/<suite-dir>/test_<Stem>.cpp` |
| `suite` | meson suite(s): `oofnd`, `oofnd-plist`, `core`, `openal` (as today) |
| `harness` | `oo_test` or `gtest`. A new field in the `oofnd` and `core` `meson.build` entries for M1–M5, removed in M6 |
| `gtestSuite` | `<Stem>` (file name less `test_` and `.cpp`), only when `harness = gtest` |
| `executable` | `oofnd_test_<Stem>` / `core_test_<Stem>` (unchanged) |
| `protocol` | `exitcode` for `oo_test`, `gtest` for `gtest` |
| `timeout` | 60 s (unchanged) |

**Rules**: one program, one suite in Google Test's sense (so no class-name collisions, R5). A
`gtest` program links `oo_gtest_dep` and never `gtest_main`. It has at least one `TEST` (a
program without one fails at run time, FR-006).

**State**: `oo_test` → `gtest` (its batch converts it; M3 or M5). There is no way back except
reverting the batch.

## Test case

| Field | Value |
|---|---|
| `name` | identifier, unchanged by conversion (FR-011), underscores allowed |
| `fullName` | `<gtestSuite>.<name>` after conversion; `<name>` before |
| `order` | position in the source file; the run order (FR-010) |
| `result` | `pass`, `fail`; or `not-run` when a filter excludes it or the program died earlier |

**Rule** (FR-013): for every case, `result(before) = pass` implies `result(after) = pass`.

## Check site

| Field | Value |
|---|---|
| `file`, `line` | where the macro is written (call sites of wrapper macros count once each, at the call) |
| `kind` | old: `OO_CHECK`, `OO_CHECK_EQ`, `CHECK`, `CHECK_JS`, wrapper names; new: by the mapping in [contracts/check-mapping.md](contracts/check-mapping.md) |
| `valueUsed` | true where the result is used as an expression (19 sites) |
| `expression` | the macro's argument text, whitespace collapsed |
| `fatal` | always false, before and after |

**Identity across conversion**: a site is the same site if it is in the same file, in the same
case (or helper function), at the same position in order, with the mapped kind and the same
`expression`. Line numbers may move (the include line changes); order may not.

## Migration batch

| Field | Value |
|---|---|
| `id` | `oofnd`, `core-verifier`, `core-materials`, `core-sound`, `core-js`, `core-entities`, `core-rest` |
| `programs` | list of test programs (the `core` families are listed in `tasks.md`) |
| `baseRef` | the `oolite-dev` commit before the batch |
| `staticReport` | `parity.py static` output: per file, cases and sites before/after, differences |
| `runReport` | `parity.py run` output: cases that passed before and do not now |
| `state` | `open` → `parity-clean` → `committed`; or `stopped` (a regression or an unexplained parity difference; reported, not fixed by editing the expectation) |

## Result report

Meson's own, per run: `build/meson_<type>/meson-logs/testlog.txt` (console text), `testlog.json`
and `testlog.junit.xml`. With `protocol: 'gtest'`, meson adds one `<testcase>` per Google Test case
under the program's `<testsuite>`. Old-harness programs appear as one test each until converted.

## Ledger entry (`test-ledger.md`)

| Field | Value |
|---|---|
| `file:line` | where the hand edit is |
| `before` / `after` | the text |
| `why` | one of: sign-compare literal, bit-field `+`, custom `main` → `Environment`, wrapper body, own-harness macro |
| `meaning kept` | one line saying why the assertion's meaning is unchanged |

The mechanical mapping is not ledgered line by line; `parity.py static` proves it.
