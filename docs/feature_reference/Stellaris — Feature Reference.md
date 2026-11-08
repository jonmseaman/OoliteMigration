# Stellaris — Feature Reference

Nov 7, 2026 · @Jon Seaman

Stellaris is the odd one out and this reference says so up front. You never fly anything. There is no
cockpit, no cargo hold, no docking; a fleet is a counter you move between star systems and combat
resolves itself while you watch. Most of the game — pops, districts, jobs, ethics, federations,
ascension paths — has no analogue in Oolite and should not acquire one.

It earns a reference for four things that nothing else in this set does well:

1. **Galaxy generation as player-facing configuration.** Twenty-odd sliders that produce a different
   galaxy, exposed on the setup screen rather than buried in a config file. The ideas doc already
   wants this — the "Custom galaxies" row, from Amiga Elite — and Stellaris is the best worked
   example of what the settings should be.
2. **An authored content library keyed to procedurally generated objects.** The galaxy is random;
   the anomalies, archaeology sites, precursor chains and event chains attached to it are
   hand-written, and they attach by *predicate* — any gas giant, any habitable planet, any star.
   That is exactly the architecture an expansion ecosystem wants, and Stellaris has more of it than
   any other game here.
3. **A crisis system with a strength dial.** Mid-game and end-game crises that arrive on a schedule
   you configure, scaled by a multiplier that runs from off to 25×, with the explicit job of making
   the late game hard again. The ideas doc's Thargoid rows and X4's Existential Crisis are both
   reaching for this.
4. **A nine-year performance story with a published rewrite.** Stellaris's late-game slowdown is the
   canonical example of a simulation outgrowing its own data model, and in 2025 Paradox rewrote the
   core of it in public. For a project that has just finished a language migration and is now doing
   performance work, that is the most useful part of this document.

**On sources.** Stellaris is unusually well documented: the Paradox wiki is detailed, versioned and
reasonably current (its galaxy-settings page is marked verified for 4.4), and patch notes are
published per release. Most figures here come from that wiki. Mod-count figures are community
numbers from different years and are flagged. Where the wiki warns that something is undocumented
and may change between versions — which it does about the mod override rules — that warning is
repeated here.

**On scope.** The sections below cover what is transferable and summarise the rest in a line. This
is deliberately the shortest reference in the folder relative to the size of its subject.

## Overview and timeline

| Item | Value |
| --- | --- |
| Release | **9 May 2016**, Windows, macOS and Linux |
| Developer | Paradox Development Studio; published by Paradox Interactive |
| Engine | **Clausewitz**, in use at the studio since *Europa Universalis III* (2007), with later additions such as physically based rendering |
| Genre | 4X grand strategy, real-time with pause |
| Current version | **4.5 "Cygnus"**, 22 September 2026; 4.5.3 hotfix in early November 2026 |
| Galaxy | Procedural, 200–1000 stars, systems as nodes joined by **hyperlanes** |
| Start date | 1 January 2200; default campaign 300 years |
| Expansions | **26** paid packs from August 2016 to June 2026 |
| Influences | *Star Control II*, *Master of Orion 2*, *Europa Universalis IV*, per director Henrik Fåhraeus |
| Sales | 200,000 in the first 24 hours (a Paradox record at the time), 500,000 by June 2016, **over 3 million by May 2020** |
| Metacritic | 78/100 |
| Mods | Well over 20,000 Steam Workshop items — community figures, see below |

### How it is updated

The cadence is worth noting on its own, because it is the opposite of Egosoft's: Paradox ships a
**free named update** alongside a **paid pack**, several times a year, and has done so for ten years.
Update names were science-fiction authors until 2022 (Cherryh, Niven, Le Guin, Dick) and constellations
since (Libra, Phoenix, Cetus, Pegasus, Cygnus).

| Version | Date | What it did |
| --- | --- | --- |
| **4.5 "Cygnus"** | 22 Sep 2026 | Current. A 4.5.1 hotfix two days later made fleet automation follow the options you actually selected rather than choosing for itself |
| 4.4 "Pegasus" | 15 Jun 2026 | Shipped with the **Nomads** expansion |
| 4.3 "Cetus" | May 2026 | **Walked 4.0 back**: cuts to unity generation, planetary ascensions and per-pop jobs, to undo the "supercharged navies and economies" 4.0 had introduced |
| **4.0 "Phoenix"** | May 2025 | The pop rework. See below |
| 3.0 "Dick" | Apr 2021 | |
| 2.2 "Le Guin" | Dec 2018 | Introduced the Pop and Jobs economy — and, with it, the performance problem 4.0 was built to fix |
| 2.0 "Cherryh" | Feb 2018 | Replaced free-form FTL with the hyperlane network |
| 1.0 | May 2016 | Release |

### The expansions

Twenty-six packs in four flavours — Expansion, Story Pack, Species Pack and more recently
"Mechanical Expansion" and "Narrative Expansion". The full list, because the shape of it is the
interesting part:

| Pack | Type | Date |
| --- | --- | --- |
| Plantoids | Species | 4 Aug 2016 |
| Leviathans | Story | 20 Oct 2016 |
| Utopia | Expansion | 6 Apr 2017 |
| Synthetic Dawn | Story | 21 Sep 2017 |
| Humanoids | Species | 7 Dec 2017 |
| Apocalypse | Expansion | 22 Feb 2018 |
| Distant Stars | Story | 22 May 2018 |
| MegaCorp | Expansion | 6 Dec 2018 |
| Ancient Relics | Story | 4 Jun 2019 |
| Lithoids | Species | 24 Oct 2019 |
| Federations | Expansion | 17 Mar 2020 |
| Necroids | Species | 29 Oct 2020 |
| Nemesis | Expansion | 15 Apr 2021 |
| Aquatics | Species | 22 Nov 2021 |
| Overlord | Expansion | 12 May 2022 |
| Toxoids | Species | 20 Sep 2022 |
| First Contact | Story | 14 Mar 2023 |
| Galactic Paragons | Expansion | 9 May 2023 |
| Astral Planes | Narrative | 16 Nov 2023 |
| The Machine Age | Expansion | 7 May 2024 |
| Cosmic Storms | Mechanical | 10 Sep 2024 |
| Grand Archive | Story | 29 Oct 2024 |
| BioGenesis | Expansion | 5 May 2025 |
| Shadows of the Shroud | Mechanical | 22 Sep 2025 |
| Infernals | Species | 25 Nov 2025 |
| Nomads | Expansion | 15 Jun 2026 |

Three observations. The **Species Packs are cosmetic-plus**: portraits, ships, a few traits and
civics, sold at a lower price — a tier of paid content that is almost entirely art. The **Story
Packs** are content libraries: events, anomalies, archaeology, a crisis. And the newer labels
("Mechanical", "Narrative") exist because the old three stopped describing what was being sold.

An expansion ecosystem that has run for a decade at several packs a year, where the mechanics are
free and the content is paid, is the same split Egosoft uses — and it is worth noting that the two
most successful long-lived space games in this folder both chose it.

## Galaxy generation

This is the section to copy. Every one of these is on the new-game screen, and together they are the
best available answer to what "custom galaxies" should mean.

### Size and shape

| Size | Stars | Max AI empires | Max fallen empires | Max marauders | Recommended crisis strength |
| --- | --- | --- | --- | --- | --- |
| Tiny | 200 | 6 | 1 | 1 | 0.5× |
| Small | 400 | 12 | 2 | 2 | 0.75× |
| Medium | 600 | 18 | 3 | 2 | 1× |
| Large | 800 | 24 | 4 | 3 | 1.25× |
| Huge | 1000 | 30 | 6 | 3 | 1.5× |

Ten galaxy shapes, each with a minimum size: **elliptical, two-arm spiral, ring** and **barred
spiral** from Tiny; **three-arm spiral** from Small; **four-arm spiral, starburst, cartwheel** and
**spoked** from Medium; **six-arm spiral** from Large.

Note what the size table is doing: it does not merely scale the star count, it scales **how many
other actors the galaxy can hold**, and it carries a *recommended* crisis multiplier so the late
game stays proportionate. The recommendation is advice, not a constraint.

### The rest of the setup

| Setting | Range |
| --- | --- |
| **Hyperlane density** | 0.5× to 2.75×, or **Full** — which removes clusters and choke points entirely |
| AI empires | capped by size, with an optional **50% randomisation** |
| Advanced AI starts | how many AI empires begin with a head start (500 alloys, 150 unity, 200 influence and more); only eligible origins can take it |
| Fallen empires | capped by size, with their **starting strength set separately, 0.25× to 5×** |
| Marauder empires | capped by size, optional 50% randomisation |
| **Habitable worlds** | **Rare** — no habitable planets outside special systems — then 0.25× to 5× |
| Guaranteed habitable worlds | 0, 1 or 2 **per empire** |
| Pre-FTL civilisations | off, then 0.25× to 5× |
| Pre-sapient species | off, then 0.25× to 5× |
| Empire placement | clustered or random |
| Resource abundance | 0× to 5× |
| **Precursors** | a toggle **per precursor civilisation**, so you choose which ancient-empire content can appear |
| Technology and tradition cost | a multiplier that feeds the research cost formula |

The two most interesting entries are the ones that are not multipliers. **Hyperlane density "Full"**
turns a galaxy with chokepoints into a galaxy without them, which changes the entire strategic
character of a campaign from one dropdown. And **the precursor toggles** let the player choose which
*authored content* is eligible to appear — a content filter on the setup screen, which is a very
unusual thing to expose and exactly the thing a game with hundreds of expansions might want.

### Difficulty, stated as multipliers

Seven levels — Civilian, Cadet, Ensign, Captain, Commodore, Admiral, Grand Admiral. Easier levels
give the *player* bonuses; harder ones give the AI bonuses and **strengthen the endgame crisis**.
Then three modifiers on top:

- **Scaling difficulty**: AI and spaceborne-alien bonuses start at zero and ramp to their full value
  by the mid-game or end-game year, so the difficulty setting describes the *end* of the campaign
  rather than the beginning.
- **Difficulty-adjusted AI modifiers**: scales the AI's economic multipliers.
- **Difficulty-adjusted technology costs**: raises tech costs at higher levels.

**Ironman** is a separate mode: no manual saving, a single save file overwritten after significant
actions, and **the console disabled**. It is the mechanism that makes achievements meaningful, and
the honest version of the same idea Privateer's permanent-failure state was reaching for.

### Victory, or not

**Mid-game start year** has a floor of 2225; **end-game start year** a ceiling of 3000 and must come
after the mid-game year; **victory year** can only be set after the end-game year, and setting it to
maximum **disables victory altogether**. An active crisis prevents the game ending even past the
victory year.

So the campaign's three acts are player-set numbers, and "no victory condition, just keep playing"
is a supported configuration rather than a mod.

## The content library

Stellaris's galaxy is generated and its content is written, and the join between the two is the part
worth studying. The wiki's anomaly page alone runs to about 228,000 characters of tables; the volume
is the point.

### Anomalies

A **science ship** surveying a system can turn up an **anomaly**. The mechanics:

- Each anomaly is **bound to a class of celestial object** — any star, any planet, a habitable
  planet, an uninhabitable planet, or a specific type such as asteroid, gas giant or frozen world.
  Some are excluded for gestalt or machine empires. So an anomaly is authored content with a
  *predicate* for where it can attach, and the generator decides where that is.
- Each has a **discovery level from 1 to 8**.
- **Each outcome fires once per empire.** When all of an anomaly's outcomes have been used up, that
  empire stops finding it — so a long campaign exhausts the library rather than repeating it.
- Investigating usually presents a **choice**, typically a permanent resource deposit against a
  **special project** with a bigger or stranger payoff. Outcomes include deposits, scaled research,
  one-off resources, planetary features, edicts, **ships**, technologies, **leader traits**,
  experience, empire-wide modifiers, and **event chains**.
- Some outcomes have extra options **conditional on your ethics, civics or origin**, so the same
  anomaly reads differently to different empires.
- Risk is per-outcome rather than global: the Distress Signal anomaly has a special project with a
  **30% chance of destroying the ship**.

Several of the housekeeping rules are the kind of thing you only write after shipping: if an anomaly
grants a deposit needing a different station type, the old deposit is removed; if it grants an
expertise trait the scientist already has, they get 200 experience instead. Content that attaches to
generated objects needs that sort of conflict handling, and it is worth knowing in advance that you
will be writing it.

### Archaeology, precursors and chains

Anomalies are the entry point to longer structures. Some outcomes **spawn archaeology sites** — the
Crash Site anomaly leads to the Seeds of Destruction dig — and others start **event chains** that run
for many steps. **Precursor** chains are multi-stage mysteries about ancient empires, and which ones
are eligible is a galaxy setting.

The shape is: a one-screen discovery can open a multi-session storyline, and the storyline is
authored, not generated. That is the thing Oolite's mission OXPs already do and the thing a shared
content format would make easier to do a hundred times.

## Crises

The late game gets harder on purpose, and the machinery is explicit enough to copy.

### Mid-game crises

Four, each tied to a DLC mechanic rather than the end-game spawn system: **The Horde** (marauders),
**The Gray Tempest** (the L-Cluster), **The Formless** (the Crystal Rift) and **The Voidworm
Plague** (spaceborne aliens).

### End-game crises

Normally **one per game**, and two cannot start within 25 years of each other. Every **five years**
the game checks eligibility against: the end-game year and how long since it passed, whether anyone
has Jump Drive or Psi Jump Drive technology, whether the Galactic Threats Committee or
Extradimensional Experimentation resolutions have passed, and whether fallen or awakened empires
exist. A **weighted roll** then picks one, and its event chain begins **200 to 1000 days later**.

| Crisis | Notes |
| --- | --- |
| **Extradimensional Invaders** | The only one that can arrive early, via the Ancient Robot World site or either resolution. Its weight **rises with time since the end-game year** |
| **Prethoryn Scourge** | Base weight 10, rising over time |
| **The Contingency** | Base weight 10. The only crisis that lets the Ancient Caretakers awaken |
| **The Synthetic Queen** | Base weight 10. From The Machine Age |

### The dial

**Crisis strength** runs from off through 0.25× to **25×**, and it multiplies crisis **hull, shields,
armour and damage — but not fire rate**. Mid-game crises get the **square root** of the bonus, so the
same slider scales the two tiers differently. With the "All" setting, every crisis you defeat
**doubles the strength of the remaining ones**, and killing one quickly earns a further multiplier
(×1.5 within five years of its determination, ×1.25 within ten), which stack.

Beating one is a galaxy-wide event: every empire gets +10% happiness for ten years and a large unity
payout, the Galactic Community can pass a resolution to fight it, and fallen empires may **awaken as
Guardians of the Galaxy** to help.

Three ideas in there are worth taking whatever the genre. **Difficulty as a multiplier on specific
stats**, named, so the player knows what the dial does. **A square root for the lesser tier**, so one
setting serves both. And **a reward for the whole galaxy**, so the crisis is a shared event rather
than the player's private boss fight.

## Research

Stellaris has no technology tree. It has a **deck**.

- Three research areas — **Physics, Society, Engineering** — each with its own resource, 13
  subcategories between them, and roughly **400 technologies**.
- When a project finishes, the game **draws a new hand** of alternatives from a hidden deck of
  everything currently valid. The base hand is **three**, raised by civics, edicts and traditions.
- Each technology has a **weight**, modified by your ethics, civics, leader traits and what you have
  already researched. **A technology that appeared in the previous hand has its weight halved** in
  the next draw, which keeps hands moving.
- **Rare technologies** sit at roughly **one-eighth weight** without matching expertise, ×2 if a
  Research Cooperative partner already has it, ×1.5 with the Technological Ascendancy perk.
- **Six tiers, T0 to T5.** A tier becomes eligible only after you have researched **six technologies
  from the preceding tier in the same area** — so progress is gated by breadth, not by named
  prerequisites.
- **Permanent alternatives**, marked with a **golden border**, come from debris, special projects,
  anomalies, archaeology, situations and events. They stay in every hand until researched.
- **Debris**: destroying hostile ships leaves wreckage, and each component gives **10% progress**
  toward that technology or an unresearched prerequisite. Ship upgrades, hull sizes, repeatables and
  psionics cannot come from debris, and the Enigmatic Engineering perk stops enemies looting yours.
- Cost rises with **empire size**: +0.2% per point above 100. Partial progress is stored as an
  absolute value, so it does not rescale when costs change.

Two transferable ideas. The first is **a weighted draw instead of a tree**: you never see the whole
space, every campaign unlocks things in a different order, and tuning is a matter of weights rather
than topology. The second is **the golden-bordered permanent alternative** — a thing you found in the
world appearing in your list of purchasable options, permanently, until you take it. For Oolite that
is the natural shape for an equipment unlock earned by exploration rather than by tech level.

## The parts that do not transfer

Recorded briefly so the omission is deliberate.

**Empire design.** Origin, eight **ethics** on four mutually exclusive axes (each available
fanatically or moderately), civics, government type, species traits. It is the best part of the game
and it is character creation for a civilisation, which Oolite is not about.

**Pops and the economy.** Six resources — energy credits, minerals, food, consumer goods, alloys,
trade — plus unity for edicts and traditions. Planets have districts with **specialisations** that
add jobs, worked by population. This is the system the performance story below is about.

**Diplomacy.** Opinion, envoys, federations, and a **Galactic Community** that passes resolutions by
vote — legislation as a game system, including the resolutions that help summon or fight a crisis.
Reviewers at launch called the diplomacy simple and the AI passive, and ten years of expansions have
been answering that.

**Fleets and war.** A fleet is a stack with a fleet power number; ships are designed from sections and
component slots with behaviour set by a combat computer, then combat resolves without input. Armies
invade planets. There is nothing here for a game where the player flies one ship.

**Ascension.** Genetic, cybernetic, psionic and synthetic paths in the late game, each rewriting your
species. Lovely, and irrelevant here.

## The performance story

This is the section with the most direct bearing on the migration work, and it is a decade-long case
study in a simulation outgrowing its data model.

**The cause.** Version **2.2 "Le Guin"** (December 2018) replaced the old tile-based planets with the
**Pop and Jobs** economy: individual population units, each with a species, a stratum, ethics and a
faction, each looking for a job, each recalculated on a tick. It was a much better game. Paradox's own
later words are that the system "has always had significant performance implications in the late
game" — because the number of pops grows through the campaign, and the per-pop work grows with it. A
Stellaris campaign that crawls by year 2400 was a known, accepted, joked-about property of the game
for **six and a half years**.

**The fix.** Version **4.0 "Phoenix"** (May 2025) rewrote the representation. Pops are now aggregated
into **Pop Groups** keyed by species, stratum, ethics and faction, and a group produces **workforce**
that fills jobs. Effects that used to apply to one pop now apply to **groups of 100**. The stated
goal was the late game, and the stated benefit was headroom: more ability to support many pops
growing on a planet at once.

**The collateral.** Two things went with it, and both are instructive.

- **Trade routes were simplified out.** The reason given is the cleanest cost/benefit statement in
  any of these references: the old system had a *"disproportionately high impact on performance
  compared to the benefit \[it provides]"*. A feature was removed because its runtime cost was not
  earning its keep.
- **It was a rocky launch.** Lag, crashes and bugs, several hotfixes inside the first week, and a
  known issue — very small pop groups created by ethics shifts — that Paradox judged **"too risky"**
  to fix in that update. Coverage and players disagreed about whether performance was better at all:
  the late game improved, and the **early game got slower on low-spec machines**, because
  aggregation has fixed overhead that small populations do not amortise.
- **The balance had to be walked back too.** 4.0 produced "supercharged navies and economies", and
  **4.3 "Cetus"** a year later cut unity generation, planetary ascensions and per-pop jobs across the
  board. Changing the unit of simulation changed every number that referenced it.

Four lessons worth writing down:

1. **The data model is the performance ceiling.** No amount of optimisation inside a per-pop loop
   fixes a design where the number of pops grows without bound. The fix was changing what the
   simulation's unit *is* — which is the same shape as de-globalising to make a headless in-process
   sim possible.
2. **Aggregation moves cost, it does not remove it.** Grouping helped the case that was dying and hurt
   the case that was fine. A benchmark that only measures the late game would have called this a
   clean win; the complaints came from the early game.
3. **Changing the unit invalidates the tuning.** Every balance number downstream of "per pop" needed
   revisiting, and it took until 4.3 to finish.
4. **Cutting a feature is a legitimate optimisation**, and saying so plainly — cost disproportionate
   to benefit — is better than keeping it and apologising for the frame rate.

## Modding

Stellaris has one of the largest mod ecosystems in PC gaming and a conflict model that is noticeably
worse than X4's. Both halves of that are useful.

### How a mod is built

- A `.mod` descriptor the launcher reads, plus a folder that **mirrors the game's own structure** —
  `common/`, `events/`, `gfx/`, `interface/`, `localisation/`, `music/`. Newer launchers also want a
  `descriptor.mod` and a `thumbnail.png`.
- Content is **plain text**: `.txt` script, `.yml` localisation, `.gfx`/`.gui` interface, `.dds`
  images, `.ogg` and `.wav` audio, `.asset` definitions. UTF-8 throughout, and **UTF-8 with BOM**
  for localisation and name lists.
- The game loads **every file in a folder**, so the guidance is to add uniquely-prefixed new files
  rather than replace the game's own.
- Scripted **effects**, **triggers**, **modifiers**, **variables** and **localisation** are all
  reusable named blocks.

### How overriding actually works

This is the part worth reading twice. Override behaviour is **per folder**, with four different
semantics:

| Rule | Behaviour |
| --- | --- |
| **FIOS** | first in, only served — the earliest definition wins |
| **LIOS** | last in, only served — the latest wins, and duplicate-key errors may appear in the log even though it worked |
| **DUPL** | duplicates are kept and **both take effect** |
| **NO / MERGE** | the folder cannot be overridden entry by entry, or new entries merge into existing ones |

Load order is **ASCIIbetical by filename**, falling back to the launcher's mod order, with mods at
the top loading first since patch 2.5. The community's workarounds are naming hacks: prefix a mod
with `~` to force it to the top or `!` to push it to the bottom. `on_actions` **merge** rather than
override, and load order decides their internal sequence. Scripted variables are FIOS, so a name
already taken blocks a new definition. For ordinary localisation keys, **the translation with the
smallest UTF-8 byte sequence wins** — a rule nobody would guess.

And the wiki's own warning about the per-folder table: **this is undocumented and may change between
versions.**

### What that produces

- **Compatibility patches as a genre.** Because two mods touching the same content collide, the
  ecosystem has a whole class of mod whose only job is to reconcile two others, loaded after both,
  usually in a separate section at the end of the list. The `dependencies` field exists to force that
  ordering.
- **Multiplayer requires identical mod lists and load order** for every player.
- **A merge tool in the workflow**, because a new game patch changes the vanilla files a mod replaced.

Compare X4, where a mod selects nodes with **XPath** and the server composes the diffs, so two mods
can edit the same file without knowing about each other. X4's format is plainly better engineering.
Stellaris's ecosystem is many times larger.

The conclusion is not comfortable but it is probably right: **ecosystem size is driven by content
volume, audience and script legibility, not by the elegance of the conflict model.** Plain text files
in named folders that anyone can read and copy got Paradox tens of thousands of mods with an override
system whose rules are undocumented. If Oolite wanted both, the lesson is that legibility comes
first and composition is the thing you can fix later — but that fixing it later means compatibility
patches in the meantime.

### Scale

Community figures from several different years, which is why they disagree:

- Paradox's own social accounts said **over 12,000** mods and later **almost 15,000** — both in 2019.
- PCGamesN has cited **over 22,000**.
- The Workshop's own category pages show roughly **9,100 under Gameplay** and about **2,300 under
  Events** alone.
- Nexus Mods lists about 168, which says more about Nexus than about Stellaris.

Treat "well over 20,000 Workshop items, of which a couple of thousand are event content" as the
defensible reading.

## Scale numbers

From the Paradox wiki unless marked. Its galaxy-settings page is verified for 4.4.

| Quantity | Value |
| --- | --- |
| Release to now | 9 May 2016 → **4.5 "Cygnus"**, September 2026 |
| Paid packs | **26**, Aug 2016 to Jun 2026 |
| Galaxy size | **200 to 1000** stars, five presets |
| Galaxy shapes | **10**, gated by minimum size |
| Hyperlane density | 0.5× to 2.75×, or **Full** |
| AI empires | up to **30** at Huge |
| Fallen empires | up to **6** at Huge, strength 0.25× to 5× |
| Habitable worlds | **Rare**, then 0.25× to 5× |
| Guaranteed habitable worlds | 0, 1 or 2 per empire |
| Resource abundance | 0× to 5× |
| Difficulty levels | **7**, Civilian to Grand Admiral |
| **Crisis strength** | off, then 0.25× to **25×** |
| Crisis scaling | multiplies hull, shields, armour and damage; **not fire rate**; mid-game crises get the **square root** |
| End-game crisis checks | every **5 years**; chain begins **200–1000 days** after the roll |
| Crises per game | **1** normally; two cannot start within **25 years** |
| End-game crisis base weights | **10** each for Prethoryn, Contingency and Synthetic Queen |
| Mid-game crises | **4** |
| Start date | 1 January **2200** |
| Mid-game year floor | **2225** |
| End-game year ceiling | **3000** |
| Victory | set after the end-game year; **maximum disables it** |
| Technologies | about **400**, across 3 areas and 13 subcategories |
| Research hand | **3** alternatives by default |
| Repeat suppression | a technology seen last hand has its weight **halved** |
| Technology tiers | **6** (T0–T5); each needs **6** researched from the tier below, same area |
| Rare technology weight | about **1/8** without matching expertise |
| Debris | **10%** progress per recovered component |
| Research cost scaling | **+0.2%** per point of empire size above 100 |
| Anomaly discovery levels | **1 to 8** |
| Anomaly outcomes | each fires **once per empire**; exhausted anomalies stop appearing |
| Pop aggregation (4.0) | effects now apply to groups of **100** |
| Sales | 200k in 24 hours; 500k by June 2016; **3M+ by May 2020** |
| Metacritic | **78/100** |
| Workshop mods | **20,000+** items; ~9,100 Gameplay, ~2,300 Events (community figures) |
| Mod override rules | **4** — FIOS, LIOS, DUPL, NO/MERGE — assigned **per folder**, undocumented |

### What could not be verified

- **Whether a paid pack shipped with 4.5 "Cygnus".** Wikipedia's DLC list ends at Nomads (June
  2026) and 4.5 arrived in September 2026. Either nothing was paired with it or the list lags.
- **The 4.5.3 date.** One tracker lists an open beta on 28 October 2026 and another a release on
  4 November 2026. Both are probably right about different builds.
- **Default mid-game and end-game years.** Forum posts consistently say 2275 and 2325, which look
  like the defaults, but no official source consulted states them. The wiki gives the limits, not
  the defaults, and does not publish defaults for most settings.
- **Whether 4.0 improved performance overall.** The late game improved; the early game got slower on
  low-spec machines; coverage and players disagree about the net. No benchmark from either side was
  found.
- **Total anomaly, event and archaeology-site counts.** The wiki's anomaly page is 228,000 characters
  of tables and no summary count was located.
- **What an anomaly's discovery level 1–8 actually changes.** The levels are documented; their effect
  is not, in the part of the page retrieved.
- **A current mod total.** Paradox's own figures are from 2019 and the Workshop reports per-category
  counts rather than a total.
- **The ship designer and fleet combat in any depth.** Deliberately not researched; it is the least
  transferable system in the game.

## Ideas for Oolite

Most of Stellaris is a different game and this section is short on purpose. What it has that Oolite
could use is **configuration, content architecture, a late-game difficulty structure, and a
cautionary tale about data models.**

### Five that fit best

1. **Galaxy generation as a setup screen.** Size, shape, hyperlane density, habitable-world
   frequency, resource abundance, how many rival actors, where they start, and which authored content
   is eligible — all exposed, all with stated ranges, with a *recommended* crisis multiplier per
   size rather than a forced one. The ideas doc's "Custom galaxies" row (from Amiga Elite) asks for
   this and Stellaris is the specification. Oolite's galaxy seeds are fixed; the interesting version
   is not "let players edit the seed" but "let players set the parameters the generator reads".
2. **Authored content attached to generated objects by predicate.** An anomaly declares the *kind*
   of object it can appear on — any gas giant, any frozen world, any habitable planet — and the
   generator decides where. Oolite already generates systems procedurally and already has OXPs full
   of authored content; this is the join between them, and it is what would let a hundred expansions
   add discoveries without any of them naming a system.
3. **Each outcome fires once, and the library exhausts.** An anomaly whose outcomes you have all seen
   stops appearing for you. That single rule is the difference between an exploration layer that
   stays interesting for a campaign and one that becomes wallpaper in an hour — and it is the thing
   procedurally generated content cannot do for you.
4. **A crisis with a dial that says what it multiplies.** Mid-game and end-game crises on a schedule
   the player sets, scaled by a multiplier that is documented as applying to hull, shields, armour
   and damage but *not* fire rate, with the lesser tier getting the square root of the same number,
   and a galaxy-wide reward when it is beaten. Oolite has Thargoids as ambient opposition; this is
   the structure that would turn them into an endgame.
5. **Permanent options earned from the world.** Stellaris marks technologies you found — in debris,
   in an anomaly, at a dig — with a golden border, and they stay available until you take them.
   For Oolite that is the natural shape for equipment unlocked by exploration rather than by tech
   level: not a reward handed over, but a thing that appears in the outfitter from now on.

### Galaxy and setup

| Idea | What Stellaris does | Oolite today |
| --- | --- | --- |
| Generation parameters as settings | ~20 sliders and toggles on the new-game screen, each with a stated range | Eight charts of 256 generated systems; seeds are fixed |
| Size scales the actors, not just the map | Each size preset caps AI empires, fallen empires and marauders, and recommends a crisis multiplier | — |
| Topology as a setting | Hyperlane density 0.5×–2.75×, or **Full**, which removes chokepoints and so changes the strategic character of the galaxy | The witchspace network follows from the seed |
| Habitability as a frequency | "Rare" means no habitable planets outside special systems; otherwise 0.25× to 5× | Every system has a main planet and station |
| A content filter at setup | Per-precursor toggles decide which ancient-empire storylines can appear at all | Expansions are on or off wholesale |
| Campaign shape as numbers | Mid-game year, end-game year and victory year are all player-set, and victory can be switched off | The game is open-ended already |
| Difficulty that ramps | Scaling difficulty starts AI bonuses at zero and reaches full value by the mid- or end-game year, so the setting describes the end of the campaign | Difficulty is the galaxy you are in |
| Ironman as a mode | One save file, overwritten after significant actions, console disabled | Saving is unrestricted |

### Content and exploration

| Idea | What Stellaris does | Oolite today |
| --- | --- | --- |
| Discovery as a survey job | A science ship surveys a system and may turn up an anomaly, shown on the map in a detail mode | Systems hold what the populator put there |
| Content keyed by object class | Any star, any gas giant, any uninhabitable planet — with exclusions for certain empire types | — |
| A choice, not a reward | Most anomalies offer a permanent deposit against a riskier special project | — |
| Risk per outcome | One Distress Signal project carries a **30% chance of losing the ship** | Combat is the risk |
| Outcomes that are content | Deposits, research, ships, leader traits, empire modifiers, planetary features, and **event chains** | Missions award money, equipment and rank |
| Conditional branches on identity | Extra options depending on ethics, civics or origin, so the same find reads differently | — |
| Chains that escalate | An anomaly can open an archaeology site or a multi-stage precursor mystery | Mission chains exist in core and in OXPs |
| Conflict handling as a stated rule | A deposit needing a different station type replaces the old one; a duplicate trait becomes 200 XP instead | — |

### Progression and the late game

| Idea | What Stellaris does | Oolite today |
| --- | --- | --- |
| A weighted draw, not a tree | ~400 techs in a hidden deck, three alternatives per hand, weights modified by who you are and what you have researched | Equipment is gated by tech level and price |
| Repeat suppression | A technology that appeared last hand has its weight halved | — |
| Breadth gates depth | A tier opens after six technologies researched from the tier below in the same area — no named prerequisites | Tech level gates equipment per system |
| Permanent found options | Golden-bordered alternatives from debris, anomalies and digs stay in every hand until taken | Mission rewards are granted outright |
| Salvage as research | Ship debris gives 10% progress toward the component's technology; a perk stops enemies looting yours | Scooped cargo and the escape pod bounty |
| Cost scaling with empire size | +0.2% per point above 100, so expansion has a research price | — |
| A crisis that prevents the ending | An active crisis keeps the game going past the victory year | — |
| Defeat rewarded galaxy-wide | +10% happiness for everyone for ten years, a unity payout, and fallen empires may awaken to help | Thargoid attacks are ambient |

### Rules worth stealing outright

- **Name what the difficulty dial multiplies.** "Crisis strength scales hull, shields, armour and
  damage, but not fire rate" is a sentence the player can reason about. A single opaque "hard" is
  not.
- **One dial, two tiers, via a square root.** Mid-game crises take √(crisis strength). A cheap trick
  that keeps a single setting meaningful across content of different weights.
- **Exhaust the library rather than repeat it.** Fire each outcome once per player and retire the
  content when it is used up.
- **Attach content by predicate, never by coordinate.** It is what lets authored content and a
  procedural galaxy coexist, and what lets two expansions add discoveries without colliding.
- **Write the attachment conflict rules before you need them.** Stellaris has published answers for
  "the deposit needs a different station" and "the scientist already has that trait". You will need
  the equivalents.
- **Free mechanics, paid content** — the same split Egosoft uses, sustained for ten years at several
  packs a year, including a cheap tier that is almost entirely art.
- **Cutting a feature is a legitimate optimisation.** Trade routes were removed because their cost
  was "disproportionately high compared to the benefit". Saying that plainly is better than keeping
  the feature and apologising for the frame rate.
- **The data model is the performance ceiling.** Per-pop work in a game where pops grow without bound
  cannot be optimised, only re-represented. The analogue is exactly the de-globalising work: what the
  simulation's unit *is* decides what is achievable inside it.
- **Benchmark both ends.** Aggregation fixed the late game and slowed the early game on weak
  machines, because grouping has fixed overhead that small populations never amortise. A benchmark
  aimed only at the dying case would have reported a clean win.
- **Budget for the tuning pass after a model change.** Every number downstream of "per pop" needed
  revisiting, and 4.0 in May 2025 was still being walked back by 4.3 a year later.
- **Legible beats elegant for ecosystem growth.** Plain text files in named folders got Paradox tens
  of thousands of mods on top of an override model whose rules are undocumented. Legibility first;
  but know that deferring composition means years of compatibility patches.

### What not to take

- **Per-folder override semantics.** Four different rules — FIOS, LIOS, DUPL, NO/MERGE — assigned
  per directory, undocumented, and subject to change between versions. X4's XPath diffing is the
  better answer and Oolite should prefer it.
- **Load order decided by filename.** When the workaround is prefixing your mod with `~` or `!` to
  sort it to the top or bottom of an ASCIIbetical list, the ordering model has failed.
- **"Smallest UTF-8 byte sequence wins"** for duplicate localisation keys. Nobody will ever guess
  that, and it was presumably an implementation detail that escaped.
- **Compatibility patches as a content category.** A sign of the conflict model, not a feature.
- **A 25× difficulty multiplier.** The top of that range exists for people who want a number, not a
  game.
- **Shipping a data-model rewrite without a low-spec benchmark**, and then declaring a known bad case
  "too risky" to fix in the same release.
- **The whole 4X layer.** Pops, districts, jobs, ethics, federations, the galactic senate and the
  ascension paths are a different game, and the reason this reference is the shortest in the folder.

## Sources

### The Paradox wiki

Detailed, versioned and current enough to trust. The source for nearly every figure above.

- **[Galaxy settings](https://stellaris.paradoxwikis.com/Galaxy_settings)** — the size table, the ten
  shapes and their minimum sizes, hyperlane density, habitable worlds, precursor toggles, resource
  abundance, the seven difficulty levels and the scaling modifiers, ironman, and the mid-game,
  end-game and victory year rules. Marked verified for 4.4
- **[Crisis](https://stellaris.paradoxwikis.com/Crisis)** — the four mid-game crises, the four
  end-game crises and their weights, the five-year eligibility check and its conditions, the
  200–1000 day delay, the crisis strength multiplier and what it scales, the square root for
  mid-game crises, the "All" doubling, and the galaxy-wide rewards
- **[Technology](https://stellaris.paradoxwikis.com/Technology)** — the three areas, ~400 techs, the
  card draw and weights, the halving of a repeated alternative, rare-tech weighting, the six tiers
  and their six-per-tier gate, permanent alternatives, debris, and the cost and speed formulas
- **[Anomaly](https://stellaris.paradoxwikis.com/Anomaly)** — discovery by science ship, binding to
  celestial-object classes, discovery levels 1–8, once-per-empire outcomes and library exhaustion,
  the deposit-versus-project choice, outcome types, conditional options, and the links out to
  archaeology sites and event chains
- **[Modding](https://stellaris.paradoxwikis.com/Modding)** — the `.mod` descriptor and folder
  layout, file types and encodings, the FIOS/LIOS/DUPL/NO-MERGE table and its warning that the rules
  are undocumented, ASCIIbetical load order, the `~` and `!` conventions, `on_actions` merging,
  scripted variables as FIOS, the localisation byte-sequence rule, and compatibility-patch guidance
- [Map modding](https://stellaris.fandom.com/wiki/Map_modding) and
  [galaxy settings](https://stellaris.fandom.com/wiki/Galaxy_settings) on the community wiki —
  cross-checks

### Patch notes and the 4.0 story

- [Paradox: the 4.3 "Cetus" update](https://www.paradoxinteractive.com/games/stellaris/news/cetus-update-is-now-available)
  — the walk-back of 4.0's economy and navy inflation
- [Stellaris 4.0 "Phoenix" free features](https://forum.paradoxplaza.com/forum/threads/stellaris-4-0-phoenix-update-free-features.1739072/)
  — Paradox's own announcement of pop groups, workforce and district specialisations
- **[PCGamesN: Stellaris 4.0 fixes the space game's performance problems with population rework](https://www.pcgamesn.com/stellaris/4-0-population-rework)**
  — the clearest statement of the 2.2 Le Guin performance debt, the grouping-by-100 design, and the
  trade-route removal with its cost/benefit reasoning
- [PCGamesN: after 4.0's rocky launch, Paradox is considering changes](https://www.pcgamesn.com/stellaris/4-0-phoenix-update-interview-eladrin)
  — the launch problems, the contested performance outcome, and the "too risky" pop-group bug
- [SteamDB: 4.5.1](https://steamdb.info/patchnotes/25505771/) and the trackers at
  [changelog.gg](https://changelog.gg/games/stellaris-281990) and
  [patchbot.io](https://patchbot.io/games/stellaris) — version dates
- [Stellaris 4.5.3 notes](https://jeu.video/en/article/stellaris-4-5-3-patch-notes-district-specializations)
  and [4.4.4](https://xpgained.co.uk/patch-notes/stellaris-4-4-4-patch-notes-5505) — the most recent
  builds

### Encyclopedic and community

- **[Wikipedia: Stellaris](https://en.wikipedia.org/wiki/Stellaris_(video_game))** — release and
  platforms, the Clausewitz engine and its lineage, the full 26-pack DLC table with dates, the
  resource list and ethics structure, sales figures, Metacritic and the individual review scores,
  the update-naming convention, and the console editions
- [Steam Workshop for Stellaris](https://steamcommunity.com/app/281990/workshop/) — the per-category
  mod counts
- [PCGamesN: the best Stellaris mods](https://www.pcgamesn.com/stellaris/best-stellaris-mods) — the
  22,000 figure
- [Paradox's own 2019 mod-count posts](https://www.facebook.com/StellarisGame/photos/did-you-know-there-are-now-over-12000-mods-in-stellaris-steam-workshopwaiting-fo/2174780436124523/)
  — the 12,000 and 15,000 figures, for the date spread
- [Paradox forum: favourite galaxy settings](https://forum.paradoxplaza.com/forum/threads/what-are-your-favorite-galaxy-settings-i-am-particularly-interested-in-your-hyperlane-and-pop-growth-settings.1504665/)
  — where the commonly-cited 2275/2325 mid- and end-game years come from, unofficially

### Oolite

- [Oolite Feature Ideas](<../../notes/Oolite Feature Ideas.md>) — the Custom galaxies, Thargoid and
  exploration rows this reference answers
- [X4: Foundations](<X4 Foundations — Feature Reference.md>) — the better modding format, and the
  Existential Crisis as the same late-game idea in a space sim
- [Wing Commander: Privateer](<Wing Commander Privateer — Feature Reference.md>) — permanent failure
  as the ancestor of ironman
- [Freelancer](<Freelancer — Feature Reference.md>),
  [EVE Online](<EVE Online — Feature Reference.md>),
  [EVE Online — Modules and Fitting](<EVE Online — Modules and Fitting Reference.md>),
  [Elite Dangerous](<Elite Dangerous — Feature Reference.md>),
  [Frontier: Elite II and First Encounters](<Frontier Elite II and First Encounters — Feature Reference.md>),
  [Elite (1984)](<Elite (1984) — Feature Reference.md>) — the rest of the set
