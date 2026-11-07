# Review guidelines: the `seriesb/*` stack

Review each branch only against its parent (`git town diff-parent`) and only for the goal listed here, so a diff that does something else is a finding.

Per-branch descriptions: [`../pr/`](../pr/). Placement notes: [`placement-018-023.md`](placement-018-023.md).

## Parents (mirror upstream, not reviewed)

- `000a-upstream-767-quickjs-option`: upstream #767, QuickJS-ng as an option.
- `000b-upstream-768-quickjs-only`: upstream #768, QuickJS-ng only.

## Steps

- `001-random-seed-env`: `OO_RANDOM_SEED` pins the seed. Check: nothing else changes.
- `002-safety-net`: deterministic runs plus GUI and component tests. Check: tests only, plus the hooks they need.
- `003-objcpp-switch`: compile as Objective-C++ on #768's binding. Check: build flags and renames, no behaviour change.
- `004-oofnd-core`: add `oofnd` and the Foundation-free Objective-C floor. Check: new code, no callers moved yet.
- `005-typed-accessors`: `oo_*ForKey` becomes typed `PListView::get`. Check: same values and defaults.
- `006-foundation-wave-1`, `007-foundation-wave-2`: move Foundation usage to `oofnd`. Check: mechanical, one-for-one replacements.
- `008-selector-families`: retire the remaining Foundation selectors and their bridge callers.
- `009-leaf-conversions`: drop gnustep-base; convert maths, leaf utilities and the OXP verifier to C++.
- `010-module-conversions`: convert scripting, entities, audio and materials to C++.
- `011-first-slices`: convert the large files in slices; delete the first bridges.
- `012-shipentity-slices`: convert `ShipEntity`.
- `013-universe-player-slices`: convert `Universe` and `PlayerEntity`.
- `014-facade-deletions`: delete the Objective-C bridges.
- `015-entity-facade`: delete the Entity bridge and the last bridges.
- `016-objc-runtime-out`: remove the Objective-C runtime; rename sources to `.cpp`. Check: renames and build files only.
- `017-gcc-build`: fix what GCC warns about or evaluates differently. Check: no warning silenced (hard rule 2).
- `018-develop-fixes`: small fixes after the migration. Check: each fix stands alone.
- `019-source-hygiene`: comments describe the code; `#pragma once`. Check: no code change (compare with comments stripped); no ADR, bead, phase, golden or Objective-C-history references.
- `020-tests-and-tooling`: tests and developer tooling. Check: no existing test edited to pass (hard rule 1).
- `021-c-as-cxx`: compile the remaining C as C++; build QuickJS-ng with the fork's patches.
- `022-upstream-28ceaaba0-ports`: port upstream #783 (joystick GUI control); macOS bundle without Foundation.
- `023-google-style-format`: reformat with Google-style clang-format 22. Check: no code change beyond whitespace, wrapping and include order; rerun clang-format 22 and expect an empty diff.
- `024-post-conversion-fixes`: small fixes after the conversion; Mozilla polyfills for expansions.
- `025-remove-bool-macros`: remove the true/false macro workarounds (not in the manifest yet).

## Every branch

- It builds and passes `./mk.sh build test` and `tests/run.sh unit`.
- No test is modified or deleted to make it pass; no `-Wno-*`, diagnostic pragma or unused attribute is added.
- It merges cleanly into its child; a conflict means the work belongs in the earlier branch.
