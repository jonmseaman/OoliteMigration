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
| 4 | 4 | Method sweep, array argument `[1, 2]`: `Ship.setMaterials`, `Ship.setShaders` → `ok:boolean`, `Mission.markSystem` → `ok:undefined`, `Mission.unmarkSystem` → `ok:boolean`; reference `Error:Native exception` for all four | **migration** | Upstream converts the array to an `NSArray` and sends it a dictionary method (`oo_intForKey:` in `OOJSMission.m` `MissionMarkSystem`); the unrecognised selector raises an Objective-C exception, which `OOJS_NATIVE_EXIT` turns into a script error. The C++ port's `oo::PList::get<int>("system", -1)` (`OOJSMission.cpp` `MissionMarkSystem`) returns the default for an array, so the call succeeds silently. The other three follow the same pattern (to be confirmed per method). | Jon: match upstream (scripts get an error) or document as a deliberate difference. Default proposed: match upstream, since an OXP that passes an array gets an error on 1.93 |

No other differences. Against the macOS output (`baseline-quickjs-macos.txt`) the same rows appear,
plus one float formatting difference (`player.ship.collisionRadius` `72.697342` vs `72.69735`)
where the C++ build matches Linux.

### Follow-ups

- **F1** — Shipyard: get an upstream 1.93 Windows reference (official build with the debug console,
  or a probe run Jon makes) and check whether it shows Python, Python.
- **F2** — For row 4, check every native that converts an argument with
  `cxx_OOJSPListFromJSObject` and then reads keys: the sweep only passes one array, so other
  callers with the same pattern may differ in ways the probe does not reach.
