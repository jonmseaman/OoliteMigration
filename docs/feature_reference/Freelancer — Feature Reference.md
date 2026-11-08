# Freelancer — Feature Reference

Nov 3, 2026 · @Jon Seaman

Freelancer is the usability reference. It is twenty-three years old, it was gutted during
development, its economy is static, its missions repeat, and it is still the game people name when
they want to say that a space sim can be *easy to start playing*. A new player docks, undocks,
trades, fights and crosses six systems in their first hour without reading anything, because every
one of those actions is one mouse click or one key, and the game tells them what to do next.

That makes it the opposite number to [X4](<X4 Foundations — Feature Reference.md>) in this set. X4
has the deepest systems and asks you to learn an interface; Freelancer has shallow systems and the
best interface. The two together bracket the problem the ideas doc keeps running into — the note
that says *"I don't know how to find asteroid fields. I kinda want to do some mining, but I only got
one dollar. Also, not sure how to get fuel."* Those are not content gaps. They are onboarding gaps,
and Freelancer is the game that does not have them.

Freelancer is also the only game in these five references whose **engine has been reimplemented from
scratch as an open-source project**. Librelancer is a .NET and OpenGL clean-room re-implementation
that reads the original data files, has been in development since 2013, and reached the second story
mission in 2025. For a project that has just finished moving Oolite from Objective-C to C++, that is
worth a section of its own: it is the same exercise run from the other end, by people who had no
source at all.

**On sources.** There is no surviving official documentation. Microsoft shut the global server in
late 2007 and ended support on 8 April 2008; Digital Anvil was dissolved on 31 January 2006. So
everything mechanical here comes from community wikis, data sites and twenty-year-old forum threads,
and the main fan wiki is behind a paywall to automated fetches, which limited what could be checked
directly. Concrete figures are flagged as community-derived, and the ones that could not be pinned
down — the level-to-net-worth table above all — are listed at the end rather than guessed.

## Overview and timeline

| Item | Value |
| --- | --- |
| Release | **4 March 2003** |
| Developer | Digital Anvil, Austin, Texas — a Microsoft studio from December 2000, dissolved 31 January 2006 |
| Publisher | Microsoft Game Studios |
| Designer | Chris Roberts (announced it in 1999, left after the acquisition, stayed on as consultant) |
| Setting | The Sirius sector, 2960 — 800 years after *Starlancer* |
| Scope | **48 known star systems**, four great houses |
| Campaign | A linear story in stages, about **two hours of unskippable cutscenes**, voiced by Ian Ziering, Jennifer Hale, George Takei and John Rhys-Davies |
| Multiplayer | Up to **128 players**, any qualifying PC could host, per-server persistence, no story |
| Metacritic | **85/100** (GameRankings 84.36%) |
| Support ended | Global server closed late 2007; support ended 8 April 2008 |
| Still running | The **Discovery Freelancer** RP server, 200 slots, with forum activity in October 2026 |

### What was promised and what shipped

The development history is the most-told cautionary tale in the genre, and it is relevant to anyone
scoping an ambitious space game.

Roberts began the project around 1997 with a two-and-a-half-year schedule and a pitch for a living,
dynamic galaxy holding thousands of players. It was shown at GameStock in 1999, won four Game
Critics Awards at E3 1999 including Best of Show, and was targeted at autumn 2000. By 2000 it was
eighteen months past its original three-year estimate, the press had started calling it vapourware,
and Microsoft opened acquisition talks in June and closed the deal on **5 December 2000**. Roberts
left; Digital Anvil showed a deliberately lighter Freelancer to the press in 2001.

What was cut is the interesting part: **automated flight control, branching dialogue and
sub-quests**. The dynamic economy became a static one. The thousands-of-players galaxy became a
128-player server. All planned content was finished by October 2002, a beta ran with about 500
testers, and the game shipped in March 2003 as one of the month's best sellers — though UK sales of
about 20,000 units in the first half of 2003 were, as the trade press put it at the time, not the
numbers of a hit.

So Freelancer is what you get when a game is scoped down hard and polished instead: narrower than
promised, and far more playable than its ambitions would have allowed.

### What reviewers said

Worth recording, because the split is clean and it maps onto the ideas doc directly.

**Praised**: the graphics, the production values, the voice acting, and above all the **mouse
controls** — IGN gave it 9.2, and the controls are what nearly every review led with.

**Criticised**: a **static galaxy with fixed prices**, repetitive missions, forgettable NPCs,
similar-sounding voices, and shallow multiplayer. GameCritics gave it 6.0. Dogfights were called
repetitive because the flight model has no barrel rolls and no jinking.

That is the trade this reference is about. Freelancer bought its accessibility by making the world
inert.

## The setting

Four **houses**, each a transparent historical analogue, which is a cheap and effective way to make
a sector legible on first contact:

| House | Analogue |
| --- | --- |
| **Liberty** | 1920s United States |
| **Bretonia** | Victorian Britain |
| **Kusari** | Shogunate Japan |
| **Rheinland** | Germany in the second industrial revolution |

The backstory: a civil war between the Western Alliance and the Eastern Coalition sent Alliance
sleeper ships to Sirius, one per house. The fifth, the *Hispania*, was abandoned in Omicron Alpha
and its descendants became the pirate factions — so the game's outlaws have the same origin as its
governments, which gives the Edge Worlds a reason to exist beyond being where the good loot is.

Most planets and stations sit near a single plane, with some above and below it. Each house has
police, military and corporate factions, and each has pirate factions arrayed against it; the
pirates have their own rivalries. Standing with any of them moves standing with their friends and
enemies, which is the mechanic the whole reputation layer is built on.

## Flight

### Mouse-first

Ships are flown by **pointing and clicking**. The camera sits behind the ship, the ship steers
toward the cursor, and clicking fires the guns at the cursor's position — not at a locked target.
There is a keyboard-and-joystick mode, but the mouse mode is the default and the one the game was
designed around, and it is why a player who has never flown a space sim can dogfight in the first
ten minutes.

The limit is real: **no barrel rolls, no jinking**, and reviewers found dogfights repetitive because
of it. The lesson is not "copy the flight model" — it is that the control scheme a newcomer already
knows is worth a lot, and that Oolite's mouse already steers but cannot target anything.

### No radar

There is **no radar display**. Off-screen objects are indicated by **pointers at the edges of the
screen**, and the information boxes can be minimised. Combat awareness therefore comes from the
world and the screen edge rather than from a separate instrument you have to learn to read. Whether
that is better than Oolite's scanner is arguable; what is not arguable is that it needs no
explaining.

### Engine kill and momentum

Cutting engine power lets the ship drift while turning freely to face any direction — a nod to
conservation of momentum rather than a physics model. It is the standard combat technique (drift
backwards away from a pursuer while shooting at them), and it is the same bargain X4 makes with
flight assist: **ship the simple model, put the momentum on one key.**

### Cruise engines

Every ship is capped at the same normal top speed — community guides give 80 — so no one can simply
outrun anyone. **Cruise** is the in-system fast mode: a few seconds of charge, then a constant 300,
with **weapons disabled** while it is engaged.

Two things make this good rather than merely convenient:

- **Cruise disruptor** missiles knock a ship out of cruise, so running away is not automatic. This
  is the ancestor of Elite Dangerous's interdiction and X4's travel-drive overload, and it is the
  simplest version of the three.
- There is a known exploit the community treats as a technique: charge cruise, reach 300, then
  engine-kill, and you keep the speed while able to shoot.

### Trade lanes

The best idea in the game, and the one most worth taking.

**Trade lanes** are built infrastructure: pairs of rings strung between the planets and stations of
a system. Fly into the entry ring and your ship is accelerated along the lane far faster than cruise
will go, hands-off, from one end to the other. They are the reason a Freelancer system feels
inhabited: somebody built roads here, and the roads go where the business is.

They are also **interruptible**. Shoot a lane's brackets and the lane is disrupted, dumping everyone
in it into open space — which is exactly how pirates ambush you, and how you ambush a convoy. A
disrupted lane **recovers after about thirty seconds**. Docking with a lane leaves you briefly
helpless while the ship guides itself to the entry point, so the moment of entering is a moment of
vulnerability. The community's countermeasure is to keep the next ring targeted so you can re-dock
immediately.

So the fast-travel convenience and the ambush mechanic are the *same system*. Compare Oolite's space
lanes, which are where traffic happens but are not infrastructure and cannot be cut.

### Jump gates and jump holes

- **Jump gates** are the mapped, legal links between systems. They are what the nav map will plot
  routes through.
- **Jump holes** are unstable, unmapped, often in nebulae or debris, and frequently the only way
  into somewhere interesting. The nav map **will not route through them**, so using one is a
  deliberate act of exploration based on information you got elsewhere — usually from a bar.

That split is worth copying wholesale: a route network the interface knows about, and a second
network it does not, which only knowledge unlocks.

### The nav map and Go-To

The nav map (F6) shows the system and the wider sector. Pick a destination and the game **generates
the waypoints for you**, offering a *Best Route* that strings together trade lanes and jump gates,
or letting you plot your own path by hand. The autopilot then flies a leg at a time: you issue
**Go-To** and the ship flies to the next waypoint, **steering itself around asteroids and mines**, and
stops there awaiting the next order.

It is not a full hands-off cross-galaxy autopilot — each leg needs its own Go-To, it will not route
through jump holes, and it will not bypass trade lanes. But the division of labour is exactly right:
**the map does the routing, the autopilot does the flying, the player decides where to stop.**
Oolite's advanced navigational array already plots multi-jump routes between systems; this is the
missing in-system half, and it is the answer to the ideas doc's "No in-system map" row.

### Docking

Docking is **one keypress** within 9.5 km. There is no alignment minigame and no landing sequence to
fly. The screen then changes to the interior of wherever you arrived. Freelancer and X4 sit at
opposite ends here — X4 makes landing a four-parameter skill with a two-tier autopilot, Freelancer
makes it a verb — and which is right depends entirely on how often the player does it. In a game
where you dock every two minutes to trade, Freelancer is right.

## Ships and equipment

### Hulls

The player flies single-seat craft: **light fighters, heavy fighters, very heavy fighters** and
**freighters**, rising in cost, hull, cargo space and hardpoint count. Capital ships exist in the
world — battleships and gunboats are set dressing and mission targets — but are not flyable in the
stock game. Freighters are the trading hulls and are deliberately poor in a fight, so the career
choice is made at the ship dealer rather than in a menu.

### The cash gate

Progression is a **level** earned by reaching a **total accumulated net worth** — not experience,
not kills. Level gates what the dealers will sell you, and in the campaign it gates the story: a
story stage will not start until you have reached the required level, so you go and do side jobs
until you have. The community calls it the cash gate, and it is one of the game's least-loved
mechanics; it is included here mostly as a thing to understand before copying it. The useful half is
that **net worth is the single progression number** — your ship, its equipment and your cash all
count, so selling your good guns to buy a bigger hull does not set you back.

The ceiling is where the content thins out: class 10 equipment fits only three fighters and is sold
at five bases, four of them pirate-run, and class 10 shields only in the Edge Worlds. So the last
tier of gear is gated by where you are willing to go, not by what you can afford — a better gate
than the price.

### Guns: hull damage and shield damage are separate numbers

Every gun has **two damage figures, hull and shield**, plus a refire rate, and the derived
damage-per-second numbers differ between them. A gun that strips shields fast may barely scratch
hull, and vice versa, so a competent loadout **mixes gun types across the hardpoints** rather than
fitting six of the best one.

A couple of community-data examples, to show the spread at the top tier:

| Gun | Class | Hull damage | Shield damage | Rate | Hull DPS | Shield DPS |
| --- | --- | --- | --- | --- | --- | --- |
| Nomad Energy Blaster | 10 | 636 | 318 | 4.0 | 2,544 | 1,272 |
| Diamondback | 10 | 1,174 | 587 | 2.0 | 2,348 | 1,174 |

Oolite has one damage number per laser, differentiated by rate of fire and heat. Splitting it in two
is close to free and immediately makes a weapon rack a decision.

### Shields: three types and a ±20% swing

Shields come in classes and in **three types — Graviton, Positron and Molecular** — and each type is
**strong against some weapon families and weak against others**, with the community consistently
reporting the swing as **±20%** (or nothing, for neutral matchups). Molecular resists plasma and
particle weapons and suffers against tachyon and neutron; Positron resists tachyon and neutron and
suffers against laser, pulse and photon.

The availability is also staggered by type: Graviton can be bought up to class 8, Molecular to 9,
Positron to 10, so the late game pushes everyone toward Positron whether they like the matchups or
not. That last part is a balance accident rather than a design idea, but the **damage-type matrix
with a modest swing** is a good one: it is a damage model with real decisions and no arithmetic the
player has to do.

### Everything else on the hardpoints

Thrusters (a short afterburner on a recharging pool), **countermeasures** (flare launchers against
missiles), **mines**, **cruise disruptors**, and a **tractor beam** for pulling in loot — the tractor
beam being mandatory kit for a trader, since collecting cargo is a core verb rather than a scoop
upgrade.

### Codename weapons, and wrecks

The best guns in the game **cannot be bought**. The class 10 "codename" weapons — Archangel,
Bloodstone, Cerberus, Diamondback, Onyx, Thor's Hammer — are loot from **wrecks** hidden around
Sirius.

Wrecks are a deliberate exploration layer:

- They sit in places with **reduced visibility** — dark-matter clouds, debris fields, asteroid
  fields — so you find them by going somewhere awkward.
- They appear on the nav map as a small **red X at about 7 km**, so the discovery moment is real but
  not a pixel hunt.
- They are **fixed**, so the knowledge of where one is has lasting value and can be shared.
- Some need **several trips** to empty, and some sit in clusters that mark something else — a ring of
  Outcast fighter wrecks around an unmapped jump hole in Omicron Alpha, for instance.
- Fields they sit in are also where pirates hang about, so the risk is built in.

This is the whole "exploration should pay" problem solved with static placement and no procedural
generation at all: hand-placed loot in hostile, low-visibility terrain, findable at short range, with
the unique items only available this way.

## Trading and the economy

### Fixed prices

Every base buys and sells a fixed list of commodities at **fixed prices**. Trading means learning
which base is cheap and which is dear and running the gap: engine components bought in one place and
sold in another for a bit over a thousand credits a unit, and so on. Routes are static, so the
optimal route stays optimal forever, and the community wrote the route lists down twenty years ago.

This is the single biggest weakness of the game and the clearest contrast with X4, where prices slide
with stock levels. Reviewers named it at the time. **Oolite is already better than Freelancer here**,
since its prices vary with system economy — so the lesson is the direction of travel, not the
mechanic: Freelancer shows how much polish can be spent on the surface of an economy that is not
actually simulating anything, and how quickly players notice.

### Contraband

Some commodities are illegal in some jurisdictions — cardamine and artifacts being the famous ones.
Police scan passing ships and go hostile if they find contraband, so smuggling is a route choice and
a risk calculation rather than a separate career with its own equipment.

### Mining

Mining in Freelancer is as simple as it gets, and it is instructive how little it needed:

- Certain asteroid fields are marked **mineable on the nav map**.
- Fly in and **shoot the small asteroids**; they break into cargo you **tractor in**.
- Too heavy a volley destroys the fragment, so players fire single shots — an accidental skill
  mechanic that everyone discovers for themselves.
- The fields are where pirates and outlaws hang about.

No prospecting, no probes, no refining: find the marked field, shoot the little rocks, pull in the
gold. Compared with X4's resource-region and probe layer this is crude, but it answers the ideas
doc's complaint directly — **the map tells you where the rocks are** — and it is perhaps two days of
work rather than two months.

## Reputation

Reputation is **per faction, on a slider**, and the whole system is a web rather than a ladder:

- Destroying a faction's ships angers that faction **and its allies**.
- Attacking a faction's enemies **earns their favour**.
- At bad standing you are **attacked on sight and refused docking** in their space, which can lock
  you out of a region's bases and economy.
- **Bribes** — bought on bases — move standing back up.

So you cannot be everyone's friend, your choices in one fight propagate across a graph, and the
consequence is geographic: a region of space becomes unusable. That is a much more interesting
object than Oolite's single legal status, and it is the same idea the Privateer reference would
cover, implemented with ally and enemy edges between factions.

The flaw is that the slider is the only state. There is no diplomacy to do, no representative to
negotiate with, and no reputation-gated content beyond docking rights and dealer access.

## Bases

Docking switches to a rendered interior you navigate **by clicking on places**, which is why no
part of a base needs explaining. The rooms are:

- **Ship dealer** and **equipment dealer** — buy, sell and refit, with your goods on the left of the
  screen and theirs on the right.
- **Commodity trader** — the same exchange layout for cargo.
- **The bar** — the content room, discussed below.

### The bar

The bar carries three separate things, and keeping them separate is the design idea:

1. **The job board** — the posted, public missions.
2. **The news** — flavour, explicitly not mechanically useful, but it is what makes the sector feel
   like it has politics. (A Liberty bar will tell you Liberty is ready to fight two houses at once.)
3. **The patrons** — people standing around. Some have a **briefcase icon** and offer a specific
   job, which works like a board posting but is attached to a person. The rest, and the bartender,
   **talk**, and what they say includes **rumours**: where a wreck is, where an unmapped jump hole
   goes, what is happening in the next system.

That third item is the one Oolite does not have an equivalent of. **Information lives with people,
in a room, and you get it by walking up to them** — not from a scanner, not from a menu, not from a
wiki. It is the delivery mechanism for the entire hidden layer of the game: jump holes, wrecks,
codename weapons.

## Missions and the campaign

### The campaign as the tutorial

The story follows Edison Trent through a **linear sequence of stages**, with about two hours of
cutscenes that **cannot be skipped**, voiced by a real cast. The plot runs through the Nomads — aliens
who possess humans — the Dom'Kavash hyper-gate network, and an artifact, with the Order destroying
the Nomads' power source at the end. After that the game continues as an open sandbox with the story
removed, and the story NPCs are absent from multiplayer entirely.

The reason it matters here has nothing to do with the plot. **The campaign is the tutorial**, and it
is why nobody is confused in their first hour: it hands you a ship, tells you to dock, tells you to
buy something, tells you to fight, and introduces trade lanes, jump gates, bars and the nav map in
an order that makes sense, while a voice actor explains the sector's politics. Between stages you
are pushed out into the sandbox to raise your net worth, which teaches trading and bounty work by
necessity. Oolite's ideas doc wants a tutorial that explains how to get fuel; this is what the
industrial-strength version of that looks like, and the cost of it is a linear campaign and two
hours of cutscenes.

### Generic missions

The job board offers bounty and escort work: eliminate a group, assassinate a leader, clear a
sector, recover something stolen, ferry someone. Reviewers found them bland and repetitive, and
twenty years of players have agreed. The structure — a board at every base, scaled to your level and
the local faction's enemies — is sound; the variety is not there.

## How the world is populated

This part is only known because modders took the game apart, and it is the most directly comparable
thing in the reference to Oolite's own populator.

Freelancer's traffic is **declared, not scripted**. A system's `.ini` file carries `[Zone]` sections
covering volumes of space, and a zone can carry **encounter** definitions that say what turns up
there. The parameters modders work with include:

- **toughness** — the level of the encounter, so difficulty is a property of the place.
- **density** — how many ships may be in one location at a time.
- the **faction weights** for who shows up, which is how a zone becomes "Outcast space" without
  anything being placed by hand.

The ships themselves come from `npcships.ini`, which ties a **pilot type, a hull and a loadout**
together into a named NPC kind, with its own difficulty; `faction_prop.ini` defines the factions and
their properties and references those NPC kinds; and the behaviour each encounter uses is one of a
small set — **`wander`, `trade`, `patrol_path`**. Patrol paths are the interesting one: they must
begin and end near a dockable object declared in `mbases.ini`, and the faction has to have an entry
there for every base the patrol touches, or the game crashes. So a police patrol is literally a
route between two stations that the faction has standing at.

Two observations worth carrying over:

- **Difficulty and population are properties of a region**, set as two numbers on a volume, rather
  than of an encounter table or a script. That is a very small amount of data for the amount of
  character it produces, and it is why flying from Liberty to the Edge Worlds feels like a gradient.
- **NPC behaviour is a short, closed list.** Three verbs, one of them a route between bases. Oolite's
  populator and priority AI are considerably more capable than this; the point is how far three
  declarative behaviours and two numbers per zone will get you.

The caveats are equally instructive. The files are encrypted and compressed, so modders needed an
unpacking tool before they could read anything; and the standing community advice is to leave
encounters alone until you know what you are doing, because a malformed patrol path crashes the
game. Declarative data with no validation is still a trap — which is an argument for the kind of
checking an OXP verifier does.

## Multiplayer

Up to **128 players** per server, **any qualifying PC could host**, and servers **saved each
player's progress**, so a server was a small persistent galaxy. There were no story missions in
multiplayer and no transfer of wealth or gear between servers.

The world itself did not become any more dynamic with people in it — prices stayed fixed, factions
stayed put — so reviewers called multiplayer shallow. What actually sustained it was **roleplay**:
communities imposed their own rules, politics and economies on top of an inert sandbox, which turned
out to be enough to keep servers running for two decades.

The relevant observation for Oolite, whose multiplayer section starts from
`PlayerEntity::sharedPlayer()`: Freelancer's multiplayer was **a listen server with per-player save
state and no simulation changes at all**. It was cheap, and it was sufficient for a community. That
is a far smaller target than the shared-galaxy model in the ideas doc.

## The afterlife: mods and Librelancer

### Why it is still alive

Freelancer's data — ships, systems, equipment, factions, prices, missions — lives in **plain
configuration files** (an `.ini` format, sometimes in a binary-encoded variant) that the community
reverse-engineered quickly. There was never official mod support, and it did not matter: the game
turned out to be almost entirely data, and the tooling to edit that data was written by players
within a year.

What came of it:

- Total conversions adding capital ships, new factions and other franchises' fleets entirely —
  *Star Wars* against *Wing Commander*, and so on.
- **Discovery Freelancer**, a long-running roleplay total conversion, whose main server runs
  **24/7 with 200 slots** and whose forums were still showing players online and new posts in
  **October 2026** — twenty-three years after release, and nineteen after Microsoft shut the
  official server down.
- Community servers that simply replaced the dead master server, so multiplayer never stopped.

### Librelancer

Librelancer is a **cross-platform open-source re-implementation of the engine**, not a mod:

- Written in **.NET**, rendering through **OpenGL 3.1 / OpenGL ES 3.2**, targeting Windows 10+ and
  modern x86_64 and arm64 Linux. 32-bit and arm32 are explicitly unsupported.
- It ships **LancerEdit**, a modding toolkit, in its SDK.
- It needs **your own copy of the game's data files**; it distributes no assets.
- It is honest about where it is: the project says it **cannot yet play through the game**. Mission
  01A became playable in 2024, Mission 2 in 2025, **multiplayer is supported**, and more story
  missions are becoming playable. Contributor copyright notices run 2013–2026.

The parallel with the Oolite migration is close enough to be useful. Librelancer is a reverse-
engineered rewrite with no source code, no documentation and no original developers, and its measure
of progress is *"which mission can you play through"* — a scenario-level integration test, chosen
because unit tests against a black box are not available. Oolite's conversion has the opposite
luxury (the source, and the original behaviour to diff against) and arrives at the same instinct:
the component scenarios over the debug console are the same kind of check.

The second thing worth taking is the one that made both the mod scene and Librelancer possible:
**the game is data, and the data is legible**. A twenty-three-year mod community exists because
ships and systems were `.ini` files rather than code. Oolite already knows this — it is what OXPs
are — and this is the strongest available evidence for the proposition that **legible data formats
are what make a game outlive its studio**.

## Scale numbers

Community-derived unless marked. Freelancer has no published data tables, so these are the figures
multiple fan sources agree on.

| Quantity | Value |
| --- | --- |
| Release to now | 4 Mar 2003 → 23 years |
| Star systems | **48** (Wikipedia) |
| Houses | 4, plus pirate factions descended from the fifth sleeper ship |
| Normal top speed | **80**, the same for every ship |
| Cruise speed | **300**, with a few seconds of charge and weapons disabled |
| Trade lane disruption recovery | about **30 s** |
| Dock range | within **9.5 km** |
| Wreck visibility on the nav map | about **7 km**, shown as a red X |
| Shield types | **3** — Graviton, Positron, Molecular |
| Shield matchup swing | **±20%**, or neutral |
| Shield availability ceiling by type | Graviton to class 8, Molecular to 9, Positron to 10 |
| Equipment classes | **1–10** |
| Class 10 fighters / vendors | fits **3** fighters, sold at **5** bases, 4 of them pirate |
| Example class 10 gun | Diamondback: 1,174 hull / 587 shield per shot at 2.0/s, 115,660 credits |
| Multiplayer cap | **128** players per server |
| Discovery Freelancer main server | **200** slots, 24/7, active October 2026 |
| Campaign cutscenes | about **2 hours**, unskippable |
| Metacritic | **85/100** |
| UK sales, first half of 2003 | about **20,000** units |
| Beta testers | about **500** |

### What could not be verified

- **The level-to-net-worth table.** That levels come from total accumulated worth is well
  documented; no source consulted gives the thresholds. The main fan wiki, which probably has them,
  blocks automated access.
- **Counts of bases, commodities and flyable ships.** No reliable current figure for any of the
  three. 48 systems is the only scope number Wikipedia commits to.
- **Where to buy it in 2026.** Nothing found confirms a current digital storefront listing, and
  Microsoft's support ended in 2008. Librelancer requires original data files, which implies they
  are obtainable, but by what route is not established here.
- **Whether a cruise disruptor is a missile, a mine or both**, and its exact effect duration.
  Community sources describe cruise-disruptor missiles that slow you and knock you out of cruise;
  the numbers vary by source.
- **Bribe pricing and the exact reputation arithmetic.** That bribes exist and that ally/enemy
  propagation happens is documented; the magnitudes are not.
- **Whether `Freelancer 2` / Project Lonestar was really in development.** Reported for the Xbox 360
  and said to have been cancelled with Digital Anvil's closure in 2006, but the sourcing is thin.
- **Librelancer's current milestone.** The project's own site states Mission 2 in 2025 and does not
  name a 2026 milestone; the repository would be the place to check. A SourceForge mirror claims
  "fully functional single-player and multiplayer", which contradicts the project's own page and is
  not believed.

## Ideas for Oolite

Freelancer's systems are shallower than Oolite's in several places — its prices are fixed where
Oolite's vary by economy, and its reputation is one slider where Oolite has legal status and
rank — so this is not a reference to mine for depth. It is the reference for **the surface**: how a
player finds out what to do, how they get somewhere, and how the interface stops being in the way.
That is the part of the ideas doc that is still open, and the part the "More" notes keep returning
to.

### Five that fit best

1. **Trade lanes: fast travel that an enemy can cut.** Rings between the stations and planets of a
   system that grab a ship and fling it along at many times normal speed, hands-off — and that a
   pirate can **disrupt by shooting the brackets**, dumping everyone into open space, recovering
   after about thirty seconds. The convenience and the ambush are one system, which is why it never
   feels like a cheat. Oolite has space lanes where traffic happens and a torus drive that
   mass-locks; this would make the lanes into built infrastructure with a geography of their own,
   and would give pirates something to do besides wait.
2. **A nav map that generates the route, and an autopilot that flies one leg at a time.** Pick a
   destination, get waypoints along the best lane-and-gate route, then Go-To each leg while the ship
   steers itself around asteroids and mines. The division of labour is the thing: **the map routes,
   the autopilot flies, the player decides where to stop.** Oolite's advanced navigational array
   already does the between-systems half; this is the in-system half, and it answers the "No
   in-system map; the docking computer only docks at stations" row directly.
3. **Mouse-first controls, including targeting.** The ship steers toward the cursor and guns fire at
   the cursor, no radar instrument, off-screen contacts shown as **pointers at the screen edge**.
   This is why Freelancer has no onboarding problem. The ideas doc's Modern UI row already notes
   that Oolite's mouse "picks rows and steers, but can't target anything" — Freelancer is the
   worked example of fixing exactly that, and it was praised for it in nearly every review.
4. **Bar patrons as the delivery mechanism for hidden knowledge.** A room on every base with three
   distinct things in it: the posted job board, the news (flavour, deliberately useless), and
   **people you can talk to** who tell you where a wreck is and where an unmapped jump hole goes.
   Information lives with a person in a place rather than in a scanner or a menu, and it is what
   makes the whole hidden layer of the game discoverable at all. Oolite's missions arrive as station
   messages; a bar is a place to put the rumour that a derelict is drifting in a particular system.
5. **Hull damage and shield damage as separate numbers, with a damage-type matrix.** Every gun has
   two damage figures, so a good rack mixes gun types; three shield types each resist some weapon
   families and suffer against others, at a flat **±20%**. Oolite has one damage number per laser,
   differentiated only by rate and heat. This is close to free, adds no items, and turns a weapon
   choice into a decision — the same conclusion the EVE reference reached from the other direction.

### Flight and travel

| Idea | What Freelancer does | Oolite today |
| --- | --- | --- |
| Trade lanes | Built, one-way-at-a-time rings between a system's bodies; hands-off high-speed travel; disruptable by shooting the brackets; recover in ~30 s | Space lanes are traffic patterns, not infrastructure |
| Vulnerability on entry | Docking with a lane leaves you unable to fly or thrust while the ship guides itself in | — |
| A single normal top speed | Every ship caps at the same cruise speed, so nothing outruns anything without a drive | Ships differ in top speed; injectors and the torus drive are the fast modes |
| Cruise with weapons disabled | A few seconds of charge, then a constant high speed, guns offline | The torus drive disengages near ships |
| Cruise disruptors | A consumable that knocks a ship out of its fast drive, so fleeing is never automatic | Nothing pulls a ship out of torus |
| Engine kill as a combat toggle | Cut power to drift while turning freely — the standard dogfight move | — |
| Two travel networks | Jump **gates** are mapped and routable; jump **holes** are unmapped, often hidden in nebulae, and the nav map refuses to route through them | Witchspace routes are all on the chart |
| Mineable fields marked on the map | The nav map says which asteroid fields can be mined | The populator places asteroids; nothing marks them |
| Autopilot that avoids terrain | Go-To steers around asteroids and mines so debris fields are crossable | The docking computer docks |
| Docking as one keypress | Within 9.5 km, one key, no alignment | The docking computer docks you; there is no 10-second version |

### Interface and onboarding

| Idea | What Freelancer does | Oolite today |
| --- | --- | --- |
| No radar instrument | Off-screen contacts are pointers at the screen edges; info boxes minimise | The scanner is a distinct instrument to learn |
| Mouse targeting | Click a ship to target it; guns fire at the cursor rather than at a lock | The mouse steers and picks rows |
| Bases as rooms you click | Docking switches to a rendered interior; each function is a place | Full-screen pages on function keys |
| Exchange screens | Your goods on the left, theirs on the right, for ships, equipment and cargo alike — one layout, three dealers | Separate market and outfitter pages |
| The campaign is the tutorial | A linear story introduces docking, trading, lanes, gates, bars and the map in a sensible order, with the sandbox used as the gap between stages | The tutorial exists; the ideas doc wants fuel explained in it |
| News as free worldbuilding | A news item on every base, explicitly not mechanically useful, which is what makes the sector feel political | Station messages |

### Equipment and combat

| Idea | What Freelancer does | Oolite today |
| --- | --- | --- |
| Two damage numbers per gun | Separate hull and shield damage, so loadouts mix weapon types | One damage number per laser |
| Damage-type matrix | Three shield types, each ±20% against particular weapon families | Shields are a single pool with a recharge rate |
| Net worth as the one progression number | Level comes from total accumulated worth — ship, equipment and cash together — so trading up is never a setback | Money and tech level gate equipment |
| The last tier gated by geography | Class 10 gear sells at five bases, four of them pirate-run, and class 10 shields only in the Edge Worlds | Tech level gates equipment by system |
| Unique items only from wrecks | The best guns in the game cannot be bought at any price | Everything purchasable is purchasable somewhere |
| Tractor beam as core kit | Collecting cargo is a verb every trader fits for | The fuel scoop and cargo scooping |
| Countermeasures as consumables | Flare launchers, mines and disruptors occupy hardpoints and run out | Missiles, mines and ECM |

### Content and the world

| Idea | What Freelancer does | Oolite today |
| --- | --- | --- |
| Hand-placed wrecks in bad terrain | Fixed wreck sites in dark-matter clouds, debris and asteroid fields; visible as a red X at ~7 km; some need several trips; some clusters mark something else nearby | Derelicts and cargo appear from combat, not from placement |
| Rumours as the index to the hidden layer | Bar patrons tell you where wrecks and jump holes are; nothing else will | — |
| A reputation web, not a ladder | Per-faction standing where helping one hurts its enemies, bad standing means attacked on sight and refused docking, and bribes buy it back | A single legal status plus rank |
| Factions with a shared origin | The pirates descend from the fifth sleeper ship, so the outlaws and the governments have the same ancestry | Anarchies are a government type |
| Contraband as a route decision | Illegal goods differ by jurisdiction and the police scan in transit | Illegal goods exist; scanning is by police ships |
| Mining as three verbs | Find the marked field, shoot the small rocks, tractor the fragments — with single shots, because a heavy volley destroys the ore | — |
| Difficulty as a property of a place | A zone carries a `toughness` level and a `density` cap plus faction weights, so a region's character is two numbers and a list | The populator places traffic along the space lanes; government and economy drive who appears |

### Rules worth stealing outright

- **Every convenience is interruptible.** Trade lanes can be cut, cruise can be disrupted, lane
  entry leaves you helpless. The fast-travel system and the ambush system are the same code, which
  is why Freelancer's conveniences never drain the tension out of the map.
- **One key for the thing the player does a hundred times.** Docking is a keypress. Compare X4,
  which makes it a four-parameter skill — correct for X4, wrong for a game where you dock between
  every trade.
- **The campaign is the tutorial, and the sandbox is the gap between its stages.** Everything a
  player needs to know arrives inside a story they have a reason to follow.
- **Ship a mapped network and an unmapped one.** The routable gates teach the map; the unroutable
  jump holes are what knowledge buys.
- **Put the information in a person, in a room.** Rumours from bar patrons are the index to
  everything hidden, and they cost nothing but dialogue.
- **Make the best items unbuyable and hand-place them somewhere unpleasant.** Static placement,
  short-range discovery, repeat visits, clustered hints. No procedural generation required.
- **Scope down and polish instead of shipping the ambition.** Freelancer lost its dynamic economy,
  its branching dialogue and its thousands-of-players galaxy, and what remained is the game people
  still cite twenty-three years later for being pleasant to play.
- **Legible data formats outlive the studio.** The entire world is configuration files, which is why
  there is a 200-slot server still running in 2026, nineteen years after the publisher shut the
  official one down, and why volunteers could rewrite the engine from scratch. This is the argument
  for OXPs stated as a historical fact.
- **Measure an engine rewrite by what you can play through.** Librelancer's milestones are "Mission
  01A, 2024" and "Mission 2, 2025" — scenario-level integration tests, because that is what you have
  when the thing under test is a black box. The component scenarios over the debug console are the
  same instinct with better tooling.

### What not to take

- **Fixed prices.** The game's most-criticised feature, and Oolite is already ahead of it. X4 is the
  reference for the other direction.
- **The cash gate.** Gating story progress on accumulated net worth forces grinding between
  chapters, and twenty years of players have disliked it. The useful half — net worth as the single
  progression number — survives without the gate.
- **Two hours of unskippable cutscenes.** Even reviewers who praised the voice acting said so.
- **A flight model with no manoeuvres.** No barrel rolls and no jinking is why reviewers called the
  dogfights repetitive. Mouse-first controls do not require that trade; it was a separate decision.
- **Reputation with nothing behind it.** The slider is the whole state: no representatives, no
  negotiation, no reputation-gated content beyond docking rights. X4's ladder does more with the
  same idea.
- **A big board of bland missions.** The board at every base is right; twenty-odd interchangeable
  kill-and-fetch templates are what reviewers singled out.
- **Staggered shield availability by type.** Buying Graviton only to class 8 and Positron to 10
  funnels every late-game player into one type regardless of the matchups, which undoes the matrix.
  A balance accident, not a design.

## Sources

Freelancer has no surviving official documentation, so everything here is community material of
varying age. Grouped by what each was actually trusted for.

### Encyclopedic and historical

The only sourcing solid enough for dates, scope and reception.

- **[Wikipedia: Freelancer](https://en.wikipedia.org/wiki/Freelancer_(video_game))** — the source
  for the release date, the 48 systems, the houses and backstory, the campaign structure and cast,
  the 128-player multiplayer, the development timeline, the end-of-support dates, the review scores
  and the sales figure
- [Wikipedia: Digital Anvil](https://en.wikipedia.org/wiki/Digital_Anvil) and
  [Chris Roberts](https://en.wikipedia.org/wiki/Chris_Roberts_(video_game_developer)) — the
  acquisition dates and Roberts's departure
- [Wikipedia: Starlancer](https://en.wikipedia.org/wiki/Starlancer) — the prequel and the 800-year
  gap
- [Unseen64: Freelancer beta](https://www.unseen64.net/2011/10/02/freelancer-beta-pc/) — what was
  shown in 1999–2001 against what shipped

### The engine re-implementation

- **[Librelancer](https://librelancer.net/)** — the project's own statement of what works, the
  mission milestones for 2024 and 2025, the .NET and OpenGL requirements, the supported platforms
  and the LancerEdit toolkit. Treated as authoritative over third-party mirrors
- [Project Sirius](https://github.com/davidichalfyorov-wq/Project-Sirius) — a Librelancer-based
  remake project, cited only for the 2013–2026 contributor range
- [Librelancer SourceForge mirror](https://sourceforge.net/projects/librelancer.mirror/) — claims
  "fully functional single-player and multiplayer", which contradicts the project's own site and is
  **not** relied on

### Game data and mechanics

Community data sites, used for equipment numbers. Figures are theirs, not Egosoft's or Microsoft's.

- [fl-guide.de weapons tables](http://fl-guide.de/weapons.php?filter=level10) — per-gun hull damage,
  shield damage, refire rate, derived DPS and price, filtered by class
- [StrategyWiki: Freelancer/Shields](https://strategywiki.org/wiki/Freelancer/Shields) and
  [Freelancer/Ships](https://strategywiki.org/wiki/Freelancer/Ships) — the shield-type matchups and
  the ship level requirements
- [Freelancer Wiki (Fandom)](https://freelancer.fandom.com/wiki/Base_Features) — base features, the
  bar, trade lanes, guns, shields, class 10 weapons, tips. **Blocks automated fetching**, so it was
  reached through search summaries rather than read directly, which is the main gap in this
  reference
- [SWAT Portal: wrecks and loot](https://swat-portal.com/forum/cms/wiki/freelancer/wrecks/) and the
  [complete vanilla wreck list](https://swat-portal.com/forum/thread/10628-complete-wreck-loot-list-vanilla/)
- [The Starport INI editing wiki](https://the-starport.com/wiki/ini-editing/) and the
  [encounters reference](https://lizerium.com/wiki/KnowledgeBase/en/ini-editing/typed-inis/encounters.md)
  — how zones, encounters, `npcships.ini`, `faction_prop.ini` and patrol paths fit together
- [Lancers Reactor](http://lancersreactor.org/) — the long-running forum; shield-versus-weapon
  threads and the nav map and autopilot discussions
- [Discovery Wiki: the nav map and autopilot](https://discoverygc.com/forums/showthread.php?tid=6661)
  — on what the route planner will and will not plot. Note this is a **mod** community, so its
  mechanical claims can differ from the stock game
- [TV Tropes: Freelancer](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Freelancer) — the cash
  gate and the class 10 availability, cross-checked where possible

### The mod scene

- [Discovery Freelancer on ModDB](https://www.moddb.com/mods/discovery-freelancer) and
  [on Nexus Mods](https://www.nexusmods.com/freelancer/mods/13) — the 200-slot 24/7 server
- [Discovery Gaming Community forums](https://discoverygc.com/forums/index.php) — the October 2026
  activity figures
- [Discovery Wiki: other servers](https://discoverygc.com/wiki/Other_Servers) — dated, but evidence
  of how many servers there were

### Press and retrospectives

- [GameSpot's Freelancer walkthrough](https://www.gamespot.com/articles/freelancer-walkthrough/1100-6025600/)
  — cited for completeness; it blocks fetching
- [DualShockers: 20 years on](https://www.dualshockers.com/20-years-on-freelancer-still-best-space-sim-ever-made/)
  — a retrospective, and a caution: much of what it praises is the Discovery mod, not the stock game
- [Gaming Nexus review, 2003](https://www.gamingnexus.com/Article/Freelancer/Item196.aspx) and
  [Super Adventures in Gaming](http://superadventuresingaming.blogspot.com/2016/06/freelancer-pc.html)
  — contemporary and retrospective accounts of the mining, the bar and the mission board

### Oolite

- [Oolite Feature Ideas](<../../notes/Oolite Feature Ideas.md>) — the Modern UI, system map and tutorial rows
  this reference answers
- [X4: Foundations](<X4 Foundations — Feature Reference.md>) — the counterweight: deep systems,
  harder interface
- [EVE Online](<EVE Online — Feature Reference.md>),
  [Elite Dangerous](<Elite Dangerous — Feature Reference.md>),
  [Frontier: Elite II and First Encounters](<Frontier Elite II and First Encounters — Feature Reference.md>),
  [Elite (1984)](<Elite (1984) — Feature Reference.md>) — the rest of the set
