# EVE Online — Modules and Fitting Reference

Nov 3, 2026 · @Jon Seaman

Every module class in EVE Online, what it does, and the mechanics that make fitting a ship a real
optimisation problem rather than a shopping list. This is the companion to
[EVE Online — Feature Reference](<EVE Online — Feature Reference.md>), which covers the game as a
whole and summarises ships and fitting in one section; everything here goes a level deeper, and the
two overlap on purpose.

Oolite's equipment model is a flat list gated by tech level and price, with one item per slot and no
budget beyond the hold. EVE's is the opposite extreme: a dozen module families, three competing
fitting budgets, a stacking penalty, a meta ladder seven rungs deep, and a per-item randomiser on
top. It is worth reading not as a template — Oolite should not want most of this — but as the fully
worked version of questions Oolite's own feature list keeps raising: equipment mass, stackable
shields, wear and repair, subsystem targeting, engineering upgrades, drones.

**On sources.** Concrete numbers come from **EVE Ref**, generated from the game's own static data
export, or from the studio's patch notes and devblogs. EVE University is used for how mechanics work
rather than for what the numbers are — many of its module pages predate recent balance passes.
Anything that could not be verified is marked unclear rather than asserted. The studio renamed
itself from CCP Games to **Fenris Creations** in May 2026; this reference says CCP for things done
under that name. **Fractured Skies** ships on 10 November 2026, a week after this was written, so
any figure here may be a patch out of date by the time you read it.

## The fitting model

A hull in EVE is a set of budgets and a set of holes. Nothing about a ship is fixed except the
budgets; everything else is a choice made against them, and almost every choice costs something
elsewhere. This is the part of the design worth understanding before any individual module makes
sense.

### Slots

| Slot | What goes in it | Role |
| --- | --- | --- |
| **High** | Turrets, missile launchers, energy neutralisers and nosferatu, remote repairers, smartbombs, cloaks, probe launchers, tractor beams, salvagers, command bursts | Offence and remote assistance |
| **Mid** | Propulsion, warp disruptors and scramblers, webs, electronic warfare, **shield** modules, capacitor boosters, sensor boosters, target painters | Control, range and shield tank |
| **Low** | **Armour** modules, damage amplifiers, capacitor and powergrid relief, nanofibres, inertial stabilisers, warp core stabilisers | Armour tank, damage, and fitting relief |
| **Rig** | Rigs only, paid for in calibration rather than CPU or powergrid | Permanent specialisation |
| **Subsystem** | Tech 3 strategic cruisers only — four subsystems that define the hull itself | — |

Two extra counts sit on top of the slot counts and are easy to miss: **turret hardpoints** and
**launcher hardpoints**. A hull with six high slots and three turret hardpoints can fit only three
turrets; the other three highs must hold something else. This is why utility highs exist as a
concept, and why a "spare high" for a neutraliser or a cloak is a real fitting decision.

### The coupling that makes it interesting

Because **shield modules live in mid slots and armour modules in low slots**, and mids are also
where tackle, propulsion and electronic warfare go, tank choice is not merely defensive:

- A **shield** ship spends mids on extenders and hardeners, so it gives up the points, webs and
  damps it would otherwise carry — but keeps its lows for damage amplifiers.
- An **armour** ship spends lows on plates and hardeners, so it gives up damage modules — but keeps
  its mids for control.

That single layout decision produces most of EVE's fitting culture, and it is the cheapest idea in
this whole document to borrow.

### Three budgets

| Budget | Where it comes from | What happens if you exceed it |
| --- | --- | --- |
| **CPU** (teraflops) | The hull, plus CPU Management skill, co-processors and engineering rigs | The module cannot be brought online |
| **Powergrid** (MW) | The hull, plus Power Grid Management, reactor control units, power diagnostics | The module cannot be brought online |
| **Calibration** | The hull — **400 on most hulls** | The rig cannot be fitted |

Rig slots are separate from the count: **tech 1 hulls get three, tech 2 hulls get two**, and
freighters, shuttles and corvettes get none at all.

Beyond those three, two hull statistics act as hidden budgets. **Mass** drives align time and so
determines whether you can escape; **signature radius** determines how easily turrets hit you and
how fast you can be locked. Several of the strongest modules in the game raise one of those two as
their cost — armour plates add mass, shield extenders and an active microwarpdrive add signature.

### The stacking penalty

When several modules apply **the same effect**, only the strongest gets its full value. The rest are
multiplied by a curve, sorted strongest first:

```
multiplier(n) = exp( −((n − 1) / 2.67)² )
```

| Module | 1st | 2nd | 3rd | 4th | 5th | 6th | 7th |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Effectiveness | **100%** | 86.9% | 57.1% | 28.3% | 10.6% | 3.0% | 0.6% |

A third adaptive nano plating adds a fraction of what the first did; a fifth is a rounding error.
The elegance is that **nothing is forbidden** — the game never says "you may fit only two" — and yet
nobody fits five, because the fourth and fifth are visibly wasted slots. It also means the answer to
"what should I fit?" is almost always *a mixture*, which is what makes fits diverse.

Not everything is penalised. Resistances stack multiplicatively against the *remaining*
vulnerability rather than additively, so hardeners never reach 100%; raw hit points from extenders
and plates stack **without** penalty, which is precisely why buffer tanking is the fleet standard.

### Capacitor as a resource

Capacitor is the other budget, and it recharges on a **non-linear curve that peaks at about 25% of
capacity** and collapses below it. That produces a genuine decision point in every fight: a ship
below a quarter capacitor is not merely low, it is losing the ability to recover, which is the basis
of the standard advice to disengage before you get there.

A fit is called **cap stable** if its running modules draw less than the capacitor regenerates at
equilibrium. Active armour and shield repair, microwarpdrives and energy neutralisers all compete
for the same pool, which is why **capacitor warfare kills active tanks** and why buffer fits, which
spend nothing, are immune to it.

### What this costs the player

The honest assessment: EVE's fitting system is the deepest in the genre and the single largest
barrier to entry in the game. It cannot be learned in the client — the community's answer is
**Pyfa**, a third-party offline simulator, and the "shared fit" posted in a doctrine document. The
in-game fitting window gained a simulator in 2016, which helped, and the game still expects you to
read a spreadsheet to understand your own ship.

[EVE University: Fitting](https://wiki.eveuniversity.org/Fitting), [Stacking penalty](https://wiki.eveuniversity.org/Stacking_penalty), [Capacitor](https://wiki.eveuniversity.org/Capacitor), [Rigs](https://wiki.eveuniversity.org/Rigs), [Tanking](https://wiki.eveuniversity.org/Tanking)

## The quality ladder

Almost every module in EVE exists at several quality levels, and the ladder is seven rungs deep.
This is the mechanism that gives the game a loot economy, a manufacturing economy and a reason for
rare NPC spawns to matter, all from one piece of structure.

Each module carries a **meta level** attribute, and the rungs map onto it:

| Rung | Meta | Where it comes from | How good |
| --- | --- | --- | --- |
| **Tech 1** | 0 | Manufactured from minerals | The baseline, and the volume bracket of the game |
| **Meta**, or "named" | **1–4** | NPC loot drops | Better stats *and/or* **easier to fit** — lower CPU and powergrid. **No extra skills over tech 1** |
| **Tech 2** | **5** | **Invention**, plus specialisation skills | The competitive standard, usually harder to fit. For weapons the real payoff is that it **unlocks tech 2 ammunition** |
| **Storyline** | 6–7 | Mission and epic-arc rewards | Inconsistent, usually near tech 2, with meta-grade fitting costs |
| **Faction**, navy and pirate | 6–12 | Loyalty-point stores and rare loot | Tech 2 stats or better with **reduced fitting cost**. Often the attraction is capacitor use or skills, not raw power |
| **Deadspace** | 7–16 | Rated complexes and rare spawns, graded **C → B → A → X** | C-type can be *worse* than tech 2; **X-type approaches officer grade** and runs into the billions. Mostly battleship-sized |
| **Officer** | 7–17 | Named rare spawns, asteroid belts only | The rarest, and **not always better than deadspace** — the stats have to be checked |
| **Abyssal** | – | Mutaplasmid-rolled from any of the above | Unique, and tradeable only by contract |

**One important asymmetry: turrets have no deadspace tier.** Across every turret family the ladder
runs tech 1 → meta → tech 2 → storyline → faction → officer, with nothing in between. Deadspace
modules are shields, armour, capacitor and propulsion — the defensive and support half of the game.
So the most expensive *gun* in EVE is an officer module, while the most expensive *tank* has a whole
extra rung to climb.

Two things about this ladder are better designed than they first appear.

**Meta modules being easier to fit** means the cheap loot rung is not simply worse — it is the answer
to a different problem. A new pilot whose powergrid is too small for a tech 2 weapon fits a meta one
and it works. The ladder is not strictly ordered, so there is a real decision at every rung.

The clearest illustration is the **meta 4 trap**. A Heavy Modulated Pulse Energy Beam I — a meta 4
loot drop — has the *same* 12,600 m optimal range as a Heavy Pulse Laser II, needs **26 teraflops
against the tech 2 gun's 35**, and requires no specialisation skills at all. It is cheaper, easier to
fit and just as long-ranged. The only thing the tech 2 gun buys is the ability to load Scorch and
Conflagration crystals — which turns out to be worth it, but the point is that the player has to
know *why*.

**Faction modules trading power for fitting** does the same thing at the top. A faction module that
is marginally weaker than tech 2 but uses half the capacitor can make a fit possible that tech 2
cannot. "Best" depends on what the rest of the ship is already spending.

### Mutaplasmids and abyssal modules

Mutaplasmids, added with the Triglavian storyline, apply a **randomised reroll** to a module's
statistics, producing an "abyssal" variant. They come in grades — decayed, gravid, unstable and so
on — that trade how wide the possible range is against how likely the result is to be worse than
what you started with.

The consequences are worth noting as design:

- The result is **permanent and unique**. You cannot reroll the same module twice toward a target,
  so each attempt consumes a module and a mutaplasmid.
- It creates a market in **outcomes** rather than items. An abyssal module with a good roll on the
  statistic that matters for one doctrine is worth far more than its own base type, and it is traded
  by contract because the market cannot express "a good one".
- It gives the top of the ladder an **unbounded ceiling** without the studio having to design new
  modules, and it is a sink for both modules and mutaplasmids.

The honest criticism is that it adds a gambling layer to an already deep system, and that the best
fits in the game are now partly a function of who got lucky.

[EVE University: Faction modules](https://wiki.eveuniversity.org/Faction_modules), [Meta levels](https://wiki.eveuniversity.org/Meta_levels), [Mutaplasmids](https://wiki.eveuniversity.org/Mutaplasmids), [EVE Ref module pages](https://everef.net/)

## Turrets

EVE has three turret families, one per weapon-using empire, and each splits into a **short-range,
high-sustained-damage** variant and a **long-range, high-alpha, low-sustained** one. That two-by-three
grid is the whole of the game's direct-fire design, and the differences between the families are
about *what they cost you* rather than how much damage they do.

| Family | Empire | Resource cost | Damage types | Ammunition | Reload |
| --- | --- | --- | --- | --- | ---: |
| **Energy** (lasers) | Amarr | **Capacitor**, 13–180 GJ a shot | **EM and thermal only**, fixed ratio per crystal | Reusable **crystals** | **0 s** |
| **Hybrid** | Caldari and Gallente | Moderate capacitor, 1–75 GJ | **Kinetic and thermal only** | Consumable charges | 5 s |
| **Projectile** | Minmatar | **None at all** — 0 GJ | **All four, freely selected by ammunition** | Consumable ammunition | 10 s |

Amarr's bargain is the clearest: pay capacitor on every trigger pull in exchange for ammunition that
is free, infinite and never reloads — then discover that a laser boat is crippled by energy
neutralisers and can only ever deal two of the four damage types. Minmatar's is the mirror image:
nothing to recharge, every damage type available, and the worst sustained damage of the three.

### Energy turrets

Pulse lasers are the short-range variant; beam lasers reach much further, hit harder per shot and
track far worse.

| Module (tech 2) | Size | Damage mult. | Cycle | Optimal | Falloff | Tracking | Cap/shot |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Small Focused Pulse Laser II | S | 3.60× | 3.5 s | 6,300 m | 2,500 m | 246 | 4 GJ |
| Small Focused Beam Laser II | S | 5.40× | 5.0 s | 13,200 m | 2,500 m | 90 | 9 GJ |
| Heavy Pulse Laser II | M | 3.60× | 5.25 s | 12,600 m | 5,000 m | 26 | 13 GJ |
| Heavy Beam Laser II | M | 4.50× | 6.0 s | 26,400 m | 8,000 m | 9.5 | 22 GJ |
| Mega Pulse Laser II | L | 3.60× | 7.875 s | 25,200 m | 10,000 m | 3.4 | 36 GJ |
| Tachyon Beam Laser II | L | 5.40× | 12.5 s | **52,800 m** | 20,000 m | 1.39 | 76 GJ |
| Quad Mega Pulse Laser II | XL | 1.26× | 6.0 s | 36,300 m | 16,000 m | 1.5 | 180 GJ |
| Dual Giga Beam Laser II | XL | – | 15 s | **110,000 m** | – | – | 520 GJ |

**Frequency crystals** are the distinctive part: they load once and fire forever. Tech 1 crystals
never degrade at all; tech 2 ones wear out. The ladder trades range against damage, and medium
crystals are exactly twice the small values, large four times, extra-large eight.

| Crystal | Optimal | Capacitor need | Small damage | Split |
| --- | ---: | ---: | ---: | --- |
| **Multifrequency** | **×0.50** | baseline | 12 | 7 EM / 5 thermal |
| Gamma | ×0.625 | −15% | 11 | 7 / 4 |
| Xray | ×0.75 | −25% | 10 | 6 / 4 |
| Ultraviolet | ×0.875 | −35% | 9 | 6 / 3 |
| Standard | ×1.00 | **−45%** | 8 | 5 / 3 |
| Infrared | ×1.20 | −35% | 7 | 5 / 2 |
| Microwave | ×1.40 | −25% | 6 | 4 / 2 |
| **Radio** | **×1.60** | −15% | 5 | **5 EM / 0** |

Note that capacitor cost is a shallow **V**, cheapest in the middle at Standard — so the longest-ranged
crystal is not the most efficient one, and the ladder is not a straight line.

The tech 2 crystals are where lasers become distinctive:

| Crystal | Gun | Optimal | Tracking | Cap | Effect |
| --- | --- | ---: | ---: | ---: | --- |
| **Scorch** | Pulse | **×1.40** | ×0.75 | 0 | +40% range at about 92% of Multifrequency damage |
| Conflagration | Pulse | ×0.50 | ×0.70 | +25% | The highest short-range damage in the family |
| **Aurora** | Beam | **×1.80** | ×0.25 | – | Sniping |
| Gleam | Beam | ×0.25 | ×1.25 | – | Close-range beams |

**Scorch is arguably the most important charge in the game.** Forty percent more range for almost no
damage loss and no capacitor penalty is why Amarr pulse ships fight at ranges that blasters and
autocannons simply cannot answer.

### Hybrid turrets

Blasters are the shortest-ranged and highest-damage guns in EVE; railguns are the mid-point between
artillery and beams.

| Module (tech 2) | Size | Damage mult. | Cycle | Optimal | Falloff | Tracking |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Light Neutron Blaster II | S | **4.41×** | 3.5 s | **1,800 m** | 2,500 m | 380 |
| 150mm Railgun II | S | 3.63× | 4.25 s | 14,400 m | 6,000 m | 73.5 |
| 200mm Railgun II | M | 3.04× | 4.46 s | 19,440 m | 9,000 m | 7.2 |
| Neutron Blaster Cannon II | L | **4.41×** | 7.875 s | 7,200 m | 10,000 m | 5.2 |
| 425mm Railgun II | L | 3.63× | 8.13 s | 51,840 m | 21,600 m | 1.05 |
| Triple Neutron Blaster Cannon II | XL | 0.92× | 5.0 s | 17,600 m | 20,000 m | 2.3 |

The blaster signature is that **falloff exceeds optimal** — a Light Neutron II has 1,800 m of optimal
and 2,500 m of falloff — so blasters are mathematically a falloff weapon and their usable range is
mostly the fuzzy half.

Hybrid charges run **Antimatter** (×0.50 range, 12 damage small) down to **Iron** (×1.60, 5 damage) on
the same eight-step ladder as crystals, in kinetic and thermal only. Tech 2 adds **Null** (+40%
optimal *and* +40% falloff) and **Void** (the damage charge) for blasters, **Spike** (×1.80 range) and
**Javelin** for railguns.

### Projectile turrets

| Module (tech 2) | Size | Damage mult. | Cycle | Optimal | Falloff | Tracking |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 200mm AutoCannon II | S | 3.47× | 3.75 s | 1,200 m | **5,160 m** | 315 |
| 250mm Light Artillery II | S | 6.10× | 8.5 s | 9,660 m | 8,750 m | 80 |
| 425mm AutoCannon II | M | 3.47× | 5.46 s | 2,400 m | **10,836 m** | 33.8 |
| 720mm Howitzer Artillery II | M | 9.57× | 18.0 s | 24,000 m | 17,500 m | 6.7 |
| **1400mm Howitzer Artillery II** | L | **12.81×** | **40.2 s** | 48,000 m | 35,000 m | 0.9 |
| Quad 3500mm Siege Artillery II | XL | 11.86× | – | **103,400 m** | – | – |

Autocannons are the most extreme falloff weapon in the game — the 425mm has **four and a half times
more falloff than optimal**. Artillery sits at the other pole: the 1400mm Howitzer has the highest
damage multiplier of any turret and a **forty-second cycle**, which makes it the alpha weapon of
choice and nearly useless against anything small and moving.

Projectile ammunition is the only one that selects damage type freely, which is the family's real
advantage:

| Ammunition | Optimal | Tracking | Damage |
| --- | ---: | ---: | --- |
| **EMP** | ×0.50 | – | **EM**-dominant |
| **Fusion** | ×0.50 | – | **Explosive** — 4 kinetic / 20 explosive at medium |
| **Phased Plasma** | ×0.50 | – | **Thermal** — 4 kinetic / 20 thermal |
| Titanium Sabot | ×1.00 | **+20%** | **Kinetic**-dominant |
| Depleted Uranium | ×1.00 | **+20%** | A spread: 4 kinetic / 6 thermal / 6 explosive |
| Proton, Nuclear, Carbonized Lead | ×1.60 | +5% | EM, explosive and kinetic long-range variants |

Tech 2 adds **Barrage** (+50% falloff for autocannons), **Hail** (damage), **Tremor** (×1.80 range for
artillery) and **Quake**.

### Sizes, hardpoints, and the thing that replaces firing arcs

| Size | Hulls | Pulse tracking |
| --- | --- | ---: |
| Small | Frigates, destroyers | 246 |
| Medium | Cruisers, battlecruisers | 26 |
| Large | Battleships, and the attack battlecruisers that mount large guns on a cruiser-sized hull | 3.4 |
| Extra-large | Dreadnoughts, supercapitals, structures | 1.5 |

**Tracking falls by roughly an order of magnitude per size class.** That one attribute — not a
separate damage-application rule — is what stops a battleship shooting frigates, and it is the same
job the missile explosion-radius formula does by other means.

Two counts gate high slots independently: **turret hardpoints** (which also gate mining lasers) and
**launcher hardpoints**. A hull can have more high slots than either, and the leftovers are "utility
highs" for a neutraliser, a cloak or a probe launcher. Cloaks, neutralisers, smartbombs, remote
repairers and command bursts need a high slot but no hardpoint.

Worth stating because it differs from Elite: **EVE has no fixed-versus-turreted distinction and no
firing arcs.** Every turret has unlimited traverse, and **signature resolution is 40,000 m on every
turret in the game regardless of size**. All of the "can this gun hit that target" work is done by
tracking against angular velocity, which means the pilot controls it by controlling *range and
transversal* rather than by pointing the ship.

### Reload, and the cost of changing your mind

| Family | Reload |
| --- | ---: |
| Energy | **0 s** — crystals are reusable |
| Hybrid | 5 s |
| Projectile | 10 s |

Changing ammunition mid-fight means eating the current cycle **and** the reload, which is why the
choice of what to load before undocking is a real commitment, and why Amarr's zero-reload crystals
are a quietly large advantage. Magazines are small and scale oddly: a 425mm AutoCannon II holds about
120 rounds, a 720mm Howitzer II only 20, and **every laser holds exactly one crystal**, because a
crystal is 1 m³ and so is the gun's magazine.

Faction ammunition adds **+10% damage for pirate, +15% for navy and +20% for elite pirate** variants,
with identical range and tracking. Faction crystals last about **4,000 shots against tech 2's 1,000**,
which makes them the value choice for long sessions rather than a power choice.

Tech 2 ammunition can only be loaded into **tech 2, faction, storyline and officer** guns — never
tech 1 or meta — and needs the matching Specialization skill, which itself needs the size skill at V.

### Hitting, and wrecking shots

```
chance = 0.5 ^ [ (angular × 40,000 / (tracking × signature))² + (max(0, range − optimal) / falloff)² ]
```

At optimal plus one falloff you hit **half** the time; at two falloffs, **6.25%**. Tracking behaves as
a threshold on angular velocity, and the three levers are exactly equivalent: **doubling tracking,
doubling the target's signature radius and halving its angular velocity all do the same thing.** That
equivalence is why a target painter helps every gun in a fleet, and why a stasis web is as much an
offensive module as a defensive one.

The damage roll shares the hit roll, producing a multiplier from 0.50 to 1.49× base — and below a
threshold the shot is a **wrecking hit at triple damage**. That small tail is why a frigate
occasionally kills something enormous, and why no engagement is strictly decided by the averages.

[EVE Ref: Heavy Pulse Laser II](https://everef.net/type/3520), [Mega Pulse Laser II](https://everef.net/type/3057), [Tachyon Beam Laser II](https://everef.net/type/3025), [Scorch M](https://everef.net/type/12818), [425mm AutoCannon II](https://everef.net/type/2929), [EVE University: Turrets](https://wiki.eveuniversity.org/Turrets), [Turret damage](https://wiki.eveuniversity.org/Turret_damage), [Tech and meta levels](https://wiki.eveuniversity.org/Tech_and_meta_levels)

## The other direct-fire weapons

Outside the three turret families sit six more weapon systems, and each one exists because it breaks
a rule the turrets obey. They are the most interesting weapons in EVE precisely because of that.

### Entropic disintegrators — damage that ramps

The Triglavian weapon is a continuous beam with **no falloff at all** and a damage multiplier that
climbs the longer it stays on one target.

| Heavy Entropic Disintegrator I | Value |
| --- | --- |
| Damage multiplier | **0.80×** — deliberately poor at the start |
| Cycle | 5.5 s |
| Optimal | 15,500 m, **no falloff** |
| Gain per cycle | **+7%** of base |
| Maximum | **+212.5%**, so **×3.125 at full spool** — about thirty cycles |

**Any deactivation resets it to base.** The target dying, the target leaving optimal, being jammed,
or simply switching targets all throw away the ramp. That one rule is the entire tactical identity
of the weapon: a Triglavian ship wants a long, uninterrupted fight against one target, and the
counter is not to out-tank it but to **make it stop shooting**.

Its ammunition, Exotic Plasma, runs on a completely different numeric scale from conventional
charges — hundreds of hit points per charge paired with sub-1.0 damage multipliers — with Tetryon at
×0.70 range, Baryon at ×1.10 and Meson at ×1.80.

### Vorton projectors — damage that chains

The EDENCOM weapon is direct-fire but **uses the missile damage formula rather than turret tracking**.
There is no tracking attribute, no falloff, and no tracking module or rig affects it.

Its distinctive mechanic is chaining: the shot hits the locked target, then **arcs to as many as nine
more ships or drones within 10 km of it**, for ten entities in total.

| Size | Cycle | Explosion radius | Explosion velocity | Optimal |
| --- | ---: | ---: | ---: | ---: |
| Small | 6 s | 43 m | 190 m/s | 22,460 m |
| Medium | 9 s | 143 m | 105 m/s | 34,560 m |
| Large | 15 s | 333 m | 79 m/s | 57,600 m |

It is the anti-swarm weapon, and the only gun in the game whose value rises with how tightly the
enemy is anchored — which is a direct counter to the fleet discipline that command bursts encourage.

### Smartbombs — no target at all

Point-blank area damage with **no targeting and no hardpoint**, just a high slot. Damage ignores
signature radius and speed entirely; only resistances matter.

| Size | Radius | Cycle | Damage, tech 1 → 2 | Capacitor |
| --- | ---: | ---: | ---: | ---: |
| Micro | ~2 km | 10 s | 25 → 35 | 15 GJ |
| Small | ~3 km | 10 s | 50 → 70 | 30 GJ |
| Medium | ~4 km | 10 s | 100 → 140 | 75 GJ |
| Large | ~5–6 km | 10 s | 250 → **300** | 200–220 GJ |

They hit **everything** in range — allies, your own drones, neutrals — which makes them the game's
only genuinely indiscriminate weapon, and a liability in a fleet. Their niche is killing drones,
missiles and frigate swarms that are too small or too fast for turrets to track.

### Bombs — a weapon with a fixed range

Launched from a stealth bomber's nose, a bomb flies **in a straight line and detonates at exactly
30 km** from the launch point, damaging everything in a 15 km radius of that point.

| Bomb | Effect | Amount |
| --- | --- | ---: |
| Concussion, Electron, Scorch, Shrapnel | Kinetic, EM, thermal, explosive | 5,800 each |
| **Void** | Capacitor neutralisation | 1,800 GJ |
| Focused Void | Capacitor neutralisation, capitals only | 15,000 GJ |
| **Lockbreaker** | ECM burst across all sensor types | 12.5 strength |

Three details make bombing a skill rather than a button. Damage scales against the target's
signature radius versus a **fixed 400 m explosion radius**, and unlike missiles **target speed is
irrelevant**. Bombs have very low hit points and can be **destroyed in flight** by defender missiles,
smartbombs, or other bombs — and because each damage type has its own bomb, a defending bomber can
throw a counter-bomb to annihilate an incoming volley. And only stealth bombers can fit a launcher,
**one per hull**.

### Doomsday devices — the largest numbers in the game

| Weapon | Damage | Geometry | Cycle |
| --- | --- | --- | --- |
| **Doomsday** | **2,400,000 in a single shot** | **One target, capitals only** | 5 min |
| Lance | up to 50,000/s | 2.5 km radius along a **200 km line** | 15 s |
| Reaper | up to 100,000/s | 5 km radius, 150 km, sweeping between two points | 10 s |
| Bosonic Field Generator | up to 40,000/s, all damage types | **30 km cone** | 20 s |
| GTFO | none | Teleports nearby subcapitals away and stops them warping for 60 s | — |

The single-target doomsday **cannot hit a subcapital at all** — it is a capital-killer by rule, not by
damage. Firing one immobilises the titan for thirty seconds and locks it out of docking, tethering,
cloaking and its jump drive for **five minutes**, which is the real cost: the biggest ship in the game
commits itself completely for the length of a small battle.

### Disruptive lances — a weapon that denies rather than kills

The four tech 2 "lancer" dreadnoughts carry a lance whose damage scales with the target's signature
radius, and which can only be fired **while the ship's siege module is running** — so the firer is
already immobile and uninterruptible.

What it does to the target for sixty seconds matters more than the damage: **warp and jump drives
disabled, tethering and docking disabled, and incoming remote repair cut by half.** It is a
logistics-and-escape denial weapon, and the counterpart to a doomsday rather than a smaller version
of one. The firer pays five minutes without docking, tethering, cloaking or jumping, and lancers can
never fit a cloak at all.

### Polarized weapons

A curiosity worth recording because the trade is so stark: polarized variants give higher rate of
fire and damage and **+200% ammunition capacity**, in exchange for **losing your resistances while
they are fitted**. They are a pure glass-cannon option in a game that otherwise never offers one, and
they exist mostly as a design statement.

[EVE Ref: Heavy Entropic Disintegrator I](https://everef.net/type/47273), [Tetryon Exotic Plasma M](https://everef.net/type/47886), [EVE University: Smartbombs](https://wiki.eveuniversity.org/Smartbombs), [Bombs](https://wiki.eveuniversity.org/Bombs), [Doomsday devices](https://wiki.eveuniversity.org/Doomsday_device), [Vorton projectors](https://wiki.eveuniversity.org/Vorton_Projectors), [CCP: Catalyst expansion notes](https://www.eveonline.com/news/view/catalyst-expansion-notes)

## Missiles

Missiles solve the same problem as turrets — hitting things of different sizes at different speeds —
by exactly the opposite method. **A missile always hits.** What varies is how much of its damage
arrives, and the formula that decides this is the most important piece of maths in the game's weapon
design.

### The damage-application formula

```
damage = D × min( 1 ,  S / E ,  ( (S × Ve) / (E × Vt) ) ^ drf )
```

| Term | Meaning |
| --- | --- |
| `D` | The charge's base damage |
| `S` | The **target's signature radius**, after target painters |
| `E` | The missile's **explosion radius** — the size of ship the warhead is shaped for |
| `Ve` | The missile's **explosion velocity** — how fast the blast front expands |
| `Vt` | The **target's current speed** at impact, after webs |
| `drf` | The **damage reduction factor**, the exponent on the velocity term |

Three details make this elegant rather than merely complicated. The terms are a **minimum, not a
product**, so only the single worst one applies. The result is **capped at 1**, so a missile can never
over-apply — a torpedo does not do extra damage to a titan. And the **damage reduction factor** is a
per-charge exponent that decides how *steeply* damage falls away with target speed, which is the dial
the designers use to separate one missile from another.

So a missile fired at something smaller than its explosion radius loses damage in proportion, and a
missile fired at something faster than its blast front expands loses damage again. Turrets answer the
same question with tracking and a chance to miss; missiles answer it with a guaranteed hit for reduced
damage. **Turrets are variance; missiles are attenuation.**

### The ladder

| Charge | Damage | Velocity | Flight | **Range** | Explosion radius | Explosion velocity | DRF |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| **Rocket** | 33 | 2,250 | 2.0 s | **4,500 m** | **20 m** | 150 m/s | 0.644 |
| Light Missile | 83 | 3,750 | 5.0 s | 18,750 m | 40 m | 170 m/s | 0.604 |
| Heavy Assault Missile | 100 | 2,250 | 4.0 s | 9,000 m | 125 m | 101 m/s | 0.882 |
| Heavy Missile | 149 | 4,300 | 6.5 s | 27,950 m | 140 m | 85 m/s | 0.682 |
| **Cruise Missile** | 375 | 4,700 | 14.0 s | **65,800 m** | 330 m | 69 m/s | 0.882 |
| **Torpedo** | 450 | 1,800 | 7.2 s | 12,960 m | **405 m** | 78 m/s | 0.944 |
| XL Cruise Missile | 4,750 | 7,000 | 15.0 s | **105,000 m** | **6,000 m** | 40 m/s | 0.882 |
| XL Torpedo | 5,885 | 3,480 | 7.5 s | 26,100 m | **10,000 m** | 42 m/s | **1.000** |
| Structure XL Cruise | 24,000 | 9,000 | 100 s | **900,000 m** | 15,000 m | 70 m/s | 0.944 |

Range is simply **velocity × flight time**, which has a consequence turrets do not share: there is
**no falloff**. A missile either reaches the target or expires in flight. Skills multiply both terms,
so Missile Projection and Missile Bombardment at V together give **×2.25 range** — a light missile
reaching 42 km.

### Why a cruise missile barely scratches a frigate

Take a frigate at 35 m signature radius moving at 400 m/s, and a cruise missile with a 330 m
explosion radius. The `S/E` term alone is **35 ÷ 330 ≈ 0.106**, so before the velocity term is even
considered the missile delivers about a tenth of its damage. The velocity term then makes it worse.

This is why the "rapid" launchers exist. A **Rapid Light Missile Launcher** puts *light* missiles — a
40 m explosion radius — on a cruiser, so a cruiser can actually hurt a frigate; a **Rapid Heavy**
does the same for a battleship. They pay for it with a punishing reload: a 35-second reload after a
20-missile magazine, giving about **78% uptime**. The whole family is a workaround for a damage
formula that would otherwise make cruisers helpless against frigates.

### The pairs

**Rockets against light missiles** is not a damage ladder but a range-and-application trade at the
same hull size. Rockets do 2.5× less damage per missile but fire far faster, for about **27% more
damage a second**, and have **half the explosion radius** — so they apply nearly fully to frigates.
Rockets are the brawling weapon, light missiles the kiting one, and the rocket's 4.5 km base range
sits neatly inside scram range.

**Heavy assault missiles against heavy missiles** is the same trade a tier up and inverted: heavy
assault missiles give up two thirds of the range for **26% more damage a second** and a smaller
explosion radius, but carry a much worse damage reduction factor, so they punish immobile targets and
struggle against moving ones.

### Ammunition

Four damage types, one per family: **Mjolnir** EM, **Inferno** thermal, **Scourge** kinetic, **Nova**
explosive — selected freely, which gives missiles the flexibility that only projectiles have among
turrets.

Tech 2 splits into two opposed variants, and the damage reduction factors in the table above show
exactly what they trade:

| Variant | Effect | DRF example, light missiles |
| --- | --- | ---: |
| **Precision** | Less damage, **much smaller explosion radius** — for hitting small things | **0.561** |
| **Fury** | More damage, larger explosion radius — for hitting big things | 0.682 |
| **Rage** and **Javelin** | The equivalents for heavy assault missiles, torpedoes and rockets | up to 0.967 |

### Support and counters

| Module | Effect |
| --- | --- |
| **Ballistic Control System** (low) | The missile damage amplifier — damage and rate of fire |
| **Missile Guidance Computer** (mid) | Range **or** precision, chosen by **script** |
| Missile Guidance Enhancer (low) | Both, passively, weaker |
| **Guidance Disruptor** (the counter) | −9% velocity and flight time, −12% explosion velocity, **+12% explosion radius** |
| Rigs | Warhead Calefaction (damage), **Rigor** (explosion radius), **Flare** (explosion velocity), Hydraulic Bay Thrusters (velocity) |

Note that **Rigor and Flare rigs attack the two terms of the damage formula directly** — one shrinks
the explosion radius, the other raises the explosion velocity — which is why a missile fit's rigs
matter more than they do on a turret boat. And a **target painter**, by raising `S`, improves the very
first term, which is why painters and missiles are such a natural pairing.

### The honest assessment

Missiles are widely described as newcomer-friendly with a low ceiling, and the reasons are structural.
They always hit, which removes the tracking skill curve, and they need no capacitor. But they have
**travel time**, so damage arrives late and a target can die, warp or be repaired before the volley
lands; they have **no alpha**, because the volley is spread across flight time; and their damage
application against small, fast targets is poor enough to need an entire extra launcher family as a
patch.

Where they excel is reach and flexibility: a cruise missile battleship projects 65 km of freely
selected damage type with no falloff at all, and a missile boat never cares which way it is facing.

[EVE Ref: Rocket Launcher II](https://everef.net/type/10631), [Light Missile Launcher II](https://everef.net/type/2404), [Rapid Light Missile Launcher II](https://everef.net/type/1877), [Scourge Cruise Missile](https://everef.net/type/203), [Scourge Torpedo](https://everef.net/type/267), [EVE University: Missile mechanics](https://wiki.eveuniversity.org/Missile_mechanics), [Missile damage](https://wiki.eveuniversity.org/Missile_damage)

## Shield modules

Shields live in **mid slots**, recharge on their own, and are the layer whose numbers are easiest to
make enormous. Every base hull starts with the same profile, and it has a hole:

| Layer | EM | Thermal | Kinetic | Explosive |
| --- | ---: | ---: | ---: | ---: |
| **Shield** | **0%** | 20% | 40% | 50% |
| Armour | 50% | 35% | 25% | **10%** |
| Hull | 33% | 33% | 33% | 33% |

Effective hit points are `HP ÷ resonance`, which makes resistance **super-linear**: going from 0% to
50% doubles your effective hit points, and going from 90% to 95% doubles them again. That is why a
few resistance modules matter more than a lot of raw capacity, and why "plugging the hole" in a
profile is the first thing any fit does.

### Extenders — flat and unpenalised

| Module | Shield HP | **Signature radius** |
| --- | ---: | ---: |
| Medium Shield Extender II | **+1,100** | **+7 m** |
| Large Shield Extender II | +2,600 | +25 m |
| Capital Shield Extender II | +72,000 | +1,200 m |

Extender hit points are **flat and not stacking-penalised**, so you fit as many as you have slots
for. The cost is signature radius — and the penalty is **per size class, not per tech level**, so a
medium tech 1 and a medium tech 2 both cost you the same 7 metres. Shield tanking makes you a bigger
target; that is the whole trade.

### Boosters — active, and capacitor-hungry

| Module | Boost | Cycle | HP/s | Capacitor | **HP per GJ** |
| --- | ---: | ---: | ---: | ---: | ---: |
| Medium Shield Booster II | 104 | 3 s | 34.7 | 60 GJ | **1.73** |
| Large Shield Booster II | 276 | 4 s | 69.0 | 160 GJ | 1.73 |
| X-Large Shield Booster II | 690 | 5 s | 138.0 | 400 GJ | 1.73 |

Tech 2 is a flat **+33% boost at identical capacitor cost**, and sub-capital shield boosters are a
hard constant **1.73 hit points per gigajoule** — which is the number that decides whether an active
shield fit survives a neutraliser.

**Ancillary Shield Boosters** are the interesting variant. Loaded with capacitor charges they cost
**zero capacitor** and boost about 40% harder than a tech 2 booster — for exactly **seven cycles**,
then a 60-second reload. It is a burst tank with a hard duty cycle, and the cadence is the design: a
ship that can win in twenty seconds or lose in ninety.

### Hardeners against amplifiers

| Module | Resistance | Capacitor | Damage types |
| --- | ---: | --- | --- |
| **Multispectrum Shield Hardener II** | **−32.5%** | Yes — **can be neutralised off** | All four |
| Thermal Shield Hardener II | **−55%** | Yes | One |
| Thermal Shield Amplifier II | **−37.5%** | **None** — passive, immune to neutralisers | One |

The design asymmetry worth noting: **there is no omni passive shield amplifier.** You can have
all-round protection *or* immunity to capacitor warfare, never both. A single-type amplifier at 37.5%
beats the omni hardener on its one type and never switches off; the single-type *hardener* at 55% is
the strongest per-slot resistance in the game outside officer gear.

One naming correction, because the old term is still everywhere: the **"Adaptive Invulnerability
Field" no longer exists**. The module is now the Multispectrum Shield Hardener.

### Passive shield tanking

The most distinctive shield fit in the game never activates anything. Shields recharge on the same
non-linear curve as capacitor:

```
peak rate = 2.5 × capacity / recharge time, at exactly 25% of capacity
```

So a passive fit maximises capacity *and* minimises recharge time, then **deliberately sits at a
quarter shields**, where regeneration peaks at two and a half times its average. It works because
extender hit points are flat, the recharge-time multipliers are **not stacking-penalised**, and the
repair costs **no capacitor at all** — so it cannot be neutralised off.

Worked on a Drake, the classic hull for it:

| Step | Capacity | Recharge time | **Peak** |
| --- | ---: | ---: | ---: |
| Bare hull | 5,500 | 1,400 s | 9.8 HP/s |
| Two large extenders | 10,700 | 1,400 s | 19.1 |
| Shield Management V | 13,375 | 1,400 s | 23.9 |
| Shield Operation V | 13,375 | 1,050 s | 31.8 |
| Three Core Defense Field Purgers | 13,375 | 443 s | 75.5 |
| **Two Shield Power Relays** | 13,375 | **249 s** | **134 HP/s** |

With hardeners on top that is roughly **380 effective hit points a second of free, un-neutralisable
repair** — and the only counters are raw alpha past the regeneration, or making the ship too big to
miss.

[EVE Ref: Medium Shield Extender II](https://ref-data.everef.net/types/3831), [Multispectrum Shield Hardener II](https://ref-data.everef.net/types/2281), [EVE University: Shield tanking](https://wiki.eveuniversity.org/Shield_tanking), [Passive shield tanking](https://wiki.eveuniversity.org/Passive_shield_tanking), [Capacitor](https://wiki.eveuniversity.org/Capacitor)

## Armour and hull modules

Armour lives in **low slots**, does not regenerate, and pays for itself in **mass** rather than
signature radius — which means it costs you the ability to leave.

### Plates

| Module | Armour HP | **Mass added** |
| --- | ---: | ---: |
| 400mm Steel Plates II | +1,200 | +375,000 kg |
| 800mm Steel Plates II | +2,400 | +1,450,000 kg |
| **1600mm Steel Plates II** | **+4,800** | **+3,750,000 kg** |

Align time is proportional to mass × inertia, so a Drake fitting 1600mm plates with the mass-reducing
skill at V goes from a **12.2-second align to 14.7** — about 21% slower to escape — and mass also
divides propulsion thrust, so the ship is slower under a microwarpdrive too. That is the deliberate
counterweight to armour's otherwise free hit points.

Note the meta alternative: **800mm Rolled Tungsten Compact Plates** give 83% of the hit points for
83% of the powergrid and **63% of the CPU** — the classic answer when the fit does not quite fit.

### Repairers

| Module | Repair | Cycle | HP/s | **HP per GJ** |
| --- | ---: | ---: | ---: | ---: |
| Medium Armor Repairer II | 368 | 12 s | 30.7 | **2.30** |
| Large Armor Repairer II | 920 | 15 s | 61.3 | 2.30 |

Armour repairers are **2.30 hit points per gigajoule against the shield booster's 1.73** — about a
third more capacitor-efficient — but they repair **at the end of the cycle** rather than the start,
so a twelve-second cycle is twelve seconds of hoping.

**Ancillary Armour Repairers** triple their repair when loaded with nanite paste, for exactly **eight
cycles**. Two asymmetries against the shield equivalent matter: the paste does **not** zero the
capacitor cost the way capacitor charges do for an ancillary shield booster, and you may fit **only
one per ship**.

### Four ways to buy resistance

| Family | Resistance | Capacitor | Types | CPU |
| --- | ---: | --- | --- | ---: |
| **Active Armour Hardener II** | **−55%** | Yes | **One only — there is no omni active armour hardener** | 36 |
| Multispectrum Energized Membrane II | −20% omni | No | All four | 36 |
| {type} Energized Membrane II | −38.8% | No | One | 30 |
| **Armour Coating II** | −15.4% omni, or −27.6% single | No | Either | **zero** |

Coatings cost **no CPU at all**, which makes them the frigate and destroyer staple and the fallback
whenever a fit is CPU-starved. The ladder here is unusually legible: more resistance costs more CPU,
and omni costs more than single-type.

### The Reactive Armour Hardener

Worth singling out as the cleverest defensive module in EVE. It starts at **15% resistance on all
four types** and then, every ten seconds, **moves six percentage points** away from the damage types
it is not taking and toward the ones it is — keeping a conserved total of 60 points.

It is the game's answer to the fact that resistance profiles are otherwise a guess made before
undocking. It trades peak resistance — about 30% on one type, against a hardener's 55% — for never
being wrong about *which* type. One per ship, and it needs capacitor, so it can be switched off.

### Hull

| Module | Effect |
| --- | --- |
| Reinforced Bulkheads II | **Structure +25%**, cargo −11%, and an agility penalty |
| Medium Hull Repairer II | **2.5 HP/s** for 2.5 GJ/s and 66 CPU |
| Medium **Remote** Hull Repairer II | **19.2 HP/s** |

Self hull repair is deliberately terrible and remote hull repair is nearly eight times better per
second — a small, pointed piece of design that says hull damage is something a friend fixes.

### Damage Control, the exception to everything

| Module | Shield | Armour | **Hull** | Capacitor |
| --- | ---: | ---: | ---: | --- |
| Damage Control I | 7.5% | 10% | **30%** | **None** |
| **Damage Control II** | **12.5%** | **15%** | **40%** | **None** |

One per ship, **passive since 2016**, and the only module in the game that touches all three layers.
It is also the only source of omni shield resistance that costs no capacitor, which makes it close to
mandatory on almost every fit — the rare case where EVE has a module everybody takes.

[EVE Ref: Reactive Armor Hardener](https://ref-data.everef.net/types/4403), [Damage Control II](https://ref-data.everef.net/types/2048), [1600mm Steel Plates II](https://ref-data.everef.net/types/20353), [EVE University: Armor tanking](https://wiki.eveuniversity.org/Armor_tanking), [Natural resistances](https://wiki.eveuniversity.org/Natural_Resistances)

## Capacitor

Capacitor is the resource that makes active modules a decision rather than a switch, and its curve is
the single most important formula in EVE's fitting maths. Shields use the same one.

```
rate(x) = (10 × Cmax / T) × (√x − x)        where x = current ÷ maximum
```

`√x − x` is maximised at **exactly x = 0.25**, so:

```
average rate = Cmax / T
PEAK rate    = 2.5 × Cmax / T,  at exactly 25% of capacity
```

Recharge falls to zero at both empty **and full**, which has a consequence most players learn the
hard way: a ship sitting at 100% capacitor is regenerating nothing, and a ship at 25% is regenerating
two and a half times its average. The familiar advice to disengage below a quarter is not caution,
it is the shape of the curve.

**Cap stability** has a closed form. A fit is stable if its steady drain `D` is at most the peak rate:

```
stable  ⟺  D ≤ 2.5 × Cmax / T
```

and the ship settles at the higher of two equilibria. On a Drake with 2,500 GJ and a 625-second
recharge, peak is 10 GJ/s: a 6 GJ/s drain settles at **67% capacitor**, a 9 GJ/s drain at **43%**, and
10.1 GJ/s is not stable at any level at all. Note how violently the stable point slides as you
approach the ceiling — which is why "almost cap stable" is a meaningfully different fit from "cap
stable".

### The modules

| Module | Slot | Effect | Side effect |
| --- | --- | --- | --- |
| Cap Recharger II | Mid | Recharge time **−20%** | — |
| Capacitor Power Relay II | Low | Recharge time **−24%** | **Shield boost −11%** |
| **Capacitor Flux Coil II** | Low | Recharge time **−39%** | **Capacity −20%** |
| Power Diagnostic System II | Low | A little of everything, plus **+6% powergrid** | — |
| Reactor Control Unit II | Low | **+15% powergrid** | — |

Because peak rate is `2.5 × Cmax / T`, **reducing recharge time beats adding capacity** for sustain —
and the Flux Coil's capacity penalty partly eats its own bonus, which is why it is a situational
module rather than an obvious one.

### Batteries and boosters

| Module | Capacitor | **Energy-warfare resistance** |
| --- | ---: | ---: |
| Medium Cap Battery II | +625 GJ | **−25%** |
| Large Cap Battery II | +1,625 GJ | **−25%** |

The capacitor battery is the **only dedicated counter to capacitor warfare** in the game, and it is a
**mid slot** — so it competes directly with shield tank and propulsion. An armour ship can fit one
comfortably; a shield ship pays for it in tank. That asymmetry is deliberate and it is why
neutraliser pressure is so much more effective against shield fits.

**Capacitor Boosters** inject a charge directly. The charge ladder is a model of clean design:

| Charge | Restores | Volume | **GJ per m³** |
| --- | ---: | ---: | ---: |
| Cap Booster 25 | 25 | 1.0 m³ | **25.0** |
| Cap Booster 100 | 100 | 4.0 m³ | **25.0** |
| Cap Booster 400 | 400 | 16.0 m³ | **25.0** |
| Cap Booster 800 | 800 | 32.0 m³ | **25.0** |

**Gigajoules per cubic metre is a perfect constant of 25 across the entire ladder.** The choice of
charge is therefore purely about *granularity against magazine depth* — never about efficiency — and
any charge fits any booster. It is the kind of detail that makes the rest of the system trustworthy.

[EVE Ref: Medium Cap Battery II](https://ref-data.everef.net/types/3496), [EVE University: Capacitor](https://wiki.eveuniversity.org/Capacitor)

## Sensors, targeting and tracking support

### Four sensor types

Each empire's hulls use a different sensor — Amarr **radar**, Caldari **gravimetric**, Gallente
**magnetometric**, Minmatar **ladar** — and each is a separate ship attribute with its own strength.

This exists for exactly one reason: **racial ECM jammers get full strength only against the matching
sensor type**, and roughly a third against the others. So a jamming ship either carries a
multispectral jammer that is weaker against everything, or racial jammers and the knowledge of what
it is about to fight. It makes an otherwise flat counter into an intelligence problem.

One correction worth recording: **dedicated ECCM modules no longer exist.** There is no "ECCM —
Gravimetric II" and no Sensor Backup Array in the current data. Sensor strength is now raised by
**Signal Amplifiers** (low slot) and by a **Sensor Booster loaded with an ECCM script** (mid slot) —
so resisting jamming competes for the same slots as everything else, rather than having a module of
its own.

### Targeting and tracking modules

| Module | Slot | What it does |
| --- | --- | --- |
| **Sensor Booster** | Mid | Targeting range, scan resolution or sensor strength — **chosen by script** |
| Signal Amplifier | Low | The passive equivalent, plus locked targets |
| **Tracking Computer** | Mid | **Optimal range or tracking speed**, by script |
| Tracking Enhancer | Low | Both at once, passively, at lower magnitude |
| **Omnidirectional Tracking Link** and Enhancer | Mid / low | The same pair, for **drones** |

The script-versus-enhancer pattern repeats throughout: the active module is stronger and
reconfigurable but takes a mid slot and capacitor, the passive one is weaker and gives both bonuses at
once. Neither is correct; it depends what the rest of the fit is short of.

[EVE Ref types API](https://ref-data.everef.net/), [EVE University: Sensor boosters](https://wiki.eveuniversity.org/Sensor_booster), [Electronic warfare](https://wiki.eveuniversity.org/Electronic_warfare)

## Electronic warfare

All electronic warfare shares a range model identical in shape to turret falloff — full effect inside
optimal, **50% at optimal plus one falloff**, about 6% at two. Past that the modules differ sharply,
and the differences are the most instructive thing in EVE's module design.

### ECM — the probabilistic one

| Module | Matched strength | Unmatched | Optimal | Falloff |
| --- | ---: | ---: | ---: | ---: |
| Gravimetric ECM II | **4.0** | 1.3 | 34,560 m | 32,400 m |
| Multispectral ECM II | 2.6 | 2.6 | 23,040 m | 21,600 m |

```
P(jam) = ECM strength ÷ target sensor strength
P(jam, n modules) = 1 − (1 − p)ⁿ
```

**There is no stacking penalty on ECM**, which makes it the only electronic warfare that scales
linearly in module count. A single Gravimetric ECM II against a Drake is a **21%** chance per
20-second cycle; four of them is **61%**.

A successful jam drops **all** of the target's locks except on the jammer itself, and stops it locking
anything that is not jamming it. So one lucky roll removes a ship from the fight for twenty seconds —
and one unlucky roll does nothing at all.

**Burst Jammers** are the area version: **7.2 strength across all sensor types in a 12 km radius**,
with no lock required, hitting everything nearby including friendlies. They are restricted to
battleships, haulers, blockade runners and a few other hulls, and the item text explains why:
*"fitting a Burst Jammer module will disable interdiction nullification."* A hauler can jam its way
out of a gate camp, but not while staying immune to bubbles.

### Sensor dampeners — the deterministic one

| Module | Targeting range and resolution | Optimal | Falloff |
| --- | ---: | ---: | ---: |
| Remote Sensor Dampener II | **−15.3%** each, or **−30.6%** on one with a script | 30,000 m | **60,000 m** |

Note the falloff is **twice** the optimal, so a damp is still half-effective at 90 km. Damps project
further than almost anything else in the game, which is what makes them the anti-sniper tool.

The contrast with ECM is the point, and it is worth laying out plainly:

| | **ECM** | **Sensor dampener** |
| --- | --- | --- |
| Outcome | **Binary and probabilistic** — total shutdown or nothing | **Deterministic and graded** — always lands, partially |
| Stacking | **None** — scales linearly | **Penalised** — the second is 87% effective |
| Depends on target size? | **Yes** — on its sensor strength | **No** — a percentage, so a titan suffers as much as a frigate |
| Counterplay | Fit sensor strength, or bring racial diversity | **Close the distance** |
| Feels like | A coin flip that deletes a ship from the fight | Slowly strangling a sniper |

Two modules, the same job, opposite philosophies. One is high-variance with a high ceiling and can be
answered by fitting; the other is reliable, unavoidable and can only be answered by flying
differently. Having both is better design than picking either.

### Weapon and guidance disruptors

| Module | Effect |
| --- | --- |
| **Tracking Disruptor II** | **−17.2%** to the target's optimal, falloff **and** tracking — or −34% to one with a script |
| **Guidance Disruptor II** | −9% missile velocity and flight time, −12% explosion velocity, **+12% explosion radius** |

They are deliberately **two separate modules** rather than one, so a single module can never blunt
both a turret boat and a missile boat. Note the guidance disruptor's +12% explosion radius: it is the
exact mirror of a target painter.

### Target painters — electronic warfare that helps you shoot

| Module | Signature radius | Optimal | Falloff |
| --- | ---: | ---: | ---: |
| **Target Painter II** | **+30%** | 36,000 m | **90,000 m** |

The only electronic warfare module that improves your own side rather than degrading the enemy's.
Because target signature feeds **both** the turret hit formula and the missile damage formula, a
painter is a **damage multiplier for the entire fleet** — one module on one ship making everybody
else's guns better. It is the cheapest force multiplier in the game and the reason painting ships are
primary targets.

### Capacitor warfare

| Module | Drain | Cycle | **GJ/s** | Optimal |
| --- | ---: | ---: | ---: | ---: |
| Medium Energy Neutralizer II | 180 | 12 s | **15.0** | 10,000 m |
| **Heavy Energy Neutralizer II** | 600 | 24 s | **25.0** | 20,000 m |
| Capital Energy Neutralizer II | 4,400 | 48 s | **91.7** | 36,000 m |

A **neutraliser** destroys the target's capacitor and costs you some of yours; a **nosferatu**
transfers it instead, at no net cost to you. They are the counter-design to everything active: an
active tank, a cap booster, a microwarpdrive, a laser boat and a jump drive all stop working when the
capacitor is empty. Against a buffer fit with no active modules they do almost nothing — which is
precisely why buffer tanking is the fleet standard.

[EVE Ref: Gravimetric ECM II](https://ref-data.everef.net/types/2571), [Remote Sensor Dampener II](https://ref-data.everef.net/types/1969), [Target Painter II](https://ref-data.everef.net/types/19806), [Heavy Energy Neutralizer II](https://ref-data.everef.net/types/12271), [EVE University: Electronic warfare](https://wiki.eveuniversity.org/Electronic_warfare)

## Remote assistance

The modules that make EVE's fleet combat what it is. Everything a ship can do for itself, it can do
for somebody else, usually better — and that single decision shapes every doctrine in the game.

| Module | What it projects |
| --- | --- |
| **Remote Shield Booster** | Shield repair |
| **Remote Armor Repairer** | Armour repair |
| Remote Hull Repairer | Structure repair — about **eight times** better than repairing your own |
| **Remote Capacitor Transmitter** | Capacitor, which is how a fleet keeps its active modules running |
| Remote Tracking Computer, Remote Sensor Booster | Range, tracking and targeting bonuses |

Three consequences follow, and together they explain why EVE fights look the way they do:

1. **Buffer tanking becomes correct.** If someone else can repair you, you do not need to repair
   yourself — so you spend your slots on raw hit points instead, which cost no capacitor and cannot
   be neutralised off. A fleet's effective tank is its logistics wing, not its hulls.
2. **Logistics ships are the real target.** Killing the ships that repair is worth more than killing
   the ships that shoot, which is why target painters, dampeners and ECM are all evaluated primarily
   by what they do to logistics.
3. **The capacitor chain.** Remote capacitor transmitters let a fleet pool capacitor, so a ship under
   neutraliser pressure can be fed from outside. Capacitor warfare and remote capacitor transmission
   are a conversation rather than a counter.

The one hard limit on all of it: **siege, triage and bastion modules reduce incoming remote repair
by 99.9999%** — effectively to nothing. A ship that has committed to one of those is on its own by
design, and that is the price of the enormous bonuses they give.

[EVE University: Logistics](https://wiki.eveuniversity.org/Logistics), [Remote repair](https://wiki.eveuniversity.org/Remote_repair)

## Propulsion and mobility

Speed in EVE is not a stat you buy more of — it is a set of trades against signature radius,
capacitor and align time. The central choice is between two modules that both make you faster and
are otherwise opposites.

### Afterburner against microwarpdrive

| | **Afterburner** | **Microwarpdrive** |
| --- | ---: | ---: |
| Speed bonus, tech 1 / 2 | 115% / **135%** | **500% / 510%** |
| **Signature radius** | **none** | **×5.0 tech 1, ×4.75 tech 2** |
| Maximum capacitor | none | **−25% / −20%** |
| Capacitor per cycle, medium | 80–90 GJ | 160–180 GJ |
| **Disabled by a warp scrambler** | **No** | **Yes** |

Four consequences follow, and together they are most of EVE's small-ship doctrine:

1. **Signature radius drives incoming damage.** A 120 m cruiser running a microwarpdrive becomes
   roughly a **690 m** target — far above the signature resolution of the guns shooting at it, so it
   takes full damage from things that would otherwise struggle to track it. Going fast makes you
   easier to hit.
2. **Capacitor.** The microwarpdrive costs about twice as much per cycle *and* removes a fifth of
   your maximum capacitor, which compounds against active tanks, lasers and neutraliser pressure.
3. **Scram immunity.** A warp scrambler shuts a microwarpdrive off outright. An afterburner brawler
   that gets scrammed keeps about 2.35× its base speed; a microwarpdrive ship drops to base speed and
   is simply caught. This single rule is why afterburner fits exist at all.
4. **Both add identical mass**, so both cost the same in align time.

The design detail worth admiring: the best module for a signature-sensitive doctrine is not the tech
2 one. The **meta 1 "Quad LiF Restrained" microwarpdrive** carries a ×4.50 signature penalty against
tech 2's ×4.75, so it is a doctrine staple *because it is worse in the headline statistic*.

### Micro jump drives

| | Medium / Large | **Capital** | Micro Jump **Field** Generator |
| --- | ---: | ---: | ---: |
| Distance | 100 km | **250 km** | 100 km |
| Spool-up | 12 s, to 9 s with skills | 12 s | **9 s** |
| Reactivation | 3 min | 3 min | 2 min 40 s |
| Signature while active | +150% | – | +150% |
| Fits | Cruiser and up; large is battleship-only | Carriers | **Command destroyers only** |

Both jump **in the direction the ship is facing**, and arriving ships keep their heading and
velocity. The field generator is the interesting one: it throws **everything within 6 km**, up to 24
ships, including drones, probes and bombs — so a command destroyer can scatter an enemy fleet, or
rescue a friendly one, and it is banned in high-security space.

### Being held

| Module | Strength | Optimal | Disables propulsion? |
| --- | ---: | ---: | --- |
| Warp Disruptor II | **1** | 24,000 m | No |
| **Warp Scrambler II** | **2** | 9,000 m | **Yes** |
| Heavy Warp Scrambler II | **6** | 10,000 m | **Yes** |
| Warp Disruption Field Generator II | **100** | 20,000 m field | Yes, and blocks jumping |

The scrambler's text is explicit: it disables "warping, jumping, microwarpdrives and micro jump
drives" — **regardless of the target's warp core strength**. So warp core stabilisers can beat a
point but never save a microwarpdrive from a scram, which is why 9 km is the knife-fight range of the
entire game.

### Agility, and the low slots

| Module | Effect | Penalty |
| --- | --- | --- |
| Inertial Stabilizers II | Inertia **−20%** — faster align | **Signature radius +11%** |
| Nanofiber Internal Structure II | Velocity +9.5%, inertia −15.75% | **Structure hit points −20%** |
| Overdrive Injector System II | Velocity +12.5% | **Cargo capacity −20%** |
| Warp Core Stabilizer II | **+2 warp core strength** | **Targeting range −40%**, and it is now an *activated* module, one per ship |

Every one of them costs something a different fit would want, and all are subject to the stacking
penalty, which is the real limit on "nano" fits.

### Warp, jumps and bubbles

**Align time** is a product of mass and inertia, and it is the statistic that decides whether you
escape at all — everything that adds mass (plates, propulsion modules, cargo) makes you slower to
leave.

Beyond gates there are three ways to move a fleet. **Jump drives** on capitals need a **cynosural
field** lit at the far end by another pilot, and cannot be used in high-security space. **Titan
bridges** throw a fleet to a lit cyno. **Ansiblex jump bridges** are alliance-built gates between
owned systems, and since September 2026 they run on a **draining capacitor** whose cost rises with
distance from the alliance's capital system — cheap inward, expensive outward — restricted to the
owning alliance, with capitals barred.

**Interdiction** is the counter to all of it: warp disruption bubbles stop warp outright within their
radius, and only work outside high- and low-security space. Some hulls fit **interdiction
nullifiers** to ignore them — and in one of EVE's better details, fitting a **Higgs Anchor** rig or
activating a **burst jammer** cancels your own nullification.

### The Higgs Anchor, the rig that makes you worse

Worth singling out as a design object. A medium Higgs Anchor **doubles your mass**, cuts maximum
velocity by **75%**, improves inertia by 55% and reduces warp speed.

It exists for two jobs. **Collapsing wormholes**, where mass is the currency — doubling a
battleship's mass roughly halves the number of passes needed to crit a hole. And **holding
position**, where being nearly impossible to push around is exactly what you want.

It is the clearest case in EVE of a rig whose headline effect is the thing every other ship pays to
avoid, and it is a neat demonstration that a stat is only a penalty in a context.

[EVE Ref: 50MN Microwarpdrive II](https://everef.net/types/12076), [10MN Afterburner II](https://everef.net/types/12058), [Warp Scrambler II](https://everef.net/types/448), [Medium Micro Jump Drive](https://everef.net/types/33915), [Medium Higgs Anchor I](https://everef.net/types/34268), [Inertial Stabilizers II](https://everef.net/types/1405), [EVE University: Propulsion modules](https://wiki.eveuniversity.org/Propulsion_module), [Warp disruption](https://wiki.eveuniversity.org/Warp_disruption), [CCP: Cradle of War expansion notes](https://www.eveonline.com/news/view/cradle-of-war-expansion-notes), [CCP: Force Projection revamped](https://www.eveonline.com/news/view/major-update-force-projection-revamped)

## Cloaking devices

Cloaks are the most consequential single module in EVE, because they do not make you harder to
find — they make you **impossible** to find. There is no counter-detection module, only probability
and geometry.

| | Prototype | Improved | **Covert Ops** |
| --- | ---: | ---: | ---: |
| CPU | 30 tf | 60 tf | **100 tf** |
| Speed while cloaked | **−90%** | −75% | **no penalty** |
| Scan resolution | −50% | −40% | **no penalty** |
| Targeting delay after decloaking | 30 s base, 15 s at skill V | 20 s base, 10 s at V | **10 s base, 5 s at V** |
| Reactivation delay | 30 s | 30 s | 30 s |
| **Warp while cloaked** | **No** | **No** | **Yes** |

The ladder is unusually clean: the prototype cloak hides you but nearly immobilises you and leaves
you blind for half a minute after you drop it, so it is a tool for sitting still. The covert ops
cloak removes every penalty and lets you **warp cloaked**, which is what turns it from a hiding place
into a mode of travel.

"Covert" is a **hull capability, not a module stat**. Only covert operations frigates, force recons,
stealth bombers, blockade runners, strategic cruisers with the right subsystem and a handful of
special hulls can fit one, and the same list can use **covert jump bridges** and **covert cynosural
generators** — so the covert fleet is a parallel, invisible logistics network rather than a few
sneaky ships. Fitting two cloaks negates both.

### What breaks a cloak

| Cause | Detail |
| --- | --- |
| **Proximity** | Any collidable object within **2,000 m** prevents cloaking or forces a decloak — jetcans, corpses, drones, structures, even gas clouds. Flying through a cloud of debris is how you get caught |
| Activating a module | The cloak blocks module activation entirely, with a brief grace window on non-offensive modules |
| **Missiles** | Decloak you. Bombs and smartbombs **damage** a cloaked ship without decloaking it |
| A completed target lock | Prevents cloaking; a cloak that lands first makes the lock fail |
| **Mobile Observatory** | A deployable with a **40% chance every ten minutes** of revealing cloaked ships — low and null security space only |
| Electrical metaliminal storms | Make cloaking impossible across the whole system |

Note the **gate cloak**: every ship is automatically cloaked for 60 seconds after jumping a gate or
wormhole, invulnerable and undecloakable, until it moves or warps. It is the game's single most
important safety mechanic, and the reason jumping into a hostile system is survivable at all.

### The cloaky camper problem

Worth recording as a design failure the studio has never solved. An indefinitely cloaked hostile in
a system is **unlocatable, invulnerable, free to maintain and can be left unattended**, while the
system's residents must assume a hostile fleet could arrive at any moment. One player imposes a
permanent tax on everyone else's activity at no cost and with no presence at the keyboard.

The chosen answer has been **probabilistic, deployable, space-limited counterplay rather than nerfing
cloaks** — the Mobile Observatory's one-in-ten-minutes roll, restricted to the space where such a
fight is legal anyway. It is a revealing choice: rather than weaken a mechanic players love, add a
tool that *might* work. Whether it is enough is still argued about.

[EVE Ref: Prototype Cloaking Device I](https://everef.net/types/11370), [Improved Cloaking Device II](https://everef.net/types/11577), [Cloaking Device group](https://everef.net/groups/330), [EVE University: Cloaking](https://wiki.eveuniversity.org/Cloaking)

## Rigs

Rigs are permanent specialisations bought with a separate currency. They are the cleanest idea in
EVE's fitting system, because they make a hull *commit* to something.

### The budget

| Rule | Value |
| --- | ---: |
| Calibration on most hulls | **400** |
| Pirate-faction and most special-edition hulls | 350 |
| **Tech 1 hull rig slots** | **3** |
| **Tech 2 hull rig slots** | **2** |
| Tech 3 cruisers and tactical destroyers | 3 |
| Freighters, jump freighters, corvettes, shuttles | **none at all** |
| Tech 1 rig calibration cost | 25–250 |
| **Tech 2 rig calibration cost** | **+50% over tech 1** — 50 becomes 75, 100 becomes 150 |
| CPU and powergrid cost | **none** |

Rigs come in small, medium, large and capital to match hull size, and **rigs are destroyed when
removed** — refitting a hull means throwing them away. The only exception is the tech 3 strategic
cruiser, whose rigs come off intact, which is part of what that hull class is *for*.

The calibration budget does the interesting work: a 400-point budget against rigs costing 50 to 150
means a tech 1 hull can take three cheap rigs, or two expensive ones, or one of each — and tech 2
rigs cost half again as much calibration for a bigger effect, so "better rig" and "more rigs" are
genuinely in tension.

### Categories

| Family | Representative rigs | Drawback |
| --- | --- | --- |
| **Armour** | Armour Reinforcers by damage type, **Trimark Armor Pump**, Nanobot Accelerator, Transverse Bulkhead | **Agility** |
| **Shield** | Shield Reinforcers by damage type, **Core Defense Field Extender**, Core Defense Field Purger | **Signature radius** |
| **Engineering** | **Capacitor Control Circuit**, Ancillary Current Router, Semiconductor Memory Cell | Often none |
| **Astronautic** | Polycarbon Engine Housing, Auxiliary Thrusters, **Hyperspatial Velocity Optimizer**, Warp Core Optimizer | Armour hit points, or signature |
| **Anchor** | **Higgs Anchor** — one per ship, no tech 2 | Velocity and warp speed |
| **Drone** | Control Range Augmentor, Damage / Durability / Speed Augmentors, Sentry Damage Augmentor | Varies |
| **Electronic Superiority** | Inverted Signal Field Generator, Particle Dispersion Augmentor, **Signal Disruption Amplifier** | Sometimes **none** |
| **Targeting** | Ionic Field Projector, Targeting System Subcontroller | Varies |
| **Launcher** | Bay Loading Accelerator, **Warhead Calefaction Catalyst**, Rocket Fuel Cache Partition, Warhead Rigor and Flare Catalysts | CPU |
| **Weapon**, one family per turret type | Burst Aerator, **Collision Accelerator**, **Locus Coordinator**, Metastasis Adjuster, Ambit Extension | CPU or capacitor |
| **Resource Processing** | **Ice Harvester Accelerator**, Deep Core Mining Optimization, Salvage Tackle | Sometimes none |
| **Scanning** | **Gravity Capacitor Upgrade**, Memetic Algorithm Bank, Signal Focusing Kit | Varies |
| **Synchronizer**, from 10 Nov 2026 | Nine sets — four navy and five pirate — whose bonuses **grow with each matching faction module fitted** | Not yet published |

**Jury Rigging** gates rigs at all, and each family has its own rigging skill that **reduces that
family's drawback by 10% a level**, so a specialist pays less for the same rig than a generalist.

Three corrections to what the community commonly says, from current data:

- **Armour rigs penalise agility, not maximum velocity**, and **shield rigs penalise signature
  radius, not capacitor.** The older descriptions are still widely repeated.
- **Tech 2 rigs do not carry a bigger drawback.** Every pair checked shows **10% on both tiers**;
  what tech 2 buys is a larger bonus for 50% more calibration.
- Some rigs are genuinely **drawback-free** — the Signal Disruption Amplifier, the Ice Harvester
  Accelerator, and the Capacitor Control Circuit.

### Structure rigs

Upwell structures run a parallel system: **Standup** rigs in medium, large and extra-large to match
the structure class, split between engineering rigs that improve manufacturing, research and
reprocessing and combat rigs that improve the structure's defences. Calibration runs 100 at tech 1
and 150 at tech 2, **only one rig of a given type** per structure, and Citadels get a **+25% bonus to
combat rig effectiveness**. This is the layer that makes a null-security industrial hub measurably
better than a high-security station, and it is why the ore and reprocessing figures in the main
reference depend on where you are.

[EVE Ref: Medium Trimark Armor Pump](https://everef.net/types/31055), [Medium Core Defense Field Extender I](https://everef.net/types/31790), [Medium Capacitor Control Circuit I](https://everef.net/types/31372), [Rig Navigation group](https://everef.net/groups/782), [EVE University: Rigs](https://wiki.eveuniversity.org/Rigs), [Upwell structures](https://wiki.eveuniversity.org/Upwell_structures)

## Tech 3: subsystems and modes

EVE answers the question "let a pilot reconfigure a ship" twice, with two systems that are almost
exact opposites. Taken together they are the most interesting pair of mechanics in the game's
fitting design.

### Strategic cruiser subsystems

Four hulls — Legion, Tengu, Proteus, Loki — each assembled from **four subsystems** (Core, Defensive,
Offensive, Propulsion) with **three variants of each**, giving **81 configurations per hull and 324
in all**.

The crucial fact: **the hull itself contributes nothing.** A bare Legion has **zero high, mid and low
slots and zero hardpoints**. Every slot, every hardpoint, the capacitor, the hit points, the drone
bay, the cargo hold and the signature radius are contributed *by the subsystems*. The ship does not
exist until you decide what it is.

Taking the Legion as the worked example:

| Subsystem | Variant | What it contributes |
| --- | --- | --- |
| **Core** | Dissolution Sequencer | Sensor strength, targeting, **+1 locked target**; +2 mid, +2 low |
| | Augmented Antimatter Reactor | Capacitor, **+20% power output**; +1 mid, +3 low |
| | Energy Parasitic Complex | Capacitor warfare and heat; **−50% fitting cost** for its specialism |
| **Defensive** | **Covert Reconfiguration** | The subsystem that permits a **covert ops cloak** |
| | Augmented Plating | **+1,000 armour**, +10 m signature |
| | Nanobot Injector | Repair effectiveness, +300 GJ capacitor |
| **Offensive** | Liquid Crystal Magnifiers | Lasers: damage, range, capacitor. **+7 high slots** |
| | Assault Optimization | Missiles and **+10% drone damage and hit points**. +7 high |
| | Support Processor | Command bursts and remote repair. +7 high |
| **Propulsion** | **Interdiction Nullifier** | Ignores warp disruption bubbles; warp speed and capacitor |
| | Intercalated Nanofibers | Agility and velocity; +2 low |
| | Wake Limiter | Afterburner speed, and **−10% microwarpdrive signature penalty** |

Every hull gets the same four "archetype" options in each slot — a Covert Reconfiguration, a Support
Processor, an Augmented reactor and an Interdiction Nullifier — so the choice is legible across all
four ships even though the numbers differ.

Mechanics worth knowing:

- **Each subsystem carries its own skill**, four racial skills per hull, which both gate it and
  improve it. A strategic cruiser is therefore a large training commitment on top of a large ISK one.
- **Refitting** happens docked or at a **Mobile Depot**, and every strategic cruiser carries a
  **subsystem bay holding three spares** — so a pilot can bring a second configuration into the field
  and reconfigure in space.
- **Skill loss on destruction was removed in July 2021.** Losing one used to cost a level of a random
  subsystem skill, which made the hull genuinely frightening to fly; it is now an ordinary loss.
- Strategic cruisers are the **only hulls whose rigs survive removal**.

### Tactical destroyer modes

The other answer. Four destroyers — Confessor, Svipul, Jackdaw, Hecate — with **three switchable
modes** and a **ten-second cooldown**, changeable mid-fight.

| Mode | What it gives |
| --- | --- |
| **Sharpshooter** | **+66.6% weapon optimal range**, +33.3% damage, **+100% sensor strength and targeting range**, +66.6% resistance to sensor and weapon disruption |
| **Propulsion** | **+66.6% afterburner and microwarpdrive speed**, +33.3% inertia — the mechanic behind sub-three-second destroyer aligns |
| **Defense** | **+33.3% resistances**, and either **−33.3% signature radius** or **−66.6% microwarpdrive signature penalty** depending on hull |

Switching takes effect immediately, and modules mid-cycle pick up the new values at the start of
their next cycle. A Hecate's base 8.7-second align becomes **2.9 seconds** on the propulsion mode
alone.

### The contrast, which is the point

| | **Tactical destroyer modes** | **Strategic cruiser subsystems** |
| --- | --- | --- |
| Granularity | 3 states | **81 per hull, 324 in all** |
| What changes | **Bonuses only** — never slots, hardpoints, fitting or hit points | **Everything**, including the slot layout |
| When | **Mid-combat**, instantly, 10 s cooldown | Docked, or at a mobile depot |
| Skills | One racial skill | **Four** racial subsystem skills |
| Are they items? | **No** — nothing to buy, build or lose | **Yes** — built, traded, and destroyed with the hull |
| Economy attached | None | An industry chain: invention from Sleeper relics |

Subsystems make reconfiguration a **pre-combat, economic, high-commitment** decision with a
manufacturing industry behind it. Modes make it a **tactical, free, reversible** one with no economy
at all. Same design question, two answers, and both are good — which is a better outcome than most
games get from picking one.

[EVE Ref: Legion](https://everef.net/types/29986), [Dissolution Sequencer](https://everef.net/types/45622), [Covert Reconfiguration](https://everef.net/types/45586), [subsystem categories](https://everef.net/categories/32), [Confessor](https://everef.net/types/34317), [Hecate](https://everef.net/types/35683), [EVE University: Subsystems](https://wiki.eveuniversity.org/Subsystems), [Tactical Destroyer](https://wiki.eveuniversity.org/Tactical_Destroyer)

## Drones

Drones are a weapon system that is also a cargo problem, and they are governed by **two independent
hull limits plus a hard pilot cap** — a neat piece of design that makes the same drones behave
differently on different ships.

| Limit | What it gates |
| --- | --- |
| **Drone bay**, in m³ | How many you can **carry** |
| **Drone bandwidth**, in Mbit/s | How many you can have **in space at once** |
| **The Drones skill** | A hard ceiling of **five** in space, one per level |

Neither hull limit can be raised by any module or skill. The standard ladder is **light 5 m³ and
5 Mbit, medium 10 and 10, heavy and sentry 25 and 25** — so a ship with a 40 m³ bay and 25 Mbit
carries eight lights but fields only five, or two mediums and a light. The hull decides your options
and the skill decides how many you get to use.

### Combat drones

Damage type is fixed per racial line, which makes drone selection the same decision as ammunition
selection for a turret boat:

| Empire | Damage | Light | Medium | Heavy | **Sentry** |
| --- | --- | --- | --- | --- | --- |
| Amarr | **EM** | Acolyte | Infiltrator | Praetor | Curator |
| Gallente | **Thermal** | Hobgoblin | Hammerhead | Ogre | Garde |
| Caldari | **Kinetic** | Hornet | Vespa | Wasp | Warden |
| Minmatar | **Explosive** | Warrior | Valkyrie | Berserker | Bouncer |

Within a size the lines trade damage multiplier against speed and tracking — the Amarr and Caldari
drones are slower and hit harder, the Minmatar ones are the fastest and weakest. A tech 2 drone is
roughly **+20% on damage multiplier and velocity** over tech 1.

**Sentry drones** are the interesting variant: immobile, with microscopic tracking, in exchange for
enormous range.

| Sentry | Damage | Optimal, tech 2 | Falloff |
| --- | --- | ---: | ---: |
| Curator II | EM | 42,000 m | 12,000 m |
| Garde II | Thermal | 18,000 m | 30,000 m |
| **Warden II** | Kinetic | **60,000 m** | 42,000 m |
| Bouncer II | Explosive | 36,000 m | 54,000 m |

A Warden reaching sixty kilometres is a sniping platform you deploy and leave, and the tracking
figures — around 0.012 — mean it cannot hit anything that moves across it at all.

Two off-ladder drones are worth naming. The **Gecko** takes 50 m³ and 50 Mbit, deals all four damage
types and carries a **2.05 damage multiplier** — the strongest drone in the game, and it eats your
whole bandwidth. The **Aralez** and the 'Subverted' drones are similar oddities from event and
storyline rewards.

### The other drone families

| Family | What they do |
| --- | --- |
| **Electronic warfare** | ECM, sensor dampening, tracking disruption, target painting, stasis webbing and energy neutralisation, in three sizes each, mostly at 5–10 km |
| **Logistics** | Shield, armour and **hull** maintenance bots in three sizes — remote repair without spending a high slot |
| **Mining** | Mining Drone I and II, Harvester, 'Augmented', and the Rorqual's **Excavator** at 80 m³ a cycle — which takes **1,100 m³ of bay** and 25 Mbit, so only a capital can carry them |
| **Ice harvesting** | Including an Excavator variant at 1,000 m³ per 310-second cycle |
| **Salvage** | Salvage Drone I and II, which add to salvaging *chance* rather than doing damage |
| **Hybrid**, new in 2025–26 | A new group that deals EM and thermal damage **and applies an electronic-warfare effect at the same time** |

Mining drones carry the residue mechanic too — an Excavator destroys extra ore on a **60%** roll,
against the 'Pluto' prototype's 30%, which is the trade for its lower yield.

### Skills and support

**Drone Interfacing** is the big one at **+10% damage per level**; the per-size Operation skills add
+5% each; **Drone Avionics** and its advanced version extend control range; **Drone Sharpshooting**,
**Durability** and **Navigation** fill in optimal, hit points and speed. On the module side,
**Omnidirectional Tracking Links** and **Enhancers** do for drones what tracking computers do for
turrets, and the drone rigs cover control range, damage, durability and speed.

The practical note that every drone pilot learns: drones get shot. They are targetable, they do not
benefit from your tank, and a drone left behind when you warp is simply gone unless you come back for
it — so "abandon drones" and "scoop to drone bay" are muscle memory.

[EVE Ref drone groups](https://everef.net/categories/18), [EVE University: Drones](https://wiki.eveuniversity.org/Drones), [Drone skills](https://wiki.eveuniversity.org/Drone_skills), [CCP: Cradle of War expansion notes](https://www.eveonline.com/news/view/cradle-of-war-expansion-notes)

## Fighters

Fighters are the capital-scale equivalent of drones and deliberately break every rule drones obey.
They launch from **tubes** rather than being limited by bandwidth, they operate as **squadrons**
rather than individuals, and they are ordered about with explicit abilities rather than left to an
AI.

| Role | Squadron | What it is for |
| --- | ---: | --- |
| **Light Attack** | 6 | Anti-subcapital damage |
| **Space Superiority** | **12** | Killing other fighters and drones |
| **Heavy Attack** | 6 | Anti-capital — **supercarriers only** |
| **Long Range Attack** | 6 | Anti-battleship, and bombing |
| **Support** | 3 | Electronic warfare, unarmed |

Two hull attributes gate them: the **fighter hangar** in m³ and the number of **launch tubes**, which
caps how many squadrons can be in space simultaneously. Fighters must be back in the hangar for a
squadron to refuel and rearm, so a carrier's tempo is a logistics loop rather than a trigger pull.

The hit-point model is pointed: fighters have **shields but no armour and only 100 structure**, and
**cannot be remote-repaired**. They regenerate shields between engagements and die outright to
anything that lands a hit on the structure. That makes space superiority fighters — a twelve-strong
squadron whose whole job is killing other squadrons — a real counter rather than a footnote.

Carriers, supercarriers, some Guristas capitals and Upwell structures launch them.

[EVE University: Fighters](https://wiki.eveuniversity.org/Fighters), [EVE Ref fighter groups](https://everef.net/categories/87)

## Holds and bays

A hull in EVE does not have "a cargo hold". It has a cargo hold plus, often, one or more **special
holds** that accept only one category of thing. This is how the game makes a hauler a *specialist*
without giving it a bigger number, and it is the mechanic Oolite has least of.

Enumerated from the game's own capacity attributes, every hold that exists on a live hull:

| Hold | Where it is, with figures |
| --- | --- |
| **Cargo** | Universal |
| **Mining Hold** | Barges, exhumers, Rorqual, Orca, Porpoise, Venture, Prospect, Endurance, Miasmos, Pioneer, Outrider. Accepts **all harvestable resources** — ore, ice and gas |
| **Drone Bay** | Every drone hull |
| **Fighter Hangar** and **launch tubes** | Carriers, supercarriers, structures |
| **Ship Maintenance Bay** | Capitals, Orca, **Bowhead**, Nestor, Odysseus. Holds **assembled** ships |
| **Fleet Hangar** | Capitals, deep space transports, Orca, Porpoise. The **only hold fleetmates can access directly** |
| **Fuel Bay** | Every jump-capable hull. Fuel blocks, isotopes, liquid ozone and strontium only |
| **Gas Hold** | Hoarder 30,000 m³; Primae 10,000 |
| **Mineral Hold** | **Kryos 50,000 m³** |
| **Ice Hold** | Kryos 30,000; Primae 10,000 |
| **Ammo Hold** | **Hoarder 41,000 m³**; Monitor 25 |
| **Command Center Hold** | **Epithal 6,000 m³**; Primae 2,000 |
| **Planetary Commodities Hold** | **Epithal 45,000 m³**; Primae 2,500 |
| **Quafe Hold** | The three Miasmos special editions, 10,000 m³ each — a hold for a soft drink |
| **Subsystem Hold** | Tengu, Legion, Proteus, Loki — **120 m³**, three spare subsystems |
| **Booster Hold** | Virtuoso 50; Victor 100; Monitor 25 |
| **Corpse Hold** | **Blood Raider hulls only** — Molok 2,000 m³ down to Caedes 60. A hold for bodies |
| **Mobile Depot Hold** | **Metamorphosis, 100 m³** — the only hull in the game with one |
| **Infrastructure Hold** | The Equinox haulers: **Avalanche 2,000,000 m³**, Torrent 60,000, Squall 45,000, Deluge 30,000 |
| **Expedition Hold** | **Odysseus, 50,000 m³** — the only hull, added by Catalyst |
| **Frigate Escape Bay** | Every battleship, marauder and black ops — capacity **one ship**, used when the hull dies |
| **Clone Vat Bay** | A titan module, and a jump-clone destination |
| Moon Material Output Bay | **Metenox Moon Drill, 500,000 m³** |

Five attributes exist in the data model and are **on no live hull at all** — Salvage Hold, Asteroid
Hold, and four Ship Hold variants including Industrial Ship Hold. They are leftovers, and worth
knowing about only because community references still cite some of them.

Four corrections to what is commonly repeated:

- **The "Ore Hold" no longer exists.** It was renamed the **Mining Hold** and made generic, so it now
  takes ore, ice and gas in one place.
- **The Kryos has no fuel hold** — it has a Mineral Hold and an Ice Hold.
- **The Bowhead has no Industrial Ship Hold.** It has a **Ship Maintenance Bay of 1,600,000 m³**.
- There is **no Hazardous Chemical, Reagent, Deposit or Moon Materials hold** on any ship.

### The headline numbers

| Hull | Mining Hold | | Hull | Ship Maintenance Bay | Fleet Hangar |
| --- | ---: | --- | --- | ---: | ---: |
| **Rorqual** | **300,000 m³** | | **Titans** | **5,000,000 m³** | 100,000 |
| Orca | 150,000 | | Supercarriers | 5,000,000 | 50,000 |
| Porpoise, Miasmos | 50,000, 42,000 | | Carriers | **2,000,000** | 10,000 |
| Mackinaw | 31,500 | | **Bowhead** | **1,600,000** | — |
| Retriever, Procurer | 27,500, 16,000 | | Rorqual | 1,000,000 | 40,000 |
| Hulk, Covetor | 11,500, 9,000 | | Orca | 400,000 | 40,000 |
| **Venture** | 5,000 | | Deep space transports | — | **50,000** |

Note the Hulk: the best mining ship in the game has a **smaller hold than the Procurer**, because its
bonuses went into yield instead. The hold is a balance lever, not a capability.

### Access in space

Almost every special hold can be opened in flight, but each is **strictly type-filtered** — try to
put a module in a mining hold and it refuses. Two have social rules instead:

- The **Fleet Hangar** is the only hold other pilots can reach, and access is role-gated.
- The **Ship Maintenance Bay** needs the pilot to grant fleet or corporation access. Someone scanning
  your ship can see **which** ships are inside but cannot take them.

And the **Subsystem Hold** is the odd one out: you can open it in space but cannot use it there, since
subsystems can only be swapped at a station, an Upwell structure, or a **Mobile Depot**.

### Making a hold bigger

| Module or rig | Effect | Cost |
| --- | --- | --- |
| **Expanded Cargohold** (low) | More cargo | **Velocity and armour hit points** |
| **Cargohold Optimization** rig | More cargo | Velocity or armour |
| Giant Secure Container and friends | Nested storage inside the hold | Volume overhead |
| **Jetcan** | 55,000 m³ floating in space, **anyone may open it after two hours** | It is in space, not on your ship |
| **Mobile Tractor Unit** | 27,000 m³, collects wrecks and loot automatically | Destructible, and visible |

The expanded cargohold is the cleanest statement of the whole system: you may always carry more, and
it will always cost you the ability to get away.

[EVE Ref ship attributes](https://everef.net/), [EVE University: Ships](https://wiki.eveuniversity.org/Ships), [Orca guide](https://wiki.eveuniversity.org/Orca_Guide), [CCP: Cradle of War expansion notes](https://www.eveonline.com/news/view/cradle-of-war-expansion-notes), [CCP: Catalyst expansion notes](https://www.eveonline.com/news/view/catalyst-expansion-notes)

## Utility, industrial and fleet modules

### Scripts

Several modules take a **script** that redirects their bonus rather than increasing it — one of the
best small ideas in EVE's fitting system, because it makes a fitted module a *decision you can
revisit* without refitting.

| Module | Scripts available |
| --- | --- |
| **Tracking Computer**, Remote Tracking Computer, **Omnidirectional Tracking Link** | Optimal Range, or Tracking Speed |
| **Sensor Booster**, Remote Sensor Booster | Targeting Range, Scan Resolution, or **ECCM** |
| **Tracking Disruptor** | Optimal Range Disruption, or Tracking Speed Disruption |
| Remote Sensor Dampener | Scan Resolution Dampening, or Targeting Range Dampening |
| **Missile Guidance Computer** | Missile Range, or Missile Precision |
| Guidance Disruptor | Missile Range Disruption, or Missile Precision Disruption |
| **Warp Disruption Field Generator** | Focused Warp Disruption, or **Focused Warp Scrambling** |
| **Flex Armour and Shield Hardeners** | One script per damage type |

A script is loaded like ammunition, swaps in seconds, and doubles the number of things a single
module can be. The **Enhancer** variants — Tracking Enhancer, Omnidirectional Tracking Enhancer,
Missile Guidance Enhancer — are the passive counterpart: weaker, but they give both bonuses at once
and need no slot discipline.

### Siege, triage and bastion

The capital and marauder "commit everything" modules, and the clearest risk-reward trades in the
game. All of them make the ship **immobile** and **unable to receive remote repair**, and **cannot be
switched off early**.

| Module | Duration, fuel | What it gives |
| --- | --- | --- |
| **Siege Module II** (dreadnoughts) | 300 s, **250 Strontium** | **+840% turret damage**, +200% missile damage, +100% local repair, and near-immunity to dampening and weapon disruption |
| **Triage Module II** (force auxiliaries) | 300 s, 200 Strontium | **+450% remote repair amount**, +200% remote range, +5 locked targets, ×10 scan resolution — and **−100% drone damage**, no electronic warfare at all |
| **Bastion Module I** (marauders) | **60 s**, no fuel | **Double rate of fire**, +25% range, +60% local repair, **+30% resistance to every damage type**, and **immunity to all electronic warfare** |
| **Capital Industrial Core II** (Rorqual) | 300 s, 1,500 Heavy Water | **+300% drone mining yield**, +250% command burst range, +100% drone damage and hit points |

The bastion module is the most elegant of the four: sixty seconds, no fuel, and a marauder that
cannot move but cannot be jammed, dampened, or tracking-disrupted either. It turns a battleship into
a turret emplacement for exactly one minute, and knowing when to press it is most of flying one.

### Command bursts

A high-slot module that projects a **fleet-wide buff in a 15,000 m radius** for 60 seconds, fed by
charges. Only one may be online per ship, and tech 2 bursts are a flat **×1.25** on every charge.

| Burst | Charges and their base effect |
| --- | --- |
| **Shield** | Shield HP +8%, resistances +8%, or booster duration and capacitor −8% |
| **Armor** | Armour HP +8%, resistances +8%, or repairer duration and capacitor −8% |
| **Information** | Scan resolution +9% and targeting range +18%; electronic warfare range and strength +9%; or sensor strength +18% |
| **Skirmish** | **Signature radius −6% and agility −6%**; tackle range +12%; or propulsion speed bonus +12% |
| **Mining Foreman** | Range, duration, crystal preservation — and, new in Catalyst, **Mining Laser Efficiency: +50% crit chance and −15% residue** |
| **Expedition**, new in Catalyst | Probe strength +8% and analyser virus coherence +8; scanner, hacking and salvager **range +20%**; or scan deviation −8% |

The 15 km radius is what makes **anchoring** — everyone orbiting a designated ship — the basic unit
of fleet discipline. The buff does not follow the fleet; the fleet has to stay inside it.

### Exploration, salvage and industrial utility

| Module | What it does |
| --- | --- |
| **Tractor Beam** | Pulls wrecks and containers to you |
| **Salvager** | Extracts salvage from a wreck, on a chance roll improved by rigs and skills |
| **Data and Relic Analyzers** | Run the hacking minigame; the stats are **virus coherence** and **virus strength** |
| **Core and Expanded Probe Launchers** | Core probes resolve signatures; expanded ones also launch combat probes to find ships |
| Survey Scanner, Cargo Scanner, **Ship Scanner** | Read an asteroid's contents, a target's cargo, or a target's entire fit |
| Mining lasers, strip miners, ice harvesters, gas harvesters | Covered in the main reference |
| **Cynosural Field Generator**, and the covert version | Lights the beacon a jump drive or bridge needs |
| **Jump Portal Generator** | The titan bridge |
| **Interdiction Sphere Launcher** | A 20 km warp-blocking bubble for two minutes |
| **Stasis Grappler** | A battleship and capital web that gets stronger the closer the target is |

The ship scanner deserves a note: it reads **another player's entire fitting**, which makes
intelligence a module rather than a guess, and is why killboards can show what a ship was carrying.

### Deployables

| Deployable | Capacity | What it is for |
| --- | ---: | --- |
| **Mobile Depot** | 3,000 m³ | **Refit anywhere**, after a one-minute arming delay. The module that made field refitting a tactic |
| **Mobile Tractor Unit** | **27,000 m³** | Collects wrecks and loot within 125 km automatically |
| **Mobile Micro Jump Unit** | — | A 100 km forced jump for anyone who activates it |
| **Mobile Cynosural Inhibitor** | — | Blocks cyno lighting in the system — the counter to a capital drop |
| **Mobile Scan Inhibitor** | — | Hides ships on the grid from the directional scanner |
| **Mobile Observatory** | — | Rolls to reveal cloaked ships |
| **Mobile Phase Anchor**, Catalyst | — | Phases in Prismaticite asteroids; **30,000 shield at 75% resistances** |
| **Encounter Surveillance System** | — | Untargetable, with **warp scramble strength 100** — the null-sec bounty risk mechanic |

### Nanite Repair Paste

One consumable, two completely different jobs, which is unusual enough to note. It **repairs heat
damage in space**, letting a pilot reset burned-out modules without docking; and it is the **charge
that ancillary repairers burn** for a much larger repair over a short, finite run. At 0.01 m³ each,
a pilot carries thousands.

[EVE Ref: Salvager I](https://everef.net/types/25861), [Nanite Repair Paste](https://everef.net/types/28668), [EVE University: Command bursts](https://wiki.eveuniversity.org/Command_bursts), [Scripts](https://wiki.eveuniversity.org/Scripts), [Deployable structures](https://wiki.eveuniversity.org/Deployable_structures), [Siege module](https://wiki.eveuniversity.org/Siege_module), [CCP: Catalyst expansion notes](https://www.eveonline.com/news/view/catalyst-expansion-notes)

## Overheating

Overloading — shift-clicking a module — trades heat damage for performance, and it is the mechanic
that gives a fight a second gear. It is also one of the few systems in EVE where the interesting part
is the *spatial* layout of your fit.

| Module class | Overload bonus |
| --- | --- |
| **Short-range turrets** — pulse, blaster, autocannon, entropic disintegrator | **+15% damage per shot** |
| **Long-range turrets** — beam, railgun, artillery, vorton projector | **−15% cycle time** |
| Missile launchers | −15% cycle time |
| Afterburners and microwarpdrives | **+50% speed** |
| Warp disruptors and scramblers | +20% range |
| Stasis webifiers | +30% range |
| Stasis grapplers | **+300% optimal** |

Both weapon bonuses come to roughly +15% damage a second, but they are not interchangeable: the
short-range version raises **alpha**, the long-range version raises **sustained rate**. Overloading
artillery therefore does nothing for the one thing artillery is for, which is the single volley.

### The heat model

- A module has about **40 structure hit points**, and burns out when they are gone.
- Heat accumulates **per rack** — high, mid and low each have their own pool.
- Generation runs at **4% a second** for propulsion, **2%** for most tech 2 modules and **1%** for
  everything else, multiplied by hull size: **100% on a frigate down to 25% on a titan**, so big
  hulls can overload far longer.
- Heat dissipates at **1% of current heat per second**, a half-life of about **69 seconds**.
- Generation is logarithmic, so heat **asymptotes and never actually reaches 100%**.

Damage is then chance-based per cycle, scaled by rack heat and by how full the rack is, and
distributed by **position**: the overheated module is likeliest to be hit, then its immediate
neighbours, with probability falling as rack distance grows.

That last rule produces **"heatsinking"** — the practice of deliberately spacing active modules apart
in the rack, with passive or empty slots between them, so that spillover damage lands on something
that does not matter. It means the *order* modules sit in is a real fitting decision, which is an
unusual and rather elegant thing for a game to ask.

The honest note: it is also completely undiscoverable. Nothing in the interface suggests that slot
adjacency matters.

### Repair

**Nanite Repair Paste** repairs heat damage in space. Repairs take time, can be cancelled, are
cancelled automatically by a gate or cyno jump, and the module **cannot be used while being
repaired**. Thermodynamics reduces heat damage by 5% a level, and level I is the gate on overloading
anything at all; Nanite Interfacing speeds repair and Nanite Operation reduces paste consumption.

[EVE University: Overheating](https://wiki.eveuniversity.org/Overheating), [Nanite repair paste](https://wiki.eveuniversity.org/Nanite_Repair_Paste), [EVE Ref: Heavy Pulse Laser II](https://everef.net/type/3520)

## Ideas for Oolite

Oolite's equipment model is a flat list of about forty `EQ_` keys gated by tech level and price. Seven
of them are weapons, one of each per ship, chosen from a four-mount bitmask (`weapon_facings` — 12
core hulls are forward-only, 8 have all four). Only the passenger berth consumes hold space or can be
fitted more than once. Energy recharges **linearly** —
`energy += energy_recharge_rate * delta_t`, `ShipEntity.cpp:2862` — with no curve and no peak.

So almost nothing in this document transfers directly, and most of it should not. What follows is the
short list of mechanics that are small, self-contained, and would answer questions Oolite's own
feature list already asks.

### Five that fit best

1. **A fitting budget.** EVE's CPU and powergrid are the general form of the "equipment mass" idea
   already in the ideas doc, and the better form: a shared numeric budget per hull means ships
   specialise without a single new item being added. Oolite's hulls currently differ in hold, speed
   and gun mounts; a budget would make them differ in *character*.
2. **The stacking penalty.** `exp(−((n−1)/2.67)²)` — 100%, 87%, 57%, 28%, 11%. The moment Oolite
   allows a second shield booster, as the Frontier stackable-shields idea proposes, it needs this.
   It forbids nothing and makes excess visibly pointless, which is far better than an arbitrary cap.
3. **A non-linear energy curve.** EVE's capacitor peaks at **25% of capacity** and collapses below it,
   which creates a real "break off now" threshold in every fight. Oolite's linear recharge has no
   such moment, and this is a two-line change to `ShipEntity.cpp` with a large effect on how combat
   feels.
4. **Scripts.** A loaded module that can be re-aimed — optimal range *or* tracking speed, targeting
   range *or* scan resolution — doubles what one item can be, at no content cost. Oolite has nothing
   like it, and `EQ_` items with a swappable mode would be cheap to express.
5. **Special holds.** A hold that accepts only one category of cargo is how EVE makes a hauler a
   specialist without giving it a bigger number. Oolite has one hold and a 5 t passenger berth; an ore
   hold, a fuel bay or a passenger deck would differentiate hulls immediately — and the mining sketch
   needs one anyway.

### Weapons

| Idea | What EVE does | Oolite today |
| --- | --- | --- |
| **Short-range against long-range, per family** | Every turret family splits into a high-damage short-range and a high-alpha long-range variant, so the choice is a doctrine not an upgrade | Pulse → beam → military is a straight power ladder; the mining laser is the only sidestep |
| **Ammunition as the range/damage dial** | Eight charge steps from ×0.5 to ×1.6 optimal range, with damage inverse to range, selected before undocking | Lasers have no ammunition at all |
| **Damage types against resistances** | Four damage types against four resistances, with shields weak to EM and armour weak to explosive — so ammunition choice is tactical | One damage number |
| **Reusable ammunition as a trade** | Amarr crystals never reload and never run out, paid for in capacitor and in only ever dealing two damage types | Lasers are free and unlimited, with no counterweight |
| **Weapons that ramp** | The entropic disintegrator gains 7% a cycle to **×3.125**, and resets completely on any interruption | Nothing changes during sustained fire |
| **Area weapons with no target** | Smartbombs hit everything within a few kilometres, friendlies included | The Q-mine is the only area weapon |
| **A fixed-range weapon** | Bombs detonate at exactly 30 km, can be shot down in flight, and are countered by other bombs | None |
| **Overheating** | +15% for heat damage, with damage spilling to **adjacent slots**, so rack layout matters | None; equipment damage is random on hit |

### Defence and support

| Idea | What EVE does | Oolite today |
| --- | --- | --- |
| **Three tank archetypes** | Buffer, active and passive, each beaten by something different — buffer by alpha, active by capacitor warfare, passive by raw damage | One energy bank and an optional shield booster |
| **The adaptive hardener** | The Reactive Armour Hardener moves 6 points of resistance a cycle toward whatever is hitting you, conserving a 60-point total | None |
| **A module that is always correct** | Damage Control touches all three layers, is passive and cannot be switched off — the one item everyone fits | `EQ_ENERGY_UNIT` is close in spirit |
| **Capacitor warfare** | Neutralisers empty the target's capacitor, disabling active tanks, propulsion and lasers; batteries resist it; buffer fits ignore it | ECM exists but only against missiles |
| **Probabilistic against deterministic counters** | ECM is a coin flip that removes a ship from the fight; dampeners always land but only partially. Having both is the design | None |
| **Support that multiplies the fleet** | A target painter raises the target's signature, improving **everyone's** guns | NPC escorts have no support roles |
| **Remote repair** | Everything a ship can do for itself it can do better for someone else, which is why fleets buffer-tank | None |

### Ships and configuration

| Idea | What EVE does | Oolite today |
| --- | --- | --- |
| **Rigs** | Permanent specialisations on a separate budget, **destroyed if removed** — so a hull commits | Equipment is freely removable, and only the passenger berth has a removal item |
| **Reconfigurable hulls, two ways** | Strategic cruiser subsystems (economic, docked, 81 combinations, the hull is empty without them) and tactical destroyer modes (free, instant, three states) | One hull, one configuration |
| **Hardpoints separate from slots** | Turret and launcher hardpoints are counted apart from high slots, so "spare" slots become utility slots | `weapon_facings` and `max_missiles` are the nearest thing, and are already a four-mount bitmask |
| **Drones** | Two hull limits — bay volume and bandwidth — plus a skill cap of five, so the same drones behave differently per hull | None; the ideas doc already wants them |
| **A cloak with real costs** | −90% speed on the cheap one, no warping, a 30-second blindness after decloaking, and a 2 km proximity rule | `EQ_CLOAKING_DEVICE` exists, mission-only, with energy drain as its cost |
| **Commit-everything modules** | Siege and bastion give enormous bonuses for immobility, no remote repair, and no early cancel | None |

### What not to take

| Avoid | Why |
| --- | --- |
| **The depth itself** | EVE's fitting system cannot be learned in the client. The community's answer is a third-party offline simulator, and a doctrine document that tells you what to fit. That is a failure, not a feature |
| **Seven meta rungs** | Tech 1, meta 1–4, tech 2, storyline, faction, deadspace, officer and abyssal is a loot economy for an MMO. Oolite has one player |
| **Modules that only exist as traps** | The meta 4 gun that matches tech 2's range at lower fitting cost is a nice secret, but it means the obvious choice is wrong and nothing in the game says so |
| **Randomised module stats** | Mutaplasmids put the best fits in the game partly down to luck, and move them onto a contract market |
| **Undiscoverable mechanics** | Heat damage spreading to *adjacent slots* makes rack order matter, and nothing in the interface hints at it. A good idea, delivered invisibly |

## Sources

Grouped by reliability, because it varies sharply and it matters which was used for what.

### Game data, generated from the game itself

The source for essentially every number in this document.

- **[EVE Ref](https://everef.net/)** and its [reference-data API](https://ref-data.everef.net/),
  generated from the Static Data Export. Representative pages used:
  turrets — [Heavy Pulse Laser II](https://everef.net/type/3520),
  [Mega Pulse Laser II](https://everef.net/type/3057),
  [Tachyon Beam Laser II](https://everef.net/type/3025),
  [425mm AutoCannon II](https://everef.net/type/2929),
  [Scorch M](https://everef.net/type/12818),
  [Heavy Entropic Disintegrator I](https://everef.net/type/47273);
  missiles — [Rocket Launcher II](https://everef.net/type/10631),
  [Rapid Light Missile Launcher II](https://everef.net/type/1877),
  [Scourge Cruise Missile](https://everef.net/type/203);
  defence — [Medium Shield Extender II](https://ref-data.everef.net/types/3831),
  [Multispectrum Shield Hardener II](https://ref-data.everef.net/types/2281),
  [Reactive Armor Hardener](https://ref-data.everef.net/types/4403),
  [Damage Control II](https://ref-data.everef.net/types/2048),
  [Medium Cap Battery II](https://ref-data.everef.net/types/3496);
  electronic warfare — [Gravimetric ECM II](https://ref-data.everef.net/types/2571),
  [Remote Sensor Dampener II](https://ref-data.everef.net/types/1969),
  [Target Painter II](https://ref-data.everef.net/types/19806),
  [Heavy Energy Neutralizer II](https://ref-data.everef.net/types/12271);
  mobility — [50MN Microwarpdrive II](https://everef.net/types/12076),
  [Warp Scrambler II](https://everef.net/types/448),
  [Medium Higgs Anchor I](https://everef.net/types/34268);
  cloaks — [Prototype Cloaking Device I](https://everef.net/types/11370),
  [the cloaking group](https://everef.net/groups/330);
  rigs — [Medium Trimark Armor Pump](https://everef.net/types/31055),
  [Medium Capacitor Control Circuit I](https://everef.net/types/31372),
  [the navigation rig group](https://everef.net/groups/782);
  tech 3 — [Legion](https://everef.net/types/29986),
  [Dissolution Sequencer](https://everef.net/types/45622),
  [the subsystem categories](https://everef.net/categories/32),
  [Confessor](https://everef.net/types/34317)
- **[ESI](https://esi.evetech.net/ui/)**, CCP's own API, for type-ID resolution and live market data
- The **Static Data Export** itself, dated 2 November 2026, for the exhaustive hold and bay
  enumeration and for confirming which attributes exist on no live hull

**Two data-reading traps**, both of which bit more than one research pass and are worth recording:

1. **EVE Ref renders multiplier attributes with a stray percent sign.** Scorch M shows "Range bonus:
   1.4%" where the item means **×1.4, that is +40% optimal range**. A Ballistic Control System's
   "Rate of Fire Bonus: 0.895%" means **×0.895, a 10.5% shorter cycle**. Every such figure in this
   document has been converted.
2. **Numbers in community guides are frequently a balance pass out of date.** Where EVE University
   and the Static Data Export disagree, the export is used.

### The studio

- [Catalyst expansion notes](https://www.eveonline.com/news/view/catalyst-expansion-notes),
  [Cradle of War expansion notes](https://www.eveonline.com/news/view/cradle-of-war-expansion-notes),
  [patch notes 24.01](https://www.eveonline.com/news/view/patch-notes-version-24-01),
  [Fractured Skies In Focus](https://www.eveonline.com/news/view/fractured-skies-in-focus),
  [Fractured Skies arrives 10 Nov](https://www.eveonline.com/news/view/fractured-skies-expansion-arrives-10-nov),
  [Force Projection Revamped](https://www.eveonline.com/news/view/major-update-force-projection-revamped),
  [Lighting the invention bulb](https://www.eveonline.com/article/lighting-the-invention-bulb)

### EVE University

Reliable for **how a mechanic works**, unreliable for **what the number is** — several module pages
predate recent balance passes, and the missile pages in particular still quote superseded torpedo
figures.

[Fitting](https://wiki.eveuniversity.org/Fitting) ·
[Stacking penalty](https://wiki.eveuniversity.org/Stacking_penalty) ·
[Capacitor](https://wiki.eveuniversity.org/Capacitor) ·
[Turrets](https://wiki.eveuniversity.org/Turrets) ·
[Turret damage](https://wiki.eveuniversity.org/Turret_damage) ·
[Missile mechanics](https://wiki.eveuniversity.org/Missile_mechanics) ·
[Missile damage](https://wiki.eveuniversity.org/Missile_damage) ·
[Smartbombs](https://wiki.eveuniversity.org/Smartbombs) ·
[Bombs](https://wiki.eveuniversity.org/Bombs) ·
[Doomsday devices](https://wiki.eveuniversity.org/Doomsday_device) ·
[Shield tanking](https://wiki.eveuniversity.org/Shield_tanking) ·
[Passive shield tanking](https://wiki.eveuniversity.org/Passive_shield_tanking) ·
[Armor tanking](https://wiki.eveuniversity.org/Armor_tanking) ·
[Natural resistances](https://wiki.eveuniversity.org/Natural_Resistances) ·
[Electronic warfare](https://wiki.eveuniversity.org/Electronic_warfare) ·
[Logistics](https://wiki.eveuniversity.org/Logistics) ·
[Propulsion modules](https://wiki.eveuniversity.org/Propulsion_module) ·
[Warp disruption](https://wiki.eveuniversity.org/Warp_disruption) ·
[Cloaking](https://wiki.eveuniversity.org/Cloaking) ·
[Rigs](https://wiki.eveuniversity.org/Rigs) ·
[Subsystems](https://wiki.eveuniversity.org/Subsystems) ·
[Tactical Destroyer](https://wiki.eveuniversity.org/Tactical_Destroyer) ·
[Drones](https://wiki.eveuniversity.org/Drones) ·
[Fighters](https://wiki.eveuniversity.org/Fighters) ·
[Command bursts](https://wiki.eveuniversity.org/Command_bursts) ·
[Scripts](https://wiki.eveuniversity.org/Scripts) ·
[Overheating](https://wiki.eveuniversity.org/Overheating) ·
[Deployable structures](https://wiki.eveuniversity.org/Deployable_structures) ·
[Meta levels](https://wiki.eveuniversity.org/Meta_levels) ·
[Mutaplasmids](https://wiki.eveuniversity.org/Mutaplasmids) ·
[Upwell structures](https://wiki.eveuniversity.org/Upwell_structures)

### Oolite

The "Oolite today" column under **Ideas for Oolite** comes from Oolite's own core data and source in
this repository — `Resources/Config/equipment.plist`, `Resources/Config/shipdata.plist` and
`src/Core` — read at the commit current on 3 November 2026. **No expansion packs were read.**

### Companion documents

- [EVE Online — Feature Reference](<EVE Online — Feature Reference.md>) — the whole game, including
  the ship-class ladder, prices and the economy these modules are bought in
- [Mining and Manufacturing — Design Sketch](<Mining and Manufacturing — Design Sketch.md>) — the
  mining career these mining modules would serve
- [Oolite Feature Ideas](<Oolite Feature Ideas.md>) — the running list this feeds
