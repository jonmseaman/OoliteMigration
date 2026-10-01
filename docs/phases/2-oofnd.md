# Phase 2 — `oofnd` (Foundation replacement)

**Status:** in progress on `phase-2`; reviewed 2026-09-30 ([Review (oo-eipg)](#review-oo-eipg)); exit gate oo-ndo run green on 5d19dbbe0 2026-09-30 ([Exit gate (oo-ndo)](#exit-gate-oo-ndo)) · **Est.:** 6–10 eng-months · **Depends on:** [Phase 0](0-safety-net.md) exit
**Runs in parallel with:** [Phase 1](1-js-engine.md). **This is where GNUstep dies.**

## Goal

Switch the build to Objective-C++, build a C++20 Foundation replacement bottom-up with unit tests,
migrate every Foundation usage site onto it while the classes are still Objective-C, and delete
`libgnustep-base` from every platform. Only the Objective-C *runtime* remains. Design:
[architecture §3.4](../architecture.md); memory model: [ADR-0003](../decisions/0003-intrusive-refcount.md).

## Entry gate

- [ ] Phase 0 exit gate green
- [x] Decision 4 is `std::string` (ADR-0013). A benchmark story runs before the String seam lands: golden wall-clock before/after; > 5% regression escalates via the Reporter, otherwise proceed ([benchmark](2-string-benchmark.md), bead oo-lvj: +0.1%, confirmed)

## Exit gate

- [ ] All goldens reproduce
- [ ] `libgnustep-base` absent from the link line; deny-list enforces it
- [ ] `oofnd` old-style **and** XML plist parser/writer fuzzed against GNUstep with zero divergences on the corpus (contract C1) — evidence: [2-plist-fuzz-report.md](2-plist-fuzz-report.md)
- [ ] Every `oofnd` component has its own unit-test suite green under `meson test`
- [ ] Zero `oo_*ForKey:` call sites remain (`OOCollectionExtractors` retired)

## Seams

| Seam | Produces (exemplar path) | Owner |
|---|---|---|
| The `.m` → `.mm` switch: one atomic, behaviour-free commit (`.m` files with no `@implementation` become `.c`, per [ADR-0012](../decisions/0012-c-stays-c.md)) | the commit itself | Frontier agent; compiler-driven loop for the mechanical fixes |
| `Ref` / `WeakRef` / `RefCounted` / `AutoreleaseScope` | `src/oofnd/Ref.hpp` + tests | Frontier agent |
| `PList` + old-style and XML parser/writer | `src/oofnd/PList.hpp` + tests | Frontier agent |
| Typed accessor `PList::get<T>` and one fully migrated consumer | one file with zero `oo_*ForKey:` left | Frontier agent |
| String utilities, `FileSystem`, `Defaults`, `Logging`, `Data` | one migrated consumer each | Frontier agent |

The `PList` component as originally written scores 2/7 on the sizing rule: too big and unverifiable.
It must be split into stories with test-file acceptance (e.g. "old-style scanner: quoted strings and
`\U` escapes; `test_plist_oldstyle_strings.cpp` cases 1–14 go green") before any of it is dispatched.

## Sweeps

| Sweep | Unit | Inventory command | Exemplar | Est. stories | Ordering |
|---|---|---|---|---:|---|
| `OOCollectionExtractors` retirement | one file | `grep -rl 'oo_[a-zA-Z]*ForKey' src` | the migrated consumer | ~150 | after `PList::get` seam |
| Foundation → `oofnd` | one file | `grep -rl 'NSString\|NSDictionary\|NSArray' src` | per component | ~250–400 | in the order below |

Order for the Foundation sweep: `oomath` → `Core` leaf utilities → `Materials` → `oxp` →
`Scripting` → `Entities` → `Universe`.

## Work items

1. **Switch the build to Objective-C++.** Rename `.m` → `.mm`, `-x objective-c++`, `-std=c++20` ([ADR-0011](../decisions/0011-cpp20-then-cpp23.md)).
   Expect a few hundred mechanical fixes (`nil` vs `nullptr`, `class`/`new`/`delete`/`template` used
   as identifiers or selector parts, `id` in C++ contexts, `BOOL` conflicts, stricter enum/`void*`
   conversions). Do this as one atomic, reviewable commit — it must change no behaviour.
2. **Build `oofnd` bottom-up**, each piece landed with its own unit tests:
   - `Ref`/`WeakRef`/`RefCounted`/`AutoreleaseScope` (replaces `OOWeakReference`, `OOWeakSet`)
   - `PList` + old-style **and** XML plist parser/writer (replaces `OOPListParsing`,
     `OldSchoolPropertyListWriting`, `NSPropertyListSerialization`)
   - Typed accessors (retires `OOCollectionExtractors` — ~1,800 sites)
   - String utilities (retires the `NSString` categories, `OOStringParsing`, `OOStringExpander`,
     `OOEncodingConverter`)
   - `FileSystem`, `ResourcePaths`, `Data` (retires `NSFileManager`/`NSBundle`/`NSData` usage)
   - `Defaults` (retires `NSUserDefaults` + the two `Override` categories)
   - `Logging` (retires `OOLogging` — already mostly C-shaped)
3. **Migrate usage sites** from Foundation to `oofnd`, still inside Objective-C classes. Order:
   `oomath` → `Core` leaf utilities → `Materials` → `oxp` → `Scripting` → `Entities` → `Universe`.
4. **Delete `libgnustep-base`** from the dependency list. `libobjc2` (runtime only) stays.

The `.m` → `.mm` mechanical fixes are a compiler-driven loop (fix, rebuild, repeat), which a cheap
model does well because the compiler is the oracle. `oofnd` itself is frontier design work.
`OOCollectionExtractors` → `PList::get` retires ~1,800 call sites in one stroke: the highest-leverage
single change in the project, and pure design, not volume.

## Commands

From Phase 0. `meson test -C build --suite oofnd` for the library.

## Open decisions

- **4** — decided: `std::string`, with the threshold-gated benchmark story above (ADR-0013).

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §7.
- 2026-09-23 — Seam 2.4 (bead oo-u77): `oo::PList::get<T>`/`at<T>` (`src/oofnd/PListGet.hpp`) with OOCollectionExtractors' exact GNUstep conversions; sweeps bridge through `oo::PListView` (`src/Core/OOPListView.h`); exemplar `src/Core/Entities/OOWaypointEntity.mm`; recipe in `src/oofnd/README.md` "Migrating oo_*ForKey" (proposed ADR-0031).
- 2026-09-23 — Seam 2.5a (bead oo-lvj): decision-4 benchmark ([2-string-benchmark.md](2-string-benchmark.md), `tools/bench-string-copy.sh`). Value-semantics `std::string` copying where Objective-C copied: golden wall-clock +0.1% (paired median of 22 interleaved repetitions; noise floor ±15% per pair), 13 ms modelled CPU per golden pair. Deep copy on every `-retain`: +16.5% wall, so the String seam takes `string_view`/`const&`/moves where Objective-C retained. Decision 4 confirmed, not escalated.
- 2026-09-23 — Seam 2.5b (bead oo-dps): `oo::str` (`src/oofnd/String.hpp`, `Encoding.hpp`) reproduces GNUstep 1.31.1's string answers over UTF-8 `std::string` (case tables, composed-sequence matching, `-pathExtension`, libiconv transliteration to the five Windows code pages), pinned by digests of captured GNUstep output; exact `NSString` bridge `src/Core/OOStringBridge.h`; exemplar `src/Core/OOOXZManager.mm`; recipe in `src/oofnd/README.md` "Migrating NSString category calls" (proposed ADR-0034). `OOStringExpander`'s engine is a follow-up bead.
- 2026-09-23 — Seam 2.8 Logging (bead oo-qpb): `oo::log` (`src/oofnd/Log.hpp`) carries OOLogging's settings resolution, diagnostics, indentation and exact line layout, with a std::format `OO_LOG` front end; `src/Core/OOLogging.mm` is now its Objective-C shell; exemplar `src/SDL/OOSDLJoystickManager.mm`; recipe in `src/oofnd/README.md` "Migrating OOLog calls" (proposed ADR-0035). Latest.log of both blessed goldens byte-identical before/after (run-varying text masked).
- 2026-09-23 — oofnd components complete (seam 2.10, bead oo-rml): Ref/WeakRef/AutoreleaseScope (oo-qpa), PList value + old-style/XML parsers and writers (oo-075..oo-pig), PList::get + PListView bridge (oo-u77), strings/encoding (oo-dps), FileSystem/ResourcePaths/Data (oo-i9q), Defaults (oo-32f), Logging (oo-qpb), each with an exemplar consumer and a unit suite in tools/check-oofnd.sh. The Foundation sweep may fan out.
- 2026-09-23 — Foundation sweep recipe (beads oo-g7k5, oo-hi38, oo-ro7q): `src/oofnd/README.md` "Migrating Foundation usage (sweep:foundation)", proposed ADR-0043. C++ types inside a file; unique selectors take C++ types with nil-safe (zero-valid) method results; shared selectors keep `id` until a family bead (`tools/check-selector-types.py`); direct callers adapted at the call site via `OOFoundationBridge.h`; `oo::ObjCRef` for objects in std containers. Exemplars `OOVector` (oomath), `OORoleSet` (Core leaf), `OOBasicMaterial` (Materials); both blessed goldens verify.
- 2026-09-23 — Foundation sweep, batch 1 (48 beads: 16 done, 31 stops) -> ADR-0043 Amendment 1: transitional `cxx_`/`X+FoundationBridge` bridges for fan-out (exemplar OOColor, oo-tms0), Foundation categories and subclasses retire after their callers (dependencies recorded in beads), `oo::str::pointerDescription` and the path-component family (exemplar OOALSoundDecoder, oo-oz2y), NS typedefs count as NS types.
- 2026-09-23 — Foundation sweep, Materials/OXPVerifier/Debug batch (19 done, 20 stops) -> ADR-0043 Amendment 2: `oo::PList` carries mixed configurations exactly (Object nodes, single-precision reals); OOMaterialSpecifier (oo-hiis, bridged) and OOMultiTextureMaterial (oo-vpbt) as exemplars; Materials order; chunk beads for oo-vvxy; opaque C++ handles for OOTCPStreamDecoder's abstraction layer.
- 2026-09-23 — Foundation sweep, Core batch 2 -> ADR-0043 Amendment 2 items 15-18: floats written to disk are `PList::singleReal` (XML and defaults writers print `%0.7g`; oo-gj2i restores the joystick text); the saved-game writer moves to `oo::writeXMLPList`; Foundation enumerator subclasses become C++ iteration; OOLogging / OOCheckOpenGLErrors bridged; 12 oversized files split into chunk beads.
- 2026-09-23 — ADR-0043 Amendment 3: `oo::str::formatRuntime` formats DESC / plist-template format strings (%@, %p, positional) as GNUstep did, pinned against captured output; OOOXPVerifier (oo-hkvv) is its exemplar. GuiDisplayGen's last chunk split (5a oo-3rb.165, 5b oo-3rb.96 after PlayerEntity's cxx_markedDestinations, oo-3rb.164).
- 2026-09-23 — Entities wave (24 done, 9 stops) -> ADR-0043 Amendment 3 items 21-24: selectors called by name are shared (check-selector-types.py finds them); live containers through pointer accessors; error-log collection text may change; runtime DESC formats via formatRuntime (oo-3rb.171).
- 2026-09-29 — One-time guardrails waiver for the phase-2 → main merge (bead oo-3rb.328; Jon, in chat: "Just override the rule for this one. The change is good."). `tools/guardrails.sh` is NOT changed. Over the aggregate range `$(git merge-base phase-2 main)..phase-2` (base 6b4694ffb, evidence `.agent-tmp/p2exit/guardrails-mainbase.log`) its "a change may not approve itself" checks fire only because each approval and the change it approves landed in separate commits of the same phase; Jon waives exactly these five findings, and nothing else: (1) `goldens/windows-x64/001-launch-dock/provenance.json` and (2) `goldens/windows-x64/001-launch-dock/state.json` — re-bless approved in 0ab0c0342 (oo-pabc, `tools/rebless-approvals.txt`), applied in 04e034ee9 (oo-3rb.256); (3) `upstream/oolite/tests/unit/game/meson.build` and (4) `upstream/oolite/tests/unit/game/test_defaults_bridge.mm` — ADR-0049 retirement approved in 770e04a3f (oo-soac, `tools/retire-test-approvals.txt`), deleted in 3299b8fd0 (oo-iobt); (5) `upstream/oolite/tests/unit/test_enumeration_shuffle.c` — ADR-0049 retirement approved in 75a904e5b (oo-1osf), deleted in c1ac638ad (oo-qps.7). The waiver covers only the phase-2 → main merge range: `bash tools/guardrails.sh --base "$(git merge-base HEAD main)"` is dropped from the exit gate oo-ndo's acceptance, and every other guardrails run (per bead against phase-2, the deny-list and suppression checks, and any later range or phase) is unaffected. Any further self-approval finding, or any of these paths changed again, is not covered.

## Review (oo-eipg)

**Date:** 2026-09-30 · **Reviewer:** Claude Fable 5.1 (bead oo-eipg) · **Tree:** `phase-2` @ 4fc7e1887, detached worktree, `BEADS_WORKER_BASE_BRANCH=phase-2` except where noted. Rule 7: every row is a command and its exit status, not a judgement. Logs: `.agent-tmp/cc/p2review/`.

### Evidence table (every work item and gate box)

| Item | Evidence command (review worktree) | Result |
|---|---|---|
| Entry: Phase 0 exit green | ROADMAP Phase 0 row; Phase 0 gate bead closed | done |
| Entry: decision 4 = `std::string`, benchmark | oo-lvj closed; [2-string-benchmark.md](2-string-benchmark.md) (+0.1%) | done |
| Exit: all goldens reproduce | `tools/tier-c.sh --only goldens` | GREEN 68 s: 001 MATCH, 001-launch-dock MATCH (2 blessed verified, 18 unblessed present). Full `tier-c.sh` is the gate's own line |
| Exit: `libgnustep-base` absent from the link line | `bash tools/check-foundation-free.sh --link upstream/oolite/build/meson_test/oolite.app/oolite.exe` after `tools/build-windows.sh test` (309 s, ccache 90%) | OK: oolite.exe and its local DLLs import no gnustep-base (35 DLLs); `objdump -p ... \| grep -iE 'DLL Name:.*gnustep'` = 0 (imports: libobjc-4.6, libstdc++-6, ICU, SDL deps only) |
| Exit: deny-list enforces it | `grep -qF '[-]lgnustep-base' tools/deny-list.txt`; `! git grep -nE gnustep-base -- upstream/oolite/src/meson upstream/oolite/src/meson.build upstream/oolite/meson.build tools/setup-windows.sh upstream/oolite/ShellScripts/Windows/install_deps.sh`; tier-b wiring greps for `--stage source` and `--link` | PASS / PASS (empty) / PASS |
| Exit: plist parsers fuzzed vs GNUstep, zero divergences | `grep -q '^Unexplained divergences on the Tier-3 corpus: 0$' docs/phases/2-plist-fuzz-report.md`; `python3 tools/plist_fuzz.py selftest` | PASS / PASS. Not re-fuzzed: the oracle links gnustep-base, which oo-qps.18 unlinked (oo-ndo notes caveat) |
| Exit: every `oofnd` component has a green unit suite | `bash tools/check-oofnd.sh` (inventory asserts tests/unit/oofnd/meson.build registers every test file; plain + ASan) | PASS: 25 headers canary-clean; 37 test files, 353 tests, 4,856 checks, green plain and under ASan (memoised digest 27fea14b..., green at 2026-09-30T17:29Z on this tip) |
| Exit: zero `oo_*ForKey:` sites, OOCollectionExtractors retired | `! test -e src/Core/OOCollectionExtractors.{h,mm}`; the gate's message-send/@selector grep outside src/oofnd, comments excluded | PASS / PASS (empty) |
| Work item 1: `.m` -> `.mm` switch | `git ls-files upstream/oolite/src \| grep -c '\.m$'` | 0 `.m`, 233 `.mm`, 6 `.c` (oo-x7o closed) |
| Work item 2: `oofnd` bottom-up with unit tests | `ls src/oofnd/*.hpp` (25 headers); 45 test files under tests/unit/oofnd; every seam bead (oo-qpa, oo-075..g2k, oo-u77, oo-dps, oo-i9q, oo-32f, oo-qpb, oo-fde, oo-rml) closed | done (suite result: the check-oofnd row) |
| Work item 3: every Foundation usage site migrated | `bash tools/check-foundation-free.sh --stage source` (the absolute census, ADR-0054); `--selftest` | 0 findings, 7 s / PASS 690 s. All sweep, chunk, bridge, endgame, family and extractor beads closed (940 Phase 2 beads, 933 closed) |
| Work item 4: `libgnustep-base` deleted from the dependency list | as the link-line rows; oo-qps.18 closed; only `libobjc-4.6.dll` remains | done. oo-qps itself was still open with the generated `exit 1` acceptance: replaced with the executable plan from its notes (see beads below) |
| Guardrails, per bead (base `phase-2`) | `bash tools/guardrails.sh` in the sampled beads' blocks | PASS in every sampled bead |
| Guardrails, whole phase vs `main` (base 6b4694ffb, 1,087 commits) | `bash tools/guardrails.sh` without BEADS_WORKER_BASE_BRANCH | FAIL 568 s: the five findings Jon waived on 2026-09-29 (oo-3rb.328) **plus 15 deny-list findings the waiver does not cover** (comments, docstrings, selftest fixtures, the ADR-0052 harness block) -> oo-3rb.345 (human) |
| `tools/guardrails-selftest` | run | 29/54 sections PASS, 0 FAIL after 2.5 h on a contended box when this was written; accept.sh ran it green on oo-qps.19's merge today, two merges before this tip, and it is oo-ndo's own line |
| `bash tools/check-file-modes.sh` / `bash tools/check-desktop-lock.sh` | run | PASS 65 s / PASS 79 s |
| Docs: status log, ROADMAP, ADR index | read | status log complete through the waiver; the doc header said "not started" and ROADMAP's "current focus" was Phase 0 (fixed in this bead); `docs/decisions/README.md` indexes through 0057 |
| Leftovers grep: TODO/FIXME added in the phase | `git diff main...HEAD -- upstream/oolite/src tools` filtered for added TODO/FIXME/XXX | none |
| Leftovers: dead `cxx_` helpers | every `cxx_*` name occurring once in `upstream/oolite/src` | none dead: `+[ResourceManager cxx_writeDiagnosticPList:]` is used (OOMaterialConvenienceCreators.mm:281,284); the single-occurrence names are docs, two key constants and a debug method |
| Leftovers: `NSDate` outside oofnd (orchestrator note on oo-qps) | `grep -rlE NSDate upstream/oolite/src` minus oofnd | 2 files: OOStringExpander.mm:352-354 inside the `OO_EXPANDER_TEST_SURFACE` block (ADR-0052, fenced from the census) and a comment at OOJavaScriptEngine.mm:1480 |
| `tools/gen-stories.py --dry-run` | run | emits only the golden-scenario listings; no Phase 2 work the generator should have produced is missing, so no generator-bug bead |

### Closed-bead spot audit

Each block re-run line by line on the review tree; build lines share the one build above (BUILD-SHARED), tier lines are the gate's (DEFERRED). A FAIL would be a regression bead.

| Bead | Kind | Verdict | Lines re-run (result) |
|---|---|---|---|
| oo-0aes | sweep:extractors | PASS |  L1:PASS(0s) L2:BUILD-SHARED L3:PASS(72s) L4:PASS(46s) |
| oo-0f7h | sweep:foundation-bridge | PASS |  L1:PASS(0s) L2:PASS(0s) L3:PASS(0s) L4:PASS(0s) L5:BUILD-SHARED L6:PASS(21s) |
| oo-19g0 | sweep:foundation | PASS |  L1:PASS(0s) L2:BUILD-SHARED L3:PASS(88s) L4:PASS(17s) |
| oo-1hvf | sweep:foundation-bridge | PASS |  L1:PASS(1s) L2:PASS(0s) L3:PASS(1s) L4:BUILD-SHARED L5:PASS(71s) |
| oo-32f | seam:2.7 | PASS |  L1:PASS(616s) L2:PASS(0s) L3:PASS(0s) L4:BUILD-SHARED L5:PASS(35s) |
| oo-3rb.258 | sweep:selector-family | PASS |  L1:PASS(7s) L2:PASS(3s) L3:BUILD-SHARED L4:PASS(53s) |
| oo-3rb.270.2 | sweep:selector-family | PASS |  L1:PASS(1s) L2:PASS(1s) L3:BUILD-SHARED L4:PASS(49s) |
| oo-3rb.289.13 | sweep:selector-family | PASS |  L1:PASS(2s) L2:PASS(1s) L3:PASS(1s) L4:BUILD-SHARED L5:PASS(43s) |
| oo-3rb.328 | fleet | PASS |  L1:PASS(0s) L2:PASS(4s) L3:PASS(66s) |
| oo-3rb.330 | fleet | PASS |  L1:PASS(1s) L2:PASS(11s) L3:PASS(2s) L4:PASS(89s) |
| oo-3rb.331 | fleet | PASS |  L1:PASS(134s) L2:PASS(109s) L3:DEFERRED-TIER L4:DEFERRED-TIER L5:PASS(1s) L6:PASS(65s) |
| oo-3rb.335 | epic,fleet | PASS |  L1:PASS(83s) L2:PASS(36s) L3:PASS(170s) |
| oo-3rb.4 | epic,frontier | PASS |  L1:PASS(1s) L2:PASS(1s) L3:PASS(1s) L4:PASS(1s) L5:PASS(3s) L6:BUILD-SHARED L7:PASS(61s) L8:PASS(79s) |
| oo-3yh0 | sweep:foundation | PASS (tier-a PASS but over its 120 s budget on a contended box) |  L1:PASS(1s) L2:BUILD-SHARED L3:FAIL-rc1(385s) L4:PASS(193s) |
| oo-diow | sweep:foundation | PASS (tier-a PASS but over its 120 s budget on a contended box) |  L1:PASS(1s) L2:BUILD-SHARED L3:FAIL-rc1(217s) L4:PASS(653s) L5:PASS(180s) |
| oo-dps | seam:2.5b | PASS / superseded (L3 spelling oo::StringMap(...) deleted by oo-qps.16; call is now direct oo::str::trimLeadingWhitespaceAndNewlines; L5 tier-a PASS over budget, contended) |  L1:PASS(36s) L2:PASS(2s) L3:FAIL-rc1(6s) L4:BUILD-SHARED L5:FAIL-rc1(532s) L6:DEFERRED-TIER L7:PASS(198s) |
| oo-ffi5 | sweep:foundation | PASS (tier-a PASS but over its 120 s budget on a contended box) |  L1:PASS(5s) L2:BUILD-SHARED L3:FAIL-rc1(234s) L4:PASS(156s) |
| oo-g7k5 | sweep:foundation | PASS (tier-a PASS but over its 120 s budget on a contended box) |  L1:PASS(7s) L2:BUILD-SHARED L3:FAIL-rc1(238s) L4:PASS(205s) |
| oo-hiis | sweep:foundation | PASS (tier-a PASS but over its 120 s budget on a contended box) |  L1:PASS(6s) L2:BUILD-SHARED L3:FAIL-rc1(205s) L4:PASS(112s) |
| oo-hkvv | sweep:foundation | PASS (tier-a PASS but over its 120 s budget on a contended box) |  L1:PASS(2s) L2:BUILD-SHARED L3:FAIL-rc1(264s) L4:PASS(208s) |

Sampled 20 of 933 closed beads (alphabetical from 43 selected across seams, sweeps, families, bridges and the endgame; stopped at 20 to free the box). 7 `tier-a.sh` lines returned nonzero only for exceeding their 120 s budget (`tier-a: PASS but N s exceeds the 120s budget`); no deny-list, warning or compile finding. The 23 selected but not re-run are covered by the gate-level rows above.

### Open Phase 2 beads at review time and the exit gate

| Bead | State | Blocks oo-ndo? | Action |
|---|---|---|---|
| oo-qps (seam 2.12) | open with the generated `exit 1` acceptance although oo-qps.1-.74 are closed | yes | acceptance replaced with the executable plan from its 2026-09-24 notes (tier-c left to oo-ndo); every line passes here; needs `accept` |
| oo-3rb.329 | open: regenerate the fleet report right before the gate | yes | unchanged; run last by design |
| oo-3rb.333 | in_progress: G5 flake in a full GUI session | yes | unchanged |
| oo-3rb.336 | open; was an `epic` with no acceptance or gate edge | now yes | acceptance set (3x G8 under gui-tier.sh); gate edge added |
| oo-3rb (epic) | open | parent | closes with the gate |
| oo-49qqu (human) | open: ratify the test_OOShipGroup.mm cast (oo-3kqi) | no | Jon-owned |

### Beads filed (all `--parent oo-3rb`, label `sweep:review-2`)

| Bead | Label | What | Gate dep |
|---|---|---|---|
| oo-3rb.345 | human, P1 | guardrails deny-list over phase-2..main: 15 findings outside the oo-3rb.328 waiver; recommended default: extend the one-time waiver (Jon, in chat) and log it here; alternative: a comment/fixture-aware deny-list stage | **yes** |
| oo-3rb.337 .. .343 | human, proposed-adr | ratify ADR-0043 (+Amendments 1-3), 0051, 0052, 0053, 0054, 0055, 0057, each with its recommended default (accept as written) | no (ADR-0030) |
| oo-3rb.344 | human, proposed-adr | ratify the other 22 Phase 2 proposed ADRs (0026-0029, 0031-0042, 0044-0048, 0050) in one pass | no |
| oo-3rb.346 | fleet, P4 | repo-root harvest debris (X.txt, SMOKE_OK.txt, acceptance-block.txt, `~`, .oo-izi-*) | no |
| oo-3rb.347 | fleet, P3 | src/oofnd/README.md recipes still instruct `#import` of the deleted bridge headers | no |

### Verdict

Every work item and exit-gate box has passing evidence on the tree. Phase 2 is ready for oo-ndo once oo-qps (now acceptable), oo-3rb.345 (Jon), oo-3rb.333/336, oo-3rb.329 (last) and this review close.

## Exit gate (oo-ndo)

**Date:** 2026-09-30. **Tested commit C:** `5d19dbbe02c2cdd10a68fbb6b05f2603b864af25` (phase-2 tip
0f6d10e2a after oo-3rb.329 merged, plus one docs-only commit refreshing `docs/fleet/REPORT-2026-09-30.md`
because phase-3 planning filed beads during the first run). Every line of oo-ndo's acceptance block was
run in a detached worktree of C (`.worktrees/p2-gate`) from the MSYS2 UCRT64 login shell with
`BEADS_WORKER_BASE_BRANCH=phase-2`, as accept.sh runs it. Logs: `.agent-tmp/p2gate/r3-NN.log` (line NN),
`r3t2-01.log` (the green Tier C); results tables `r3-results.tsv`, `r3t2-results.tsv`.

| # | Line | Result | Wall |
|---|---|---|---|
| 1-3 | oo-eipg, oo-qps, oo-snzn status = closed | PASS | 9 s, 3 s, 2 s |
| 4 | `bash tools/guardrails.sh` | PASS | 13 s |
| 5 | `tools/guardrails-selftest` (119 cases) | PASS | 3073 s |
| 6 | `bash tools/check-file-modes.sh` | PASS | 26 s |
| 7 | `bash tools/check-desktop-lock.sh` | PASS | 20 s |
| 8 | `tools/build-windows.sh test` | PASS | 27 s |
| 9 | `check-foundation-free.sh --link .../oolite.exe` | PASS | 21 s |
| 10 | no `gnustep` DLL import in `objdump -p oolite.exe` | PASS | 3 s |
| 11 | no `gnustep-base` in meson files / setup scripts | PASS | 4 s |
| 12 | `check-foundation-free.sh --selftest` | PASS | 123 s |
| 13 | `check-foundation-free.sh --stage source` | PASS | 9 s |
| 14 | tier-b wires `--stage source` and `--link` | PASS | 1 s |
| 15 | deny-list carries `[-]lgnustep-base` | PASS | 2 s |
| 16 | `OOCollectionExtractors.{h,mm}` absent | PASS | 1 s |
| 17 | zero `oo_*ForKey:` call sites outside `src/oofnd` | PASS | 4 s |
| 18 | `bash tools/check-oofnd.sh` | PASS | 5 s |
| 19 | fuzz report: `Unexplained divergences on the Tier-3 corpus: 0` | PASS | 1 s |
| 20 | `python3 tools/plist_fuzz.py selftest` | PASS | 1 s |
| 21 | `bash tools/tier-c.sh` | PASS on attempt 2: GREEN in 1823 s (tier-b 966 s, jsapi 2 s, asan 359 s, goldens 25 s with 2 blessed verified, corpus 36/36 in 296 s, gui 179 passed in 173 s, fleetdata 1 passed) | 1824 s |

Flake record: Tier C attempt 1 on C (and the earlier run on 0f6d10e2a) went RED in its tier-b stage on a
60 s `TimeoutExpired` in `tools/test_tier_c_diff.py` (`tier-c-diff.sh --report-only` under tier-b shard
load; 24 s for the whole file standalone). It recurred, so it is filed as oo-3rb.349; it does not block the
gate. Not counted: a first run whose harness leaked `OO_GUARDRAILS_BASE=phase-2` into
`guardrails-selftest`'s scratch repositories (`.agent-tmp/p2gate/r1-aborted/`), which accept.sh never sets.

Since C, only `docs/` changes (this record and a fleet-report refresh); oo-ndo's stored acceptance is the
fast proof of that (`git diff --quiet 5d19dbbe0 HEAD -- upstream tools`) plus the static checks.
