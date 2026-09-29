# Slice plan: OOJSSystem

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-sxsg). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OOJSSystem.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Scripting/OOJSSystem.mm` (1,952 lines) + header (38 lines). No class of its
  own: the JavaScript `System` object, as file-scope `ooscript` callbacks (property getter and
  setter, ~35 methods) that message `Universe`, `PlayerEntity` and the entity classes. The
  preamble is large (~570 lines: property and method tables, declarations) and every slice is
  charged for it.
- **Shape:** a callback that sends Objective-C messages is converted in a slice; one that only
  calls `ooscript` / C++ APIs has no Objective-C and stays verbatim
  ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9) — the checker proves which is
  which. Slice 1 is the property surface and the entity queries; slice 2 is everything that
  creates ships, visual effects, populators and waypoints.
- **Order:** after the scripting-bindings pattern seam (oo-ppc, `OOJSVector`). The slices are
  independent: they share only the preamble's declarations.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | `SystemGetProperty` / `SystemSetProperty`, `toString`, `addPlanet` / `addMoon`, ship and entity counts and searches | ~595 | ~1,205 |
| 2 | ship creation: `addShips*` / `addGroup*`, the legacy `legacy_add*` family, static system lookups, visual effects, populators, waypoints | ~535 | ~1,145 |
| verbatim | callbacks and helpers with no Objective-C | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Scripting/OOJSSystem.mm
header: upstream/oolite/src/Core/Scripting/OOJSSystem.h

slice 1: properties, planets, entity counts and searches
  SystemGetProperty()
  SystemSetProperty()
  SystemToString()
  SystemAddPlanet()
  SystemAddMoon()
  SystemSendAllShipsAway()
  SystemCount*()
  SystemLocationFromCode()
  FindJSVisibleEntities()

slice 2: ship creation, legacy spawners, static lookups, effects, populators, waypoints
  SystemLegacy*()
  SystemStaticSystemNameForID()
  SystemStaticSystemIDForName()
  SystemAddVisualEffect()
  SystemSetPopulator()
  SystemSetWaypoint()
  SystemAddShipsOrGroup()
  SystemAddShipsOrGroupToRoute()

verbatim: plain C/C++ callbacks and helpers, no Objective-C (checked)
  *
```
