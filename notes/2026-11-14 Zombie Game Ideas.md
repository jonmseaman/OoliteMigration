# Zombie Game Ideas

2026-11-14. Brainstorm: ways to bring zombies into Oolite beyond reskinned ships, using what the game already has (trade, flight, docking, the galactic chart, witchspace). Nothing here is planned or built.

## Ideas

1. **The Plague Run (trade and quarantine).** An infection spreads system to system along trade routes on the galactic chart. Infected systems pay huge prices for medical supplies, but docking there risks bringing the infection aboard. Each station has a quarantine status: open, screening (cargo inspected), or sealed (smuggle in). Your choice of route either slows the spread or speeds it up.
2. **Derelict Boarding.** Dead ships drift in space. Docking with one switches to a short first-person or top-down boarding section: clear the corridors, grab the black box or cargo, and get out before the oxygen runs out. Some derelicts aren't dead: their reactors come back on and the ship chases you, flown by whatever is left of the crew.
3. **Necrotic Ships.** The ships themselves are the zombies. A nanite or bio-swarm takes over hulls, and a destroyed ship can come back as a slower, tougher, twitchier version that tries to ram you. Anything killed near an infected ship can become another one, so fights snowball if you're slow. Scooping their wreckage pays well and puts your cargo hold at risk.
4. **Last Station Standing (survival).** A station in a collapsing system is overrun, and you're the only pilot with a working ship. Each trip carries a few evacuees to safety, but some are infected and turn mid-flight, damaging systems from inside your ship. Screening takes time you don't have.
5. **Witchspace Horrors.** Misjumps drop you into "dead space," where Thargoid-like hulks drift, half-alive. Navigation is unreliable, the scanner shows things that aren't there, and you need fuel to escape. A horror version of being stranded between systems.
6. **Infected Pilot (you're the zombie).** You catch the infection and your stats slowly change: better reflexes and night vision, but stations refuse you docking, police turn hostile, and your controls start drifting. Race across several systems to buy a cure, or accept it and become a pirate legend among the undead.
7. **Cargo That Moves.** "Biological samples" and "slaves" in the hold aren't always what the label says. A cargo pod can breach, and dumping it starts a small outbreak at whatever is nearby. A moral and economic twist on contraband.
8. **Faction War: The Living vs. the Hive.** A galaxy-wide campaign. The infection behaves like a faction with territory on the chart, and other factions bid for your services: Navy blockades, cure researchers, cultists who want it to spread, scavengers profiting from the collapse. Your missions move the frontier.

## How hard each would be in Oolite

| Idea | Main hooks |
|---|---|
| Plague Run | System info overrides, market scripts, docking checks |
| Necrotic Ships | `shipDied` handlers that respawn a variant role; custom AI |
| Cargo That Moves | Custom commodity, a timer that damages the player ship |
| Infected Pilot | Player script that degrades stats and changes legal status |
| Derelict Boarding | Needs a new game mode, so it's the hardest |

The strongest core is Necrotic Ships plus the Plague Run: together they change combat and trade without needing a new game mode.
