# Delegated human decisions, 2026-10-05

On 2026-10-05 Jon delegated the open human-assigned beads: "handle human-assigned beads ... to your
best judgement" (Jon, in chat, 2026-10-05, relayed by the orchestrator). Each decision below takes
the recommended default the bead already carried, which had been the default in effect
(CLAUDE.md rule 10). This file is the record each bead's acceptance checks; the bead closes when
`accept` merges its proof. A decision Jon later reverses gets a new ADR or bead, as usual.

## oo-1x6ak: ratify proposed ADR-0059 (upstream delta and per-module freeze policy)

- Question: ratify or reject [ADR-0059](0059-upstream-freeze-policy.md): a module is one `src/`
  directory, frozen once it holds Phase 3 work; the monthly upstream sync leaves frozen modules
  alone and each upstream commit touching one becomes a `docs/UPSTREAM_DELTA.md` row and a port
  bead, enforced by `tools/upstream-delta.sh`.
- Decision: ratified as proposed. ADR-0059's status and the index row read
  "Accepted (delegated 2026-10-05)".
- Delegation: Jon, 2026-10-05: "handle human-assigned beads ... to your best judgement".

## oo-f4rft: ratify proposed ADR-0058 (GUI click row from pointer)

- Question: ratify or reject [ADR-0058](0058-gui-click-row-from-pointer.md): a click on an
  interactive GUI screen resolves its row from the pointer position at click time
  (`-[GuiDisplayGen rowAtVirtualJoystickPosition:]`, shared with the draw), not the render-stale
  `cursor_row`.
- Decision: ratified as proposed. ADR-0058's status and the index row read
  "Accepted (delegated 2026-10-05)".
- Delegation: Jon, 2026-10-05: "handle human-assigned beads ... to your best judgement".

## oo-9n5p9: retiring façade-contract test cases as each X+ObjCBridge is deleted

- Question: may the façade-deletion beads (label `sweep:objc-bridge`) remove the test cases and
  stand-ins that exist only to exercise the deleted façade (CLAUDE.md rule 2, ADR-0049)?
- Decision: a standing ADR-0049 approval, scoped to ONLY test cases/stubs that exercise the
  deleted façade (its selectors, `oo::ToObjC`/`oo::ToCxx` crossings, the façade's `-dealloc`).
  Each such case is listed in its deletion bead, and its approval line in
  `tools/retire-test-approvals.txt` cites oo-9n5p9. The C++ API checks of the class stay and must
  still pass; nothing else in a test may be removed or weakened under this approval. The scope is
  written as a comment block in `tools/retire-test-approvals.txt`.
- Delegation: Jon, 2026-10-05: "handle human-assigned beads ... to your best judgement".

## oo-9hoy9: the compiled-out old-planet code (NEW_PLANETS 0)

- Question: delete, fence, or revive `TextureStore.h/.mm`, `PlanetEntity.h/.mm` and the
  `#if !NEW_PLANETS` branches, which no build compiles and which do not compile?
- Decision: option A, delete. Dead old-planet code is not converted in Phase 3; one fleet bead
  deletes TextureStore.h/.mm, PlanetEntity.h/.mm, their meson lines and the `#if !NEW_PLANETS`
  branches (keeping the NEW_PLANETS branches unconditionally, and the macro until its last use
  goes). oo-btm5, oo-lzsr, oo-s7hw and oo-n39b are superseded by that bead. No game behaviour
  changes: the code is not compiled.
- Delegation: Jon, 2026-10-05: "handle human-assigned beads ... to your best judgement".

## oo-9wpwn: the dead OOEnvironmentCubeMap

- Question: delete or revive `src/Core/OOEnvironmentCubeMap.h/.mm`, which has never been compiled
  by this tree and does not compile against today's API?
- Decision: delete it as dead code in a small fleet bead (`git rm` both files; the Universe.mm TODO
  naming it stays as a comment); oo-v7ob is superseded by that bead.
- Delegation: Jon, 2026-10-05: "handle human-assigned beads ... to your best judgement".

## oo-jsx0h: porting test_SkyEntity's star set-up stand-in (oo-4jjl)

- Question: may OOSkyDrawable's conversion (oo-4jjl) edit `tests/unit/core/test_SkyEntity.mm`'s
  stand-in block (CLAUDE.md rule 2), since after the conversion there is no Objective-C method to
  hook?
- Decision: approved for the stand-in block only. The converted OOSkyDrawable gets a test seam for
  its star set-up (a friend struct `OOSkyDrawableTestAccess` with a static hook the test sets);
  `SetUp()` sets that hook instead of `method_setImplementation`, and
  `[[sky drawable] isKindOfClass:[OOSkyDrawable class]]` becomes a `dynamic_cast` of the
  drawable's C++ part to `::OOSkyDrawable`. No `OO_TEST` case is added, removed or weakened; the
  expectations (star colours, sky colour, flags) stay identical.
- Delegation: Jon, 2026-10-05: "handle human-assigned beads ... to your best judgement".

## oo-9ht.117: check-slice-plan fails a plan whose class-shell slice landed

- Question: may `tools/check-slice-plan.py` exempt converted out-of-line C++ members
  (`cxx::X::m`) from the verbatim no-Objective-C check (an earlier fleet attempt was refused as
  weakening a gate)?
- Decision: take the recommended default. In `analyse()`, a unit that is an out-of-line C++
  member definition (its head was qualified, `X::m`) is exempt from the verbatim no-Objective-C
  check, with a selftest case: a converted member that messages an object passes; a plain
  function that does still fails. `--slice-done` is unchanged.
- Delegation: Jon, 2026-10-05: "handle human-assigned beads ... to your best judgement".

## oo-a1mau: EntityShaderBindings.mm is now built

- Question: keep `upstream/oolite/src/Core/Entities/EntityShaderBindings.mm` in the build (bead
  oo-aeev added it to `src/Core/Entities/meson.build`, so the entity shader uniforms whitelisted
  in `shader-uniform-bindings.plist` — `clock`, `pseudoFixedD100`/`D256`, `systemGovernment`,
  `systemEconomy`, `systemTechLevel`, `systemPopulation`, `systemProductivity` — have values
  again), or drop it and leave those uniforms unbound?
- Decision: take the recommended default, keep building it. The upstream sources define the
  category for the runtime to find and the whitelist names its methods, so an unbound uniform was
  a defect of this tree's meson lists, not upstream behaviour. Its test stays. A sweep for other
  sources missing from the meson lists is a separate bead if wanted.
- Recorded 2026-10-06 under the same delegation.
- Delegation: Jon, 2026-10-05: "handle human-assigned beads ... to your best judgement".
