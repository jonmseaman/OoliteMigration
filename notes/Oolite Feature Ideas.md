# Oolite Feature Ideas

Features that Frontier: Elite II (1993), Frontier: First Encounters (1995), Elite Dangerous and the later ports of the original Elite have and core Oolite doesn't, plus a modern UI and multiplayer. The details and sources for each game are in the feature references in `docs/feature_reference`: [Elite (1984)](<../docs/feature_reference/Elite (1984) — Feature Reference.md>), [Frontier: Elite II and First Encounters](<../docs/feature_reference/Frontier Elite II and First Encounters — Feature Reference.md>), [Elite Dangerous](<../docs/feature_reference/Elite Dangerous — Feature Reference.md>) , [EVE Online](<../docs/feature_reference/EVE Online — Feature Reference.md>) , [X4: Foundations](<../docs/feature_reference/X4 Foundations — Feature Reference.md>) , [Freelancer](<../docs/feature_reference/Freelancer — Feature Reference.md>) , [Wing Commander: Privateer](<../docs/feature_reference/Wing Commander Privateer — Feature Reference.md>) and [Stellaris](<../docs/feature_reference/Stellaris — Feature Reference.md>).
EVE Online's modules and fitting systems are covered in depth separately, in [EVE Online — Modules and Fitting](<../docs/feature_reference/EVE Online — Modules and Fitting Reference.md>).

"Oolite today" describes the core game in `oolite-dev` (`Resources` and `src`), not expansions, so some of these may already exist as OXPs. Elite II and First Encounters together are "Frontier".

## Interface

| Idea | From | What it does there | Oolite today |
| --- | --- | --- | --- |
| Modern UI | Frontier, Elite Dangerous | Frontier is mouse-first: click a ship in any view to target it, or a body on the system map to send the autopilot there. First Encounters keeps combat and flight targets apart, so the autopilot keeps flying during a fight. Elite Dangerous has cockpit panels: navigation, transactions and contacts on the left; modules, cargo and ranks on the right; fuel, power and radar in the centre | Full-screen pages on the function keys. The mouse picks rows and steers, but can't target anything. The HUD is defined in `hud.plist`, multi-function displays included |
| System map and autopilot | Frontier | A zoomable, rotatable 3D orrery that reaches down to planet surfaces. Pick a body or port, and the autopilot flies there, asks for clearance and docks or lands | No in-system map; the docking computer only docks at stations |
| Trade-route overlay | Elite Dangerous | Coloured arcs on the galaxy map show goods flowing between systems | The long-range chart shows no trade |
| Telemetry for companion apps | Elite Dangerous | A journal of every event plus live `Status.json` and `NavRoute.json` files, read by tools such as EDDI | The debug console already exposes game state to the component tests |
| Situational music | Elite Dangerous | The soundtrack changes for combat, supercruise, docking, exploration and more | Docking music, and `customsounds.plist` for sound effects |
| Commander portrait | NES Elite | A portrait that changes with rank, wealth and legal status | None |

## Flight and physics

| Idea | From | What it does there | Oolite today |
| --- | --- | --- | --- |
| Newtonian flight | Frontier | Ships keep their momentum, thrust is rated in g, and three engine modes (engines off, set speed, autopilot) share one key | Elite-style flight at a set speed |
| Gravity | Frontier | The body you're flying near pulls on you, slingshots work round big stars and planets, and heavy ships drop like bricks on high-gravity worlds | No gravity anywhere in the source |
| Landing on planets | Frontier | Fly down through the atmosphere to a surface starport with 2, 4 or 6 pads, or land anywhere flat. Atmospheric shielding allows fast entry | Planets are scenery; you dock only at stations |
| Time acceleration | Frontier | The Stardreamer runs time at up to 10,000× and drops back to normal when you're attacked, hailed or arrive | Only in debug builds (0.0625× to 16×); players use the torus drive (32×) |
| Power distributor | Elite Dangerous | Systems, engines and weapons each have a capacitor, and you move power between them; an empty weapons capacitor stops the guns | Shields and lasers share one energy bank |
| Heat and silent running | Elite Dangerous | Silent running hides your heat signature while heat builds up; heat sinks dump heat and decoy missiles | Cabin and laser temperature and the heat shield exist; the only stealth is the cloaking device |
| Interdiction | Elite Dangerous | An attacker drags you out of supercruise in a tug-of-war; submitting lets your drive recharge sooner | The torus drive is mass-locked near ships, but nothing pulls you out |

## The galaxy

| Idea | From | What it does there | Oolite today |
| --- | --- | --- | --- |
| Full star systems | Frontier | Up to 43 bodies (Sol has 43), including gas giants, moons and several starports, moving along fixed orbits | One sun and one main planet. Scripts can add planets and moons, but nothing moves along an orbit |
| Multiple stars | Frontier | One to six stars per system; Castor has six | One sun per system |
| Star classes | Elite Dangerous | Over 40 stellar types, from main sequence to Wolf-Rayet stars, white dwarfs and black holes. Only O, B, A, F, G, K and M stars refuel you. A neutron star's jet cone adds 300% to jump range and a white dwarf's 50%, with drive wear | Suns vary in colour, and any sun refuels |
| The real neighbourhood | Frontier | A procedural Milky Way with 117 hand-placed systems: 76 real stars near Sol, 30 famous stars and the 11 Old Worlds | Eight charts of 256 made-up systems |
| Empty systems | Frontier | Over 3,800 systems are populated, but only about 650 have a starport, and some have no planets | Every system gets a main station by default |
| Permits | Frontier, Elite Dangerous | In Frontier some systems need a permit, earned by doing business there. In Elite Dangerous, navy ranks unlock permit-locked systems | None |
| Signal sources | Elite Dangerous | Signals such as weapons fire, combat aftermath, distress calls and convoys show a threat level before you drop in | The populator places traffic along the space lanes; nothing marks an encounter for you to drop in on |
| Space beacons | Archimedes Elite | Drop a beacon, which takes 1 t of cargo | Nav buoys exist; player beacons would be new |
| Custom galaxies | Amiga Elite | Players could make their own galaxies | Galaxy seeds are fixed |

## Ships and equipment

| Idea | From | What it does there | Oolite today |
| --- | --- | --- | --- |
| Drive classes | Frontier | Range depends on drive class and ship mass, roughly 200 × class² ÷ mass in tonnes. Military drives are lighter but burn scarce fuel that turns into radioactive waste | Every ship jumps 7 ly on a full tank, whatever it carries |
| Jump time by drive | Frontier | A jump at a drive's full range always takes a week, so a bigger drive is also a faster one | A jump takes the distance squared, in hours |
| Fuel as cargo | Frontier | Jump fuel is hydrogen carried in the hold, bought at the market or scooped from gas giants, which needs atmospheric shielding | A separate tank, filled at the outfitter or by skimming the sun |
| Equipment mass | Frontier | Every item's mass comes out of one capacity shared with the drive, guns, fuel, cabins and cargo | Only the passenger berth (5 t) uses hold space |
| Stackable shields | Frontier | Shield generators take 4 t each and stack; players report 68 on an Imperial Trader | Apart from missiles and mines, the passenger berth is the only item you can fit more than once |
| Crew | Elite II, Elite Dangerous | Big Frontier hulls need crew hired from the bulletin board and paid weekly; the Panther Clipper needs 12. In Elite Dangerous a hired NPC pilot takes a share of your earnings and flies your ship-launched fighter | No crew and no player fighters; NPC escort groups exist |
| Cargo bay life support | Frontier | Needed to carry live animals or slaves | Slaves are tagged `oolite-living` in `trade-goods.plist`, but nothing reads the tag |
| Canopy breach | Elite Dangerous | A breach starts an oxygen countdown set by the life-support module's rating | None |
| Radar mapper | Frontier | Scans a target's shields, range and kit and checks it against the wanted list; no bounty is paid unless it identified the ship | Bounties pay on every offender you kill |
| Mines, decoys and cooling | Frontier | Proximity mines wait for an assigned target; dummy mines look live on radar and can be scooped as cargo; a 1 t laser cooling booster | The Q-mine is the only mine; no cooling kit |
| Energy bomb | Elite (6502 versions), Frontier | One shot destroys the small ships around you. Elite's spares the station; Frontier's spares your own ship, and a strong shield resists it | Removed from core; the strict scenario could bring it back |
| Field repairs | Elite Dangerous | Every module has its own integrity, can be rebooted at 0%, and a repair unit fixes it in flight | Damaged equipment is repaired only at stations |
| Wear per item | Frontier | Unserviced items grow unreliable, then fail and show faded until repaired | Partly there: a ship-wide service level (see Already in Oolite) |
| Subsystem targeting | Elite Dangerous | Aim at a ship's drives or power plant to disable it instead of killing it | NPC equipment can be damaged, but you can't aim at it |
| Drones | Elite Dangerous | Limpets break open cargo hatches, collect cargo and prospect asteroids | None |
| Owning several ships | Elite Dangerous | Keep ships in storage, plus up to 600 stored modules, and choose which to fly | One ship; buying another trades in the old one |
| Engineering | Elite Dangerous | 25 engineers upgrade modules with grade 1–5 blueprints paid for in collected materials, plus one experimental effect per module | Equipment has fixed stats |

## Trade and economy

| Idea | From | What it does there | Oolite today |
| --- | --- | --- | --- |
| Laws by system | Frontier | Each system lists its own illegal goods: anarchies ban nothing, Imperial space almost nothing, and the Federal core cracks down on narcotics and slaves | One legality per good everywhere. A planetinfo or station `market_script` can already change it, but no core script does |
| Black markets | Elite II, Elite Dangerous | In Elite II illegal goods trade only through bulletin-board dealers, some of them police stings. In Elite Dangerous black markets take illegal goods and fence stolen cargo | Illegal goods sell on the open market, and carrying them out raises your bounty |
| Dumping is a crime | Frontier | Jettisoning cargo is illegal, and some cargo changes when dumped: live animals become meat, slaves die, and food and liquor become rubbish | Jettisoning has no legal cost |
| Cargo you pay to unload | Frontier | Radioactives and rubbish have negative prices, and military fuel burns into radioactive waste | Radioactives are an ordinary good |
| Prices that react | Frontier | Buying a good out raises its price, and a big sale lowers it at the midnight reset | Trades change only the stock; prices change when the market is regenerated or a script sets them |
| Buyers in a hurry | Elite II | "Wanted" adverts pay above market, often double, for goods you find yourself | Cargo contracts give you the client's cargo |
| Rare goods | Elite Dangerous | 142 rares, each from one station and worth more the farther you carry it. Lavian Brandy, Leestian Evil Juice and Diso Ma Corn are named after Galaxy 1 systems | `trade-goods.plist` already has price, quantity and legality keys per commodity |
| System states | Elite Dangerous | Boom, Famine, Outbreak, Lockdown and War shift prices and missions, and players' trading, fighting and missions push them | Government, economy and tech level are fixed per system |
| News that moves markets | First Encounters | The plague report at Soholia comes with high medicine prices and a relief job | No news or market events |
| Ore and refined materials | EVE Online | Raw ore is bulky and cheap; refined minerals are compact and are what blueprints actually consume, so the market carries a two-tier materials economy | Gold, platinum and gem-stones have no source in the game at all — nothing turns a rock into any of them. Minerals and Alloys are ordinary goods |
| Salvage | Elite Dangerous | Black boxes, data cores and relics to scoop and hand in | Cargo pods and escape pods can be scooped (see Already in Oolite) |

## Mining and exploration

| Idea | From | What it does there | Oolite today |
| --- | --- | --- | --- |
| Mining as a craft | Elite Dangerous | Icy, rocky, metallic and metal-rich fields with hotspots; prospector limpets show what a rock holds; a refinery turns fragments into tonnes; seismic charges crack cores | The mining laser, the cargo scoop, asteroid fields and rock hermits |
| Mining machine | Elite II | The MB4 lands on a world below 200 °C and mines and refines into a 10 t hopper over about 8 months; other pilots can steal it | None |
| Mining contracts | Elite Dangerous | Factions ask for named minerals; gems such as Void Opals sell above 100,000 CR a tonne | Contracts cover cargo, parcels and passengers |
| Ore types | EVE Online | Sixteen ores, each refining into a different *mix* of the eight minerals: Veldspar is pure Tritanium, Hedbergite gives Pyerite and Nocxium, Mercoxit alone gives Morphite. What you mine depends on what you mean to build | One rock type; every splinter is 1 t of Minerals at about 12 CR. `trade-goods.plist` already has `oolite-mining` and `oolite-rawmaterial` classes, and `cargo_carried` lets any entity hold any commodity |
| Refining and compression | EVE Online | Ore reprocesses into minerals at 50–90% depending on structure, rigs, skills and standings, and compresses to 1% of its volume for hauling | No refining. But `quantity_unit` already models tonnes, kilograms and grams, and up to 499 kg or 499,999 g of a good rides free of the hold |
| Rich ore where it is dangerous | EVE Online | The 2020–22 resource redistribution made each security band the only source of certain minerals, to force hauling and trade | Asteroid fields are identical everywhere. Government already decides rock hermit allegiance, so the hook exists |
| Critical mining hits | EVE Online | A chance per laser cycle of bonus yield that does not deplete the asteroid, with its own sound and flash; skills and modules raise it from 1% to roughly 30–50% | Nothing. A mining-laser hit always splits a rock the same way |
| Ore surveyor | EVE Online, Elite Dangerous | EVE puts a mineral surveyor on every starter hull, colour-coding asteroids by value in space with a remaining-quantity readout; Elite Dangerous uses prospector limpets and a Pulse Wave Analyser | You cannot tell one rock from another, or find a field without flying the lanes and looking |
| Blueprints | EVE Online | Blueprints gate what you can build: bought, copied, looted from data sites, or invented from datacores, then researched for material efficiency | None. Equipment is bought at a station of sufficient tech level or not at all |
| Manufacturing jobs | EVE Online | A job at a station or player structure consumes materials, a blueprint and time, with a fee set by a self-balancing system cost index. Ammunition takes minutes, a dreadnought hull 23 days | None. `station.setInterface` and the game clock would carry it; `installation_time` already adds hours on purchase |
| Industry rank | EVE Online, Elite Dangerous | Mining and industry are first-class careers with their own progression and contracts | The engine already counts a `miner` role weight on every asteroid the player cracks and shows it nowhere. Contract reputations exist for cargo, parcels and passengers |
| Exploration career | Elite Dangerous | Scan bodies and sell the data more than 20 ly away, valued by class, mass and terraforming. First-discovery tags carry your name, and a codex logs finds and phenomena such as Lagrange clouds and space molluscs | Exploring pays nothing |

## Missions, careers and law

| Idea | From | What it does there | Oolite today |
| --- | --- | --- | --- |
| Navy careers | Frontier | Federal and Imperial rank ladders of 13 steps. Missions pay points, rank opens assassination, reconnaissance and bombing work, and medals mark firsts. Points for one side count against you with the other | One combat rating and one authority, GalCop |
| More kinds of work | Frontier, Elite Dangerous | Frontier has timed assassinations (a named target leaving a named port at an exact time), missing-person tips and charity appeals. Elite Dangerous has courier, source-and-return, massacre, salvage and rescue missions, with a choice of reward | Cargo, parcel and passenger contracts on the F4 interfaces screen |
| Fleeing targets | First Encounters, Elite Dangerous | Targets run when alarmed, and the job fails if they jump out | None |
| Negotiating terms | Elite II | A trusted pilot can ask for about 10% more and payment up front; reputation plus a roll decides. A high fee warns of danger | Passenger contracts already pay part up front, scaled by reputation |
| Passenger traits | Elite Dangerous | Secretive, wanted, impatient and demanding passengers, and sightseeing trips to tourist beacons | Passenger contracts exist (`oolite-contracts-passengers.js`) |
| A record per faction | Frontier, Elite Dangerous | Frontier keeps a record with each bloc: about ten named offences with fixed fines, status bands from Clean to Fugitive, and fines paid remotely or bribed away. In Elite Dangerous each bounty belongs to the faction that issued it; a Kill Warrant Scanner reveals them all, and Interstellar Factors clears your own | One legal status from bounty points; fines for docking as an offender or without clearance. Stations already carry an allegiance (galcop, neutral, chaotic, pirate) |
| Crimes and notoriety | Elite Dangerous | About 20 ship and station crimes; fines differ from bounties; notoriety stops you paying them off; ships can be impounded | Clean, Offender and Fugitive statuses |
| Docking rules | Elite Dangerous | Numbered pads, reasons for refusal, and offences for loitering or blocking the slot | Docking clearance, and fines for docking without it |
| More rank ladders | Elite Dangerous | Trade and Exploration ranks beside Combat, plus navy ranks that unlock ships and permit-locked systems | The combat rating |
| Faction reputation | Elite Dangerous | Standing from Hostile to Allied with every faction; allies offer promotions | Contract reputations for cargo, parcels and passengers |
| Conflict zones | Elite Dangerous | Faction wars stage battles at three intensities that pay combat bonds | None |
| Powerplay | Elite Dangerous | Pledge to a Power for perks and a weekly fight over system control | None |
| Galactic events | Elite Dangerous | Community goals pool many players toward one target, such as building a starport, with tiered rewards; month-long story events | None |
| Calendar story with newspapers | First Encounters | 16 missions in fixed date windows, foreshadowed and reported by five biased newspapers | Five core missions, triggered by kill count, galaxy and chance; no news |
| Peaceful first contact | First Encounters | The story ends in peaceful contact with the Thargoids, with a Thargoid warship as the reward | Thargoids are only enemies |
| Difficulty starts | Frontier | Start at Ross 154 in an Eagle, at Mars, or at Lave in a Cobra Mk III owing 70,000 credits in fines | Standard, easy, tutorial and strict scenarios |
| Competition code | Elite (1984–86 versions) | A checksummed code packing flags, cash and kills, posted in to prove your rank | None |

## Owning a piece of the galaxy

| Idea | From | What it does there | Oolite today |
| --- | --- | --- | --- |
| Fleet carriers | Elite Dangerous | A 5-billion-credit station of your own that jumps up to 500 ly, for about 5M CR a week in upkeep plus optional services | None |
| Colonisation | Elite Dangerous | Players haul commodities to build stations in uninhabited systems within about 16 ly of populated ones | None |

## Multiplayer

Oolite is single-player. The engine is built around one player (`PlayerEntity::sharedPlayer()`), and its only network code is the expansion manager's downloads and the debug console's TCP link.

| Idea | What it does in Elite Dangerous |
| --- | --- |
| One shared galaxy | Every player shares one galaxy and one background simulation, met in Open (everyone), Private Group or Solo mode |
| Wings | Teams of up to four. Everyone who damaged a wanted ship gets its bounty, wings take missions together, and wing members show on the HUD compass |
| Multicrew | Other players join your ship as gunner or fighter pilot, as holograms or, since Odyssey, walking aboard. The captain can remove them |
| Arena | CQC: player-versus-player deathmatch, team deathmatch and capture the flag in four arenas, with its own ranks |
| Squadrons | Player groups aligned with a faction, with perks, leaderboards and a squadron carrier holding a shared treasury and bank |
| Community goals | Many players pool contributions toward one target, counted in every mode |
| Chat and friends | Local, wing, system, squadron, friend, direct and voice channels, and a friends list |

Possible starting points:

- An arena (one sealed system, no economy) or co-op wings keep the shared state small, but both still need ship state sent between machines.
- Asynchronous features need only a server: community goals, shared leaderboards, or other commanders' careers turning up as NPCs.

## From Elite's later ports

Content that versions after the 1984 BBC game added and Oolite's core doesn't have.

| Idea | Versions | What it was | Oolite today |
| --- | --- | --- | --- |
| New ships | 6502SP, C64, Amiga, Archimedes and others | The Cougar and Wolf Mk II, and the Archimedes Bushmaster, Hognose, Moccasin, Caiman, Copperhead, Racer and Crazy Craft | Not in core; the cloaking mission uses a cloaked Asp |
| Supernova rescue | Spectrum, CPC, MSX, PC, Elite Plus, ST, Amiga | Reach a star about to blow, scoop fuel, take the station crew or refugees aboard and jump out | The nova mission exists; carrying the refugees out is the extra |
| Thargoid invasion | CPC, MSX, PC, Elite Plus, ST, Amiga | Destroy a Thargoid-held station with missiles; the reward is an anti-ECM device and the title Archangel | None |
| Thargoid documents | MSX, Elite Plus, ST, Amiga | Only Thargoids attack while you carry them, up to four at once; the reward is a Naval Energy Unit | Core has the BBC Thargoid plans mission |
| Constrictor, 16-bit form | MSX, ST, Amiga | Follow station messages across several galaxies to a ship that shows like a Thargoid on the scanner | Core has the 6502 form |
| Archimedes missions | Archimedes | The Genesis Capsule (changes a planet's description), Kill Zartid III, Kill Zurid Pino and the Medicine Run | None |
| A living world | Archimedes | Pirate packs defend their patches, police Vipers fly in formation and tow disabled ships, NPC Cobras hunt pirates to raise their own rating, and escorted ships run while you fight the escorts | The populator and priority AI already stage NPC fights and escorts; towing, formations and ranked NPC rivals would be new |
| Bigger packs | Elite Plus | Damaged Adders and Kraits spill missiles, and anarchies send up to 7 attackers at once | Populator and AI tuning |
| Docking for hire | Archimedes, NES | Pay 50 CR for remote docking at tech level 8 or above (Archimedes), or 5 CR to use a docking computer you don't own (NES) | Docking computers exist |

## Already in Oolite

- **Hyperspace pursuit.** The wormhole scanner reads a wormhole's destination, and you can fly into an NPC's wormhole, much as Frontier's hyperspace cloud analyser allows.
- **Passenger advances.** Passenger contracts pay part of the fee up front, scaled by reputation.
- **Wear.** A ship-wide service level from 75 to 100 drops with jumps and damage and lowers trade-in value. Below 80 it raises the chance of a misjump. The maintenance overhaul resets it.
- **Rescues.** Scooped escape pods pay an insurance reward, or a bounty if the pilot is wanted.
- **Smaller pieces.** Docking clearance, external views, spoken messages and the Blue Danube docking music.
- **Ahead of Frontier.** The advanced navigational array plots multi-jump routes, which neither Frontier game had.


## More

Main menu background: Include the stars and space station just like the startup screen?

Definitely like the idea of the system map. This along with UI improvements would make the game a lot more accessible. I don't know how to find asteroid fields. I kinda want to do some mining, but I only got one dollar. Also, not sure how to get fuel.

Maybe I could make an Oolite LLM?

Right click mouse and drag to rotate camera and look around like in EVE online. That would be cool. It would be cool to make an EVE Online feature reference as well as some of the other space games too. — written: [EVE Online](<../docs/feature_reference/EVE Online — Feature Reference.md>), and the mining and manufacturing career it suggests is sketched in [Mining and Manufacturing](<Mining and Manufacturing — Design Sketch.md>). [X4: Foundations](<../docs/feature_reference/X4 Foundations — Feature Reference.md>) and [Freelancer](<../docs/feature_reference/Freelancer — Feature Reference.md>) and [Wing Commander: Privateer](<../docs/feature_reference/Wing Commander Privateer — Feature Reference.md>) and [Stellaris](<../docs/feature_reference/Stellaris — Feature Reference.md>) are written too.

I'm not sure how I get fuel. Maybe I could add that to the tutorial?


It would be cool to have a station defense arcade mode that is wave defense against a bunch of spaceships. Or, it could be a thing to pass the time.


EVE Online ships: Have a pod as the default ship, eject, frigate as the most basic one, clones if you die???
