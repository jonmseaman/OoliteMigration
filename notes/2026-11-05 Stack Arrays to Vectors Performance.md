# Perf: variable-length stack arrays became `std::vector` in the Objective-C++ switch

| | |
|---|---|
| **Type** | Performance investigation (nothing measured yet) |
| **Branch** | `seriesb/003-objcpp-switch` (parent: `seriesb/002-safety-net`) |
| **Introduced by** | `de8858b2c` "Compile the game as Objective-C++, keeping #768's QuickJS-ng binding" |
| **Priority** | Low until measured. The entity-scan sites are the ones worth looking at first. |

## Summary

C99 variable-length arrays (VLAs) are not valid C++, so the switch to Objective-C++ replaced 40
of them with `std::vector`. A VLA lives on the stack and costs nothing to create. A
`std::vector` is a heap allocation plus a free, on every call. Most of these sites are cold, but
about two dozen run in or near the per-frame path, so this is a plausible source of a small
steady-state slowdown, mostly in allocator traffic and frame-time jitter. **Nobody has measured
it.** This ticket exists so that when performance testing starts, these sites are on the list.

## Background

Before (`seriesb/002-safety-net`):

```c
Entity* my_entities[ent_count];            // stack, uninitialised, free
```

After (`seriesb/003-objcpp-switch`):

```cpp
std::vector<Entity*> my_entities(ent_count);   // heap, zero-filled, freed on scope exit
```

Behavioural differences besides cost:

- The vector is **zero-initialised**. The VLA was not, so there is a small extra `memset` per call.
- A zero-length vector is well defined. A zero-length VLA was undefined behaviour.
- `std::vector<BOOL>` is **bit-packed when `BOOL` is `bool`** (Apple platforms), so element access
  is slower than for a `BOOL[]`. On GNUstep `BOOL` is `unsigned char` and there is no
  specialisation. This affects `OOMesh.mm:1720` only.
- `argv.data()` for an empty `std::vector` can be null. `OOJSFunction.mm:248` used to allocate
  `argc + 1` so the pointer was never null. This is a correctness question, not a perf one, and
  is tracked separately in the review notes.

## How big were the arrays?

| Sites | Element count | Size per call |
|---|---|---|
| `Entity*` / `ShipEntity*` scan buffers (about 22 sites) | `ent_count` ≤ `UNIVERSE_MAX_ENTITIES` = 2048, usually far less | up to 16 KB |
| `sinTable`, `cosTable` (`OOConvertCubeMapToLatLong.mm:60-61`) | `width` ≤ 4096 | up to 16 KB each |
| `triangle_area`, `smoothGroup`, `is_edge_vertex` (`OOMesh.mm`) | faces or vertices of one ship model | up to tens of KB |
| `quantityInHold`, `quantities` (cargo) | commodity count | tiny |
| `row_alpha`, `characters`, `result`, `argv` | tens | tiny |

None was large enough to threaten the stack, so the old code was safe in practice. Heap
allocation is the only cost being added.

## Sites

Grouped by how often they probably run. **This classification comes from function names, not
from a profile.** Confirm with a profiler before acting on it.

### Probably per frame or per entity pair (look here first)

| Site | Function |
|---|---|
| `Universe.mm:6435` | `-update:` |
| `Universe.mm:4381` | `-drawUniverse` |
| `CollisionRegion.mm:244` | `-findCollisions` |
| `CollisionRegion.mm:526`, `:528` | `-findShadowedEntities` (two vectors) |
| `HeadUpDisplay.mm:1117` | `-drawScanner:` |
| `GuiDisplayGen.mm:1318` | `-drawGLDisplay:…` |
| `PlayerEntity.mm:2905` | `-updateAlertConditionForNearbyEntities` |

### Probably per AI tick or per shot

| Site | Function |
|---|---|
| `Universe.mm:5274` | `-isVectorClearFromEntity:…` |
| `Universe.mm:5339` | `-hazardOnRouteFromEntity:…` |
| `Universe.mm:5394` | `-getSafeVectorFromEntity:…` |
| `Universe.mm:5576` | `-firstShipHitByLaserFromShip:…` |
| `Universe.mm:5660` | `-firstEntityTargetedByPlayer` |
| `ShipEntity.mm:12156` | `-setTargetToNearestStationIncludingHostiles:` |
| `ShipEntity.mm:12518` | `-checkShipsInVicinityForWitchJumpExit` |
| `ShipEntityAI.mm:588`, `:921`, `:2175` | wormhole, merchantman and station target selection |
| `DockEntity.mm:927`, `:981` | docking-corridor checks |
| `PlayerEntity.mm:6233` | `-loseTargetStatus` |
| `Universe.mm:8896` | `-allShipsDoScriptEvent:…` |
| `Scripting/OOJSFunction.mm:248` | `-evaluateWithContext:…` (every scripted function call with arguments) |

### Load time or UI events (probably ignore)

`Universe.mm:2308` (`-addShips:`), `:3890` (`-getContainersOfGoods:`),
`PlayerEntity.mm:7398-7399`, `:9754`, `:9917` (cargo and market screens),
`ShipEntity.mm:7245`, `PlayerEntityLegacyScriptEngine.mm:1978`, `OOMesh.mm:1589`, `:1656`,
`:1720-1721` (mesh setup), `OOConvertCubeMapToLatLong.mm:60-61` (texture conversion),
`OOPolygonSprite.mm:445`, `OOStringExpander.mm:261`, `OOStringParsing.mm:469`.

## What to measure

1. **Frame time** in a busy scene (many ships, station with traffic, combat), before vs after.
   Report the median and the 99th percentile. Allocator cost shows up in the tail first.
2. **Allocation count per frame**, for example with `malloc` counters, Instruments (Allocations)
   or `heaptrack`. The expected result is "N extra allocations per frame", where N is roughly
   the number of calls to the per-frame sites above.
3. **Time inside the top-level functions** (`-update:`, `-drawUniverse`, `-findCollisions`,
   `-drawScanner:`) with a sampling profiler. If none of them moves, stop.
4. **Both platforms** if possible. The allocators differ (macOS libmalloc vs glibc or the
   Windows heap), and so does `BOOL`.

Compare `seriesb/002-safety-net` against `seriesb/003-objcpp-switch` built with the same flags
(`./mk.sh build test`), same seed (`OO_RANDOM_SEED`, from `001-random-seed-env`) and same
scenario, so the only difference is the language switch.

## If it turns out to matter: options

- **Fixed-capacity stack buffer** for the entity-scan sites, for example
  `Entity* buf[UNIVERSE_MAX_ENTITIES]`, with `ent_count` clamped (it is already bounded by the
  same constant). This costs 16 KB of stack per call and nothing else, and it matches the
  old behaviour. It suits every entity site and nothing else, because the other sizes have no
  compile-time cap.
- **Small-buffer container** (`boost::container::small_vector<T, N>`, LLVM `SmallVector`):
  stack up to N, heap beyond. Adds a dependency.
- **`std::pmr::vector` over a local `std::pmr::monotonic_buffer_resource`**: standard C++17, no
  dependency, more verbose.
- **A reused member or static scratch buffer**, grown once and cleared per call. This removes
  the allocation entirely, but is not re-entrant, so it needs care in `Universe`, which some
  of these methods call recursively through scripts.
- **`alloca`**: closest to a VLA, same stack-overflow risk, awkward in C++. Not recommended.

Do **not** change the sites in the third group. They are not hot, and every one switched back
is a place where the code reads less like idiomatic C++.

## Acceptance criteria

- A short measurement (numbers, scenario, commit hashes, machine) is added to this note.
- If the per-frame cost is under the noise floor of the frame-time measurement, close this
  as "not a problem" and record the measurement here.
- If it is measurable, pick one of the options above for the entity-scan sites, apply it
  there only, and re-measure.

## Not in scope

- Correctness of `argv.data()` for empty argument lists (`OOJSFunction.mm:248`).
- Changing any VLA in plain C or vendored code. Those were not converted and are unaffected.
- General Objective-C++ performance. Beyond these allocations, the switch is casts, renames
  and brace-scoping only.

## References

- Diff: `git diff -M seriesb/002-safety-net...seriesb/003-objcpp-switch`
- Full list of sites: `git grep -n 'std::vector<' -- 'src/*.mm'` on `seriesb/003-objcpp-switch`
- `UNIVERSE_MAX_ENTITIES`: `oolite-dev/src/Core/OOTypes.h:168`
