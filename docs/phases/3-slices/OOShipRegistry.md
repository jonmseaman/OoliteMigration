# Slice plan: OOShipRegistry

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-7zpk). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OOShipRegistry.md`, which recounts the
file every time, so the numbers below are only a snapshot.

- **File:** `Core/OOShipRegistry.mm` (1,908 lines) + header (74 lines). One singleton class with
  four categories: the primary block (lifecycle and `cxx_*` lookups), `OOConveniences`,
  `OODataLoader` (~1,350 lines: loading, merging and validating shipdata.plist), `Singleton`.
  A dozen `oo::PList` helpers and the `DumpStringAddrs` debug block are plain C++.
- **Shape:** `OODataLoader` is too big for one story, so it splits in two along the pipeline:
  slice 2 is loading, merging, filtering and the demo/role tables; slice 3 is subentity
  canonicalisation and validation plus mesh preloading and role maps.
- **Order:** slice 1 (class shell) first; slices 2 and 3 are independent of each other.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | class shell, lifecycle, lookups, `OOConveniences`, `Singleton` | ~230 | ~475 |
| 2 | `OODataLoader`: load, merge, like_ship, shipyard, filters, conditions | ~755 | ~1,000 |
| 3 | `OODataLoader`: subentity/flasher canonicalisation and validation, meshes, roles | ~600 | ~845 |
| verbatim | PList helpers, string-address debug dump | — | not read |

```slice-plan
source: upstream/oolite/src/Core/OOShipRegistry.mm
header: upstream/oolite/src/Core/OOShipRegistry.h

slice 1: class shell, lifecycle, cxx_* lookups, OOConveniences, Singleton
  @OOShipRegistry
  @OOShipRegistry(OOConveniences)
  @OOShipRegistry(Singleton)
  FirstToken()

slice 2: OODataLoader - load, merge, like_ship, shipyard, filters, demo ships and role tables
  @OOShipRegistry(OODataLoader)

slice 3: OODataLoader - subentity and flasher declarations, mesh preloading, role maps
  -[OOShipRegistry canonicalizeAndTagSubentities:]
  -[OOShipRegistry canonicalizeSubentityDeclaration:forShip:shipData:fatalError:]
  -[OOShipRegistry translateOld*]
  -[OOShipRegistry validateNewStyle*]
  -[OOShipRegistry shipIsBallTurretForKey:inShipData:]
  -[OOShipRegistry preloadShipMeshes:]
  -[OOShipRegistry mergeShipRoles:forShipKey:intoProbabilityMap:]

verbatim: plain C/C++ helpers, no Objective-C (checked)
  *
```
