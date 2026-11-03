# EVE Online — Feature Reference

Nov 2, 2026 · @Jon Seaman

EVE Online is the other tradition in space games. Where Elite put one pilot in a procedural galaxy,
EVE put everyone in the same one and let them run the economy. It is the deepest worked example of
most of the systems Oolite has in shallow form — a commodity market, mining, equipment, reputation,
contracts, factions — and the only one of these references whose subject is still being rebalanced
by a studio with an in-house economist.

This is the longest of the four references because EVE is much the largest game. Mining and industry
get the deepest treatment, because they prompted it, and the career they suggest for Oolite is
worked out separately in
[Mining and Manufacturing — Design Sketch](<Mining and Manufacturing — Design Sketch.md>).

**On the studio's name.** CCP Games completed a management buyout from Pearl Abyss and **renamed
itself Fenris Creations on 6 May 2026**, returning to independence after Pearl Abyss had bought it in
2018. Google took a minority stake alongside a Google DeepMind research partnership that uses EVE as
a testbed for long-horizon planning and continual learning, and the studio said there would be no
layoffs or restructuring. The teams on EVE Online, EVE Frontier, EVE Vanguard and EVE Galaxy
Conquest stayed in place. This reference says **CCP** for things CCP did under that name, which is
most of the game's history, and Fenris Creations for 2026 onward.

**On sources.** EVE's community wikis are substantially out of date. The Catalyst expansion of
18 November 2025 quartered mining cycle times, renamed every ore grade and added critical hits, and
most EVE University mining pages still carry pre-Catalyst figures behind an "outdated" banner; its
"Perfect mining" page was last edited in April 2024 and gives numbers that cannot be reconciled with
current module data. Concrete numbers here come from **EVE Ref**, which is generated from the game's
own static data export, or from CCP's patch notes and devblogs. EVE University is used for how
mechanics work rather than what the numbers are. Anything that could not be verified is marked
unclear rather than asserted, and the open questions are collected at the end of Scale numbers.

## Overview and timeline

EVE Online launched on **6 May 2003** as *EVE Online: The Second Genesis* and has been continuously
operated and patched for twenty-three years. The studio was founded in Reykjavík in June 1997,
took the name CCP in 1999, was bought by Pearl Abyss in 2018, bought itself back from Pearl Abyss
for about **US$120 million** on 1 May 2026, and renamed itself **Fenris Creations** five days later.

| Item | Value |
| --- | --- |
| Launch | 6 May 2003, originally published by Simon & Schuster |
| Developer | Fenris Creations, Reykjavík — CCP Games until 6 May 2026 |
| Ownership | Independent → Pearl Abyss 2018 (US$425M headline, about US$225M effective) → management buyback 2026 |
| Headcount | 173 in 2022, down from about 250 at the acquisition; no newer figure published |
| Peak concurrency record | **65,303 pilots**, 5 May 2013 — **still unbeaten** |
| Typical daily peak, Nov 2026 | about 34,000 |
| Subscriber count | **Unclear.** No figures published for years, and Alpha/Omega makes "subscriber" ill-defined |

### One universe, one server

EVE is the canonical **single-shard** MMO. There are no realms and no instancing of the persistent
world: one cluster, **Tranquility**, simulates the entire universe for everyone outside China, which
has a separate shard called Serenity. A public test server, Singularity, and a tournament server,
Thunderdome, sit alongside.

The hardware is published, which is itself unusual. As of the most recent specification Tranquility
runs **195 active simulation nodes** on eighteen machines, with **Jita given a node of its own** and
another for its market, and a database pair carrying four terabytes of memory each. Daily downtime
is about **125 seconds**.

The game runs on **Stackless Python**, whose lightweight tasklets are what let one node hold
thousands of pilots, and a migration of roughly **2.4 million lines of Python across 20,000 files**
from Python 2.7 to Python 3 began in August 2026 — live, in stages. **Time dilation**, which slows
simulation to as little as a tenth of real time rather than dropping players, arrived with Crucible
in 2011 and is the reason EVE's largest battles are possible at all.

### Free to play, with a cap

**Alpha** and **Omega** clone states arrived with Ascension in November 2016. The state is per
account, and Alpha is permanently free.

| | **Alpha**, free | **Omega**, paid |
| --- | --- | --- |
| Training rate | **Half speed** | Full |
| Skill-point ceiling through the queue | **5 million** | Uncapped |
| Ships | Combat hulls to **battleship**, and mining in a **Venture or Pioneer** only | Everything |
| Industry | Tech 1 manufacturing, **no invention**, **no planetary industry**, +2% tax | Full |
| Market | Higher taxes, sell only within five jumps, **one active contract** | Region-wide |
| Missions | **No level 4 or 5 agents** | All |
| Multiple clients | **Cannot log in two characters at once** | Allowed if all are Omega |

**PLEX** bridges money and the game: 500 PLEX buys thirty days of Omega, and PLEX is a tradable item
on the only global market in EVE, so cash converts to ISK and ISK converts to subscription time
through a channel the studio sanctions and runs.

### Release log

The cadence has changed repeatedly: twice-yearly named expansions from 2003 to 2013, about six free
releases a year in 2014–15, named expansions again, a "quadrant" model in 2020–21, and named
expansions once more from 2022.

| Date | Release | Headline |
| --- | --- | --- |
| **2026-11-10** | **Fractured Skies** | Chapter 2 of *Theatres of War*: two-month Military Campaigns per empire pair, four navy attack battlecruisers from loyalty-point stores, Synchronizer rigs, a redesigned heads-up display in preview |
| 2026-09-22 | Cradle of War major update | **Force projection revamped** — Ansiblex jump bridges put on a draining capacitor, owning-alliance only, and jump fatigue explicitly abandoned as the throttle |
| **2026-06-09** | **Cradle of War** | Chapter 1: **Exordium**, a 53-system starter region at security 1.0 with PvP blocked and a one-way exit; Military Campaign groundwork; Bulwark mining anomalies |
| 2026-05-06 | *A New Era* | CCP Games becomes **Fenris Creations**; buyback from Pearl Abyss; Google DeepMind research partnership |
| 2026-02 | EVE Evolved | A three-part quality and art pass: Neocom upgrades, Aura guidance, sharper skies |
| **2025-11-18** | **Catalyst** | **Mining overhaul** — lasers and strip miners four times faster, gas harvesters twice, **critical mining successes**, the Pioneer and Outrider hulls, Prismaticite, ore grades renamed, Omber and Kernite back in high-sec |
| 2025-05-27 | **Legion** | Freelance Jobs; sovereignty and exploration iteration |
| 2024-11-12 | **Revenant** | The Deathless storyline, Mercenary Dens, Tholos and Cenotaph |
| 2024-06-11 | **Equinox** | **Null-sec sovereignty overhaul** — Sov Hubs replace the claim unit and infrastructure hub; Orbital Skyhooks; power, workforce and reagents; the Metenox Moon Drill; the SKINR designer |
| 2023-11-14 | **Havoc** | **Playable pirate factions** in Faction Warfare: insurgencies, smuggling, black markets, Zarzakh |
| 2023-06-13 | **Viridian** | Corporation Projects and management tools, structure customisation |
| 2022-08-11 | **Uprising** | Faction Warfare rebuilt on frontline, command-operations and rearguard states with scaling rewards |
| 2020–2021 | Quadrant era | No classic named expansions |
| 2019-05-28 | **Invasion** | The **Triglavian invasion** begins; mutaplasmids; 64-bit client |
| 2018-11-13 | **Onslaught** | Upwell navigation structures — cyno beacons and jammers, **Ansiblex jump gates**; Abyssal PvP |
| 2018-05-29 | **Into The Abyss** | **Abyssal Deadspace** and filaments |
| 2017-10-24 | **Lifeblood** | **Refineries**, the moon-mining overhaul, mining ledgers |
| 2016-11-15 | **Ascension** | **Free to play** via Alpha and Omega clone states; Engineering Complexes; command bursts |
| 2016-04-27 | **Citadel** | **Upwell Citadels** — Astrahus, Fortizar, Keepstar; force auxiliaries |
| 2015 | Release era | Parallax, Vanguard, Galatea, **Aegis** (entosis sovereignty), Carnyx, Mosaic, Scylla, Tiamat |
| 2014 | Release era | Rhea, **Phoebe** (jump fatigue introduced), Oceanus, Hyperion, **Crius** (industry overhaul), Kronos |
| 2013-11-19 | **Rubicon** | Ghost sites, hacking changes, high-sec customs offices |
| 2013-06-04 | **Odyssey** | Exploration revamp; ice-belt anomalies |
| 2012-12-04 | **Retribution** | Bounty rebuild, **Crimewatch 2.0** with suspect and criminal flags and safeties, the **Venture** |
| 2011-11-29 | **Crucible** | **Time dilation**; a large UI pass; the goodwill release after Incarna |
| 2011-06-21 | **Incarna** | Captain's Quarters and the store that triggered the "monoclegate" player protests |
| 2010-11-30 | **Incursion** | **Sansha incursions**; learning skills removed |
| 2010-05-26 | **Tyrannis** | **Planetary Interaction** |
| 2009-12-01 | **Dominion** | Sovereignty overhaul; in-game browser |
| 2009-03-10 | **Apocrypha** | **The skill queue**, **tech 3 strategic cruisers**, **wormhole space** and the Sleepers |
| 2008-06-10 | **Empyrean Age** | **Faction Warfare** introduced |
| 2007-12-05 | **Trinity** | New graphics engine; jump freighters; the infamous `boot.ini` bug |
| 2006-11-29 | **Revelations I** | **Scanning and exploration**, the **contract system**, **invention** replacing the tech 2 blueprint lottery, **rigs** |
| 2005-12-16 | **Red Moon Rising** | 39 ships including carriers, motherships and **titans** |
| 2005-06-29 | Exodus: Cold War | Freighters, dreadnoughts, outposts |
| 2004-11-17 | **Exodus** | **Alliances** and player-owned starbases claiming null-sec |
| 2003-12-18 | **Castor** | The first **tech 2** ships; agent missions |
| **2003-05-06** | Launch | *The Second Genesis* |

### Announced, not yet released

Fractured Skies' full notes are due 6 November 2026 and the expansion on the 10th. Its campaign
bonuses activate on **5 January 2027**, a four-way low-security live event follows in mid-January,
and **Conquests** — the third chapter, in which Conquest Engines claim whole systems through timed
directives and a final siege — arrives from **February 2027**. EVE Vanguard, the companion
first-person shooter, opens a paid round-the-clock alpha on 10 November. The Google DeepMind
collaboration is early, and is reported to involve an **offline build of EVE on a local server**
plus historical data, for work on long-horizon planning and continual learning.

### Reputation

EVE is more written-about than played. Its wars make mainstream news, its heists hold world records,
and its economy is studied: the **clash at Atioth** in April 2026 set a Guinness record with
**10,253 pilots in one system** and about **10 trillion ISK destroyed**, and B-R5RB in 2014 is still
cited at over US$300,000 of notional value lost in a night. The studio has employed economists since
2007 and publishes a **Monthly Economic Report** with its raw data attached. And it runs a
**Council of Stellar Management**: ten players, elected by single transferable vote, flown to
Iceland, and placed under non-disclosure agreement to advise on design.

[Wikipedia: CCP Games](https://en.wikipedia.org/wiki/CCP_Games), [Expansions of EVE Online](https://en.wikipedia.org/wiki/Expansions_of_Eve_Online), [Shacknews: the rebrand](https://www.shacknews.com/article/149020/fenris-creations-ccp-games-eve-online-rebrand), [Game Developer: EVE dev turns independent](https://www.gamedeveloper.com/business/eve-online-studio-ccp-games-turns-independent-and-rebrands-as-fenris-creations), [MassivelyOP on the rebrand and DeepMind](https://massivelyop.com/2026/05/06/eve-continues-eve-onlines-ccp-games-rebrands-as-fenris-creations-partners-with-google-deepmind/), [CCP: Tranquility Tech IV](https://www.eveonline.com/news/view/tranquility-tech-iv), [CCP: The Move to Python 3 Begins](https://www.eveonline.com/news/view/the-move-to-python-3-begins), [CCP: Introducing Clone States](https://www.eveonline.com/news/view/introducing-clone-states-and-the-future-of-access-to-eve-online), [CCP: Catalyst expansion notes](https://www.eveonline.com/news/view/catalyst-expansion-notes), [CCP: Cradle of War expansion notes](https://www.eveonline.com/news/view/cradle-of-war-expansion-notes), [CCP: Fractured Skies In Focus](https://www.eveonline.com/news/view/fractured-skies-in-focus), [CCP: Directors' Letter, 2026 and beyond](https://www.eveonline.com/news/view/directors-letter-2026-and-beyond), [EVE University: Clone states](https://wiki.eveuniversity.org/Clone_states), [eve-offline concurrency tracker](https://eve-offline.net/?server=tranquility)

## The universe

Counted from the game's own data on 2 November 2026. These supersede the figures in most wikis and
press coverage, which usually quote 7,800–7,900 systems; the number has grown with Pochven, Zarzakh
and Exordium.

| Metric | Count |
| --- | ---: |
| **Solar systems** | **8,490** |
| **Regions** | **114** |
| **Constellations** | **1,184** |
| Known space | **5,485**, of which 230 are permanently inaccessible "Jove" systems, leaving about **5,255** reachable |
| **Wormhole space** | **2,604** systems across 33 regions |
| Abyssal Deadspace | 400 instanced systems |
| **Stargate objects** | **13,978**, so about **6,989** two-way links |
| NPC stations | 5,210 |

Known space is joined by fixed **stargates** — warp to the gate, jump, arrive at its pair — forming
a static graph. Everything else in the game is reached another way: wormholes, filaments, or a jump
drive.

### Security status

Two different things share the name, and conflating them causes no end of confusion.

**System security** is a number per system from 1.0 down to −1.0.

| Band | Label | Systems |
| --- | --- | ---: |
| 1.0 | High-sec | **53** — all of them Exordium, the 2026 starter region, and the first true 1.0s in the game's history |
| 0.9–0.5 | High-sec | 1,193 |
| 0.4–0.1 | Low-sec | 674 |
| 0.0 and below | Null-sec | 3,565, about 3,335 of them reachable |

Before Exordium nothing displayed 1.0 — the highest real values in the game are Tew at 0.9498 and
Yulai at 0.949.

| | High-sec | Low-sec | Null-sec | Wormholes and Pochven |
| --- | --- | --- | --- | --- |
| **CONCORD** | **Spawns and destroys criminals**, in a few seconds to about thirty depending on the system | Does not respond to criminal acts | None | None |
| Faction police | Hunt pilots below a security threshold that tightens with the system | Yes | No | No |
| Gate and station sentry guns | **Yes** — 176 damage a second at 500 km, invulnerable and untargetable | Yes | No | No |
| Shooting another ship | **Criminal** | **Suspect** | Legal, unflagged | Legal, unflagged |
| Shooting a capsule | Criminal | **Criminal** | Legal | Legal |
| Stealing from a wreck | **Suspect** | Suspect | Legal | Legal |
| Lighting a cynosural field | **Forbidden** | Yes | Yes | Special rules |
| Sovereignty | No | No | **Claimable** | **None at all** |

**Crimewatch** then runs the consequences on timers: a 60-second **weapon timer** that blocks
jumping, docking and refitting; a 15-minute **suspect** flag that lets anyone shoot you; a 15-minute
**criminal** flag that also brings CONCORD; a 5-minute **limited engagement** between two specific
pilots; and a **15-minute log-off timer** that renews if you are shot again while logged off. Since
2012 a three-state client-side **safety** interlock refuses, by default, to let you do anything that
would flag you at all.

**Character security status** runs from −10 to +10, in practice capping near +5. An unprovoked
attack costs a little; **killing a capsule costs about ten times more**; and a higher-standing
aggressor is punished harder than a low one. Below about **−5 you are an outlaw**: anyone may shoot
you anywhere, high-security space included, with no CONCORD response. It is repaired by pirate
missions, ratting, incursions, or handing security tags to CONCORD — and tags can only bring you
back to zero, never above it.

### The factions

Four empires — the Amarr theocracy, the Caldari corporate state, the Gallente Federation and the
Minmatar Republic — plus the pirate factions that matter mechanically: the Angel Cartel, Guristas,
Blood Raiders, Sansha's Nation and Serpentis. Around them sit CONCORD as the law, ORE as the mining
conglomerate whose hulls every miner flies, the Sisters of EVE, and the Secure Commerce Commission
that takes a cut of every trade.

Standing with each is a real number that gates agents, loyalty stores and, in Pochven, whether you
can dock at all.

### Wormhole space

Added by Apocrypha in 2009, **Anoikis** is 2,604 systems named `J######` and defined by what it
lacks: **no stargates, no stations** (bar the Sisters' outpost in Thera), **no empire authority, no
sovereignty**, and **no working Local chat** — the channel exists but nobody appears in it, so you
cannot know who is in the system with you. That single omission is what makes wormhole space the
most paranoid environment in the game.

| Class | Systems |
| --- | ---: |
| C1 / C2 / C3 | 363 / 537 / 506 |
| C4 / C5 / C6 | 523 / 531 / 118 |
| Thera, and the small shattered constellations | 1 and 25 |

Class rises with how entrenched the Sleepers are and how strong the **system effect** can be, and
those effects are dramatic: a Magnetar gives **+100% weapon damage** for −50% tracking, a Wolf-Rayet
gives **+200% small-weapon damage**, a Pulsar doubles shield capacity while halving armour
resistances, and a Black Hole doubles speed while making everything handle like a barge.

Holes themselves are scanned down as signatures and have three properties that govern wormhole life:
a **lifetime** of around 24 hours, a **total mass allowance** of about two billion kilograms with a
per-jump limit, and a **maximum ship size**. Fleets deliberately collapse holes by running mass
through them. You cannot jump the same hole twice in five minutes, and — unlike gates — wormhole
jumps leave a timestamped entry in Local, which is the one piece of intelligence available.

### Pochven and the Abyss

**Pochven** is what the Triglavian invasion storyline left behind: 27 systems in three constellations
of nine, one per Triglavian clade, where the gates form **a single loop with no branches and no dead
ends**. There is no player sovereignty, a permanent system effect penalises warp speed and target
count, entry is by filament or wormhole, and leaving means lighting an exit trace that **cannot be
jumped for up to three and a half minutes** — which is a long time under pressure. Ships destroyed
there drop **up to 60% of their loot**, against the usual 50%.

**Abyssal Deadspace** is the most structurally unusual content in EVE and the most transplantable.
You consume a **filament** and are dropped into an instanced pocket.

| Mechanic | Detail |
| --- | --- |
| Tiers | **Seven**, T0 to T6: Tranquil, Calm, Agitated, Fierce, Raging, Chaotic, Cataclysmic |
| What you may bring | **One cruiser**, or two destroyers, or three frigates — strategic cruisers barred |
| Structure | **Three pockets**; each gate opens only when everything in the pocket is dead |
| **Time limit** | **Twenty minutes, hard.** Still inside when it expires and your ship and pod are destroyed |
| Failure cost | The hull, the capsule, the clone and every fitted implant |
| Inside | **No cloaking, no warping to fleet members, no mobile depots, no Local, no directional scanner, no map** |

Each site also rolls one of five **weathers** that applies to you *and* the NPCs — a bonus paired
with a resistance hole, such as Firestorm's +50% armour for −70% thermal resistance at the top tiers.
It is a complete, self-contained, repeatable, rankable challenge with a hard clock and total loss on
failure, built for one ship.

### Getting around

Stargates are free and instant between known systems. Beyond that: **jump drives** on capitals,
which need a **cynosural field** lit at the destination by another pilot and cannot be used in
high-security space; **titan bridges** that throw a fleet to a lit cyno; and **Ansiblex jump
bridges**, alliance-built gates between owned systems. Jump fatigue, introduced in 2014 to stop
instant force projection across the galaxy, was explicitly **abandoned as the throttle** in
September 2026 in favour of a capacitor on the jump bridges whose cost rises with distance from the
owning alliance's capital.

[EVE University: Security status](https://wiki.eveuniversity.org/Security_status), [Crimewatch](https://wiki.eveuniversity.org/Crimewatch), [W-space](https://wiki.eveuniversity.org/W-space), [Wormholes](https://wiki.eveuniversity.org/Wormholes), [Pochven](https://wiki.eveuniversity.org/Pochven), [Abyssal Deadspace](https://wiki.eveuniversity.org/Abyssal_Deadspace), [ESI universe endpoints](https://esi.evetech.net/latest/universe/systems/), [EVE Ref reference data](https://data.everef.net/reference-data/), [CCP: Force Projection revamped](https://www.eveonline.com/news/view/major-update-force-projection-revamped)

## Factions

EVE's factions are not flavour. Each empire owns a ship line, a weapon philosophy, a tanking layer,
a navy, a loyalty-point store and a standing you can gain or lose, so choosing who to work for has
mechanical consequences that compound over years of play.

### The four empires

| Empire | Identity | Combat signature |
| --- | --- | --- |
| **Amarr Empire** | A theocratic absolute monarchy, the largest by territory, built on religious destiny and a legacy of **slavery** | Armour, energy turrets, long range, heavy capacitor use |
| **Caldari State** | A megacorporate oligarchy — the State *is* its corporations. Duty, efficiency, collectivism. Seceded from the Gallente | Shields, missiles and railguns, long range |
| **Gallente Federation** | Liberal democracy, individual liberty and mass media; the ideological opposite of both Amarr and Caldari | Armour, **drones** and short-range blasters |
| **Minmatar Republic** | A tribal republic rebuilt after escaping Amarr enslavement; improvised, fast, cheap | Shields and speed, projectiles with freely selected ammunition |

The two standing conflicts — **Amarr against Minmatar**, **Caldari against Gallente** — are exactly
the two Faction Warfare war zones, so the lore and the map agree.

### The pirate factions

Each has territory, a hybrid ship line that borrows from two empires, and a loyalty store.

| Faction | Flavour | Ships |
| --- | --- | --- |
| **Angel Cartel** | The largest and best-organised syndicate | Minmatar and Gallente hybrids, built for speed |
| **Guristas** | Caldari deserters turned raiders | Caldari and Gallente, missiles and drones |
| **Blood Raider Covenant** | An Amarr heretical cult that harvests capsuleer blood | Amarr and Minmatar, capacitor warfare |
| **Sansha's Nation** | A hive-mind cyborg horror, and the driver of **incursions** | Amarr and Caldari, lasers at range |
| **Serpentis** | A drug cartel and the game's booster manufacturer | Gallente and Minmatar, drones and webs |

Havoc made two of them playable: the Angel Cartel and the Guristas can be **enlisted with** in
Faction Warfare insurgencies, which is a rare thing in any game — the pirates are a side, not just
an obstacle.

### The institutions

These matter because each one owns a mechanic.

| Organisation | What it owns |
| --- | --- |
| **CONCORD** | Pan-empire law. It is the thing that actually destroys criminals in high-security space, and it runs the security-tag system that lets an outlaw buy back a clean record |
| **ORE** | Outer Ring Excavations, the mining manufacturer. **Every hull a miner flies is theirs** — the Venture, the barges and exhumers, the Porpoise, Orca and Rorqual, and the 2025 Pioneer |
| **Sisters of EVE** | A humanitarian and scientific order that makes the best **exploration** hulls — Astero, Stratios, Nestor — and runs the only stations in wormhole space, in Thera |
| **Secure Commerce Commission** | Regulates markets and contracts, and mechanically **owns the broker fees and sales tax**. It is also the nominal owner of a freshly anchored sovereignty hub |
| **EDENCOM** | The empires' joint defence force, raised against the Triglavians |
| **Triglavian Collective** | Invaders out of Abyssal Deadspace whose campaign created **Pochven**, and whose ship line ramps damage the longer it holds a target |
| **Drifters and Sleepers** | Ancient and post-human factions tied to wormhole space and the game's deep backstory. The Sleepers guard the materials that tech 3 is built from |

The design lesson is that a faction in EVE is a bundle: a standing number, a store, a hull line, a
damage profile and a place on the map. Nothing is decorative.

[EVE University: Factions](https://wiki.eveuniversity.org/Factions), [NPC corporations](https://wiki.eveuniversity.org/NPC_corporations), [CCP: Havoc expansion notes](https://www.eveonline.com/news/view/havoc-expansion-notes)

> This section is a compressed summary of long-established background rather than a fresh source
> pass; the names, roles and mechanical attachments are stable and well documented, but no attempt
> was made to re-verify the lore against 2026 material.

## Ships and fitting

Ships in EVE are consumables. Everything below is bought to be lost eventually, and the price
ladder is steep enough that the choice of hull is itself the main risk decision a pilot makes.

### The hull ladder

Jita hull prices, unfitted, on 2 November 2026. A fit routinely costs between half and five times
the hull.

| Class | Example | Hull price | What a loss means |
| --- | --- | ---: | --- |
| Corvette | Impairor | 100,000 | Nothing — handed out free at any station, so you can always undock |
| Frigate, tech 1 | Rifter | 270,200 | About a minute of income. Fully consumable |
| Frigate, tech 2 | Crow, an interceptor | 17.3M | Routine, and sixty times the tech 1 hull |
| Destroyer, tech 1 | Catalyst | 1.2M | Trivial — which is exactly why it is the standard gank hull |
| Destroyer, tech 3 | Confessor, Svipul, Hecate | 61–68M | Real but recoverable |
| Cruiser, tech 1 | Vexor | 11M | Routine. The classic bracket for learning to fight |
| Cruiser, tech 2 | Ishtar, Guardian | 135M, 258M | Meaningful; a fitted logistics cruiser passes 400M |
| Cruiser, tech 3 | Loki, Tengu, Proteus | 227–237M | Hull plus four subsystems plus rigs |
| Battlecruiser | Hurricane; Damnation | 50M; 315M | The command ship carries fleet-wide bursts, so it is a priority target |
| Battleship, tech 1 | Megathron | 149M | Painful for a new player, routine for an established one |
| Battleship, navy | Megathron Navy Issue | 400M | About 2.7× the tech 1 hull |
| Battleship, pirate | Machariel, Nightmare, Bhaalgorn | 993M–1.25B | Fitted, comfortably multi-billion |
| Battleship, tech 2 | Paladin, Golem — marauders | 916M, 935M | With deadspace modules, 3–6B fitted |
| Hauler | Badger | 1.5M | The hull is trivial; **the cargo is the loss**, and that asymmetry is the whole basis of hauler ganking |
| Freighter | Charon, Obelisk, Fenrir | 1.38–1.50B | Hull about 1.4B, cargo routinely several times that |
| Jump freighter | Ark, Rhea, Anshar | 6.1–7.0B | Plus cargo |
| Capital | Archon, Revelation, Apostle | 2.4–5.3B | A fleet operation to field and to lose |
| Supercapital | Nyx, Wyvern | **42.6B, 43.8B to build** | Docks only at a Keepstar |
| **Titan** | Avatar, Ragnarok | **133B to build** | Months of coordinated effort |

### The four doctrines

| Empire | Weapons | Tank | Identity |
| --- | --- | --- | --- |
| Amarr | Energy turrets, with reusable crystals for free ammunition and heavy capacitor draw | Armour | Slow, tough, long range |
| Caldari | Missiles and railguns | Shields | Long-range and sniper profiles |
| Gallente | Drones and blasters | Armour | Mid-speed brawlers |
| Minmatar | Projectiles, which use no capacitor and select damage freely by ammunition | Shields | Fastest, cheapest hulls |

Damage comes in four types, and **the two tanking layers have inverted weaknesses** — which is what
makes ammunition choice a genuine tactical lever rather than flavour:

| Layer | EM | Thermal | Kinetic | Explosive |
| --- | ---: | ---: | ---: | ---: |
| Hull | 33% | 33% | 33% | 33% |
| Shields, baseline | **0%** | 20% | 40% | 50% |
| Armour, baseline | 50% | 35% | 25% | **10%** |

Shields have a hole in EM, armour has a hole in explosive. Tech 2 hull classes then apply a further
*multiplicative* cut to whatever vulnerability remains — up to **−75%** on an assault frigate or
heavy assault cruiser — which is why a tech 2 hull is so much harder to kill than its tech 1
counterpart. NPC factions have fixed damage profiles, so PvE fits are deterministic in a way PvP
fits never are.

### Tiers, and the module ladder

Hulls run tech 1, tech 2 (invention-gated, specialist, heavily resistance-bonused), tech 3
(strategic cruisers assembled from a hull plus four subsystems, and tactical destroyers with three
switchable modes), then navy, pirate-faction and unique hulls.

Modules have their own ladder, and it is longer than most games':

| Rung | Source |
| --- | --- |
| Tech 1 | Manufactured from minerals |
| Meta or "named" | NPC loot — usually slightly better and **easier to fit** |
| **Tech 2** | Invention plus higher skills. The competitive standard |
| Storyline | Mission rewards and rare copies |
| Faction | Loyalty-point stores — often not stronger than tech 2, but cheaper to fit |
| **Deadspace** | Rare drops in low and null complexes, graded C through B, A to X. X-type runs to billions |
| **Officer** | Named rare spawns. The strongest modules in the game, from 250M to about **12B ISK each** |

### Fitting is a budget problem

Every hull publishes fixed counts of high, mid and low slots, plus rig slots and weapon hardpoints,
and two hard budgets — **CPU and powergrid** — that a module simply cannot be onlined without.

The elegance is in the coupling. **Shield modules live in mid slots and armour modules in low
slots**, and mid slots are also where tackle, propulsion and electronic warfare go. So choosing a
shield tank directly costs you the points and webs you would otherwise bring. Tank choice is a
tactical choice, not just a defensive one.

Two more rules do a great deal of balancing work:

- **The stacking penalty.** When several modules apply the same effect, only the strongest counts
  fully; the rest are multiplied by roughly `exp(−((n−1)/2.67)²)`, giving 1.00, 0.87, 0.57, 0.28,
  0.11 for the first five. Stacking is never banned, merely made pointless.
- **Capacitor recharge peaks at 25% of capacity** and collapses below it, which is why the standing
  advice is to disengage before you drop under a quarter.

Tanks come in three archetypes: **buffer**, which is raw hit points with no capacitor cost and no
self-repair, and the fleet standard because remote logistics can top it up; **active repair**, which
can outlast sustained fire but dies to capacitor warfare; and **passive shield**, which exploits the
recharge curve, uses no capacitor at all and is immune to neutralisers, but needs many slots.

[EVE University: Damage types](https://wiki.eveuniversity.org/Damage_types), [Natural resistances](https://wiki.eveuniversity.org/Natural_Resistances), [Tanking](https://wiki.eveuniversity.org/Tanking), [Stacking penalty](https://wiki.eveuniversity.org/Stacking_penalty), [Capacitor](https://wiki.eveuniversity.org/Capacitor), [Rigs](https://wiki.eveuniversity.org/Rigs), [Strategic cruisers](https://wiki.eveuniversity.org/Strategic_Cruisers), [Faction modules](https://wiki.eveuniversity.org/Faction_modules), live Jita prices via Fuzzwork and the [EVE Ref industry cost API](https://docs.everef.net/api/industry-cost.html)

### Drones and fighters

Drones are governed by **two independent hull limits and a skill cap**, which is a neat piece of
design: the drone **bay** in cubic metres caps how many you can carry, the **bandwidth** in
megabits caps how many you can have in space at once, and neither can be raised by any module or
skill. The **Drones** skill then allows one in space per level, to a maximum of five.

| Size | Bay volume | Bandwidth |
| --- | ---: | ---: |
| Light | 5 m³ | 5 Mbit/s |
| Medium | 10 m³ | 10 Mbit/s |
| Heavy or sentry | 25 m³ | 25 Mbit/s |

So a Tristan with a 40 m³ bay and 25 Mbit/s carries eight light drones but can field only five — or
two mediums and a light. The hull decides your options and the skill decides how many of them you
get.

**Fighters** are the capital equivalent and deliberately break that rule: they launch from tubes as
**squadrons**, are ordered about rather than left to their own devices, and have shields but **no
armour and only 100 points of structure**, so they die to anything that can hit them.

| Fighter | Role | Squadron |
| --- | --- | ---: |
| Light Attack | Anti-subcapital | 6 |
| Space Superiority | Anti-drone and anti-fighter | 12 |
| Heavy Attack | Anti-capital, supercarriers only | 6 |
| Long Range Attack | Anti-battleship and bombing | 6 |
| Support | Electronic warfare, unarmed | 3 |

### Insurance, clones, and ships as inventory

**Insurance covers the hull only** — never modules, rigs, cargo or drones — in seven tiers, as a
percentage of the game's own *estimated* hull value rather than its market price.

| Tier | Payout |
| --- | ---: |
| Uninsured | **40%** |
| Basic to Platinum | 50%, 60%, 70%, 80%, 90%, **100%** |

Policies run twelve weeks, and coverage **drops back to the 40% default** if the ship is repackaged,
traded, sold, contracted, or destroyed by CONCORD — so a suicide ganker cannot insure the hull they
intend to lose. Because the payout is based on an estimated value derived from build materials,
faction and tech 2 hulls insure badly: the estimate does not know what you paid.

Losing the ship leaves you in a **capsule**. Losing the capsule returns you to a medical clone at
your home station and **destroys every implant you had fitted**, which is what makes a full set of
+5 attribute implants a standing wager on not being caught. **Jump clones** let a pilot keep bodies
in several places, with different implants in each.

The combination is deliberate and worth stating plainly: **ships are inventory, not progress.**
Insurance returns a fraction of the hull and none of the fit, loot transfers part of your loss to
whoever killed you, and nothing you lose was ever a level you have to re-earn.

[EVE University: Drones](https://wiki.eveuniversity.org/Drones), [Fighters](https://wiki.eveuniversity.org/Fighters), [Insurance](https://wiki.eveuniversity.org/Insurance), [Clone](https://wiki.eveuniversity.org/Clone), [Jump clones](https://wiki.eveuniversity.org/Jump_clones)

## Skills and progression

EVE's progression system is the one most often described as a mistake and most stubbornly defended.
Skills train in **wall-clock time**, continuously, whether or not you are logged in. There is no
experience, no grinding, no rested bonus, and **no way to train faster by playing more**.

```
Omega: SP per minute = primary attribute + 0.5 × secondary attribute
Alpha: exactly half that
```

A well-remapped character with +5 implants trains about **45 skill points a minute**, or 2,700 an
hour. Every skill has five levels and a **rank** multiplier from 1 to 16:

| Level | Cumulative SP at rank 1 | Time at 2,700/hr |
| --- | ---: | --- |
| I | 250 | 6 minutes |
| II | 1,414 | 31 minutes |
| III | 8,000 | 3 hours |
| IV | 45,255 | 17 hours |
| **V** | **256,000** | **4 days** |

Level IV is only about **18% of the points** of level V, so the first four levels are quick and the
fifth is the long pole. Multiply by rank and the consequence is stark: **a single level V on a
high-rank capital skill is one to two months of real time**, and no amount of playing shortens it.

| Rank | SP for level V | Days |
| ---: | ---: | ---: |
| 1× | 256,000 | 3.9 |
| 5× | 1,280,000 | 19.8 |
| 8× | 2,048,000 | 31.6 |
| 12× | 3,072,000 | 47.4 |
| 16× | 4,096,000 | 63.2 |

Training all 494 skills in the game would take **604,416,000 skill points**.

### Trading skill points

Skill points became a commodity in 2016. A **Skill Extractor** pulls 500,000 points out of a
character — which must keep at least 5 million — into a tradeable injector. The receiving yield is
**tiered by how much the recipient already has**, which is the mechanism that stops anyone simply
buying a veteran:

| Recipient's total | Points per injector |
| --- | ---: |
| Under 5M | **500,000** |
| 5–50M | 400,000 |
| 50–80M | 300,000 |
| Over 80M | **150,000** |

On 2 November 2026 an injector sold at about 735M ISK and an extractor at 465M, so moving half a
million points created roughly **270M ISK of value** — and a new character was effectively buying
skill points at about 1,470 ISK each.

### Access, not power

There is **no character level, no class and no talent tree**, and no statistic that scales with
total skill points. Points buy *access* — to hulls, modules, ammunition and activities — plus
bounded percentage bonuses. Three consequences follow, and they are the reason the design survives:

- Time away from the game costs you ISK, not capability.
- A veteran **cannot out-statistic a newcomer in the same hull**. They can only out-choose them.
- The real progression curve is wealth and social capital, not skill points.

**Implants** occupy ten slots: five attribute implants that speed training, and five hardwirings
that give combat or industrial bonuses. They are **destroyed when your capsule is**, which makes a
full set a wager on not being caught.

[EVE University: Skill training](https://wiki.eveuniversity.org/Skill_training), [Clone states](https://wiki.eveuniversity.org/Clone_States), [Skill trading](https://wiki.eveuniversity.org/Skill_trading), live Jita prices via Fuzzwork

## Combat

### Nothing dies unless it is held

The single most important fact about EVE combat is that any ship can warp away in a few seconds, so
every kill begins with **tackle**.

| Module | Range | Warp core strength | Also disables |
| --- | --- | ---: | --- |
| Warp Disruptor, "point" | 20–30 km | 1 | – |
| **Warp Scrambler, "scram"** | 7.5–11 km | **2–3** | **Microwarpdrives and jump drives, regardless of the target's warp strength** |
| Heavy disruptor and scrambler | 22–40 km, 8.5–15 km | 3–5, 6–10 | – |
| Stasis Webifier | 10–15 km | – | **−50 to −60% maximum velocity** |
| Interdiction Sphere | **20 km bubble, 2 minutes** | Blocks all warp | Null-sec and wormholes only |
| Warp Disruption Field Generator | 20 km bubble | **100 points** scripted | An effectively unbreakable hold |

The crucial asymmetry is that a scrambler is a point **plus** a propulsion kill. That makes **7.5 km
the most dangerous range band in the game**: a ship caught there with a microwarpdrive loses both
its escape and its speed at once.

### Hitting things

The turret hit formula is published and unusually legible:

```
chance = 0.5 ^ [ (angular × 40,000 / (tracking × signature))² + (max(0, range − optimal) / falloff)² ]
```

Three consequences shape every engagement. At optimal plus one falloff you hit **half** the time; at
two falloffs, **6.25%**. **Doubling your tracking, doubling the target's signature radius, and
halving its angular velocity are exactly equivalent** — which is why a target painter that adds 25%
to signature helps every weapon in the fleet, not just its own ship. And signature radius is itself
pushed up by shield extenders and an active microwarpdrive, so the defensive choices feed back into
how easily you are hit.

A small fraction of shots are **wrecking hits** at triple damage, which is how a frigate occasionally
kills something enormous.

### Electronic warfare

| Type | Mechanic |
| --- | --- |
| **ECM** | **Probabilistic** — jam chance is strength divided by the target's sensor strength. Success drops every one of their locks |
| Remote Sensor Dampener | **Deterministic**: cuts targeting range and scan resolution |
| **Target Painter** | Raises the target's signature radius, helping **every** friendly weapon |
| Tracking Disruptor | Cuts turret optimal, falloff and tracking. No effect on drones |
| Guidance Disruptor | The missile equivalent |
| **Energy Neutraliser** | Drains the target's capacitor, killing active tanks, cap boosters and microwarpdrives |
| Energy Nosferatu | Transfers capacitor from the target to you, at no cost to your own |

ECM is the only probabilistic one, and it is correspondingly hated.

### Fleets

Capitals enter **siege** or **triage** — a dreadnought's Siege Module runs a five-minute cycle,
consumes 250 units of Strontium Clathrates, and grants **+840% turret damage** while making the ship
immobile and unable to receive remote repair. That is the whole shape of capital warfare: enormous
damage, total commitment, and a five-minute window in which you cannot leave.

A **doctrine** is a prescribed fleet composition — specific hulls with specific fits — that an
organisation stocks, ships and reimburses, so that two hundred pilots arrive with compatible
resistances and ranges. **Command bursts** then project fleet-wide bonuses from a single hull, in a
15 km radius, fed by ammunition: armour and shield resistances up about 23% at best, signature
radius down 18%, tackle range up 35%. **Anchoring** — everyone orbiting a designated ship so the
fleet moves as one body and stays inside that 15 km — is the basic fleet discipline.

### Time dilation

When a node cannot process its queue in real time, the server **slows the clock** rather than
dropping commands, down to a floor of **10% of normal speed** — one game second taking ten real
ones. It applies to the whole node, so neighbouring systems slow too, and it needs thousands of
pilots in a system to reach the floor.

Server time is unaffected: industry jobs, skill training and structure timers keep running at normal
speed while a battle crawls.

The alternative, which EVE lived with before 2011, was packet loss and modules that silently failed
to activate — large fights as a lottery. Time dilation converts an unplayable fight into a slow one,
and that trade is why EVE can hold ten thousand players in one system at all.

### Loss is permanent

A destroyed ship leaves a **wreck** holding some of its modules and cargo; the rest is annihilated.
A **killmail** is generated automatically, itemising the fit, the cargo and everyone who contributed
damage, and third-party killboards aggregate them into public records of every pilot's history.

Three properties combine to give destruction its weight: the ship is **gone**, with no respawn and
no repair; the loss is **itemised and public**; and somebody else now owns part of what you were
carrying. A killmail is simultaneously a receipt, a trophy and an intelligence document, and the
culture of the game is built on them.

### Large battles

| Battle | Scale |
| --- | --- |
| Asakai, 2013 | The accidental battle — a misclicked titan jump |
| **B-R5RB**, 2014 | 75 titans destroyed; over US$300,000 of notional value; covered in mainstream press |
| **Atioth**, April 2026 | **10,253 pilots in one system**, a new world record beating 6,557, with about **10 trillion ISK destroyed** — and the server node collapsed minutes before the contested Keepstar came online |
| Pochven, August 2026 | About **9,000 ships destroyed** |

[EVE University: Tackling](https://wiki.eveuniversity.org/Tackling), [Turret damage](https://wiki.eveuniversity.org/Turret_damage), [Electronic warfare](https://wiki.eveuniversity.org/Electronic_warfare), [Time dilation](https://wiki.eveuniversity.org/Time_dilation), [Command bursts](https://wiki.eveuniversity.org/Command_bursts), [CCP: Clash at Atioth](https://www.eveonline.com/news/view/clash-at-atioth), [CCP: Monthly Economic Report, August 2026](https://www.eveonline.com/news/view/monthly-economic-report-august-2026)

## Mining

Ships mine asteroid belts, ore anomalies, ice belts, gas clouds and moon chunks. EVE has reworked
extraction repeatedly — Scarcity and the Resource Redistribution of 2020–22, mining residue in
December 2021, Equinox planetary industry and Sovereignty Hubs in June 2024, Revenant's mining
sovereignty tuning in March 2025 — and most recently the **Catalyst expansion of 18 November 2025**,
which quartered mining-laser cycle times, added critical mining hits, introduced the Pioneer mining
destroyer and Prismaticite, and returned Omber and Kernite to high-security space.

Most community wikis still carry pre-Catalyst numbers. Figures below come from EVE Ref, which is
generated from the game's own static data export, except where noted.

### Asteroid ore

Yields are the base reprocessing output of one 100-unit batch — the portion size for every asteroid
ore — before skills, structure and implants.

| Ore | m³/unit | Batch m³ | Trit | Pye | Mex | Iso | Nox | Zyd | Meg | Morph | Space |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Veldspar | 0.1 | 10 | 400 | – | – | – | – | – | – | – | High-sec belts 1.0–0.5 |
| Scordite | 0.15 | 15 | 150 | 110 | – | – | – | – | – | – | High-sec belts 1.0–0.5 |
| Pyroxeres | 0.3 | 30 | – | 90 | 30 | – | – | – | – | – | High-sec 0.9–0.5, low, null |
| Plagioclase | 0.35 | 35 | 175 | – | 70 | – | – | – | – | – | High-sec ≤0.7 |
| Omber | 0.6 | 60 | – | 90 | – | 75 | – | – | – | – | High-sec 0.5–0.8 anomalies, low |
| Kernite | 1.2 | 120 | – | – | 60 | 120 | – | – | – | – | High-sec 0.5–0.8 anomalies, low, null |
| Jaspet | 2 | 200 | – | – | 150 | – | 50 | – | – | – | Low-sec |
| Hemorphite | 3 | 300 | – | – | – | 240 | 90 | – | – | – | Low-sec 0.2–0.1 |
| Hedbergite | 3 | 300 | – | 450 | – | – | 120 | – | – | – | Low-sec |
| Gneiss | 5 | 500 | – | 2,000 | 1,500 | 800 | – | – | – | – | Low, null, wormhole |
| Dark Ochre | 8 | 800 | – | – | 1,360 | 1,200 | 320 | – | – | – | Low, null |
| Crokite | 16 | 1,600 | – | 800 | 2,000 | – | 800 | – | – | – | Low, null |
| Bistot | 16 | 1,600 | – | 3,200 | 1,200 | – | – | 160 | – | – | Null, wormhole |
| Arkonor | 16 | 1,600 | – | 3,200 | 1,200 | – | – | – | 120 | – | Null, wormhole |
| Spodumain | 16 | 1,600 | 48,000 | – | – | 1,000 | 160 | 80 | 40 | – | Pochven only |
| Mercoxit | 40 | 4,000 | – | – | – | – | – | – | – | 140 | Null ≤ −0.8; needs Deep Core Mining |

Veldspar is the densest Tritanium source at 40 units per m³, which is why the cheapest ore in the
game is also the backbone of hull production. Mercoxit is the only source of Morphite, and the only
ore needing its own module class.

Three newer families sit outside that table. The **Pochven** ores — Bezdnacine, Rakovene and
Talassonite, all 16 m³ — carry about 40,000 Tritanium per batch plus a rare mineral each; Rakovene
gives 3,200 Isogen and 200 Zydrine, Talassonite 960 Nocxium and 32 Megacyte, and Bezdnacine's exact
split could not be verified. The **Sovereignty Hub** ores added by Equinox — Mordunium, Griemeer,
Kylixium, Nocxite, Hezorime and Ueganite — spawn only where a null-sec owner has built the matching
Prospecting Array, so a region's ore is now a political choice. **Border rare** asteroids
(Ducinium, Eifyrium, Ytirium) appear on the high-to-low and null-to-wormhole borders and respawn
instantly.

Catalyst renamed every ore grade. The old Concentrated, Dense and Stable variants became
**II-Grade (+5%)**, **III-Grade (+10%)** and **IV-Grade (+15%)** mineral output; Mercoxit and the
Pochven ores have no IV-Grade.

**Prismaticite** (Catalyst, 40 m³) is the most unusual ore in the game: it reprocesses into **one
random mineral of the eight**, in a variable quantity. It spawns in Phased Asteroid Fields that last
about 40 hours, where the asteroids mine at 10% efficiency until a Mobile Phase Anchor is deployed
within 50 km and charged — 100 energy from a Rorqual, 50 from an Orca, 35 from a Porpoise. A beacon
makes the field visible to everyone about 20 hours after it is scanned, and the two richest rocks
only activate after that, which makes contesting it the point. The randomness can be removed by
researching an Unrefined Mineral Reaction, so industry is the control knob on an RNG ore.

### The 2026 additions

**Cradle of War** (9 June 2026), the first of three "Theatres of War" expansions, tied mining to
Faction Warfare for the first time. Each empire's high-security **Bulwark** systems — the ones
bordering a warzone during a Military Campaign — gained temporary mining anomalies with ores of
their own: the Imperial Raspite Reserve for Amarr and the State Polycrase Reserve for Caldari. The
new ores reprocess much like Scordite but also yield **crystalline faction minerals**, which are
turned in to item traders outside each faction's Navy Anchorage for boosters, faction modules and
cosmetic components, and only while the campaign runs. A world-map filter finds the sites.

The same expansion made two quieter changes that matter more to the feel of mining than to its
economics: **asteroids in most sites were moved closer together and closer to the warp-in point**,
and wormhole ore anomalies got a balance pass. It also added **Exordium**, a PvP-free starter
region where ore yield, payouts and market activity are all deliberately reduced, with higher taxes
and industry costs — a training wheel rather than a place to work.

**Fractured Skies**, the second of the three, is announced for **10 November 2026**, eight days after
this was written, with its full notes due on the 6th. Its headline content is Faction Warfare
Military Campaigns, four navy attack battlecruisers sold through loyalty-point stores, nine
Synchronizer rig sets, thirteen free pre-fitted starter ships in Exordium, and the first opt-in phase
of a redesigned heads-up display. The **Conquest** system it sets up does not arrive until February
2027. Nothing in the announcement touches mining or industry directly, but anything below dated
later than 2 November 2026 should be re-checked against the expansion notes.

### Where rocks come from, and whether they return

| Source | Behaviour | Respawn |
| --- | --- | --- |
| Static asteroid belts | In every system, visible without scanning, finite | Refill at daily downtime once empty |
| Ore anomalies | Scanned; sized small to colossal; vanish when cleared | Sovereignty arrays: tier 1 one hour, tier 2 4h20m, tier 3 ten hours. Mercoxit eight to twelve hours |
| Mining escalations | Chance follow-on sites | Interstitial Ore Deposit never respawns and despawns after six hours, at 8.5M m³ since Catalyst; Veiled Asteroid Field 24 hours |
| Phased Asteroid Fields | Probe-scanned, low and null | About 40 hours |
| Border rare asteroids | Region borders, A0 stars | Instant |
| Ice belts | One to three per system, position moves each time | Six hours; the timer pauses through downtime, so there is always ice after it |

### Ice and gas

Every ice block is **1,000 m³ with a portion size of 1** — one block per harvester cycle — so ice
mining is purely a race on cycle time, with no yield bonuses to stack.

| Ice | Security | Heavy Water | Liquid Ozone | Strontium | Isotopes |
| --- | --- | ---: | ---: | ---: | --- |
| Blue Ice (Gallente) | High-sec faction space | 69 | 35 | 1 | 414 Oxygen |
| Clear Icicle, White Glaze, Glacial Mass | High-sec faction space | low | low | low | **high**, faction-specific |
| Enriched faction ices | Null-sec matching space | more | more | more | more |
| Glare Crust | ≤0.4 | high | high | high | **none** |
| **Dark Glitter** | ≤0.1 | **691** | **1,381** | 69 | none |
| Gelidus, Krystallos | ≤0.0 | high | high | high | none |

The split is the whole point. High-security ice gives **isotopes**, which become the fuel blocks that
keep every player structure running; the dangerous ices give far more **Heavy Water, Liquid Ozone and
Strontium** — reactor inputs, jump fuel, and the strontium that puts a structure into reinforcement.
So the fuel economy of the entire game is split across the security bands exactly as the minerals
are.

Gas is "huffed" with scoops and harvesters. Mykoserocin feeds synthetic boosters and neurolink
components; Cytoserocin feeds the serious combat boosters and sits in clouds that **damage your ship
on each completed cycle**; fullerites exist only in wormhole space and feed tech 3. Catalyst halved
harvester cycle times, leaving throughput unchanged.

| Module | Cycle | Yield | m³/min |
| --- | ---: | ---: | ---: |
| Gas Cloud Scoop I | 30s | 10 | 20 |
| Gas Cloud Scoop II | 40s | 20 | 30 |
| Syndicate Gas Cloud Scoop | 30s | 20 | 40 |
| Gas Cloud Harvester I | 200s | 100 | 30 |
| Gas Cloud Harvester II / ORE | 160s | 200 | 75 |

### Moon mining

A refinery anchored within 250 km of a moon beacon in **0.4 security or lower** can fit a Standup
Moon Drill. Extraction runs **6 to 56 days at 30,000 m³ an hour**, and the resulting chunk is
detonated into a temporary asteroid field — manually, or automatically after about three hours.

| Tier | Ores | Yield per 1,000 m³ | Space |
| --- | --- | --- | --- |
| R4 Ubiquitous | Bitumens, Coesite, Sylvite, Zeolites | 65 of one basic material, plus 2,000–8,000 Pyerite and 400 Mexallon | High, low, null, wormhole |
| R8 Common | Cobaltite, Euxenite, Scheelite, Titanite | 40 Cobalt / Scandium / Tungsten / Titanium | Low, null |
| R16 Uncommon | Chromite, Otavite, Sperrylite, Vanadinite | 40 of one metal plus 10 of an R4 | Low, null |
| R32 Rare | Carnotite, Cinnabar, Pollucite, Zircon | 50 of one, plus 10 R8 and 15 R4 | Low, null |
| R64 Exceptional | Loparite, Monazite, Xenotime, Ytterbite | 22 of one, plus 10 R16, 20 R8 and 20 R4 | Low, null |

Improved ores give 15% more and "excellent" ores twice as much; a **jackpot**, signalled by a blue
flash on detonation, makes every ore in that pull excellent. The **Metenox Moon Drill** added by
Equinox is the passive alternative — it harvests automatically at **40% of manual efficiency** in
exchange for fuel blocks and Magmatic Gas, has a million points of shield and armour, and does not
repair itself.

### The ships

| Ship | Class | Hold | Role |
| --- | --- | --- | --- |
| Venture | Mining frigate, free to new players | 5,000 m³ | Role bonus doubles mining and gas yield |
| Prospect | Expedition frigate | – | Covert ops cloak; wormhole and low-sec huffing |
| Endurance | Expedition frigate | – | Ice specialist |
| **Pioneer** | Mining destroyer, new in Catalyst | larger than a Venture | +10% yield and +20% range per level, +50% yield role bonus |
| Outrider | ORE command destroyer, new in Catalyst | – | Command bursts for small fleets; cannot compress |
| Procurer, Retriever, Covetor | Mining barges, 15–40M ISK | Covetor 9,000 m³ | Tank, hold, yield respectively |
| Skiff, Mackinaw, Hulk | Exhumers, tech 2 | Hulk 11,500 m³ | The same three-way split, higher numbers |
| Porpoise | Industrial command cruiser | – | Drone yield bonuses; medium compressor |
| Orca | Industrial command ship | 30,000 m³ | Large compressor; may enter high-sec |
| Rorqual | Capital industrial | **300,000 m³** mining hold | Excavator drones, capital compressor, strongest foreman bursts; barred from high-sec |

### Lasers, crystals and crits

Catalyst cut ore mining-laser and strip-miner cycle times to a quarter of their old values and
scaled per-cycle yield down to match — the same ore per hour, four times the feedback.

| Module | Cycle | m³/cycle | m³/min | Range | Residue |
| --- | ---: | ---: | ---: | ---: | ---: |
| Miner I | 15s | 10 | 40 | 10 km | 0% |
| Miner II | 15s | 15 | 60 | 12 km | 0% |
| Strip Miner I | 45s | 150 | 200 | 15 km | 0% |
| Modulated Strip Miner II | 45s | 120 | 160 | 15 km | 34% |
| …with a tech 2 Type A crystal | 45s | 216 | 288 | 15 km | 34% |
| ORE Strip Miner | 45s | 200 | 266 | 18.75 km | 0% |
| ORE Deep Core Strip Miner | 45s | 133 | 177 | – | 0% on Mercoxit |
| Ice Harvester II / ORE | 200s | 1,000 | 300 | 10 km | 34% |
| Excavator Mining Drone | 60s | 80 | 80 each | – | 60% |

**Mining crystals** work only in modulated modules. Type A trades nothing for yield, Type B buys
cycle time at the cost of residue, and **Type C is a denial weapon** — near-zero yield and huge
residue, fitted to burn a rival's asteroid rather than mine it.

| Crystal | Yield × | Cycle × | Residue chance | Residue size |
| --- | ---: | ---: | ---: | ---: |
| A, tech 1 | 1.5 | 1.0 | +0% | – |
| A, tech 2 | 1.8 | 1.0 | +3.6% | – |
| B, tech 1 | 1.5 | 0.9 | +20% | – |
| B, tech 2 | 1.8 | 0.8 | +30% | – |
| C, tech 1 | 0.25 | 1.0 | +40% | +18% |
| C, tech 2 | 0.2 | 1.0 | +59% | +28% |

**Mining residue**, added in December 2021, rolls after each cycle to destroy *extra* ore inside the
asteroid. Your own yield per minute is untouched; the rock simply runs out faster. It was launched
with tech 1 modules at 100% residue, which CCP cut to zero after the reaction, and it remains the
least popular mechanic in mining. Mining Survey Chipsets reduce it by up to 20%.

**Critical mining hits**, added by Catalyst, are the counterweight and the best thing to happen to
mining in years: a base **1% chance per cycle of 200% bonus yield**, announced with its own sound
and flash, and **the crit does not deplete the asteroid**. Two new skills, a chipset, a foreman
burst and the new Consortium Issue hulls raise the chance to roughly 30–50%. Catalyst also replaced
yield truncation with stochastic rounding, so observed yields now converge on the module's expected
value instead of always rounding down.

### Yields and tracking

| Stack | Figure |
| --- | --- |
| Venture | about 250 m³/min; a full hold in 20 minutes |
| Mining barge | more than twice a Venture |
| Hulk | about 1,600 m³/min, or 96,000 m³ an hour gross; a full hold in **seven minutes** |
| Orca boost stack | up to −46.5% cycle time, about +87% yield |
| Rorqual boost stack | up to −61.5% cycle time, about +160% yield |
| Rorqual's own drones | 400 m³/min base from five Excavators, before three multiplicative bonus lines |

The seven-minute Hulk is the number that explains the rest of the career: without compression and a
boosting Orca to hold the ore, mining is a station run every few minutes.

The **Mining Ledger** records 90 days of personal extraction, graphable by quantity, volume or
estimated market value, and a corporation ledger covers moon-belt mining at corporate refineries,
which is what moon payouts and taxes are calculated from. Catalyst added a **Mining Surveyor** to
every ORE hull and every empire corvette, colour-coding asteroids by value in space, with a
hold-capacity indicator, a depletion estimate on warp-in and fleet-wide sharing of surveyor data
through foreman bursts.

[EVE University: Asteroids and ore](https://wiki.eveuniversity.org/Asteroids_and_ore), [Mining](https://wiki.eveuniversity.org/Mining), [Mining crystals](https://wiki.eveuniversity.org/Mining_crystals), [Ice harvesting](https://wiki.eveuniversity.org/Ice_harvesting), [Gas cloud harvesting](https://wiki.eveuniversity.org/Gas_cloud_harvesting), [Moon mining](https://wiki.eveuniversity.org/Moon_mining), [CCP: Catalyst expansion notes](https://www.eveonline.com/news/view/catalyst-expansion-notes), [CCP: Mining in Focus](https://www.eveonline.com/news/view/mining-in-focus-new-ore-and-more), [CCP: Resource Distribution Update](https://www.eveonline.com/news/view/resource-distribution-update), [CCP: Introduction to Mining](https://support.eveonline.com/hc/en-us/articles/23655785488668-Introduction-to-Mining), [CCP: Introducing the Mining Ledger](https://www.eveonline.com/article/introducing-the-mining-ledger-new-tools-for-miners-in-eve-online), [CCP: Cradle of War expansion notes](https://www.eveonline.com/news/view/cradle-of-war-expansion-notes), [CCP: Fractured Skies arrives 10 Nov](https://www.eveonline.com/news/view/fractured-skies-expansion-arrives-10-nov), EVE Ref type pages for [Veldspar](https://everef.net/types/1230), [Mercoxit](https://everef.net/types/11396), [Miner I](https://everef.net/types/483) and [ORE Strip Miner](https://everef.net/types/28754)

## Reprocessing and minerals

Ore is worthless until it is reprocessed into minerals, and **perfect reprocessing is impossible**.
The yield is a chain of multipliers on a base rate, which is why where you refine matters as much as
what you mined.

At an NPC station:

```
yield = base (30–50%) × (1 + 0.03 × Reprocessing)
                      × (1 + 0.02 × Reprocessing Efficiency)
                      × (1 + 0.02 × ore-specific skill)
                      × (1 + implant)
```

At a player-owned structure the base becomes `(50 + rig) × (1 + security) × (1 + structure)`.

| Term | Values |
| --- | --- |
| Base rate | NPC station 30–50%; Citadel or Engineering Complex 50%; **Athanor 51%**; **Tatara 52%** |
| Reprocessing rig | none, +1 for tech 1, +3 for tech 2 |
| Security modifier | high-sec 0, **low-sec +6%**, **null and wormhole +12%** — but only if rigs are fitted |
| Structure modifier | other Upwell 0, Athanor +2%, **Tatara +5.5%** |
| Reprocessing skill | +3% per level, +15% at V |
| Reprocessing Efficiency | +2% per level, +10% at V |
| Ore-specific skill, sixteen of them | +2% per level, +10% at V |
| Zainou 'Beancounter' implants | +1%, +2% or **+4%** |

Three reference points. All five skills at V in a 50% NPC station gives **69.6%**. A month-old
character gets 63–65%. The ceiling in the game is a **tech 2 rigged Tatara in null-sec with the best
implant, at 90.6%**.

Reprocessing modules and ships — "scrapmetal" — is a separate and much worse track, capped at
**55%** and immune to implants. Standings affect only the station's tax, not the yield; NPC tax
starts at 5% and reaches zero at 6.67 standing.

### The eight minerals

| Mineral | Main sources | Intended home |
| --- | --- | --- |
| Tritanium | Veldspar at 40 units per m³, Spodumain, Pochven ores | **High-sec** |
| Pyerite | Scordite, Hedbergite, Arkonor and Bistot, Mordunium | High and low |
| Mexallon | Crokite, Gneiss, Dark Ochre, Kylixium | Low |
| Isogen | Hemorphite, Kernite, Dark Ochre, Omber, Ytirium | **Low-sec** |
| Nocxium | Hedbergite, Crokite, Dark Ochre, Jaspet, Nocxite | **Low-sec** |
| Zydrine | Bistot, Eifyrium, Hezorime, Rakovene | **Null-sec** |
| Megacyte | Arkonor, Ducinium, Ueganite, Talassonite | **Null-sec** |
| Morphite | Mercoxit, and nothing else | **Null-sec** |

That last column is deliberate. The **Resource Redistribution** of 2020–22 made each security band
the monopoly supplier of specific minerals in order to force hauling and trade between them. It
removed every ore anomaly from high-security space, cut null-sec Mercoxit by 90%, Bistot by 70% and
Arkonor by 50%, and raised low-sec Crokite anomalies by 9,900%. CCP framed the whole programme as
moving the game "from extraction to production". Catalyst partly reversed the high-sec cut by
returning Omber and Kernite anomalies.

### Compression

Compression is what makes any of it haulable.

| Material | Ratio |
| --- | --- |
| Asteroid ore, moon ore, Mercoxit | **100 to 1** by volume, yield unchanged |
| Ice and gas | 10 to 1 |

It is free, untaxable and unlimited, and happens at a structure with a reprocessing service or
aboard a Porpoise, Orca or Rorqual with a compressor running. Catalyst added a single keybind that
compresses all ore, ice and gas at once. A Hulk's 11,500 m³ hold carries 115,000 units of Veldspar
loose and about 1.15 million compressed — the difference between a station run every seven minutes
and a fleet that mines for an evening.

### Moon materials and reactions

Moon ore reprocesses into raw moon materials, which are then combined in reactions at a refinery in
**0.4 security or lower**. The chain behind an ordinary tech 2 module is four player-run stages
deep: moon drill, reprocess, intermediate reaction, composite reaction, and then manufacturing.

| Reactor | Typical recipe | Feeds |
| --- | --- | --- |
| Composite | 100 + 100 + 5 fuel blocks → 200 intermediate; or → 10,000 Titanium Carbide, 1,500 Nanotransistors, 400 Ferrogel, 200 Fermionic Condensates | **All tech 2 manufacturing** |
| Hybrid | 100 of each fullerite + fuel + minerals → hybrid polymers, about 40% of input volume | **Tech 3** |
| Biochemical | 20 gas + 20 water + fuel → 15 pure standard booster material | Boosters |

[EVE University: Reprocessing](https://wiki.eveuniversity.org/Reprocessing), [Minerals](https://wiki.eveuniversity.org/Minerals), [Compression](https://wiki.eveuniversity.org/Compression), [Reactions](https://wiki.eveuniversity.org/Reactions), [CCP: Resource Distribution Update](https://www.eveonline.com/news/view/resource-distribution-update), [CCP: From Extraction to Production](https://www.eveonline.com/news/view/from-extraction-to-production)

## Blueprints

Nothing is built in EVE without a blueprint, and the blueprint economy is a career in itself.

| | Original (BPO) | Copy (BPC) |
| --- | --- | --- |
| Source | **Seeded on the NPC market** for tech 1 items — recognisable by an order duration over 300 days — or bought from players | Copying an original; loyalty-point stores; exploration data sites; invention; reverse engineering |
| Runs | Infinite | Finite, and the copy vanishes when exhausted. Ship copies cap at 10 runs, most modules and ammunition at 600 |
| Research | Yes, material and time efficiency | **No.** A copy inherits whatever the original had when it was copied |
| Trading | Market or contract | **Contracts only** — copies cannot be listed on the market |
| Tech 2 | Originals exist but are rare legacy items | Come from invention, and are manufacture-only: they cannot be researched or copied again |

### Research, and the 790-day problem

- **Material efficiency** has ten levels, each cutting material use by 1%, capped at **−10%**.
- **Time efficiency** has ten research steps, each cutting build time by 2%, capped at **−20%**. The
  label counts 0 to 20 in twos, but there are only ten jobs.
- Each level costs roughly **2.4 times** the previous one. The per-step base durations for a rank-1
  blueprint run 105s, 250s, 595s, 1,414s, 3,360s, 8,000s, 19,000s, 45,255s, 107,700s and
  **256,000s**, multiplied by the blueprint's rank — which ranges from 1 for small ammunition to
  4,000 for a jump freighter.

| Blueprint | To ME1 | To ME5 | To **ME10** | Copy time |
| --- | ---: | ---: | ---: | ---: |
| Coercer, a tech 1 destroyer | 52m 30s | 1d 4h | **88d 21h** | 2h |
| Naglfar, a dreadnought | 7h 47m | – | **790d 3h** | 18d 12h |

This is the hardest pacing gate in EVE. A fully researched capital original is a multi-year asset,
which is exactly why there is a resale market in them, and skills and structure bonuses exist to
make the numbers tractable rather than merely long.

Copy time per run is **80% of build time**, and time efficiency does not reduce it.

| Skill | Effect |
| --- | --- |
| Science | −5% copy time per level |
| Metallurgy | −5% material-efficiency research time per level |
| Research | −5% time-efficiency research time per level |
| Advanced Industry | −3% manufacturing **and** research time per level |
| Laboratory Operation, then Advanced | +1 concurrent science job per level, to **11** |
| Scientific Networking | +5 jumps of remote job range per level, 25 at V |

### Invention

Invention turns a tech 1 **copy** into a tech 2 copy. It consumes one run of the copy, two kinds of
datacore, and optionally a decryptor — all of them whether it succeeds or fails.

| Item class | Base chance |
| --- | ---: |
| Modules, rigs, ammunition | 34% |
| Frigates, destroyers | 30% |
| Cruisers, battlecruisers, barges, haulers | 26% |
| Battleships | 22% |
| Freighters | 18% |
| Wrecked relics | 14% |

```
chance = base × (1 + (science1 + science2)/30 + encryption/40) × (1 + decryptor/100)
```

Decryptors then trade probability against the output copy's runs and efficiency — Attainment adds
80% probability but costs material efficiency, Augmentation cuts probability by 40% for nine extra
runs. A successful invention usually yields a **10-run copy at ME2 and TE4**; ships and rigs yield
a single run.

### The tiers

| Tier | Where the blueprint comes from | Research |
| --- | --- | --- |
| Tech 1 | NPC market original | ME10 / TE20 |
| Tech 2 | **Invention**, as a limited-run copy | None possible |
| Tech 3 | **Reverse engineering** of Sleeper relics from wormhole space | None |
| Faction and navy | Loyalty-point store copies, and rare drops | None |
| Capital and supercapital | NPC market original, researched like tech 1, and gated behind Capital Ship Construction | ME10, at 790 days base |

[EVE University: Blueprints](https://wiki.eveuniversity.org/Blueprints), [Research](https://wiki.eveuniversity.org/Research), [Invention](https://wiki.eveuniversity.org/Invention), EVE Ref: [Coercer Blueprint](https://everef.net/type/16237), [Naglfar Blueprint](https://everef.net/type/19723)

## Industry and manufacturing

A manufacturing job consumes materials, a blueprint, a fee and time. Where it runs changes all four.

| Facility | Material bonus | Time bonus | Fee bonus | Slots |
| --- | ---: | ---: | ---: | ---: |
| NPC station | – | – | – (0.25% tax) | n/a |
| Raitaru, medium Engineering Complex | 1% | **15%** | 3% | 3 |
| Azbel, large | 1% | **20%** | 4% | 5 |
| Sotiyo, extra large | 1% | **30%** | 5% | 6 |
| Athanor, medium Refinery | – | – | – | 3 |
| Tatara, large Refinery | – | **25% on reactions** | – | 5 |

Rigs raise those further for particular item categories. Carriers, dreadnoughts and Rorquals cannot
be built in high-security space at all; supercapitals need a Sotiyo with a sovereignty upgrade.

### Slots and time

| Skill | Effect |
| --- | --- |
| None | **one** manufacturing job |
| Mass Production | +1 per level, to 6 |
| Advanced Mass Production | +1 per level, to **11** |
| Industry | **−4% manufacturing time per level** |
| Advanced Industry | **−3% manufacturing and research time per level** |
| Supply Chain Management | remote installation, +5 jumps per level, 25 at V |

Stacked up — time efficiency at −20%, Industry V at −20%, Advanced Industry V at −15% and a
structure at −15 to −30% — a job runs at roughly **40–45% of its base duration**.

### What a job costs

```
cost = estimated item value × ((system cost index × structure bonus)
                               + facility tax + 4% SCC surcharge + alpha tax)

estimated item value = Σ (material quantity × adjusted price), at ME0 with no bonuses
system cost index    = this system's production work-hours over 28 days
                       ÷ the whole universe's over 28 days
```

The index is **self-balancing**: crowding a system raises everyone's fees there and pushes
production outward. In practice most of New Eden sits at a floor of about 0.14%, so the flat
**4% surcharge usually dominates**, and the industry service tax a structure owner may charge is
capped at 10%.

Materials are the overwhelming share of a tech 1 build, which is why the −10% from material
efficiency is the headline number. Requirements are `base × (1 − 0.01 × ME)`, **rounded up after
multiplying by the run count**, with a floor of one unit per material per run — so batching runs is
not a convenience but a real saving.

### What real things consume

| Item | Build time | Materials |
| --- | ---: | --- |
| Cap Recharger I, a small module | **30 min** | 763 Tritanium, 321 Pyerite, 412 Mexallon, 2 Megacyte |
| Infiltrator I, a light drone | 10 min | 3,133 Tritanium |
| Coercer, a tech 1 destroyer | **2h 30m** | 80,000 Tritanium, 15,000 Pyerite, 5,000 Mexallon, 1,000 Isogen |
| Tempest Fleet Issue, a faction battleship | 5h | minerals plus faction components |
| Capital Construction Parts | 4h 27m | – |
| Naglfar, a dreadnought | **23d 3h** | 15 Capital Turret Hardpoints, 15 Capital Siege Arrays, 400 Auto-Integrity Preservation Seals and thirteen other capital component types |

The dreadnought's 23 days are for the hull alone, on top of building nineteen component types in
their own jobs. With full skills and a Sotiyo that collapses to nine or ten days — still a
fortnight-scale project in real time. Titans are reported at seven to eight weeks excluding
components, though no current source confirms the figure. Catalyst cut carrier build costs by about
30% and build times by about 10%.

[EVE University: Manufacturing](https://wiki.eveuniversity.org/Manufacturing), [Industry](https://wiki.eveuniversity.org/Industry), [Upwell structures](https://wiki.eveuniversity.org/Upwell_structures), [EO-Map industry cost index](https://eo-map.com/industry-cost-index/), [EVE Ref industry cost API](https://docs.everef.net/api/industry-cost.html), EVE Ref: [Cap Recharger I Blueprint](https://everef.net/types/1196)

## Planetary industry and reactions

### Planetary industry

A **colony** on a planet extracts raw material from its surface and processes it up a four-tier
chain. The planet types — barren, temperate, lava, ice, gas, storm, plasma and oceanic — each carry
five of the fifteen raw resources, so **no single planet can feed a whole chain** and a product
needs a spread of worlds.

| Structure | Function | Throughput |
| --- | --- | --- |
| **Command Center** | The colony anchor, providing the CPU and powergrid budget everything else spends | One type per planet class |
| Extractor Control Unit | Places heads on surface hotspots and runs timed programmes | Up to **ten heads** |
| Basic Industry Facility | Raw → P1 | **3,000 raw → 20 P1** per 30 minutes |
| Advanced Industry Facility | P1 → P2 → P3 | **80 P1 → 5 P2**, then 20–30 P2 → 3 P3, hourly |
| High-Tech Production Plant | P3 → P4 | **18 P3 → 1 P4**, barren and temperate planets only |
| Launchpad | Bulk export, and the **only** way to import onto a planet | About 3,600 CPU — a large share of the budget |
| Links | Connect structures, with cost scaling by length and bandwidth | – |

The real content is the **routing**: a colony is a flow network optimised under a hard CPU and
powergrid budget, and laying one out well is a planning puzzle rather than an activity.

The value escalation up the chain is extraordinary, and the export tax table is the clearest
statement of it:

| Tier | Base value per unit |
| --- | ---: |
| Raw | **5 ISK** |
| P1 | 400 |
| P2 | 7,200 |
| P3 | 60,000 |
| **P4** | **1,200,000 ISK** |

That is a factor of **240,000** from raw material to finished advanced commodity — and the five P4
goods feed structure and capital construction, which is why planetary industry is not a sideshow.

### Equinox, and planets as territory

Equinox in June 2024 tied planets to sovereignty. **Orbital Skyhooks** replaced customs offices,
harvest planetary resources automatically, and can be destroyed or **hacked** by other players. The
resources they pull — **power** from suns and gas giants, **workforce** from habitable worlds, and
**reagents** in the form of superionic ice and magmatic gas — are what a Sovereignty Hub spends to
run its upgrades. Planets stopped being scenery and became the supply line for holding space.

### Reactions

Reactions run in a refinery in **0.4 security or lower**, and they are the stage between moon mining
and tech 2 manufacturing.

| Reactor | Recipe | Feeds |
| --- | --- | --- |
| Composite | 100 + 100 + 5 fuel blocks → an intermediate, then intermediates → composites | **All tech 2 manufacturing** |
| Hybrid | Fullerites plus minerals → hybrid polymers, about 40% of input volume | **Tech 3** |
| Biochemical | Gas + water + fuel → pure booster material | Boosters |

### Boosters

Boosters are the only consumable in EVE that trades a benefit for a **randomised drawback**, and the
structure of that trade is worth copying.

| Tier | Benefit | Side-effect chance | Legality |
| --- | --- | ---: | --- |
| **Synth** | small | **none** | **Legal everywhere** |
| Standard | larger | 20% | Contraband |
| Improved | larger still | 30% | Contraband |
| **Strong** | largest | **40%** | Contraband |

Each booster has four possible side effects, and **each rolls independently**, so a strong booster
can land you anything from a clean run to four simultaneous penalties. Two skills exist purely to
manage that risk — one cuts the chance of a side effect, the other its severity — and a third sets
duration and gates the tiers. The whole design is a legible risk ladder: more power, more chance of
harm, and illegality that rises with both.

[EVE University: Planetary Industry](https://wiki.eveuniversity.org/Planetary_Interaction), [Reactions](https://wiki.eveuniversity.org/Reactions), [Medical boosters](https://wiki.eveuniversity.org/Medical_boosters), [CCP: Equinox expansion notes](https://eveonline.com/news/view/equinox-expansion-notes)

## The economy

EVE's economy is the game. Almost everything in it was built by a player from materials another
player dug up, and almost all of it will be destroyed. The studio has employed economists to watch
it since 2007 and publishes the figures monthly.

### The market is regional, and there is no global price

Each of roughly a hundred regions has **its own market**. An order sits at one station or structure
but is visible across the whole region; the buyer must travel to the seller's station to collect,
and nothing moves goods automatically. That single decision is the foundation of hauling, regional
arbitrage and most of the game's logistics as professions.

Formally the market is a list of standing buy orders, with the ISK held in escrow, and sell orders,
with the goods held at the station. The one exception is **PLEX**, which trades on a single global
market shared by every station.

| Fee or limit | Value |
| --- | --- |
| Sales tax | **7.5%** of the sale, raised from 4% in March 2025; `7.5% × (1 − 0.11 × Accounting)`, so about **3.4%** at Accounting V |
| Broker's fee, NPC station | `3% − 0.3% per Broker Relations level − standings`, with a **1% floor**. Charged on placing any order, and not refunded if it is cancelled |
| Broker's fee, player structure | **0.5% plus whatever the owner sets**, which may be zero. Skills and standings do not apply |
| Order duration | Up to **90 days**; "immediate" pays no broker fee but only fills against existing orders |
| Simultaneous orders | **5** untrained, **305** with all four order skills at V |

| Skill | Effect |
| --- | --- |
| Trade, Retail, Wholesale, Tycoon | +4, +8, +16, +32 maximum orders per level |
| **Accounting** | −11% sales tax per level |
| **Broker Relations** | −0.3 points of broker fee per level, at NPC stations only |
| Marketing, Procurement, Daytrading | Place sell orders, place buy orders, and manage orders remotely |
| **Visibility** | Buy-order range: station, system, 5 jumps, 10, 20, then the whole region |
| Margin Trading | Reduces the escrow a buy order needs — the classic set-up for a deliberate default |

The skills are carefully chosen: they extend the *reach of your orders* and never move goods. Someone
still has to fly the freighter.

### Hub concentration

**Jita IV – Moon 4**, in Caldari high-security space, is the capital market of New Eden by an order
of magnitude.

| Hub | Region | Value of market offers |
| --- | --- | ---: |
| **Jita** | The Forge | about **687 trillion ISK** |
| Amarr | Domain | about 54T |
| Dodixie | Sinq Laison | about 17T |
| Hek | Metropolis | about 10T |
| Rens | Heimatar | about 8T |

Those are February 2025 figures and are directionally rather than currently right. The concentration
is a feedback loop: depth attracts buyers, buyers attract sellers, spreads tighten, and buyers will
pay a premium to get everything in one trip rather than hunt six regions. Reputation then locks it
in. Jita is one jump from Perimeter, where player-owned structures undercut the NPC station's broker
fee, so the hub has spilled across two systems. Fractured Skies will try to counterweight it by
halving taxes and broker fees at Amarr for six months — an explicit experiment in de-concentration.

### Contracts

Contracts cover everything the market cannot express, and some things only they can carry.

| Type | What it does |
| --- | --- |
| **Item exchange** | Items and ISK for items and ISK, public or private. It can demand items *from* the acceptor |
| **Courier** | Pay someone to move a sealed package. Carries a **reward** to the hauler and **collateral** the hauler must escrow |
| **Auction** | Open bidding with an optional buyout |

**Collateral is the trust primitive.** The hauler posts it on accepting; if the package is opened,
destroyed or delivered late, the contract fails and the issuer keeps the collateral. The convention
is to set it slightly above the cargo's value, which makes it a scam vector in both directions —
inflated collateral plus a gank on the route, or lowball collateral and simply keep the cargo.

Blueprint copies, assembled ships and ships with cargo **have no market type at all** and can only
change hands by contract. That is why the entire blueprint-copy economy is contract-based.

### Hauling

With no global market and no NPC freight, logistics is an industry.

| Class | Examples | Cargo |
| --- | --- | ---: |
| Tech 1 industrials | Bestower, Tayra, Mammoth, Iteron V | 500–7,300 m³, more with specialised holds |
| Blockade runners | Prorator, Viator, Crane, Prowler | ~10,000 m³ fitted, and they cloak |
| Deep space transports | Impel, Occator, Mastodon, Bustard | 3,100–5,000 m³ plus a 50,000 m³ fleet hangar |
| **Freighters** | Fenrir and Providence 435,000 · Obelisk 440,000 · **Charon 465,000 m³** | Cannot be fitted for defence; a Charon reaches about 1.2M m³ with expanders |
| **Jump freighters** | Nomad 132,000 · Ark 135,000 · Anshar 137,500 · **Rhea 144,000 m³** | 5 ly base jump range, 9–10 skilled, burning liquid ozone |

Because freighters are slow, uncloakable and cannot shoot back, a mature service industry exists —
Red Frog Freight and others quote high-security work as a flat rate per jump regardless of volume,
and jump-freighter work per cubic metre per light year, with a surcharge for anything bound for
Jita because of the gank risk.

**Suicide ganking** is a sanctioned profession. Attack a hauler in high-security space without legal
cause, accept that CONCORD will certainly destroy your ship, and profit if the cargo is worth more
than your fleet. Scouts scan cargo at the gates into Jita and call targets to a waiting fleet.
Insurance covers **the hull only, at its mineral value** — never modules, rigs or cargo — so faction
and tech 2 hulls insure badly and the loss is real.

The **Force Projection revamp** of September 2026 reshaped alliance logistics by putting Ansiblex
jump bridges on a slowly recharging capacitor that each transiting ship drains, with the cost
scaling by the destination's distance from the owner's capital system — cheap inward, expensive
outward. Bridges became owning-alliance-only, and the studio said explicitly that it was moving
*away* from jump fatigue as the throttle.

### Faucets, sinks and the Monthly Economic Report

ISK is created by NPC bounties — historically the largest faucet — mission and Faction Warfare
rewards, incursion payouts, commodities sold to NPC buy orders, and insurance. It is destroyed by
broker fees and sales tax, industry job fees that scale with the system cost index, reprocessing
fees, NPC-sold skill books and blueprints, the ISK half of every loyalty-point purchase, insurance
premiums, clone and office fees, and alliance maintenance bills. Structure **fuel blocks are
player-manufactured**, so fuel is a materials sink rather than an ISK sink — a distinction commonly
got wrong.

The **Monthly Economic Report** publishes about twenty-three charts plus a downloadable raw-data
archive: sinks and faucets, money supply, money velocity, active ISK delta, the mineral and module
price indices, and the value of production, destruction, mining and trade, broken down by region.

| Report | What it said |
| --- | --- |
| February 2026 | Destruction up, mining and production down. **Mineral price index down about 52% year on year.** Velocity still falling |
| March 2026 | Total faucets up 17% on the month |
| April 2026 | Faucets back to February levels; large battles at Atioth and 4-HWWF |
| May 2026 | Faucets up 26%; mining value stabilises; mineral index up on the month |
| August 2026 | Recovery from the summer slowdown; mineral index still trending down; the largest battle in Pochven, about **9,000 ships destroyed** |
| September 2026 | Active ISK delta swings from +82.2T to **−144.7T**; module index down 4%; mining down again |

### PLEX and loyalty points

**PLEX** is bought with real money or ISK, held in an account-wide vault, and traded on the only
global market in the game. On 2 November 2026 the lowest sell order was **4,990,000 ISK**, and Omega
membership costs 500 PLEX a month — so a month of EVE is about **2.5 billion ISK**, roughly 19%
cheaper in ISK than two years earlier. A player who earns that much a month plays for nothing; a
player with cash can convert money into ISK into ships. This is the studio's sanctioned channel, and
the reason selling ISK for cash outside it is a bannable offence.

**Loyalty points** are a second currency, earned per NPC corporation from missions, Faction Warfare,
incursions and insurgencies, and **non-transferable** — spendable only in that corporation's store,
where almost every offer costs loyalty points *and* ISK *and* sometimes a tech 1 item to trade in.
It lets the studio seed faction hulls and modules into the economy without printing ISK, and gives
territorial control a direct economic payoff. Players monetise it by buying store goods and selling
them on, and the resulting ISK-per-point rate falls as a store saturates, which self-regulates the
farming.

### Theft is allowed, and that is the point

| Event | Year | Scale |
| --- | --- | --- |
| Guiding Hand Social Club heist | 2005 | About 30B ISK, a year of infiltration, a Guinness world record for the largest virtual theft. The target's frozen corpse was delivered to the client |
| Cally's EVE Intergalactic Bank | 2006 | About **790B ISK** taken from depositors in four months |
| Ricdic / EBank | 2009 | About 85B ISK — and he was banned for **selling the proceeds for real cash**, not for the theft |
| Titans4U | 2010 | About 800B ISK |
| Phaser Inc. | 2011 | About **1 trillion ISK**, the largest recorded at the time |
| Cynosural Field Theory | 2014 | About 1.19T ISK |
| **The clash at Atioth** | April 2026 | About **10 trillion ISK destroyed** and a peak of **10,253 pilots in one system**, a new world record beating 6,557 |

Scamming, corporate theft, espionage, betrayal, market manipulation and Ponzi schemes are all
explicitly permitted as emergent play; the studio's own support material defines a scam as robbing
someone "via legal in-game means". The bright line is anything that reaches outside the fiction:
selling ISK for cash outside PLEX, account sharing, phishing, impersonating another character by
name, botting, or exploiting bugs. On Atioth the studio said it would "mostly let the simulation
play out".

### Economists on staff

- **Dr Eyjólfur Guðmundsson** was hired as lead economist in **June 2007**, reported as the first PhD
  economist ever employed to watch an MMO economy. He built the economics team and published the
  **Quarterly Economic Newsletter** from 2007 to 2010, with price indices, trade volumes and
  sink-and-faucet accounting.
- **Stefán Þórarinsson**, a former central-bank economist, was appointed Head of Economy in
  **March 2025**.
- The data is public: the **ESI** API exposes live orders per region and thirteen months of daily
  market history without authentication, along with industry cost indices and kills and jumps per
  system; the static data export covers every type and blueprint; and the monthly report ships its
  raw numbers as an archive. The third-party ecosystem built on this — zKillboard, Dotlan, EVE Ref,
  Adam4EVE, Fuzzwork — is substantially how players actually read the economy.

[EVE University: Market](https://wiki.eveuniversity.org/Market), [Trading](https://wiki.eveuniversity.org/Trading), [Tax](https://wiki.eveuniversity.org/Tax), [Trade hubs](https://wiki.eveuniversity.org/Trade_hubs), [Contracts](https://wiki.eveuniversity.org/Contracts), [Hauling](https://wiki.eveuniversity.org/Hauling), [Suicide ganking](https://wiki.eveuniversity.org/Suicide_ganking), [PLEX](https://wiki.eveuniversity.org/PLEX), [Loyalty Points](https://wiki.eveuniversity.org/Loyalty_Points), [CCP: Monthly Economic Reports](https://www.eveonline.com/news/t/monthly-economic-reports), [CCP: patch notes 22.02](https://www.eveonline.com/news/view/patch-notes-version-22-02), [CCP: Force Projection revamped](https://www.eveonline.com/news/view/major-update-force-projection-revamped), [CCP: Clash at Atioth](https://www.eveonline.com/news/view/clash-at-atioth), [CCP: Team Security rules and policy clarifications](https://www.eveonline.com/news/view/team-security-rules-and-policy-clarifications), [CCP appoints an in-world economist, 2007](https://community.eveonline.com/news/news-channels/press-releases/eve-online-appoints-in-world-economist-1), [Game Developer: CCP appoints Stefán Þórarinsson](https://www.gamedeveloper.com/press-release/ccp-games-appoints-central-bank-economist-stef-n-rarinsson-to-advance-virtual-economies), [Guinness: largest virtual theft](https://www.guinnessworldrecords.com/world-records/92197-largest-virtual-theft-in-an-mmorpg), [EVE Ref market datasets](https://docs.everef.net/datasets/market-orders)

## Corporations, alliances and sovereignty

### Corporations

| Parameter | Value |
| --- | --- |
| Founding cost | **1,599,800 ISK**, and Corporation Management I |
| Other requirements | You must be docked, and hold no roles in another player corporation — roles take **24 hours** to drop |
| Starting shares | 1,000 |
| Corporate tax | **0% to 100%**, applied to members' NPC bounties and mission rewards — **not** to market income |
| Member cap | 101 with Corporation Management V, 601 with Megacorp Management, 2,601 with Empire Control, and **12,601** with the 500M ISK Sovereignty skill, which is the largest a corporation can be |

A corporation has **seven hangar divisions and seven wallet divisions**, and access to each is granted
per division and per location scope. On top of that sit functional roles — Director, Accountant,
Contract Manager, Fitting Manager, Station Manager and a dozen more — which the chief executive and
directors bundle into freely named **titles**.

That matrix is why insider theft is a genuine and celebrated part of EVE. One misassigned
`Account Take` or `Hangar Take` role drains a division, and corporate theft is **never** a support
matter. Alliances consequently run real vetting pipelines with API audits and voice interviews, and
dedicated infiltrators spend months earning a directorship before the heist.

### Alliances and coalitions

| Parameter | Value |
| --- | --- |
| Founding cost | **1,000,000,000 ISK**, and Empire Control V |
| Upkeep | **2,000,000 ISK per member corporation per month**, billed to the executor corporation. Miss it and the alliance **closes at the next downtime** |
| Executor | One corporation, holding the declared support of at least half the member chief executives |

**Coalitions have no game mechanic at all.** They are out-of-game agreements about shared comms,
standings, intelligence tools and jump-bridge access, and nothing in the client knows they exist.
The September 2026 Ansiblex change deliberately weakened them by restricting jump bridges to the
owning alliance.

The famous blocs — Band of Brothers, Goonswarm and the Imperium, Pandemic Legion and Pandemic Horde,
TEST, Northern Coalition., Brave, Fraternity. — churn constantly, and so do their wars: the Great
War of 2007–09, the Halloween War, B-R5RB in 2014, and the two World War Bees. In April 2026 the
Imperium declared on WinterCo, and the opening clash at **Atioth** set a world record of **10,253
pilots in a single system** with about **10 trillion ISK destroyed**, the server node collapsing
minutes before the contested Keepstar came online.

### Sovereignty

Equinox replaced both the Territorial Claim Unit and the Infrastructure Hub with a single
**Sovereignty Hub**. Anchoring one claims the system and hosts every upgrade it runs.

Capture still runs on the **Entosis Link**:

1. A new hub starts neutral and must be claimed, which rivals may contest.
2. Attacking an owned hub means running a link during its vulnerability window. **Multiple links do
   not stack** — more attackers cannot go faster, which is the anti-blob design intent — and if both
   sides run links, progress pauses.
3. Success puts the hub into **reinforcement for about 48 hours**.
4. **Command nodes** then spawn across the constellation. The bar starts at 60% and each captured
   node moves it seven points, so attackers need nine captures and defenders six.
5. An attacker's win destroys the hub and every upgrade on it.

The throttle is the **Activity Defense Multiplier**, capped at 6 and summed from the military,
industrial and strategic indices. It decides two things that matter enormously:

- **Entosis reinforcement time**, 10 minutes at ADM 1 and 60 at ADM 6.
- **The vulnerability window**, which is `18 hours ÷ ADM` — 18 hours of exposure at ADM 1, **three
  hours at ADM 6**. Changes only take effect after the next window, so an inbound attack cannot be
  dodged.

So ratting and mining in your own space literally buy defensive cover, and an alliance's capital
system gets two free points of it.

Equinox then added a resource layer underneath:

| Resource | Source | Behaviour |
| --- | --- | --- |
| **Power** | The system's sun, plus plasma, storm and gas planets | A **hard per-system cap** on how many upgrades a hub can run |
| **Workforce** | Temperate, barren and oceanic planets | A softer limit, and transferable between systems only if one alliance owns every system on the route |
| **Reagents** | Superionic ice and magmatic gas | Harvested automatically, and must be physically carried into the hub to keep some upgrades online |

**Orbital Skyhooks** replaced customs offices as the extraction structure, and they can be destroyed
or **hacked**, which is a content loop in itself; killing one can force upgrades offline. After a
system changes hands the new owner gets a one-hour window to buy out the surviving Skyhooks.
Upgrades cover jump bridges and cyno beacons, guaranteed ore anomalies by mineral, threat detection,
signature detectors, power-to-workforce conversion, and Abyssal-style system-wide ship effects — a
supercapital shipyard costs 1,750 power and 17,500 workforce, which is most of a good system.

### Upwell structures

| Class | Hull | Slots | Docking | Jita price, 1 Nov 2026 |
| --- | --- | ---: | --- | ---: |
| Citadel | **Astrahus** | 3 | Subcapitals | ~0.99B ISK |
| | **Fortizar** | 5 | Capitals | ~10.47B ISK |
| | **Keepstar** | 7 | Supercapitals, and it has a **doomsday weapon** | Built on site; older estimates of 188–300B are dated |
| Engineering Complex | **Raitaru** | 3 | Subcapitals | ~0.59B ISK |
| | **Azbel** | 5 | Capital manufacturing | ~4.39B ISK |
| | **Sotiyo** | 6 | **Supercapital** manufacturing | ~23.7B ISK |
| Refinery | **Athanor** | 3 | Subcapitals | ~0.82B ISK |
| | **Tatara** | 5 | Subcapitals and Rorquals | ~6.75B ISK |

The *Palatine* Keepstar is the game's folk legend: estimated at around a hundred trillion ISK, only
one may ever exist, and none has ever been anchored.

Tethering, hangars, fitting, repair, contracts and offices are always available. **Fuelled service
modules** — the market hub, clone bay, reprocessing plant, research lab, invention, manufacturing,
the capital and supercapital shipyards, the reactors and the moon drill — each burn fuel blocks every
hour, and **onlining one costs three days of fuel up front**. Run dry and jobs pause, the market
stops and clones lock. Fuel blocks are player-manufactured, so upkeep is an industrial commitment
rather than a bill.

Attacking a structure runs through timers the **owner** largely chooses: they set a reinforcement
hour, and the armour and hull fights land within three hours of it. Shields are vulnerable
immediately; losing them starts the armour timer; losing armour puts large and extra-large
structures into structure reinforcement before a final window. Medium structures skip the hull timer
entirely. Unscouted, the full chain runs up to 14 days in high-security space and 9 in wormholes.

The anti-spam mechanism is elegant: a structure that has **burned no fuel for seven days** becomes
*Abandoned*, loses its reinforcement cycles altogether, and can be killed in a single pass.

### War declarations

A corporation is war-eligible **only if it owns a structure in space** — and if any corporation in
an alliance owns one, the whole alliance is eligible. Wars are declared at alliance level by a chief
executive or director, cost about 100M ISK a week, run seven days at a time, and can be surrendered;
defenders may hire allies.

That single gate, added in 2018, ended the era of mass predatory high-security wars against
defenceless new corporations. A group that owns nothing cannot be declared on, so the rule reads:
plant a flag in high-sec and you have accepted war.

### Faction Warfare, and Havoc's pirates

Four empire militias fight over two war zones — 70 systems between Amarr and Minmatar, 101 between
Caldari and Gallente. Enlisted pilots are at war with the opposing militia **everywhere in New
Eden**.

| Step | Numbers |
| --- | --- |
| Run **complexes** behind acceleration gates | Clear enemies within 30 km of the capture point and hold it for 10 or 15 minutes. Timers pause while an enemy is in range, and cloaking is disabled inside the radius |
| Accrue **victory points** | 75 for a small site up to 2,000 for a battlefield; defensive plexing subtracts them |
| System becomes vulnerable | at **75,000 victory points**, exposing the Infrastructure Hub |
| Kill the hub | **25 million hit points** with about 1,700 a second of recharge, so it needs a real fleet |

Two systems make territory compound. **Advantage** modifies victory-point gain — blowing up an enemy
supply cache costs them 2% and pays 15,000 loyalty points to everyone who shot it, and each adjacent
friendly system adds 10%. And the **faction tier**, set by share of the war zone, multiplies
loyalty-point income from **−50% at tier 1 to +225% at tier 5**. Meanwhile frontline systems pay the
most, rearguard systems pay about 99% less, and in enemy command-operations and rearguard systems
**you cannot dock or undock at all** — capsules only. The design pushes everyone to the actual
border.

**Havoc** (November 2023) made the pirates playable. The Angel Cartel and the Guristas can be
enlisted with, and an **insurgency** centres on a hub system with a pirate forward operating base,
opening with a 48-hour forecasting phase that reveals where it will be. Each system then carries two
opposing meters, **Corruption** and **Suppression**, and crossing a threshold advances a stage that
adds roaming NPCs, laundering centres against counter-insurgency outposts, and market and tax
effects. From September 2026 a corrupted system can host a site that grants the equivalent of **an
extra skill level** to pilots inside it.

**Fractured Skies**, announced for 10 November 2026, puts a campaign structure on top: two-month
**Military Campaigns** per empire pair, with four objectives — hacking, killing and *mining* — whose
completion grants system-wide bonuses to warp speed, defences or damage, chosen by the occupying
faction. The first empire to finish all four picks the site of a four-way live event in January and
wins a limited-time module in its store. **Conquests** follow in February 2027, built on Conquest
Engines that can take a whole system and can only be countered by a rival engine.

### The Council of Stellar Management

| Parameter | Value |
| --- | --- |
| Seats | **10** elected players |
| Term | 12 months, with a maximum of three years served and then a year's cooldown |
| Election | **Single transferable vote**, one ballot per paying account, ranked, anonymous |
| **NDA** | Members must sign one, and candidates must supply a **real name and passport or national ID**, in order to be given pre-release access to designs and data |
| Summit | At least one trip to Iceland per term, paid for by the studio |
| Powers | **Advisory only.** It has no formal power, and a voice |

A council member was removed for breaking the non-disclosure agreement around 2020. The CSM 21 cycle
ran from applications in September 2026 through 54 qualified candidates to a ballot that closed on
**3 November 2026**, the day after this was written. The studio credits recent council input on the
Catalyst update, the Cradle of War follow-up and the redesigned heads-up display.

That a commercial studio runs a player election, flies the winners to Iceland and puts them under
NDA is, as far as this reference's author knows, unique in the industry.

[EVE University: Forming a corporation](https://wiki.eveuniversity.org/Forming_a_corporation), [Managing corporation members](https://wiki.eveuniversity.org/Managing_corporation_members), [Alliances](https://wiki.eveuniversity.org/Alliances), [Sovereignty](https://wiki.eveuniversity.org/Sovereignty), [Upwell structures](https://wiki.eveuniversity.org/Upwell_structures), [Vulnerability](https://wiki.eveuniversity.org/Vulnerability), [War Declaration](https://wiki.eveuniversity.org/War_Declaration), [Factional Warfare](https://wiki.eveuniversity.org/Factional_Warfare), [Council of Stellar Management](https://wiki.eveuniversity.org/Council_of_Stellar_Management), [CCP: Equinox in Focus, Reinvigorating Nullsec](https://eveonline.com/news/view/equinox-in-focus-reinvigorating-nullsec), [Equinox expansion notes](https://eveonline.com/news/view/equinox-expansion-notes), [Upwell 2.0](https://www.eveonline.com/news/view/upwell-2.0-structures-changes-coming-on-february-13th), [War Declaration Changes](https://www.eveonline.com/article/pjblu1), [Havoc expansion notes](https://www.eveonline.com/news/view/havoc-expansion-notes), [Fractured Skies In Focus](https://www.eveonline.com/news/view/fractured-skies-in-focus), [CSM 21: Is it Your Time?](https://www.eveonline.com/news/view/csm-21-is-it-your-time)

## Exploration

Exploration is the lowest-capital and highest-variance career in EVE, and the only one built around
a puzzle rather than a fitting.

### Finding things

Two discovery layers coexist. **Cosmic anomalies** are already warpable in the scanner and need no
probes — they are the null-sec ratting and ore feed. **Cosmic signatures** must be probed to 100%
before they can be warped to, and they are the explorer's content.

The progressive reveal is the mechanic: at **25%** signal strength the signature's *type* resolves —
relic, data, gas, wormhole or combat — at **75%** its *name*, and only at **100%** can you warp.
That lets an explorer decide whether a signature is worth finishing before committing to it.

Each scan result carries a **deviation**, a radius of positional error that shrinks as you narrow the
probe formation and train the skills:

```
deviation = base × (scan range / base range) × (1 − 0.05 × Astrometrics) × (1 − 0.05 × Pinpointing)
```

A core probe at a 4 AU spread lands within 1.9 AU at Astrometrics I and 1.5 AU at V, which is why
the standard routine is a wide pass to find the ball, then successive tighter passes to collapse it.

### The hacking minigame

Once at a site, the container must be hacked, and this is the one genuine minigame in EVE. An
analyser launches a **virus** with two statistics that map exactly onto hit points and damage:
**coherence** and **strength**. You explore a hidden grid; each revealed node may be empty, the
system core you are looking for, or a defensive subsystem with its own coherence and strength.

| Node | Behaviour |
| --- | --- |
| Firewall or antivirus | A straight blocker that hits back hard |
| **Restoration Node** | Once revealed, **heals the other defences every turn** — so it must be killed first |
| Virus Suppressor | Reduces your strength while it lives |
| Utility pickups | Self-repair, a coherence-stripping attack, a shield, or a second attack vector |

**Two failures destroy the container and its loot**, and in a ghost site a failed hack damages your
ship. The design is a deterministic tactical puzzle laid over a stochastic reveal: every click is a
choice between gathering cheap information and committing damage.

### Sites

The naming convention encodes the space class, which is a quietly excellent piece of readability —
"Local" and "Crumbling" are high-sec, "Regional" and "Decayed" low, "Central" and "Ruined" null, and
"Unsecured" and "Forgotten" are Sleeper sites in wormhole space.

| Site | Contents |
| --- | --- |
| **Data** | Decryptors and datacores for invention, tools, and blueprint copies |
| **Relic** | Faction **salvage**, which feeds tech 2 and tech 3 rigs and components |
| **Sleeper Cache** | Blue loot, tech 2 and capital materials, storyline blueprints |
| **Ghost site** | Covert research tools and rare implant blueprints — behind **a hidden self-destruct timer** of roughly thirty seconds to three minutes from arrival |
| Combat site | Rated 1/10 to 10/10, with faction and deadspace modules, often reached by escalation |
| Gas site | Fullerites in wormholes, and the booster gases elsewhere |

### Wormholes as a career

Wormhole space has **no local chat, no stargates and no static map**, so every connection must be
scanned and every chain mapped by hand. Residents track the state of their chain in third-party
tools authenticated against the game's API, because the client will not do it for them.

A home system has one or more **static** connections — a fixed destination class that respawns
immediately when collapsed — plus wandering holes. Since every hole has a total mass allowance and a
per-jump limit, fleets deliberately **roll** holes by pushing heavy ships through until they
collapse, which is how a group controls who can reach it.

The pay scales with class, from roughly 20–50M ISK an hour in a C1 to several hundred million in a
C6 with a practised fleet. The danger is structural: no local chat means no warning, and connections
are bidirectional, so the hole you came through is also the one somebody else can use to find you.

[EVE University: Probe scanning](https://wiki.eveuniversity.org/Probe_scanning), [Relic and data sites](https://wiki.eveuniversity.org/Relic_and_data_sites), [Ghost sites](https://wiki.eveuniversity.org/Ghost_Sites), [Exploration skills](https://wiki.eveuniversity.org/Exploration_skills), [W-space](https://wiki.eveuniversity.org/W-space), [EVE Ref: Data Analyzer I](https://everef.net/types/22175)

## PvE content

### Agent missions

Agents work for NPC corporations belonging to the four empires and a long tail of others, and offer
three divisions: **security** (combat in deadspace pockets behind acceleration gates),
**distribution** (courier work gated on cargo capacity) and **mining**. **Storyline** agents fire
every sixteen missions with better rewards, and **epic arcs** are long branching chains with faction
consequences.

| Level | Standing needed | Typical hull | Space |
| --- | ---: | --- | --- |
| 1 | none | Frigate | High-sec |
| 2 | 1.0 | Cruiser | High-sec |
| 3 | 3.0 | Battlecruiser | High and low |
| 4 | **5.0** | Battleship or marauder; **paid accounts only** | High and low |
| 5 | **7.0** | Capital or a small gang; paid only | **Low-sec only** |

The gate uses the higher of your corporation or faction standing, so standing is a currency in its
own right. Rewards are ISK, bounties and **loyalty points**.

### The null-sec grind, and escalations

Null-sec income rests on **combat anomalies** whose difficulty scales with how negative the system's
security is, climbing through Hubs and Havens to Sanctums. Clearing them pays NPC bounties, and this
is **the single largest ISK faucet in the game**. Any anomaly may **escalate** into a multi-stage
rated complex bookmarked in your journal, which is where the deadspace and officer modules come from
— a lottery sitting on top of a grind.

### Incursions

An **incursion** is a constellation-scale Sansha invasion with three site scales — vanguard, assault
and headquarters — and one genuinely interesting mechanic. The focus system starts at **100% Sansha
influence**, which applies system-wide debuffs to players, and running sites drives it down. The
players are not just farming the content, they are visibly rolling it back, and the debuff is what
makes the early runs hard and the late ones easy.

Incursions pay fixed, repeatable ISK rather than drop luck, and are available in high-security
space, which is why drilled communities have run them as a profession for fifteen years.

### Abyssal Deadspace

Covered under **The universe** above, and the most interesting PvE structure in the game: a filament
drops one cruiser, two destroyers or three frigates into three instanced pockets behind a **hard
twenty-minute clock**, with no cloaking, no Local, no directional scanner and no map, under one of
five rolled weather effects that help and hurt both sides. Run out of time and the ship, the pod and
every fitted implant are destroyed.

### Events, dailies and the new-player funnel

The studio runs a stable calendar of roughly fortnightly themed events, and **AIR Daily Goals** give
five daily objectives feeding a monthly reward track. The **AIR Career Program** replaced the old
tutorial with four career tracks.

The largest structural change to the new-player experience in years is **Exordium**, added in June
2026: a **53-system starter region at security 1.0 where PvP is blocked entirely**, where every new
character now begins and which is left by a one-way, one-time jump. Ore yield, payouts and market
activity there are all deliberately reduced, and taxes and industry costs raised, so it is a training
ground rather than a place to settle. Fractured Skies adds thirteen free pre-fitted hulls usable only
inside it.

### NPC intelligence as a difficulty tier

EVE's baseline NPCs are famously primitive — belt rats aggress the first thing that locks them and
never adapt. Rather than fix that globally, the studio has used **better AI as a content tier**:

| Generation | Behaviour |
| --- | --- |
| Classic rats | Fixed aggression, no target switching |
| **Sleepers**, 2009 | Switch targets mid-fight, ignore the drone-priority convention, **remote repair each other**, neutralise capacitor |
| Incursion Sansha, 2010 | Target switching, and they **prioritise logistics ships** |
| **Burner missions**, 2014 | Solo targets running *fleet* AI, with response fleets |
| Triglavian and abyssal, 2018 | Ramping damage, capacitor and web pressure, composed room by room |
| Insurgency NPCs, 2023 | Faction-aligned aggression — they engage anyone not on the leading pirate faction's side |
| 2026 | Roaming NPC AI improved; in wormholes, NPC targeting now **splits across capsuleers** |

There is a reported constraint worth recording: community accounts hold that earlier attempts to
make general null-sec rat AI smarter mostly succeeded in breaking the botting software, which then
adapted. Difficulty in a game with an economy is never only a difficulty question.

[EVE University: Missions](https://wiki.eveuniversity.org/Missions), [Combat site](https://wiki.eveuniversity.org/Combat_site), [Incursions](https://wiki.eveuniversity.org/Incursions), [Abyssal Deadspace](https://wiki.eveuniversity.org/Abyssal_Deadspace), [CCP support: AIR Daily Goals](https://support.eveonline.com/hc/en-us/articles/14411899943068-AIR-Daily-Goals-and-the-Monthly-Reward-Track), [CCP: patch notes 24.01](https://www.eveonline.com/news/view/patch-notes-version-24-01), [CCP: Cradle of War expansion notes](https://www.eveonline.com/news/view/cradle-of-war-expansion-notes)

## Interface

EVE's interface is studied as a design subject, and the nickname "spreadsheets in space" is accurate
without being quite the insult it sounds like. Almost every window is a configurable table over live
data, and learning to configure them *is* the skill curve.

| Element | What it does, and why it matters |
| --- | --- |
| **The Overview** | A filtered table of everything on the grid. Configuring it — which classes, standings and object types appear in which tab — is considered genuinely essential rather than optional, to the point that experienced players distribute **shared overview packs** as files for newcomers to import. A badly configured overview gets you killed, because what you cannot see you cannot shoot or avoid |
| **The fitting window** | Slot layout with live CPU, powergrid, capacitor and resistance readouts, and a simulator since 2016. The third-party **Pyfa** exists because players want to plan fits offline |
| **The Industry window** | Blueprints, facilities and jobs, with each activity's **system cost index drawn as a fill bar** so the fee is visible before committing — rare in any game, and the reason the index works as a soft control on where production happens |
| **The directional scanner** | A 360° or narrow-cone sweep of everything within range, with no automation. In wormhole space, where there is no Local chat, it is the primary intelligence tool |
| **The probe scanner** | Signature list plus the 3D probe formation; the explorer's whole working environment |
| **The map** | Region and system views with information layers — jumps, kills, pod kills, sovereignty, industry indices — so the galaxy map doubles as a situation report |
| The Neocom and windows | The persistent sidebar and a stack of dockable windows, reworked under the **Photon UI** programme and iterated repeatedly since |

### The API, and the ecosystem it enables

The most consequential interface decision EVE ever made was to publish the data.

**ESI**, the current API, serves live market orders per region, thirteen months of daily price
history, industry cost indices, sovereignty, and kills and jumps per system — much of it without
authentication. The **static data export** publishes every item, attribute and blueprint recipe.
The monthly economic report ships its raw numbers as an archive.

What grew on top is now inseparable from the game: **zKillboard** for destruction records, **Dotlan**
for maps and system statistics, **EVE Ref** for item and industry data, **Pyfa** for fitting,
**Tripwire** and **Pathfinder** for wormhole chains, and a row of market and industry calculators.
Players do not read EVE's economy in the client; they read it in third-party tools the studio does
not build and does not have to.

The in-game browser, by contrast, was removed years ago — the ecosystem lives outside the client
entirely.

[EVE University: Overview](https://wiki.eveuniversity.org/Overview), [Fitting](https://wiki.eveuniversity.org/Fitting), [Industry](https://wiki.eveuniversity.org/Industry), [Directional scanner](https://wiki.eveuniversity.org/Directional_scanner), [ESI documentation](https://esi.evetech.net/ui/), [EVE Ref datasets](https://docs.everef.net/datasets/)

## Multiplayer, social structure and out-of-game culture

EVE is one game with one world, so its social systems are not a layer on top of the gameplay — they
are most of it. What follows is the part Oolite, being single-player, can learn from least directly
and borrow from most selectively.

### Chat and intelligence

| Channel | Behaviour |
| --- | --- |
| **Local** | Everyone in the solar system. In known space this is the primary intelligence tool — you watch the member list, not the conversation. **In wormhole space it does not populate**, which is the single mechanic that makes Anoikis frightening |
| Corporation, alliance | Persistent organisational channels |
| Fleet, wing, squad | Scoped to the fleet hierarchy |
| Custom channels | Player-created and moderated; the intelligence backbone of every large group |
| Private conversations | One to one |

The design point is that **Local's member list is a sensor**, and removing it from one region of
space changed the entire character of that region without changing a single ship statistic.

### Fleets

A fleet is a formal structure — fleet, wings, squadrons — with **boosting positions that only work
if the hierarchy is filled in**, since command bursts and old-style links propagate along it. The
fleet commander's job is largely information: calling targets, calling ranges and calling the
**anchor** everyone orbits so that two hundred ships move as one body and stay inside a 15 km burst
radius.

Fleet mining works the same way: a boosting Orca or Rorqual projects cycle-time and yield bonuses
to everyone nearby and holds the ore, so a mining fleet is a formation with a logistics centre
rather than a group of people in the same belt.

### Organisations as a structure

The full ladder is **player → corporation → alliance → coalition**, and only the first three exist
in the client at all. Coalitions — the blocs that actually fight EVE's wars — are entirely social:
shared comms, shared standings, shared intelligence tools, and an agreement. The game has never
modelled them, and in September 2026 it deliberately made them weaker by restricting jump bridges to
the owning alliance.

That gap between what the client models and how players organise is where EVE's reputation comes
from. The vetting pipelines, the spies, the year-long infiltrations and the public betrayals all
live in the space the game left empty.

### Out-of-game infrastructure

An unusual amount of EVE happens outside the client, and the studio supports rather than resists it:

- **Third-party tools** built on the public API: killboards, map and intelligence services, wormhole
  chain mappers, fitting simulators, market and industry calculators. Most serious players run
  several, and some are effectively required to play a career.
- **Voice** is almost universally run on outside platforms rather than in-game.
- **The Council of Stellar Management**, ten elected players flown to Iceland under
  non-disclosure agreement to advise on design — a formal channel between the player body and the
  studio that no other game of this size operates.
- **Published economics.** The monthly economic report, with its raw data attached, means the player
  base argues about the game's economy using the same numbers the studio does.
- **Fanfest and the monument.** The studio holds an annual convention in Reykjavík, and there is a
  physical monument there carrying the names of players.

### The part worth borrowing

For a single-player game, almost none of this transfers directly. Three things do:

1. **Asymmetric information as a mechanic.** Wormhole space is frightening because one UI element was
   switched off. The equivalent in a single-player game is a scanner that tells you less, selectively.
2. **Publishing the data.** The telemetry idea already in Oolite's feature list is the same instinct:
   let the game's state be readable from outside, and tools appear that nobody had to design.
3. **Letting the record be public.** Killmails make loss permanent *socially*, not just mechanically.
   Oolite has no record of anything the player has done — not a kill, not a trade run, not a career.

[EVE University: Chat channels](https://wiki.eveuniversity.org/Chat_channels), [Fleet](https://wiki.eveuniversity.org/Fleet), [Command bursts](https://wiki.eveuniversity.org/Command_bursts), [Council of Stellar Management](https://wiki.eveuniversity.org/Council_of_Stellar_Management)

## The player loop, and what players complain about

EVE's extraction and production economy works because every stage is a decision someone can
specialise in, and because the stages depend on each other. A miner who ignores the market mines the
wrong rock. An industrialist who ignores sovereignty cannot buy the moon goo. The famous description
of EVE as "spreadsheets in space" is accurate and is also the appeal: the game is an economy with
ships attached.

What makes it a career rather than a chore, in order of how much the players themselves credit it:

1. **Specialisation pays.** The barge-to-exhumer-to-Rorqual ladder, boosting hulls, crystals,
   compression logistics and moon scheduling are each a distinct competence with a distinct income.
2. **Someone else needs your output.** Minerals are consumed by real losses in real fights, so
   demand is genuine rather than a quest reward.
3. **The numbers are visible.** The Mining Ledger, the Industry window's cost indices, the public
   market history and CCP's own Monthly Economic Report mean a player can actually optimise.
4. **It is contested.** The good ore is in dangerous space, the good moons belong to someone, and
   the richest Phased Asteroid Fields announce themselves to everyone before they can be mined.

And the complaints, which are as instructive as the design:

| Complaint | Status |
| --- | --- |
| **"Clicking more rocks is not engaging gameplay"** | Acknowledged. It drove Equinox's fewer-but-bigger rocks and Catalyst's crits and quartered cycle times |
| **High-sec ganking** | Perennial and still live. Players calculate that a fully tanked Hulk needs ten or eleven Catalysts to kill and that its loot can pay about 350M ISK, so the arithmetic favours the gankers |
| **The Scarcity-era nerfs** | Null-sec Mercoxit down 90%, Bistot 70%, Arkonor 50%, every high-sec ore anomaly removed. Still resented |
| **Mining residue** | Widely disliked as random resource destruction. CCP cut tech 1 modules from 100% residue to 0% after the backlash |
| **Research times** | Material efficiency 10 on a capital blueprint is 790 days of base research. Nothing has changed it |
| **Mineral prices** | **The dominant complaint now.** The Monthly Economic Report had the mineral price index down about 52% year on year by February 2026, with mining value falling through the year. The problem is not that ore is scarce — it is that ore is cheap |
| **Equinox sovereignty mining** | CCP publicly conceded the design missed in a February 2025 devblog and committed to bringing capital mining back without returning to the Rorqual era |

The last two are the lesson worth carrying anywhere else. EVE spent four years making ore harder to
get, and the result was not that mining became prestigious; it was that mining became unprofitable
and the people who did it anyway did it while watching television. An extraction career balanced on
the sale price of what comes out of the rock will always drift that way.

[CCP: Equinox Mining Balance, Philosophy and Learnings](https://forums.eveonline.com/t/devblog-equinox-mining-balance-philosophy-and-learnings-devblog-feedback-thread/478088), [Nosy Gamer: what went wrong with Equinox sov mining](https://nosygamer.blogspot.com/2025/03/what-went-wrong-with-eve-onlines.html), [Nosy Gamer: MER for February 2026](https://nosygamer.blogspot.com/2026/03/eve-onlines-monthly-economic-report-for.html), [EVE forums: Ungankable Hulk](https://forums.eveonline.com/t/ungankable-hulk/509788), [EVE forums: Highsec ganking epidemic of 2026](https://forums.eveonline.com/t/highsec-ganking-epidemic-of-2026/504735), [EVE forums: returning player, residue, why](https://forums.eveonline.com/t/returning-player-residue-why/367139)

## Scale numbers

Collected for pacing comparisons. Mining and industry figures are verified against the static data
export; the income figures are the softest numbers here and are flagged accordingly.

| Quantity | Value |
| --- | --- |
| Mining laser cycle | **15s**, down from 60s before Catalyst |
| Strip miner cycle | **45s**, down from 180s |
| Ice harvester cycle | 240s tech 1, 200s tech 2 — always 1,000 m³, one block |
| Ore per strip-miner cycle | 120 m³ bare, 216 with a tech 2 crystal, 200 for the ORE module |
| Venture | about 250 m³/min; 5,000 m³ hold filled in 20 minutes |
| Covetor | 9,000 m³ hold, more than twice a Venture's rate |
| Hulk | about 1,600 m³/min, 96,000 m³ an hour gross; hold filled in **seven minutes** |
| Rorqual | 300,000 m³ mining hold; 400 m³/min base from five Excavators before bonuses |
| Moon drill | **30,000 m³ an hour**, over a 6 to 56 day cycle; Metenox is passive at 40% of that |
| Compression | **100 to 1** for ore, 10 to 1 for ice and gas |
| Reprocessing | 69.6% with full skills at a 50% NPC station; **90.6%** at a rigged null-sec Tatara |
| Jetcan, secure container, mobile tractor unit | 55,000 m³ / 3,900 m³ / 27,000 m³ |
| Build time, module | 30 minutes (Cap Recharger I) |
| Build time, light drone | 10 minutes |
| Build time, tech 1 destroyer | **2h 30m** |
| Build time, capital component | 4h 27m |
| Build time, dreadnought hull | **23 days 3 hours**, about 9–10 with full skills and a Sotiyo |
| Build time, titan | reportedly seven to eight weeks, excluding components — unverified |
| Research, destroyer blueprint to ME10 | **89 days** base |
| Research, dreadnought blueprint to ME10 | **790 days** base |
| Copy time | 80% of build time per run |
| Job cost | estimated item value × (index × structure) + 0.25% station tax + **4% flat surcharge** |
| System cost index | a floor around 0.14% across most of New Eden; several times that in hubs |
| Job slots | 11 manufacturing, 11 science, 25 jumps of remote range |
| Mining income | about **10M ISK an hour** solo in high-sec, 15–20M boosted in a fleet — optimistic given the 52% fall in the mineral index through early 2026, and no reliable 2026 measurement was found |
| Industry income | **not reliably measurable.** The usual advice is to target a 10% margin per item; claims in guides range from almost nothing to 300M per pilot per three-hour cycle |

### What could not be verified

The references above are good for mechanics and mostly good for numbers, but these points stayed
open and are recorded rather than guessed:

- The mineral splits for Bezdnacine, and for the Equinox sovereignty ores (Kylixium, Nocxite,
  Hezorime, Ueganite, Griemeer, Mordunium). The wiki table for these is garbled and flagged
  outdated; only Rakovene and Talassonite came through cleanly.
- A current sustained ore-per-hour figure for a Rorqual. The module arithmetic gives 400 m³/min
  before three multiplicative bonus lines, but no 2026 source states the result.
- The "perfect mining" ceilings widely quoted for a Hulk (50–130 m³ per second). They come from a
  page last edited in April 2024 and cannot be reconciled with current module statistics.
- A current table of security-space multipliers for *manufacturing* rigs. The reprocessing ones
  (0, +6%, +12%) are confirmed; the manufacturing equivalents are not.
- The exact present behaviour of the system cost index, which the wiki warns may post-date its own
  published formula.
- Titan build times beyond the dreadnought figure.
- Tier-3 Mercoxit respawn, quoted as ten hours in one announcement and twelve in the patch notes.
- Whether the mining figures above survive Fractured Skies, which ships on 10 November 2026 with
  its full notes due on the 6th. Nothing announced touches mining, but the notes were not out.

## The wider EVE project

EVE Online is now one product among four, all under the same studio, and the others are informative
about where the studio thinks the design goes next.

| Product | What it is | Status, November 2026 |
| --- | --- | --- |
| **EVE Online** | The 2003 MMO this reference describes | Live; Fractured Skies on 10 November 2026 |
| **EVE Vanguard** | A first-person shooter set in the same universe, intended to connect to EVE itself | **Paid round-the-clock alpha from 10 November 2026**, with Founder's packs, three maps and a job board |
| **EVE Frontier** | A separate, blockchain-based survival game in the EVE setting | Under the same umbrella; no verified 2026 status found |
| **EVE Galaxy Conquest** | A mobile strategy game | Under the same umbrella; no verified 2026 status found |

The studio's named Head of Economy, appointed in March 2025, was framed as working on EVE Frontier
as much as EVE Online — which suggests the economic simulation is being treated as transferable
technology rather than one game's feature.

### The DeepMind partnership

Alongside the May 2026 rebrand, Google took a minority stake and **Google DeepMind** entered a
research partnership using EVE as an environment for work on **long-horizon planning, memory and
continual learning**. Reported early work involves an **offline build of EVE running on a local
server** plus the historical data the studio has accumulated since 2003.

Floated applications include testing how changes propagate through a simulated economy, guidance for
new players, and — more speculatively — semi-autonomous agents in the world itself. None of it is
shipped, and the partnership is early enough that it should be read as a statement of intent.

It is worth noting *why* EVE is attractive for this: twenty-three years of a single, continuously
recorded economy with millions of participants, where the studio owns the ledger. There is no other
dataset quite like it in games.

[MassivelyOP on the rebrand and the DeepMind partnership](https://massivelyop.com/2026/05/06/eve-continues-eve-onlines-ccp-games-rebrands-as-fenris-creations-partners-with-google-deepmind/), [80.lv](https://80.lv/articles/eve-online-studio-goes-indie-in-new-era-rebrand-with-google-deepmind-ai-partnership), [CCP: Directors' Letter, 2026 and beyond](https://www.eveonline.com/news/view/directors-letter-2026-and-beyond), [Game Developer: Head of Economy appointment](https://www.gamedeveloper.com/press-release/ccp-games-appoints-central-bank-economist-stef-n-rarinsson-to-advance-virtual-economies)

## Ideas for Oolite

EVE's systems mostly assume thousands of players and an open market, so they transfer less directly
than Frontier's or Elite Dangerous's. What does transfer is the *shape* of its careers: each one has
inputs it must source, a decision about where to work, and an output somebody else needs. Several of
these also answer things already written down in
[Oolite Feature Ideas](<Oolite Feature Ideas.md>).

### Five that fit best

1. **Ore types that refine into different material mixes.** The one idea that makes mining a career
   instead of a chore, and Oolite already has the pieces — a commodity class taxonomy, a tonne /
   kilogram / gram unit system, and `cargo_carried` on any entity. Worked out in
   [Mining and Manufacturing](<Mining and Manufacturing — Design Sketch.md>).
2. **Critical hits on a repetitive action.** A 1% chance of triple yield that does not consume the
   asteroid, with its own sound and flash, is the cheapest fix for tedium in either game, and it
   generalises past mining to scooping and sun-skimming.
3. **Abyssal Deadspace as a template for a self-contained run.** A filament drops you into an
   instanced pocket with a hard twenty-minute timer and seven difficulty tiers, and you either clear
   it and extract or die with the ship. That is almost exactly the wave-defence mode already wished
   for at the end of the ideas doc, with a structure that makes it repeatable and rankable.
4. **A fitting budget, not just slots.** Every EVE module costs CPU and powergrid out of a hull's
   fixed budget, so fitting is a real optimisation and ships specialise. This is the general form of
   Frontier's equipment-mass idea, and it would give Oolite's hulls distinct characters without
   adding a single new item.
5. **Scanning with a payoff.** Signatures resolved by probing, then a hacking puzzle for the
   contents, give exploration something to *do* rather than merely somewhere to go — the gap the
   exploration-career row already names.

### Ships, fitting and progression

| Idea | What EVE does | Oolite today |
| --- | --- | --- |
| Fitting budget | Each hull has fixed CPU and powergrid; every module draws on both, so a full rack of good modules will not fit | Equipment is gated by tech level and price, and only the passenger berth costs hold space |
| Stacking penalties | The second and later modules of the same kind give sharply diminishing returns, which bounds stacking without banning it | Only missiles, mines and passenger berths can be fitted more than once at all |
| Damage types and resistance profiles | Four damage types against four resistances per ship, so ammunition choice matters | One damage number; lasers differ in rate and heat |
| Tech tiers and faction variants | Tech 1, tech 2, faction, pirate and officer versions of most modules, at rising cost | Equipment has one version each |
| Real-time training | Skills train in wall-clock time whether or not you are logged in, so progression is access rather than power | Equipment is gated by money and tech level; `installation_time` already charges hours to the clock |
| Insurance as a system | Ships are insured for a payout, making loss a budgeted cost rather than a disaster | Escape pods pay an insurance reward; the ship and cargo are simply gone |
| Permanent loss and killmails | Everything lost is destroyed and the killmail is public, which is where much of the game's social weight comes from | Dying costs the ship and cargo; nothing records it |

### Economy and trade

| Idea | What EVE does | Oolite today |
| --- | --- | --- |
| Order books | Players place buy and sell orders at a station; the market is a real order book with broker fees and sales tax, visible across a region | Each station quotes one price per good and trades instantly |
| No global market | Prices differ by region, there is no universal price, and hub concentration emerges rather than being designed | Prices already vary per system by economy, but the player cannot see them without going there |
| Contracts with collateral | Courier contracts carry collateral the hauler forfeits by stealing the cargo, which makes third-party hauling a real business | Cargo, parcel and passenger contracts hand over the goods with no stake |
| A published economy | CCP publishes a Monthly Economic Report — money supply, mineral price index, production and destruction — and an API the community builds tools on | The debug console already exposes game state to the component tests |
| Faucets and sinks by design | ISK enters through bounties and missions and leaves through fees, taxes and fuel, and the balance is managed deliberately | Credits enter through trade and bounties and leave through purchases; nothing is tracked |
| Loyalty points | A second currency earned per faction, spendable only in that faction's store | Contract reputations exist but buy nothing |

### Content and structure

| Idea | What EVE does | Oolite today |
| --- | --- | --- |
| Instanced timed runs | Abyssal filaments: a tiered pocket, a twenty-minute timer, extract or lose the ship | None |
| Signatures and probing | Cosmic signatures resolved by probe, then a hacking minigame for the contents | Nothing to find and nothing to scan |
| Site classes with known loot | Data, relic, combat, gas and ghost sites each have a known profile, so players choose what to look for | None |
| Space with no safety net | Null-sec and wormhole space have no police response at all, and wormhole space has no local chat, so you cannot tell who is there | Anarchies have fewer police; the scanner always shows everyone |
| Smarter NPCs in specific content | Burner missions, Sleepers and Triglavians use noticeably better AI than ordinary NPCs, as a difficulty tier | The priority AI is uniform; difficulty comes from numbers and hulls |
| Structures with timers | Attacking a player structure starts a reinforcement timer, so defence is scheduled rather than instant | Stations cannot be attacked meaningfully |

### Mining, industry and the economy

Mostly a pointer: the full working-out is in
[Mining and Manufacturing](<Mining and Manufacturing — Design Sketch.md>). These are the rows that
belong in the ideas table.

| Idea | What EVE does | Oolite today |
| --- | --- | --- |
| Ore types with distinct yields | Sixteen ores, each giving a different mix of eight minerals, so the rock you mine depends on what you want to build | One rock type; every splinter is 1 t of Minerals at about 12 CR |
| Refining as compression | Ore reprocesses at 50–90% and compresses to **1% of its volume** for hauling | No refining. But `quantity_unit` already models tonnes, kilograms and grams, and 499 kg rides free of the hold |
| Resources split by region | Each security band is the only source of certain minerals, and of certain ice products, specifically to force trade between them | Asteroid fields are identical everywhere; government already decides rock hermit allegiance |
| A survey layer | Ore anomalies are scanned, sized and named before you commit to them | Fields are deterministic per system but entirely undiscoverable in play |
| An industry cost index | Job fees scale with how much production a system has hosted over 28 days, so crowding pushes industry outward, self-balancing | Equipment prices scale by station, fixed |
| Two-tier materials | Raw material at 5 ISK a unit becomes an advanced commodity at 1,200,000 — a factor of 240,000 across four processing tiers | Commodities are a single flat tier |
| Fuel as upkeep | Player structures burn **player-manufactured** fuel blocks hourly; run dry and the services stop | Nothing the player owns needs feeding |

### Rules worth stealing outright

Four EVE mechanics are small, self-contained and would improve Oolite without any new content.

1. **The stacking penalty.** `exp(−((n−1)/2.67)²)` applied to the second and later modules with the
   same effect — 100%, 87%, 57%, 28%, 11%. It makes "fit five of the best thing" pointless without
   forbidding it, which is exactly the problem Oolite would hit the moment equipment became
   stackable, as the Frontier shield-generator idea proposes.
2. **A non-linear energy curve.** EVE's capacitor recharges fastest at 25% of capacity and collapses
   below it, which creates a real "disengage now" threshold. Oolite's energy banks recharge
   linearly, so there is no such moment.
3. **Insurance that pays on estimated hull value, not price.** It covers the hull and never the fit,
   reverts to a lower tier if the ship is traded, and **pays nothing if the law destroyed you** — so
   it cannot subsidise a deliberate loss. Oolite insures the escape pod and nothing else.
4. **Progressive reveal on a scan.** A signature resolves its *type* at 25% signal, its *name* at
   75%, and only becomes usable at 100%, so the player decides whether to keep spending effort.
   Oolite's scanner is binary: a contact is either in range or not.

### What not to take

Worth recording, because EVE is a cautionary tale as often as a model, and all four of these are
things the studio itself has had to walk back or defend.

| Avoid | Why |
| --- | --- |
| **Resource destruction on a roll** | Mining residue — tech 2 lasers destroying extra ore in the asteroid on a random roll — is the most disliked mechanic in mining, and tech 1 modules had to be cut from 100% residue to 0% after launch. It is punishment with no decision attached |
| **Research measured in months** | Material efficiency 10 on a dreadnought blueprint is **790 days** of base research. It makes a researched blueprint an inheritable asset, which is interesting in a game with corporations and absurd in one without |
| **Probabilistic countermeasures** | ECM is the only electronic warfare in EVE that rolls dice rather than applying an effect, and it is correspondingly resented. Deterministic effects of the same strength read as fair |
| **An economy balanced on extraction prices** | The mineral price index fell about 52% in a year and mining became what people do while watching television. Pay an extraction career in capability, not in credits |

## Sources

Grouped by kind, because their reliability differs sharply and it matters which was used for what.

### Game data, generated from the game itself

The most reliable class, and the source for essentially every concrete number in the mining,
reprocessing, blueprint, industry and ship-price tables.

- **[EVE Ref](https://everef.net/)** — generated from the static data export. Item and ore pages
  ([Veldspar](https://everef.net/types/1230), [Mercoxit](https://everef.net/types/11396),
  [Miner I](https://everef.net/types/483), [ORE Strip Miner](https://everef.net/types/28754),
  [Blue Ice](https://everef.net/types/16264), [Bitumens](https://everef.net/types/45492)),
  blueprints ([Coercer](https://everef.net/type/16237), [Naglfar](https://everef.net/type/19723),
  [Cap Recharger I](https://everef.net/types/1196)),
  [datasets](https://docs.everef.net/datasets/) and the
  [industry cost API](https://docs.everef.net/api/industry-cost.html)
- **[ESI](https://esi.evetech.net/ui/)** — the live API. Universe counts, market orders, the global
  PLEX market
- Live Jita market aggregates for the ship, module and injector prices

### The studio: patch notes and devblogs

Authoritative on mechanics and on anything recent.

- Expansions: [Catalyst](https://www.eveonline.com/news/view/catalyst-expansion-notes),
  [Cradle of War](https://www.eveonline.com/news/view/cradle-of-war-expansion-notes),
  [Fractured Skies arrives 10 Nov](https://www.eveonline.com/news/view/fractured-skies-expansion-arrives-10-nov),
  [Fractured Skies In Focus](https://www.eveonline.com/news/view/fractured-skies-in-focus),
  [Equinox](https://eveonline.com/news/view/equinox-expansion-notes),
  [Equinox in Focus](https://eveonline.com/news/view/equinox-in-focus-reinvigorating-nullsec),
  [Havoc](https://www.eveonline.com/news/view/havoc-expansion-notes),
  [Upwell 2.0](https://www.eveonline.com/news/view/upwell-2.0-structures-changes-coming-on-february-13th),
  [patch notes 24.01](https://www.eveonline.com/news/view/patch-notes-version-24-01),
  [patch notes 22.02](https://www.eveonline.com/news/view/patch-notes-version-22-02)
- Mining and the economy:
  [Mining in Focus](https://www.eveonline.com/news/view/mining-in-focus-new-ore-and-more),
  [Resource Distribution Update](https://www.eveonline.com/news/view/resource-distribution-update),
  [From Extraction to Production](https://www.eveonline.com/news/view/from-extraction-to-production),
  [Introducing the Mining Ledger](https://www.eveonline.com/article/introducing-the-mining-ledger-new-tools-for-miners-in-eve-online),
  [Equinox mining balance, philosophy and learnings](https://forums.eveonline.com/t/devblog-equinox-mining-balance-philosophy-and-learnings-devblog-feedback-thread/478088)
- Technology and operations:
  [Tranquility Tech IV](https://www.eveonline.com/news/view/tranquility-tech-iv),
  [The Move to Python 3 Begins](https://www.eveonline.com/news/view/the-move-to-python-3-begins),
  [Force Projection Revamped](https://www.eveonline.com/news/view/major-update-force-projection-revamped)
- Policy and community:
  [Introducing Clone States](https://www.eveonline.com/news/view/introducing-clone-states-and-the-future-of-access-to-eve-online),
  [Team Security rules and policy clarifications](https://www.eveonline.com/news/view/team-security-rules-and-policy-clarifications),
  [Clash at Atioth](https://www.eveonline.com/news/view/clash-at-atioth),
  [CSM 21: Is it Your Time?](https://www.eveonline.com/news/view/csm-21-is-it-your-time),
  [Directors' Letter: 2026 and beyond](https://www.eveonline.com/news/view/directors-letter-2026-and-beyond)
- [Monthly Economic Reports](https://www.eveonline.com/news/t/monthly-economic-reports), and the
  2007 press release [appointing an in-world economist](https://community.eveonline.com/news/news-channels/press-releases/eve-online-appoints-in-world-economist-1)
- [Support knowledge base](https://support.eveonline.com/), for mining, daily goals and service modules

### EVE University

Excellent on **how mechanics work**, unreliable on **what the numbers are** — most mining and
industry pages carry an "outdated" banner, and the "Perfect mining" page has not been revised since
April 2024. Used here for mechanics and formulas, with numbers taken from the data sources above.

[Asteroids and ore](https://wiki.eveuniversity.org/Asteroids_and_ore) ·
[Mining](https://wiki.eveuniversity.org/Mining) ·
[Mining crystals](https://wiki.eveuniversity.org/Mining_crystals) ·
[Ice harvesting](https://wiki.eveuniversity.org/Ice_harvesting) ·
[Gas cloud harvesting](https://wiki.eveuniversity.org/Gas_cloud_harvesting) ·
[Moon mining](https://wiki.eveuniversity.org/Moon_mining) ·
[Compression](https://wiki.eveuniversity.org/Compression) ·
[Reprocessing](https://wiki.eveuniversity.org/Reprocessing) ·
[Minerals](https://wiki.eveuniversity.org/Minerals) ·
[Reactions](https://wiki.eveuniversity.org/Reactions) ·
[Blueprints](https://wiki.eveuniversity.org/Blueprints) ·
[Research](https://wiki.eveuniversity.org/Research) ·
[Invention](https://wiki.eveuniversity.org/Invention) ·
[Manufacturing](https://wiki.eveuniversity.org/Manufacturing) ·
[Industry](https://wiki.eveuniversity.org/Industry) ·
[Upwell structures](https://wiki.eveuniversity.org/Upwell_structures) ·
[Planetary Industry](https://wiki.eveuniversity.org/Planetary_Interaction) ·
[Medical boosters](https://wiki.eveuniversity.org/Medical_boosters) ·
[Security status](https://wiki.eveuniversity.org/Security_status) ·
[Crimewatch](https://wiki.eveuniversity.org/Crimewatch) ·
[W-space](https://wiki.eveuniversity.org/W-space) ·
[Wormholes](https://wiki.eveuniversity.org/Wormholes) ·
[Pochven](https://wiki.eveuniversity.org/Pochven) ·
[Abyssal Deadspace](https://wiki.eveuniversity.org/Abyssal_Deadspace) ·
[Damage types](https://wiki.eveuniversity.org/Damage_types) ·
[Natural resistances](https://wiki.eveuniversity.org/Natural_Resistances) ·
[Tanking](https://wiki.eveuniversity.org/Tanking) ·
[Stacking penalty](https://wiki.eveuniversity.org/Stacking_penalty) ·
[Capacitor](https://wiki.eveuniversity.org/Capacitor) ·
[Strategic cruisers](https://wiki.eveuniversity.org/Strategic_Cruisers) ·
[Skill training](https://wiki.eveuniversity.org/Skill_training) ·
[Skill trading](https://wiki.eveuniversity.org/Skill_trading) ·
[Clone states](https://wiki.eveuniversity.org/Clone_states) ·
[Market](https://wiki.eveuniversity.org/Market) ·
[Trading](https://wiki.eveuniversity.org/Trading) ·
[Tax](https://wiki.eveuniversity.org/Tax) ·
[Trade hubs](https://wiki.eveuniversity.org/Trade_hubs) ·
[Contracts](https://wiki.eveuniversity.org/Contracts) ·
[Hauling](https://wiki.eveuniversity.org/Hauling) ·
[Suicide ganking](https://wiki.eveuniversity.org/Suicide_ganking) ·
[PLEX](https://wiki.eveuniversity.org/PLEX) ·
[Loyalty Points](https://wiki.eveuniversity.org/Loyalty_Points) ·
[Forming a corporation](https://wiki.eveuniversity.org/Forming_a_corporation) ·
[Alliances](https://wiki.eveuniversity.org/Alliances) ·
[Sovereignty](https://wiki.eveuniversity.org/Sovereignty) ·
[War declaration](https://wiki.eveuniversity.org/War_Declaration) ·
[Factional Warfare](https://wiki.eveuniversity.org/Factional_Warfare) ·
[Council of Stellar Management](https://wiki.eveuniversity.org/Council_of_Stellar_Management) ·
[Probe scanning](https://wiki.eveuniversity.org/Probe_scanning) ·
[Relic and data sites](https://wiki.eveuniversity.org/Relic_and_data_sites) ·
[Ghost sites](https://wiki.eveuniversity.org/Ghost_Sites) ·
[Missions](https://wiki.eveuniversity.org/Missions) ·
[Incursions](https://wiki.eveuniversity.org/Incursions) ·
[Time dilation](https://wiki.eveuniversity.org/Time_dilation) ·
[Command bursts](https://wiki.eveuniversity.org/Command_bursts)

### Press and encyclopedias

- The 2026 rebrand: [Shacknews](https://www.shacknews.com/article/149020/fenris-creations-ccp-games-eve-online-rebrand),
  [Game Developer](https://www.gamedeveloper.com/business/eve-online-studio-ccp-games-turns-independent-and-rebrands-as-fenris-creations),
  [MassivelyOP](https://massivelyop.com/2026/05/06/eve-continues-eve-onlines-ccp-games-rebrands-as-fenris-creations-partners-with-google-deepmind/),
  [VGC](https://www.videogameschronicle.com/news/eve-online-studio-ccp-games-is-rebranding-following-its-split-from-crimson-deserts-pearl-abyss/),
  [Gematsu](https://www.gematsu.com/2026/05/ccp-games-rebrands-to-fenris-creations-following-split-from-pearl-abyss),
  [80.lv](https://80.lv/articles/eve-online-studio-goes-indie-in-new-era-rebrand-with-google-deepmind-ai-partnership)
- Wikipedia: [EVE Online](https://en.wikipedia.org/wiki/Eve_Online),
  [CCP Games](https://en.wikipedia.org/wiki/CCP_Games),
  [Expansions of EVE Online](https://en.wikipedia.org/wiki/Expansions_of_Eve_Online)
- [Guinness World Records: largest virtual theft](https://www.guinnessworldrecords.com/world-records/92197-largest-virtual-theft-in-an-mmorpg)
- [Game Developer: CCP appoints Stefán Þórarinsson](https://www.gamedeveloper.com/press-release/ccp-games-appoints-central-bank-economist-stef-n-rarinsson-to-advance-virtual-economies)
- Fractured Skies coverage: [Gaming Trend](https://gamingtrend.com/news/eve-online-fractured-skies-brings-conquests-and-a-winner-to-factional-warfare/),
  [MMOHuts](https://mmohuts.com/news/eve-onlines-fractured-skies-expansion-lands-november-10-with-new-navy-battlecruisers)

### Player analysis and community tools

Directional rather than authoritative, and the income figures in particular are soft.

- [Nosy Gamer](https://nosygamer.blogspot.com/) on the monthly economic reports and on Equinox
  sovereignty mining · [EO-Map industry cost index](https://eo-map.com/industry-cost-index/) ·
  [eve-offline concurrency tracker](https://eve-offline.net/?server=tranquility) ·
  [Tripwire](https://tripwiremap.app/) · zKillboard, Dotlan, Adam4EVE, Fuzzwork and Pyfa
- Forum threads used for the player-complaint section:
  [Ungankable Hulk](https://forums.eveonline.com/t/ungankable-hulk/509788),
  [Highsec ganking epidemic of 2026](https://forums.eveonline.com/t/highsec-ganking-epidemic-of-2026/504735),
  [Returning player, residue, why](https://forums.eveonline.com/t/returning-player-residue-why/367139)

### Oolite

The "Oolite today" column under **Ideas for Oolite** comes from Oolite's own core data in this
repository — `Resources/Config` and `Resources/Scripts` — and from `src`. **No expansion packs were
read.**
