# Golden scenario 003 — combat encounter

One attacker destroys one victim; the engine's own damage and death events are harvested; the
world is settled and a canonical dump is written. Run by `tests/golden/combat.py`, pinned by
`spec.json` beside this file, checked by `tests/golden/check_combat_evidence.py` and
`tests/golden/gate_003_spec.py`, unit-tested by `tests/golden/test_combat.py`.

**10 runs, 10 byte-identical dumps** (md5 `54ff0e9d8fbe2a0564fc4cf4208c9bbc`, 1848 bytes, wall
27–42 s per run). Measured on windows-x64 on 2026-09-18.

## Is a combat golden buildable on this engine? Yes — but only after three findings

The bead asked for a judgement backed by evidence. Combat is *not* deterministic by default on
this build. Three mechanisms break it, two of them fatally; each was measured, then traced to the
source line that causes it, then designed out. Nothing was rounded harder to make anything agree —
the stability numbers above are at the policy quantisation of 3 decimals, and the divergence
measurements below were taken at **15 decimals** (effectively unrounded) precisely so that
agreement could not be manufactured by the dump format.

### Finding 1 — spawning by ROLE is not deterministic, and it changes the OUTCOME

`system.addShips("pirate", 1, ...)` reaches `Universe.m:4008 -newShipWithRole:` →
`:3948 -randomShipKeyForRoleRespectingConditions:` → `OOShipRegistry.m:276-279`
`[[self probabilitySetForRole:role] randomObject]` — a RANROT draw. A fixed `OO_RANDOM_SEED` fixes
the *sequence* but not how far into it the run has advanced, because the frames burned between
launch and spawn depend on how fast the box renders.

Measured, three runs at seed 20260918, spawning `police` vs `pirate`:

| run | attacker | victim | victim maxEnergy | fixed 6×60 strike outcome |
|-----|----------|--------|------------------|---------------------------|
| 5 | GalCop Viper (180) | Moray Star Boat | 240 | victim destroyed |
| 6 | GalCop Viper (180) | Moray Star Boat | **496** | **victim survived** |
| 7 | GalCop Viper (180) | **Mamba** | 240 | victim destroyed |

The *encounter's outcome* changed, not just a float. Fixed by pinning the cast to literal ship
keys — `"[viper]"` and `"[adder]"`, the form `OOShipRegistry.m:1229` registers with probability
1.0 for every ship, so `addShips` makes no draw. Three keyed runs returned
`GalCop Viper|180|Adder|85` every time. `gate_003_spec.py` refuses a spec whose cast keys are not
in the `[shipKey]` form, so this cannot silently regress.

### Finding 2 — AI-driven gunnery is not deterministic, and does not even finish

Three runs of a real dogfight (both ships given their roles' real AIs, attacker given the victim
as `target` and told to `performAttack()`), 400 ticks ≈ 50 game seconds each:

| run | damage_events | damage_total | death_events |
|-----|---------------|--------------|--------------|
| 1 | 6 | 35.4751763343811 | 0 |
| 2 | 4 | 24.0 | 0 |
| 3 | 6 | 36.0 | 0 |

Different damage every run and **no kill at all** within the budget. The hit path is RANROT-fed:
`ShipEntity.m:11763-11769` delivers laser damage, and `-noteTakingDamage:` itself rolls
`randf()*10.0 < accuracy` at `:8988` to pick an evasion behaviour. No seed pinning makes that
repeatable while `delta_t` is wall-clock.

**So the damage is scripted, and this is stated plainly rather than hidden.** The attacker calls
`ship.dealEnergyDamage(60, 2500)` twice. That is not a simulation of combat — it enters the engine
at `OOJSShip.m:2406` → `ShipEntity.m:8836 -dealEnergyDamage:atRange:withBias:` → `-takeEnergyDamage:`
(`:13119`), **the same method a laser hit calls**, which decrements `energy` (`:13131`), dispatches
`shipTakingDamage` (`:8983`), and on `energy <= 0` runs `-getDestroyedBy:` → `-noteKilledBy:`
(`:9020-9024`) dispatching `shipDied` on the victim and `shipKilledOther` on the attacker.

**What this golden therefore does and does not pin.** It pins the engine's *damage, destruction
and kill-attribution* path end to end. It does **not** pin AI target selection, weapon aiming, or
hit probability — those are nondeterministic on this build and a golden over them would be flaky
by construction. That limit is the honest scope of scenario 003.

### Finding 3 — `delta_t` is wall-clock, so nothing moving can be in the dump

`GameController.m:405`: `delta_t = [NSDate timeIntervalSinceReferenceDate] - last_timeInterval`.
There is no fixed-timestep mode. Any entity still integrating at dump time carries a
frame-count-dependent value, and a spawned ship under thrust **cannot be frozen from JS** because
`ShipEntity.m:12830-12833` defines `-velocity` as `[super velocity] + [self thrustVector]` — the
setter clears only the Newtonian half.

Measured: keeping the surviving attacker in the dump diverged on **7 of 105 leaf fields** across 3
runs, the attacker reading 15.92 and 320.00 m/s *after* the world was supposedly frozen. So the
encounter is fought, the engine counters are harvested, and *then* every non-station ship is
removed. The dump carries the station furniture, the market, the player, and the evidence block.

For scale, the same comparison without any of these three fixes: **45 of 135 leaf fields diverged
across 4 runs at one seed** — including which ship types existed at all.

## What is asserted on, and why a dead run cannot satisfy it

A combat scenario where the combat never happens produces a clean log and a perfectly stable dump.
Six independent fields make that impossible to pass, all stored *in* the dump so every future diff
re-checks them rather than trusting a capture-time assertion:

| field | source | a dead run gives |
|---|---|---|
| `damage_events` | engine `shipTakingDamage` on the victim (`ShipEntity.m:8983`) | 0 |
| `damage_total` | the engine's own `amount` argument, summed | 0 |
| `death_events` | engine `shipDied` on the victim (`:9020`) | 0 |
| `kill_events` | engine `shipKilledOther` on the **attacker** (`:9024`) | 0 |
| `victim_destroyed` / `attacker_survived` | handle validity | false / — |
| `cast_alive_before` → `after` | **the scenario's own two handles**, 2 → 1 | 2 → 2 |

All four counters are **engine dispatches**, hung on the ships' own script objects the way the
stock content does it (`Resources/Scripts/oolite-tutorial.js:860`). The harness installs the
handlers and never calls them; nothing in Python can increment them.

`kill_events` is the strongest of the four: the engine dispatches `shipKilledOther` to `whom`, so
it is the engine's *own attribution* of the kill to this scenario's attacker. A victim that died
of a proximity accident, of overheating, or at the hands of a ship the station launched cannot
satisfy it.

`cast_alive` is deliberately **not** a role count. A role count cannot distinguish a ship the
scenario spawned from one the system populator or the station's traffic timer wandered in — bead
oo-qwk5 was parked on exactly that, and combat is the worst case for it since combat means ships
and ships mean role counts. The scenario keeps *handles* on `debugConsole`, so the count is immune.

`death_events` is pinned to **exactly 1**, not `>= 1`: the counter is scoped to one ship's script
object, so 0 means the victim survived and >1 means the handle is not the ship the scenario spawned.

## Populator traffic

The system populator is switched off at the source (`system.setPopulator(key, null)` →
`OOJSSystem.m:1311` → `[UNIVERSE setPopulatorSetting:key to:nil]`; 36 keys suppressed, verified
zero remain), because `Universe.m:7101`'s `system_repopulator` both adds traffic and consumes a
per-run-variable number of RANROT draws.

That is **not sufficient on its own** and the scenario does not pretend it is. The main station
launches its own traffic on a separate timer (`StationEntity.m:961-995`), and the rock hermit
launches miners via `rockHermitAI.plist`. Observed survivors across probe runs included a
*Mining Transporter*, a *Worm*, a *Cobra Mark I*, a *Transporter* and an *Adder* — traffic the
scenario never spawned. This is exactly the hazard that blocked three previous beads. It is
handled by not depending on absence: the final `clear_system()` removes every non-station ship
before the dump, and every assertion is on handles or engine counters rather than on population.

## What is NOT evidence in this golden

`player.ship.position` and `player.ship.velocity` are **declared**, not measured, written from the
spec under the pause. The player's velocity is not settled after a launch — scenario 001 measured
it growing from 0 to 110 m/s between two console round trips while `speed` stayed pinned — so it
tracks wall-clock frames, not the simulation. A test comparing only those fields would be vacuous.
The measured content of this golden is the entity set, the market, the player's ledger, and the
evidence block.

## Determinism knobs

All thirteen are pinned in `spec.json`, all are read by `combat.py`, and all are asserted **equal
to the values recorded in the staged golden's `provenance.json`** by `gate_003_spec.py` — not
against literals in the checker, which would make a deliberate re-bless illegal. Bead oo-3ya found
a seed that could be changed with its gate staying green because the spec line *printed* the seed
and had no predicate on it; a fresh-run-vs-golden comparison cannot catch that, since changing the
seed changes both sides.

`seed`, `system_id`, `ticks`, `tick_seconds`, `quant_decimals`, `load_save`, `attacker_key`,
`victim_key`, `attacker_position`, `victim_position`, `strikes`, `strike_damage`, `strike_range`.

Ask of each: *if someone changed this, which line goes red?* Every one of them is answered by
`gate_003_spec.py`'s provenance-drift clause, and the cast keys and `strike_damage` are
additionally answered by their own predicates.

## Storage

The golden is staged at `tests/golden/pending/003-combat/`, **not** under `goldens/`. See
`LANDING.md` there: `goldens/` is a protected path and the guard does not distinguish creating a
new golden from modifying an existing one, so landing it is a human decision.
