# Slice plan: OOJSPlayerShip

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-r1en). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OOJSPlayerShip.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Scripting/OOJSPlayerShip.mm` (2,220 lines) + header (51 lines). The JavaScript
  `PlayerShip` object: file-scope `ooscript` callbacks (a ~280-line property getter, a ~460-line
  property setter, ~30 methods) plus a three-method `PlayerEntity (OOJavaScriptExtensions)`
  category. The preamble is large (~620 lines: property and method tables, declarations) and every
  slice is charged for it, so no slice may own much more than ~800 lines.
- **Shape:** a callback that sends Objective-C messages is converted in a slice; the handful that
  only touch `ooscript` (the class/prototype/object accessors) stay verbatim
  ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9). The setter is kept whole in
  one slice: splitting a `switch` over property ids across stories buys nothing.
- **Order:** after the scripting-bindings pattern seam (oo-ppc, `OOJSVector`) and after
  `OOJSShip` (frontier, oo-e4i), whose prototype `PlayerShip` extends. Slice 1 first: it holds
  `InitOOJSPlayerShip` and the `PlayerEntity` JS-extension category; slices 2 and 3 are then
  independent.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | init, `PlayerEntity (OOJavaScriptExtensions)`, `PlayerShipGetProperty`, passenger / parcel / contract methods and `ValidateContracts` | ~585 | ~1,255 |
| 2 | `PlayerShipSetProperty`, launch, cargo, autopilot, docking clearance, pylon equipment | ~620 | ~1,290 |
| 3 | custom views, scanner zoom, internal damage, hyperspace countdowns, MFDs, primed equipment, HUD dials and selector | ~385 | ~1,055 |
| verbatim | `ooscript`-only accessors | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Scripting/OOJSPlayerShip.mm
header: upstream/oolite/src/Core/Scripting/OOJSPlayerShip.h

slice 1: init, JS extensions, property getter and contract methods
  NormalizedColorComponents()
  InitOOJSPlayerShip()
  @PlayerEntity(OOJavaScriptExtensions)
  PlayerShipGetProperty()
  PlayerShipAddPassenger()
  PlayerShipRemovePassenger()
  PlayerShipAddParcel()
  PlayerShipRemoveParcel()
  PlayerShipAwardContract()
  PlayerShipRemoveContract()
  ValidateContracts()

slice 2: property setter, launch, cargo, autopilot and docking
  PlayerShipSetProperty()
  PlayerShipLaunch()
  PlayerShipRemoveAllCargo()
  PlayerShipUseSpecialCargo()
  PlayerShipEngageAutopilotToStation()
  PlayerShipDisengageAutopilot()
  PlayerShipRequestDockingClearance()
  PlayerShipCancelDockingRequest()
  PlayerShipAwardEquipmentToCurrentPylon()

slice 3: views, hyperspace countdowns, MFDs and HUD
  PlayerShipSetCustomView()
  PlayerShipResetCustomView()
  PlayerShipResetScannerZoom()
  PlayerShipTakeInternalDamage()
  PlayerShip*HyperspaceCountdown()
  PlayerShipSetMultiFunction*()
  PlayerShipSetPrimedEquipment()
  PlayerShipSetCustomHUDDial()
  PlayerShip*HUDSelector()

verbatim: plain C/C++ accessors, no Objective-C (checked)
  *
```
