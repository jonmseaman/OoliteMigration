# Golden scenario 015-trumbles — load the 1.75 Trumbles checklist save

Bead **oo-hv4d**. Scenario 001's shape (fixed seed, fixed tick count, canonical dump, frame hash,
10-run stability) applied to a **saved game**: `upstream/oolite-tests/Checklist-files/Missions/
Trumbles.oolite-save`, loaded through the game's own `-load` argument.

| knob | value |
| --- | --- |
| seed (`OO_RANDOM_SEED`) | 20260918 |
| system | Lave (ID 7) |
| ticks × tick_seconds | 24 × 0.125 = 3.0 s of game time |
| quantisation | 3 decimals (storage policy) |
| save | `upstream/oolite-tests/Checklist-files/Missions/Trumbles.oolite-save`, 24424 bytes, `written_by_version = 1.75` |
| trumble awards | 4 — **a measured constant, see below** |

---

## The trumble determinism question, measured

Trumbles are a live, multiplying population, so "is the count after N ticks reproducible at a
fixed seed?" is the sharpest determinism question in the save-load set. It was **measured on this
box**, not reasoned about, and the answer has two halves.

### Half one — the saved population is exactly reproducible, and it is zero

The fixture's `trumbles` plist value is `[0, 20936, [24 trumble dictionaries]]`. The first element
is the count, the second is an anti-cheat checksum, and `-setTrumbleValueFrom:`
(`PlayerEntity.m:12069-12175`) accepts the stored count **only if the checksum agrees**. If it
does not, the loader *searches* 1..23 for a count that matches (`:12112-12125`) — so the population
the engine ends up with is a function of the **checksum**, not of the stored integer.

`munge_checksum` (`legacy_random.c:48-57`) was reimplemented in Python and run over this fixture's
own values (`player_name = "Trumbles"`, `credits = 65534`, `ship_kills = 0`) for every candidate
count 0..23. Exactly one matches:

    n=0  -> 20936   MATCH
    n=1  -> 48138
    n=2  ->  9806
    ...  (no other n in 0..23 yields 20936)

So the count is uniquely pinned by the file, and the live game confirms it: `player.trumbleCount`
reads **0** after the load, on every run. A population of zero cannot breed — `updateTrumbles:`
(`PlayerEntity.m:3601-3611`) iterates `trumbleCount` times — so on the fixture alone the
determinism question has a trivial answer and no teeth.

### Half two — a live population is NOT reproducible past four

To give the question teeth the scenario grows a real population with
`player.ship.awardEquipment('EQ_TRUMBLE')`, which reaches `PlayerEntity.m:11521-11534`:

```objc
if ((trumbleCount < PLAYER_MAX_TRUMBLES / 6) ||
    (trumbleCount < PLAYER_MAX_TRUMBLES / 3 && ranrot_rand() % 2 > 0))
    [self addTrumble:trumble[ranrot_rand() % PLAYER_MAX_TRUMBLES]];
```

`PLAYER_MAX_TRUMBLES` is 24 (`PlayerEntity.h:312`), so `MAX/6 = 4` awards take the **left branch
unconditionally** and the fifth onwards are gated on a RANROT draw.

**Measured — three runs, identical seed 20260918, count after each of fourteen awards:**

| award | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| run 1 | 1 | 2 | 3 | 4 | **5** | **6** | **6** | **7** | **7** | **7** | **7** | **8** | 8 | 8 |
| run 2 | 1 | 2 | 3 | 4 | **5** | **5** | **6** | **6** | **7** | **8** | **8** | **8** | 8 | 8 |
| run 3 | 1 | 2 | 3 | 4 | **5** | **5** | **6** | **6** | **6** | **6** | **6** | **7** | 8 | 8 |

The first four agree on every run; from the fifth they diverge. **This is exactly the shape bead
oo-izi measured for `system.addShips`**: a fixed seed pins the RANROT *sequence* but not how far
into it a run has advanced, because the number of frames burned before the draw depends on how
fast this box rendered.

So `spec["trumble_awards"] = 4` is **not a convenient number — it is the measured boundary of the
deterministic prefix**, and `check_trumbles_evidence.py` asserts it equals
`PLAYER_MAX_TRUMBLES // 6` rather than the literal 4.

**The seam that would be needed** to pin a larger population is a JS-reachable way to seed or step
the engine's RANROT stream at a known point (or an award path that does not consult it). Inventing
one is out of scope for a golden scenario. Coarsening the dump or widening a tolerance to hide the
divergence would have been strictly worse than measuring it.

### Half two, continued — breeding does not fire inside the tick budget

`OOTrumble.m:623-627` sets `readyToSpawn` only after a trumble has eaten 10 accumulated units of
cargo (`trumbleAppetiteAccumulator > 10.0`) while full-grown (`size > 0.95`) and comfortable
(`discomfort < 0.25`), and the feeding branch at `:585-612` iterates `[player cargo]` — the **cargo
pods**, of which a docked player has none.

**Measured:** with 8 live trumbles the count did not move across 15 s of game time. The dump
therefore carries `trumble_count_stable_across_ticks`, so if a future engine ever breeds inside
this budget the golden goes **red** instead of silently drifting.

---

## Anti-vacuity: what a fresh commander cannot produce

"The game started" is satisfiable by a run that ignored `-load` entirely, and rc=0 plus an absence
of ERROR lines are *both* satisfiable by a dead run (bead oo-het caught seven expansions that way).
Six positive defences, each naming state a default new game cannot have:

1. **`evidence.load_stages` — ENGINE-EMITTED.** `PlayerEntityLoadSave.m:620-811` logs a fixed
   14-stage sequence ("Reading file" … "Loading complete") on the `load.progress` channel. Those
   `OOLog` calls exist **only inside `-loadPlayerFromFile:`**. A run that never loaded emits
   *none* of them; a load that died partway emits a *prefix*. The **whole ordered sequence** is
   required, so both failures are caught by name.
   The channel is off by default (`Resources/Config/logcontrol.plist:241`), and it cannot be
   switched on from the console the way scenario 010 does with texture channels — the entire load
   happens *before* the debug console connects. So the scenario writes a `Config/logcontrol.plist`
   into its private `OO_ADDITIONALADDONSDIRS` root, which `ResourceManager.m:1761-1777` merges
   over the built-in copy. **Verified by running it:** without the file the log has no
   `[load.progress]` lines; with it, all 14.
2. **`evidence.mission_variable_keys`.** The save carries five mission variables including
   `mission_trumbles`, the field the bead names. A fresh commander's dictionary is **empty**
   (`PlayerEntity.m:1986-1987`). Compared as a **key set, never by value**: this fixture's
   `mission_trumbles` is the *empty string* and an absent mission variable reads the same way, so
   value equality would be satisfied by a game that had never heard of the mission. (The engine
   strips the `mission_` prefix for JS — `OOJSMissionVariables.m:191-193`.)
3. **`evidence.save_written_by_version == "1.75"`** — the save-format compatibility contract.
4. **The 11-field census**, read out of the *file* by Python's plistlib and out of the *live game*
   by the JS API, in two OS processes sharing no code (scenario 006's invariant). Commander
   `Trumbles`, credits 6553.4, fuel 7.0 — none is a default.
5. **The population, both halves** (above), plus `cheat_messages == []` — the engine logs
   `POSSIBLE CHEAT DETECTED` when the checksum disagrees, and that absence is meaningful *only
   because* defence 1 proves the channels were on.
6. **`trumble_count_stable_across_ticks`.**

## The deliberate asymmetry

`state.json` is **hashed byte-wise** and its sha256 + byte count are recorded in `provenance.json`
— a **separate file a mutant does not touch**, because perturbing the golden alone moves *both
sides* of a golden-vs-copy comparison (bead oo-gxp measured that mutant surviving).

`frame.grid` is **never byte-hashed into the verdict**. llvmpipe is not bit-reproducible: this
scenario's own 10-run sweep produced **10 distinct frame-grid digests over 10 byte-identical
dumps**. Frames are compared with the tolerance bead oo-ae9 *measured* (0.004377268476873758),
used as measured and never adjusted to make a run pass.

## Determinism sources switched off

Three, in this order, before any slow probe — order is load-bearing, not tidiness:

1. `system.setPopulator(key, null)` for every populator setting (`OOJSSystem.m:1311`);
2. `hasNPCTraffic = false` on every station (`StationEntity.m:960-995` runs its own launch
   schedule, gated on nothing the system populator owns);
3. `worldScripts['oolite-populator'].systemWillRepopulate` replaced with a no-op — its station
   picker `_tradeStation` ends with an **unconditional `return system.mainStation`**, so switching
   the flag off does not stop it launching.

Then `quiesce()` drives clear-and-settle to a **fixed point** (both conditions in one loop,
immediately before the measurement) and refuses rather than hanging if the world never reaches it.

## Stability

See `provenance.json` → `stability`. Runs, dumps written, distinct digests, REFUSED vs DIFFERED
and per-run wall times are all recorded there; `stability()` captures every run's outcome
**regardless of exit code** and shouts if fewer than two runs produced a dump.
