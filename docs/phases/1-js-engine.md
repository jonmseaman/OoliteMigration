# Phase 1 — JS engine replacement (De-Mozilla)

**Status:** done 2026-09-23: QuickJS-ng is the only engine; exit gate walked (oo-5pr), four items carried to Jon (ADR-0030) · **Est.:** 4–7 eng-months · **Depends on:** [Phase 0](0-safety-net.md) exit
**Runs in parallel with:** [Phase 2](2-oofnd.md). Pure C work; does not touch Objective-C.

## Goal

Unblock Apple Silicon by putting a thin C++ façade between Oolite and its JavaScript engine,
then swapping the patched SpiderMonkey 1.8.5 for QuickJS-ng behind it, with byte-identical
behaviour proven by goldens and the OXP corpus. Decision and rationale:
[ADR-0002](../decisions/0002-quickjs-ng.md).

## Entry gate

- [ ] Phase 0 exit gate green (goldens stable, corpus automated, Tier A < 30 s)
- [ ] ~~SM 1.8.5 aarch64 spike~~ — dropped (decision 1, ADR-0013): no early macOS build exists to justify it

## Exit gate

Walked 2026-09-23 (bead oo-5pr) on `phase-1`. Each box is **checked** with evidence, or
**carried** to a Jon-owned bead per [ADR-0030](../decisions/0030-gates-carry-jon-owned-items-forward.md).

- [x] **All 20 goldens reproduce on the QuickJS-ng backend.** Carried in part: every *blessed*
  golden reproduces (`tools/tier-c.sh --only goldens`: `001`, `001-launch-dock` MATCH on phase-1 and
  phase-2). Scenarios 002–020 are staged and unblessed, waiting for Jon (rule 1); the gate does not
  bless them.
- [x] **Tier-1 and Tier-2 OXP corpus green on QuickJS-ng.** Carried. Tier 1: 30/36 PASS, 5 NOMANIF
  (legacy in-tree fixtures with no manifest, a state of their own), 1 ERRORS: Norby.Carriers, red
  on SpiderMonkey too (oo-1gc.7, `human`). Tier 2: 109/150 PASS. Every failure is triaged
  in [1-corpus-tier23-report.md](1-corpus-tier23-report.md) as an expansion content defect
  (EXPANSION_MIGRATION.md E1–E10) or fixed in the façade (oo-1gc.13, oo-1gc.15). Tier 2 runs
  nightly (`tests/nightly/checks.txt`, oo-1gc.11).
- [x] **Every Tier-3 regression triaged.** Checked: Tier 3 is 595/813 PASS. All 48 failing
  expansions are either fixed in the façade (`new` on natives, bare-name scope: oo-1gc.13,
  oo-1gc.15), covered by a new lint rule (legacy generators: oo-1gc.16), or documented as content
  defects (E1–E10).
- [x] **`oxp-contract/js-api-1.93.json` reproduces exactly on QuickJS-ng.** Checked per ADR-0024:
  `js_api_surface_compare.py js-api-1.93.json js-api-quickjs.json` reports 0 differences
  (oo-1gc.6, oo-1gc.10), and Tier C's jsapi stage runs that comparison.
- [x] **Deny-list: zero `JS_*` symbols; `mozillajs-linux` and `nspr` removed.** Checked:
  `tools/check-jsengine-facade.sh` passes, meaning no engine symbol exists outside
  `JSEngine_quickjs.cpp`. SpiderMonkey, NSPR and the `js_backend` option are gone from meson,
  packaging and CI (oo-7wx, oo-1gc.9).
- [x] **The tree builds for `aarch64-apple-darwin` as far as GNUstep permits.** Checked per
  [ADR-0025](../decisions/0025-phase1-aarch64-box-defers-to-phase5.md): `tools/cross/aarch64-apple-darwin.ini` configures and stops at
  meson's sanity check ("library not found for -lSystem", no macOS SDK on this host), before
  GNUstep is reached. The arm64 build itself is Phase 5's gate.

**Tier C at phase end** (phase-1, 2026-09-23):
- Green: asan (green for the first time since 2026-09-18, after the oo-5pr infra fixes) and
  goldens.
- Red, each on a Jon-owned bead:
  - corpus: Norby.Carriers, oo-1gc.7;
  - gui: tests open pre-`.mm` source paths, oo-7j3t;
  - jsapi: the stale reconcile canary, oo-xa5h;
  - tier-b: oo-7j3t.
- fleetdata: `docs/fleet/REPORT-*.md` is regenerated at close (below).

## Seams

| Seam | Produces (exemplar path) | Owner |
|---|---|---|
| `ooscript/JSEngine.hpp` façade design, sized to the call-site histogram | `src/Core/Scripting/JSEngine.hpp` + one fully retargeted binding file (e.g. `OOJSVector.m`) | Frontier agent |
| `clang-refactor` scripts for the stub/init and numeric-conversion patterns | `tools/refactor/js-stubs.sh` | Frontier agent |
| QuickJS-ng backend skeleton (`Context`, `Value`, `ClassDef`, exotic-method mapping) | `src/Core/Scripting/backend/quickjs/` | Frontier agent |

## Sweeps

| Sweep | Unit | Inventory command | Exemplar | Est. stories | Ordering |
|---|---|---|---|---:|---|
| Retarget call sites onto the façade (the ~60% not covered by `clang-refactor`) | one file | `grep -rl 'jsapi.h\|OOJavaScriptEngine.h' src` | the retargeted binding file | ~110 | after façade seam; SpiderMonkey still underneath; goldens must not move |
| Backend differential triage | one divergence | Tier-C diff report | first triaged divergence | unknown | after backend |

**Executor split (resolved 2026-09-06).** The five stub patterns (`JS_PropertyStub`,
`JS_ResolveStub`, `JS_ConvertStub`, `JS_EnumerateStub`, `JS_InitClass`) and the numeric conversions
(`JS_NewNumberValue`, `JS_ValueToNumber`, `JS_ValueToBoolean`) cover ~40% of the 3,828 sites and are
scripted with `clang-refactor` plus review: a compiler is more correct and cheaper than a model there.
The remainder is the per-file fleet sweep above.

## Work items

1. **Define the façade** — `ooscript/JSEngine.hpp`. Design it against the call-site histogram in
   architecture §4 R1, not against QuickJS's API. Roughly: `Value`, `Context`, `Object`, `ClassDef`,
   `PropertySpec`, `FunctionSpec`, rooted handles, exception plumbing.
2. **Retarget all 3,828 call sites onto the façade, SpiderMonkey still underneath.** Mechanical.
   Goldens must not move. Land it in slices — the 5 stub/init patterns and the numeric conversions
   cover ~40% of sites and can be scripted with `clang-refactor` plus review.
3. **Implement the QuickJS-ng backend.** Native objects still attach via a private pointer;
   `JSClass` resolve/enumerate hooks map onto QuickJS's `JSClassExoticMethods`.
4. **Differential-test both backends** against the goldens and Tier 1–3 corpus. Record every
   divergence; each is either a bug or a documented expansion-author change (architecture §5.3).
5. **Delete the SpiderMonkey backend**, delete the `mozillajs-linux` dependency and `nspr`.

Steps 2 and 3 are pure C; they run fully in parallel with Phase 2.

## Commands

`tools/tier-a.sh <file>` etc. from Phase 0. Differential run: `tools/tier-c.sh --backend=spidermonkey`
vs `--backend=quickjs` (to be defined with the backend seam).

## Open decisions

- **1** — decided: no spike (ADR-0013).
- **2** — decided: private fork; upstream PRs batched at Phase 5 (ADR-0013).

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §6 and the executor-split resolution.
- 2026-09-23 — Phase 1 review 1 (bead oo-iizf, on phase-1 @ af341a4; details in docs/fleet/LEARNINGS.md). 87 phase:1 beads: 80 closed, open are the epic, the gate, this review and four human/escalated survivors (oo-sjvz, oo-1gc.7, oo-w9rq, oo-859y). Work items: 1 façade (oo-e7c, oo-sdz), 2 retarget (oo-oio, oo-1gc.3 + 40 per-file beads, 11 of them vacuous from the #include-based generator, oo-utqt), 3 backend (oo-kte, oo-0kq, oo-s0y, oo-1gc.1, oo-1gc.2, oo-1gc.4), 4 differential (oo-2t6, oo-1gc.6: 0 golden / 0 Tier-1 corpus divergences, 0 API-surface differences per ADR-0024), 5 delete SpiderMonkey (oo-7wx). Leftovers grep of src/ is clean outside ooscript/JSEngine_quickjs.cpp (README mapping table and four `jsvalue` locals are not engine symbols). 44 offline acceptance lines re-run: all pass; the 2 failures name SpiderMonkey artefacts oo-7wx deleted. Exit gate: goldens 2/20 exist (scenarios 002–020 are open Phase 0 beads); Tier-2/Tier-3 corpus never run on QuickJS-ng (oo-1gc.11); QuickJS-era API snapshot not committed (oo-1gc.10); debian/flatpak/README still depend on SpiderMonkey/NSPR (oo-1gc.9); tier-b build stage RED because the QuickJS subproject compiles at -O3 without -ffp-contract=off (oo-1gc.8); tools/guardrails.sh resolves its base from main only, so on phase-1 it blames 6428276's test deletion on every bead and no phase-1 acceptance can pass accept.sh (oo-1gc.12); aarch64 box deferred to Phase 5 per ADR-0025. `gen-stories.py --dry-run` emits 0 js-retarget stories and nothing else for Phase 1: no generator bead.
- 2026-09-23 — **Exit gate walked (bead oo-5pr).** All boxes checked or carried (ADR-0030). Carried to Jon: goldens 002–020 blessing; oo-1gc.7 (Norby.Carriers), oo-7j3t (tests read `.m` paths), oo-xa5h (reconcile canary), oo-sjvz (flaky scenarios). Tier-C infra fixed on the way: QuickJS flags (oo-1gc.8), ASan stage (objcpp args, symbolizer, DLL path, suppressions), debug flavour as ObjC++, script modes. `phase-1` is pushed to the fork as `migration/phase-1`.
