# Phase 4 — Remove the Objective-C runtime

**Status:** done on `main`; reviewed 2026-10-21 ([Review (oo-6pad)](#review-oo-6pad), no gap filed); exit gate oo-lqd's eight acceptance lines green on 3fa41ff7c and again on 4819d144d, closes behind the review · **Est.:** 1–2 eng-months · **Depends on:** [Phase 3](3-cpp-conversion.md)

## Goal

Delete `AutoreleaseScope`, drop `libobjc2` and every `-fobjc-*` flag, rename `.mm` → `.cpp`, restore
the GCC (MINGW64) build alongside Clang (UCRT64). Nearly mechanical if Phase 3 was disciplined.

## Entry gate

- [x] Phase 3 exit gate green (zero `@implementation`) — oo-o8x closed behind review oo-r7fo
- [x] Renderer target is GL 3.3 Core (decided, ADR-0013); pull the Phase 6 renderer work forward if Apple has removed legacy GL by now (Phase 5 needs it) — not pulled forward ([ADR-0004](../decisions/0004-legacy-gl-until-phase-6.md): legacy GL until Phase 6)

## Exit gate

- [x] No `.mm` files; no `-fobjc-*` in any build line; `libobjc2` gone from all platforms — oo-lqd lines 1, 2, 5, 6
- [x] GCC (MINGW64) build green alongside Clang (UCRT64) — oo-lqd line 4 (the GCC flavour is UCRT64's g++ by [ADR-0063](../decisions/0063-gcc-flavour-and-gcc-only-diagnostics.md) item 1, not a MINGW64 environment)
- [x] Goldens reproduce on Windows; ASan clean — oo-lqd line 3 (Clang) and line 4 (the GCC game plays the same goldens)
- [x] Cross-platform golden policy (decision 11) implemented on Windows, since Phase 5 adds the first other platforms — oo-lqd line 7 (`goldens/windows-x64/`, `tests/golden/test_golden_storage.py`)

## Notes

This is the last phase that runs entirely on the single Windows machine
([ADR-0010](../decisions/0010-single-windows-machine.md), [ADR-0017](../decisions/0017-native-windows-subtree.md)).
Its exit is the point at which the Mac and a Linux build environment join.

## Seams / sweeps

One mechanical pass. If it is not mechanical, something in Phase 3 was left undone; fix it there.

| Seam | Bead | What landed |
|---|---|---|
| 4.1 deferred release | oo-31u (.1, .6–.10) | No Objective-C autorelease left; the C++ pool `oo::AutoreleaseScope`/`oo::autorelease` is the game's deferred release by recorded default (ADR-0056 amendment oo-31u items 3–4: deleting it outright is a later, behaviour-changing decision for Jon) |
| 4.2 runtime and rename | oo-dbz (.1–.5), oo-4aq6a (.1–.13), oo-rskgl, oo-xu228, oo-cnhzq, oo-ua886, oo-2gi85, oo-6e1.1, oo-6e1.2 | Root classes, `OOException`, `@try`, `@selector`, `#import`, `@encode` (now `OOTypeEncodings.h`, generated), the libobjc2 floor tests; `.mm` → `.cpp`; no `objc`/`objcpp` language in meson |
| 4.3 GCC | oo-1q4 (.2, .3) | `tools/build-windows.sh --gcc`, ADR-0063/0064; the GCC game plays the blessed goldens |

## Review (oo-6pad)

**Date:** 2026-10-21 · **Reviewer:** Claude Fable 5.1 (bead oo-6pad) · **Tree:** `main` @ 4819d144d (the exit gate's own merge of an empty proof commit; `git diff 3fa41ff7c 4819d144d` is empty, so the gate's run and this review's are on the same tree; worktree `bead/oo-6pad`). Rule 7: every row is a command and its exit status, not a judgement. Heavy commands ran in the build pool (pool-1) at 4819d144d; logs in `.agent-tmp/cc/review4/`.

### Beads

`bd list --label phase:4 --all`: 52 beads, 49 closed, none escalated or deferred. Open: this review, the gate oo-lqd (in progress: every acceptance line exit 0 on 3fa41ff7c in its accept; bd refused the close only because this review blocks it) and the epic oo-6e1. Every closed bead has its `bead <id>: merge into main` commit on `main`'s first-parent line (49 of 49). The whole tracker has four open beads: these three and oo-b7hg (`phase:5`). No bead under the seams' id prefixes lacks `phase:4`; no open bead of any label names Phase 4, Objective-C, libobjc or GCC.

### Evidence table (every gate box and the goal's four items)

| Item | Evidence command | Result |
|---|---|---|
| Entry: Phase 3 gate | oo-o8x, oo-9ht closed (`bd list --label phase:3 --status open,in_progress`: 0) | PASS |
| Entry: GL target | ADR-0004 stands; no Phase 6 renderer bead pulled forward | n/a (decided) |
| Exit: no `.mm`, no `-fobjc-*`, no libobjc2 | gate lines 1–2 (`git ls-files` inventory = `GameController+FullScreen.mm` only; meson grep empty); line 5 in the pool on both built trees (`compile_commands.json`, `build.ninja`, `objdump -p` import tables, `check-foundation-free.sh --link`); line 6 (`check-foundation-free.sh --stage source`, `check-oofnd-objc.sh`) | PASS / PASS / PASS / PASS |
| Exit: GCC beside Clang | gate line 4 in the pool: `build-windows.sh --gcc test`, core 173/173, oofnd 39/39, goldens on the GCC game GREEN (2 blessed verified, 18 unblessed present, 17 s) | PASS |
| Exit: goldens, ASan | gate line 3 in the pool less the ASan stage: `build-windows.sh test`, core 173/173, oofnd 39/39, goldens GREEN (16 s). ASan: the gate's line 3 exit 0 on 3fa41ff7c, 2026-10-21 (`.agent-tmp/acceptq.log`; same tree, not re-run on a shared box) | PASS |
| Exit: golden policy on Windows | gate line 7: `test -d goldens/windows-x64`, `test_golden_storage.py` 20 passed | PASS |
| Goal: `AutoreleaseScope` | `grep -rnE 'AutoreleaseScope\|oo::autorelease\('` src: 51 live lines in 25 files, all the C++ pool; no `@autoreleasepool`/`objc_autorelease*`/`autorelease]` outside `#if OOLITE_MAC_OS_X` (oo-31u line 1 less the Mac arm) | kept by decision (ADR-0056 amendment oo-31u items 3–4; the deletion is Jon's) |
| Goal: libobjc2 and flags | as the exit row; `tools/setup-windows.sh` still installs libobjc2/gnustep-make for the GNUstep reference tools only (oo-ebds4, delegated 2026-10-19) | PASS |
| Goal: `.mm` → `.cpp` | `git ls-files 'oolite-dev/*.m' '*.mm'`: `src/Core/GameController+FullScreen.mm` (Phase 5) and seven files under `oolite-dev/tools/` (icosmesh, fonttexgen, JSErrorMunger: upstream's Mac-only tool sources, never built here) | PASS |
| Goal: GCC | as the exit row; `test_guardrails_pipefail.py`'s `grep -q` idiom that failed oo-31u's first tier-b (batch BG) is gone from `guardrails.sh` | PASS |
| Leftovers: Objective-C syntax in `.h/.hpp/.cpp/.c` | `grep -rnE '^\s*@(interface\|implementation\|protocol\|selector\|try\|catch\|...)\|@selector(\|@encode('` src+tests outside comments | only `#if OOLITE_MAC_OS_X` arms (`GameController.cpp` 85–90 and the `(MacOSX)` block 944–1253, `Universe.cpp:10449`, `OOMusicController.cpp:304`, `PlayerEntityLoadSave.cpp` 876/895 under `OOLITE_USE_APPKIT_LOAD_SAVE`) — Phase 5; and `OOCocoa.h:286`'s unused `OOLITE_OPTIONAL` macro (dead; no use in src or tests) |
| Leftovers: runtime symbols | `objc_*(`, `<objc/`, `sel_*`, `class_getName`, `IMP` outside comments | none; `oofnd/objc/` holds only `OOAssert.*`, `OOException.h`, `OOFoundationTypes.h`, `OOObject.h` (C types, no `@`) |
| Leftovers: `NS*` names | `NSString` etc. outside comments | the Mac arms above and oofnd's own Foundation-free headers' doc comments; `tools/cross/aarch64-apple-darwin.ini` still names `objc`/`objcpp` compilers (Phase 5's file) |
| Generator | `python3 tools/gen-stories.py --dry-run` (14 s) | every Phase 3/4 sweep 0 (renames, convert, slices, foundation); only the Phase 0 golden scenarios 002–020 "would file", as in reviews 1–3; no generator bead |
| Docs | header, ROADMAP row 4, `docs/decisions/README.md` | header said "not started", ROADMAP's row and focus were Phase 3's, the ADR index stopped at 0062: fixed in this bead |

### Re-run table (every seam + every closed phase:4 bead, acceptance blocks re-run on 4819d144d)

All 49 closed beads' blocks were re-run (not a sample): 160 cheap lines in the main checkout, the heavy lines once each in the pool (`build-windows.sh test`, `check-core-tests.sh`, oofnd suite, goldens, `--gcc` and its three suites, `tier-c.sh --only jsapi`, `check-string-expander.sh`, `check-sysdesc-tools.sh`, `plist_fuzz.py fuzz --count 2000`, oo-31u's `tier-b.sh`: all exit 0). Guardrails is this bead's own line.

| Bead(s) | Verdict | Note |
|---|---|---|
| oo-dbz, oo-dbz.1–.5, oo-4aq6a, oo-4aq6a.1–.9, .11–.13, oo-1q4, oo-1q4.2, oo-1q4.3, oo-xu228, oo-xu228.3, .3.1, .3.2, oo-rskgl, oo-ua886, oo-2gi85, oo-6e1.1, oo-6e1.2, oo-5ekxm, oo-ebds4, oo-l4f2h, oo-dxxt, oo-4d403, oo-8kdkl, oo-r3ffn, oo-31u.1, oo-31u.10 | PASS | every line exit 0 |
| oo-31u.6, oo-31u.7, oo-31u.8, oo-31u.9, oo-rskgl.1 | PASS / superseded | nine `grep -qF '…' X.mm` lines name a file oo-dbz.5 renamed; the same string is in each `X.cpp` (EntityHelpers, AI, OODrawable, OOMaterial, OOScript, OOTCPStreamDecoderAbstractionLayer, OOTexture, test_OOTexture, test_ResourceManager); oo-rskgl.1's `oofnd/objc/OOException.mm` was deleted by oo-4aq6a.1, whose line pins the same `throw oo::Exception` in `oofnd/Exception.cpp` |
| oo-31u, oo-cnhzq | PASS / superseded | one line each whose `.mm` exclusion (`OOMusicController.mm`) or `.cpp`-only scope stopped excluding the Mac arm once oo-dbz.5 renamed it: the only matches are `OOMusicController.cpp:304` (`NSAppleScript … autorelease`) and `GameController.cpp:63–66` (`#import`), both under `#if OOLITE_MAC_OS_X` (Phase 5); oo-31u's other lines and `tier-b.sh` exit 0 |

No block fails for a reason that survives the rename, so no bead is filed.

### Beads filed

None. Not filed, with the reason: the Mac-only Objective-C arms (Phase 5, oo-b7hg and ADR-0061's two `GameController` places); `OOCocoa.h`'s unused `OOLITE_OPTIONAL` macro and `instancetype` comment (dead text under no gate box; Phase 6 tidy-up); `oo::AutoreleaseScope` (kept by ADR-0056 amendment oo-31u, deletion is Jon's); golden scenarios 002–020 (open Phase 0 beads, as in reviews 1–3).

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §8 (Phase 4).
- 2026-10-18 — Seam 4.1 (oo-31u) decided on recorded default: the Objective-C pools go, the C++ pool `oo::AutoreleaseScope` stays as the game's deferred release (ADR-0056 amendment oo-31u, oo-31u.1).
- 2026-10-19/20 — std-2026-10-19 and ADR-0062 (Jon: "I approve ADR-0062") let the test re-bases and subject-deleted retirements land; oo-4aq6a's thirteen slices, oo-rskgl, oo-xu228, oo-cnhzq, oo-ua886, oo-2gi85, oo-6e1.1/.2 closed.
- 2026-10-20/21 — oo-dbz.1–.5: libobjc2, the `objc`/`objcpp` languages and every `-fobjc-*` flag left the build; `.mm` → `.cpp` (0560aa359). ADR-0063/0064 (GCC flavour, GCC-only diagnostics, `__PRETTY_FUNCTION__` spelling) decided on recorded defaults; oo-1q4: the GCC build compiles every target and its game plays the blessed goldens (903e52cbd).
- 2026-10-21 — Exit gate oo-lqd: eight executable acceptance lines, all exit 0 on 3fa41ff7c; merged as 4819d144d; close pending the review.
- 2026-10-21 — Review oo-6pad (Claude Fable 5.1, `main` @ 4819d144d): 52 beads, 49 closed, every merge commit on `main`; all 49 acceptance blocks re-run (cheap lines in the checkout, heavy lines in the pool: Clang and GCC builds, core 173/173 ×2, oofnd 39/39 ×2, goldens GREEN ×2, jsapi, expander, sysdesc, plist fuzz, tier-b); 11 lines superseded by oo-dbz.5's rename only; every gate box has executable evidence; no gap filed. Leftover Objective-C is the Mac-only arms (Phase 5) and one dead macro in `OOCocoa.h`.
