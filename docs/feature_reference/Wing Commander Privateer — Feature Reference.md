# Wing Commander: Privateer — Feature Reference

Nov 7, 2026 · @Jon Seaman

Privateer is the equipment reference, and it is the oldest game in this set apart from Elite itself.
It came out in 1993, ten years before [Freelancer](<Freelancer — Feature Reference.md>) and from the
same designer's studio, and on the two things it chose to do properly it is still better than its
descendant: **a reputation you hold with seven factions at once**, and **an energy budget that makes
every purchase a trade-off**.

It is also the one game here with a surviving primary source. Origin shipped a 64-page manual with
exact figures for every gun, missile, shield, scanner and armour plate, written half as documentation
and half as an in-universe magazine. So where the Freelancer reference had to lean on twenty-year-old
forum threads, this one can quote refire delays.

The headline mechanic is the one the ideas doc does not have an equivalent of. Oolite tracks a legal
status and a rank; Privateer tracks your standing with **merchants, bounty hunters, militia, the
Confederation, pirates, the Kilrathi and the Retros**, separately and simultaneously, with those
factions' own rivalries wired in — so killing pirates is a way of being paid twice, and there is no
way to be everybody's friend. That is 1993 technology, and it costs seven integers.

**On sources.** The manual is excellent on mechanics and is the source for essentially every number
below — but its **ship stat blocks are written in-fiction**, as a review column by a magazine
correspondent, and they **disagree with the shipped game**. The manual gives the Tarsus a 100-unit
hold, Level 1 engines, Level 2 shields and no turret mount; community ship guides give it a 50-unit
hold and Level 5 caps on both, which matches the way everyone actually plays it. Both are recorded
below and the conflict is left standing rather than resolved. Reputation figures come from fans
reading the save format and are marked as such.

**On the lineage.** Origin Systems made Privateer in 1993 as a spin-off of Wing Commander. *Privateer
2: The Darkening* (1996) was directed by Erin Roberts and is a self-contained FMV spin-off rather
than a sequel. After EA shut Origin down, Chris Roberts went off and made Freelancer. So Privateer is
Freelancer's direct ancestor, which is why the two references rhyme — a bar, a mission computer, a
jump network, modular upgrades — and it is worth noticing which of the two is deeper on each point.
Usually it is this one.

## Overview and timeline

| Item | Value |
| --- | --- |
| Release | **September 1993**, DOS, floppy |
| Developer | Origin Systems, Austin, Texas; published by Electronic Arts |
| Credits | Producer R. Scott Russo, designer Joel Manners, programmer Ed Maurer, music Nenad Vugrinec |
| Setting | The Gemini Sector, 2669, during the Kilrathi war |
| Protagonist | Grayson Burrows, nicknamed "Brownhair" |
| Scope | Four quadrants — Clarke, Fariss, Humboldt, Potter — of several systems each |
| Player ships | **4** — Tarsus, Centurion, Galaxy, Orion |
| Factions | **7**, tracked separately |
| Graphics | Pseudo-3D, 320×200 VGA, 256 colours; cockpit view in flight, static first-person views on bases |
| Reception | *Computer Gaming World* 3.5/5; *Hyper* gave Righteous Fire 82/100; second on PC Data's September 1993 DOS chart and first in CGW's November 1993 reader survey |
| Still playable | GOG re-release 2011 (macOS 2012); **OpenPrivateer**, a 2026 reimplementation, in public alpha |

### Versions and add-ons

| Release | Year | What it was |
| --- | --- | --- |
| Privateer | 1993 | The base game, on floppy |
| Speech Pack | 1993 | Digitised voice for in-flight comms |
| **Righteous Fire** | 1994 | The story expansion. Adds purchasable equipment and — notably — **removes permanent mission failure**, so a failed mission can be retried |
| CD-ROM edition | 1994 | Both add-ons plus full speech throughout, with a different lead voice actor |

Righteous Fire's removal of permanent failure is worth recording on its own: the original shipped
with a failure state you could not undo, and the expansion took it out. That is a design correction
made in public, a year later, by the same team.

## The Gemini Sector

Gemini is a frontier on the Kilrathi border, recently out of martial law, and the fiction does real
work: the sector's politics explain why there is piracy, why the militia is thin, and why a lone
pilot can get paid at all.

### Base types, and why trade exists

Every base is one of a handful of types, and the type tells you what it needs. This is the whole
economy, and it is entirely legible on sight:

| Base type | Produces | Wants |
| --- | --- | --- |
| **Agricultural** | Furs, lumber, pets, grain, foodstuffs | Equipment, workers, housing |
| **Mining** | Minerals and ore (bases carved into asteroids, usually behind an asteroid field) | Food, and entertainment for lonely workers |
| **Refinery** | Advanced fuels, durable goods, plastics | Food, entertainment, raw resources to process |
| **Pirate** | Whatever has been taken | — (and no guild offices) |
| **Pleasure** | Luxury | — |

The manual spells out a worked route: buy grain at an agricultural world, sell it at a mining base,
buy ore there, sell it to a refinery, buy the refinery's plastics, sell those back at the
agricultural world. A closed loop, four stops, discoverable by reading the base descriptions.

Four places are special: **New Constantinople** (the capital), **New Detroit** (industrial, and where
the fixer Sandoval reliably has work), **Oxford** (the university, which is where the lore and
several plot threads live) and **Perry Naval Base**. New Constantinople and Perry both **refuse to
trade contraband** at all, so jurisdiction is a property of individual bases and not just of regions.

Mining bases being carved into asteroids — so that reaching one usually means flying an asteroid
field — is the kind of detail that makes a base type feel like a place rather than a price list.

## Flight and navigation

### Energy is one pool, and the engine is the cap

This is the best idea in the game.

A ship has a single **energy** supply, drawn on by **guns, shields, propulsion and the afterburner**
alike. Generating capacity comes from **engine upgrades, of which there are five levels** — the
manual describes them as generators, not thrusters — and the ship decides how many levels it can
take. Consequences:

- **You can buy a gun you cannot fire.** The manual says so in as many words: "Buying a gun you
  haven't got the juice to fire is a painful experience."
- Shields cost energy to hold up. Each of the **five shield levels** draws **100 gigawatts** and
  provides **100 cm of durasteel-equivalent** protection. You can switch shields off, or step them
  down, to free energy for guns — and the manual's own tactical advice is to run with shields down
  when nothing is threatening you.
- The standing recommendation is to keep **at least one more engine level than shield levels**.
- Chasing someone on afterburner can leave you with nothing to shoot them with when you arrive.

So a loadout is an optimisation against one budget, and the budget is set by a component you also
have to pay for. Oolite's shields and lasers already share one energy bank, which means the
scaffolding exists; what is missing is the *cap you buy* and the ability to trade shield strength for
gun output in flight.

### Fuel is only for jumping, and it refills itself

Privateer's answer to fuel management is the cleanest in any of these five games, and it answers the
ideas doc's own complaint — *"I'm not sure how I get fuel"* — by removing the problem:

- **Fuel is used by the jump drive and nothing else.** Propulsion and afterburners run on energy.
- A full tank is **six jumps**.
- **Jump fuel is included in the landing fee.** You land, you pay a fee that covers fuel along with
  staffing and equipment, and your tank is full again.

There is no fuel scoop, no refuelling decision and no way to be stranded by inattention. The only
number the player tracks is how many jumps they have left. Compare Oolite, where fuel is a separate
tank filled at the outfitter or by skimming the sun, and where a new player can fail to work out
that either is a thing.

The **jump drive itself** is the gate: it is an expensive purchase without which you cannot leave the
system you started in. So interstellar travel is a one-time unlock rather than a per-trip cost.

### Nav maps are a purchase

You buy **nav maps** at the software booth, by quadrant, with an all-four discount. Without the map
for where you are:

- no autopilot,
- no directional marker on the HUD,
- no information about the quadrant at all.

The manual's advice if you jump into an unmapped quadrant is to jump straight back out. Information
is a product you buy, and the consequence of not owning it is immediate and legible — the same idea
as X4's trade subscriptions, shipped twenty-five years earlier.

### The nav map and nav points

A system is a set of **nav points** you travel between, and the map is two layers:

- the **quadrant map**, showing systems and the **jump tunnels** between them, with the ones
  currently available to you drawn in a different colour, and
- the **system map**, showing every nav point in the system you occupy.

Nav points are colour-coded: a green circle is a plain nav point, usually a buoy; a **green square**
is somewhere you can land, and selecting it lists the planets and bases there; a **blue circle** is a
jump point; red marks a mission objective; a white dot is you. Mission listings live in the same
screen, with completed tasks in dull red, outstanding ones in bright red, and **hints in yellow**
marked as not required.

So the map is the briefing, the route planner and the mission log in one screen, in 1993, at 320×200.

### Autopilot as a reward for clearing the area

**Autopilot only engages when there are no hostile fighters and no asteroids in range.** The cockpit
has an `AUTO` light that comes on when the area is clear; you press `A` and watch an external camera
shot of your ship streaking off. It cuts out automatically when you approach a hazard or arrive.

This is a much better rule than a cooldown or a fuel cost. The fast-travel is free, and the price is
that **you have to finish the fight first** — which turns every ambush into a decision about whether
to kill the attackers or run for the next nav point. Oolite's torus drive mass-locks near ships,
which is the same instinct; the Privateer version makes the condition explicit with a light on the
dashboard, and extends it to terrain.

### Targeting, and the scanner as the thing that lets you know

Target brackets are colour-coded — **red hostile, blue friendly, yellow bases and cargo** — and then
there is the fourth case:

> **Grey brackets indicate that your scanner cannot differentiate objects.**

A cheap scanner means you cannot tell what you are looking at. Identification is probabilistic:
each scanner has a **percentage chance per second of identifying a target**, and the better ones add
**target lock** and then **ITTS**. The difference between the cheapest and dearest scanner is the
difference between flying blind and flying informed, and it is bought with money.

### ITTS, and one cross per gun type

The **Inertial Targeting and Tracking System** computes the lead needed to hit a moving target — and
it draws **one cross per gun type** fitted, each colour-coded to its gun: turquoise for the neutron
gun, bright red for the laser, dark red for plasma, grey for the mass driver, and so on.

That is a lovely consequence of a mixed loadout: different guns have different projectile speeds, so
a ship carrying three kinds of gun gets three separate aim points and has to choose which one to
honour. The weapon table is not cosmetic, and the interface tells you so.

### The afterburner slide

The manual devotes a full page and a diagram to the game's signature manoeuvre: punch the
afterburners, then turn hard, and the ship slides — because tracking systems cannot anticipate it,
and because it puts you on the target's flank, where most fighters carry **weaker port and starboard
armour**. The instructions are specific: start the turn at about 3,500 m at 30°, burn when the enemy
is barely visible, then turn hard the other way while holding your elevation.

Two things in that are worth having. One is **directional armour**, which gives the manoeuvre a
reason to exist. The other is that the manual **teaches a technique** rather than listing controls.

## Ships

Four hulls, and the choice between them is the career choice. The manual frames it as cargo versus
protection versus offence: the **Galaxy** for cargo, the **Orion** for protection, the **Centurion**
for offence, and the **Tarsus** as the hand-me-down you start with — your grandfather's ship, sitting
in the hangar at Achilles, a mining base in the Troy system.

Figures as the manual gives them. Velocities are in kps; acceleration and maximum yaw/pitch/roll are
rated in words (Poor, Average, Good, Very Good, Excellent); armour is in centimetres of
durasteel equivalent, **per face**.

| | Tarsus | Centurion | Galaxy | Orion |
| --- | --- | --- | --- | --- |
| Class | Merchant scout | Bounty hunter heavy fighter | Merchant ship | Mercenary gunship |
| Max velocity | 300 | **500** | 300 | 350 |
| Afterburner | 600 | **1000** | 750 | 800 |
| Acceleration | Average | **Excellent** | Average | Average |
| Max YPR | Average | Good | Average | **Poor** |
| Cargo hold | 100 (150 expanded) | 50 | **150 (225 expanded)** | 50 (75 expanded) |
| Armour, fore | 10 | 20 | 25 | **48** |
| Armour, aft | 10 | 15 | 20 | **50** |
| Armour, sides | 8 each | 15 each | 17.5 each | **35 each** |
| Turret mounts (manual) | none | none | 4 turreted mass drivers | 2 turreted lasers |
| Shield cap (manual) | Level 2 | Level 2 | Level 3 | — |
| Engine cap (manual) | Level 1 | — | — | — |

The Orion's armour is the striking number — fifty centimetres aft, five times the Tarsus — bought
with the worst handling in the game. And the manual's own verdict on the Tarsus is that it rates a B
in peacetime and a **D** with the war on.

**Treat the last two rows with suspicion.** Those caps are from the in-fiction review and community
ship guides contradict them, giving the Tarsus Level 5 engines and shields and a rear turret, and a
50-unit hold. The shipped game is what matters and the community figures match how the game is
actually played, so the manual is probably wrong here — deliberately or otherwise.

### Trading a ship in

The economics are spelled out, and they are better than most modern games manage:

- Trade-in value is **the ship's index value, minus wear and tear, plus the current selling price of
  every upgrade on it**. Your equipment is not sunk cost.
- The dealer **refuses the trade if your cargo will not fit in the new ship**. Sell down first.
- There is **no financing and no insurance** — explicitly, because a freelancer's life expectancy in
  Gemini makes both uninsurable. So you save up, and a loss is total.

Oolite already has an escape-pod insurance payout and a service level that lowers trade-in value, so
the pieces are there; the idea worth taking is **upgrades carrying their resale value into the
trade-in**, which makes buying good equipment for a cheap hull a sensible strategy rather than a
waste.

## Equipment

### Guns

Eight guns, and the table is a clean statement of a design rule: **more armour penetration costs more
energy per shot and fires more slowly.** Velocity is projectile speed from a stationary ship, refire
delay is the minimum recharge, energy use is gigajoules per shot, penetration is in centimetres of
durasteel.

| Gun | Velocity (kps) | Refire (s) | Energy (GJ) | Penetration (cm) |
| --- | --- | --- | --- | --- |
| Laser | **1400** | **0.3** | **4** | 1.8 |
| Mass Driver | 1100 | 0.6 | 6 | 2.6 |
| Meson Blaster | 1300 | 0.4 | 8 | 3.2 |
| Tachyon Cannon | 1250 | 0.4 | 8 | 5.0 |
| Particle Cannon | 1000 | 0.6 | 11 | 4.3 |
| Ionic Pulse Cannon | 1200 | 0.7 | 15 | 5.4 |
| Neutron Gun | 900 | 0.65 | 18 | 6.2 |
| Plasma Gun | 840 | 0.8 | **22** | **7.2** |

The laser is the cheapest gun and has the fastest projectile and the fastest refire; the plasma gun
hits four times as hard and costs five and a half times the energy per shot. With one energy pool
and an engine level you paid for, that is a real decision at every mount — and the mount is chosen
by the player: when you buy a gun, **you pick where on the ship it goes**.

### Missiles and torpedoes

A launcher holds **up to 10 missiles in any combination**, with a **2.5-second refire delay** per
launcher — and **two launchers fire twice as fast**, which is a reason to spend a mount on
redundancy. Any locking missile that fails to lock simply flies straight.

| Ordnance | Lock | Speed (kps) | Penetration (cm) |
| --- | --- | --- | --- |
| Dumb Fire | none, flies straight | 1000 | 13 |
| Heat Seeker | onto the target's **engines** — best from behind | 800 | 16 |
| Image Recognition | onto the target's **shape** — works from any angle | 850 | 17 |
| Friend or Foe | onto the **nearest hostile**, or nearest ship not transmitting a friendly signal | 900 | 17 |
| Proton Torpedo | own launcher, 10 rounds, **0.5 s** refire | 1200 | **20** |

The lock *methods* are the interesting part: each missile has a different way of finding a target,
and therefore a different geometry it wants. Heat seekers want you behind the target; image
recognition does not care; friend-or-foe does not even need you to choose. That is more texture than
"short range" and "long range", and it is the same number of missile types Oolite has mounts for.

Also: the manual warns that **firing guns too soon after a missile can shoot down your own missile.**

### Defences and utility

| Item | What the manual says |
| --- | --- |
| **Shield generators** | 5 levels. Each draws **100 GW** and gives **100 cm** durasteel equivalent. Not all levels fit all ships. Can be switched off or stepped down to free energy |
| **Armour** | Priced by material; tungsten is **20 cm** equivalent and will "slop up to two torpedoes". Fitted per face, and most fighters are weakest on the flanks |
| **ECM** | 3 levels against missile locks. Level 1 broke a lock about **25%** of the time, each level adding about 25 more. Breaking the lock does **not** stop the missile flying straight at you |
| **Repair droid** | Repairs damaged systems in flight, instead of landing and paying for it |
| **Tractor beam** | The salvage tool. Collected cargo goes straight onto the manifest. Drains **4 GJ/second** — out of the same pool as the guns |
| **Turrets** | Three mounts: **top, bottom, rear**, availability by hull. Each holds **two guns and a tractor beam**, and has a targeting MFD but **no radar** |
| **Cargo expansion** | Internal, volume varies by hull, and **not every hull can take one** |
| **Jump drive** | Required to leave your starting system. One manufacturer has a monopoly |
| **Nav maps** | Per quadrant, or all four at a discount. No map means no autopilot and no HUD marker |

### Scanners

Three brands, three levels each, all with a **35,000 K range**. What you are buying is not range —
it is **how much the ship can tell you**:

| Brand | Level | Display | Lock | ITTS | Identify chance/second |
| --- | --- | --- | --- | --- | --- |
| Iris | Mk I | basic radar | — | — | 5% |
| Iris | Mk II | basic radar | yes | — | 15% |
| Iris | Mk III | basic radar | yes | yes | 25% |
| Hunter | AW 6 | **friend-or-foe colour-coded** | — | — | 5% |
| Hunter | 6i | friend-or-foe colour-coded | yes | — | 15% |
| Hunter | Infinity | friend-or-foe colour-coded | yes | yes | 25% |
| B&S | Tripwire | **fully colour-coded** | — | — | 15% |
| B&S | E.Y.E. | fully colour-coded | yes | yes* | 25% |
| B&S | Omni | fully colour-coded | yes | yes | **35%** |

So the ladder is three separate axes — display quality, lock capability, identification speed — and
the brands differ in character rather than only in price. The cheapest scanner in the game gives you
basic radar, no lock, and a one-in-twenty chance per second of working out what you are looking at.

## Reputation

### Seven factions at once

Merchants, bounty hunters, militia, the Terran Confederation, pirates, the Kilrathi and the Retros.
Each has its own standing with you, each has its own enemies, and your actions propagate.

The numbers below are **fan analysis of the save data**, not documentation:

| Faction | Starting standing |
| --- | --- |
| Merchants, bounty hunters, Confederation, militia | **0** |
| Pirates, Kilrathi | **-50** |
| Retros | **-128** |

Bands: **hostile below -25, neutral between -25 and +25, friendly above +25.** Standing is what
determines the comm responses you get when you hail someone, which is the only in-game indication of
where you stand — there is no reputation screen.

Attacking a faction lowers its standing with you and **raises the standing of its rivals**. The
Confederation's listed enemies are pirates, Kilrathi and Retros, so bounty work pays twice: once in
credits and once in standing. Killing Kilrathi raises Confederation standing much faster than it
raises the mercenaries' or the militia's. Appeasing the Kilrathi means killing Confederation and
militia ships. **Failed missions cost you standing with the faction you flew for.**

### Three implementation details worth knowing

1. **Reputation is keyed to ship type, not to the pilot.** Destroy a Stiletto and the game counts it
   as a pirate kill; destroy a Broadsword and it counts as Confederation, regardless of who was
   actually flying it. A cheap approximation that mostly works and occasionally produces nonsense.
2. **The Retros can never be improved.** Their standing starts at -128 and only ever falls — each
   Retro killed costs 5 — and in exchange **killing Retros raises your standing with everyone
   else**. They are the designed-in pressure valve: a faction that exists so there is always
   something you can shoot to repair your reputation.
3. **The counter is a signed 16-bit integer and it is not clamped.** Kill about 6,528 Retros and
   standing bottoms out at -32,768; kill one more and it **overflows to positive**, and the Retros
   become friendly. Fans found this by arithmetic and then by doing it.

That third one is the best bug in this set of references and the clearest possible argument for
clamping a stat you expose to unbounded player action.

### Getting back in favour

You can recover, slowly, by killing pirates, Retros and Kilrathi for long enough. Righteous Fire
added a shortcut: a contact who, **for 200,000 credits, will hack the Confederation database** and
set everyone except the Retros and the Kilrathi back to neutral. A paid absolution — which is a far
more characterful sink for late-game money than another gun.

## Bases, bars and getting work

Docking puts you on a **main concourse** with doors off it, and the set of doors depends on the base
type. The manual's list of common locations: the hangar, the bar, the mission computer, the ship
dealer, the ship modification shop, the software booth, the two guild offices and the commodity
exchange.

### The bar

Two separate things live in the bar, and both are people:

- **Fixers.** Businessmen who solicit pilots over a drink for "especially lucrative (read
  'dangerous')" work. The manual notes they cluster in **large urban areas** because that is where
  the middlemen are, warns that most of them **bind their contracts with a handshake and often prove
  not to be legit**, and tells you outright that *Sandoval, on New Detroit, nearly always has
  something of interest.* This is how the plot is delivered: by a named man in a bar, who you have to
  go and find.
- **Bartenders.** The manual's line is that a good bartender "knows more about the war than military
  intelligence types do, and more about trading than the Merchants' Guild ever will."

Freelancer's bar is the same idea ten years later. Privateer's version is more pointed, because the
fixer is also the campaign's entry point: **the story is something you find by walking into a bar on
the right planet**, not something that is pushed at you.

### The mission computer, and why you may only hold three

The mission computer is the automated board, on essentially every base, and it is where the military
hires mercenaries because it is cheaper than a standing navy. You may hold **no more than three
missions at once** — and the manual explains the cap in-fiction twice over: pilots who take more end
up dropping one and causing casualties, and a cap stops "mobsters and shady characters" cornering the
work and subcontracting it for a cut.

That is a mechanical limit given a world reason, and it reads as colour rather than as a rule.

### The two guilds

The **Mercenaries' Guild** and the **Merchants' Guild** each charge a **membership fee** and then
give you a second mission computer in their offices. What membership buys:

- Guild missions are **vetted** — nothing illegal — and **payment is guaranteed**.
- You are paid **as soon as the requirements are met**, with no need to report back to an office.
- Members are registered, trackable and penalised for indiscretions, which is what the guarantee is
  built on.
- The Mercenaries' Guild **keeps no offices on pirate bases**, so guild work is unavailable exactly
  where the illegal work is.
- The same three-mission cap applies.

And the manual is honest that the choice matters: "For a military pilot with no cargo hold there is
only a little work available through the guild." Membership is a paid subscription that unlocks a
category of work suited to a particular kind of ship — which is a much more interesting purchase
than a licence that just raises a cap.

### The commodity exchange and contraband

State-run, standardised, fully automated, and **prices are set locally by demand**. You can buy and
sell anything there — including **slaves and drugs**, which are illegal: if militia or Confederation
ships scan you in transit and find contraband, you are treated as a trafficker and attacked on sight.
New Constantinople and Perry Naval Base refuse to trade contraband at all.

The fiction behind it is a nice piece of worldbuilding with mechanical consequences: the exchange was
heavily regulated under a previous governor, whose administration fell over selling ships to the
Church of Man, and in the vacuum the regulations were dropped and the exchange automated. That is why
the player can buy slaves from a government terminal and be shot for carrying them.

## The campaign and Righteous Fire

The plot: a mysterious drone is destroying ships. Sandoval, on New Detroit, hires you and hands over
an artifact, and is dead when you come back. Dr. Monkhouse, a xenoarchaeologist on Palan, identifies
it as **Steltek** — an ancient, vastly advanced species — and as half of a map; he has the other half.
You find a derelict Steltek ship and mount a gun from it, which brings the drone after you; the
Confederation asks you to lure it into an ambush; a Steltek scout **energises the gun** in exchange
for the location of the ship you took it from, and you kill the drone.

The structure is the important part. The plot **must be played in a fixed order**, and between and
during missions you do whatever you like — trade, bounty hunt, smuggle. So the campaign is a spine
through an open world, and the thing it hands you at the end, the **Steltek gun**, is the
unobtainable-by-purchase reward that every one of these games turns out to have.

**Righteous Fire** picks up with the Steltek gun stolen while you were docked. An informant on Oxford
helps in exchange for work against the **Retros**, now led by Mordecai Jones; Governor Menesch, who
has been selling arms to Retros and pirates, is the suspect. A Retro defector gives up their
headquarters and the fact that they have made **copies of the Steltek gun**, and the job is to kill
Jones and destroy the copies.

## The afterlife: Gemini Gold and OpenPrivateer

Privateer has been reimplemented twice, which for a 1993 game with no official mod support is
remarkable.

**Privateer: Gemini Gold** (2005) was a fan remake built on the **Vega Strike** engine — an
open-source space sim engine that was itself heavily inspired by Privateer. Its last update was 2013.

**OpenPrivateer** (2026) is the current one, and it is the closer parallel to
[Librelancer](<Freelancer — Feature Reference.md>):

- It calls itself a **modern reimplementation**, not a remake, with stated goals of **authentic
  behaviour, portability, modding and long-term preservation**.
- Built on **SDL3**, with nightly builds for Windows, Linux (x86_64 and **ARM64**) and macOS
  (x86_64, **ARM64** and universal).
- It **ships no copyrighted assets**: you supply `PRIV.TRE` and `INITCFG.PAK` from your own copy, or
  `RF.TRE` and `INITRF.PAK` for Righteous Fire, and the launcher either imports or uses them in
  place.
- **Public alpha** and playable, Righteous Fire included.
- Three MIDI backends (OPL2, SF2, MIDI-Mapper) plus CD audio; render scaling, texture filtering,
  xBRZ and a CRT filter lifted from DOSBox Staging.
- **Multiplayer** through a headless `openprivateer_server`, by direct IP: combat against NPCs and
  each other, jumping between systems and landing all work; **missions, trading, persistence and
  chat are not networked**.
- **Modding** covers assets, translations, weapons, equipment, missions, starting ships and bases.
- **Three modes**: *Classic* aims to match the original exactly, while *Enhanced* and *Modern* add
  conveniences and optional features — multiple ships, **hired wingmen**, and an experimental "Open
  Universe".
- Roadmap: capital ships and fleet combat, carrier operations, more modding, HD and widescreen (it is
  currently faithful to 320×200), and VR. Known gaps are stated plainly.

The mode split is the part worth stealing. **Classic mode is the fidelity contract and Enhanced is
where the improvements go**, which lets one codebase be both a preservation project and a modern
game without either argument blocking the other. For a fork being polished for upstream, that is a
directly applicable pattern — and it is also how a project of this kind states which behaviour is
load-bearing.

The second point is the dates. Privateer shipped in 1993, GOG re-released it in 2011, and in 2026
volunteers are producing ARM64 macOS builds of a reimplementation that reads the original `.TRE`
archives. Thirty-three years. The reason it is possible is the same as Freelancer's: the game is
mostly **data in archives** that somebody could work out.

## Scale numbers

From the manual unless marked. Reputation figures are fan analysis of the save format.

| Quantity | Value |
| --- | --- |
| Release | September 1993; Righteous Fire 1994; CD-ROM 1994 |
| Quadrants | **4** — Clarke, Fariss, Humboldt, Potter |
| Player ships | **4** |
| Factions | **7** |
| Jumps per full fuel tank | **6** |
| Jump fuel cost | included in the landing fee |
| Engine levels | **5** |
| Shield levels | **5**, each 100 GW for 100 cm equivalent |
| ECM levels | **3**, about 25% lock-break each |
| Scanner range | **35,000 K**, all brands and levels |
| Scanner identify chance | **5% to 35%** per second depending on model |
| Guns | **8**, from 4 GJ/1.8 cm to 22 GJ/7.2 cm |
| Fastest / slowest projectile | laser **1400 kps** / plasma **840 kps** |
| Missiles per launcher | **10**, any combination; **2.5 s** refire |
| Torpedoes per launcher | **10** proton, **0.5 s** refire, 20 cm penetration |
| Tractor beam drain | **4 GJ/s** |
| Turret capacity | **2 guns and a tractor beam**, no radar |
| Turret mounts | top, bottom, rear |
| Missions held at once | **3**, on the computer and in each guild |
| Tungsten armour | **20 cm** equivalent, soaks two torpedoes |
| Heaviest hull armour | Orion, **50 cm** aft |
| Fastest hull | Centurion, **500 kps** / 1000 on afterburner |
| Largest hold | Galaxy, **150 units**, 225 expanded (manual) |
| Reputation bands | hostile **< -25**, friendly **> +25** |
| Starting standing | 0 merchants/hunters/Confed/militia, **-50** pirates and Kilrathi, **-128** Retros |
| Retro kill penalty | **-5** each, and +standing with everyone else |
| Retro overflow | about **6,529** kills flips them friendly, via signed 16-bit overflow |
| Reputation wipe (Righteous Fire) | **200,000 credits** |
| Resolution | 320×200, 256 colours |

### What could not be verified

- **The ship upgrade caps.** The manual's in-fiction stat blocks (Tarsus: Level 1 engine, Level 2
  shields, no turret, 100-unit hold) contradict community ship guides (Level 5 both, rear turret,
  50-unit hold). The community figures match how the game is played, so the manual is likely wrong,
  but nothing consulted here settles it from the game data.
- **The full reputation table.** Starting values, bands and the Retro penalty are reported
  consistently by fans; the per-kill deltas for the other six factions and the exact rival weightings
  are not documented anywhere found.
- **Counts of systems, bases and commodities.** Wikipedia commits only to four quadrants of several
  systems each. No reliable total.
- **The B&S E.Y.E. scanner's ITTS.** The scanned manual lists target lock and an identify chance for
  it; whether it has ITTS is ambiguous in the scan and is marked with an asterisk above.
- **Sales figures.** Chart positions only — second on PC Data's September 1993 DOS list, first in a
  CGW reader survey. No unit totals published.
- **OpenPrivateer's exact release and versioning.** The site says public alpha with nightly builds
  and gives no version number; Wikipedia dates the project to 2026 while a tracking issue from
  October 2026 still treats it as forthcoming. The project's own site is used here.
- **Whether the energy pool arithmetic is exactly as the manual implies.** The manual gives per-shot
  energy costs and per-shield-level draw, but not the generator output per engine level, so the
  budget cannot be computed from the documentation alone.

## Ideas for Oolite

Privateer is a 1993 game and most of its systems are simpler than Oolite's. Two are not, and they
are the two this reference exists for: **the reputation web** and **the energy budget**. Everything
else below is cheap detail of the kind that is easy to underrate — an autopilot condition, a fuel
rule, a scanner that admits it cannot tell what it is looking at.

### Five that fit best

1. **Standing with several factions at once, with their rivalries wired in.** Seven integers, a
   hostile threshold at -25 and a friendly one at +25, starting values that differ by faction, and
   the rule that attacking one faction pleases its enemies. Oolite has a legal status and a rank;
   this is the structure that makes bounty hunting pay twice, makes a region of space close to you,
   and makes "whose side are you on" a question the game can ask. It is also the cheapest idea here
   by a distance — and the Freelancer reference wanted the same thing, implemented less clearly.
2. **An energy budget with a cap you buy.** Guns, shields, propulsion and afterburner all draw on
   one pool; five engine levels set its size; you can switch shields off or step them down in flight
   to free energy for the guns, and you can buy a gun you cannot afford to fire. Oolite's shields
   and lasers already share an energy bank, so this is mostly a matter of **making the generator a
   purchasable component and letting the player trade shields for guns mid-fight.** It is the
   Privateer form of the fitting-budget idea the EVE reference recommended, and it needs no new
   items.
3. **Fuel that refills itself as part of the landing fee.** Fuel is used by the jump drive and
   nothing else, a full tank is six jumps, and landing tops it up as part of the fee you were paying
   anyway. The ideas doc's own note says *"I'm not sure how I get fuel. Maybe I could add that to
   the tutorial?"* — the alternative is to make the question not arise, and keep sun-skimming as the
   thing you do when you cannot afford to land.
4. **A scanner that determines what you are allowed to know.** Three brands and three levels, all
   the same range, differing in display quality, target lock, ITTS and a percentage-per-second
   chance of identifying a contact — with **grey brackets when your scanner cannot tell friend from
   foe at all.** Oolite's scanner is a fixed instrument; making identification an equipment property
   turns the cheap end of the game into a different experience rather than a worse one.
5. **The bar: a fixer and a bartender.** The campaign is delivered by a named man in a bar on a
   particular planet who you have to go and find, with handshake contracts that are often not
   legitimate; the bartender is the trade and war information. Separate from the automated mission
   computer, and the reason the hidden half of the game is discoverable. Oolite's missions arrive as
   station messages; this is where a rumour about a derelict belongs.

### Flight, fuel and navigation

| Idea | What Privateer does | Oolite today |
| --- | --- | --- |
| One energy pool with a bought cap | Guns, shields, propulsion and afterburner share it; five engine levels size it; run with shields down when nothing threatens | Shields and lasers share one energy bank; there is no generator to upgrade and no in-flight trade-off |
| Fuel for jumping only | Six jumps a tank, refilled by the landing fee; propulsion runs on energy | A separate tank filled at the outfitter or by skimming the sun |
| The jump drive as a one-time unlock | Expensive, and without it you cannot leave your starting system at all | Every ship has a witchdrive |
| Nav maps as a purchase, per quadrant | No map means no autopilot, no HUD marker and no information about the region | The charts are free and complete |
| Autopilot gated on a clear area | Engages only with no hostiles and no asteroids in range, with an `AUTO` light for when the condition is met; drops out on hazards and on arrival | The torus drive mass-locks near ships; the condition is not surfaced as a light |
| Nav points as the unit of travel | A system is a handful of named points — buoys, landable bases, jump points — colour-coded on the system map, with mission objectives marked | Stations, the planet and the witchpoint; no in-system map |
| The map is also the mission log | Mission listings in the nav screen, completed tasks dull, outstanding bright, hints in yellow and marked as optional | Separate pages |
| Directional armour | Four faces with separate values, and most fighters are weakest on the flanks — which is what makes the afterburner slide worth learning | One hull value |
| One ITTS cross per gun type | A mixed loadout gets several lead markers, colour-coded by gun, because the projectiles fly at different speeds | Lasers differ in rate and heat; aiming is the same for all |

### Equipment and money

| Idea | What Privateer does | Oolite today |
| --- | --- | --- |
| Guns on an explicit cost curve | Eight guns where penetration rises with energy per shot and falls with refire speed — 4 GJ/1.8 cm to 22 GJ/7.2 cm | Lasers differ in rate and heat |
| You choose the mount | Buying a gun asks where on the ship to put it | Fore, aft, port and starboard mounts exist and are chosen when buying |
| Missiles differentiated by lock method | Dumb-fire, engine-seeking (best from behind), shape-recognising (any angle), and friend-or-foe (nearest hostile, no player lock needed) | Missiles and the hardhead; ECM counters them |
| Two launchers fire twice as fast | A reason to spend a second mount on redundancy rather than variety | — |
| ECM that only breaks the lock | A broken lock means the missile flies straight at you anyway, so evasion still matters | ECM destroys incoming missiles |
| Turrets as small fixed platforms | Top, bottom and rear mounts, two guns and a tractor beam each, their own targeting MFD and **no radar** | — |
| Upgrades retain resale value | Trade-in is index value, minus wear, plus the current price of every upgrade — so good kit on a cheap hull is a strategy | Service level lowers trade-in value |
| No financing, no insurance | Stated in-fiction: a freelancer's life expectancy makes both uninsurable, so you save up and a loss is total | Escape pods pay an insurance reward |
| Buying a licence, not a capability | Guild membership is a fee that unlocks a *category of work* — vetted, guaranteed-payment missions suited to a particular kind of ship | Equipment is gated by tech level and price |
| A paid absolution | 200,000 credits to have your record hacked clean, in Righteous Fire | Fines clear a minor offence |

### Content and the world

| Idea | What Privateer does | Oolite today |
| --- | --- | --- |
| Base type tells you the trade | Agricultural, mining, refinery, pirate, pleasure — each with what it produces and what it needs, with a four-stop loop spelled out in the manual | System economy sets prices; the relationship is less legible |
| Jurisdiction per base | New Constantinople and Perry refuse to trade contraband at all, whatever the region allows | Illegal goods are a system property |
| Terrain as part of a destination | Mining bases are carved into asteroids, so reaching one usually means flying an asteroid field | Stations orbit clear space |
| A three-mission cap with a reason | Explained in-world twice: pilots who overcommit cause casualties, and a cap stops middlemen cornering the work | No cap |
| Plot found, not pushed | The campaign starts with a specific fixer in a specific bar, and must be played in order while everything else stays open | Missions arrive by station message |
| An always-hostile faction as a pressure valve | The Retros can never be appeased, and killing them raises standing with everyone else — so there is always a way back | Thargoids are always hostile; killing them does not repair a criminal record |
| The unbuyable reward | The Steltek gun, energised by an alien scout at the end of the campaign | The cloaking device and naval energy unit from missions |

### Rules worth stealing outright

- **Classic mode is the fidelity contract; improvements go in Enhanced mode.** OpenPrivateer runs
  one codebase as both a preservation project and a modern game by naming the modes. For a fork
  being polished for upstream, that is the pattern that lets "faithful" and "better" stop arguing.
- **Clamp anything the player can push without limit.** Privateer's reputation is a signed 16-bit
  integer and nobody clamped it, so 6,529 dead Retros make the Retros your friends.
- **Make the chore disappear rather than teaching it.** Jump fuel is covered by the landing fee you
  were already paying. The best fix for "the player does not understand the fuel system" was to not
  have one.
- **Sell information as equipment.** Nav maps per quadrant, scanners that differ in what they can
  identify. Both are purchases that change what the interface is able to tell you — and both make
  the early game feel different rather than merely harder.
- **Gate the convenience on a condition the player can see.** The `AUTO` light comes on when the
  area is clear. One lamp, and fast travel becomes a reward for finishing the fight.
- **Give a mechanical limit a world reason.** The three-mission cap is justified twice in fiction,
  and reads as colour instead of as a restriction.
- **Put the campaign behind a person in a place.** Sandoval is in a bar on New Detroit and you have
  to go there.
- **Teach a technique in the documentation.** The manual spends a page and a diagram on the
  afterburner slide, with angles and ranges. It is the difference between documenting controls and
  documenting play.
- **One pool for everything makes every purchase a decision.** Guns, shields, engines and the
  tractor beam all drawing on the same energy is why the Privateer equipment list has no
  strictly-best answer.

### What not to take

- **Reputation with no interface.** Seven tracked numbers and the only way to read them is the tone
  of a comm response. The system is excellent and completely invisible; X4's explicit ladder does the
  same work legibly.
- **Reputation keyed to ship type.** Killing a Stiletto counts as a pirate kill no matter who was
  flying it. A cheap approximation that occasionally produces nonsense, and Oolite already knows the
  actual owner of every ship.
- **Permanent mission failure.** The original shipped with it and Righteous Fire took it out a year
  later. Take the corrected version.
- **An in-fiction manual whose numbers are wrong.** The magazine-column voice is charming and the
  ship stat blocks contradict the game, which is still costing people time thirty-three years later.
  Write the world document and the reference table separately.
- **The Tarsus as a starting ship rated D by its own manual.** Starting the player in something the
  documentation openly calls inadequate for current conditions is a choice; Oolite's Cobra Mk III is
  a better one.
- **Unbounded late-game money with nothing to spend it on.** The 200,000-credit record wipe is the
  only interesting sink in the game, and it is in the expansion.

## Sources

The primary source is unusually good for a game of this age; everything else is community material.

### Primary: the original manual

- **[Wing Commander: Privateer manual (PDF)](https://download.wcnews.com/files/manuals/Wing%20Commander%20-%20Privateer%20-%20Manual.pdf)**
  — Origin Systems, 1993, scanned. The source for the cockpit and energy model, fuel and jumps,
  nav maps, the nav and system maps, autopilot conditions, targeting brackets, ITTS, the tractor
  beam, base types and trading tips, the bar, the mission computer, both guilds, the commodity
  exchange and contraband, the ship dealer's trade-in rules, the four ships' stat blocks, every
  gun, missile, torpedo, shield, armour, ECM, scanner and turret figure, and the afterburner slide.
  **Caveat: the ship stat blocks are written in-fiction and conflict with the shipped game**
- [Privateer Playguide](https://download.wcnews.com/files/manuals/Privateer%20-%20Playguide-Manual.pdf)
  — the companion booklet
- [Gemini Gold's reissued manual](https://privateer.sourceforge.net/downloads/privateer-1.03-manual.pdf)
  — the fan remake's edition of the same text, useful as a cross-check

### Encyclopedic

- **[Wikipedia: Wing Commander: Privateer](https://en.wikipedia.org/wiki/Wing_Commander:_Privateer)**
  — release dates and credits, the faction list, the plot and Righteous Fire's story, the version
  and add-on history, the GOG re-releases, reception scores and chart positions, *Privateer 2*, and
  the existence of Gemini Gold and OpenPrivateer
- [Wikipedia: Vega Strike](https://en.wikipedia.org/wiki/Vega_Strike) and
  [game engine recreation](https://en.wikipedia.org/wiki/Game_engine_recreation) — context for the
  reimplementations

### The reimplementations

- **[OpenPrivateer](https://openprivateer.org/)** — the project's own statement of goals, status
  (public alpha, nightly builds), SDL3, the platform list including ARM64 macOS, the data files it
  requires, the multiplayer split, the modding surface, the Classic/Enhanced/Modern modes and the
  roadmap. Its [player manual](https://openprivateer.org/manual.pdf) is the fuller document
- [PCGamingWiki: Privateer](https://www.pcgamingwiki.com/wiki/Wing_Commander:_Privateer) — the
  surviving ports and fixes
- [Privateer Gemini Gold](https://sourceforge.net/projects/privateer/) — the 2005 Vega Strike remake,
  last updated 2013

### Community: reputation and ships

Fan analysis of the game's data. Treated as the best available and labelled as such in the text.

- **[Wing Commander CIC: Getting Deep Into the Weeds of Privateer's Faction Reputation System](https://www.wcnews.com/news/update/15799)**
  — the Retro starting value, the -5 per kill, and the signed 16-bit overflow
- [WC ChatZone: are there numbers for Privateer faction relations?](https://www.wcnews.com/chatzone/threads/are-there-numbers-for-privateer-faction-relations.24291/),
  [Privateer/RF reputation](https://www.wcnews.com/chatzone/threads/privateer-rf-reputation.25908/) and
  [improving my standing](https://www.wcnews.com/chatzone/threads/improving-my-standing-in-privateer.25666/)
  — the starting values, the ±25 bands, ship-type-based tracking, and the Righteous Fire record wipe
- [Classic Gaming: Privateer ships](https://classicgaming.cc/pc/privateer/ships) and
  [organizations](http://www.classicgaming.cc/pc/privateer/organizations) — the community ship
  figures that contradict the manual
- [TV Tropes: Wing Commander: Privateer](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/WingCommanderPrivateer)
  — cross-checked only
- [MobyGames](https://www.mobygames.com/game/611/wing-commander-privateer/) — credits and releases

### Oolite

- [Oolite Feature Ideas](<../../notes/Oolite Feature Ideas.md>) — the fuel, tutorial and interface
  notes this reference answers
- [Freelancer](<Freelancer — Feature Reference.md>) — the direct descendant; compare the bar, the
  jump network and the modular upgrades
- [X4: Foundations](<X4 Foundations — Feature Reference.md>) — the legible reputation ladder
  Privateer's system lacks
- [EVE Online](<EVE Online — Feature Reference.md>),
  [EVE Online — Modules and Fitting](<EVE Online — Modules and Fitting Reference.md>),
  [Elite Dangerous](<Elite Dangerous — Feature Reference.md>),
  [Frontier: Elite II and First Encounters](<Frontier Elite II and First Encounters — Feature Reference.md>),
  [Elite (1984)](<Elite (1984) — Feature Reference.md>) — the rest of the set
