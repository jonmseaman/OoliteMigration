# Frontier: Elite II and First Encounters — Feature Reference

Nov 1, 2026 · @Jon Seaman

## Overview and timeline

Frontier: Elite II (1993) and Frontier: First Encounters (1995) rebuilt Elite as a simulation: Newtonian flight through a full-scale Milky Way, with planets you can land on, two superpowers and a bulletin board of jobs. They sit between the 1984 original and Elite Dangerous, and many Elite Dangerous features first appear here in a simpler form.

|  | Frontier: Elite II | Frontier: First Encounters |
| --- | --- | --- |
| Released | October 1993; Amiga CD32 port in 1994 | Easter (April) 1995 |
| Platforms | Amiga, Atari ST, PC (DOS), Amiga CD32 | PC (DOS), on floppy and CD-ROM |
| Made by | David Braben, in about 250,000 lines of 68000 assembly; Chris Sawyer ported it to the PC | Frontier Developments, Braben's new studio: eight programmers, Braben and Sawyer among them |
| Publisher | GameTek, after Konami sold on its rights | GameTek |
| Music | David Lowe | David Lowe |
| Sales | About 500,000 | About 100,000 |
| Year at the start | 3200 | 3250 |
| Default start | Ross 154, Eagle Long Range Fighter, 100 credits | Gateway, Saker Mk III, 1,000 credits |

Braben spent over five years on Elite II, after buying the sequel rights from Ian Bell in 1988 for 10% of his net receipts.

### Setting and starts

- In Elite II you play Commander Jameson's grandchild, who inherits the Eagle and the 100 credits.
- A fan guide lists two more starts, most likely Elite II's: Mars in the Sol system, the easiest, and Lave, in a Cobra Mk III owing 70,000 credits in fines to both superpowers.
- First Encounters' scripted missions run from 3250 to about 3255. The Elite II start is still in its program: press 1 during the intro video.
- Elite Dangerous starts in 3300, so the series' clock moves in 50-year steps.

### What Frontier changed from Elite

- **Flight:** Newtonian physics. The fastest ships accelerate at more than 10 g.
- **Planets:** fly down through the atmosphere and land at a surface starport, or anywhere flat if you are skilled enough.
- **Systems:** whole systems at full scale, with planets and moons in motion, where Elite had one planet and one station.
- **Galaxy:** the whole Milky Way, with real stars such as Sol, Alpha Centauri, Sirius, Altair, Antares, Betelgeuse and Polaris.
- **Time:** a calendar, hyperspace jumps that take days, and time acceleration up to 10,000×.
- **Politics:** the Federation and the Empire, each with navy ranks and military missions.
- **Work:** a bulletin board of deliveries, passengers and assassinations; mining machines dropped on planets; black markets.
- **Graphics:** filled, shaded polygons in place of wireframe, and texture mapping on the PC.
- **No Thargoids:** hackers later found unused code tags for them and for cloaking devices.

First Encounters adds procedurally textured planet surfaces, five newspapers, video faces on the bulletin board and a five-year scripted story that brings back the Thargoids (see First Encounters: what changed).

### Legacy

- Braben conceived Elite Dangerous, provisionally Elite 4, in 1998. It launched on 16 December 2014.
- It keeps the Earth-based Federation and the Achenar-based Empire, adds the Alliance and brings back the Thargoids. Some Frontier systems carry over.
- Its flight assist makes Newtonian flight optional. Wikipedia contrasts its close dogfights with Frontier's jousting at long range.

[Wikipedia: Frontier: Elite II](https://en.wikipedia.org/wiki/Frontier:_Elite_II), [Wikipedia: Frontier: First Encounters](https://en.wikipedia.org/wiki/Frontier:_First_Encounters), [MCV: Elite IP profile](https://mcvuk.com/development-news/ip-profile-elite/), [Frontier Astro: Elite II](https://frontierastro.co.uk/Frontier/FE2/intro.html), [Frontier Astro: FFE at 25](https://frontierastro.co.uk/FFE25.html), [FFE start data](https://schmadalla.dyndns.org/Museum/ffe-hack.html), [Sharoma: starting guide](https://sharoma.com/frontierverse/starting.htm), [Wikipedia: Elite Dangerous](https://en.wikipedia.org/wiki/Elite_Dangerous)

## The galaxy

Both games model the whole Milky Way, about 75,000 light years across, on a grid of sectors roughly 8 light years square with Sol at (0,0). It is generated procedurally apart from 117 hand-placed systems, and only about 650 systems, most within about 120 light years of Sol, have starports.

### Scale and generation

- Each system's planets and moons form from a simulated aggregation of its mass, with a little randomness, so most stars have full planetary systems.
- Fan maps count over 3,800 populated systems. Many have no starport, and some have no planets at all.
- About 650 systems have starports: roughly 530 independent, 48 Federal and 41 Imperial, plus 23 Alliance systems in First Encounters.
- Zoomed right out, the map shows unreachable copies of the galaxy in a grid.

### Hand-placed systems

- 117 systems are placed by hand: 76 real stars within about 22 light years of Sol, 30 bright or famous stars out to 1,357 light years, and 11 Old Worlds from the 1984 game.
- The near stars carry catalogue names such as Lalande 21185, Wolf 359, Groombridge 1618, Luyten 789-6 and Lacaille 9352.
- The Old Worlds (Lave, Diso, Leesti, Zaonce, Tionisla, Riedquat, Orerve, Reorte, Quator, Orrere and Uszaa) sit together about 50 light years from Sol, each with one inhabited world round a single star.
- Jumping to Beta Lyrae, a contact binary 1,357 light years out, crashes the game.

### Stars

| Type | Example (sector) | Notes |
| --- | --- | --- |
| Type M red star | Kapteyn's Star (1,−1) | Settlements only underground |
| Faint type M star |  | Too dim for life |
| Type M flare star | YZ Canis Minoris (2,0) | Flares can raise its output tenfold |
| Type K star | Epsilon Indi (−1,−1) | Habitable zone close in |
| Type G star | Sol (0,0) | Habitable planets at 1–1.5 AU |
| Type F star | Facece (0,−4) | Habitable zone further out; radiation dangerous outdoors |
| Type A star | Altair (−2,1) | Harsh, hot, humid worlds |
| Type B star | Achenar (1,−4) | Very powerful |
| White dwarf | Anave (3,0) | A collapsed core; poor for life |
| Red giant | Arcturus (−2,0) |  |
| Bright giant | Alioth (0,4) | Inhabited planets beyond 35 AU, terraformed |
| Supergiant | Betelgeuse (59,14) |  |
| Blue supergiant | Rigel (92,6) | Unexplored in Elite II |

- There is no type O. Systems hold one to six stars; Castor has six.
- Brown dwarfs count as bodies, not stars. At Phekda, terraformed moons orbit one.

### Planets and other bodies

- **Life-bearing:** worlds with native life and oxygen (Earth); terraformed worlds with introduced life (at Epsilon Indi, Alioth and Achenar); small terraformed worlds with thin CO₂ air (Mars).
- **Corrosive:** rocky worlds under thick corrosive air (Venus), and worlds with methane, ammonia or water weather systems under corrosive air (Titan has methane).
- **Rock and ice:** thin-aired rocky planets ripe for terraforming; highly volcanic worlds such as Io, of which only two or three exist; small barren spheres of rock (Ceres); barren planetoids such as the Moon, where mining is illegal; asteroids such as Phobos.
- **Ice and ocean:** Merlin, at Ross 154, is a global salt-water ocean under an ice sheet, with Sirocco Starport built on the ice.
- **Gas giants:** four sizes, from small (Uranus) to very large; medium ones have prominent rings. They are the fuel stops.
- **Brown dwarfs:** about 20–50 Jupiter masses.
- Hand-placed systems hold up to 43 major bodies (Sol); Achenar has 28.

### Starports

- Orbital starports come in three kinds: trading posts, stations and orbital cities. Surface starports have 2, 4 or 6 landing pads, and the count shows the planet's trade and population.
- A system can have several of each, or none even when inhabited. Each starport offers a stock market, bulletin board, shipyard, police and launch control.
- First Encounters rebuilt some: double-capacity trading posts, orbital cities of two to four modules, cities grown round six-pad ports, and half-moon Alliance ports.
- Sol's starports include Apollonius City on the Moon, Columbus orbiting Io, Titan City, and Quenisset and Olympus Village on Mars.

### Systems and governments

The system screen shows population, allegiance, government, economy, major imports and exports, and illegal goods; core systems add a paragraph of history. No tech level or danger rating appears.

Starport systems by government type. Anarchy and corporate rule cover 71% of the 574 systems counted (approximate fan counts; * First Encounters only).

| Government | Systems |
| --- | --- |
| Anarchy | 190 |
| Policed by local corporations | 130 |
| Corporate state | 90 |
| Federal democracy | 40 |
| Imperial colonial rule | 30 |
| Alliance democracy * | 23 |
| Independent democracy | 12 |
| Dictatorship | 12 |
| Imperial rule | 10 |
| Civil war | 10 |
| Rule by force of local barons | 6 |
| Federal colonial rule | 5 |
| Religious dictatorship | 4 |
| None | 4 |
| Martial law | 3 |
| Communist | 3 |
| Thargoid * | 2 |

Most starport systems are anarchies or run by corporations; the superpowers' own governments run a few dozen each.

Each government comes with a fixed economy type, from "Unstable – survival of the best armed" through corporate and capitalist variants to socialist and communist.

### Famous systems

| System (sector) | What's there |
| --- | --- |
| Sol (0,0) | The Federation capital. Earth is a tourist world for the very rich; Mars, terraformed in 2290, holds the corporate offices; the Museum of Humanity is on the Moon |
| Ross 154 (−1,0) | A Federal colony of 1 million and the standard start, at Sirocco Starport on Merlin |
| Barnard's Star (−1,0) | One M star with 10 major bodies, 5.8 light years from Sol |
| Eta Cassiopeia (0,2) | The Federal naval base |
| Achenar (1,−4) | The Imperial capital. The Emperor's pink glass palace is on Capitol; visitors need a permit; radioactives and nerve gas are illegal |
| Facece (0,−4) | The Empire's second capital and a fleet base; Peter's Wreck is an interdicted military training world |
| Lave (−3,−6) | An independent dictatorship under Dr Walden and the Old Worlds' trading centre; its rain forests are being cleared and the Lavian tree grub is nearly extinct |
| Alioth (0,4) | A bright giant fought over in Elite II; the Alliance capital in First Encounters |
| Beta Lyrae (−146,85) | 1,357 light years out; jumping there crashes the game |

[Aminet review of Frontier, 1993](https://ftp.fau.de/mirrors/aminet/docs/rview/Frontier.txt), [Frontier Astro: hand-coded systems](https://frontierastro.co.uk/Systems/systems4.html), [Frontier Astro: systems with starports](https://frontierastro.co.uk/Systems/systems3.html), [Frontier Astro: star systems](https://frontierastro.co.uk/Systems/systems.html), [Frontier Astro: small stars](https://frontierastro.co.uk/FrontierObjects/stars1.html), [Frontier Astro: medium stars](https://frontierastro.co.uk/FrontierObjects/stars2.html), [Frontier Astro: giant stars](https://frontierastro.co.uk/FrontierObjects/stars3.html), [Frontier Astro: orbital starports](https://frontierastro.co.uk/changes/orbits.html), [Frontier Astro: surface starports](https://frontierastro.co.uk/changes/ports.html), [Frontier Astro: Gazetteer](https://frontierastro.co.uk/Gazetteer/side.html), [Sharoma: stars](https://sharoma.com/frontierverse/stars.htm), [Sharoma: planets](https://sharoma.com/frontierverse/planets.htm), [Sharoma: politics](https://sharoma.com/frontierverse/politics.htm), [sslmit: real star systems](https://www.sslmit.unibo.it/zat/images/cartography/FE2-FFE_real_systems.htm), [Wikipedia: Frontier: Elite II](https://en.wikipedia.org/wiki/Frontier:_Elite_II)

## Ships

Elite II sells 29 ships, from an 8 t interplanetary shuttle at 14,000 credits to the 2,000 t Panther Clipper at 2,753,000; First Encounters keeps them all and adds 16 more. Each hull comes down to about nine numbers: forward and reverse thrust, mass, capacity, crew, gun mounts, missile pylons, a fuel-scoop mounting and the standard drive.

### Elite II ships

| Ship | Allegiance | Mass (t) | Capacity (t) | Thrust fwd / rev (g) | Crew | Gun mounts | Missiles | Standard drive | Price (credits) | Range (ly) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Interplanetary Shuttle | All | 8 | 4 | 5 / 3 | 1 | 0 | 0 | Interplanetary | 14,000 | 0 |
| Lifter | Federal | 10 | 7 | 4 / 2 | 1 | 0 | 0 | Interplanetary | 16,000 | 0 |
| Osprey | Imperial | 15 | 11 | 27 / 8 | 1 | 1 | 2 | Military 1 | 45,000 | 13.3 |
| Falcon | Federal | 16 | 11 | 30 / 9 | 1 | 1 | 2 | Military 1 | 46,000 | 12.5 |
| Hawk Airfighter | Federal | 18 | 7 | 27 / 6 | 1 | 1 | 2 | Military 1 | 48,000 | 11.1 |
| Kestrel Airfighter | Federal | 20 | 9 | 25 / 6 | 1 | 1 | 2 | Military 1 | 50,000 | 10.0 |
| Eagle Long Range Fighter | Federal, Imperial | 25 | 20 | 25 / 10 | 1 | 1 | 2 | Class 1 | 38,000 | 8.0 |
| Eagle Mk II | Federal | 28 | 22 | 28 / 4 | 1 | 1 | 2 | Class 1 | 41,000 | 7.1 |
| Eagle Mk III | Imperial | 30 | 22 | 28 / 15 | 1 | 1 | 2 | Class 1 | 43,000 | 6.6 |
| Sidewinder | Independent | 33 | 25 | 23 / 12 | 1 | 1 | 0 | Class 1 | 44,000 | 6.1 |
| Krait | Independent | 35 | 27 | 20 / 10 | 1 | 1 | 4 | Class 1 | 50,000 | 5.7 |
| Gecko | Independent | 45 | 34 | 16 / 9 | 1 | 2 | 1 | Class 2 | 66,000 | 17.8 |
| Adder | Independent, Federal | 55 | 40 | 18 / 8 | 1 | 1 | 0 | Class 2 | 73,000 | 14.5 |
| Viper Defence Craft | All | 65 | 50 | 24 / 10 | 1 | 1 | 4 | Class 2 | 87,000 | 12.3 |
| Cobra Mk I | Independent, Federal | 75 | 60 | 16 / 6 | 1 | 2 | 2 | Class 2 | 97,000 | 10.7 |
| Moray Starboat | Independent, Federal | 87 | 70 | 14 / 6 | 1 | 1 | 4 | Class 2 | 109,000 | 9.2 |
| Cobra Mk III | Independent, Federal | 100 | 80 | 20 / 7 | 1 | 2 | 4 | Class 2 | 124,000 | 8.0 |
| Constrictor | Independent, Federal | 120 | 90 | 22 / 10 | 2 | 2 | 2 | Class 2 | 143,000 | 6.6 |
| Asp Explorer | Independent, Federal | 150 | 120 | 22 / 7 | 2 | 2 | 1 | Class 3 | 187,000 | 12.0 |
| Transporter | Independent, Federal | 200 | 160 | 9 / 4 | 3 | 3 | 2 | Class 3 | 241,000 | 9.0 |
| Lion Transport | Federal | 300 | 235 | 5 / 3 | 4 | 3 | 8 | Class 3 | 348,000 | 6.0 |
| Tiger Trader | Federal | 400 | 320 | 12 / 5 | 5 | 3 | 1 | Class 4 | 472,000 | 8.0 |
| Imperial Courier | Imperial | 480 | 350 | 16 / 6 | 3 | 1 | 6 | Class 5 | 611,000 | 10.4 |
| Python Freighter | Independent | 500 | 400 | 10 / 4 | 7 | 2 | 4 | Class 4 | 575,000 | 6.4 |
| Imperial Trader | Imperial | 700 | 525 | 9 / 4 | 6 | 1 | 6 | Class 6 | 954,000 | 10.3 |
| Anaconda | Independent | 800 | 650 | 6 / 3 | 8 | 2 | 8 | Class 6 | 1,060,000 | 9.0 |
| Puma Shuttle | Federal | 1,000 | 825 | 6 / 3 | 9 | 4 | 8 | Class 6 | 1,265,000 | 7.2 |
| Boa | Independent | 1,500 | 1,300 | 8 / 4 | 10 | 4 | 6 | Class 8 | 2,474,000 | 10.8 |
| Panther Clipper | Federal | 2,000 | 1,775 | 6 / 3 | 12 | 4 | 8 | Class 8 | 2,753,000 | 9.1 |

- Mass is the ship fully laden. Capacity is the internal space that the drive, equipment, fuel and cargo share.
- Gun mounts: 1 is the front, 2 adds the rear, 3 adds a top turret and 4 a bottom turret.
- The figures are a fan transcription of the Elite II manual, which shipped with some wrong specs. It prints 1 t of capacity for the Osprey and Falcon; 11 t, from First Encounters, is the only figure that fits their 6 t drives.
- Hulls without a fuel-scoop mounting: the shuttles, light fighters, Eagles, Krait, Gecko, Transporter, Imperial Courier, Imperial Trader and Panther Clipper.
- Civilian hulls cost about 1,150–1,650 credits per tonne, military fighters 2,500–3,000. The upgrade ladder runs Eagle, Cobra Mk III, Asp, Python, Panther, roughly tripling in price at each step.
- The Python carries the most hold per credit. The Panther is the biggest ship you can own and the best earner, but it needs 12 crew.
- Elite's Fer-de-Lance is the one classic ship that doesn't return.

### First Encounters additions

| Ship | Mass (t) | Capacity (t) | Thrust fwd / rev (g) | Crew | Gun mounts | Missiles | Standard drive | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Saker Mk III | 28 | 23 | 21 / 10 | 1 | 2 | 2 | Class 1 | The starting ship; built by the Alliance's New Rossyth yards |
| Merlin | 35 | 27 | 22 / 11 | 1 | 1 | 2 | Class 1 | Perez Corporation; often bought as a second ship |
| Osprey X | 35 | 29 | 29 / 9 | 1 | 2 | 4 | Military 1 | Hard to find |
| Spar Attack Fighter | 49 | 37 | 17 / 9 | 1 | 2 | 2 | Class 2 |  |
| Viper Mk II | 67 | 52 | 25 / 11 | 1 | 1 | 4 | Class 2 | Faulcon de Lacy, 3248; replaces the police Viper |
| Gyr | 78 | 62 | 15 / 6 | 1 | 2 | 4 | Class 2 | Rare |
| Harris Fighter | 111 | 83 | 21 / 9 | 3 | 2 | 2 | Class 2 | A Moray's hold with far better performance |
| Harrier | 134 | 109 | 21 / 8 | 2 | 2 | 4 | Class 3 |  |
| Wyvern Explorer | 183 | 148 | 13 / 6 | 3 | 2 | 2 | Class 3 | Built to replace the Transporter |
| Lanner | 245 | 198 | 8 / 4 | 3 | 2 | 2 | Class 3 | Common among traders and pirates |
| Lanner 2 | 271 | 211 | 7 / 4 | 3 | 2 | 2 | Class 3 |  |
| Tiercel Freighter | 328 | 257 | 10 / 4 | 6 | 1 | 4 | Class 4 |  |
| Skeet Cruiser | 562 | 427 | 9 / 4 | 6 | 2 | 6 | Class 5 | Little better than the Python |
| Mantis Transport | 915 | 749 | 6 / 3 | 8 | 4 | 8 | Class 6 | Alliance-built, designed by Mic Turner |
| Turner Class | 1,272 | 1,243 | 24 / 9 | 1 | 1 | 6 | Military 4 | Not for sale: four were built, and the story lends you one |
| Imperial Explorer | 1,996 | 1,785 | 8 / 5 | 10 | 2 | 6 | Class 8 | The most expensive ship on public sale; the Elite II manual doesn't list it |
| Griffin Carrier | 2,425 | 2,184 | 5 / 3 | 12 | 4 | 8 | Class 8 | Over 3 million credits; the largest you can buy |

- The figures come from the Elite Wiki, which gives no source. Carried-over ships keep their Elite II stats, apart from a few disputed values such as the Boa's crew.
- Open question: the new ships' prices aren't documented, apart from the Griffin's.

### Faction and NPC craft

- Every police force flies the Viper Defence Craft; First Encounters adds the Viper Mk II.
- The Federal military flies the Falcon, the fastest ship at 30 g, plus the Hawk, the Kestrel and the Eagle Mk II. The Imperial Navy flies the Osprey, the Eagle Mk III, the Imperial Courier and the Imperial Trader, a former troop transport.
- Several civilian hulls have military pasts, among them the Asp, the Constrictor and both Imperial ships.
- Nobody can own the Lynx Bulk Carrier (7,200 t, 20 crew), which can't dock, or the Long Range Cruiser (16,000 t, 100 crew), which is scenery and sometimes a generation ship. Thargoid ships cannot legitimately be owned either.

### Shipyards

- You own one ship at a time. Buying another part-exchanges the old one.
- Richer systems stock more, and some hulls sell only in their own faction's space: the Imperial Trader is Empire-only.
- Big ships need crew, hired from the bulletin board at about 15–20 credits a week each, and recruiting can take weeks. The crew count includes you.
- The escape capsule's insurance gets you a free Eagle.

[Sharoma: ship specs](https://sharoma.com/frontierverse/ship_specs.htm), [Sharoma: ships guide](https://sharoma.com/frontierverse/ships.htm), [Sharoma: basics](https://sharoma.com/frontierverse/basics.htm), [Sharoma: police](https://www.sharoma.com/frontierverse/police.htm), [Elite Wiki: FFE ships](https://wiki.alioth.net/index.php/FFE_Ships), [Elite Wiki: Turner Class](https://wiki.alioth.net/index.php/Turner_Class), [Frontier Astro: FFE ship changes](https://frontierastro.co.uk/changes/ships.html), [FFE game data](https://schmadalla.dyndns.org/Museum/ffe-hack.html), [Aminet review of Frontier, 1993](https://ftp.fau.de/mirrors/aminet/docs/rview/Frontier.txt), [GEnie Atari ST log, 1994](https://sunsite3.icm.edu.pl/packages/umich-atari/Games/Gameutil/elite_2.txt), [Wikipedia: Frontier: Elite II](https://en.wikipedia.org/wiki/Frontier:_Elite_II)

## Equipment and drives

Every item has a mass that comes out of one internal capacity shared with the drive, guns, fuel, cabins and cargo, so a fit-out is a trade between range, firepower and hold space. Hyperdrives run from a 5 t class 1 to a 600 t class 8, and a jump at a drive's full range always takes one week, so a bigger drive is also a faster one.

### Hyperdrives

| Drive | Mass (t) | Notes |
| --- | --- | --- |
| Interplanetary drive | 4 | No hyperspace: flight within a system only |
| Class 1 | 5 | The starting Eagle's drive |
| Class 2 | 25 | Standard on the Adder and the Cobra Mk III |
| Class 3 | 45 |  |
| Class 4 | 80 |  |
| Class 5 | 150 |  |
| Class 6 | 250 |  |
| Class 7 | 400 | The largest at ordinary shipyards; players report about 5.2 ly in a Puma |
| Class 8 | 600 | From specialists only; standard on the Boa |
| Military class 1 | 6 | Burns military fuel |
| Military class 2 | 12 |  |
| Military class 3 | 24 | The largest on sale |
| Military class 4 (First Encounters) |  | Defined in the game data |
| Thargoid drive (First Encounters) |  | Behaves like a class 8 military drive |

The masses are a fan site's figures, listed in class order without naming each class.

- Range depends on drive class and ship mass: a class 3 drive reaches further in a 200 t ship than in a 300 t one. A fan table fits range ≈ 200 × class² ÷ ship mass in tonnes for 27 of its 29 ships, so a 100 t Cobra Mk III with a class 2 drive reaches 8 light years. The Elite Wiki's figures fit 300 instead, so treat it as a rule of thumb.
- Jump fuel is hydrogen carried in the hold, and the amount depends on distance and drive. Normal flight burns a separate engine tank (1 t for class 1 engines, 2 t for class 2), refilled from the hold a whole tonne at a time.
- Military drives are lighter for their range, but military fuel is scarce and expensive, and every tonne burned becomes a tonne of radioactive waste. You pay to unload it, and dumping it in space is illegal.

### Equipment

| Item | Mass (t) | What it does |
| --- | --- | --- |
| Military camera | 0 | Supplied by the navy for reconnaissance missions |
| Automatic pilot | 1 | Flies to any target in the current system, asking clearance and docking or landing; can't cross between systems |
| Autorefueller | 1 | Moves fuel from the hold to the engine tank when needed, so the engine never cuts out mid-fight |
| Scanner | 1 | 3D display of nearby objects; a blip's colour shows its mass in eight bands, from 1–15 t to over 300 t |
| Radar mapper | 1 | Shows a target's shields, hyperspace range and key kit, and checks it against the wanted list; no bounty is paid unless it identified the ship |
| Hyperspace cloud analyser | 1 | Reads a hyperspace cloud for the ship's destination, mass and exact arrival time, so you can follow it |
| Cargo bay life support | 1 | Needed to carry live animals and slaves |
| Atmospheric shielding | 1 | Lets a ship fly fast in an atmosphere; needed to scoop gas giants |
| Cargo scoop conversion | 2 | Lets the fuel scoop pick up cargo, dummy mines, ore and wreckage |
| Escape capsule | 5 | The cockpit detaches and flies itself to the nearest starport; insurance replaces your ship with a basic Eagle |
| Passenger cabin | 5 | Holds one passenger, with life support |
| Fuel scoop | 6 | Scoops hydrogen below about 30 km from gas giants, or from cool stars if shielded; needs a hull with a scoop mounting |
| MB4 mining machine | 30 | Landed on a world below 200 °C, it mines and refines minerals, alloys and sometimes gems into a 10 t hopper; other pilots can steal your rigs |
| Hull auto-repair system | 40 | Slowly reverses all hull damage; large ships only |

- Built into every Elite II ship: automatic hull sealing, the Stardreamer time control and the Galactonav maps.
- First Encounters adds about a dozen items whose masses and effects are mostly undocumented: a navigation computer, combat computer, auto targetter, transmission jammer, tracking device, chaff dispenser, missile viewer, inter-species translator, and a StowMaster fighter with its launch device.
- Its tractor beam cargo scoop needs no fuel scoop, and players call it essential for asteroid mining. Its escape capsule launches only when the ship is destroyed.

### Fitting and trade-in

- Hull data fixes the gun mounts, the missile pylons and whether a fuel scoop fits. A courier is mostly engine; a warship trades drive for guns.
- What's on sale depends on the starport's size and the system's population and allegiance, not on tech levels. A shipyard that doesn't stock an item can't fit, remove or repair it.
- Equipment wears: unserviced items grow unreliable, then fail and show faded until repaired. Some shipyards repair badly.
- On trade-in only the hyperdrive affects a ship's value, so players strip extras first. Larger ships can't take off without crew, whose cabins come with the ship.
- Your cash survives the loss of your ship, thanks to automatic banking.
- Open question: no source lists the price of any drive, equipment item or weapon.

[Frontier: Elite II manual (fan transcription)](https://sharoma.com/frontierverse/files/docs/english_manual.pdf), [Sharoma: equipment](https://sharoma.com/frontierverse/equipment.htm), [Sharoma: basics](https://sharoma.com/frontierverse/basics.htm), [FFE game data](https://schmadalla.dyndns.org/Museum/ffe-hack.html), [Elite Wiki: miscellaneous equipment](https://wiki.alioth.net/index.php/Miscellaneous_Equipment), [Elite Wiki: Adder](https://wiki.alioth.net/index.php/Adder_%28Frontier%29), [Elite Wiki: Cobra Mk 3](https://wiki.alioth.net/index.php/Cobra_Mk_3_%28Frontier%29), [Elite Wiki: Boa](https://wiki.alioth.net/index.php/Boa_%28Frontier%29), [alt.fan.elite FAQ](https://ftp.nvg.ntnu.no/pub/bbc/doc/games/EliteFAQ.htm), [GEnie Atari ST log, 1994](https://sunsite3.icm.edu.pl/packages/umich-atari/Games/Gameutil/elite_2.txt)

## Weapons

Guns run from a 1 t, 1 MW pulse laser to a 900 t large plasma accelerator, and their real cost is mass: a 20 MW beam laser takes 75 t of the hold. Every missile flies at 65 g with about a minute of fuel, and a three-step ECM ladder decides which ones get through.

### Guns

| Weapon | Power | Mass (t) | Fire and heat | Notes |
| --- | --- | --- | --- | --- |
| 1 MW pulse laser | 1 MW | 1 | A pulse about every 0.6 s | The starting gun |
| 5 MW pulse laser | 5 MW | 3 | As above | The first usable laser, by the Elite Wiki; good in turrets |
| 30 MW mining laser | 30 MW | 10 | Slow to repeat, long cool-down | Breaks asteroids for mining |
| 1 MW beam laser | 1 MW | 5 | Continuous; rarely overheats | Beams do far more damage than pulses |
| 4 MW beam laser | 4 MW | 20 | Overheats under sustained fire |  |
| 20 MW beam laser | 20 MW | 75 | Overheats | Kills normal targets quickly; a 1994 player said a later version made it 25 t heavier |
| 100 MW beam laser | 100 MW | 200 | Overheats very fast |  |
| Small plasma accelerator |  | 500 | One shot, then a few seconds to recharge; no heat | One shot destroys a well-armed 100 t ship; fitted to big ships and navy craft |
| Large plasma accelerator |  | 900 | As above | The manual calls it the ultimate weapon, for orbital strikes on cities |
| Thargoid laser (First Encounters) |  |  | Blue, with a small explosion at the end | Thargoid ships only |

- Lasers work out to about 8 km and weaken with distance; a beam can glance off a surface and still do serious damage.
- Overheating trips a cut-out for a few seconds without harming the laser. A 1 t laser cooling booster makes it cool faster.
- One gun per mounting: the front, the rear if the hull has one, and top and bottom turrets on larger ships. The view you pick decides which gun fires.
- In-world, left and right mounts were banned after pilots kept shooting friends and police. First Encounters hulls have 1 to 4 gun mounts, and turret fire can hit your own hull.
- Only the biggest shipyards sell the full range of guns.
- Open question: no source gives damage values.

### Missiles, mines and ECM

| Item | Mass (t) | Behaviour | Stopped by |
| --- | --- | --- | --- |
| KL760 homing missile | 1 | Kills small ships, damages larger ones | ECM or naval ECM |
| LV111 smart missile | 1 | A bigger warhead | Naval ECM only |
| NN500 navy missile | 1 | Bigger again | Nothing |
| Nuclear missile | 1 | Issued one at a time by the navy for bombing missions |  |
| XB13 proximity mine | 1 | Carried on a pylon; explodes when its assigned target comes in range | ECM or naval ECM |
| XB74 dummy mine | 1 | Looks like a live mine, even on radar, but does nothing; can be scooped as cargo |  |
| Energy bomb | 4 | Overloads the reactors of small ships within about 100 km, sparing your own; a strong shield resists it |  |
| ECM | 2 | Destroys homing missiles and mines within about 100 km, your own included |  |
| Naval ECM | 2 | Also destroys smart missiles, out to about 200 km; larger shipyards only |  |

- A missile needs a target, steers round other objects, and a near miss does almost as much damage as a hit. It self-destructs when its fuel runs out.
- Fire close and nose-on, or the missile wastes fuel turning and the target has time to fire its ECM. Beam lasers can shoot missiles down.
- Pylons vary by hull: none on the Adder, 4 on the Cobra Mk III, 6 on the Boa.
- Players report a 10,000-credit fine for piracy and murder for an energy bomb near a station, and one bomb lifting a pilot straight to Dangerous.

### Shields and damage

- Shield generators (4 t each) stack. While any charge remains no weapon damage reaches the hull, but shields do little against collisions.
- Each generator refills in the same fixed time however many are fitted, so ten generators restore one generator's worth in a tenth of the time. A 10 t energy booster speeds up all of them.
- The shield glows bluish white at full charge, then yellow, orange and red as it drains.
- Players report big ships with dozens of generators: 68 on an Imperial Trader, 111 in one build.
- Automatic hull sealing stops one hit decompressing the whole hull. Shipyards, or the 40 t auto-repair system, fix hull damage.
- Combat rarely ends without repairs: equipment can be shot out, and a damaged hyperdrive can't jump.

[Frontier: Elite II manual (fan transcription)](https://sharoma.com/frontierverse/files/docs/english_manual.pdf), [Sharoma: equipment](https://sharoma.com/frontierverse/equipment.htm), [FFE game data](https://schmadalla.dyndns.org/Museum/ffe-hack.html), [Elite Wiki: weapons](https://wiki.alioth.net/index.php/Weapons), [Elite Wiki: combat equipment (FFE)](https://wiki.alioth.net/index.php/Combat_Equipment_%28FFE%29), [Elite Wiki: FFE combat advice](https://wiki.alioth.net/index.php/FFE_Combat_Advice), [alt.fan.elite FAQ](https://ftp.nvg.ntnu.no/pub/bbc/doc/games/EliteFAQ.htm), [FRONTIER.TXT player guide](https://bearstrong.net/tekst97/data/spill/frontier/), [GEnie Atari ST log, 1994](https://sunsite3.icm.edu.pl/packages/umich-atari/Games/Gameutil/elite_2.txt)

## Flight, navigation and time

Flight is fully Newtonian: ships keep their momentum, thrust is rated in g, and speed is measured against one reference body whose gravity alone acts on you. Three engine modes, an autopilot and time acceleration up to 10,000× make full-scale distances playable.

### Flight model

- Ships keep their speed and direction until a thruster or a collision acts, and can turn without changing course. Main thrust runs from 4 g to 30 g, and retro thrust is usually 30–60% of main.
- Speed shows in km/s relative to a reference body named on screen, and only that body's gravity counts. Orbits are fixed paths, not Keplerian.
- In First Encounters, changing reference body keeps your relative speed, so your true velocity jumps. Players use it to match a moon's orbit instantly; JJFFE fixed it.
- Distances are real: even at more than 10 g, crossing a system takes hours. Slingshots work round massive stars and large planets.
- Heavy ships drop like bricks on high-gravity worlds, where the autopilot can't slow them.
- Players fight at around 1,000 km/h relative to the reference body.

### Atmospheres and landing

- Atmospheric shielding allows fast entry; without it, fast atmospheric flight destroys the hull.
- To scoop a gas giant, aim at the horizon at 15,000 km/h, then slow to about 4,000 km/h in the atmosphere. Scooped hydrogen fills the hold first. Skimming a star also needs shield generators.
- You can land anywhere. With an atmosphere, cut the engines and let gravity lower you; without one, keep slight thrust nose-down and level off at 50–100 m.
- Landing outside a designated zone is legal unless you're told otherwise.

### Engine modes and autopilot

- Three engine modes share one key (F7 on the Elite II PC, Tab in First Encounters): engines off, with raw main and retro thrust; set speed, where the computer holds a speed relative to the reference body; and autopilot.
- The autopilot flies to a target in the system, requests clearance, lowers the undercarriage and docks or lands. It flies straight lines and can fly into a planet.
- First Encounters adds a navigation computer and a combat computer (see First Encounters: what changed).

### Docking and launching

- You need clearance to dock, land and launch, asked for on the communications screen or by the autopilot. A station can refuse while its bay is busy, and directs you to an assigned bay or pad.
- Taking off without clearance brings police who shoot you down.
- Manual landing: ask for clearance at about 100 m, fly over the assigned pad, lower the undercarriage and descend at about 50 km/h, then level off at 20 m and stop.
- You can't jump near a station or port. Leaving a planet, the hyperspace control appears at about 11,000 m.
- Open question: no source says whether clearance expires.

### Hyperspace

- Pick a star on the galactic map, and the screen shows the fuel needed or "Out of Range". Range falls as ship mass rises (see Equipment and drives).
- A jump at full range takes a week and a shorter one proportionally less. You arrive on the outskirts of the target system.
- Every jump leaves a glowing cloud at both ends for some hours. A hyperspace cloud analyser reads a cloud's destination, arrival time and ship mass, and with a longer-range drive you can arrive first and wait.
- Misjumps are rare and usually come from an unserviced drive, so players service drives at least twice a year. Holding Alt while jumping forces one, which ignores range and fuel, leaves you in deep space and can't be traced.
- In one player's test of 100 forced misjumps in an Eagle, 65 landed within range, 23 wrecked the drive, 2 destroyed the ship and 10 went far off, 610 light years on average.

### Time

- The Stardreamer, standard on every ship, runs time at 10×, 100×, 1,000× or 10,000× and can pause. It drops to real time when you're attacked, hailed or arrive.
- The calendar runs on from 3200, or 3250 in First Encounters. Jumps take up to a week and cruises hours to days, so careers span game years; players reached 3204–3207 after months of play.
- Markets and the bulletin board refresh at midnight Galactic Mean Time. Mining machines need about 8 months before you collect, and passenger and mission deadlines run on the same clock.

### Maps

- The galactic map is a scrolling grid of sectors with Sol at (0,0). Selecting a star shows its data and the fuel for the jump, and systems within a sector are numbered.
- The system map is a zoomable, rotatable 3D orrery that zooms down to planet surfaces; you pick a body or port there for the autopilot. In First Encounters the local sector map rotates in 3D too.
- There is no route planner, so you plot multi-jump routes yourself. Elite II's box included a 58 × 73 cm poster of the core sectors.

[Elite Wiki: Newtonian modelling](https://wiki.alioth.net/index.php/Newtonian_modelling), [Frontier: Elite II manual (fan transcription)](https://sharoma.com/frontierverse/files/docs/english_manual.pdf), [Sharoma: basics](https://sharoma.com/frontierverse/basics.htm), [Sharoma: manoeuvres](https://www.sharoma.com/frontierverse/manoeuvres.htm), [Sharoma: controls](https://sharoma.com/frontierverse/controls.htm), [Aminet review of Frontier, 1993](https://ftp.fau.de/mirrors/aminet/docs/rview/Frontier.txt), [alt.fan.elite FAQ](https://rk.nvg.ntnu.no/bbc/doc/games/EliteFAQ.htm), [FRONTIER.TXT player guide](https://bearstrong.net/tekst97/data/spill/frontier/), [GEnie Atari ST log, 1994](https://sunsite3.icm.edu.pl/packages/umich-atari/Games/Gameutil/elite_2.txt), [FFE game data](https://schmadalla.dyndns.org/Museum/ffe-hack.html), [Planetmic: what was in the box](https://planetmic.com/orbit/feinbox.htm), [Wikipedia: Frontier: Elite II](https://en.wikipedia.org/wiki/Frontier:_Elite_II)

## Trading and economy

Elite II has 31 commodities, each traded by the tonne at a starport stock market whose prices reset every midnight; illegal goods never appear there and trade through bulletin-board dealers instead. First Encounters kept the system almost unchanged: Braben said trading got almost no work.

### Commodities

| Commodity | Default (Cr/t) | Import to export | Black market | Notes |
| --- | --- | --- | --- | --- |
| Water | 1.0 | 1.1–0.7 |  | For small industrial settlements and dry worlds |
| Liquid oxygen | 10.0 | 13.2–8.1 |  | Life support on airless worlds |
| Grain | 40.0 | 46.7–31.1 |  | Becomes rubbish if jettisoned |
| Fruit and vegetables | 100.0 | 127–77.6 |  | Becomes rubbish if jettisoned |
| Animal meat | 140.0 | 166–95.2 | 283 | Rare real meat; illegal in some places |
| Synthetic meat | 20.0 | 23.6–16.7 |  | Vat-grown, the commonest protein |
| Liquor | 400.0 | 456–343 | 580 | Becomes rubbish if jettisoned |
| Narcotics | 600.0 | 774–452 | 1,265 | Illegal in many places; Lyrae weed is the commonest |
| Medicines | 550.0 | 603–501 |  |  |
| Fertilizer | 15.0 | 16.9–11.8 |  | Jettisoned slaves officially become fertilizer |
| Animal skins | 800.0 | 948–608 | 1,545 |  |
| Live animals | 950.0 | 1,160–774 | 1,860 | Need cargo bay life support; become meat if jettisoned |
| Slaves | 1,000.0 | 1,200–708 | 2,010 | Illegal in many systems; need life support; die if jettisoned |
| Luxury goods | 1,400.0 | 1,600–1,220 | 2,840 | Perfumes, jewellery, artefacts, fabrics |
| Heavy plastics | 35.0 | 39.6–29.4 |  |  |
| Metal alloys | 25.0 | 30.4–20.2 |  | Includes foam metal |
| Precious metals | 1,700.0 | 1,782–1,451 |  | Cheaper in the outer systems |
| Gem stones | 3,000.0 | 3,110–2,840 | 5,700 | Fashion stones such as the Zublic |
| Minerals | 7.0 | 7.6–6.2 |  | Mined by machine on rocky planets |
| Hydrogen fuel | 9.8 | 11.4–7.6 |  | Ship fuel; scoopable from gas giants and stars |
| Military fuel | 50.0 | 60.2–40.0 |  | Scarce; burns into radioactives |
| Hand weapons | 500.0 | 566–412 | 996 | Illegal in many systems |
| Battle weapons | 600.0 | 789–544 | 1,190 | Usually illegal |
| Nerve gas | 800.0 | 931–621 | 1,640 | Police in most places will chase you |
| Industrial parts | 125.0 | 141–109 |  | Fusion motors to nuts and bolts |
| Computers | 450.0 | 507–366 |  |  |
| Air processors | 200.0 | 238–158 |  | Vital to underground mines |
| Farm machinery | 75.0 | 88.0–57.4 |  |  |
| Robots | 780.0 | 915–490 | 1,580 | Servants to assault troops; banned in a few cultures |
| Radioactives | −4.0 | −3.4 to −5.2 | −8.3 | You pay to unload them; dumping them is highly illegal |
| Rubbish | −0.6 | −0.6 to −0.8 |  | You pay to unload it |

The goods and notes come from the Elite II manual. The prices are fan figures: defaults recorded at Zeceand, which neither imports nor exports, with import-to-export bands and black-market estimates from a fan page.

### How markets work

- Each starport's stock market shows a price per tonne, its stock and your cargo, and each click trades one tonne. ZITCO, the Zebulon Intergalactic Trading Corporation, sets prices and resets them every midnight Galactic Mean Time.
- Buying a good out raises its price, and a big sale lowers it at the next reset. Imports cost more than the galactic average and exports less, by roughly 10–30%.
- Only legal goods are listed. The system data screen shows each system's imports, exports and illegal goods; there is no fixed ban list per allegiance.
- Anarchies ban nothing, and Imperial space bans almost nothing. Federal core systems crack down on narcotics and slaves.
- Outer systems pay nearly double core prices, but stock runs thin: Ayurso's starport may have only 4 t of fuel.
- Jettisoning any cargo is illegal, and some cargo changes when dumped: live animals become meat, slaves die, and liquor, luxuries and food become rubbish.
- Money sits in an automatic bank, as a signed count of tenths of a credit, so it survives losing your ship. In early copies it rolled negative above about 214 million credits.

### Black market

- Illegal goods trade through "Goods bought and sold" adverts on the bulletin board, at about twice the standard price by fan estimates.
- Some of those adverts are police traps, and customs can still catch you after a deal. Players spot traps because the dealer's name changes between visits.
- Wanted adverts from buyers in a hurry often pay double the market price.

### Routes players used

- **Sol and Barnard's Star:** food and luxuries out, robots and computers back.
- **Facece to Vequess:** live animals, skins, meat and food out; slaves or robots back.
- **Sol to Lalande 21185:** liquor or luxuries out; narcotics and nerve gas back, for nearly triple the profit at Sol.
- **Enfacan to Enioar:** precious metals bought at about 1,500 credits and sold for about 3,000.
- **First Encounters:** medicine to Soholia in the first two months, at 2,000 credits a tonne, beats the opening race.
- Early copies had money bugs: negative-priced gems at Cemiess paid you to take them, and a ship-sale bug let players keep both the ship and the money.

[Frontier: Elite II manual](https://archive.org/details/frontier-manual), [Sharoma: merchandise](https://www.sharoma.com/frontierverse/merchandise.htm), [Sharoma: trading](https://www.sharoma.com/frontierverse/trading.htm), [Sharoma: basics](https://sharoma.com/frontierverse/basics.htm), [Sharoma: police](https://sharoma.com/frontierverse/police.htm), [Sharoma: politics](https://www.sharoma.com/frontierverse/politics.htm), [Elite Wiki: wages and prices in FFE](https://wiki.alioth.net/index.php/Wages_and_Price_of_Goods_in_FFE), [Elite Wiki: ZITCO GCTS](https://wiki.alioth.net/index.php/ZITCO_GCTS), [Elite Wiki: alt.fan.elite FAQ part 4](https://wiki.alioth.net/index.php/AFE_FAQ4), [Clayton review, 1993](https://www.math.uh.edu/~barrett/data/all/Frontier), [FFE game data](https://schmadalla.dyndns.org/Museum/ffe-hack.html), [Wikipedia: Frontier: First Encounters](https://en.wikipedia.org/wiki/Frontier:_First_Encounters)

## Missions and the bulletin board

Every starport has a bulletin board of small adverts, refreshed daily: passengers, packages, assassinations, buyers, black-market dealers, crew and the local navy. Pay is negotiated, and your reputation decides who will deal with you and on what terms.

### Advert types

| Advert | What you do | Terms and risks | Game |
| --- | --- | --- | --- |
| Wanted | Sell a legal good to a buyer in a hurry | Often above market price; players report double for robots at Sol and for slaves and computers at Facece | Elite II |
| Goods bought and sold | Trade illegal goods with a dealer | Some dealers are police traps; real dealers keep their names between visits, traps don't | Elite II |
| Package | Carry a small item that takes no cargo space | In First Encounters a fee of 2,000 credits or more marks a "hot" item that someone will try to stop | Both |
| Passengers | Carry people to a deadline of about a month | One person per cabin, 5 t each; late passengers leave without paying; those who say they're being chased rarely pay | Both |
| Assassination | Kill a named target as it leaves a named port at an exact time | Offered from about an Average rating; the kill brings a fine for piracy and murder | Both |
| Information | Say where a missing person was seen | Pays very little; lying costs reputation | Both |
| Charity appeal | Donate | 10,000 credits or more raises your reputation | Both |
| Crew | Hire crew for a larger ship | Wages leave your account each week, about 15–20 credits by player reports; firing crew hurts your reputation | Elite II |
| Military | Contact the local navy for missions | Federal or Imperial systems only | Both |

### How the board works

- The board refreshes at midnight Galactic Mean Time each day.
- Clients usually pay on arrival. A trusted pilot can ask for about 10% more and for half or all of the fee up front; the game decides from reputation plus a random roll.
- Some systems need a permit, which you get only by doing business there, such as delivering a package. Ross 128, van Maanen's Star and YZ Canis Minoris are permit systems.
- A passenger from a failed contract stays aboard and stops you selling the ship. Players eject in the escape capsule to clear them.
- Open question: no source gives typical pay for random adverts. Player reports mention a 150-credit military delivery and a 16,000-credit hit.
- First Encounters adds 16 scripted missions with fixed dates (see First Encounters: what changed).

### Assassinations

- The advert names the target, the port and the departure time to the second. Players arrive about a week early and wait by the station.
- In Elite II players follow a fleeing target with a hyperspace cloud analyser. In First Encounters a target that escapes into hyperspace fails the job, and so does one that crashes while dodging.
- The kill costs a fine, typically 10,000 credits for piracy and murder, which players pay remotely to keep a clean status.
- Collect each payment before the next hit, or the employer's rumours warn later targets.

### Military missions

There is no enlistment: at a Federal or Imperial port you contact the navy through the board, starting at the bottom rank. Missions pay credits and rank points; a late mission pays nothing and costs points.

| Mission | Rank points | Opens at | What you do |
| --- | --- | --- | --- |
| Delivery | 2 | Any rank | Carry documents or messages between bases; allow about a week per neighbouring system |
| Assassination | 12 (14 in the First Encounters FAQ) | Sergeant-Major or Squire | Kill a named enemy officer or official |
| Reconnaissance | 16, or 20 for a photo from under 10 km | Major or Lord | Photograph an enemy base from within about 80 km with the camera provided |
| Bombing | 18 | Colonel or Baron | Destroy a base with the nuclear missile provided; you need a free missile pylon |
| Classified (First Encounters) | Not documented | Needs a military drive | Destroy a defence satellite with the nuke provided, while a transmission jammer hides your ID |

- Points earned for one superpower count against you with the other: in full by one account, about half by the First Encounters FAQ.
- Some hubs are rich in missions. Eta Cassiopeia usually lists 8–14 Federal jobs to AC+79 3888, 8.46 light years away, and Imperial pilots loop Facece, Vequess and Sohoa.
- Imperial bases are the hardest to photograph: Imperial Couriers with 20 MW beam lasers guard them.

[Frontier: Elite II manual](https://archive.org/details/frontier-manual), [Sharoma: basics](https://sharoma.com/frontierverse/basics.htm), [Sharoma: missions](https://sharoma.com/frontierverse/missions.htm), [Sharoma: trading](https://sharoma.com/frontierverse/trading.htm), [Sharoma: police](https://sharoma.com/frontierverse/police.htm), [Jades FFE FAQ](https://www.jades.org/ffefaq2.htm), [Frontier Astro: military missions](https://www.frontierastro.co.uk/Military/military.html), [FRONTIER.TXT player guide](https://bearstrong.net/tekst97/data/spill/frontier/), [GEnie Atari ST log, 1994](https://sunsite3.icm.edu.pl/packages/umich-atari/Games/Gameutil/elite_2.txt), [Elite Wiki: FFE missions](https://wiki.alioth.net/index.php/First_Encounters/Missions)

## Factions, ranks and reputation

Elite II has two superpowers, the democratic Federation at Sol and the hereditary Empire at Achenar, with neutral independent systems between them; First Encounters adds a third bloc, the Alliance. Each superpower has a 13-step rank ladder whose thresholds are fourth powers, from 1 point to 20,736.

### Factions

| Faction | Capital | Character | For the player |
| --- | --- | --- | --- |
| Federation | Sol; navy centre at Eta Cassiopeia | Democratic and heavily militarised; its police are the Federal Security Service | Military missions and ranks; pays well |
| Empire | Achenar | The hereditary Duval dynasty, under Emperor Hengist Duval in 3200, commanding millions of slaves; its police are the Imperial Guard | Military missions and titles; pays more and builds the best ships, such as the Imperial Courier, sold only in Imperial space |
| Independent systems | None | Neutral, with mixed governments and their own police force | Civil work only |
| Alliance of Independent Systems (First Encounters) | Alioth | Founded in 3230 when Alioth rose against both powers; Gateway joined at once and 25 systems since; builds the Griffin Carrier and the Mantis Transport | No military missions; it starts the Thargoid storyline |

- A treaty lets the two powers trade freely in every system. Both keep Galactic Mean Time so that neither can miscalculate the time to start a war.
- The Social Structure screen shows each system's government, economy, allegiance and population.
- The Thargoids returned to human space between 3200 and 3250.
- Each bloc keeps its own criminal record on you (see Combat, crime and the police).

### Navy ranks

| Step | Federation | Empire | Points | Unlocks |
| --- | --- | --- | --- | --- |
| 0 | None | Outsider | 0 | Deliveries |
| 1 | Private | Serf | 1 |  |
| 2 | Corporal | Master | 16 |  |
| 3 | Sergeant | Sir | 81 |  |
| 4 | Sergeant-Major | Squire | 256 | Assassinations |
| 5 | Major | Lord | 625 | Reconnaissance |
| 6 | Colonel | Baron | 1,296 | Bombing |
| 7 | Lieutenant | Viscount | 2,401 |  |
| 8 | Lieutenant Commander | Count | 4,096 |  |
| 9 | Captain | Earl | 6,561 |  |
| 10 | Commodore | Marquis | 10,000 |  |
| 11 | Rear Admiral | Duke | 14,641 |  |
| 12 | Admiral | Prince | 20,736 |  |

- Step n needs n⁴ points, by fan sources; the manual gives only the names. Every mission pays an even number of points, so some guides list the next even number, such as 82 for Sergeant.
- Promotion is automatic. The Federal ladder switches from army to navy ranks after Colonel, so a Lieutenant outranks a Colonel.
- On deliveries alone, Admiral takes about 10,400 missions, around 14 game years.
- Medals mark six firsts with each power: the first important delivery, secret message, assassination, photograph, excellent photograph and bombing. Federal medals include the Certificate of Valour, the Starburst and the Frontier Medal; Imperial ones the Crimson Brassard, the Black Polygon and the Celestial Warrior.

### Combat rating

- The Elite Federation of Pilots awards ten ratings: Harmless, Mostly Harmless, Poor, Below Average, Average, Above Average, Competent, Dangerous, Deadly and Elite. Below Average is new since Elite.
- Fan sources give kill thresholds of 4, 8, 16, 32, 64 and 128 up to Competent, then 1,000, 3,000 and 6,000 for Dangerous, Deadly and Elite. The Elite Wiki gives different values, and the manual says the type of kill counts as well as the number.
- The rating gates work: about Average for civil assassinations, and Competent for First Encounters' Thargoid storyline.

### Reputation

- Three things are tracked apart: a hidden civil reputation, military points with each superpower, and a criminal record with each bloc.
- Reputation rises with on-time passengers and packages, some scripted missions and donations of 10,000 credits or more. It falls with lateness, failed jobs, firing crew, lying to missing-person adverts and turning in a wanted passenger.
- It shows only in how people treat you: passengers and crew refuse a bad name, while a good one earns about 10% more and payment up front. No source mentions a number on screen.
- In First Encounters the newspapers report your deeds, and killing Dentara Rast puts a price on your head with every authority.

[Frontier: Elite II manual](https://archive.org/details/frontier-manual), [Sharoma: background](https://sharoma.com/frontierverse/background.htm), [Sharoma: rank](https://www.sharoma.com/frontierverse/rank.htm), [Sharoma: combat rating](https://www.sharoma.com/frontierverse/combat_rating.htm), [Sharoma: medals](https://www.sharoma.com/frontierverse/medals.htm), [Sharoma: basics](https://sharoma.com/frontierverse/basics.htm), [Frontier Astro: military missions](https://www.frontierastro.co.uk/Military/military.html), [Frontier Astro: 3200 to 3250](https://www.frontierastro.co.uk/changes/politics.html), [Frontier Astro Gazetteer: Alioth](https://www.frontierastro.co.uk/Gazetteer/alioth.html), [Jades FFE FAQ](https://www.jades.org/ffefaq2.htm), [Elite Wiki: Federation](https://wiki.alioth.net/index.php/Federation), [Elite Wiki: The Empire](https://wiki.alioth.net/index.php/The_Empire), [FRONTIER.TXT player guide](https://bearstrong.net/tekst97/data/spill/frontier/)

## Combat, crime and the police

Combat is fought at a few kilometres with heat-limited lasers and stacked shields, and a bounty pays only if your radar mapper identified the ship first. The law keeps a separate record with each bloc: about ten offences carry fixed fines, and your status climbs from Clean to Fugitive as unpaid fines grow.

### Fighting

- You target by clicking a ship in any view. Front and rear views show a targeting tunnel and the range, and an arrow points to targets off screen.
- The scanner colours each contact by mass, from blue (1–15 t) through green, magenta, red, orange, yellow and grey to white (300 t and over).
- Heat, not an energy bank, limits lasers (see Weapons). Players dodge until an enemy's laser overheats, then press the attack so its shields can't recover.
- Players report that lasers hit harder against a ship's broad side, and that two accurate 5 MW pulse hits kill a police Viper.
- With a fuel scoop and cargo scoop conversion you can salvage jettisoned cargo, ore and explosion debris. Open question: no source says whether destroyed ships drop cargo.
- The escape capsule leaves crew, passengers and cargo behind, and the manual calls shooting capsules bad form. Without one, losing your ship costs the ship, crew and cargo, though not your cash.

### Pirates, police and bounty hunters

- Pirates read your hyperspace cloud and, in a lighter ship, reach your destination first. Outside the core they attack whatever you carry.
- Pirates spot engine flare, so coasting unpowered hides you. Riedquat reportedly holds 50 or more of them; the core worlds are safest and anarchies the most dangerous.
- Every police force flies the Viper. A rampage at Mars can bring out over 50 Vipers with 1 MW beam lasers, but flying at about 10 m keeps you fairly safe, and police often crash chasing you that low.
- Bounties on wanted criminals pay automatically when the kill is logged, but only if the radar mapper identified the ship first. Players report bounties of 500–950 credits.
- After a crime, paying the fine clears your status. You keep a record, but bounty hunters stop chasing you.

### Offences and fines

| Offence | Fine (credits) | Typical trigger |
| --- | --- | --- |
| Illegal mining | 200 | Mining where it's banned, such as a planet with a starport |
| Launching without clearance | 500 | Police launch and shoot at you |
| Trading in illegal goods | 500 | A police trap advert |
| Unlawful discharge of weapon | 600 | Firing near a starport or settlement |
| Attempted bribery | 2,000 | A failed bribe at the police station |
| Evading payment of fine | 2,000 |  |
| Smuggling illegal goods | 2,500 | A customs search after a deal |
| Unlawful dumping | 3,000 | Jettisoning cargo, especially radioactives |
| Permit violation | 4,000 | Entering a permit system without a permit |
| Piracy and murder | 10,000 | Killing an innocent ship, or an energy bomb near a station |
| Failure to obey traffic control |  | Approaching a station before clearance |

The fines come from an unsourced fan table for First Encounters; two of them, 600 and 10,000, match an independent Elite II guide.

### Legal status

- Status follows your unpaid fines: Clean (0), Offender (1 credit or more), Criminal (5,500), Outlaw (20,000) and Fugitive (100,000).
- The Federation, the Empire and the independent police keep separate records, so a Federal warrant means nothing in Imperial space. First Encounters adds a fourth record, for the Alliance.
- A system makes you pay its fines before you can dock. You can pay remotely in flight or at the police station.
- At the police station you can try a bribe instead. It usually works for a small fee but almost always fails in Imperial systems; claiming you didn't do it reportedly cuts a fine to 500 credits, a bug.
- Unpaid fines bring police attacks and refused docking.
- Elite II's copy protection was a police spot-check asking for a word from the manual. Three wrong answers meant arrest, an impounded ship and the end of the game; the CD32 version dropped it.

[Frontier: Elite II manual](https://archive.org/details/frontier-manual), [Sharoma: combat](https://www.sharoma.com/frontierverse/combat.htm), [Sharoma: police](https://sharoma.com/frontierverse/police.htm), [Sharoma: legal status](https://www.sharoma.com/frontierverse/legal_status.htm), [Sharoma: permits](https://www.sharoma.com/frontierverse/permits.htm), [Sharoma: piracy](https://www.sharoma.com/frontierverse/piracy.htm), [Sharoma: missions](https://www.sharoma.com/frontierverse/missions.htm), [Elite Wiki: wages and prices in FFE](https://wiki.alioth.net/index.php/Wages_and_Price_of_Goods_in_FFE), [Elite Wiki: FFE combat advice](https://wiki.alioth.net/index.php/FFE_Combat_Advice), [Jades FFE FAQ](https://www.jades.org/ffefaq2.htm), [Clayton review, 1993](https://www.math.uh.edu/~barrett/data/all/Frontier), [FRONTIER.TXT player guide](https://bearstrong.net/tekst97/data/spill/frontier/), [Wikipedia: Frontier: Elite II](https://en.wikipedia.org/wiki/Frontier:_Elite_II)

## First Encounters: what changed

First Encounters is a new PC-only engine on Elite II's design. It adds procedurally textured planets, five newspapers and 16 scripted missions that build to first contact with the Thargoids. GameTek forced it out at Easter 1995 close to unplayable, and patches up to 1.06 fixed most of it.

### The storyline

- Elite II has no plot, no scripted missions and no Thargoids. First Encounters adds 16 hand-coded missions between January 3250 and the end of 3252: twelve one-off jobs, then a four-step main plot.
- Each opens in a date window, is often foreshadowed in the newspapers, and appears on the bulletin board under a fixed headline such as "TURNER'S REQUIEM". Some need a combat rating, passenger cabins or an allegiance, and the papers report the outcome.
- Braben said the game has about 87 basic mission types, where Elite II had about 32 variations of package delivery alone, and that a first playthrough would see half the content or less.

| # | Mission | When | Task | Reward |
| --- | --- | --- | --- | --- |
| 1 | Wiccan Ware Race | Jan–Feb 3250 | Race a recording from Gateway to Alioth against thousands of pilots | 1,010 credits to the fastest, plus reputation |
| 2 | Soholia Medicine Relief | Jan–Feb 3250 | Deliver medicine to plague-hit Soholia | 2,000 credits a tonne, plus reputation |
| 3 | Duval Artefact | Early 3250 | Carry an artwork from Achenar to Beta Hydri; it turns out to be stolen | 6,000 credits; may anger the Empire |
| 4 | Assassinate Dentara Rast | Aug–Dec 3250 | Kill a political figure before she jumps | 50,000 credits; then every authority hunts you and the press turns on you |
| 5 | Assassinate Dr Joreb Innitu | Feb 3251 | A navy hit on a scientist at Beta Hydri | 1,500 credits and a medal |
| 6 | The Two Hitchhikers | Feb–Jun 3251 | Carry two suspected Federal spies on a two-leg route with fixed dates | 6,000 credits; miss a date and they blow up your ship |
| 7 | Assassinate the Assassin | Mar–Apr 3251 | Kill Rast's assassin, whom the papers claim is dead | 50,000 credits |
| 8 | The Visitor to Thompson's Planet | Jun 3251 | Carry a passenger to Ackwada | 6,000 credits |
| 9 | Destroy Rockforth Legal Academy | Jun–Jul 3251 | Missile a heavily defended academy on 16 July | 10,000 credits |
| 10 | Deliver Junior's Friend | Jun 3251 | Carry a dolphin from Liaququ to Fawaol | 2,000 credits |
| 11 | Transport the 5 Furies | Mar 3252 | Carry a statue to Epsilon Eridani; the board's dates are wrong, so leave at once | Not recorded |
| 12 | Rescue Stranded Hitchhiker | Mar–Aug 3252 | Federal only: fetch Jan Thikka from Miargre | 2,000 credits and a Federal promotion |
| 13 | Argent's Quest 1: Turner's Requiem | Oct–Dec 3252 | Needs Competent. Donate 10,000 credits at Alioth and swap your ship; at Pleione, nuke a defence satellite, photograph Turner's wreck and recover its flight recorder | Twice your credits, and the Turner-class Argent's Quest |
| 14 | Red Square Flowers | Dec 3252 | Only if you lost the recorder: smuggle an Alliance agent past INRA | No pay; Alliance goodwill |
| 15 | Argent's Quest 2 | Dec 3252 | At Polaris, destroy a satellite and dock with a Thargoid shuttle, which takes you to Miacke | First contact with the Thargoids |
| 16 | The Mycoid Mission | After 15 | For the Thargoids, destroy INRA's vaccine store at Hotice with a plasma accelerator and collect the vaccine with a mining machine | A Thargoid warship and alien artefacts |

- The plot follows Mic Turner, an explorer who co-founded the Alliance with Meredith Argent and was killed by INRA, a joint Federal and Imperial navy arm built to fight the Thargoids.
- In the fan wiki's account, INRA beat the Thargoids with a Mycoid virus that crippled their organic hyperdrives, then stayed active in secret to hide it. Argent's Quest reaches the Thargoids and opens peaceful contact.
- Players report that siding with the Thargoids at the requiem earns a Thargoid fighter instead. Before release, Braben said the ending could vary.

### Newspapers

| Paper | Voice |
| --- | --- |
| Frontier News | The Alliance's paper; fairly even-handed about both superpowers |
| Federal Times | The Federation's mouthpiece: formal, until it denounces the Empire |
| Imperial Herald | Florid Imperial propaganda |
| Universal Scientist | Neutral science news |
| Random Intergalactic Gossip | A tabloid with "Desperately seeking" personal ads |

- You buy or subscribe to the papers, and they update every 28 days. Their articles are hand-written, not generated, and some are deliberately false.
- They foreshadow the scripted missions and print your name once you finish one. They also contradict each other: when Rast's assassin dies, the Empire, the Federation and Interpol each claim the kill.
- One story links news to the market: the Soholia plague report comes with high medicine prices and a relief job.

### Engine, graphics and interface

- About ten people wrote it from scratch for the PC in a little over a year, in over a million lines of code.
- Gouraud shading and wider texture mapping; procedurally textured planet surfaces with vegetation, snow, mountains and cliffs, which Guinness credits as a first; elliptical planets, mist and hazy sunrises. It runs at 320 × 200.
- The scanner stays on screen (Elite II swapped it for the weapons display in combat). Separate combat and flight targets let the autopilot work mid-fight.
- Closing speeds drop when combat starts, a deliberate fudge: realistic speeds would be about 10,000 km/s.
- New kit includes a missile camera (a programmer's tool in Elite II), an auto targetter and a navigation computer that sets a destination for you. Its 16 new ships are listed under Ships.
- On CD, filmed actors replace the bulletin board's identikit portraits. 324 clips were shot, and starport staff comment on the market, the board, the shipyard and your legal status, warmer or colder by your allegiance.
- Removed: the preference screens, the floppy version's portraits, and any Amiga or ST version.

### The launch

- Version 1.00 was close to unplayable (patches and the lawsuit are under Versions, patches and fan remakes).
- Patch 1.06 fixed the timing of the Wiccan Ware race, the 5 Furies and the Thargoid steps, and disabled the CD videos, which clashed with some video cards. Missing medals and "No Commander File" errors remained.
- Fans rank it among the buggiest games ever. Your own missiles and some turrets can hit your ship, and a scripted passenger can leave you with −1 passengers and a ship you can't sell.

[PC Gamer 18, 1995: Braben interview](http://www.sslmit.unibo.it/zat/files/ffe/PCGamer_1995_issue18_FFE.htm), [Elite Wiki: FFE missions](https://wiki.alioth.net/index.php/First_Encounters/Missions), [Elite Wiki: FFE journals](https://wiki.alioth.net/index.php/First_Encounters/Journals), [Elite Wiki: FFE characters](https://wiki.alioth.net/index.php/First_Encounters/Characters), [Elite Wiki: INRA](https://wiki.alioth.net/index.php/INRA), [Elite Wiki: Turner Class](https://wiki.alioth.net/index.php/Turner_Class), [Jades FFE FAQ](https://www.jades.org/ffefaq2.htm), [Elite Wiki: alt.fan.elite FAQ part 3](https://wiki.alioth.net/index.php/AFE_FAQ3), [Elite Wiki: alt.fan.elite FAQ part 5](https://wiki.alioth.net/index.php/AFE_FAQ5), [Frontier Astro: FFE (UK)](https://www.frontierastro.co.uk/Frontier/FFE_UK/intro.html), [Frontier Astro: FFE at 25](https://frontierastro.co.uk/FFE25.html), [Wikipedia: Frontier: First Encounters](https://en.wikipedia.org/wiki/Frontier:_First_Encounters)

## Screens, controls and presentation

Both games share one console: a 3D view above a panel with the scanner in the middle, four fixed mode icons on the left (F1–F4) and four on the right whose meaning changes with the mode. Both are mouse-first, and Elite II's soundtrack is classical, with the Blue Danube at every docking.

### Elite II function keys

| Key | Opens |
| --- | --- |
| F1 | Views: front, rear and external |
| F2 | Maps: the galactic map, then the system map; press again for the system's bodies |
| F3 | Seven status pages: ship equipment, commander profile, crew roster, cargo, passengers and small items, contracts, and mining installations |
| F4 | Communications: docked, the stock market, bulletin board, launch request and shipyard; in flight, clearance and paying fines |
| F5 | Scanner or weapons display |
| F6 | System information |
| F7 | Engine mode: off, set speed or autopilot |
| F8 | Hyperspace |
| F9 | Undercarriage |
| F10 | On-screen labels, or target selection, depending on the mode |

- **Flight:** A and Z pitch, < and > roll, Enter thrusts forward and right Shift backward. Or hold the right mouse button and move the mouse to steer; the left button fires.
- **Systems:** Space fires the lasers, M a missile, E the ECM, B the energy bomb and X the escape capsule. R runs the radar mapper, ? the cloud analyser, D the camera or mining machine, and H jumps; Alt+F8 forces a misjump.
- **Time:** Shift+F1 to F5 set the Stardreamer, and Esc twice pauses.

### First Encounters controls

- The same four-panel console, plus a combat console on F5 and two crosshairs, one for heading and one for movement.
- New keys: Tab cycles the engine mode, T sets the combat or flight target, N opens the navigation computer, R the remote orbital map, L toggles labels and U the undercarriage. Alt or Shift with F2–F5 sets time acceleration.
- Some keys changed meaning: R was Elite II's radar mapper.
- GameTek called it a game written for mice, and the US box lists a mouse as required. Joysticks misbehaved: players unplug them before loading, or the laser may fire non-stop in dock.

### Music and sound

- David Lowe scored both games. Braben asked for all-classical music plus an original title theme, and Lowe wrote a main theme and a second theme.
- The Blue Danube plays at every station docking, the nod to 2001: A Space Odyssey that began in Elite. Other pieces include Wagner's Ride of the Valkyries, Mussorgsky's The Great Gate of Kiev and Grieg's In the Hall of the Mountain King.
- First Encounters stores its music as MIDI files on the CD, with a menu to switch individual tunes on or off. Its new tunes are credited to the "Quality Quartet".
- Lowe later re-recorded the Frontier themes with an orchestra at Abbey Road.
- Open question: no source covers the sound effects, or when each piece plays apart from docking.

### In the box

- **Elite II:** a 106-page manual; a 40-page Gazetteer with galactic history from 1950 to the 2380s and entries for 42 systems; Stories of Life on the Frontier, 82 pages of eight stories, mostly by David Massey; a quick-start card; and, in North America, a 58 × 73 cm star-map poster. The game itself is about 600 KB.
- Its copy protection was the police spot-check asking for a word from the manual, which fans called the "Mad Protection Scheme".
- **First Encounters:** a manual and Further Stories of Life on the Frontier, nine stories by Manda Scott, Julian Flood, Moira Sheehan and others, on three floppies or a CD. The US release was titled just "First Encounters". No copy protection is documented.

[Sharoma: controls](https://sharoma.com/frontierverse/controls.htm), [Sharoma: basics](https://sharoma.com/frontierverse/basics.htm), [Frontier: Elite II manual](https://archive.org/details/frontier-manual), [Jades FFE FAQ](https://www.jades.org/ffefaq2.htm), [PC Gamer 18, 1995: Braben interview](http://www.sslmit.unibo.it/zat/files/ffe/PCGamer_1995_issue18_FFE.htm), [VGM Online: David Lowe interview](https://vgmonline.net/?p=10929), [Planetmic: what was in the box](https://planetmic.com/orbit/feinbox.htm), [Frontier Astro: fiction](https://www.frontierastro.co.uk/Fiction/frontierfiction.html), [Frontier Astro: FFE (US)](https://www.frontierastro.co.uk/Frontier/FFE_US/intro.html), [elisoftware: FFE US CD release](<https://elisoftware.org/wiki/Frontier:_First_Encounters_(PC,_CD-ROM)_Gametek_-_1995_USA,_Canada_Release>), [Elite Wiki: alt.fan.elite FAQ part 3](https://wiki.alioth.net/index.php/AFE_FAQ3), [Wikipedia: Frontier: Elite II](https://en.wikipedia.org/wiki/Frontier:_Elite_II)

## Versions, patches and fan remakes

Elite II's Amiga, ST and CD32 versions run Braben's 68000 code; the PC version is Chris Sawyer's port and the only one with texture mapping. Every First Encounters fan port descends from John Jordan's reverse-engineered JJFFE, and Pioneer is the open-source game that does for Frontier what Oolite did for Elite.

### Elite II versions

| Version | Year | Media | Differences |
| --- | --- | --- | --- |
| Amiga | October 1993 | One 880 KB floppy, plus a save disk | Braben's 68000 code; no texture mapping |
| Atari ST | October 1993 (some listings say 1994) | Two floppies, the second for saves; installs to hard disk | Low resolution and fewer music pieces; needs 1 MB; mouse and joystick can't be used together |
| PC (DOS) | 1993 | One 720 KB floppy; CD-ROM in the UK | Sawyer's 80286 port, with texture mapping |
| PC, US release | 1994 | Floppy | Debugged after complaints; French, German and Spanish editions |
| Amiga CD32 | 1994 | CD | Debugged; adds the navigation computer; saves only in space, to the console's 1 KB of memory |
| Budget and compilations | 1995–1997 | PC CD, Amiga floppy | GameTek's Advantage Point range (without the Gazetteer, book and poster); with Lemmings and Civilization in Empire's Award Winners Platinum Edition; the debugged build on an Award Winner's CD |
| Elite Club shareware | Later | Download | English builds for PC, Amiga and ST, now mirrored by Frontier Astro |

- The whole game, galaxy included, fits on one floppy disk.
- Ships and objects are stored as Frontier's own 16-bit bytecode, which describes shapes, levels of detail and animations.
- The game refits its palette to the colours on screen every frame, reportedly a first at the time.
- Reportedly, systems 655.36 to 670.36 light years away count as within jump range, which suggests distances wrap at 65,536 hundredths of a light year.

### First Encounters patches and the lawsuit

- GameTek forced the game out unfinished at Easter 1995, and patch discs were mailed to players.
- Known builds are English 1.0 (the Euro Power Pack) and German 1.06. The final shareware release, 1.06, is mirrored by Frontier Astro.
- Open question: no list of official patch numbers, dates and fixes survives online.
- Braben's Frontier Developments sued GameTek, and the case settled out of court in 1999 in Frontier's favour. GameTek had filed for Chapter 11 in 1997 and closed in July 1998.
- In 2000 Frontier promised to open-source First Encounters under a GPL-like licence. It never did.

### Fan remakes

| Project | Based on | Author | What it is | Status |
| --- | --- | --- | --- | --- |
| Pioneer | A new game modelled on Elite II | Tom Morton, then up to 50 contributors | C++, OpenGL and Lua: Newtonian flight and orbits, atmospheres with drag and heat, three starts, mods | Active: release 20260907 on 7 September 2026; GPLv3 code, CC BY-SA 3.0 assets |
| FFED3D-AJ | FFED3D | Andy Jones | Fixes almost all of First Encounters' old bugs; regarded as the definitive version | Frozen since his death in July 2022 |
| FFED3D | JJFFE | DreamZzz, then Ittiz and Andy Jones | Direct3D, more detailed planets, replaceable ship, planet and building models | 2006 |
| GLFFE | JJFFE | Kolijoco | OpenGL 2.0 renderer, new console graphics, high resolution | 2006 |
| JJFFE | First Encounters | John Jordan | The reverse-engineered game, recompiled for Windows, Linux, Mac and OS/2 at 320 × 200 | 2005–2009; the base for later ports |
| GLFrontier | Elite II (Atari ST code) | Tom Morton | The 68000 code translated to C, with OpenGL graphics | About 2005; Windows and Linux |
| frontvm | Elite II (Atari ST code) | Reportedly Tom Morton | The original 68000 code on an emulated CPU | Last build 17 May 2004; moved to SourceForge in 2019 |
| fe2-intro | Elite II's intro | watsonmw | Reimplements the renderer and music player in C, reading models from the original program | On GitHub |

- Smaller patches exist too: Anisotropic's mod, Nic's Mod and Anton Lindström's high-resolution hack, all built on JJFFE.
- None of the reverse-engineered ports has an open licence, because the code is still Frontier's. Oolite can borrow their ideas, not their code.
- Pioneer's September 2026 release added a smuggler's hold hidden in passenger cabins, shield heating in fast atmospheric flight, and binaural audio.

[Sharoma: versions](https://sharoma.com/frontierverse/versions.htm), [Atarimania: Elite II](https://www.atarimania.com/game-atari-st-frontier-elite-ii_9211.html), [Frontier Astro: Elite II](https://frontierastro.co.uk/Frontier/FE2/intro.html), [Frontier Astro: files](http://www.frontierastro.co.uk/Files/files.html), [Frontier Astro: high-resolution FFE](http://www.frontierastro.co.uk/Hires/hiresffe.html), [fe2-intro](https://github.com/watsonmw/fe2-intro), [virtuallyfun: frontvm](https://virtuallyfun.com/2019/04/01/wasting-some-cycles-on-frontvm/), [jmtd: Frontier ports](https://jmtd.net/games/frontier/), [Elite Wiki: FFE](https://wiki.alioth.net/index.php/FFE), [Elite Wiki: GameTek](https://wiki.alioth.net/index.php/Gametek), [FFE build offsets](https://schmadalla.dyndns.org/Museum/ffe-hack.html), [Pioneer on GitHub](https://github.com/pioneerspacesim/pioneer), [Pioneer release 20260907](https://github.com/pioneerspacesim/pioneer/releases/tag/20260907), [Wikipedia: Pioneer](<https://en.wikipedia.org/wiki/Pioneer_(video_game)>), [Wikipedia: Frontier: First Encounters](https://en.wikipedia.org/wiki/Frontier:_First_Encounters)

## Ideas for Oolite

Frontier's best fits for Oolite are its career and law systems: navy ranks, a richer bulletin board, a legal record per bloc and calendar-driven story missions can all be built on screens and scripts Oolite already has. Newtonian flight and planetary landing are the big engine changes and the hardest to fit.

| Idea | In Frontier | Oolite today | How it could fit |
| --- | --- | --- | --- |
| Navy careers | Two 13-step rank ladders with thresholds at n⁴ points; missions pay points; rank opens assassination, reconnaissance and bombing work; medals for firsts | A combat rating, and one authority, GalCop | A mission line on the F4 interfaces screen, with points in mission variables and the rank on the status screen |
| More bulletin-board work | Timed assassinations, reconnaissance photos, bombing runs, missing-person tips and charity appeals | Cargo, parcel and passenger contracts on the F4 interfaces screen, each with its own reputation | New contract types beside those three; a script can launch a target from a station at a set time |
| Asking for better terms | A trusted pilot asks for about 10% more and payment up front, granted on reputation plus a roll; a high fee warns of danger | Passenger contracts already pay part up front, scaled by reputation | A negotiate option on the contract screens, with a chance of losing the job |
| A record per bloc, with named offences | Separate Federal, Imperial and independent records; ten offences with fixed fines; status bands from Clean to Fugitive; fines paid remotely or bribed away | One legal status from bounty points; fines for docking as an offender or without clearance; stations already carry an allegiance (galcop, neutral, chaotic, pirate) | A record per allegiance or region, and an offence log with fixed fines payable from the F4 screen |
| Black-market dealers | Illegal goods trade only through bulletin-board dealers, some of them police stings | Illegal goods sell on the open market, and carrying them out raises your bounty | A dealer interface at anarchies and rock hermits, with a sting chance per dealer |
| A calendar story with newspapers | 16 missions in fixed date windows, foreshadowed and reported by five biased papers | Five core missions, triggered by kill count, galaxy and chance; no news | A news screen fed by mission scripts, and missions keyed to the game clock |
| Difficulty starts | Ross 154 in an Eagle, Mars, or Lave in a Cobra Mk III owing 70,000 credits in fines | Standard, easy, tutorial and strict scenarios | A veteran scenario: a better ship with a criminal record |
| Equipment mass | Every item's mass comes out of one capacity shared with fuel and cargo | Only the passenger berth (5 t) uses hold space | A mass budget per hull on the outfitting screen, so guns, kit and cargo trade off |
| Hyperspace pursuit | Clouds show destination, arrival time and mass; a longer-range drive arrives first and waits | The wormhole scanner reads a wormhole's destination, and you can fly into an NPC's wormhole | Missions where targets flee by jumping, and pirates who follow you through |
| Jump time by drive | A full-range jump takes a week, so a bigger drive is a faster one | A jump takes the distance squared, in hours | Scale jump time by drive class or ship mass |
| Player time acceleration | The Stardreamer, up to 10,000×, dropping to normal when you're attacked, hailed or arrive | Time acceleration from 0.0625× to 16× in debug builds only; in-system jumps at 32× speed | A player control with the same automatic drop-outs |
| Crew for big ships | Large hulls need crew paid weekly; recruiting takes weeks, and firing hurts your reputation | No crew | An optional rule: weekly wages and a crew roster for the biggest hulls |
| Bounties need identification | No bounty unless the radar mapper identified the ship before the kill | Bounties pay on every offender you kill | Pay only for targets scanned or locked before the kill |
| Fuller systems | Most stars have full systems, up to 43 bodies; 117 hand-placed systems sit in a procedural galaxy | One main planet and a sun; scripts can add planets and moons, and planetinfo.plist overrides systems | More planets and moons by default, and a hand-placed cluster of named systems |
| Newtonian flight and landing | Full Newtonian flight, and landing anywhere on a planet | Elite-style flight; no landing | The largest change: an optional assist-off mode first, landing much later |

- Oolite is ahead in one place: its advanced navigational array plots multi-jump routes, which neither Frontier game had.
- The Oolite today column draws only on Oolite's core files (Resources and src in oolite-dev), not on expansions.

## Sources

Most figures come from fan transcriptions and fan wikis: neither manual could be read in full online, and several key sites blocked automated access. Each section ends with the pages it used; these are the main ones.

- **Manuals and game data:** [Frontier: Elite II manual (archive.org scan)](https://archive.org/details/frontier-manual), [Frontier: Elite II manual (fan transcription)](https://sharoma.com/frontierverse/files/docs/english_manual.pdf), [FFE game data, reverse-engineered](https://schmadalla.dyndns.org/Museum/ffe-hack.html)
- **Contemporary press and interviews:** [PC Gamer 18, 1995: Braben interview](http://www.sslmit.unibo.it/zat/files/ffe/PCGamer_1995_issue18_FFE.htm), [D. A. Clayton's Amiga review, 1993](https://ftp.fau.de/mirrors/aminet/docs/rview/Frontier.txt), [GEnie Atari ST log, 1993–94](https://sunsite3.icm.edu.pl/packages/umich-atari/Games/Gameutil/elite_2.txt), [VGM Online: David Lowe interview](https://vgmonline.net/?p=10929), [MCV: Elite IP profile](https://mcvuk.com/development-news/ip-profile-elite/)
- **Fan sites and FAQs:** [Sharoma Frontierverse](https://sharoma.com/frontierverse/), [Frontier Astro](https://frontierastro.co.uk/), [Jades FFE FAQ v2.9c](https://www.jades.org/ffefaq2.htm), [alt.fan.elite FAQ](https://rk.nvg.ntnu.no/bbc/doc/games/EliteFAQ.htm), [Elite Wiki: Frontier](https://wiki.alioth.net/index.php/Frontier), [Elite Wiki: FFE missions](https://wiki.alioth.net/index.php/First_Encounters/Missions), [sslmit: stellar cartography](https://www.sslmit.unibo.it/zat/images/cartography/default.htm), [Planetmic: what was in the box](https://planetmic.com/orbit/feinbox.htm)
- **Reference:** [Wikipedia: Frontier: Elite II](https://en.wikipedia.org/wiki/Frontier:_Elite_II), [Wikipedia: Frontier: First Encounters](https://en.wikipedia.org/wiki/Frontier:_First_Encounters), [Wikipedia: Pioneer](<https://en.wikipedia.org/wiki/Pioneer_(video_game)>), [Pioneer on GitHub](https://github.com/pioneerspacesim/pioneer)
- **Blocked:** the web archive (which holds JJFFE Central and Jongware's galaxy notes), MobyGames, Hall of Light, GameFAQs, StrategyWiki, the Elite fan wikis and Frontier's forums. Facts found only there are missing, and gaps are marked as open questions in the sections.
- **Oolite:** the Oolite today column in Ideas for Oolite comes from Oolite's core files in this repository, not from expansions.
