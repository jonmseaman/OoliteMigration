# Space Rangers — Feature Reference

Nov 7, 2026 · @Jon Seaman

Space Rangers 2 is the living-galaxy reference. It is the only game in this folder where the world
has a war of its own, fights it whether or not you are involved, and can **finish without you** —
with the Coalition victorious or collapsed, depending partly on what you did and partly on what the
AI did while you were elsewhere. Everything else here either has a static galaxy
([Freelancer](<Freelancer — Feature Reference.md>), [Privateer](<Wing Commander Privateer — Feature Reference.md>)),
a galaxy that moves only economically ([X4](<X4 Foundations — Feature Reference.md>)), or a galaxy
that moves because thousands of other players are in it
([EVE](<EVE Online — Feature Reference.md>)). This one has a front line.

It also has the best **equipment model** of any game here, and it is one number: a hull's **size** is
simultaneously its hit points, its equipment capacity and its cargo capacity. Cargo is whatever room
is left once your guns, engine, radar and repair droid are installed. The trader-versus-fighter
trade-off is therefore structural rather than a stat, and it cost the designers nothing.

And it is a genre hybrid in a way nobody has repeated: a turn-based space trader with a real-time
strategy minigame, an arcade shooter, and a library of **standalone text adventures** you play on
planets. Fifteen people in Vladivostok built it in about eighteen months. That is the other reason
it is in this folder — it is the clearest available evidence about what a very small team can get out
of content formats that cost writing rather than engineering.

**On the name.** This reference covers the series, but almost everything below is *Space Rangers 2*
(2004) as it exists in the current **Space Rangers HD: A War Apart** remaster (2013). The 2002
original is a smaller version of the same design.

**On sources.** There is no manual and no official wiki. Figures here come from contemporary
reviews, the GOG and Steam store descriptions, community wikis and Steam guides — several of them
written for versions two patches ago, which the guides themselves warn about. The galaxy size, the
number of text quests and the mechanics of the war's progression are all approximations or
descriptions rather than documented numbers, and they are flagged. This is the least well-sourced
reference in the folder and the one most worth verifying in game.

## Overview and timeline

| Item | Value |
| --- | --- |
| *Space Rangers* | 2002, Elemental Games, published by 1C |
| ***Space Rangers 2: Dominators*** | **November 2004** in Russia; *Rise of the Dominators* in North America, 27 March 2006 |
| *Space Rangers 2: Reboot* | 7 September 2007 in Russia, 2009 worldwide — the last update from Elemental Games |
| ***Space Rangers HD: A War Apart*** | 14 March 2013 in Russia, **17 October 2013** worldwide, by SNK-Games with series fans |
| Developer | Elemental Games, **Vladivostok** — about **15 people over roughly 18 months** |
| Setting | The year **3300**; five Coalition races against three kinds of Dominator |
| Galaxy | **Randomly generated**, around 60 star systems (reviewer figure) |
| Movement | Turn-based, measured in **solar days** |
| Genres | Space trading and combat, turn-based strategy, real-time strategy, third-person shooter, shoot-'em-up, text adventure, RPG |
| Metacritic | **84/100** |
| Awards | PC Gamer US **Best Turn-Based Strategy Game 2006**; fifth-best game of 2005 per *Computer Games Magazine* |
| Players | Single-player only |

### The studio, and what happened to it

Worth a paragraph because it bears on the content question. Elemental Games built *Space Rangers 2*
in Vladivostok with about fifteen developers in around a year and a half. In 2004 a conflict with
management led several of them to leave and form **Katauri Interactive** — who went on to make
*King's Bounty: The Legend*. Aleksey Dubovoy, the brand owner and a programmer, supported the game
until 2007, and *Reboot* was Elemental's last release. The 2013 HD remaster was made by
**SNK-Games** working with fans of the series.

So the game that contains six genres was made by a team smaller than many modern UI departments, and
then finished by its own community.

### Versions

| Version | What it added |
| --- | --- |
| *Reboot* (2007) | Slightly better graphics, quality-of-life fixes, and reportedly **5 new text quests and 27 new planetary battle maps** |
| *HD: A War Apart* (2013) | 1920×1200, reworked menus and views, multi-core support — plus a **new pirate campaign**, **10+ new text adventures, 15+ planetary battle maps and 20+ government missions**, and the option to side with the pirates, the Dominators, or both |

## The galaxy

Randomly generated at the start of each game: a few dozen star systems, each with planets and
stations, joined by hyperspace jumps. The population is five Coalition races — **humans, Maloqs,
Pelengs, Faeyans and Gaalians** — and three Dominator types — **Blazeroids, Kelleroids and
Terronoids** — which fight each other as well as the Coalition.

Three properties of a planet, and they are all live:

- **Its own economy**, with dynamic supply and demand, so prices move.
- **Its own government.**
- **Its own opinion of you.** Piracy and looting pay, and they damage your relations with races and
  with individual planets, which can end in being attacked on sight.

Movement is **turn-based in solar days**, which is the structural decision everything else rests on.
A game that advances in discrete days can afford to simulate a galaxy's worth of ships and a war
between turns, because it only has to do it once per day rather than continuously. Oolite is
real-time, so this is not a portable choice — but it is why the rest of this document is possible on
2004 hardware, and worth knowing before concluding that a living galaxy is expensive.

## The war that runs without you

This is the headline and it is worth being precise about what is actually claimed, because it is the
part fan sources describe best and document worst.

The Dominators are attempting to conquer the galaxy **one planet at a time**. At the start they are
far stronger than you, so early play is evasion and small jobs. Planets are **liberated** — one of
the routes is the planetary-battle minigame below. The publisher's own description of the current
version is the clearest statement available:

- *"All player actions affect what kind of place the Galaxy will be at the end"*, which may end with
  **a victorious Coalition or a collapsed alliance**.
- *"The balance in either of wars may be tipped not only by the player, but by AI actions as well."*

So there are two wars running in the current version — the Coalition against the Dominators, and the
pirates' guerrilla war for power in a weakened galaxy — and both have outcomes that the simulation
can reach on its own. **After winning one war you may end the game or keep playing into the other.**

What this buys, in design terms, is the thing a static sandbox cannot have: **the galaxy has an
agenda, and your inaction is a decision.** Elite's Thargoids attack and then stop. Oolite's populator
stages encounters. Here, a system you ignore can be gone next time you look.

### How the front actually moves

Community accounts converge on this, and it is more concrete than the publisher's blurb:

- **Dominators open black holes** and attack systems through them.
- **Rangers defend the systems they still hold and attack the ones they have lost** — NPC rangers
  included — **sometimes recovering them and sometimes not.**
- **Stations prevent a system from being captured until they are destroyed**, so infrastructure is
  the thing that holds a system rather than a garrison number.
- **Military bases can jump to occupied systems** as part of a liberation force, and you join an
  operation by docking at the base organising it.
- **Adjacency matters.** A system you liberate while it is surrounded by Dominator space can fall
  again almost immediately, so the practical advice is to retake systems next to friendly space. The
  front has a shape, and pushing a salient into it does not hold.
- After taking a system you can land and be offered the **optional planetary battle** below.

Two consequences worth recording. The first is that **fighting the Dominators is a bad living**:
repair costs mount and there is no reliable payout, so the war is something you choose to fund rather
than a source of income — which is why most playthroughs begin as trading or pirate careers and turn
military only once they can afford it.

The second is the sentence that justifies this whole reference. On higher difficulties, **either the
Dominators can take over the universe, leaving you less and less room to operate, or the rangers can
liberate the known universe without your help.** The simulation can resolve its own war in *either*
direction. A galaxy that can lose without you is unusual; one that can also *win* without you is the
part nobody else in this folder attempts, and it is what makes the player a participant rather than
a protagonist.

### Other rangers

You are one of a corps, and the others are implemented:

- Dozens of other ranger ships move around the galaxy doing the same work you do — contemporary
  reviews describe them as **in direct competition with the player**.
- There is a **ranking system and leaderboard** tracking your performance against each of them.
- **Medals** are awarded, and the Ranger Rating screen shows each ranger's medals under their
  portrait — so a rival's career is legible, not just their score.

The ideas doc already wants a version of this: the "A living world" row, from Archimedes Elite, notes
that NPC Cobras hunt pirates to raise their own rating. Space Rangers is that idea taken all the way
— named rivals with careers, medals and a public table — and it is the single cheapest way to make a
background simulation feel populated by anybody other than the player.

### The news

Every planet carries **galactic news**, alongside the mission board, the equipment shops and the
commodity market. It reports the war, what has been lost and taken, and what you have done.

This is the mechanism without which none of the above would register. A simulation the player cannot
observe is indistinguishable from no simulation, and a news ticker on every landing screen is an
extremely cheap observability layer. It is the same conclusion X4's message ticker reaches, applied
to a galaxy that has actual events to report.

## Careers

There is no class system. What you are emerges from what you do, and the game names the results:
trader, warrior, mercenary, pirate, liberator, corsair. Missions come from planets and governments —
hunting pirates, smuggling contraband, covert operations against other races — and reward money,
better hulls and weapons, and **maps that unlock new sectors**, so exploration is partly a mission
reward rather than purely a matter of flying there.

The 2013 remaster goes further and lets you **side with the pirates or with the Dominators, or
both**, with their own story missions, goals and promotions, climbing the pirate hierarchy from the
bottom. Letting the player join the faction the game was built to oppose is a bolder move than
anything in the rest of this folder, and it is the feature the remaster was named for.

## Ships and equipment

### One number, three jobs

A hull's most important statistic is its **size**, and size is:

- the ship's **hit points**,
- the **space available for equipment**, and
- the **cargo capacity** — specifically, whatever space is left after your equipment is installed.

There is no separate hold. Fit another gun and you can carry less cargo; strip your weapons and you
are a freighter. That is the entire trader-versus-fighter tension, expressed in one field, with no
ship classes required and no rule anywhere saying a freighter cannot fight. Compare X4, which needs
four storage classes and a role taxonomy to achieve something similar, and Oolite, where cargo space
and equipment are mostly independent.

Some special hulls trade a weapon slot or an artifact slot for a bonus, so the slot economy itself
is negotiable.

### Equipment, size and upkeep

Every item — engine, fuel tank, radar, scanner, repair droid, grappler, weapons — has a size, and
the pressures run against each other in a way that produces real decisions:

- **Smaller weapons take less space but generally cost more to repair**, so compactness has an
  operating cost.
- **Micromodules** modify installed equipment, and the community's standard pick is the
  **size-reducing** one, because you need spare hull space for repair nodes.
- **Artifacts** occupy a separate pool of **0 to 4 slots** depending on hull.
- A **repair droid** repairs the hull in flight, but **not equipment**, and will not take the hull
  past its maximum. Community guidance is to keep droid efficiency near **5% of hull size** for it to
  matter in combat.
- **Maintenance cost depends on who made the part.** The long-run advice is that everything except
  the hull, the weapons and the grappler should be Gaalian-made to keep upkeep down — so the
  manufacturer is a real property of an item, not flavour text.
- **Dominator wreckage yields unique parts** you cannot buy, so fighting the enemy you cannot
  negotiate with is the route to the best equipment.

Three ideas there are directly usable. **Equipment occupying the same space as cargo.** **Per-item
condition with per-item upkeep**, where Oolite has a single ship-wide service level. And
**manufacturer as a stat**, which gives a galaxy of races a mechanical reason to matter when you are
shopping.

## The genre hybrids

Space Rangers 2 contains at least three other games, and the interesting thing is that each one is
*the verb for a strategic action* rather than a diversion.

### Text quests

Standalone interactive fiction, played when you land: *Borzukhan*, *Space Lines*, *Ministry*,
*Phoncers*, *Fishing Championship*, *Edelweiss*, *Banquet*, *Elections*, *Diving*, *Jumper*, *Disc*,
*Xenopark*, *Leonardo da Vinci* and more. Each is a named, self-contained puzzle with **its own
rules** — some are logic problems, some are resource-management games, some are branching stories —
and each pays out in money, reputation or equipment.

They are the most-loved part of the game and they are almost pure text. *Reboot* added five; *A War
Apart* added more than ten. For a fifteen-person team, a text quest is **content that costs writing
rather than engineering**, and it is why a 2004 game by a tiny studio has more distinct things to do
than most modern space games. The relevance to an expansion ecosystem is obvious: a text-quest format
is a content type an OXP author could ship without touching the renderer.

### Planetary battles

A **real-time strategy minigame** fought on a stretch of planetary surface: you build and command
robots against the Dominators holding the planet, **placing turrets to protect your HQs and
resource outposts**, capturing bases, replacing losses, and finally **taking an enemy HQ with a
robot** once its defenders are destroyed. You can drop into **third-person control of any
individual unit**. It is offered as an optional quest after you liberate a system, and it is one
of the ways to **liberate a planet**.

So the RTS is not a side mode — it is how a strategic outcome is achieved, and winning it changes the
galaxy's map. That is the shape the wave-defence idea at the end of the ideas doc should take: a
sealed, rule-bounded engagement whose result is a change in the persistent world.

### Arcade combat

Enemies can be pursued into **hyperspace** for keyboard-driven arcade combat, accessible from the
main menu as its own mode in the remaster. A third engine, again attached to an actual decision —
whether to chase.

## Reception, and what it got wrong

Metacritic 84, and the reviews are unusually consistent about both halves.

**Praised**: the openness, the breadth, the replayability, and the sheer number of things to do.
GameSpot called it a successor to *Star Control II* for its exploration and sense of freedom, and a
2020 retrospective called its combination of systems ahead of its time.

**Criticised**: a **difficult interface**, a **confusing English translation**, uneven polish, and a
**lack of structure** — IGN's complaint, which also identified the open-ended design as the game's
greatest strength. The difficulty of the opening, where the Dominators vastly outclass you and the
game does not explain what to do about it, comes up repeatedly.

Which is the trade this reference records. Space Rangers has the most alive galaxy in the folder and
the worst front door. Freelancer, which has the best front door, has the most inert galaxy. Neither
of those is a necessary trade — they are separate decisions that happened to land that way — and
the pair of references together is the argument for doing both.

## Scale numbers

Approximations where no documented figure exists; marked accordingly.

| Quantity | Value |
| --- | --- |
| *Space Rangers 2* release | November 2004 (Russia) |
| Current version | **Space Rangers HD: A War Apart**, 2013 |
| Team size | about **15**, over roughly **18 months** |
| Setting | year **3300** |
| Star systems | about **60**, randomly generated — reviewer figure, not documented |
| Coalition races | **5** — humans, Maloqs, Pelengs, Faeyans, Gaalians |
| Dominator types | **3** — Blazeroids, Kelleroids, Terronoids, hostile to each other too |
| Time unit | the **solar day**; movement is turn-based |
| Hull size | **one number** = hit points = equipment space = cargo space |
| Artifact slots | **0 to 4**, by hull |
| Repair droid target efficiency | about **5% of hull size** (community guidance) |
| Text quests added by *Reboot* | **5**, plus 27 planetary battle maps |
| Content added by *A War Apart* | **10+** text adventures, **15+** battle maps, **20+** government missions |
| Metacritic | **84/100** |
| Genres combined | **6 or 7**, depending who is counting |

### What could not be verified

This is the thinnest sourcing in the folder and the gaps are worth stating plainly.

- **The exact rules of the front.** The mechanics above — black holes, stations blocking capture,
  military bases jumping in, adjacency deciding whether a liberated system holds, and the war
  resolving in either direction without the player — are consistent across community accounts and
  one publisher statement, but **no source gives the formulas**: how often the front is evaluated,
  what weights a system's fall, or how difficulty scales the Dominator advance. Directionally solid,
  numerically unknown.
- **The galaxy size.** About 60 systems comes from one contemporary review. No official figure
  found, and it is randomly generated, so the real answer is probably a range.
- **The total number of text quests.** Names are listed in community guides and the expansions'
  additions are quoted, but no complete count was located.
- **The ranger rating formula.** That rivals exist, compete, earn medals and appear on a leaderboard
  is attested by reviews and the fan wiki; how the rating is computed is not.
- **Equipment degradation specifics.** Per-item repair cost, the effect of manufacturer race on
  upkeep and the micromodule catalogue come from Steam guides that **warn they are out of date after
  patches**. Treat every number in that section as directional.
- **Whether anything came after 2013.** *Space Rangers: Quest* (2016) was a text-quest spin-off. No
  evidence was found of a current sequel or of active development, and no mod-scene figures were
  located.
- **Sales.** None published.

## Ideas for Oolite

Space Rangers is 2004, Russian, turn-based and ugly, and it is the most useful reference in the
folder for one specific question: **what makes a galaxy feel like it is doing something.** Its answer
is three cheap parts — a war with its own agenda, named rivals on a leaderboard, and a news service
that reports both — plus an equipment model that is better than anything else here.

### Five that fit best

1. **Hull size as hit points, equipment space and cargo space at once.** One field, three jobs,
   cargo being simply what is left. It makes the trader-versus-fighter decision structural, needs no
   ship roles and no new stats, and it is the single highest-value-per-line idea in any of these
   seven documents. Oolite already has cargo capacity and equipment as separate concerns; merging
   them would change the character of every hull in the game for almost no code.
2. **A war that advances without the player, and can end badly.** The front moves because of AI
   action as well as yours, and the campaign can finish with the alliance collapsed. Oolite's
   Thargoids attack and then stop; this is the structure that would make them a situation instead of
   an event, and it is the thing none of the other six references has.
3. **Named NPC rivals with medals and a public leaderboard.** Other rangers take the same contracts,
   earn the same decorations and are ranked against you, with their records visible. This is the
   full version of the ideas doc's "A living world" row, where Archimedes Elite's NPC Cobras hunt
   pirates to raise their own rating.
4. **Galactic news on every landing screen.** The observability layer, without which the simulation
   is invisible and therefore pointless. Cheap to build, and it is what turns a background war into
   something the player experiences.
5. **Per-item condition and per-item upkeep, with the manufacturer mattering.** Equipment wears,
   repair is an ongoing cost, the repair droid fixes hull but not gear, and where a part was made
   determines what it costs to keep. Oolite has one ship-wide service level that drops with jumps
   and damage; pushing that down to the item would give the eight races something mechanical to be
   different about.

### The living galaxy

| Idea | What Space Rangers does | Oolite today |
| --- | --- | --- |
| A war with its own agenda | The Dominators take planets one at a time; the balance shifts through AI action as well as the player's; the ending can be a collapsed alliance | The populator stages encounters; nothing accumulates |
| Two wars at once | The Coalition against the Dominators, and the pirates' guerrilla war for a weakened galaxy; win one and you may continue into the other | — |
| Inaction as a decision | A system you ignore can be gone when you return | — |
| The galaxy can win without you too | On higher difficulty the rangers may liberate the known universe unaided, or the Dominators may take it all and squeeze you out | — |
| A front with geography | A system liberated inside enemy space falls again quickly, so the practical move is to retake systems adjacent to friendly space | — |
| Infrastructure holds territory | A system cannot be captured while its stations stand | Stations are destructible but hold nothing |
| Mobile staging | Military bases jump to occupied systems as part of a liberation force, and you join by docking at the organising base | — |
| The war costs money | Repair bills mount and killing Dominators pays unreliably, so soldiering is something you fund out of trade | Bounties pay per kill |
| Named rivals with careers | Dozens of other rangers in direct competition, with a ranking table and medals shown under each portrait | NPC ships are anonymous |
| News as the interface to the simulation | Galactic news on every planet, reporting the war and your own deeds | Station messages |
| Planets with three live properties | Its own economy with real supply and demand, its own government, and its own opinion of you | System economy and government; legal status is galaxy-wide |
| A faction you cannot negotiate with | The Dominators, who also fight each other — so the enemy is not monolithic | Thargoids |
| Joining the enemy | The remaster lets you side with the pirates or the Dominators, with their own promotions and story | — |
| Maps as mission rewards | Missions pay in money, equipment **and sector maps that unlock new space** | The charts are complete from the start |

### Ships, equipment and money

| Idea | What Space Rangers does | Oolite today |
| --- | --- | --- |
| **Size is everything** | Hull size is hit points, equipment capacity and cargo capacity; cargo is the remainder after fitting | Cargo capacity and equipment are largely independent |
| Slots that can be traded away | Special hulls swap a weapon or artifact slot for a bonus | Equipment mounts are fixed per ship |
| Compactness costs upkeep | Smaller weapons take less space but generally cost more to repair | Equipment has a price and a tech level |
| Modify what is installed | Micromodules alter fitted equipment, most usefully by reducing its size | Equipment is as bought |
| A separate artifact pool | 0–4 slots for alien artifacts, independent of ordinary equipment | — |
| A droid that fixes hull only | In-flight hull repair that explicitly does not touch equipment, with an efficiency worth scaling to hull size | Repairs happen at stations; the maintenance overhaul resets wear |
| Upkeep by manufacturer | Where a part was made determines its maintenance cost, which makes the races mechanically distinct | Ships and equipment vary by price and availability |
| Unique parts from the unbuyable enemy | Dominator wreckage yields equipment no shop sells | Mission rewards |

### Content and structure

| Idea | What Space Rangers does | Oolite today |
| --- | --- | --- |
| Text quests as a content format | Dozens of named, self-contained interactive-fiction puzzles with their own internal rules, played on landing, paying in money, reputation or gear | Missions are scripted encounters and station messages |
| A minigame that is a strategic verb | Planetary battles are an RTS you fight to **liberate a planet**, with the option to drop into third-person control of any unit | — |
| A third mode for a real decision | Hyperspace pursuit as arcade combat — the mechanical consequence of choosing to chase | Witchspace misjumps and interception exist |
| Expansions that add content, not systems | *Reboot* and *A War Apart* shipped text quests, battle maps and government missions by the dozen | This is what OXPs do |
| Careers that emerge | No classes: trader, pirate, warrior, mercenary, liberator and corsair are descriptions of what you did | Oolite works the same way, and it is worth noticing that this is already a strength |

### Rules worth stealing outright

- **One number with three jobs beats three numbers.** Hull size as hit points, equipment space and
  cargo space is the cleanest idea in this folder.
- **Make the simulation observable or do not build it.** News on every landing screen, a leaderboard
  for your rivals, medals you can see on other people's records. A galaxy that changes invisibly is
  a galaxy that does not change.
- **Let the world be able to finish without the player.** An ending the simulation can reach on its
  own is what makes the middle of the game mean anything.
- **Give the minigame a strategic consequence.** The RTS liberates a planet; the arcade chase catches
  a runner. A diversion with a persistent-world outcome is content; one without is filler.
- **Prefer content formats that cost writing to ones that cost engineering.** A fifteen-person team
  shipped dozens of text quests, and they are the most-remembered part of the game.
- **Make the manufacturer a stat.** If the galaxy has races, let where a thing was built change what
  it costs to own.
- **Let the world win as well as lose.** A simulation that can resolve its own crisis in either direction
  makes the player a participant rather than the protagonist, and it is the reason to check the news.
- **Hold territory with infrastructure, not with a number.** A system that cannot fall while its stations
  stand gives an attacker something to do and a defender something to protect.
- **Let the player join the enemy**, if the enemy has an organisation to join.

### What not to take

- **The interface.** Universally criticised at the time and the main reason people bounce off it.
  The pairing with the Freelancer reference is the point: an alive galaxy and a good front door are
  separate decisions, and this game only made one of them.
- **The opening.** The Dominators vastly outclass a new player and the game does not explain the
  answer, which reviewers named as a lack of structure.
- **The translation**, for obvious reasons, and as a reminder that localisation quality is part of
  the product.
- **Three engines in one game.** An RTS and a third-person shooter alongside the space game is what a
  fifteen-person team could do in 2004 with 2004 expectations; the maintenance cost of that decision
  is visible in how little polish any one of them has.
- **Micromodule and upkeep bookkeeping at full depth.** The per-item, per-manufacturer maintenance
  optimisation is a spreadsheet. Take per-item condition; leave the spreadsheet.
- **Turn-based movement.** It is what makes the galaxy simulation affordable here, and it is not
  available to Oolite. Worth knowing as the reason, not as a suggestion.

## Sources

The weakest sourcing in the folder: no manual, no official wiki, and community material that is
often several patches behind. Grouped by what each was trusted for.

### Encyclopedic

- **[Wikipedia: Space Rangers 2: Dominators](https://en.wikipedia.org/wiki/Space_Rangers_2:_Dominators)**
  — release dates and publishers across four territories, the development history (Vladivostok,
  ~15 people, ~18 months, the Katauri Interactive split, Dubovoy's support until 2007), the setting
  and races, the genre list, turn-based movement in solar days, planetary battles and the
  third-person view, dynamic supply and demand, mission types, the *Reboot* and *HD: A War Apart*
  versions, Metacritic and the individual reviews, and the awards
- [Wikipedia: Space Rangers (2002)](https://en.wikipedia.org/wiki/Space_Rangers_(video_game)) — the
  original

### Official descriptions

- **[GOG: Space Rangers HD: A War Apart](https://www.gog.com/en/game/space_rangers_hd_a_war_apart)**
  — the publisher's own statements that all player actions affect what the galaxy becomes, that it
  may end with a victorious Coalition or a collapsed alliance, and that **the balance of either war
  may be tipped by AI action as well as the player's**; the pirate campaign, the option to side with
  pirates or Dominators, the content counts for the remaster, and the technical changes

### Contemporary reviews

Used for the things only someone playing in 2005 recorded.

- [GameSpot: Space Rangers 2 review](https://www.gamespot.com/reviews/space-rangers-2-rise-of-the-dominators-review/1900-6147698/)
  and [first impressions](https://www.gamespot.com/articles/space-rangers-2-rise-of-the-dominators-first-impressions/1100-6142753/)
  — the *Star Control II* comparison, and the note that Dominator debris yields unique parts
- [GameSpot: the races and ships of Space Rangers 2](https://www.gamespot.com/articles/space-rangers-2-profile-preview-the-races-and-ships-of-space-rangers-2/1100-6144080/)
- [RPGDot/RPGWatch review](https://rpgdot.rpgwatch.com/localhost/rpgdot.rpgwatch.com/httpdocs/indexf173.html?hsaction=10053&ID=1189)
  — the **~60 randomised star systems** figure, the other rangers "in direct competition", the
  **ranking system and leader board**, and galactic news on the planet screen
- [GameSpot hands-on](https://www.gamespot.com/articles/space-rangers-2-rise-of-the-dominators-hands-on/1100-6144713/)
- [RPG Codex review: “doesn’t scale to your level”](https://rpgcodex.net/content.php?id=126)
- [MobyGames](https://www.mobygames.com/game/19891/space-rangers-2-dominators/) — credits and releases
- [Metacritic](https://www.metacritic.com/game/space-rangers-2-rise-of-the-dominators/) — the
  aggregate and the review spread
- [TheGamer: Space Rangers 2 Is A Game You Should Play](https://www.thegamer.com/space-rangers-2-must-play/)
  — the 2020 retrospective

### Player accounts

The source for how the front behaves in practice, since no documentation of it exists.

- [Space Rangers 2 after-action report](https://calltoreason.org/?p=2315) — black holes as the Dominator
  attack vector, stations blocking capture, military bases jumping to occupied systems, joining an
  operation by docking at the organising base, a liberated system falling again when surrounded,
  the unreliable economics of fighting Dominators, and the observation that on higher difficulty the
  war can resolve either way without the player

### Community wikis and guides

Flagged in the text because several warn they are out of date.

- [Space Rangers wiki: standard equipment](https://spacerangers.fandom.com/wiki/Standard_Equipment),
  [medals](https://spacerangers.fandom.com/wiki/Medals) and
  [planetary battle](https://spacerangers.fandom.com/wiki/Planetary_battle) — the equipment list,
  the Ranger Rating screen showing medals per ranger, and the RTS minigame's role in liberating
  planets
- [Space Rangers HD wiki: hulls](https://space-rangers-hd.fandom.com/wiki/Hulls) — **hull size as
  hit points, equipment space and cargo space**, and the special hulls that trade slots for bonuses
- [Steam: The Complete English Guide for SR HD](https://steamcommunity.com/sharedfiles/filedetails/?id=253596035),
  [Starting guide](https://steamcommunity.com/sharedfiles/filedetails/?id=593039410) and
  [SR HD tips](https://steamcommunity.com/sharedfiles/filedetails/?id=1929133700) — micromodules,
  artifact slots, repair droid efficiency, repair costs by weapon size, and the Gaalian-parts upkeep
  advice
- [Steam: guide to all text-based planetary quests](https://steamcommunity.com/sharedfiles/filedetails/?id=3484784064)
  — the text-quest names
- [RPG Codex: a comprehensive guide to Space Rangers 2](https://rpgcodex.net/forums/threads/a-comprehensive-guide-to-space-rangers-2.36215/)
- [Before I Play: Space Rangers HD](https://beforeiplay.com/index.php?title=Space_Rangers_HD)

### Oolite

- [Oolite Feature Ideas](<../../notes/Oolite Feature Ideas.md>) — the "A living world" row this
  reference answers most directly, and the wave-defence note at the end
- [Freelancer](<Freelancer — Feature Reference.md>) — the opposite trade: best interface, most inert
  galaxy
- [X4: Foundations](<X4 Foundations — Feature Reference.md>) — a galaxy that moves economically, and
  the message ticker as the same observability idea
- [Stellaris](<Stellaris — Feature Reference.md>) — crises as the other way to give a sandbox an
  ending
- [Wing Commander: Privateer](<Wing Commander Privateer — Feature Reference.md>),
  [EVE Online](<EVE Online — Feature Reference.md>),
  [EVE Online — Modules and Fitting](<EVE Online — Modules and Fitting Reference.md>),
  [Elite Dangerous](<Elite Dangerous — Feature Reference.md>),
  [Frontier: Elite II and First Encounters](<Frontier Elite II and First Encounters — Feature Reference.md>),
  [Elite (1984)](<Elite (1984) — Feature Reference.md>) — the rest of the set
