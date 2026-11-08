# Space Reign — Feature Reference

Nov 7, 2026 · @Jon Seaman

Space Reign is the newest and smallest game in this folder, and it is here for three things nothing
else in the set provides.

The first is **no energy shields.** Combat is armour and armour penetration, with ricochets when a
gun is badly outmatched and explosive damage that bypasses armour entirely. Every other game here —
Elite, Oolite included, X4, EVE, Freelancer, Privateer — runs on a recharging shield pool. This one
deleted it, and players list its absence as a reason they like the game.

The second is **switching into any ship you own.** You give fleet orders from an RTS view, then drop
into the cockpit of a fighter in first person or onto the bridge of a capital ship in third person,
and swap again whenever you like. It is the only game in the folder that answers "what if the fleet
and the cockpit were the same game", and it is worth knowing what that costs before wishing for it.

The third is that it is **a two-person studio's shipped game, still being patched**, and its reviews
are an unusually clear list of what goes wrong when combat lacks consequence. The criticism is the
most useful part of this reference — more useful than the features — because the complaints are
specific, repeated, and about exactly the systems Oolite already has.

**On sources.** There is no manual and no official wiki; the fan wiki is small. Everything here comes
from the Steam store page and its news, community guides, player discussions, a mod's own
documentation and one trade article. Figures are version-dependent and the sources span patches 0.73
to 1.1. This is a reference about a live, small project and should be re-checked rather than trusted.

## Overview

| Item | Value |
| --- | --- |
| Early access | **12 June 2023** |
| Full release | **10 March 2026** |
| Latest content seen in sources | **1.1**, around May 2026 — added the S3 autocannon |
| Developer and publisher | **Propulsive Games** — two people, Adam Benko and Daniel Sýkora |
| Development | about **seven years** before release |
| Engine | Unity |
| Price | **$19.99**, plus a $2.49 soundtrack |
| Players | **Single-player** only |
| Setting | Near future; resource-exploiting corporations fighting over territory. You are one of the corporations |
| Stated inspirations | **Homeworld** and **The Expanse** |
| Steam reviews | **Mostly Positive** — 73% of 454 at the time of writing; recent reviews Mixed at 68% of 29 |
| Platform | Windows 10/11; minimum an i5-7600 and a GTX 1050 Ti, 15 GB |
| Notable disclosure | The developers declare **pre-generated AI voice synthesis** for pilot radio chatter and the communications officer |

Two of those rows are worth pausing on. **Seven years, two people** is the production context for
everything else in this document — it explains both the unusual core idea and the thinness around it.
And the **AI voice disclosure** is the first time one has appeared in this folder; Steam requires it,
and a two-person studio voicing a fleet's radio chatter any other way is not realistic. Recorded
because it is now part of how small studios ship, not as an endorsement.

## One game at two scales

The structure is a hybrid, and the hybridisation is the product:

- **An RTS-style tactical view**, where you issue orders and manage the fleet **ship by ship**.
- **Direct control of any ship in the fleet, switchable at any time** — agile fighters from a
  **first-person cockpit**, large ships from **third person**, firing their heavy weapons yourself.

So the fleet is not a stack with a power rating, as it is in Stellaris, and it is not a set of
subordinates you brief and then watch, as in X4. It is a set of vehicles you can personally be in.
The design claim is that you command at the scale where the decision lives and fly at the scale where
the shooting is interesting.

**What it would cost Oolite.** This is the one headline feature in the folder that is architecturally
expensive rather than cheap. Oolite is built around a single player ship —
`PlayerEntity::sharedPlayer()` is the engine's spine, and the multiplayer section of the ideas doc
already notes that. Being able to *be* any ship means the player is a camera and control surface that
attaches to an entity, not a kind of entity. That is the same de-globalising direction the migration
work is already going in, which is the interesting part: the refactor that makes headless in-process
sims possible is also the refactor that makes "fly your escort instead" possible. Worth knowing that
the two wishes share a prerequisite.

### Where the fleet layer falls short

Players are blunt about the gaps, and they are instructive:

- **Fighter bays have no real role** in deployment or repair, so carriers are hulls with hangars
  rather than a mechanic. One reviewer calls the game an incomplete prototype on that basis.
- **Fleet mechanics are called restrictive** in aggregated community feedback, alongside AI and
  combat complaints and technical performance issues.

The lesson is that a carrier is not a ship with a bay; it is a set of rules about launching,
recovering, rearming and repairing. X4 has those rules — carriers repair and rearm docked S and M
ships, auxiliaries do it for every size — and that is the difference between a carrier and a model of
one.

## Combat without shields

This is the part worth studying, and it is a complete, coherent alternative to the shield pool that
every other game in this folder uses.

### Armour and penetration

Ships have **armour**; weapons have **armour penetration**. The interaction, as the community
describes it:

- A weapon whose penetration is **well below** the target's armour can **ricochet**, and the
  ricochet chance **falls to zero** as the gap between penetration and armour grows large enough in
  the attacker's favour. Players dispute the simple reading — one thread reports ricochets even when
  penetration exceeds the armour rating — so the exact curve is unsettled, but the shape is clear:
  **mismatch is punished, and badly enough that the wrong gun simply does not work.**
- **Autocannons do poorly against armour above 2**, to the point that players say they do not do
  appreciable damage to larger targets at all.
- **Explosive damage ignores armour**, and **flak counts as explosive.**

That last rule is the elegant one. With a single line — explosives bypass armour — the game gets a
rock-paper-scissors between guns, armour and missiles without any damage-type matrix, any resistance
profile, or any arithmetic the player has to do. Compare Privateer's three shield types with a ±20%
swing, or EVE's four damage types against four resistances. This is the cheapest version of the same
idea.

### Subsystem damage, and the consequence problem

Ships have subsystems that can be hit. By default, **subsystem damage does not appear to bleed into
hull damage** — which is inferred from the existence of a mod whose "hull bleed" option makes
subsystem hits do full hull damage at a setting of 1, on a 0–1 fraction.

And this is where the reviews turn, in the single most useful sentence in the sources:

> it makes taking damage feel utterly meaningless unless something blows up

The same reviewer's proposed fix is that **ship upkeep should cost something when ships take heavy
damage.** Another community thread argues the game needs defensive progression at all, not just
better guns.

For Oolite that is corroboration rather than a new idea. Oolite already has a ship-wide service level
from 75 to 100 that falls with jumps and damage, lowers trade-in value, and below 80 raises misjump
chance, with the maintenance overhaul resetting it. Space Reign is a shipped game whose most common
complaint is the absence of exactly that mechanic. **Damage needs a cost that is paid later**, or the
combat it comes from does not matter.

### Point defence competes with guns

Weapons mount on **sized hardpoints** — S1, S2, S3 — and the layout differs per hull. The
consequences are real:

- The best point-defence weapon, the **PDL-1 laser**, requires an **S2 hardpoint**, so fitting it
  "sacrifices offensive capabilities for missile defence only". Defence and offence draw on the same
  budget.
- **Fighters cannot mount point defence at all** — it appears limited to medium and larger hulls, so
  small craft are structurally vulnerable to missiles and need the fleet to cover them.
- Fighter loadouts trade across sizes: the Ares has one S2 gun hardpoint, which lets it carry two S3
  missile hardpoints instead.
- At the top end, the **Mothership has 13 hardpoints**, making it the most heavily armed hull in the
  game.

This is the fitting-budget idea again — the one EVE, Privateer and X4 each reach by a different route
— in its simplest possible form: **slots have sizes, and everything competes for them, defence
included.**

### Torpedoes

Slow, with a long lock time, **targeting large ships only**, and doing extremely high damage. The
**HAT-64 heavy torpedo silo** is described as deliberately durable, so the torpedo survives point
defence long enough to arrive. So the anti-capital weapon is a projectile the defender is expected to
shoot at, which is what makes the point-defence hardpoint decision matter in the first place. The
three systems — armour, torpedoes, point defence — are designed against each other.

## Ships

Hulls come in **small, medium and large** tiers, with **cruisers added at the 1.0 release** in March
2026 as the newest class. Named hulls in the community guides include the **Bullfrog** gunship, the
**Prowler** scout frigate, the **Caiman** combat frigate, the **Koi** and **Kirin** support ships,
the **Taurus** heavy frigate, and the **Bowhead** and **Vulture**; the **Mashar**, **Terigon** and
**Valeris** are industrial or multi-purpose frigates. The **Kirin** support barge carries five weapon
hardpoints including one S2.

You buy ships and configure each one **weapon by weapon**, and the store's framing of the choice is a
good statement of the trade: build a flexible fleet that can do several jobs, or commit the fleet to
one task and one playstyle.

## Structure

Progression is **randomised contracts of several types, in gradually harder sectors**, with
**Conquest sectors** as the more complex form: capture control points and build defences. There is no
trading economy, no stations to walk around, no reputation web — the game is combat and fleet
management, and the campaign is a difficulty gradient across a sector map.

That is a narrower design than anything else in this folder, and it is the right choice for two
people. It is also why this reference has no economy section.

## Modding

Not officially supported, but the data is reachable: a community mod rebalances **any ship or weapon
through a JSON file**, including **resizing hardpoints** and **creating custom ship and weapon
variants**, and exposes tuning values such as the hull-bleed fraction.

So the pattern from Freelancer and Privateer repeats a third time: **the game is data, the data is
legible, and a mod scene appears without the developers doing anything about it.** For a game three
months out of early access with two developers, that is the cheapest possible longevity insurance.

## Scale numbers

Community-sourced and version-dependent.

| Quantity | Value |
| --- | --- |
| Early access → release | 12 Jun 2023 → **10 Mar 2026** |
| Development before release | about **7 years** |
| Team | **2** |
| Price | **$19.99** |
| Steam reviews | 73% positive of **454** (recent: 68% of 29) |
| Hardpoint sizes | **S1, S2, S3** |
| Most hardpoints on a hull | **13**, the Mothership |
| Kirin support barge | **5** hardpoints, one of them S2 |
| Ares fighter | 1× S2 gun **or** 2× S3 missile |
| Autocannon effectiveness ceiling | poor against **armour above 2** |
| Shields | **none** |
| Explosive and flak damage | **ignores armour** |
| Ship tiers | small, medium, large; **cruisers added in 1.0** |
| Minimum spec | i5-7600, 8 GB, GTX 1050 Ti, 15 GB |

### What could not be verified

- **The armour and penetration formula.** Ricochet exists and mismatch is punished, but the curve is
  described inconsistently by players and one thread contradicts the simple reading. No developer
  documentation found.
- **Whether subsystem damage affects hull by default.** Inferred from a mod that adds the option.
- **The full ship roster, weapon list and hardpoint layouts.** Community guides cover parts of each,
  and the fan wiki blocks automated access.
- **What 1.0 and 1.1 actually changed**, beyond cruisers and the S3 autocannon.
- **Whether the game is still in active development** as of November 2026, and any roadmap beyond
  1.1.
- **Sales.** None published. The 454 review count is the only proxy, and it is not one.
- **Whether the "restrictive fleet mechanics" complaint has been addressed** since the aggregated
  feedback was collected.

## Ideas for Oolite

A two-person combat game with no economy has less to offer than X4 or EVE, and most of what it does
have is in one system: **how damage works when there are no shields.** That system is complete,
cheap, and genuinely different from everything else in this folder.

### Five that fit best

1. **Armour and penetration instead of a shield pool.** Hulls carry an armour value, weapons carry a
   penetration value, and a weapon badly outmatched by its target **ricochets** rather than chipping
   away. This makes the question "can this gun hurt that ship at all?" a real one, which a recharging
   shield pool can never ask. Oolite's shields and the energy bank are deeply embedded, so this is a
   thought experiment rather than a patch — but it is the clearest available alternative model, and
   the one players of this game single out as the reason they like it.
2. **One line of rock-paper-scissors: explosive damage ignores armour.** Flak and missiles threaten
   armour that guns cannot scratch, with no damage-type matrix, no resistance profile and no
   arithmetic for the player. Compare Privateer's ±20% three-type table and EVE's four-by-four;
   this achieves most of the same effect in a sentence.
3. **Sized hardpoints where defence competes with offence.** S1/S2/S3 slots, per-hull layouts, and a
   point-defence laser that costs you an S2 mount — so an anti-missile fit is paid for in guns. It is
   the simplest form of the fitting budget that the EVE, Privateer and X4 references each arrive at
   from a different direction, and the closest to something Oolite's existing mount system could
   express.
4. **Damage must cost something later.** The sharpest complaint in this game's reviews is that taking
   damage is meaningless unless a ship explodes, and the proposed fix is upkeep that scales with how
   badly beaten up a ship is. Oolite already has that mechanic — the 75-to-100 service level that
   falls with damage, lowers trade-in value and raises misjump chance below 80. This is external
   evidence that it is load-bearing and should not be simplified away.
5. **A carrier is a set of rules, not a hull with a bay.** Space Reign ships fighter bays with no real
   deployment or repair role and gets called a prototype for it. If Oolite ever wants carriers, the
   rules — launch, recover, rearm, repair, and what happens to the fighters when the mothership dies
   — are the feature.

### Combat and equipment

| Idea | What Space Reign does | Oolite today |
| --- | --- | --- |
| No energy shields | Armour and penetration carry the whole defensive model, and players cite the absence of shields approvingly | Shields are a recharging pool sharing the energy bank with lasers |
| Ricochet on mismatch | A gun well below the target's armour can bounce off, with the chance falling to zero as the gap closes in the attacker's favour | Damage always lands |
| Explosives bypass armour | Missiles and flak are the answer to armour guns cannot penetrate | Missiles do more damage; nothing bypasses anything |
| Sized hardpoints | S1/S2/S3, per-hull layouts, cross-trades such as one S2 gun instead of two S3 missiles | Fore, aft, port and starboard mounts; equipment is separate from them |
| Defence on the same budget as offence | The best point-defence laser needs an S2 slot, so anti-missile capability is bought with guns | ECM is a separate equipment item with no opportunity cost |
| Class-gated defences | Fighters cannot mount point defence at all, so small craft depend on the fleet for missile cover | All ships can fit ECM if they can afford it |
| An anti-capital weapon the defender shoots at | Torpedoes are slow with a long lock, target large ships only, hit very hard, and come in a deliberately durable silo so they survive point defence | Missiles are countered by ECM outright |
| Subsystem damage | Subsystems take damage; by default it does not appear to reach the hull, which is the root of the consequence complaint | A single hull value, plus equipment that can be damaged |

### Fleet and scale

| Idea | What Space Reign does | Oolite today |
| --- | --- | --- |
| Be any ship you own | Switch into any hull at any time — first person in fighters, third person in capitals | One player ship; `PlayerEntity::sharedPlayer()` is the engine's spine |
| Command at one scale, fly at another | RTS-style order view plus per-ship direct control, in the same session | Escorts follow; the player flies one ship |
| Orders ship by ship | The fleet is managed individually rather than as a stack with a power rating | — |
| A fleet that is a set of vehicles | Not subordinates you brief and watch, as in X4, but craft you can occupy | — |
| Commit or stay flexible | The store frames fleet design as a choice between several roles or one specialism | Ship choice is the same decision at one-ship scale |

### Rules worth stealing outright

- **Delete a system to see what it was doing.** Removing shields forced armour, penetration,
  ricochet, explosive bypass and point-defence budgeting to carry the whole weight, and the result is
  more interesting than the shield pool it replaced. The exercise is worth doing on paper even if the
  answer is to keep shields.
- **One rule beats a matrix.** "Explosive damage ignores armour" is the whole counter-system.
- **Put defence and offence on the same budget.** Otherwise a defensive item is never a decision,
  just a purchase.
- **Make damage cost something after the fight.** The absence of this is the most-repeated complaint
  about a game that is otherwise praised for its combat.
- **Ship the rules, not the object.** A fighter bay with no deployment or repair rules is a model of a
  carrier.
- **Small teams should narrow, not thin.** Two people shipped a combat-and-fleet game with no
  economy, no stations and no reputation, and the result reviews at 73%. The parts that are there are
  not spread thin; the parts that are missing are simply absent.
- **Expect a mod scene whether you plan one or not.** A JSON config was enough for the community to
  start resizing hardpoints and creating ship variants within months of release.

### What not to take

- **Subsystem damage that does not reach the hull.** It is the mechanical cause of the "damage feels
  meaningless" complaint.
- **Fighter bays without deployment rules**, and more generally shipping the hull before the
  mechanic.
- **An armour formula the players cannot agree about.** Ricochet is a good mechanic described badly
  enough that community threads contradict each other about when it happens. If a rule gates whether
  a weapon works at all, the player needs to be able to read it.
- **Offence-only progression.** A community thread specifically asks for defensive technology rather
  than more guns, which is what happens when every upgrade path adds damage.
- **The ship-switching architecture, if it is not already free.** It is the one headline feature in
  this folder that would require restructuring Oolite's player model rather than adding to it.
  Worth doing only as a consequence of the de-globalising work, never as the reason for it.

## Sources

The thinnest sourcing in the folder, and all of it community or commercial. Nothing here is
documentation.

### Official

- **[Space Reign on Steam](https://store.steampowered.com/app/1762570/Space_Reign)** — the store
  description and feature list: ship switching with first-person fighters and third-person capitals,
  the RTS order view, weapon-by-weapon loadouts, randomised contracts and Conquest sectors, the
  near-future corporate setting, the 12 June 2023 early access and 10 March 2026 release dates,
  price, single-player, system requirements, the review percentages, and the AI voice-synthesis
  disclosure
- [Space Reign news hub](https://steamcommunity.com/app/1762570/allnews/) — patch announcements
- [Propulsive Games' own posts](https://lr.in.psf.lt/r/Unity3D/comments/14wlbdx/after_more_than_4_years_of_development_with_no)
  and [the early access announcement](https://lr.eu.psf.lt/r/Games/comments/1ds0f82/space_reign_propulsive_games_spacesim_rts)
  — the two-person team, Unity, and the development timeline
- [Adam Benko](https://sk.linkedin.com/in/adam-benko-181b71160) — co-owner, for the team size

### Trade coverage

- [GameDaily: Space Reign blends space sim combat and RTS fleet command](https://gamedaily.com/news/space-reign-blends-space-sim-combat-and-rts-fleet-command)
  — the clearest third-party description of the hybrid design

### Community guides, discussions and mods

Where every mechanical detail in this reference comes from. Several span patches 0.73 to 1.1.

- [Space Reign Ship Guide — 1.1 Release](https://steamcommunity.com/sharedfiles/filedetails/?id=3687092993)
  — the named hulls, the tiers, cruisers as the 1.0 addition, and hardpoint counts
- [Space Reign wiki: ships](https://spacereign.fandom.com/wiki/Ships) and
  [weapons](https://spacereign.fandom.com/wiki/Weapons) — the small/medium/large grouping and the
  weapon list. Blocks automated fetching, so reached through search summaries
- Steam discussions: [best weapons per ship class](https://steamcommunity.com/app/1762570/discussions/0/510695796907206137/),
  [best combination so far](https://steamcommunity.com/app/1762570/discussions/0/592887534192703508/),
  [the game needs defensive tech, not just offensive](https://steamcommunity.com/app/1762570/discussions/0/4638240954399090441/),
  and [thoughts on 1.1](https://steamcommunity.com/app/1762570/discussions/0/844005093415082830/)
  — the PDL-1's S2 requirement, fighters being unable to mount point defence, torpedo behaviour, the
  HAT-64 silo, autocannons against armour above 2, and explosive damage ignoring armour
- [Mod: Space Reign Tweaks](https://steamcommunity.com/app/1762570/discussions/0/561409322576390446/)
  — the JSON config, hardpoint resizing, custom ship and weapon variants, the hull-bleed fraction,
  and the ricochet description
- [Steam reviews, top rated](https://steamcommunity.com/app/1762570/reviews/?browsefilter=toprated)
  — "taking damage feel utterly meaningless unless something blows up", the upkeep suggestion, the
  praise for the flight model and the absence of energy shields, and the fighter-bay criticism
- [VaporLens community-sentiment summary](https://vaporlens.app/app/1762570/space_reign) and
  [steamstat.io](https://steamstat.io/app/1762570) — the aggregated negatives (technical
  performance, restrictive fleet mechanics, AI and combat) and the review counts. Auto-generated, so
  weighted lightly

### Oolite

- [Oolite Feature Ideas](<../../notes/Oolite Feature Ideas.md>) — the multiplayer section's note
  about the engine being built around one player ship, which is what ship-switching would touch
- [X4: Foundations](<X4 Foundations — Feature Reference.md>) — carriers and auxiliaries done as
  rules, and the fleet-subordinate model this game's RTS view is an alternative to
- [EVE Online — Modules and Fitting](<EVE Online — Modules and Fitting Reference.md>) and
  [Wing Commander: Privateer](<Wing Commander Privateer — Feature Reference.md>) — the other two
  fitting-budget models, for comparison with sized hardpoints
- [Space Rangers](<Space Rangers — Feature Reference.md>),
  [Stellaris](<Stellaris — Feature Reference.md>),
  [Freelancer](<Freelancer — Feature Reference.md>),
  [EVE Online](<EVE Online — Feature Reference.md>),
  [Elite Dangerous](<Elite Dangerous — Feature Reference.md>),
  [Frontier: Elite II and First Encounters](<Frontier Elite II and First Encounters — Feature Reference.md>),
  [Elite (1984)](<Elite (1984) — Feature Reference.md>) — the rest of the set
