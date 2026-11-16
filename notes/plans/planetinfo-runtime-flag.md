# Turn `OO_DUMP_PLANETINFO` into a runtime switch

Status: **Prepare, on hold.** Jon is still deciding (2026-11-16). He may do this on the C++ fork
only and leave upstream's `#ifdef` alone. Don't start it. This replaces step 2 (and step 3, the port) of
[planetinfo-dump.md](planetinfo-dump.md). That plan's findings, its seed check and the reply draft
still apply.

## Why

`OO_DUMP_PLANETINFO` is a compile-time `#ifdef` mode, and nobody builds it, so it has rotted: with
the define set, upstream `master` doesn't compile (mcarans, #799, 2026-11-16). A runtime switch
means:
- every normal build compiles the code, so it can't rot again;
- the mode can be used from a release build with no rebuild (Jon, 2026-11-16).

## What the mode does today

Each `#ifdef` site below is listed with upstream's `file:line`, then the fork's on
`seriesb/033-drop-oo-prefix`.

| Effect | Upstream | Fork |
|---|---|---|
| `planetinfo.record` log lines for the system, planet, sun and station | `Universe.m:1311,1369,1470,1491,1517,1544,1551`; `OOPlanetEntity.m:223`; `OOSunEntity.m:149` | `Universe.cpp:1736,1806,1940,1964,1991,2030,2040`; `PlanetEntity.cpp:388`; `SunEntity.cpp:168` |
| Max fuel 7000 instead of 70 | `PlayerEntity.h:278` (`PLAYER_MAX_FUEL`, 6 uses) | `PlayerEntity.h:417` (`inline constexpr int`) |
| Jump range 150 ly instead of 7 | `ShipEntity.h:105` (`MAX_JUMP_RANGE`, 10 uses) | `ShipEntity.h:153` (`inline constexpr double`) |
| No misjumps or malfunctions on a jump, and no draws for them | `PlayerEntity.m:6763,6787` | `PlayerEntity.cpp:7798,7825` |
| Spin-up as short as 1 s: no 5 s floor, and JS `beginHyperspaceCountdown()` with no argument uses 1 | `PlayerEntityControls.m:826`, `OOJSPlayerShip.m:1467` | `PlayerEntityControls.cpp:935`, `OOJSPlayerShip.cpp:1964` |
| `player.ship.targetSystem` writable in flight | `OOJSPlayerShip.m:921` | `OOJSPlayerShip.cpp:1264` |

The `MAX_JUMP_RANGE` uses include the galaxy route graph built at start-up
(`OOSystemDescriptionManager.m:110`), so the switch has to be read once, before the universe is
made, and can't change during a run.

## Design

**One switch, read once.**
- Upstream: a function `BOOL OODumpPlanetInfoMode(void)`.
- Fork: `bool oo::DumpPlanetInfoMode()` in `src/Core/DumpPlanetInfoMode.h`, which has no `OO` file
  prefix (new code rule).

It reads the user-defaults key `dump-planetinfo` the first time it's called, then keeps that value
for the rest of the process. Both platforms' defaults read `-key value` arguments: GNUstep's argument
domain upstream, and `oo::Defaults`' argument parsing in the fork (`Defaults.hpp:30-36`). So any of
these turn it on:

```
oolite -dump-planetinfo YES
defaults write oolite dump-planetinfo -bool YES          (macOS)
the key in the GNUstep defaults file                     (Windows, Linux)
```

When it's on, log once at start-up under `planetinfo.mode`: "planetinfo dump mode is on: fuel 7000,
jump range 150 ly, no misjumps". That way no one mistakes a cheat-strength ship for a bug.

**Each site:**
- **Log lines:** `#ifdef OO_DUMP_PLANETINFO … #endif` becomes `if (OODumpPlanetInfoMode()) { … }`.
  The `SPROP`/`IPROP`/`FPROP`/`CPROP` macros are defined inside the blocks today. They move out
  and get `#undef`'d after their last use. While compiling them, fix the rotted lines:
  - `system_seed` → `systemSeed` (`Universe.m:1370-1371`);
  - the `sun_vector` line prints `sun_dir`, not the unset `vf` (`Universe.m:1491`);
  - whatever else the compiler finds.
- **Constants:** keep the normal values under their current names (`PLAYER_MAX_FUEL` 70,
  `MAX_JUMP_RANGE` 7). Add accessors that return the mode's value when it's on:
  - upstream `OOPlayerMaxFuel()`/`OOMaxJumpRange()`;
  - fork `oo::PlayerMaxFuel()`/`oo::MaxJumpRange()`.

  Point every use at the accessors, and delete the `#ifdef` pair. The fork's tests compare against
  the constants (`test_ShipEntity.cpp:971,1761-1765`, `test_OOJSShip.cpp:617`). With the mode off,
  the accessors equal the constants, so those tests pass unedited.
- **Misjump block:** `BOOL misjump = NO;` comes first. The malfunction draw and its block run only
  `if (!OODumpPlanetInfoMode())`, so in the mode no draw is taken, as today.
- **Spin-up and `targetSystem`:** each `#ifndef` guard becomes `if (!OODumpPlanetInfoMode())` on
  the same statements.
- **Help page:** add `-dump-planetinfo YES` to the `-help` text in `SDL/main.m` (`main.cpp` in the
  fork).

## Steps

1. **Upstream branch.** Make the branch with `git town prepend fix/planetinfo-dump`. Run it from the
   checkout that has `seriesb/001-random-seed-env` (`.agent-tmp/wt-001`), which gives
   `master → fix/planetinfo-dump → 001` (Jon, 2026-11-16). Build in a worktree under `.agent-tmp/`
   with UCRT64's GNUstep, as `upstream-binding-wt` was. Then:
   1. add `OODumpPlanetInfoMode()` and the two accessors;
   2. convert the sites, and fix the rotted log lines;
   3. update the help text.

   Use clang-format 22 on the changed lines only: upstream's files aren't in the fork's layout.
2. **Fork port.** On `seriesb/033-drop-oo-prefix`, make the same change in C++:
   - `oo::DumpPlanetInfoMode()`, `oo::PlayerMaxFuel()` and `oo::MaxJumpRange()`;
   - the `OO_LOG` forms of the log lines.

   Add a unit test, `tests/unit/core/test_DumpPlanetInfoMode.cpp`, written first. It checks:
   - with the key unset, the mode is off, and the accessors return 70 and 7.0;
   - with `-dump-planetinfo YES` in the argument domain, they return 7000 and 150.0.

   If the cached value makes the second case unreachable in one test process, add a test-only reset
   hook (`oo::ResetDumpPlanetInfoModeForTesting()`). Record that under Decisions.
3. **Update the other plan:**
   - in [planetinfo-dump.md](planetinfo-dump.md), mark its steps 2-3 as replaced by this plan;
   - in its reply draft, change "a `oo_dump_planetinfo` Meson option like yours" to "a runtime
     switch, `-dump-planetinfo YES`, so it can't rot again".

## Done check

From each tree (the upstream worktree, then `oolite-dev`), this exits nonzero before and zero
after:

```bash
! git grep -q 'OO_DUMP_PLANETINFO' -- src
```

Upstream, also run the built game twice, each time for about 30 s. It sets up the start system at
start-up, so no keys are needed:
- `oolite -dump-planetinfo YES`: `Latest.log` contains `planetinfo.record` and `planetinfo.mode`
  lines;
- `oolite` alone: it contains neither.

Fork: `./mk.sh build dev` (no new warnings), `tests/run.sh unit` (the new test included) and
`tests/run.sh component`.

## Decisions (defaults taken)

- **One switch for both the logging and the play changes,** as the `#ifdef` was. A logging-only
  switch would be a new feature. Splitting them later is one more key.
- **A user-defaults key, not a new hand-parsed argument.** The defaults already read `-key value`
  on every platform, with no new parsing in `main`. Upstream already reads several settings this
  way (`fullscreen`, `ecoqos`, `use-test-release-updates`).
- **Read once and cached.** The route graph is built from the jump range at start-up, so changing
  it mid-run would leave the graph and the range disagreeing.
- **Keep the constants, add accessors.** The fork's tests stay unedited, and the normal values stay
  greppable under their old names.
- **No Meson option.** mcarans' `oo_dump_planetinfo` option isn't needed once the mode is runtime.

## Out of scope

- A separate logging-only switch.
- Anything to do with `OO_RANDOM_SEED` (see [planetinfo-dump.md](planetinfo-dump.md), step 1
  result).
