# Kerbal Space Program — Feature Reference

Nov 7, 2026 · @Jon Seaman

This is the narrow one, and the last. Kerbal Space Program has no trade, no combat, no economy, no
factions, no NPCs worth the name and nothing to shoot. It is in this folder for **one screen** — the
map view — and for the three things attached to it: **maneuver nodes**, **time warp**, and
**delta-v as a budget you plan against**.

That is the feature the ideas doc is most enthusiastic about. The note reads: *"Definitely like the
idea of the system map. This along with UI improvements would make the game a lot more accessible."*
[Frontier](<Frontier Elite II and First Encounters — Feature Reference.md>) is the reference for a
3D orrery you can fly an autopilot from; KSP is the reference for an orrery that is a **planning
instrument** — a screen where you decide what to do before you do it, and the game tells you what
will happen if you do.

Two further things earn their place. **Patched conics** is the argument that you can have real
orbital mechanics without n-body gravity: deterministic, cheap, and the direct answer to the
"Gravity" row in the ideas doc. And **CKAN** is the mature form of the thing Oolite already has —
Oolite's own manifest vocabulary (`requires_oxps`, `optional_oxps`, `conflict_oxps`,
`required_oolite_version`, `maximum_oolite_version`) lives in `src/Core/OOManifestProperties.h`, so
this is a comparison between a schema Oolite already defines and a registry built on top of the same
idea by a community that has been running it for a decade.

There is also a cautionary tale attached, and it is the most expensive one in the folder:
**Kerbal Space Program 2** went into early access in February 2023, its studio was shut down in June
2024, and it has received no substantive updates since. See the end.

**On sources.** Wikipedia is solid on development, versions, expansions and reception. The **official
KSP wiki is behind bot protection** and could not be read, so the mechanical detail here comes from
community posts and is flagged where it is thin — the time warp altitude thresholds in particular are
contradicted between sources. CKAN's own specification is authoritative and is the best-sourced
section in this document.

## Overview

| Item | Value |
| --- | --- |
| First public release | **0.7.3, 24 June 2011** |
| Steam early access | 20 March 2013 |
| Version 1.0 | **27 April 2015** — *We Have Liftoff!* |
| Last major release | **1.12 *On Final Approach*, June 2021** |
| Developer | **Squad**, Mexico City, in **Unity**. Development began 2010 when Felipe Falanghe was hired |
| Owner | **Take-Two Interactive** since May 2017, published under Private Division |
| Expansions | **Making History** (March 2018), **Breaking Ground** (May 2019) |
| Consoles | Enhanced Edition on PS4 and Xbox One, January 2018; PS5 and Xbox Series X/S, September 2021 |
| Metacritic | **88/100** |
| Notable scores | PC Gamer **96** — its highest score of 2015 — IGN 9, GameSpot 9, Edge 9 |
| Game modes | **Sandbox**, **Science**, **Career** |
| Physics | Newtonian for vehicles; **patched conics** for orbits, with **no n-body** |
| Still played | After the **Artemis II launch in April 2026** it reportedly passed its all-time concurrent player peak |

That last row is worth a moment. A game whose last major update was June 2021 set a new concurrency
record in April 2026 because a real crewed Moon mission launched. No other game in this folder has
that relationship with its subject, and it is a reminder that a simulation's audience can be renewed
by events outside it.

### Version history

| Version | Date | What it added |
| --- | --- | --- |
| 0.7.3 | 24 Jun 2011 | First public release |
| — | 20 Mar 2013 | Steam early access |
| 0.24 *First Contract* | Jul 2014 | **Contracts and reputation** — the career layer |
| 0.25 | Oct 2014 | The final alpha |
| 0.90 *Beta Than Ever* | Dec 2014 | The only beta |
| **1.0 *We Have Liftoff!*** | 27 Apr 2015 | Overhauled aerodynamics, added **heating and heat shields** |
| 1.1 | Apr 2016 | Unity 4 → Unity 5, and a stable **64-bit client** |
| 1.2 | Oct 2016 | **Communication networks** |
| 1.12 *On Final Approach* | Jun 2021 | The last planned major release; the team moved to KSP 2 |

Note where the career layer landed: **contracts and reputation arrived in 0.24, three years after the
first public release and nine months before 1.0.** For most of its development KSP was a sandbox with
no objectives at all, and it was already successful. The structure came later and on top.

## The map view

### Patched conics: orbital mechanics without n-body

The single most important engineering decision in the game.

Orbits are computed by **patched conic approximation**: a vessel is always in a two-body relationship
with exactly one celestial body — its **sphere of influence** — and when it crosses an SOI boundary
the game *patches* one conic section onto the next. Bodies do not gravitationally affect each other.
So there are **no Lagrange points, no perturbations and no tidal forces**, and the Kerbol system's
planets move on fixed rails.

What that buys is enormous, and all four of these matter for a game like Oolite:

1. **Trajectories are predictable in closed form.** The game can draw your future path, tell you
   where you will be in forty days, and let you plan a burn against it — because the answer is
   analytic rather than the output of a simulation you have to run.
2. **Time warp is possible.** A vessel "on rails" can be advanced to any future time instantly. An
   n-body integrator cannot be fast-forwarded a hundred thousand times without either diverging or
   actually doing the work.
3. **It is deterministic.** The same burn gives the same orbit, which is what makes the game
   teachable and what makes a community delta-v chart possible at all.
4. **It is cheap.** All of this ran acceptably on 2011 hardware in Unity.

The ideas doc's **Gravity** row — from Frontier, where the body you are near pulls on you and
slingshots work — has no implementation in Oolite, and the obvious objection is cost. KSP is the
proof that the interesting half of orbital mechanics is available for very little: one body's
influence at a time, conics patched at the boundaries, everything else on rails. The physics that
got cut (Lagrange points, perturbation) is physics players rarely notice is missing.

The planets are also **scaled down** — Kerbin's radius is about a tenth of Earth's with over ten
times the density — so that journeys take minutes rather than months. A deliberate lie in service of
pacing, and worth noting next to Frontier's commitment to real distances.

### What the screen does

The map view shows **trajectories, celestial bodies and orbital parameters**, and lets you select a
target for a flyby, a rendezvous or a docking. The orbit is not a picture of where you are; it is a
read-out of your future, with the numbers that describe it — apoapsis, periapsis, inclination, time
to each — presented alongside the line.

That is the distinction worth carrying over. Oolite's long-range chart shows where things are. This
shows **where you are going, when you will get there, and what would change that.**

### Maneuver nodes

The mechanism that turns the map from a display into a tool: you place a **node** on your orbit at a
future point and pull handles to specify a burn — prograde and retrograde along your motion, normal
and anti-normal out of the orbital plane, radial in and out. The map then **redraws your trajectory
as it will be after the burn**, including the new SOI encounters it creates, before you have spent a
drop of fuel.

The node also gives you the two numbers you need to fly it: **how much delta-v the burn requires**,
and **when to start**. You then point the ship at the burn marker and hold the throttle until the
required delta-v counts down to zero.

So a transfer to another planet is: place a node, drag until the projected path intersects the target,
read the delta-v, check you have it, wait for the burn timer, and execute. **Planning and execution
are separate activities with different interfaces**, and the plan is reversible until you commit.
Nothing else in this folder does that. X4's map lets you order a ship to go somewhere; Freelancer's
generates a route; Frontier's sends the autopilot. Only KSP lets you ask *"what if I did this?"* and
get an answer you can throw away.

### The navball

Flight is flown on a **navball** — a gimballed attitude sphere with markers on it for the directions
that matter: where you are going (prograde), where you came from (retrograde), the burn direction of
your next maneuver node, and your selected target. Pointing the ship means putting one marker over
another.

The idea underneath is that **the useful frame of reference is your velocity, not the stars.** For a
game where the player must align a ship with an abstract direction, that is the instrument, and it is
a single widget rather than a screen.

### Time warp

Two kinds, and the split follows directly from patched conics:

- **On-rails warp**, in space, up to **100,000×**. The vessel is not simulated, only propagated, so
  this is nearly free.
- **Physics warp**, when physics must keep running — in atmosphere, under thrust — limited to about
  **4×**, entered with a modifier key, and widely described by players as unstable and inaccurate for
  many craft.

Warp is also gated by altitude, with the higher rates unavailable close to a body. The exact
thresholds could not be pinned down: players quote both "above 70 km over Kerbin" and
"100,000–120,000 m for the 4× limiter", and mod documentation lists its own numbers. The *shape* is
not in doubt — **the closer you are to something, the less you may skip** — and that is the
transferable rule. Compare X4's SETA, a flat 6× everywhere, and Frontier's Stardreamer, which drops
out when something happens.

The combination — a tiered warp with automatic limits, plus the ability to **warp to a specific future
event** such as your next maneuver node — is what makes a game of multi-day transfers playable at
all.

### Delta-v as the budget

Everything above rests on one number. A vehicle's capability is its **delta-v**: the total velocity
change its fuel can buy, which falls out of the rocket equation as a function of engine efficiency
and the ratio of wet to dry mass. Every manoeuvre costs delta-v, and the community's canonical
artefact is the **delta-v map** — a subway-style chart of how much it costs to get from any body to
any other.

The design consequence is that **the vehicle's capability is a single comparable number, and the
mission's requirement is another**, so "can I do this?" is arithmetic the player can do before
launching. That is a remarkable amount of clarity for a simulation game, and it is the reason the
build screen and the map screen talk to each other.

## The rest of the game, briefly

**Vehicle construction.** Craft are assembled from parts with mass, drag and attachment rules, in a
hangar, with staging to decide what is discarded when. Failures are expected — running out of fuel,
or a joint breaking under load — and the comedy of that is half the game's identity. Part-based
construction is a different genre from Oolite's buy-a-hull model and is not transferable.

**Game modes.** **Sandbox** has no limits. **Science** unlocks parts by earning science from
experiments. **Career** adds funds, reputation and contracts on top. One game, three framings, and the
same split that OpenPrivateer's Classic/Enhanced modes and Stellaris's difficulty settings reach for:
let the player choose how much structure they want rather than deciding for them.

**Kerbals.** Crew who can EVA to collect science, plant flags and repair craft, and who gain
experience. They are the reason anyone cares, and they are a characterisation decision rather than a
system.

**Contracts.** Reach an altitude, reach orbit, land somewhere, rescue a stranded Kerbal, capture an
asteroid, build a station. Note that the contract list is essentially a tutorial curriculum with
money attached — and it arrived in 0.24, long after the sandbox worked.

## Modding, and CKAN

KSP's mod scene is one of the largest in PC gaming, and mods have added interstellar travel, improved
physics, new parts, multiplayer and orbital displays. Several were **absorbed into the base game** —
resource mining among them — and Squad shipped official mods of its own, including an asteroid-tracking
mod built with the B612 Foundation.

The part worth studying is not the mods. It is **CKAN, the Comprehensive Kerbal Archive Network**,
which is a community-run package manager, and the closest thing in this folder to Oolite's expansion
manager.

### What CKAN is

- **A metadata repository plus a client.** Each mod has a `.ckan` file carrying its name, licence,
  download location, dependencies and the **KSP versions it is compatible with**. The specification
  has a corresponding **JSON Schema**.
- **A dependency resolver.** The client works out the full install set including dependencies of
  dependencies, and **refuses combinations that conflict**. The project's stated aim is assurance
  that mods are installed as their metadata prescribes, for the right game version, with their
  dependencies and without conflicts.
- **Declared relationships in both directions.** As well as `depends` and `conflicts`, there is a
  **`suggests`** list for optional extras, and a `supports` list that is its inverse.
- **Version-specific overrides.** When metadata changes for one version only — a dependency added in
  a later release, say — overrides are the prescribed mechanism rather than forking the record.
- **Compatibility from the author's declaration**, via a `max_ksp`-style field.

### What CKAN gets wrong, which is the useful half

- **It can only install what the network has metadata for**, so coverage is a curation problem, not a
  technical one.
- **Bad metadata is the dominant failure mode.** The project's own position is that authors must fix
  it — and the visible symptom is that **a mod can be reported incompatible when it actually works**,
  because its declared version bound is stale.
- It is **built around KSP 1's file structure and metadata logic**, so it did not transfer cleanly to
  the sequel.

### Why this matters for Oolite

Oolite already has the vocabulary. `src/Core/OOManifestProperties.h` defines `requires_oxps`,
`optional_oxps`, `conflict_oxps`, `required_oolite_version`, `maximum_oolite_version`, `download_url`
and `information_url`, and `ResourceManager.cpp` consumes them. So the schema question is settled;
Oolite made the same choices CKAN did.

What CKAN has on top is **a decade of operating it**: a resolver that refuses bad sets rather than
installing them, `suggests` as a first-class relation alongside `requires` and `conflicts`, overrides
for version-specific metadata drift, a JSON Schema the records are validated against, and — most
instructive — the hard-won knowledge that **the bottleneck is metadata quality, not tooling**, and
that stale version bounds will make working expansions look broken.

That last point is the actionable one. A manifest field that authors must keep current will go stale,
and the failure mode is silent and user-visible. Whatever Oolite does next with the expansion manager,
the lesson from CKAN is to plan for stale metadata as the normal case: validate against a schema,
make the bound overridable without a re-release, and prefer "reported incompatible" to be a warning
rather than a refusal.

## Kerbal Space Program 2

Recorded because it is the most expensive cautionary tale in the folder, and because it is about
scope.

KSP 2 was announced in 2019 and entered **early access on 24 February 2023**, promising new
propulsion, **colonies**, **multiplayer** and **interstellar travel** — a superset of the first game
in every direction at once. At launch many of those features were **incomplete or missing**, and the
reaction was severe. **Intercept Games' development team was laid off in June 2024 and the studio shut
down.** There have been **no substantive updates since June 2024**, and the Steam rating fell to
**Overwhelmingly Negative** after review bombing.

The first game shipped a sandbox in 2011, added contracts in 2014, reached 1.0 in 2015 and was still
being patched in 2021. The sequel tried to ship colonies, multiplayer and interstellar travel
simultaneously, on top of a rebuilt physics and rendering stack, and did not survive the attempt.

For a project deciding what goes in the next release, the pairing is the lesson: **the first game
grew one system at a time in public for a decade, and the second tried to arrive complete.**

## Scale numbers

| Quantity | Value |
| --- | --- |
| First public release → last major release | 24 Jun 2011 → **1.12, Jun 2021** |
| Time to 1.0 | **almost four years** of public development |
| Career layer added | **0.24**, July 2014 — three years in |
| Metacritic | **88/100**; PC Gamer 96 |
| On-rails time warp | up to **100,000×** |
| Physics warp | about **4×** |
| Maneuver node directions | **6** — prograde, retrograde, normal, anti-normal, radial in, radial out |
| Gravity model | **patched conics**, two-body at a time, **no n-body** |
| Not modelled | Lagrange points, perturbations, tidal forces |
| Kerbin | radius about **1/10** of Earth's, density **10×** higher |
| Planets | 7 — Moho, Eve, Kerbin, Duna, Dres, Jool, Eeloo |
| Game modes | **3** — sandbox, science, career |
| Expansions | **2** |
| Owner since May 2017 | Take-Two Interactive |
| KSP 2 early access → studio shut | **24 Feb 2023 → June 2024** |
| Concurrency record | reportedly beaten in **April 2026**, after Artemis II |

### What could not be verified

- **Time warp altitude thresholds.** Community sources contradict each other — "above 70 km over
  Kerbin" and "100,000–120,000 m for the 4× limiter" — and the one precise table found belongs to a
  mod, not the stock game. The official wiki is behind bot protection.
- **The navball's exact marker set.** The instrument and the velocity-relative frame are well
  attested; the complete list of markers and their behaviour could not be read from a primary source.
- **The stock delta-v readout's history.** Delta-v is central and the community delta-v map is
  canonical, but which version added a stock readout, and what it shows, was not established here.
- **Sales figures.** None published. Chart positions and the 2026 concurrency record are the only
  proxies.
- **Whether KSP 1 is receiving any maintenance** in 2026, as opposed to merely being played.
- **The current state of CKAN for KSP 2**, beyond one source's note that it remains optimised for
  KSP 1.

## Ideas for Oolite

Almost all of this reference's value is in one screen and one engineering decision. That is a
narrow return for a document, and it happens to be aimed at the feature the ideas doc wants most.

### Five that fit best

1. **A map that shows the future, not the present.** Trajectories drawn forward, orbital parameters
   beside them, arrival times, and the boundaries where the situation changes. Oolite's long-range
   chart says where things are; the ideas doc's "System map and autopilot" row wants somewhere to
   send the autopilot. This is the version that also tells you **when you will arrive and what will
   have changed by then.**
2. **Maneuver nodes: plan, preview, then commit.** Place a burn at a future point, drag it, watch the
   projected path change, read off the cost and the start time, and discard it if you do not like it.
   **Planning and flying are separate interfaces and the plan is reversible.** For Oolite the direct
   application is not orbital transfer — it is that *any* costly decision benefits from a previewable,
   discardable plan, whether that is a multi-jump route, a trade run or an intercept.
3. **Patched conics as the answer to "gravity is too expensive".** One body's influence at a time,
   conics patched at the boundary, everything else on rails. It is deterministic, analytic, cheap
   enough for 2011, and it is why time warp and trajectory prediction are possible at all. The ideas
   doc's Gravity row currently has no implementation; this is the shape a cheap one would take, and
   the physics it omits is physics players do not miss.
4. **Tiered time warp whose limits follow from proximity.** 100,000× on rails in space, about 4× when
   physics must run, lower rates near a body, and the ability to **warp to a named future event**.
   Oolite's debug-only time controls run 0.0625× to 16× and the torus drive is 32×; the structure here
   — the closer you are to something, the less you may skip — is the rule worth taking, and it is the
   same instinct as Frontier's Stardreamer dropping out on arrival.
5. **A single comparable capability number.** Delta-v makes "can this ship do this mission?"
   arithmetic the player performs before committing, and it is why a community could draw one chart
   of the whole solar system's costs. Oolite's nearest equivalent is jump range, which is 7 ly for
   everything; the Frontier reference already wants range to depend on drive class and mass. The
   lesson is to make the resulting number **one figure the player can compare against a published
   requirement.**

### The map and flying

| Idea | What KSP does | Oolite today |
| --- | --- | --- |
| The map is a planning instrument | Trajectories, orbital parameters, arrival times and SOI boundaries, with target selection for flybys, rendezvous and docking | The long-range chart shows positions and plots jump routes; there is no in-system map |
| Preview before commit | A maneuver node redraws your future path, including new encounters, before any fuel is spent, and can be deleted | Decisions are made by doing them |
| Two numbers to fly a plan | The node publishes its delta-v cost and when to start burning | — |
| One instrument for attitude | The navball works in the frame that matters — your velocity — with markers for prograde, retrograde, the burn direction and the target | The compass points at one target; attitude is read from the view |
| Warp limited by proximity | 100,000× on rails, ~4× when physics must run, less near a body | Debug-only 0.0625×–16×; the torus drive is 32× and mass-locks near ships |
| Warp to an event | Skip directly to the next maneuver node rather than choosing a multiplier | — |
| Orbits on rails | Everything not under thrust is propagated rather than simulated | Planets are scenery; nothing moves on an orbit |
| Scaled-down bodies | Kerbin is a tenth of Earth's radius so journeys take minutes | Oolite's systems are already compressed |

### Structure and progression

| Idea | What KSP does | Oolite today |
| --- | --- | --- |
| Three framings of one game | Sandbox, Science (parts unlocked by experiments) and Career (funds, reputation, contracts) | One mode |
| Contracts as a curriculum | Reach an altitude, reach orbit, land, rescue, capture an asteroid, build a station — a tutorial sequence with money attached | Missions are authored set pieces |
| Structure added late, on top | The career layer arrived in 0.24, three years after first release and nine months before 1.0, on a sandbox that already worked | Relevant as sequencing advice, not a feature |
| Failure as content | Running out of fuel and breaking joints are expected outcomes and half the game's identity | Death is a game over; the escape pod softens it |

### Modding and distribution

| Idea | What CKAN does | Oolite today |
| --- | --- | --- |
| A validated metadata schema | A `.ckan` record per mod with a JSON Schema to validate against | The manifest keys exist in `OOManifestProperties.h`; validation is the open question |
| A resolver that refuses bad sets | Computes the full install set including transitive dependencies and declines conflicting combinations | `requires_oxps` and `conflict_oxps` are declared; the expansion manager's resolution behaviour is the thing to compare |
| `suggests` as a first-class relation | Optional extras declared alongside dependencies and conflicts, with `supports` as its inverse | `optional_oxps` exists |
| Overrides for version drift | Version-specific metadata changes are expressed as overrides rather than new records | — |
| Plan for stale metadata | The dominant failure mode is an author's version bound going stale, which makes a working mod look incompatible | `maximum_oolite_version` has exactly this exposure |
| Absorb successful mods | Resource mining and others were folded into the base game | Several core features began as OXPs |

### Rules worth stealing outright

- **Simplify the physics until it becomes a game, then stop.** Patched conics removed Lagrange
  points and perturbation and kept everything players care about. The test is not fidelity, it is
  whether the model supports prediction, determinism and fast-forwarding.
- **If you want time acceleration, you need a model that can be propagated rather than simulated.**
  Warp and patched conics are the same decision seen from two sides.
- **Let the player plan, preview and discard.** A reversible plan with a published cost is a better
  interface than a command.
- **Publish the capability as one number.** Delta-v is why a community could chart the whole system's
  costs on one page.
- **Scale the limit to the proximity.** You may skip less time the closer you are to something that
  matters.
- **Ship the sandbox first and add the structure later.** Three years of KSP had no objectives, and
  the career layer went on top of a toy that already worked.
- **Make the frame of reference the useful one.** The navball orients you against your own velocity,
  not against the stars.
- **Expect metadata to go stale and design the failure.** CKAN's decade of operation says the
  bottleneck is not the resolver.
- **Absorb the mods that prove themselves.** Resource mining started outside the game.

### What not to take

- **Part-based vehicle construction.** A different genre, and Oolite's hulls-and-equipment model is
  the right one for a game about being a pilot.
- **The n-body omission as an excuse not to think about it.** Patched conics is a *choice* with
  consequences — no Lagrange points, no slingshot subtleties beyond the two-body case — and Frontier
  managed slingshots. Know which half you are buying.
- **Physics warp.** About 4×, unstable and inaccurate for many craft, and a standing source of player
  complaints. The on-rails half is the good idea; the physics half is a compromise.
- **Undocumented thresholds.** The altitude limits on warp are contradicted between community sources
  because they were never published. If a rule gates the player's ability to skip time, state it.
- **KSP 2's scope.** Colonies, multiplayer and interstellar travel announced together, on a rebuilt
  stack, with the studio shut fifteen months after early access. The first game's one-system-at-a-time
  decade is the model; the sequel is the warning.
- **A sequel at all, arguably.** The thing that was still setting concurrency records in 2026 was the
  2011 game.

## Sources

### Encyclopedic

- **[Wikipedia: Kerbal Space Program](https://en.wikipedia.org/wiki/Kerbal_Space_Program)** — the
  development history from 2010, the full version list with dates and contents, the Take-Two
  acquisition, both expansions, the console editions, the three game modes, the patched-conic model
  and what it omits, Kerbin's scaling, the Kerbol system's planets, Metacritic and the individual
  review scores, the modding summary, the Artemis II concurrency note, and the KSP 2 early access,
  layoffs and aftermath

### CKAN

The best-sourced section here; the specification is authoritative.

- **[CKAN specification](https://github.com/KSP-CKAN/CKAN/blob/master/Spec.md)** — the metadata
  record and its JSON Schema, `depends`, `conflicts`, `suggests` and `supports`, and version-specific
  overrides as the prescribed mechanism for metadata drift
- [KSP-CKAN on SignPath](https://signpath.org/projects/ksp-ckan/) and
  [the project page](https://hysenlabs.com/projects/ksp-ckan-ckan) — the resolver's stated guarantees
- [openmods.net: KSP mods made easy with CKAN](https://openmods.net/guides/getting-started-kerbal-space-program)
  and [a CKAN usage guide](https://views.terabox.com/hub/how-to-install-and-use-ckan-to-manage-kerbal-space-program-mods)
  — the `max_ksp` compatibility field, and bad metadata as the dominant failure mode. General guides
  of uneven quality, weighted accordingly
- [CKAN-MacOS](https://github.com/wjacobs20301/CKAN-MacOS/tree/main/) — a native Apple Silicon
  rebuild, cited only as evidence of the client's portability problem

### Community, for the mechanics the wiki could not supply

The official [KSP wiki](https://wiki.kerbalspaceprogram.com/wiki/Maneuver_node) is behind
bot protection and returned an access-denied page, so the following stand in and are flagged in the
text where they conflict.

- [Steam: questions about time warp](https://steamcommunity.com/app/220200/discussions/0/530646080840315581/)
  and [x4 time warp only?](https://steamcommunity.com/app/220200/discussions/0/828937979047530061/)
  — the 100,000× on-rails ceiling, the ~4× physics warp, the modifier key, and the conflicting
  altitude thresholds
- [KSP forums: time warping and structural integrity](https://forum.kerbalspaceprogram.com/topic/203148-time-warping-and-structural-integrity/)
  — why physics warp is unstable
- [BetterTimeWarpContinued](https://github.com/linuxgurugamer/BetterTimeWarpContinued) and
  [Time Control](https://www.curseforge.com/kerbal/ksp-mods/time-control) — mod-specific warp tables,
  used only to show the shape of the altitude gating

### Oolite

- [Oolite Feature Ideas](<../../notes/Oolite Feature Ideas.md>) — the "System map and autopilot",
  "Gravity", "Time acceleration" and "Modern UI" rows this reference answers
- `oolite-dev/src/Core/OOManifestProperties.h` and `ResourceManager.cpp` — the existing manifest
  vocabulary the CKAN comparison is built on
- [Frontier: Elite II and First Encounters](<Frontier Elite II and First Encounters — Feature Reference.md>)
  — the 3D orrery with an autopilot, the Stardreamer, and real gravity with slingshots
- [X4: Foundations](<X4 Foundations — Feature Reference.md>) — SETA as a flat 6×, and the map as a
  command interface rather than a planning one
- [Space Reign](<Space Reign — Feature Reference.md>),
  [Space Rangers](<Space Rangers — Feature Reference.md>),
  [Stellaris](<Stellaris — Feature Reference.md>),
  [Wing Commander: Privateer](<Wing Commander Privateer — Feature Reference.md>),
  [Freelancer](<Freelancer — Feature Reference.md>),
  [EVE Online](<EVE Online — Feature Reference.md>),
  [EVE Online — Modules and Fitting](<EVE Online — Modules and Fitting Reference.md>),
  [Elite Dangerous](<Elite Dangerous — Feature Reference.md>),
  [Elite (1984)](<Elite (1984) — Feature Reference.md>) — the rest of the set
