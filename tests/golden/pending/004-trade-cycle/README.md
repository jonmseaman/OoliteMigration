# Golden scenario 004-trade-cycle — buy, hold, sell back

Bead **oo-zv2**. Scenario 001's shape (fixed seed, fixed system, fixed tick count, canonical dump,
frame hash, 10-run stability) applied to the **commodity market** and the player's purse and hold.

| knob | value |
| --- | --- |
| seed (`OO_RANDOM_SEED`) | 20260918 |
| system | Atdice (ID 80) — the system the fixture is docked in, and therefore the market traded |
| ticks × tick_seconds | 24 × 0.125 = 3.0 s of game time held between the legs |
| quantisation | 3 decimals (storage policy) |
| save | `upstream/oolite-tests/Checklist-files/Missions/CloakingDevice.oolite-save`, 26452 bytes, `written_by_version = 1.75` |
| commodity | `food` — quantity 17, price 40, capacity 127 at this save/system |
| cycle | buy **5**, hold, sell **3** back → hold ends at **2** |

---

## What a "trade cycle" is here, and what it is not

The engine's own buy/sell orchestration is `-[PlayerEntity tryBuyingCommodity:all:]` /
`-trySellingCommodity:all:` (`PlayerEntity.m:11334`, `:11434`). **Neither is reachable from this
tier**, and that was checked rather than assumed: both are two-argument selectors, and the debug
console's `callObjC` dispatches only the four signatures in `OOJSCall.m`'s template class — a
two-argument selector falls through `GetMethodType` to `kMethodTypeInvalid` and is refused by name.
They are otherwise driven only from `PlayerEntityControls.m`'s key handler, i.e. the GUI tier.

So the scenario drives the three engine seams the JS API **does** expose, once per leg:

```
station.setMarketQuantity(good, q)   -> -[StationEntity setQuantity:forCommodity:]
player.ship.manifest[good] = n       -> -[PlayerEntity setCargoQuantityForType:amount:]
player.credits = c                   -> -[PlayerEntity setCreditBalance:]
```

and then asserts **the engine's own answers**, not its own arithmetic:

* `player.ship.cargoSpaceUsed` is **never written** by the scenario. `-calculateCurrentCargo`
  recomputes it from the hold after the manifest write, so "used moved by exactly the units traded"
  is an engine-computed fact. Probed: asking for `cargoSpaceCapacity + 50` units yielded a hold of
  exactly 35 — the clamp is real and reachable, which is why the traded quantities sit far inside it.
* the market quantity is **read back** out of `station.market` after the write;
* the credit balance is **read back** after the write, against a credit scale that was **measured**
  (below), not assumed.

**What this scenario cannot witness**, stated plainly rather than implied away: `tryBuyingCommodity:`
itself — its capacity and legality branches, and the `playerBoughtCargo` / `playerSoldCargo` events.
The seam that would be needed is a JS-reachable buy/sell, or a single-argument ObjC shim `callObjC`
can dispatch. Inventing one is out of scope for a golden scenario.

## The credit scale, measured

`PlayerEntity` stores credits in **tenths**, so a good priced 40 costs **4.0** credits per unit.
Probed directly before the scenario was written: 5 units of food at price 40 moved
`player.credits` from **96522.6 → 96502.6**, exactly 20.0. The save file's own `credits` key is
`965226` for the same 96522.6 — an independent second confirmation. The scale is pinned in
`spec.json` and read by `trade_leg()`, so an engine that changed it fails **by name** rather than
being absorbed.

## The observable, and who else can write to it

Bead oo-rkm's rule: before measuring stability, find every carrier of the thing you assert on. The
market's carriers are

1. `-[Universe setUpSpace]` / `-[StationEntity initialiseLocalMarket]` (`Universe.m:7998`,
   `StationEntity.m:264`), which **regenerate** the market on system entry and on load — i.e.
   *before* this scenario's baseline. The scenario never changes system and never re-docks.
2. the player's own buy/sell — this scenario;
3. commodity scripts (`OOCommodities.m:327-355`), at market *generation* time only.

**Measured:** with the populators, station traffic and `oolite-populator.systemWillRepopulate`
quieted, a full 17-commodity snapshot of quantity and price was byte-identical across 4 s of game
time.

A measurement is not a guard, so the guard ships too: `evidence.untraded_goods_changed` compares
all **16** goods the scenario never trades, before and after the cycle. If another carrier ever
writes to this market during a run, that list is non-empty and the run goes **red** rather than
flaky.

## Anti-vacuity: what a dead run cannot produce

rc=0 and "no ERROR lines" are *both* satisfied by a launch that died in display setup (bead oo-het
captured the artefact). Every defence here is a **presence of progress**:

1. **`evidence.load_stages` — engine-emitted.** `PlayerEntityLoadSave.m:620-811` logs a fixed
   14-stage sequence on the `load.progress` channel; those `OOLog` calls exist **only inside
   `-loadPlayerFromFile:`**. A run that never loaded emits *none*; a load that died partway emits a
   *prefix*. The whole ordered sequence is required. The channel is off by default
   (`logcontrol.plist:241`) and cannot be switched on from the console — the load finishes before
   the console connects — so the scenario writes a `Config/logcontrol.plist` into its private
   `OO_ADDITIONALADDONSDIRS` root, which `ResourceManager.m:1761-1777` merges over the built-in copy.
2. **Credits moved by exactly `price × units / 10`**, twice, in opposite directions.
3. **The market's quantity moved by exactly the units**, twice, in opposite directions.
4. **`cargoSpaceUsed`, which the engine recomputes**, moved by exactly the units, twice.
5. **The cycle is deliberately asymmetric** (`sell_units < buy_units`), so the end state is a hold,
   a purse and a market that a run which did nothing cannot have. A symmetric cycle would leave a
   dump indistinguishable from one that never traded — `gate_004_spec.py` refuses such a spec.
6. **Every untraded good unchanged** — the witness that nothing else moved the market.

Goods conservation is checked too: what leaves the hold must arrive at the market and vice versa, so
a leg where both moved the same way is goods appearing from nowhere.

## Stability

**10 of 10 runs wrote a byte-identical dump** (3055 bytes, sha256
`7c11f202…731f`), 0 refused, 0 errored, wall 11.5–20.5 s. An **eleventh** independent run — the one
that produced the blessed artefacts — reproduced the same digest. Every run's outcome is recorded in
`provenance.json → stability.per_run` regardless of exit code, and REFUSED is tracked separately
from DIFFERED (bead oo-jor: collapsing the two is how a stability claim goes dishonest).

## The frame: both properties asserted, both measured

Unlike scenario 015 — whose animated trumble HUD put its same-scene pairs at 1.08×–2.49× the
calibrated tolerance, forcing it to assert liveness only — this scenario's scene is a docked market
view with no animated population:

| measurement | value | × tolerance (0.004377) |
| --- | --- | --- |
| same-scene pairs, 45 pairs over 10 runs | 0.001371 – 0.001583 | 0.31× – 0.36× |
| all-black vs a real frame | 0.052081 – 0.052163 | 11.9× |
| all-white vs a real frame | 0.947837 | 216× |
| nearest **different** scene (015's blessed frame) | 0.025412 | 5.8× |
| scenario 009's frame | 0.124363 | 28.4× |

Separation ratio **16.05** = nearest-different-scene ÷ worst same-scene. Signal is 16× the noise, so
the equality assertion is available here and **is** made, alongside liveness — which the tolerance
alone would not catch, because two black frames match each other perfectly.

## The deliberate asymmetry

`state.json` is **hashed byte-wise** and its sha256 + byte count are recorded in `provenance.json` —
a **separate file a mutant does not touch** — because a golden cannot witness itself: perturbing the
golden alone moves *both sides* of a golden-vs-copy comparison (bead oo-gxp measured that mutant
surviving).

`frame.grid` is **never byte-gated**. llvmpipe is not bit-reproducible: this scenario's own sweep
produced **10 distinct frame-grid digests over 10 byte-identical dumps**. Frames are compared with
the tolerance bead oo-ae9 *measured*, used as measured and never adjusted to make a run pass.

## Determinism sources switched off

Three, in this order, before any slow probe — order is load-bearing, not tidiness (scenario 010
measured eight of ten runs refusing when suppression came after a multi-second probe):

1. `system.setPopulator(key, null)` for every populator setting;
2. `hasNPCTraffic = false` on every station (`StationEntity.m:960-995` runs its own schedule);
3. `worldScripts['oolite-populator'].systemWillRepopulate` replaced with a no-op — its station
   picker ends with an unconditional `return system.mainStation`, so the flag alone does not stop it.

Then `quiesce()` drives clear-and-settle to a **fixed point** and refuses rather than hanging if the
world never reaches one.
