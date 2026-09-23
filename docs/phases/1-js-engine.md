# Phase 1 — JS engine replacement (De-Mozilla)

**Status:** work items 1–5 landed on QuickJS-ng; review 1 done (2026-09-23), exit gate oo-5pr pending behind oo-1gc.8–.11 · **Est.:** 4–7 eng-months · **Depends on:** [Phase 0](0-safety-net.md) exit
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

- [ ] All 20 goldens reproduce on the QuickJS-ng backend
- [ ] Tier-1 and Tier-2 OXP corpus green on QuickJS-ng
- [ ] Every Tier-3 regression triaged: bug fixed, or documented in `docs/EXPANSION_MIGRATION.md`
- [ ] `oxp-contract/js-api-1.93.json` reproduces exactly on QuickJS-ng
- [ ] Deny-list: zero `JS_*` symbols; `mozillajs-linux` and `nspr` removed from the dependency list
- [ ] The tree builds for `aarch64-apple-darwin` as far as the GNUstep dependency permits

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
