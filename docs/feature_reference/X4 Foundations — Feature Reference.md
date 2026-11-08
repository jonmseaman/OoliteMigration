# X4: Foundations — Feature Reference

Nov 3, 2026 · @Jon Seaman

X4 is the single-player answer to EVE Online. Egosoft's pitch is four verbs — TRADE, FIGHT, BUILD,
THINK — and the fourth one is the point: X4 is the only game in this set where the entire economy
is manufactured, carried and sold by ships that actually exist, and where the player can end up
owning a share of it. Nothing is spawned into a market. A laser on a destroyer traces back through
hull parts and claytronics to ore that some NPC miner shot off an asteroid, and if you blockade the
ore the destroyer does not get built.

That makes it the most useful reference of the five for anything about economy, industry, fleets or
owning property, because unlike EVE it reaches those systems without a single other player. Where
EVE needs thousands of people to make an order book live, X4 gets a working economy out of about
ten thousand NPC ships. For Oolite — one player, one galaxy, a script-driven populator — that is
the relevant trick.

X4 is also the clearest worked example of **the map as the command interface**, which is the thing
the [Oolite Feature Ideas](<../../notes/Oolite Feature Ideas.md>) doc keeps circling: a system map that is not
a picture but the screen you give orders from.

**On sources.** Egosoft's own manual is the best writing on X4's mechanics and the worst guide to
its current numbers. The PDF is version 77.1, authored January 2025, and most of its chapters still
say "Updated for version 5.10" — four major versions behind the live game. Mechanics described
there are generally still true in shape; figures may not be. Concrete recent numbers here come from
**patch notes** (9.00, 8.00, 7.50) and from the **official community wiki's** reputation and
feature-history pages. Community wikis and guides are used for how things feel, not for what they
cost. The two fan wikis disagree with each other and with Egosoft about sector counts, so those are
left in the unverified list rather than asserted.

**On the series.** Egosoft has been making this one game since 1999, and X4 is the fourth attempt
plus a recovery. *X: Beyond the Frontier* (1999), *X2: The Threat* (2003) and the *X3* trilogy
(*Reunion* 2005, *Terran Conflict* 2008, *Albion Prelude* 2011) built the formula; *X Rebirth*
(2013) broke it by cutting the player down to one flyable ship and was received badly enough to
become a cautionary tale. X4 is the repair job: every ship flyable again, plus everything X3's
players had modded in by hand. That history matters for a migration project, because X4's design is
visibly the result of a studio deciding which of its own earlier features were load-bearing.

## Overview and timeline

| Item | Value |
| --- | --- |
| Launch | 30 November 2018 |
| Developer | Egosoft, Würselen (near Aachen), Germany — independent, founded 1988 |
| Current version | **9.00 "Empire Update"**, 10 June 2026 |
| Expansions | 5 full, plus 2 smaller packs (see below) |
| Motto | TRADE, FIGHT, BUILD, THINK |
| Players | Single-player only. Online "Ventures" shipped in 1.50 and has been **disabled since 4.00** |
| Platforms | Windows and **native Linux** (9.00 added native Wayland); Steam Deck a stated target of 7.60 |
| Economy scale | about **1,300 stations and 10,000 ships** with all DLC — community-reported from an Egosoft staffer, not a published figure |
| Ships | over 60 in the base game; the manual's stale figure is 195 "with both DLCs". No current count published |
| Time acceleration | SETA, a flat **6×** applied to the whole universe |

### Release log (newest first)

Dates are the live-build dates from the store changelogs. Egosoft's pattern is one free major
update paired with one paid expansion, which is worth noting on its own: the mechanics are free and
the content is paid.

| Version | Date | Paired DLC | What it added |
| --- | --- | --- | --- |
| **9.00 "Empire Update"** | 10 Jun 2026 | — | Priority Orders; Travel Drive Stability; the largest combat rebalance in X4's history; per-hull heat and shield modifiers; targetable torpedoes; dedicated missile slots on some S/M ships; **equipment interchangeable across all Commonwealth S/M ships**; resource-distribution overhaul and a new Prospect behaviour; Kha'ak wreck processing yielding **Allographyne**; Ship Showroom module; plot management inside the Station Build menu; limited blueprints for some unique ships so losses can be rebuilt; **resource probes no longer affect mining efficiency** |
| 8.00 "Diplomacy Update" | 10 Sep 2025 | Envoy Pack | Agent-based diplomacy: an embassy room, agents for espionage and negotiation, more dynamic faction behaviour. Save-compatible |
| 7.60 | 28 May 2025 | — | No new features. GPU memory handling for low-end machines and the Steam Deck; better capital-fleet combat approach |
| 7.50 "Flight Model Update" | 20 Feb 2025 | Hyperion Pack | Rebuilt flight model and a matching ship rebalance; **boost moved to its own energy pool**; automated ship replacement; radar station module; **Behaviour Inspection Mode** for diagnosing what a fleet ship is actually doing; velocity indicator; DLSS and FSR 3 |
| 7.10 | 6 Aug 2024 | — | Maintenance |
| 7.00 | 20 Jun 2024 | Timelines | Reimagined Teladi and Argon capital ships; capturable Xenon ships; External Camera overhaul; **Existential Crisis** late-game challenge; reworked and expanded tutorials; customisable radial menu; gamestart recommendations for new players; the Wayward Scion start |
| 6.00 | 12 Apr 2023 | Kingdom End | Updated graphics engine; **Jolt Physics**; Live Stream camera; Position Defence for carrier fleets; new construction vessels |
| 5.00 "Hidden Treasures" | 14 Mar 2022 | Tides of Avarice | **Scrap recycling**; personal HQ office; new station and ship rooms; trophies; AMD FSR |
| 4.10 | 13 Sep 2021 | — | **Custom game starts** |
| 4.00 "Introducing Terraforming" | 16 Mar 2021 | Cradle of Humanity | **Terraforming**; Coordinated Attack; Transaction Log; NPC message system; hostile relation status; emergency eject |
| 3.30 | 30 Jul 2020 | — | Personnel management and crew transfer |
| 3.20 | 6 May 2020 | — | **Trade Rules** |
| 3.00 "A Lever to Move the World" | 31 Mar 2020 | Split Vendetta | Diplomatic missions; tutorial flight school; crew transfer; policing; drone and turret control |
| 2.50 | 28 May 2019 | — | **Resupply ships**; carrier fighter resupply; sector blacklists; Tobii eye tracking |
| 2.20 | 18 Mar 2019 | — | TrackIR; Direct Mouse Steering |
| 2.00 | 25 Feb 2019 | — | **Player-owned shipyards, wharfs and equipment docks** |
| 1.50 | 20 Dec 2018 | — | **Ventures** — sending ships into other players' universes. Disabled since 4.00 |
| 1.00 | 30 Nov 2018 | — | Release |

Two things stand out in that list for a project like Oolite. The first is that **player-owned
shipbuilding arrived three months after launch** and terraforming more than two years in: X4 shipped
as a trading-and-fighting game and grew the empire layer in public. The second is that 7.50 rebuilt
the flight model seven years after release, with a ship rebalance attached, and 9.00 did the same
for combat — Egosoft treats the core feel as something you are allowed to revise late.

### Expansions and packs

| DLC | Date | What it brings |
| --- | --- | --- |
| Split Vendetta | 30 Mar 2020 | The Split: a large territory to the north, their ships, weapons and quests |
| Cradle of Humanity | 15 Mar 2021 | Sol and the Terran Protectorate plus the Segaris Pioneers — a **separate, simplified economy** with different ware chains |
| Tides of Avarice | 14 Mar 2022 | Pirates, the scrap and salvage economy, the **Closed Loop** economy, and protectyon with its own storage class |
| Kingdom End | 12 Apr 2023 | The Boron, completing the main factions. Boron stations need water as a build resource |
| Timelines | 20 Jun 2024 | A scenario expansion: discrete, ranked missions in a separate frame, with rewards that unlock into the open universe |
| Hyperion Pack | 20 Feb 2025 | A ship pack, shipped with the flight-model update |
| Envoy Pack | 10 Sep 2025 | The Envoy and Cipher, a sector, a story and music. The Envoy is stealth-focused with a fully explorable interior |

Sources disagree on whether the last two count as expansions; Egosoft's own list has seven entries
while its prose says six. The Community of Planets Edition bundles the base game with everything
through Timelines.

## The universe

### Systems, sectors and hexes

Space is divided into **sectors**, grouped into **systems**, laid out on a hex grid you see on the
map. A sector is huge — tens or hundreds of kilometres between objects — and mostly empty, which is
why travel has four modes and a whole infrastructure layer. Sectors have an owning faction or none,
and ownership determines the illegal-wares list you are policed against.

Resources are not uniform: each sector has a published solar-energy figure in the encyclopedia
(which decides how good a solar plant is there), and regions of asteroids and nebulae carry
specific minerals and gases. Those regions are drawn on the map as coloured tiles — red for
asteroid fields, blue for nebulae, purple for mixed — so **where you build is an economic
decision**, not just a safety one.

### Travel infrastructure

This is the part of X4 with the most to teach a game whose only travel options are a set speed, a
torus drive and a hyperspace jump.

- **Local highways** run inside populated sectors: one-way lanes with an entrance and exit gate
  that grab any S or M ship flying into them anywhere along the route, rotate it and accelerate it.
  You leave by braking or strafing out, and strafing into the lane wall slows you for a controlled
  exit. Highway positions are fixed across game starts, so they are a permanent feature of a
  sector's geography — a built road network.
- **Superhighways** link nearby sectors in the same system, one-way, with gates narrow enough that
  flying a capital ship through takes care.
- **Trans-orbital accelerators** and **jump gates** are wide, bidirectional, and pass many ships at
  once. These are the trunk routes.
- **Anomalies** are one-way wormholes to distant systems that **do not appear on the map** and sit
  inside an anti-gravitational field, so a slow ship cannot enter one at all: you have to arrive
  boosting or in travel drive. They can drop you deep in hostile space with no way home.

### Hazards

Not all space is safe to cross. Electromagnetic storms tear up unshielded ships, radioactive
asteroid fields grind down shields and hull continuously, dense asteroid and wreckage fields are
simply things to crash into at travel speed, and some sectors carry **minefields**. The hazard is
part of the sector's identity, and it is what makes a shortcut a decision.

### Sector ownership

An **Administrative Centre** module completed on a player station claims an unowned sector, first
come first served. Claiming it reveals every ship and station in the sector and imposes the owner's
illegal-wares list on everyone else. Destroy the module and ownership passes to the next faction
that has one — and the NPC factions are permanently playing this game against each other, replacing
one another's defence platforms. Once the player has the blueprint, they are a participant in the
same turf war rather than a special case.

## Factions and reputation

### The reputation ladder

Reputation is **per faction**, on a scale from **-30 to +30**, and it is the main progression track
in the game: not a level, not a skill tree, but who will sell you things. Internally relations are
stored between -1.0 and 1.0 and the displayed value is `10 × log₁₀(actual × 1000)`, which is why
climbing feels slower the higher you get. Gains above 0 are explicitly non-linear and take
exponentially more work; below 0 they are linear, at +1 per kill of that faction's enemies.

| Level | What it means |
| --- | --- |
| **30** | Free trade subscription, best prices |
| **27+** | Faction paint mods; teleport to that faction's stations; their ship orders visible without scanning |
| **20+** | **Capital ship licence**, capital equipment licence, advanced station blueprints, trade subscription (10,000–10,000,000 Cr), 9–12% discount, a reputation ceremony, counted an ally |
| **10+** | **Military ship and equipment licences**, intermediate station blueprints, police licence (156,000 Cr), ~5% discount, a ceremony, counted a friend, **pirates stop plundering your property**, access to faction guilds |
| **-9+** | Civilian ship purchase, basic station blueprints, docking and trade |
| **-19+** | They will not shoot at you (pirate factions excepted) |
| **-20 to -24** | They attack your combat ships |
| **-25 to -30** | They attack everything you own, stations included |

The shape worth noticing is that **reputation gates access, not power**. Nothing in that table makes
your guns hit harder; it makes a shipyard willing to sell you a destroyer. The Xenon and Kha'ak are
pinned at -30 and cannot be negotiated with, so there is always somewhere to shoot.

### Licences

Advanced equipment needs a Military Equipment Licence (rank 10); large and extra-large military
hulls need a Capital Ship Licence (rank 20). In the ship-builder UI, unlicensed items are greyed out
and starred rather than hidden, so you can see what you have not earned yet — a small interface
decision that does a lot of work.

### Diplomacy (8.00)

The 8.00 update added an **agent** layer on top of the number: an embassy room at the player HQ and
agents you assign to espionage and negotiation, with faction behaviour reacting more dynamically.
This is the newest major system in the game and the least documented outside patch notes.

### Police, contraband and mass traffic

Large stations generate **mass traffic** — small NPC craft flying fixed lanes around the hull — and
some of those are police vehicles that peel off to scan nearby ships for wares illegal in the
owning faction's space. Refusing a scan turns the police hostile and can turn the whole station
hostile. Shooting mass traffic counts as a hostile act, except that the traffic occasionally spawns
criminal craft that you can kill for reputation. For a player-owned ship under a captain, the
response is a **policy you set in advance**, not a prompt: Police Interdiction can be set to
Attack, Comply (drop the goods — the default), Escape or Wait, and Pirate Harassment has the same
four with Attack as the default.

## Ships

### The four size classes

Size is the organising fact about a ship in X4: it decides where it can dock, what weapons it can
mount, whether it can be claimed or must be boarded, and how long a shipyard takes to build it.

| Class | Character | Weapons | Roles |
| --- | --- | --- | --- |
| **S** | Cheap, fast, fragile, S weapons only | Forward guns (some traders have none) | Scouts, fighters, interceptors, small traders, miners |
| **M** | The workhorse class, most numerous | Forward guns and secondary launchers; gun turrets | Corvettes, bombers, frigates, traders, miners |
| **L** | Expensive, few docking options, much better at everything | Guns, gun and missile turrets, a landing pad | Destroyers, freighters, large miners |
| **XL** | Limited combat ability, specialised | Turrets only | Carriers, fleet auxiliaries, builders |

Roles then cut across sizes: Combat, Trading, Mining, Salvage, Construction, and Other (the
spacesuit, drones, police vehicles). The combat ladder runs scout → interceptor → fighter → heavy
fighter → corvette → frigate → destroyer → carrier → battleship, with shields, firepower and cargo
rising and speed and affordability falling. Every ship in the game is flyable by the player except
drones and the Xenon and Kha'ak hulls — and 7.00 made some Xenon ships capturable, which chips at
even that.

### Ships are manufactured, not sold from a list

This is the single biggest structural difference from Oolite, and it is the thing most worth
stealing. Ships are **built to order** out of wares the station actually has:

- **Wharfs** build and service S and M ships; **shipyards** build L and XL; **equipment docks**
  service any size but build nothing. Resupply ships service any size in the field.
- Each has finite **construction slots**: 8 S/M slots on a wharf, 8 on an equipment dock, 2 L slots
  on most shipyards, 1 XL slot on a shipyard (2 on an equipment dock). The Alliance of Worlds
  shipyard has no L slots at all.
- If the slots are full your order joins a **waiting list**, and you can see the queue — including
  the two NPC destroyers blocking it — by expanding the station's "ships in construction" entry on
  the map.
- If the station lacks wares, the menu **lists the shortages** and warns that the order may take a
  long time. Your order is competing with the faction's own war production for the same ore.
- You can watch the claytronic construction animation happen on the pad or in the cradle, which is
  the same visual process as station module construction.
- Once a ship has started building you cannot cancel; before that you can, and get your money back.

The consequence is that a fleet loss is a supply problem, not a credits problem, and a blockade of
an ore route is a military act. 9.00 softened the edge slightly by giving **limited blueprints for
some unique ships**, so a lost one-off can be rebuilt.

### The loadout as a set of trade-offs

The buy/upgrade/repair menu is one screen for all three jobs, with the ship model in the middle,
equipment tabs down the left, a shopping list top-right and live stats at the bottom. Designs can be
**saved as named loadouts** and ordered in multiples. Compulsory items are marked by a red tab.

What makes it interesting is that the main choices are **sidegrades, not ladders**:

| Choice | Options |
| --- | --- |
| Engines (speed, acceleration, travel-drive behaviour) | **All-round** (no weakness), **Combat** (gives up travel speed for standard and boost speed), **Travel** (gives up boost for travel speed and needs a 3-second charge) |
| Thrusters (yaw, pitch, roll, strafe) | **All-round**, or **Combat** which trades yaw for pitch and roll |
| Shields | Capacity against regeneration rate; on big ships, separate shields for engine, weapon and turret groups |
| Guns | Beam (accurate, low DPS), Bolt Repeater (high burst, bad heat), Ion Blaster (strips shields without hull damage), Plasma Cannon (long range, slow projectile), Pulse Laser (balanced), Shard Battery (short-range scatter burst) |
| Launchers | Dumbfire, Torpedo, Tracking — each firing a different family of consumable missiles |
| Software | Docking Computer Mk1/Mk2, Flight Assist, Long-range Scanner Mk1/Mk2, Object Scanner (Basic or Police), Targeting Computer Extension, Trading Computer Extension |
| Crew | Captain or pilot, crewmen, marines — each with skills that change what the ship can do |

A Combat engine on a trader is a real decision, not a worse purchase. Oolite's equipment list is
mostly a ladder where the expensive item is the better item; this is the cheapest available fix for
that, and it needs no new items at all.

9.00 went further and made **equipment interchangeable across all Commonwealth S/M ships**, which
removes a layer of per-race bookkeeping without removing the choices.

### Ship mods, paint and repair

**Ship mods** are a separate customisation layer in three tiers: Basic (a modest bonus), Enhanced (a
bigger bonus with a penalty to a related stat) and Exceptional (a much bigger bonus with several
penalties). The actual numbers are rolled randomly inside defined ranges, so an Exceptional mod is a
gamble, not a purchase. Mods drop from kills or are **crafted at a workbench** from designs unlocked
by research at the player HQ, applied while docked, and can be salvaged back into their ingredients.
Paint mods are purely cosmetic and were the original hook for the online account.

Repair has four routes, and they are deliberately uneven: slowly and free with the spacesuit repair
laser; fast and for credits at a wharf, shipyard or equipment dock; fast and for wares at a resupply
ship; or automatically on M and larger, where the **captain's skill caps the repair percentage** and
service crew numbers and skill set the rate, with repair drones speeding it up.

### Resupply ships

Carriers repair and rearm S and M ships docked at them. **Fleet auxiliaries** do the same for every
size including other auxiliaries, and while they are actively supplying they **advertise their own
trade offers** to buy what they are short of — an NPC-facing logistics unit that participates in the
market. Automatic resupply is a global setting with Off/Low/Medium/High, and missile resupply
requires you to own the relevant blueprints, so even restocking ammunition is part of the industry
layer.

## Flight

### Four ways to move

- **Standard** (cruise): agile, for dogfighting and docking.
- **Boost**: a burst of speed that **drains the shields into the engines**. You cannot fire while
  boosting, but a boosting ship's shields are very hard to knock down fast enough to stop it — so
  it is a reliable escape rather than a gamble. 7.50 moved boost onto its own energy pool.
- **Travel drive**: modest acceleration, poor agility, speeds in the thousands of m/s. Weapon fire
  **overloads the drive** and locks it out for five seconds, which is the interdiction mechanic:
  you slow a fleeing ship down so something slower can catch it. You can still shoot while in it.
  9.00 added a **Travel Drive Stability** system on top.
- **Mixed mode**: not a mode but a technique — boost while the travel drive spools, or boost first
  with a combat engine, to reach travel speed immediately. A ship with no shields cannot do it,
  which is what makes shield damage matter outside of combat.

**Flight assist** is on by default and makes ships handle like aircraft in atmosphere, constantly
correcting their path. Turning it off (Ctrl+Space) gives true Newtonian behaviour — keep your
velocity, turn around, fly backwards at speed. It is also **switched off automatically for a moment
when you drop out of travel drive**. This is the pragmatic answer to Frontier's Newtonian flight:
ship the arcade model as the default, put the real physics behind a toggle, and let the toggle be
the advanced-manoeuvre button.

### Docking

Docking is a real skill with an optional autopilot, which is a better arrangement than either
extreme. Request permission within 6 km and a trail of **green landing lights** appears; a hologram
of your own ship sits on the assigned pad facing the direction you must face. Closer in, a four-part
alignment indicator appears, and all four parts must go green:

1. nose pointing the right way, 2. parallel to the pad, 3. centred over it, 4. under a maximum
hover height.

The **Docking Computer Mk1** takes over once you have nearly satisfied all four; the **Mk2** takes
over much earlier. So the upgrade does not replace the skill, it moves the threshold. Oolite's
docking computer is all-or-nothing by comparison, and the Mk1/Mk2 split is a cheap idea.

Build storage modules have no map icon and no HUD icon, so docking at your own construction site
means flying to a cradle until it appears on the right-hand monitor — a wart, but an instructive one
about what happens when a game object skips the interface layer.

### Scan modes and SETA

The player ship has four modes on Shift+1..4:

- **Travel** (above).
- **Scan**: colour-codes station modules, ship equipment and asteroid modules when close; passive
  scanning of modules, active scanning of ships within 1 km to reveal their cargo and unmask
  pirates. **Audio signals and data leaks glow red in this mode** — the whole "there is something
  hidden on this station" layer is built on one shader.
- **Long-range scan**: charge a pulse and release it; the longer the charge the further it goes, but
  overcharging aborts it. Detected objects ping like sonar and leave `?` markers on the map. Mk1
  just pings; **Mk2 colour-codes the rings** — blue for wrecks and uncommon lockboxes, yellow for
  explosive asteroids and rare lockboxes, purple for anomalies and data vaults. Range is 200 km for
  large objects and 50 km for small, within ±45° vertically and 60° horizontally.
- **SETA** (Singularity Engine Time Accelerator): a flat **6×** on everything, universe included.
  The manual frames it as sleep rather than fast-forward: the war advances at its own rate whether
  you watch or not. Oolite's debug-only time controls and the torus drive together do part of this
  job; the framing is the useful part.

### The spacesuit

Leaving the pilot's seat and going EVA is a first-class activity, not a cutscene. The suit has a
modest booster, an EVA chair with thrusters, and tools bought from item traders and selected like
weapon groups:

- **Repair laser** — slow, free hull repair at up to 25 m. Also the tool for repairing data leaks
  and data vault panels.
- **Hand laser** — a weak beam for shooting locks and surface components.
- **Bomb launcher** — magnetic explosives and **EMP bombs**, crafted in the player inventory,
  remotely detonated (and dangerous at close range). An EMP detonation **creates several small data
  leaks**, which is how you farm blueprints once the matching research is done.
- **Spacesuit scanner** — the deepest scan in the game. Level 2 data leaks can only be read this
  way.

Oxygen is finite: breathing gets harder at 25 minutes and you die at 30. Getting back aboard means
requesting docking permission from your own ship and flying into the hatch, until teleportation
research makes it a map click.

## Combat

### Weapons and heat

Five categories: **primary guns** (forward, S/M/L and some battleships), **secondary launchers**
(forward, S/M), **gun turrets** (M/L/XL), **missile turrets** (L/XL) and **defence drones** (M/L/XL
with small docks). Primary guns and launchers are the player's; turrets and drones are the ship's.

Firing primary guns builds **heat**, shown as a bar beside each weapon icon. Short bursts are free;
sustained fire, especially from several guns at once, forces a temporary shutdown. So every gun has
two real DPS numbers — a **Burst Weapon Output** and a **Sustained Weapon Output** — and the
difference between them is a weapon's character. 9.00 added per-hull heat factors on top, so the
same gun behaves differently on different ships. (The manual notes, drily, that the purchase menu
lists the sustained figure incorrectly.)

Firegroups are generous: four primary and four secondary groups on keys 1–4 and 5–8, and a weapon
may belong to all eight at once.

### Turrets as rules of engagement

Turrets are not aimed, they are **briefed**. Per turret or turret group, offline or online with one
of: Attack Enemies, Target Target (only the selected target, only if hostile), Defend Ship (return
fire on whatever shoots the ship, missiles excluded), Missile Defence (intercept missiles only) or
Break Asteroids (support mining). There is an apply-to-all control. This is the whole idea: the
player sets policy and the ship executes it, which is also how fleets, stations and traders work.

### Surface elements

Large and XL ships are not a single hitpoint pool. Individual **surface elements** — engines,
turrets, shield generators — can be targeted and disabled, and may carry their own shields. An
element at 0 hull is disabled until repaired; the ship dies only when the hull pool goes. This is
what makes disabling a destroyer a tactic distinct from killing it, and it is the precondition for
boarding. Most ships also have **blind spots** their weapons cannot cover, which are the places
their enemies try to sit.

Station modules can be targeted individually the same way, and you can order wingmen to attack a
specific module — storage, defence or the administrative centre — selected on the map.

### Loot

Hacking or destroying ships and station storage modules makes them **drop a share of their cargo**
for anyone to collect. Collecting from a station is theft, and the station may turn hostile on
whoever scoops. NPC kills also have a chance to drop items straight into the player's personal
inventory, weighted by ship type and faction.

### Fleets

Ships form **hierarchies**, not just groups: a leader with wingmen, where a wingman can itself be
the leader of a group below it. You build one by selecting the followers on the map and right-
clicking the intended leader, then choosing an assignment. Explicit player orders temporarily
override the hierarchy and then it resumes, so you can borrow a warship for a trade run without
dismantling the fleet.

Subordinate groups have modes: **Attack** (hit the commander's target), **Intercept** (engage
hostile non-capitals entering their range), **Defend** (the automatic mode, which reads what the
commander is doing), **Docked** and **Launched**.

There are over twenty named **formations** — line abreast, echelon, vulcan, W-shape — each tagged
with a star rating, because the better formations require a more skilled pilot to fly. Formation is
a property of the leader's order menu.

9.00 added a **Priority Orders** system so an urgent command can be issued without disturbing the
existing order queue, which is the sort of thing you only discover you need after shipping fleets.

### Boarding and claiming

Capture has two completely different mechanics by size, which is a neat solution to the
"should the player be able to steal ships" question.

**S and M ships bail.** Under enough fire, their pilots sometimes abandon ship and leave it
derelict and claimable by anyone. There are two ways to take it:

- **Personally**: spacewalk over, find and scan a **signal leak** on the hull. The ship becomes
  yours and you can dock with it and fly it away. No damage done.
- **By marine**: order a marine from your crew across in a boarding pod. The marine becomes the new
  pilot — but marines **damage onboard systems on the way in**, so expect to lose weapons and
  shields. The manual's advice is to replace the random marine with a real pilot, or set them to
  explore for a few hours to train them up.

**L and XL ships must be boarded**, and boarding is a planned operation in three stages — Approach
(getting pods to the target), Infiltration (breaching the hull), Assault (defeating the crew) —
with a per-stage success estimate your ship's computer only provides **if you scanned the target
first**. You assign marine numbers per participating ship and pick the boarding ship's behaviour
from: attack escorts, target engines, target turrets, disable target, maintain distance. Stage 1
options say how weakly defended the target must be before pods launch; stage 2 options say how weak
the hull must be before breaching — weaker hull means safer marines and a higher chance of
destroying the prize outright. The target has a **boarding resistance** that falls with hull damage
and crew losses, and you want your boarding strength above it.

So capturing a destroyer is: scan it, strip its turrets and engines, grind the hull to the right
window without overshooting, and land enough marines. That is a far better-shaped mechanic than a
percentage roll, and the scan-first-for-information step is the part Oolite could copy cheaply.

### Crew

Every ship has a crew capacity, filled with three kinds of NPC — **captain/pilot** (required to
give the ship remote orders; contributes most to efficiency), **crewmen** (contribute a little) and
**marines** (claim, board, and repel boarders). Stations get a **manager** instead. Mission
passengers occupy crew space, so a ship stuffed with crew cannot take a passenger job.

Skills run **0 to 5 stars** in piloting, engineering, management, boarding and morale. Service crew
reach 2 stars from ordinary work fairly quickly and then stall; past that you need **training
seminars** or terraforming rewards. Marines level from successful boarding instead and get good
fast. A skilled captain unlocks manoeuvres, fights and trades better, and — the important part —
**unlocks default behaviours the ship could not otherwise be given**.

## Trading and the economy

### The claim worth testing

Egosoft's own description of X4 says that for the first time in an X game **all parts of the NPC
economy are manufactured from resources** — wares produced by hundreds of stations, carried by
thousands of ships, traded by NPCs, with prices developing out of that activity. Players argue about
the edges: faction credit balances are not fully simulated, and one Egosoft developer's blunter
framing is that what really keeps the economy moving is **destruction**, because that is what
creates demand. Both of those caveats are worth carrying over. A closed economy with no sink
stagnates; a war is a sink.

### Items versus wares

Two inventories, and the distinction is load-bearing:

- **Wares** are cargo, held in a ship's hold, traded through the docked trade menu or remotely by
  ordering a ship to trade. This is the economy.
- **Items** are the player's personal inventory, carried from ship to ship, traded **in person**
  with a trader standing behind a counter on a station platform. Items are mission objects, crafting
  components, crystals and loot.

Oolite has one cargo hold and nothing else; the manifest/inventory split is what makes crafting,
mission objects and personal loot possible without polluting the commodity market.

### Storage classes

A hold is not generic. **Container** storage carries every manufactured ware, **solid** carries
minerals, **liquid** carries gases, and **condensate** (Tides of Avarice) carries protectyon and
nothing else. A station can have all of them and allocates space per ware within each. A trade ship
cannot carry ore and a miner cannot carry hull parts, which forces specialised hulls without a
single rule about ship roles. Oolite already has a commodity class taxonomy and a tonne/kilogram/gram
unit system, so this is the nearest available idea in the whole reference.

### Prices develop

Station prices move with stock level, between a published minimum and maximum. Energy cells, for
example, sit in a band from **10 to 22 Cr**: a station pays near 10 when its own store is nearly
full and asks near 22 when it has none. Menus show the average price so you can judge an offer. The
same formula drives player stations if you leave automatic pricing on, and you can switch it off and
set your own buy and sell prices per ware.

### Trade offers are knowledge you have to acquire

This is the best single idea in X4 for Oolite and it costs almost nothing to implement.

A station's trade offers are not public. You only know what a station buys and sells if you have
**gained that information**, and the information **goes stale** over time once whatever gave it to
you stops:

- a ship of yours is near the station, or
- the station is within radar range of a **player-owned satellite** or station, or
- you bought that faction's **trade subscription** — roughly 10M Cr for a major faction, around 1M
  for a minor one.

The **Trading Computer Extension** postpones decay. Scanning a station's modules separately reveals
what it consumes and produces. So the map's trade view is a picture of your own intelligence
network, not an oracle, and a satellite is a sensor you place for a commercial reason. Oolite's
long-range chart shows no trade at all today, and the trade-route overlay already on the ideas list
would be much more interesting built on this rule than on omniscience.

### Behaviours, and automation as a skill gate

Player-owned ships under a captain have a **default behaviour** — what they do when they have no
orders — which is a permanent assignment rather than a command. The list, with the captain skill
each needs, is the clearest statement of X4's progression model:

| Behaviour | Skill | Notes |
| --- | --- | --- |
| Patrol, Protect Position, Protect Ship, Protect Station | 0 | Combat |
| Hold Position, Fly to Object, Fly and Wait, Follow Ship, Dock and Wait | 0 | Navigation |
| **Explore** | 3 | Navigation |
| Sector AutoMine | 0 | Mining ships |
| **AutoMine** | 1 | Station-assigned only |
| **Advanced AutoMine** | 3 | |
| **Expert AutoMine** | 4 | |
| Auto Salvage | 2 | Tug-class only |
| Auto Recycle | 2 | Salvage-class only |
| Local AutoTrade | 0 | |
| Revisit Known Stations | 1 | |
| Fill Shortages | 2 | |
| **Advanced AutoTrade** | 3 | |
| Find Build Tasks | 0 | Builder ships |
| Repeat Orders | 0 | |
| **Prospect** | — | Added in 9.00 |

AutoTrade and AutoMine are set with a **whitelist of wares** and a **leash range** for how far to
look, so "automate it" is still a configuration, not a switch. And the things that remove tedium
are gated behind crew quality, which means hiring and training is the mid-game. Alongside this,
captains have standing responses to police interdiction and pirate harassment (above), and 7.50
added a **Behaviour Inspection Mode** for working out why a ship is doing something stupid — a
debugging tool shipped as a game feature, which is itself a notable decision.

### Trade rules

**Trade rules** are named white/blacklists you define once (Empire → Global Orders) and apply at
any scope: the whole empire, several stations, a single station, a single ware, or ship
construction. They were added in 3.20 and existing saves were migrated automatically. The general
pattern — a policy object you define centrally and attach at several scopes — is the right shape for
any rule a player would otherwise have to re-enter per station.

### Crafting

Some loot goes to the personal inventory and feeds a **crafting bench** found near traders and
black marketeers. Recipes only appear once you hold at least one component, so the system teaches
itself. Crafted goods include the spacesuit's EMP bombs, the sabotage tools, and ship mods. Some
components can only be obtained by specific activities — mining, or combat — which quietly ties
careers together.

## Mining

### Three kinds of resource

| Kind | Source | Resources |
| --- | --- | --- |
| Energy | Suns | Energy cells, produced by solar power plants; sector solar output is published in the encyclopedia |
| **Liquid** | Nebulae | Helium, hydrogen, methane |
| **Solid** | Asteroids | Ice, ore, nividium, silicon |

Liquids are gathered by flying through a nebula; solids by shooting asteroids apart and collecting
the fragments. The split matters because a miner's storage class decides which career it is in.

### Finding the rocks

Resource regions are drawn on the map as coloured tiles. **Resource probes** are deployables you
drop at a prospective site to read the actual abundance there — two numbers per resource, the
current amount and the maximum possible at that spot — and probes can be deactivated and collected
again afterwards. Since 4.00, mining ships **only visit regions you have discovered**, and compare a
probed zone's yield against the average of the larger area to decide whether to work it.

9.00 overhauled this: a **resource distribution overhaul** to make prospecting worthwhile, a new
**Prospect** behaviour, and — importantly — **resource probes no longer affect mining efficiency**
and the upkeep missions nagging you to deploy them were removed. The information is now the point of
a probe, rather than a buff.

This whole layer is the answer to the complaint already written in the ideas doc: *"I don't know how
to find asteroid fields."* X4's answer is a map layer, a scanner mode and a deployable sensor.

### Doing the mining

- **Mining lasers** on S/M ships and **mining turrets** on M/L; turrets automatically fire on
  asteroids in line of sight once in range, under the Break Asteroids rule of engagement.
- S and M ships collect fragments **by flying into them**, sped up by the **container magnet** (hold
  a key to pull nearby fragments in). L miners use **collector drones** instead.
- **Crystal mining** is a separate, manual activity: some asteroids have surface spots you mine away
  individually to release crystals worth **1,000 to 250,000 Cr** each as items, which also feed
  crafting. You have to shoot the spot, not the asteroid.
- Mining ships with a skilled enough captain can be left on AutoMine; everything else is a
  per-order thing you give from the map by right-clicking a resource region.

The structure here is the same as the rest of the game: a manual version that is slightly fiddly and
rewarding, an automated version gated behind crew skill, and a reason to keep doing the manual one
(crystals).

### Scrap and salvage

Tides of Avarice added a second extraction industry that does not involve asteroids at all.
**Tugs** haul large wrecks; **salvage ships** recycle them into smaller pieces; **processing
modules** convert scrap debris into scrap metal, which then feeds ordinary production. Auto Salvage
and Auto Recycle are behaviours at skill 2, restricted by hull class. 9.00 extended the idea to
enemy wreckage with **Kha'ak wreck processing**, yielding a new transmutable resource,
**Allographyne**.

A battlefield is therefore a resource region, which closes the loop between the combat and economy
layers in a way nothing else in these references does.

## Stations and building

### Modules

Stations are assemblies of independent modules, each with its own hull and surface elements, each
scannable. The categories are: **Production** (make wares from wares), **Build** (produce, upgrade
and repair ships), **Processing** (scrap into scrap metal), **Storage** (solid, liquid, container),
**Habitation** (house the workforce), **Defence** (heavily armed, durable), **Dock** (landing pads
and piers), **Venture** (the disabled online features) and **Other** (struts and cross-connections
for geometry). Many production, storage and habitation modules only accept connections in specific
directions, so **cross-connection modules are the scaffolding** you build the real station onto.

### Getting a plot

1. Open the map's **Manage Plots** tab, choose a size — the sliders run 1 to 20 along each axis
   from the centre — and place the cube.
2. Pay the **Real Estate Transfer Tax**, between **1,000 and 7,000 Cr per km³** depending on
   location and your standing with the sector's owner.
3. Or don't pay it, in which case the owning faction attacks anything you build there. Plots in
   Xenon or unowned sectors are free.

A plot is a volume you own in someone's sovereign space, with a tax and a consequence for evading
it. A simple station — a basic dock and a small platform — costs **2–3 million Cr** to build.

### The station editor

Modules snap to connection points shown as arrows that turn green when compatible, and are built
**in the order you placed them**, so priority modules go first. Modules can be merged or overlapped
where the snap points allow, with no functional effect. Selecting an **anchor** module and moving it
drags everything attached to it — which is also the trick for finding modules you accidentally left
**disconnected**, since a disconnected storage or production module will still be built but will
never move wares. Modules that can take turrets and shields are marked with a `+`, and loadouts for
them can be saved like ship loadouts. Any change to an already-built module **recycles it** and
loses part of its resources, so the design should be finished before the builder is hired. 9.00
pulled plot management into this menu and improved the editor's camera.

### Build storage and builders

Construction needs a **builder ship** — XL vessels that do nothing else — either your own or an NPC
one hired for **50,000 Cr**. A hired NPC builder will walk off the job if it waits too long for
resources; your own won't. Build rate depends on available materials and the builder's **building
drones**, up to 30 of them.

The construction site gets a **build storage** module that holds the wares. It fills visibly, with
prism-shaped containers appearing inside it — and those containers **can be shot off**. Three ways
to fill it:

1. **Automatically**: transfer credits to the build storage and set buy-offer prices per resource;
   it then trades with NPC haulers until the job is done or the money runs out.
2. **Ware transfer**: order your own captains to deliver, or buy cheap elsewhere and ship it in.
   This also lets you **overstock** for future expansions.
3. **By hand**, flying it in yourself.

Most stations need hull parts, claytronics and energy cells; Boron stations also need water. Build
storages pay your own ships for deliveries out of their assigned funds, so if you underfund one your
own freighters will refuse to unload.

### Blueprints

You cannot build what you do not have the plans for. A new game starts with a few basic blueprints
and the rest are acquired:

- bought from **faction representatives**, gated by reputation (basic at -9+, intermediate at 10+,
  advanced at 20+),
- scanned out of **data leaks** on station hulls, with the chance depending on the leak's level and
  your scanner — level 2 leaks need the spacesuit scanner,
- or farmed by **detonating a spacesuit EMP** on a module, which creates several small data leaks,
  once you have researched the relevant perk.

Every faction sells a different module list, and the lists differ in substance, not just in name:
the Teladi sell a **Teladianium** production module where the Argon and Paranid sell refined metals,
and several Teladi modules keep the same name while consuming different inputs.

So industrial capability is a progression track with three different acquisition routes — diplomacy,
exploration and crime — which is a better shape than a tech-level number.

### The Logical Station Overview

The LSO is the station management screen, and it is the piece of UI most worth studying. The top
half is a **flow diagram**: rounded boxes are production modules, square boxes are per-ware storage,
and lines show wares moving left to right from raw resources to finished tech goods. A box that is
both an output and an input appears once, in the middle, which makes the station's internal
dependency chain legible at a glance. A spinning circle in each production box shows cycle progress
and turns red when the module is starved. The bottom half is a **graph** of storage levels, funds,
quantities traded or prices traded, over hours, days or weeks, for up to four selected wares.

Clicking a ware opens its policy: automatic or manual storage allocation, automatic or manual buy
and sell pricing, and a checkbox to **restrict trade to your own ships and stations**. Problems
raise a red exclamation mark on the ware that caused them. A **trade rule** applied to a ware shows
as an orange cross on its icon.

That is a dashboard, a dependency graph and a control panel in one screen, and the lesson for
Oolite's full-screen pages is that the diagram and the controls should be the same object.

### Workforce

Add a habitation module and the station acquires a **workforce**, which raises the efficiency of
every production module. Workers need **food**, so the manager allocates storage for food wares and
the station now has an input it did not have before — and a population whose output you can watch in
its own hexagonal box. It is a straightforward and legible way to make habitation modules worth
their mass.

### Managers, accounts and drones

A station needs a hired **manager** — management and morale are the skills that matter — who orders
subordinate ships to mine and trade for the station and allocates storage automatically. Ships are
assigned to a station with an "Assign role for" option, so a mining fleet is a property of the
station rather than a fleet you babysit.

The **station account** is a real budget with a Minimum Recommended Budget calculated from the
module list. Subordinates buying from your own warehouse still pay for the wares out of it, so an
underfunded station throttles its own supply chain. Drones come in three types with automatic
restocking from parts: **cargo** drones (exchange wares with L and XL ships at piers, and feed the
build storage), **defence** drones, and **repair** drones.

### Research and terraforming

A **Player Headquarters** unlocks a **Research** menu: pick a technology, have the required wares on
site, wait the stated time. The headline branch is **teleportation** — first between your own ships
and stations, then at increasing range, then **Mass Teleportation**, which lets you teleport the
headquarters itself within a sector (destroying anything within a few kilometres of where it lands).
Research also unlocks ship-mod designs and the blueprint-from-EMP trick.

**Terraforming** (4.00) sits at the end of that chain: after High-mass Teleportation II, Boso Ta
introduces it, and it needs a shipyard module at the HQ to build terraforming drones plus container,
solid and liquid storage. Each terraformable planet has a list of objectives, pursued by feeding
**wares and drones** into projects from a terraforming menu. Terraforming missions are their own
guild-mission category, one active at a time, with the rest staying visible until done. Rewards
include **crew skill increases** — one of the few ways to push service crew past the natural
ceiling.

This is the shape of an endgame: a sink that consumes industrial output at scale and returns
something that is not money.

### Sabotage and the hidden layer

Stations have an inside, and it is mechanically live. The **Engineering Bay**, the **Manager's
Office** and a mission-unlocked **bar** are on every station, reached by elevators and transporters
from the docking platforms. Crafted items — Security Bypass Systems, Decryption Systems, Slicers —
let you cripple a station's defences, shields, repair, production, construction or trading from its
panels, or extract discounts and release its stored wares, with a risk of police detection.

Meanwhile, **audio signals** and **data leaks** spawn on module hardpoints with a static hiss and a
red glow. Repair a leak with the suit laser for reputation with the owner, or scan it for a
temporary station-wide discount, a commission, or a blueprint. **Audio signals reveal hidden
missions** — illegal work that is never posted on the board and pays far better than what is.

So "fly close to a station and look at it" is a rewarded activity, built from one shader, one
scanner mode and a spawn rule.

## Missions and content

### Four tiers of mission

X4 sorts missions by *what they are for*, not by what you do in them, and the four tiers are a
useful taxonomy for any game with a mission board.

1. **Guidance missions** are self-issued: select anything — a ship, station, gate or lockbox, or
   just a point in empty space — and set guidance to it. No reward, no board entry, and they abort
   themselves when you arrive. This is what Oolite's advanced navigational array does for jumps,
   applied to everything.
2. **Generic missions** are the board: assassination, criminal termination, clearing military
   objects, crew delivery, ship delivery, deploying satellites and laser towers, espionage, item
   delivery, lost item recovery, mining contracts, mining and trading escort, passenger transport,
   satellite repair, rescuing trapped ships, station construction, station supply, and "the
   recovery". They appear as icons on the HUD, radar and map when you come within radar range of a
   station, and blink once when they are added.
3. **Upkeep missions** are generated from the state of your own empire — a ship with no pilot, a
   station that needs a manager, a station with no cargo drones. **They pay nothing.** They are a
   to-do list the game writes for you, which is a much better answer to empire micromanagement than
   a notification.
4. **Guild missions** are the top tier and need reputation: at +10 a faction representative may
   invite you in, and joining acts as a subscription to a stream of further offers. The most
   prominent are the **war effort** missions, where several large wars are running in the universe
   and the player can join either side. One guild mission at a time; everything else is unlimited.

Failing or aborting a mission usually costs nothing, except in faction missions and time-critical
ones. 9.00 added the ability to hand **fleets and stations** over to a mission briefing, so missions
can now ask for property rather than just activity.

### Secret missions

Some work is never posted. Illegal and secret missions are offered by individuals who contact
pilots through **disguised audio transmissions** — you find them by flying near stations in scan
mode and scanning the signal leak. The pay is significantly better and so is the risk. The whole
hidden-economy layer thus rides on the same scanning mechanic as blueprints and discounts, which is
why that one mechanic earns its keep.

### Things floating in space

- **Crystal clusters**: glints on asteroids in asteroid fields, shot off individually. Worth 1,000
  to 250,000 Cr as items and useful for crafting. Shooting the asteroid instead loses them.
- **Lockboxes**: found by long-range scanning or luck. Between **1 and 16 glowing red locks** must
  be shot off a spinning box without destroying it — a low-power weapon is advised, and nudging the
  box with your hull slows its spin. More locks, more loot.
- **Data vaults**: satellite-shaped puzzles that need damage, repair and scanning in combination.
  Every pressure valve and power relay on the outside must be **repaired with the spacesuit laser at
  25 m or less** before they open.

These three are the same design idea at three difficulties: a piece of loot whose container is a
small skill test with a dedicated tool, placed in the world rather than in a menu.

### Plots, the crisis, and Timelines

**Plot campaigns** are hand-authored chains with real consequences for the universe — they are
marked "Important" in the mission list, and the 3.00 story was called *A Lever to Move the World*.
7.00 added an **Existential Crisis**: a late-game challenge for established empires, which is X4's
answer to the problem every sandbox has, where a strong player runs out of opposition.

**Timelines** (7.00's paid expansion) is the structurally interesting one. Rather than more open
universe, it is a set of **discrete scenarios** in a separate frame — the Timelines Nexus — each
rankable, with completion progressively unlocking systems and rewards that carry into the open game.
Scenarios are also the game's training ground: short, bounded, replayable, scored. 9.00 made several
of them easier to rank in.

That is almost exactly the wave-defence mode wished for at the end of the ideas doc: a sealed
scenario with a score, built from the same engine as the main game, unlocking something in the
sandbox. It is worth noting that Egosoft shipped this **six years after launch** as a way to give a
simulation game a second content shape.

### Game starts

Game starts are an explicit feature rather than a difficulty setting: several hand-authored starts
(with recommendations marking which suit new players, added in 7.00), and since 4.10 a **custom game
start editor**. The editor has two modes, and the distinction is a good piece of design politics:

- **Budgeted** — you spend a budget on ships, credits, blueprints and reputation. Requires having
  finished the Timelines story once.
- **Creative** — everything unlocked, no budget. **Marks the save as modified**, disables online
  features, and makes it unusable for bug reports.

So the game lets you have anything you want and simply labels the save honestly. For a game with an
expansion ecosystem and a bug tracker, that trade is worth copying.

## Interface

### The map is the game

The map is not a view, it is the command interface, and almost everything in this document is done
through it. It is a 3D, pannable, rotatable, zoomable orrery (right-drag to rotate, `R` to reset to
your own position and default orientation) with three sets of tabs:

- **Top**: the other major menus — options, **terraforming**, **research**, player information,
  ship interactions, map, encyclopedia, tutorials. The terraforming and research tabs only appear
  once unlocked.
- **Left**: the object list (filtered to stations, ships, deployables, at the current zoom); the
  **player-owned** object list sorted into stations-and-subordinates, fleets and unassigned ships;
  **mission offers**; **active missions** split into regular, upkeep and guidance; the
  **information** pane; and **Manage Plots**.
- **Right**: layer **filters**, a **legend** explaining every icon and the resource-region colours,
  and the information pane again.

The **information pane** is the inspector, and the manual flatly calls it the most important menu in
the game. Select any ship, station or sector and get six tabs: General, Crew, Loadout, Logbook,
**Behaviours**, and Individual Instructions (weapons, turrets and subordinates). The behaviours tab
is where a captain's default behaviour, their police and pirate response policies, and their
abandoned-ship policy are set. Every object in the game is therefore configured through one
consistent inspector, and that is why a thousand-ship empire remains playable.

The **search bar** takes object names, types and the six-character ship ID, plus type keywords:
`accelerator`, `data vault`, `equipment dock`, `highway`, `jumpgate`, `shipyard`, `trade`, `trades`,
and `a` for everything in the universe (which, the manual notes, often tanks the frame rate). Some
filters are order-sensitive, which is a bug described as a feature.

### Elsewhere

The **HUD** puts three curved bars under the reticle — speed, hull, shields — and three monitors
along the bottom: a message ticker on the left (mission progress, guidance, credit and standing
changes), the radar in the middle, and a target monitor on the right that doubles as the video comms
window. Centre icons cover SETA ownership and activity, target lock and incoming missiles. Ship IDs
are three letters and three digits, painted on the hull and used in menus and the search bar.

7.00 added a **customisable radial menu** for quick actions, and 9.00 an **input hint bar**, an
optional WASD keyboard profile and better controller support in the crafting and plot menus. The
**pause key** exists specifically so you can use menus while paused — a small thing that makes a
complex interface survivable in a game with no time stop. Joystick and controller support ships with
profiles for named hardware and an editor for your own.

## Multiplayer, or the lack of it

X4 is single-player, and its one attempt at anything else is instructive.

**Ventures** shipped in 1.50, a month after release: you built venture modules on a station, sent a
ship off into other players' universes through Egosoft's servers, and it came back with rewards. It
required an Egosoft community account linked to Steam or GOG. It has been **disabled since 4.00**,
and the manual's page on it now opens with a notice that the information is irrelevant until online
features are re-enabled. A **Multiverse Team Seasons** beta ran from 19 April to 14 June 2023 to
test "the next evolution of Ventures", with a ship as the reward. Nothing has shipped since.

What X4 does instead is make the simulation itself the other party. The wars run without you, NPC
factions fight their own turf war over sector ownership, prices move because other people's ships
are moving goods, and your reputation with seven-plus factions is a live negotiation. The lesson for
Oolite, whose multiplayer section opens by noting that the engine is built around
`PlayerEntity::sharedPlayer()`, is that **most of what players want from a shared galaxy is a galaxy
that does things when they are not looking**, and that is single-player work.

## Modding

X4 has official, first-class mod support, and the mechanism is worth comparing with Oolite's OXP/OXZ
model directly.

- Mods are **extensions**: a folder under `extensions/` with a `content.xml` metadata file. Packing
  into an archive is optional for local use and required only for Steam Workshop distribution.
- Changes are made by **XML diff patching**: a diff file selects nodes in the base game's XML with
  **XPath** and adds, replaces or removes them, validated against Egosoft's `diff.xsd`. Two mods can
  therefore modify the same base file without conflicting, which is the central problem OXPs have
  with overlapping overrides.
- Game logic is in **Mission Director** XML scripts and **Lua** for UI, with the caveat that UI work
  is harder than data work: `ui.xml` historically could not be diff-patched cleanly, so UI mods have
  tended to replace Egosoft's files.
- Distribution is **Steam Workshop plus Nexus Mods plus the official forum**, and Egosoft's wiki
  links all three alongside its own XML patch and XPath documentation.
- Community tooling is substantial — the X4 Customizer generates diff XML automatically and can
  check an extension for patch and dependency errors, which is effectively a linter for mods.
- Mods flag the save as modified, exactly as the creative game start does.

The transferable idea is **XPath diff patching as the extension format**. It gives you additive mods
that compose, a schema to validate against, and the ability to lint an extension before shipping
it — all three of which are things an expansion ecosystem eventually needs.

## Scale numbers

Collected for pacing comparisons. Figures from the official manual are marked, because the manual is
four major versions behind; patch-note figures are current.

| Quantity | Value |
| --- | --- |
| Launch to current version | 30 Nov 2018 → 9.00, 10 Jun 2026 |
| Stations in the universe | about **1,300** with all DLC — community-reported |
| Ships in the universe | about **10,000** with all DLC — community-reported |
| Flyable ship types | over 60 base game; 195 with the first two expansions (manual, stale) |
| SETA | **6×**, applied universe-wide |
| Travel drive spool-up | **3 s** for travel engines, 0 for combat engines |
| Travel drive lockout under fire | **5 s** |
| Docking request range | within **6 km**; landing lights from 5 km |
| Long-range scan range | **200 km** large objects, **50 km** small, ±45° vertical |
| Spacesuit repair laser | **25 m** range, fixed repair per tick |
| Spacesuit oxygen | warning at **25 min**, death at **30 min** |
| Reputation scale | **-30 to +30**, displayed as `10 × log₁₀(actual × 1000)` |
| Military licence / capital ship licence | reputation **10** / **20** |
| Police licence | **156,000 Cr** |
| Trade subscription | about **10M Cr** major factions, **1M Cr** minor |
| Reputation discounts | ~5% at rep 10, 9–12% at rep 20 |
| Plot size | 1 to **20** along each axis from the centre |
| Plot tax | **1,000–7,000 Cr per km³**; free in unowned and Xenon space |
| Simple station | **2–3M Cr** |
| NPC builder hire | **50,000 Cr** |
| Building drones used | up to **30** |
| Construction slots | 8 S/M on a wharf, 8 on an equipment dock; 2 L on most shipyards; 1 XL on a shipyard, 2 on an equipment dock |
| Energy cell price band | **10 to 22 Cr** |
| Crew skill range | **0 to 5 stars** in five skills; service crew stall at 2 without seminars |
| Behaviour skill gates | AutoMine 1, Explore 3, Advanced AutoTrade 3, Expert AutoMine 4 |
| Boarding strength to aim for | **20 or more** over the target's resistance |
| Defence drone | about **15,000 Cr**, 1,900 MJ hull, no shields, Pulse Laser Mk1 |
| Crystals | **1,000 to 250,000 Cr** each |
| Lockbox locks | **1 to 16** |
| 9.00 changelog size | **436 changes** |

### What could not be verified

- **The sector count.** Egosoft's own wiki contradicts itself across revisions — 50 systems, 47
  sectors, 59 playable areas and "63 sectors linked by superhighways" all appear — and the
  expansion pages add 30, 19, 7 and 11 sectors without a stated total. Adding them gives roughly
  120–130 with all DLC, but no source states it and Timelines adds systems progressively.
- **A current ship count.** The manual's 195 predates four expansions.
- **The 7.00 release date.** Egosoft's wiki says 30 June 2024; the store changelogs and the launch
  announcements say 20 June. The store date is used here.
- **8.00's diplomacy mechanics in detail.** Agents, an embassy room, espionage and negotiation are
  confirmed by press coverage of the patch; nothing found describes the actual numbers, the agent
  skill model or how faction relations are computed. This is the newest major system and the worst
  documented.
- **Ware and production-chain counts.** No reliable current list of how many wares exist, or of the
  Terran and Closed Loop chains' exact inputs. The claim that the Terran economy costs roughly
  double the raw resources is a player's, not Egosoft's.
- **Per-project terraforming costs.** The Segaris plot's 125 antimatter cells and several nav
  beacons are documented; the main projects' ware lists were not found.
- **VR support.** Nothing in the sources consulted confirms or denies it for the current version, so
  it is not claimed either way here.
- **Whether Ventures will return.** The Multiverse beta ended in June 2023 and nothing has been
  announced since.

## Ideas for Oolite

X4 is the most transferable of the five references, because it reaches EVE's systems — industry,
property, fleets, a live market — with **one player and no server**. Everything below works in a
single-player game by construction. Several of these also answer rows already written in
[Oolite Feature Ideas](<../../notes/Oolite Feature Ideas.md>), and the industry ones connect directly to
[Mining and Manufacturing — Design Sketch](<../../notes/Mining and Manufacturing — Design Sketch.md>).

### Five that fit best

1. **Trade offers as knowledge, not as a given.** You only know a station's prices if something of
   yours has been near it, a satellite of yours can see it, or you bought a subscription — and the
   knowledge **goes stale**. This is the cheapest high-impact idea in the whole reference: it turns
   the long-range chart into a picture of your own intelligence network, gives satellites and the
   trade computer a commercial purpose, makes exploration pay in money rather than in trivia, and
   makes the trade-route overlay already on the ideas list far more interesting than omniscience
   would. Oolite already quotes one price per good per station; the change is to gate *when you can
   see it* and let it decay.
2. **Ships built from wares, not sold off a list.** A shipyard that consumes hull parts, energy and
   refined metals, with finite construction slots, a visible queue and visible shortages, makes
   every destroyed ship a supply problem and every blockade a military act. It also gives the mining
   and manufacturing career an end customer inside the core game rather than a commodity price.
   Oolite's shipyards already pick from a per-station list with tech-level gating and
   `installation_time` charging hours to the clock, so the scaffolding is there.
3. **The map as the command interface, with one inspector.** A 3D, rotatable, zoomable system map
   where you select anything and configure it through the *same* six-tab pane — general, crew,
   loadout, logbook, behaviour, instructions — is what makes a complex game playable. This answers
   the Modern UI and System map rows together, and the discipline to copy is that **the diagram and
   the controls are the same object** (see the Logical Station Overview), not a view plus a separate
   settings page.
4. **Default behaviours with a skill gate.** A ship under an NPC captain has a *standing* behaviour
   for when it has no orders, plus standing policies for police scans and pirate demands. Better
   behaviours — explore, auto-trade, auto-mine — require a more skilled captain, so hiring and
   training *is* the mid-game. Oolite already has AI state machines and a priority AI; exposing a
   player-facing default behaviour for owned escorts would give fleet play without turning the game
   into an RTS.
5. **Equipment as trade-offs, not a ladder.** Travel versus combat engines, travel versus combat
   thrusters, capacity versus regeneration shields, six guns with genuinely different characters.
   Oolite's equipment is largely a price ladder where dearer is better; making the main choices
   sidegrades would give hulls distinct characters **without adding a single item**.

### Flight and travel

| Idea | What X4 does | Oolite today |
| --- | --- | --- |
| Newtonian flight behind a toggle | Flight assist on by default makes ships handle like aircraft; one key turns it off for true momentum, and it drops automatically when leaving travel drive | Elite-style flight at a set speed. This is the pragmatic version of the Frontier row: ship the arcade model, put the physics on a key |
| Boost that costs you something | Boost drains shields into the engines and you cannot fire while boosting; a boosting ship is hard to stop | Injectors and the torus drive; no shield cost |
| Travel drive interdiction | Weapon fire overloads the travel drive and locks it out for 5 s, so you slow a runner down for someone slower to catch | The torus drive is mass-locked near ships, but nothing knocks it out |
| Docking computer in two grades | Mk1 takes over once you have nearly aligned; Mk2 takes over much earlier. The upgrade moves the skill threshold rather than removing it | The docking computer docks you; there is no partial assist |
| A built road network | One-way highway lanes inside a sector, fixed across game starts, that grab any ship that flies into them | Space lanes are traffic patterns, not infrastructure |
| Hidden one-way routes | Anomalies are unmapped wormholes inside an anti-gravity field, so only a fast ship can enter, and they can strand you | Witchspace and the nova mission are the nearest thing |
| Hazard as sector identity | EM storms, radioactive asteroid fields, minefields — a shortcut you take knowingly | Suns burn you; otherwise space is safe |

### Combat and capture

| Idea | What X4 does | Oolite today |
| --- | --- | --- |
| Weapon heat with two DPS figures | Every gun has a Burst and a Sustained output, and sustained fire shuts it down. Per-hull heat factors since 9.00 | Laser temperature exists and overheating stops fire — this is the extension: publish both numbers and make them the weapon's character |
| Turrets as rules of engagement | Per turret: offline, attack enemies, target target, defend ship, missile defence, break asteroids | NPC turrets exist; the player sets no policy |
| Surface elements | Engines, turrets and shield generators on big ships are separately targetable, separately shielded, and disabled at 0 hull while the ship lives | A ship is one hull number |
| Ships bail and can be claimed | S and M pilots sometimes abandon ship; you claim the derelict by spacewalking over and scanning a signal leak (no damage) or by sending a marine (damage, and the marine becomes your pilot) | Escape pods pay an insurance reward; there is no capture |
| Boarding as a planned operation | Scan for intel, choose a per-stage behaviour, grind the target into a window, land marines across three stages | None |
| Fleet hierarchies with modes | A leader with wingmen, nested, where subordinates run attack / intercept / defend / docked / launched, and explicit orders temporarily override assignment | Escorts follow a mother ship; no player-facing hierarchy |
| Formations gated by skill | Over twenty named formations, each with a star rating that is the pilot skill it needs to fly | The Archimedes row already wants Viper formations; this is the general form |
| Priority orders | An urgent order that executes without disturbing the existing order queue | — |

### Trade and the economy

| Idea | What X4 does | Oolite today |
| --- | --- | --- |
| Prices move with stock | Each ware has a published min and max (energy cells 10–22 Cr) and a station's price slides between them with its own stock level | Prices vary by system economy and are stable per visit |
| Information decays | Known trade offers go stale once nothing of yours can see the station; the Trading Computer Extension slows the decay | Prices are known when docked and not before |
| Satellites as commercial sensors | A satellite in radar range of a station keeps its offers current | Nav buoys exist; satellites would be new |
| Buy the data | A faction trade subscription (~10M Cr major, ~1M minor) hands you their whole market | — |
| Cargo versus personal inventory | Wares in the hold are the economy; items in the player's pockets are mission objects, crystals, crafting parts and loot, traded in person with a shopkeeper | One cargo hold; no personal inventory |
| Storage classes | Container, solid, liquid and condensate holds force specialised hulls without a rule about ship roles | Cargo is cargo; the commodity class taxonomy and the tonne/kg/g units are the hooks |
| Trade rules as attachable policy | Named white/blacklists defined once and applied to the empire, a station, a ware or ship construction | — |
| Automation configured, not switched | AutoTrade takes a ware whitelist and a leash range | — |
| Destruction as the demand sink | Egosoft's own framing: the wars are what keep the economy moving | The populator stages NPC fights; nothing consumes goods at scale |

### Mining and industry

| Idea | What X4 does | Oolite today |
| --- | --- | --- |
| Resource regions on the map | Asteroid fields, nebulae and mixed regions drawn as coloured tiles, with published solar output per sector | Asteroids are placed by the populator; nothing tells you where |
| Prospecting with a deployable | Resource probes read current and maximum abundance at a spot; since 9.00 they inform rather than buff, and miners compare a probed zone against the local average | — |
| Collection as a skill with a crutch | S/M miners fly into fragments, helped by a hold-to-use container magnet; L miners use collector drones | Fuel scooping is the nearest mechanic |
| Crystals as a manual reward | Surface spots on asteroids yield items worth 1,000–250,000 Cr if you shoot the spot and not the rock | — |
| Salvage as a second extraction industry | Tugs haul wrecks, salvage ships recycle them, processing modules turn scrap into metal that feeds normal production. 9.00 extended it to enemy wreckage | Scooping cargo pods; no wreck economy |
| A battlefield is a resource region | The combat and economy layers feed each other directly | — |
| Blueprints with three acquisition routes | Bought from representatives by reputation, scanned out of station data leaks, or farmed by detonating an EMP on a hull | Equipment is gated by tech level and price |

### Stations and property

| Idea | What X4 does | Oolite today |
| --- | --- | --- |
| A plot is a taxed volume | 1–20 units per axis, 1,000–7,000 Cr per km³, free in unowned space — and if you refuse the tax the sector's owner attacks what you build | None |
| The flow diagram *is* the control panel | The Logical Station Overview draws the station's dependency chain and you click a ware in the diagram to set its policy, with graphs of stock, funds, volume and price over hours to weeks | Full-screen pages on function keys |
| Build storage you can shoot | The construction site's ware store is a physical module that fills visibly and can be destroyed | None |
| Workforce as an input | Habitation raises production efficiency and creates a food demand | None |
| Station budget as a real constraint | Subordinates buying from your own warehouse still pay out of the station account, so underfunding throttles your own supply chain | None |
| Sector ownership by module | An Administrative Centre claims an unowned sector and imposes your contraband list; destroy it and the next faction takes over. NPC factions play the same game against each other | None |
| Research as an unlock tree | A player HQ researches teleportation, ship-mod designs and perks, consuming wares and wall-clock time | None |
| An endgame sink | Terraforming consumes industrial output at scale and pays in things that are not money, crew skill included | None |
| Property upkeep as a to-do list | Upkeep missions are generated from your own empire's defects and pay nothing | None |

### Missions, content and interface

| Idea | What X4 does | Oolite today |
| --- | --- | --- |
| Self-issued guidance missions | Select anything, including a point in empty space, and get guidance to it; it aborts on arrival and pays nothing | The advanced navigational array plots jumps; this is the in-system form |
| Secret missions behind a scan | Illegal work is never posted; you find it by scanning audio signals on station hulls, and it pays much better | Missions arrive by station message |
| Loot in a container with a skill test | Lockboxes (shoot 1–16 locks without destroying the box), crystal clusters, data vaults (repair every panel with the suit laser at 25 m) | Cargo pods are scooped |
| Scenarios as a second content shape | Timelines: sealed, ranked, replayable scenarios in their own frame, unlocking rewards into the sandbox | This is the wave-defence idea in the ideas doc, with a structure that makes it repeatable |
| A late-game crisis | The Existential Crisis gives an established empire something it cannot ignore | Thargoid attacks are ambient |
| Custom game starts, labelled honestly | A budgeted editor, and a creative mode that unlocks everything and marks the save modified | Game starts are fixed |
| One inspector for every object | Six tabs — general, crew, loadout, logbook, behaviours, instructions — for ships, stations and sectors alike | Separate pages per concern |
| A legend that explains the map | A tab listing every icon and what the region colours mean | — |
| Typed search | `jumpgate`, `shipyard`, `trade`, `data vault`, or a ship's six-character ID | — |
| Pause for menus | A dedicated key so you can use the interface while the game is stopped | Oolite pauses with `P` |

### Rules worth stealing outright

Less features than habits, and cheaper than any of the above:

- **Free mechanics, paid content.** Every major system in X4 shipped in a free update; the paid DLC
  is ships, sectors and stories. For a project whose content comes from an expansion community, that
  split is the right one.
- **The player sets policy; the ship executes it.** Turret rules of engagement, captain behaviours,
  police-scan responses, trade rules, storage allocation — all the same shape. It is what lets one
  player run a thousand ships, and it generalises to one player running six escorts.
- **Gate automation behind crew quality, and keep a reason to do it by hand.** AutoMine needs a
  one-star captain and Expert AutoMine a four-star one; crystals are only worth taking manually.
- **Information is a resource that decays.** Prices, ship cargo, station contents, boarding odds —
  all of them something you acquire by scanning, visiting, placing a sensor or paying, and all of
  them perishable.
- **Build one scanning mechanic and make it pay in four currencies.** Scan mode yields missions,
  discounts, blueprints, intel for boarding and the ability to claim a derelict. One shader, one
  spawn rule, five systems.
- **Label the save, don't forbid the wish.** Creative game starts and mods both set a "modified"
  flag that disables online features and bug reports, and are otherwise permitted.
- **Let the game write the player's to-do list.** Upkeep missions pay nothing and exist purely to
  surface the state of your own property.
- **Ship your debugging tool as a player feature.** 7.50's Behaviour Inspection Mode exists because
  players could not tell why a fleet ship was idling. Oolite's debug console already exposes game
  state to the component tests; a player-facing version of the same thing is a short step.
- **Revise the core feel late if it is wrong.** The flight model was rebuilt in year seven and
  combat in year eight, each with a rebalance attached. Neither broke the game's identity.
- **XPath diff patching as the extension format.** Additive mods that compose, a schema to validate
  against, and a linter that can check an extension before release.

### What not to take

- **The full station editor.** Snap points, anchor modules, disconnected-module hunting and
  recycling a module if you edit it after it is built — this is a lot of interface for a game with
  no module system, and the LSO is the part worth copying, not the builder.
- **Universe-scale simulation.** 1,300 stations and 10,000 ships is a different engineering project
  from Oolite's per-system populator, and chasing it would be the wrong fight. The *appearance* of a
  galaxy that moves can come from much less.
- **Ventures.** The one online feature has been switched off for five years and its replacement beta
  died in 2023. The clear lesson is that the asynchronous-multiplayer idea in the ideas doc should
  be cheap or not attempted.
- **The breadth of the generic mission board.** Twenty-odd procedural mission types produce
  repetition; Oolite's authored missions are better than any of them, and the tiering (guidance /
  generic / upkeep / guild) is the transferable part, not the catalogue.
- **Objects without an interface layer.** The build storage has no map icon and no HUD icon, so
  docking at your own construction site is a guessing game. A good counterexample.
- **Terraforming literally.** The planet-changing fiction is far from Oolite's scope; the
  transferable part is only the idea of a late sink that eats industrial output.

## Sources

Grouped by reliability, because it differs sharply and it matters which was used for what.

### Egosoft: the official manual and wiki

Authoritative on mechanics. The manual is **four major versions behind** — most chapters say
"Updated for version 5.10", the map chapter says 6.10 — so its figures were treated as indicative
and its descriptions as sound.

- **[X4: Foundations Manual (PDF)](https://wiki.egosoft.com/download/X4%20Foundations%20Wiki/Manual%20and%20Guides/X4%3A%20Foundations%20Manual/WebHome/X4_%20Foundations%20Manual.pdf)**
  — version 77.1, 8 January 2025, 141 pages. The source for capturing and boarding, combat and
  weapons, fleet management and formations, missions and loot, NPC behaviours, piloting and travel,
  purchasing and upgrading ships, resupply ships, the HUD and ship modes, station building and
  management, station basics, research, the spacesuit, the map, and trading and mining
- [X4 Foundations Wiki](https://wiki.egosoft.com/X4%20Foundations%20Wiki/) — the manual's home, plus
  the [Downloadable Content](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Downloadable%20Content/)
  list
- [Reputation Effects](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/Objects%20in%20the%20Game%20Universe/Factions/\(Player\)/Reputation%20Effects/)
  — the -30 to +30 table, the licence thresholds and the display formula
- [Feature Development Overview](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Game%20Updates%20and%20Patch%20History/X4%20Foundations%20Feature%20Development%20Overview)
  — the version-by-version history from 1.0 to 7.00, with dates and headline features
- [Systems, Sectors and Zones](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/Objects%20in%20the%20Game%20Universe/Systems%2C%20Sectors%20and%20Zones/)
  — and the source of the sector-count contradictions
- [Station Building And Management](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/X4:%20Foundations%20Manual/Station%20Building%20And%20Management/)
- [Modding Support](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Modding%20Support/) — the
  official hub, with the XML patch and XPath documentation and the community tool list
- [Segaris Terraforming Plot](https://wiki.egosoft.com/X4%20Foundations%20Wiki/Manual%20and%20Guides/Objects%20in%20the%20Game%20Universe/Plots/Segaris%20Terraforming%20Plot/)

### Patch notes

Current where the manual is not. The 9.00 feature list, the version history from 7.00 to 9.00 and
the 436-change count come from here.

- [GOG Database release notes for X4: Foundations](https://www.gogdb.org/product/1588366064/releasenotes)
  — the full 9.00 notes and dated version list
- [SteamDB patch notes: 9.00 "Empire Update"](https://steamdb.info/patchnotes/23660954/),
  [7.00 and Timelines](https://steamdb.info/patchnotes/14784192/),
  [7.50 "Flight Model Update" beta](https://steamdb.info/patchnotes/16614520/)
- [Steam: 9.00 public beta announcement](https://steamcommunity.com/games/392160/announcements/detail/528744981882470469)
- [Egosoft press release for 9.00](https://www.gamespress.com/en-US/Forge-Your-Galactic-Legacy-in-the-X4-Foundations-900-Empire-Update-Ava)
- [Steam store page](https://store.steampowered.com/app/392160/X4_Foundations/) — the economy
  claim and the DLC list

### Press

Used for the 8.00 and 7.50 feature summaries where Egosoft's own wiki has not caught up.

- [Saving Content: Diplomacy Update (8.00) and the Envoy Pack](https://www.savingcontent.com/2025/09/11/diplomacy-update-8-00-warps-in-alongside-paid-envoy-pack-dlc-for-x4-foundations/)
  and [the Envoy Pack announcement](https://www.savingcontent.com/2025/08/13/x4-foundations-gets-stealthy-with-envoy-pack-releasing-when-the-diplomacy-update-8-00-arrives-later-this-year/)
- [Saving Content: Update 7.60](https://www.savingcontent.com/2025/05/28/update-7-60-for-x4-foundations-is-now-live-and-improves-gpu-memory-handling-better-capital-ship-combat-and-more/)
  and [7.50 with the Hyperion Pack](https://www.savingcontent.com/2025/02/20/x4-foundations-receives-major-overhaul-of-its-flight-model-with-update-7-50-alongside-hyperion-pack-dlc-for-a-new-era-today/)
- [Game Rant on 7.50](https://gamerant.com/x4-foundations-update-750-patch-notes-changelog-hyperion-dlc-whats-new/)
- [GameReactor on the Envoy Pack](https://www.gamereactor.eu/x4-foundations-introduces-its-next-dlc-x4-envoy-pack-along-with-update-800-1587493/)
- [Bleeding Cool on the Empire Update](https://bleedingcool.com/games/x4-foundations-launches-new-massive-empire-update-today/)
- [Wikipedia: Egosoft](https://en.wikipedia.org/wiki/Egosoft) and
  [the X series](https://en.wikipedia.org/wiki/X_(video_game_series)) — studio and series history

### Community wikis, guides and forums

Used for how things feel and for leads, not for numbers. Several are years out of date and are
flagged as such where used; the economy scale figures and the Terran-economy claim come from forum
posts and are marked community-reported in the text.

- [X4 Wiki (xuniverse.wiki)](https://x4.xuniverse.wiki/w/Update:7.50) — the newer fan wiki
- [X4 Foundations Wiki (Fandom)](https://x4-foundations-wiki.fandom.com/wiki/Expansions) —
  expansions, terraforming, game starts, update pages
- [X4 Player's Handbook](https://x4playershandbook.com/index.php/index-stations/station-building/)
  — station building
- [Ludo guide: station building and faction relations](https://www.ludo.guide/guide/x4-foundations/side-quests-activities/station-building-management/station-modules-list)
- [Steam discussion: economy simulation](https://steamcommunity.com/app/392160/discussions/0/733658398226259846/)
  — the ~1,300 stations / ~10,000 ships figures
- [X4 Customizer](https://github.com/bvbohnen/X4_Customizer/) — the community modding toolchain, and
  evidence for what mod authors actually need
- [XML diff and patch tool](https://www.nexusmods.com/x4foundations/mods/1578) on Nexus Mods
- [Veanturverse interactive universe map](https://veanturverse.com/guides/x4-universe-map.html)

### Oolite

- [Oolite Feature Ideas](<../../notes/Oolite Feature Ideas.md>) — the rows this reference answers
- [Mining and Manufacturing — Design Sketch](<../../notes/Mining and Manufacturing — Design Sketch.md>) — where
  the industry ideas are worked out
- [EVE Online — Feature Reference](<EVE Online — Feature Reference.md>),
  [Elite Dangerous](<Elite Dangerous — Feature Reference.md>),
  [Frontier: Elite II and First Encounters](<Frontier Elite II and First Encounters — Feature Reference.md>),
  [Elite (1984)](<Elite (1984) — Feature Reference.md>) — the other four references
