# Mining and Manufacturing — Design Sketch

Nov 2, 2026 · @Jon Seaman

How a mining and manufacturing career could work in Oolite, in the shape EVE Online uses: mine
several kinds of rock, acquire blueprints, manufacture items, then fly with them. The EVE mechanics
quoted here are in [EVE Online — Feature Reference](<EVE Online — Feature Reference.md>); the
Oolite claims are cited to `oolite-dev` and were read back against the source.

Nothing here is scheduled. The roadmap runs to phase 6 and is all port and platform work, so this
is an idea for afterwards, written down while it is fresh.

## The loop

**Prospect → mine → refine → manufacture → fit or sell.**

Find a field worth working and learn what its rocks hold. Crack them with a mining laser and scoop
the fragments: bulky, cheap ore, by the tonne. Refine the ore into compact materials measured in
kilograms and grams, which barely touch your hold. Spend those materials, a blueprint and some
hours of station time on an item — equipment, ammunition, or a trade good. Fit the item, or sell it.

Two properties make that a career rather than a chore. Each ore refines into a *different mix* of
materials, so which rock you mine depends on what you mean to build. And the valuable ores sit in
the dangerous systems, so the galaxy map starts to matter to a miner.

## What Oolite already has

This is the strongest argument for the feature. It lights up five pieces of machinery that exist
and currently do almost nothing.

| Piece | State today |
|---|---|
| Gold, platinum and gem-stones | **No source anywhere in the game.** No code path turns a rock into any of them; the only core award is 100 g of gem-stones from the nova mission (`oolite-nova-mission.js:237`). They are three commodities you can only ever buy |
| Rock hermits | One guaranteed per non-nova system (`oolite-populator.js:188-213`), tech level 1, `market_monitored = no` so contraband trades freely, and a `market_definition` that exports the `oolite-mining` class at 0.8× price and 3.5× quantity. A whole station type with almost nothing to do |
| The `"miner"` role weight | Incremented on **every asteroid the player cracks** (`PlayerEntity.cpp:5209-5219`), promoted into the 8-slot `roleWeights` ring at each power of two, readable as `player.roleWeights`. Already tracked, never shown |
| The t/kg/g unit system | `quantity_unit` 0/1/2, and up to 499 kg or 499,999 g of a good rides in the "safe" at **no cargo cost** (`PlayerEntity.h:2031-2034`). Tuned, and currently used by three commodities |
| Deterministic asteroid fields | 2–8 clusters of 1–11 rocks on the two space lanes, `deterministic: true` off `system.scrambledPseudoRandomNumber` (`oolite-populator.js:139-186`). Stable per system, so a survey layer needs no saved state |

And the mechanisms a career would be built from, all present:

| Mechanism | Where |
|---|---|
| Breakup chain, data-driven | `ShipEntity.cpp:8686-8757`. `debris_role`, `likely_cargo`, `no_boulders`; `n_rocks = 2 + (Ranrot() % (likely_cargo + 1))`, so 2–6 children per level, two levels deep |
| Any entity can carry any commodity | `cargo_carried = "3 gold"` (`ShipEntity.cpp:985-1025`), so new ore-bearing splinters are a pure data change |
| Commodity classes | `oolite-mining`, `oolite-rawmaterial`, `oolite-metals`, `oolite-salvage`, `oolite-machinery`, `oolite-shipyard`. Station `market_definition` rules already match on them (`OOCommodities.cpp:386-396`) |
| Station services on F4 | `station.setInterface(key, {title, summary, callback, category})` (`OOJSStation.cpp:1067`) |
| Clock-based jobs | `clock.adjustedSeconds`; `installation_time` and `repair_time` already add hours to the clock on purchase |
| Script state in save games | A JSON blob in `missionVariables`, written in `playerWillSaveGame` — how the whole contract system works (`oolite-contracts-cargo.js:149-176`) |
| Equipment you can only earn | `oolite-conditions.js:38-60` blocks `EQ_CLOAKING_DEVICE` in the `purchase` and `newShip` contexts while allowing repair, and gates `EQ_NAVAL_ENERGY_UNIT` on a mission variable |

Nothing resembling refining, crafting, recipes or blueprints exists in core. Grepping `src` and
`Resources` for `refine`, `smelt`, `craft`, `recipe`, `blueprint`, `manufactur` and `ore` finds only
unrelated prose and GPU `fragment_shader` keys.

**And the number that explains why mining isn't a career.** One asteroid yields 4–36 splinters, each
1 t of `minerals` at a `price_average` of 120 decicredits — 12 CR a tonne. A full 20 t hold of mined
minerals is worth about **240 CR**. Mining pays nothing, so nobody mines.

## What carries over from EVE, and what doesn't

Five mechanics are worth taking.

1. **Ore refines into different mineral mixes.** Veldspar is pure Tritanium, 400 units per 100-unit
   batch; Hedbergite gives Pyerite and Nocxium; Mercoxit is the only source of Morphite. What you
   mine is decided by what you intend to build. This is the mechanic that makes several ore types
   meaningful rather than decorative, and it is the core of this sketch.
2. **Materials monopolised by region.** EVE's 2020–22 Resource Redistribution deliberately made each
   security band the sole supplier of certain minerals — high-sec Tritanium, low-sec Isogen and
   Nocxium, null-sec Zydrine, Megacyte and Morphite — specifically to force hauling and trade.
   Oolite has the same shape in `government`, and government is already the one system property that
   touches asteroid fields, picking hermit allegiance in `oolite-populator.js:2455-2473`.
3. **Compression.** EVE compresses ore to 1% of its volume, free and untaxed, and it is the only
   reason a mining session lasts longer than the seven minutes it takes to fill a Hulk. Oolite's
   t → kg → g units with the free 499 kg safe are the same idea, already built.
4. **Critical mining hits.** New in EVE's Catalyst expansion, November 2025: a base 1% chance per
   cycle of 200% bonus yield, with audio and visual feedback, and **the crit does not deplete the
   asteroid**. Skills and modules raise the chance to roughly 30–50%. It is the cheapest possible
   fix for "holding a laser on a rock is boring", and in Oolite it is a few lines in the
   fragmentation path.
5. **Blueprints gate capability, not credits.** What a blueprint buys you is access to an item. The
   money is a side effect.

Five are worth refusing, and EVE supplies the evidence for each.

| Refuse | Why |
|---|---|
| **Mining residue** — lasers destroy extra ore in the rock on a roll | Widely disliked; CCP had to cut tech 1 gear from 100% residue to 0% after launch. It is punishment without a decision attached |
| **Long blueprint research, and two axes of it** | Material efficiency 10 on a destroyer blueprint is 89 days of base research time; on a dreadnought, **790 days**. That is an asset-ownership game. One grade axis, hours to days |
| **Multi-stage reaction chains** | Every tech 2 module in EVE sits behind moon drill → ore → reprocess → intermediate reaction → composite reaction → components. Four player-run stages is a corporation's work, not one pilot's |
| **Anything needing a fleet** | Catalyst's Phased Asteroid Fields need 100 energy from a Rorqual, or three Porpoises, to mine at full rate. Oolite has one ship |
| **Balancing the career on credits** | EVE's own Monthly Economic Report had the mineral price index down about 52% year on year through early 2026, with mining at roughly 10M ISK an hour against far better earners. An extraction career balanced on sale price decays into a chore |

One EVE idea is worth recording as a curiosity. Catalyst's **Prismaticite** refines into a *random*
one of the eight minerals, and the way you remove the randomness is to research a reaction for it —
industry as the control knob on an RNG ore. Elegant, possibly a late addition, not load-bearing.

## Rock classes and ores

Four common classes and one rare, each a `shipdata.plist` template with its own `debris_role` chain
and a splinter that carries a named ore through `cargo_carried`. `minerals` stays as the baseline so
nothing already in the game breaks.

| Rock class | Appearance | Ore | Where |
|---|---|---|---|
| Carbonaceous | the current grey asteroid | `minerals` (existing) | everywhere, commonest |
| Silicate | pale, glassy | `oolite-silicates` | everywhere |
| Ferrous | rust-streaked | `oolite-ferrous-ore` | most systems |
| Cupric | dark with bright flecks | `oolite-metallic-ore` | uncommon, weighted to low government |
| Pitchblende | near-black, faintly warm | `oolite-pitchblende` | rare; anarchies and feudal systems |

New commodities take the `oolite-` prefix, which is what `trade-goods.plist`'s own header comment
asks of new goods — the unprefixed core names are a compatibility holdover and new goods have no
such legacy. Five new commodity keys in total: four ores and one refined material.

Alternate textures already exist for asteroids, boulders and splinters (`oolite_alt_boulder`,
`oolite_alt_splinter`), so the visual work is a diffuse map per class, not new geometry.

## Refining, and why it is the spine

Ore is tonnes and nearly worthless. Refined material is kilograms and grams and rides mostly free.
That conversion is what makes mining survivable in a 20–35 t hold, and the engine already has it.

Illustrative yields per 10 t of ore — **the numbers are a starting point, and tuning them against
trade income is the real work**:

| Ore | Refines into | Rough value of the output |
|---|---|---|
| `minerals` | 2 t `alloys` | ~78 CR |
| `oolite-silicates` | 1 t `alloys` + 12 g `gem_stones` | ~274 CR |
| `oolite-ferrous-ore` | 3 t `alloys` + 200 kg `oolite-rare-earths` | tune to ~1,500 CR |
| `oolite-metallic-ore` | 120 kg `gold` + 20 kg `platinum` | ~6,100 CR |
| `oolite-pitchblende` | 2 t `radioactives` + 60 kg `platinum` + 40 g `gem_stones` | ~5,100 CR, and illegal to carry out of some systems |

Note what the units do. 120 kg of gold and 20 kg of platinum are both under the 499 kg safe, so
10 t of ore becomes about 6,100 CR that **occupies no cargo space at all**. Against 10 t of
`minerals` at 120 CR, that is a factor of fifty, achieved entirely with mechanics already in the
game. This is the single most important thing in the design.

A caution that falls straight out of the existing prices. `gem_stones` are 196 decicredits **per
gram**, so a gram-unit good is worth 19.6 CR a gram — and the safe carries 499,999 g of it free,
about **9.8M CR with no cargo cost**. Any ore that yields grams must yield very few of them, and
the gram unit is better reserved for a trophy output than a routine one. The kilogram unit, at
roughly 39–72 CR, is the right home for ordinary refined material.

Three places to refine, each with a yield and a catch:

| Where | Yield | Catch |
|---|---|---|
| Rock hermit | Poor | Takes anything and asks nothing (`market_monitored = no`). One per system, so always nearby |
| Main station, industrial economy | Good | Logs what you bring in; illegal ore earns a fine |
| Shipboard refinery (a new `EQ_` item) | Worst | Costs hold space through `requires_cargo_space`, runs on the clock, but lets you keep mining instead of hauling |

Yield is modified by the station's `equivalent_tech_level`, the refinery's grade, and the player's
`miner` standing — which is EVE's yield-from-structure-rigs-skills-standings formula, built from
inputs Oolite already has. The passenger berth is the existing template for a hold-consuming,
multiply-fittable module with a paired removal item (`equipment.plist:245-258`).

## Prospecting

Fields are already deterministic per system, so each system's rock composition can be derived from
its seed with no saved state — `system.scrambledPseudoRandomNumber(salt)` exists for exactly this
and its own documentation asks callers to use a distinct salt per decision so different features
don't cluster. A `planetinfo.plist` key overrides composition per system, the way other per-system
data works.

Then two pieces of kit:

- **A survey readout** on the chart or system-data screen: what this system's fields hold and how
  rich they are. This answers the complaint in the ideas doc directly — *"I don't know how to find
  asteroid fields."*
- **An ore surveyor** that names a targeted rock's class and ore in flight, with the value shown in
  space. EVE shipped exactly this in Catalyst and put it on every starter hull, which is an argument
  for not hiding it behind a tech level.

## Blueprints

A new file, `Config/blueprints.plist` — or JSON5 if phase 5b lands first. Per entry: the output (an
equipment key or a commodity), the inputs, a credit fee, a duration in hours, a minimum tech level,
and how it is acquired.

Inputs may name a **commodity class** rather than a key, reusing the existing `classes` taxonomy, so
an expansion's own metals can substitute for the core ones without the blueprint knowing about them.

Four ways to get one:

| Route | Shape |
|---|---|
| Bought | Listed at stations above a tech level. Stock is day-stable, using the deterministic "bargain tech day" pattern already in `setGuiToEquipShipScreen` (`day = i*13 + floor(time/86400)`), so availability is learnable rather than a slot machine |
| Mission reward | The hook the five core missions and the contract reputations already provide |
| Salvaged | A damaged data core scooped from wreckage as a scripted-item pod, useless until researched |
| Researched | A station service that turns a damaged or partial blueprint into a usable one, over clock days, for credits |

One quality axis, not EVE's two: a blueprint has a **grade 1–5**, and each grade cuts the material
cost. Research raises the grade. Time efficiency as a separate axis is bookkeeping the screens don't
want.

Blueprints are not cargo. They live in a JSON blob in `missionVariables`, like every contract, and
show on an F4 entry.

## Manufacturing jobs

A station service registered with `setInterface` on `shipDockedWithStation`, gated on the station's
tech level and the system's economy, under a new `interfaces-category-industry` heading — the tenth
category beside the nine in `descriptions.plist:1864-1872`.

1. Pick a blueprint you hold.
2. The screen shows its inputs against your manifest, the fee, and the finish time.
3. Accept. Inputs leave the manifest, credits are debited, and the job is recorded with
   `deadline = clock.adjustedSeconds + hours * 3600`.
4. Fly away and do something else.
5. Dock after the finish time and collect: equipment through `awardEquipment`, commodities into the
   manifest.

One job slot to begin with, more with standing. The fee scales with a queue-pressure term derived
from the system's productivity and economy, which is EVE's self-balancing system cost index for
free: building in a rich industrial system is cheap, building at a rock hermit is dear, and crowding
a system raises everyone's fees.

Jobs run **hours to a few days**, not EVE's weeks. Oolite has no time acceleration outside debug
builds, so a job longer than a few days of game time is dead time rather than a decision.

## What you can build, and the balance rule

State the rule first, because it decides whether any of this is worth playing.

> **Manufacturing must not out-earn trading in credits per hour. It pays in things you cannot buy.**

EVE's mineral price index fell by about half in a year and mining became the career people do while
watching something else. An extraction chain balanced on sale price decays into a chore. Balance
this one on capability instead.

| Output | Why it matters |
|---|---|
| **Equipment above the local tech level** | The best reward in the list. It breaks the tech-level wall that otherwise forces long hauls to buy one item |
| **Equipment sold nowhere** | New `EQ_` keys awarded only by a job, using the cloaking device's existing pattern — a condition script returning false for `purchase` and true for `scripted`. The ideas doc already wants kit with no core analogue: proximity mines, laser cooling, heat sinks, field repair units, drones. Those become blueprint outputs instead of shop stock |
| **Ammunition and consumables** | Missiles and mines are already `can_carry_multiple`, so building your own from mined metal is the tightest loop available |
| **Upgraded variants** | `_MK2` keys with better `weapon_info` — Elite Dangerous's engineering through the blueprint system rather than a second mechanic, made cheap by `equipment-overrides.plist` (a retuning hook the engine reads at `ResourceManager.cpp:1709`; core ships no such file) and `OOEquipmentType::addEquipmentWithInfo()`, which registers equipment at runtime |
| **Trade goods** | The dull option. It should pay worse than hauling, so it is a sink for surplus rather than the point |

## The career ladder

The engine already counts the career and shows it nowhere. Surface the `"miner"` weight as a mining
or industry rating on F5 beside the combat rating, and gate refining yield, job slots and blueprint
grades on it.

Then mining contracts on F4, mirroring `oolite-contracts-cargo.js`: a named ore, a quantity, a
deadline, a client. Elite Dangerous has these and Oolite's contract machinery is already three
quarters of the implementation.

## What this needs from C++

Most of it is data and a world script. Five engine changes earn their place.

1. **Generalise the breakup chain** (`ShipEntity.cpp:8686-8757`). The two-level depth and the
   `minerals` fallback are hardcoded. Ore yield should come from shipdata.
2. **Mining feel** — crit rolls, a shorter laser cycle with proportionally fewer splinters, and
   stochastic rather than truncating rounding. Small, contained, and the highest value per line in
   the whole design.
3. **The in-flight surveyor display.** Scripts cannot draw in flight. `player.consoleMessage()` is a
   cheap first cut; a real dial is HUD work.
4. **Per-station persistent state.** Only `missionVariables` persists, and `localMarket` is saved for
   the main station alone, so a job left running at a secondary station has nowhere honest to live.
   Keying a blob by galaxy, system and station role works, but it is a hack.
5. **A fourth reputation.** `contractReputation`, `parcelReputation` and `passengerReputation` are
   hardcoded in `OOJSPlayer.cpp:142-159` and in the save game. A mining reputation either joins them
   in C++ or lives in `missionVariables` and is not a real sibling.

The screens should wait for RmlUi (spec 007). The contract scripts align their columns by hand with
`_paddingText` and pad to 21 or 27 lines; a manufacturing screen is a table and a form, which is
what RmlUi makes cheap. Hand-rolling another padded text page would be work thrown away.

## Risks

**The biggest one: mining is tedious before any of this is built**, and no amount of refining and
manufacturing stacked on top will fix it. Today it is 2–6 boulders per asteroid, 2–6 splinters per
boulder, each scooped individually, on a 2.5 s laser recharge. EVE hit this exact wall and the fix
is worth copying:

- **Shorten the cycle and scale yield down to match.** Catalyst cut mining lasers from 60 s to 15 s
  and strip miners from 180 s to 45 s, reducing per-cycle yield in proportion — the same ore per
  hour, four times the feedback. Here that means a faster laser with fewer splinters per hit.
- **Add crits.** Occasionally exciting, never punishing.
- **Show value in space**, as the prospecting section says.

Sequence that work first. A mining career built on an unpleasant mining loop is a worse use of the
effort than fixing the loop and stopping there.

The rest:

- **Hold size.** 20–35 t against EVE's effectively unlimited barges. Refining compression is the
  answer and it has to be generous, or mining stays pointless.
- **No time acceleration**, so job durations are bounded. Related: the time-acceleration idea in the
  ideas doc would loosen this.
- **Balance against trading**, per the rule above.
- **Expansion compatibility.** New commodities appear in every station market and on every
  expansion's market screen. The corpus scan should look for scripts that enumerate goods.
- **One upstream bug to know about.** `OOCommodities.cpp:634-640` writes the *import* legality when a
  station `market_definition` sets `legality_export`. The comment says it is faithful to upstream, so
  it is preserved rather than introduced — but a design leaning on per-station export legality for
  unlicensed hermit refining will hit it.

## Not in this design

- **Player-owned refineries and outposts.** The ownership layer; a step beyond this one.
- **Unattended mining rigs**, in the style of Elite II's MB4. EVE's passive Metenox Moon Drill, which
  harvests automatically at 40% of the manual rate in exchange for fuel, is the modern precedent.
- **Corporation-scale industry.** Oolite is single-player.
