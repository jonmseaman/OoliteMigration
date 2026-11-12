# Triage: #772 probe and JS tests against the C++ build

Every probe line that differs from upstream's stored output and every failing JS test, with its
class (FR-006). Classes: *engine*, *platform*, *noise*, *migration*, *known difference*.
Proposals only: Jon adjudicates (Hard rule 5).

## Run 1 — pilot, 2026-11-12

- **Build**: `oolite-dev` `012-adopt-upstream-772-tests` at `ee6cde6d2` (`seriesb/025-libcurl-http`
  `ab6ac68b3` plus the #772 import), `./mk.sh build test`, Clang, Windows 11.
- **Imported from**: OoliteProject/oolite#772 at `12c39549e`, unchanged.
- **Commands** (from the worktree):
  `python tools/js-parity/run_probe.py build/meson_test/oolite.app <out> --check-leaks`,
  `tools/js-parity/compare.sh tools/js-parity/baseline-quickjs.txt <out>`,
  `python tests/run_js_tests.py --path build/meson_test/oolite.app --test_output <dir>`.

### JS tests

69 passed, 0 failed, all five phases; no unexpected script exceptions; the one time-limit kill is
the one a test declares with `// expect-log`; the leak check passed; compiled-script cache: 807
loads, 46 stores, 0 stale, 0 read failures. About 7 s of game log at 16x.

### Probe

1,100 lines (same count as the reference), exit 0, no leaked objects. Two runs on Windows match
each other once upstream's `noise.txt` is applied. Against `baseline-quickjs.txt` (Linux x86-64),
37 lines differ:

| # | Lines | What differs | Class | Evidence | Outcome |
|---|---|---|---|---|---|
| 1 | 31 | Location line after each script warning: `C:/…/probe.txt.run/AddOns/…` instead of `<AddOns>/…` | platform | `run_probe.py` replaces the AddOns path as `os.path` writes it (`C:\…`); the game logs it with `/`. Message lines match. | Fork-side runner normalises `/` and `\` (adaptation A2); not a game difference |
| 2 | 1 | `station.shipyard`: Python, Python where Linux has Adder, Cobra Mk I | platform (unconfirmed) | Upstream's own outputs differ by platform: macOS has Cobra Mk I, Python. Stable across Windows runs. | Follow-up F1: compare with an upstream 1.93 Windows build; until then not counted as a bug |
| 3 | 1 | `"government" in system.info` is `true`; reference `false` | known difference | `OOJSSystemInfo.cpp` comment: the `has_property` hook answers true for data keys so that QuickJS-ng 0.17's `for..in` lists them | Jon: keep, or document in `docs/current-state.md` known differences |
| 4 | 4 | Method sweep, array argument `[1, 2]`: `Ship.setMaterials`, `Ship.setShaders` → `ok:boolean`, `Mission.markSystem` → `ok:undefined`, `Mission.unmarkSystem` → `ok:boolean`; reference `Error:Native exception` for all four | **migration** | Upstream converts the array to an `NSArray` and sends it a dictionary method (`oo_intForKey:` in `OOJSMission.m` `MissionMarkSystem`); the unrecognised selector raises an Objective-C exception, which `OOJS_NATIVE_EXIT` turns into a script error. The C++ port's `oo::PList::get<int>("system", -1)` (`OOJSMission.cpp` `MissionMarkSystem`) returns the default for an array, so the call succeeds silently. `setMaterials` and `setShaders` reach `+[OOMaterial materialWithName:…]` (`OOMaterialConvenienceCreators.m`), which sends `oo_dictionaryForKey:` to the shaders dictionary while shaders are on, then to the materials dictionary for each material no shader entry covers. | **Jon (2026-11-12): match upstream.** Fixed in run 2 |

No other differences. Against the macOS output (`baseline-quickjs-macos.txt`) the same rows appear,
plus one float formatting difference (`player.ship.collisionRadius` `72.697342` vs `72.69735`)
where the C++ build matches Linux.

## Run 2 — row 4 fixed, 2026-11-12

Jon decided row 4: match upstream. The fix raises `NSInvalidArgumentException` (an `oo::Exception`)
exactly where 1.93 sent a dictionary method to a non-dictionary, so the script gets
`Native exception: …` under the same conditions:

- `OOJSMission.cpp`: `markSystem` and `unmarkSystem` raise when a marker converts to anything but a
  dictionary or null. Null still reads as the default (`nil` in 1.93), and markers before the bad
  one in the same call are still applied, as in 1.93.
- `OOMaterialConvenienceCreators.cpp`, `OOMaterial::materialWithName`: raises when the shaders
  dictionary is read (shaders on) or the materials dictionary is read (no shader entry for the
  material) and it is neither a dictionary nor null. The ship and visual-effect loaders already
  pass only a dictionary or null (`DictionaryForKey`), so only `Ship.setMaterials`/`setShaders`
  and `VisualEffect.setMaterials`/`setShaders` can reach it with anything else.
- As in 1.93, `setShaders([…])` with shaders off reads nothing and returns normally.

Test: `tests/component/test_dictionary_arguments_reject_arrays.py` (4 tests). Before the fix 3
failed (`markSystem`, `setMaterials`, `setShaders` returned normally; the control test that an
object marker still marks and unmarks passed); after, 4 passed. Shaders were on in that run.

Probe after the fix: 33 lines differ from `baseline-quickjs.txt`, all from rows 1–3 (31 path lines,
the shipyard, `system.info`); none of row 4's. Unit tier 221/221 (oofnd 40, core 179, headers 2);
component tier 24/24, including the new tests.

Commit `58d415268` on `seriesb/028-upstream-772-tests`, after the import (decision D4).

### JS tests: an intermittent player death (not the fix)

`tests/run_js_tests.py` sometimes stops at "Could not start the hyperspace countdown": the player
ship is `STATUS_DEAD` by then. The recorder shows `shipCollided["buoy"]` during the 10 s of flight
before the jump; missiles are spawned in the flight phase and the alert condition rises just before.
It happens without the fix too: 2 of 9 runs without it failed, against 10 of 13 with it (and the
one run with only the `OOJSMission.cpp` half). A build that
logs every time the new checks fire passed 2 of 3, and the checks never fired, so the JS tests do
not reach the changed code; the two rates are put down to timing. Follow-up F3.

Environment notes: in a new worktree `tests/run.sh` cannot create its venv (Pillow's wheel build
fails with `WinError 3`), so the runs used `OO_VENV=<oolite-dev>/build/.venv-tests`. Only
clang-format 23 is installed in MSYS2; the changed files were checked with clang-format 22.1.8 from
PyPI in a scratch venv (`.agent-tmp/cf22`), and it gives the same layout as 23 does for them.

### Follow-ups

- **F1** — Shipyard: get an upstream 1.93 Windows reference (official build with the debug console,
  or a probe run Jon makes) and check whether it shows Python, Python.
- **F2** — For row 4, check every native that converts an argument with
  `cxx_OOJSPListFromJSObject` and then reads keys: the sweep only passes one array, so other
  callers with the same pattern may differ in ways the probe does not reach.
- **F3** — The intermittent player death above: find out what the player hits (buoy, missile) at
  16x and whether upstream's harness sees it on Linux. Until then a JS-tier failure at the
  arrived phase is re-run once before it counts.
