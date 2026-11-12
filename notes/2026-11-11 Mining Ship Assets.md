# Mining ship and cockpit assets

| | |
|---|---|
| **Type** | Research notes (asset sourcing) |
| **Goes with** | [Mining Summary](Mining%20Summary.md), [Mining and Manufacturing — Design Sketch](Mining%20and%20Manufacturing%20—%20Design%20Sketch.md) |
| **Goal** | More mining ships, industrial in style and reminiscent of EVE's mining barges and exhumers, plus ideas for cockpits |

## Summary

Buying a model is easy. Putting it in the repo is the hard part. The fork's artwork is dual-licensed
**GPLv2-or-later or CC BY-NC-SA 3.0**, user's choice ([LICENSE.md](../oolite-dev/LICENSE.md)), so a
new model has to be shareable under both. Royalty-free marketplace licenses (CGTrader, Sketchfab
Standard, Fab, RenderHub) allow shipping a model inside a game. They don't allow publishing the
source files in an open repo.

There are three ways to get usable art:

1. **CC0** packs. Free and clean, but cartoony low-poly; best as kitbash parts.
2. **Commission** an artist with a written license grant. The only realistic way to get the EVE
   industrial look. Roughly $200–600 per ship from a mid-level freelancer.
3. **Ask an OXP author** for permission. Most OXPs are CC BY-NC-SA 4.0, which can't go into core
   without the author's OK.

Don't use EVE fan recreations (Hulk, Mackinaw and so on). Those are CCP's designs. Use "in the
style of", never "a copy of".

## Already in the core game

[shipdata.plist](../oolite-dev/Resources/Config/shipdata.plist) has a `miner` role filled by three
mining-laser reskins of stock hulls:

| Ship | Template |
|---|---|
| Cobra Mk I miner | `oolite_template_cobramk1-miner` |
| Mining Transporter | `oolite_template_transporter-miner` |
| Worm miner | `oolite_template_worm-miner` |

A new ship given `roles = "miner"` spawns alongside these with little config work.

Models load as `.dat`. The usual route is OBJ → DAT with Obj2DatTex. Every candidate below ships OBJ.
A few thousand triangles is plenty for Oolite.

## Licensing rules for incoming art

| Incoming license | Usable in core? | Why |
|---|---|---|
| CC0 / public domain | Yes | No conditions |
| CC BY 4.0 | Yes, with credit | FSF counts it GPLv3-compatible; fits the CC side |
| CC BY 3.0 | Probably, with credit | Fine on the CC side; GPLv2 compatibility less clear |
| CC BY-SA | No | Can only be shared under BY-SA |
| CC BY-NC / BY-NC-SA 4.0 | Not without permission | NC isn't GPL-compatible; 4.0 can't be relicensed to 3.0 |
| GPL only | No | Breaks the CC side |
| Marketplace royalty-free | No | No redistribution of source files |
| AI-generated (Meshy, Tripo…) | Avoid | Copyright status unclear, restrictive terms |

For everything added, record the author, source URL and license next to the model in the commit.
For anything bought or commissioned, the written permission is what counts. (This is not legal
advice.)

## Marketplace models (paid; reference or permission request only)

Usable in core only if the artist grants the licenses above in writing, which many will do for a fee.

**Closest to an exhumer (large industrial hulls)**

- [Mining Command Control Vessel MCCV-2](https://cgtrader.com/3d-models/space/spaceship/mining-command-control-vessel): command, drilling and processing ship, ~11.8k vertices
- [Spaceship Mining Operation](https://www.cgtrader.com/3d-models/space/spaceship/mining-operation)
- [Spaceship Progenitor Resource Ships](https://cgtrader.com/3d-models/space/spaceship/progenitor-resource-ships)

**Low-poly, game-ready**

- Scifi Mining Vessel C500M: [CGTrader](https://www.cgtrader.com/3d-models/space/spaceship/scifi-mining-vessel-c500m) / [Sketchfab, $25](https://www.sketchfab.com/3d-models/scifi-mining-vessel-c500m-f3ce76687b484571b36cfdcd669af21f). ~1.4k triangles, FBX/OBJ, 6 texture sets. The best fit for Oolite's budget
- [Spaceship Mining Ships ($30)](https://cgtrader.com/3d-models/space/spaceship/scifi-mining-ships): mining ship (~8k tris) and harvester (~3k), FBX/OBJ, 4096 px textures
- [Spaceship Mining Ship TTB01 ($27.50)](https://cgtrader.com/3d-models/space/spaceship/scifi-mining-ship-ttb01): mining ship and mining drone, ~10.8k polygons. Appears to be by msGameDevelopment ([mirror](https://art.cleberg.net/post/msgamedevelopment/Scifi-Mining-Ship-TTB01-766794127)), the same creator as the cockpit below

**A different kind of miner: one that eats asteroids**

- [Spaceship Loader with Asteroid, rigged for Cinema 4D](https://www.cgtrader.com/3d-models/space/spaceship/spaceship-loader-with-asteroid-rigged-for-cinema-4d) ($149): hydraulic arms, conveyors and grippers that take a whole asteroid in. Also as a [Maya version](https://www.cgtrader.com/3d-models/space/spaceship/spaceship-loader-with-asteroid-rigged-for-maya) ([TurboSquid](https://www.turbosquid.com/it/3d-models/3d-spaceship-loader-with-asteroid-rigged-for-maya-2391468)). The same artist has a [Sci-Fi Space Loader](https://www.cgtrader.com/3d-models/space/spaceship/sci-fi-space-loader-rigged-for-cinema-4d) without the asteroid and a [Sci-Fi Repair Spaceship](https://www.cgtrader.com/3d-models/space/spaceship/sci-fi-repair-spaceship-rigged-for-cinema-4d)
- It's a render asset, not a game asset: **~391k polygons**, about 100× Oolite's budget, so it would need a low-poly rebuild with the detail baked into a normal map. Oolite has no skeletal animation, so the rig wouldn't carry over. Arms and grippers could become rotating subentities, the way turrets and radar dishes work
- Best use: a design reference for a commission, or ask the artist for a game-resolution version
- Gameplay angle: today mining means lasering a rock into splinters and scooping them (the breakup chain in the [design sketch](Mining%20and%20Manufacturing%20—%20Design%20Sketch.md)). An eater would take a whole small asteroid into the hold and process it over time, which would make it a distinct ship class rather than a reskin

**Freighters (msGameDevelopment)**

CGTrader blocks page fetches, so prices and triangle counts are still to be read off the listings.

- [Spaceship CFS24 Heavy Freighter](https://www.cgtrader.com/3d-models/space/spaceship/spaceship-cfs24-heavy-freighter): low-poly, game-ready, December 2022. Also on the Unity Asset Store ([mirror](https://art.cleberg.net/post/msgamedevelopment/CFS24-Heavy-Freighter-940109705))
- [Spaceship CFS113 Superfreighter](https://www.cgtrader.com/3d-models/space/spaceship/spaceship-cfs113-superfreighter)
- Same series: [CFS56 Heavy Freighter](https://www.cgtrader.com/3d-models/space/spaceship/spaceship-cfs56-heavy-freighter), [CFS3 Light Freighter](https://www.cgtrader.com/3d-models/space/spaceship/spaceship-cfs3-light-freighter)
- Bundles: [Civilian Freighter Spaceship Collection (CGTrader)](https://www.cgtrader.com/3d-model-collections/civilian-freighter-spaceship-collection) / [Unity Asset Store](https://marketplace.unity.com/packages/3d/vehicles/space/civilian-freighter-spaceship-collection-235634); a [pack](https://www.cgtrader.com/gallery/project/spaceship-spacecraft) listing CFS15, CFS24, CFS56, CFS113, CH12, 20 modular cargo containers and a loader drone. All FBX/OBJ, PBR, royalty-free
- msGameDevelopment now has a mining ship (TTB01), a freighter line, a cockpit and a modular hangar. One artist with a consistent style is the natural person to ask for a GPLv2+/CC BY-NC-SA 3.0 license on a set, or to commission new mining hulls from

**Whole kits**

- [POLYGON Sci-Fi Space (Synty)](https://www.cgtrader.com/3d-models/space/other/polygon-sci-fi-space), also on the [Synty Store](https://syntystore.com/products/polygon-sci-fi-space-pack) and [Unity Asset Store](https://marketplace.unity.com/packages/3d/environments/sci-fi/polygon-sci-fi-space-low-poly-3d-art-by-synty-138857) ($149.99): about 660 assets. A modular ship kit with dozens of ready-made ships (fighters, bombers, cruisers, carriers, transports, escape pods), stations and interiors, asteroids, drones, warp gates, a first-person cockpit and 24 colour variants. Flat-shaded low poly, which suits Oolite's look and polygon budget
- Licence: Synty's [one-time purchase licence](https://syntystore.com/pages/one-time-purchase-licence) forbids sharing the source files outside your team, so it can't go in the repo or in a public OXP. Synty says distribution needs a custom licence ([licence overview](https://syntystore.com/pages/licences-overview)). Usable for private prototyping and as a style reference. Sites offering it as a "free download" are pirated copies

**Stations and other pieces**

- [Space Factory and Cargo Spaceship (RenderHub)](https://www.renderhub.com/max/space-factory-and-cargo-spaceship): mining plant and freighter, ~9.2k polygons
- [FelipeVera's Sketchfab page](https://sketchfab.com/FelipeVera/models): has an Asteroid Mining Station; price and license not checked
- [Sci-Fi Heavy Cargo Overland Transport ($4.99)](https://www.cgtrader.com/3d-models/space/spaceship/sci-fi-heavy-cargo-overland-transport-3d-model): listing says AI-assisted; avoid

## Free models that can go in the repo

**CC0**

- [Quaternius – LowPoly Spaceships](https://quaternius.itch.io/lowpoly-spaceships): 10 ships, OBJ/FBX/glTF/Blend ([OpenGameArt copy](https://opengameart.org/content/lowpoly-spaceships-pack) has fewer textures)
- [Kenney – Space Kit](https://kenney-assets.itch.io/space-kit) and [remade version](https://opengameart.org/content/space-kit-remade): 150+ pieces
- [Kenney – Space Station Kit](https://kenney-assets.itch.io/space-station-kit): platforms and refinery parts
- [Quaternius Ultimate Space Kit on Sketchfab](https://sketchfab.com/3d-models/ultimate-space-kit-84c108ff2bcf4d4cbf2adff74a942822): the page says both CC0 and "CC Attribution"; check quaternius.com
- Sketchfab search: "mining ship" / "industrial ship", filtered on *Downloadable* and *CC0*

**CC BY**

- [Low poly space freighter](https://opengameart.org/content/low-poly-space-freighter) (CC-BY 3.0)
- [Spaceship 10](https://opengameart.org/content/spaceship-10) (CC-BY 3.0, credit Creomoto)
- [Spaceship 3D model1](https://opengameart.org/content/spaceship-3d-model1-blend) (pick CC-BY of its CC-BY / BY-SA options)

## Commissioning

No published prices turned up; these are estimates from typical freelance rates. Get two or three
quotes.

| Who | Per ship (few thousand tris, textured) | Notes |
|---|---|---|
| Fiverr / beginners | ~$50–150 | Uneven; check for hard-surface work. [Example gig](https://fiverr.com/exiondesigns/create-an-awesome-3d-spaceship-model-for-you) |
| Mid-level freelancer (ArtStation, Polycount, r/gameDevClassifieds) | ~$200–600 | Likely sweet spot |
| Experienced game artist | ~$500–1,500+ | Often $150–400 a day; 1–4 days per ship |
| Concept art first | +$100–400 | Gives an original design, not an EVE lookalike |

A vendor FAQ gives a similar [$50–500](https://www.hitem3d.ai/ai-faq/what-is-the-cost-of-a-low-poly-3d-model-for-game-artists)
range. A set of three in one style (small mining frigate, barge, exhumer-class hull) sharing one
texture sheet is roughly **$800–2,500** at mid-tier rates.

**Brief checklist**

- License clause: "Released under GPLv2-or-later and CC BY-NC-SA 3.0 for inclusion in Oolite, with
  credit to the artist."
- Deliverables: OBJ plus source `.blend`; triangle budget (2–5k); diffuse, emission and normal maps
  at 1024 or 2048.
- References: "industrial, not a copy of any EVE ship"; size in metres against a stock Oolite ship.
- Also post on the Oolite BB first. Community modellers may do it cheaply or free for a core addition.

## Artists to approach

| Artist | Strengths | How to reach |
|---|---|---|
| **msGameDevelopment** ([YouTube](https://www.youtube.com/@MSGDI)) | Game-ready low-poly hulls in one consistent style: mining ship TTB01, the CFS freighter line, a cockpit, a modular hangar | Through their CGTrader listings |
| **VattalusAssets** ([CGTrader](https://www.cgtrader.com/designers/vattalusassets), [website](https://www.vattalusassets.com/)) | Cockpits and interiors: Sci Fi Fighter Cockpit 2, 4–7, Cockpit Bridge 6 (a large starship bridge), a VR light-fighter cockpit, the Phobos Starhopper (a ship with a full interior), the Tempest Hover Tank. Sells on Unity, Unreal/Fab, Sketchfab, CGTrader and 3DModels.org. The [Sci Fi Fighter Cockpit 8](https://www.cgtrader.com/3d-models/space/spaceship/sci-fi-fighter-cockpit-8) and 5 in the cockpit list are probably theirs too | CGTrader private job requests are **off**. Use the "Commissions & Questions" page on their website (form, email or Messenger). Their bio offers consulting commissions and help optimising art for games. 5.0 rating, 84% response rate |

VattalusAssets is the stronger fit for the cockpit and the station or hangar interior, and
msGameDevelopment for the hulls. A three-ship mining set and a cockpit could go to different
artists, as long as the brief fixes the scale and the licence clause for both.

## Mining and industrial ships in OXPs

From the Oolite wiki pages only; no expansion files were opened. Each needs its author's permission
to go into core.

| OXP | What | License (per wiki) |
|---|---|---|
| [MinerCobra](https://wiki.alioth.net/index.php/MinerCobra) (Norby) | Cobra Mk III refit, 75t, mining laser. Model from Griff's Shipset Resources, texture from Z_GrOovy's Cobra pack | CC BY-NC-SA 4.0; page says email the author for reuse |
| [Hermitage](https://wiki.alioth.net/index.php/Hermitage) (phkb) | Run your own Rock Hermit. Its mining ships are stock models, so no new art | CC BY-NC-SA 4.0 |
| [Zeke Mining Transporter](https://bb.oolite.space/viewtopic.php?p=226627) | Slow starter mining ship (forum thread) | Not checked |
| [Hognose](https://wiki.alioth.net/index.php/Hognose_(Oolite)) | Scavenger and miner variants in undeveloped systems | Not checked |
| [Dictators](https://wiki.alioth.net/index.php/Dictators) | Imperial Freighter, Imperial Tanker, [Imperial AstroFactory](https://wiki.alioth.net/index.php/Imperial_AstroFactory). Closest to the EVE industrial feel | Not checked |
| [Ixian Freighter Mk I](https://wiki.alioth.net/index.php/Ixian_Freighter_MK1) | 120t freighter | Not checked |

Related equipment: [Miner Pod](https://wiki.alioth.net/index.php/Miner_Pod),
[Ore Processor](https://wiki.alioth.net/index.php/Ore_Scanner).

**Griff's models** are the best OXP candidates: high quality, widely reused, part of many players'
idea of Oolite. Griff's own license terms are not yet checked.

**Avoid (someone else's IP):** [Lambda Freighter](https://wiki.alioth.net/index.php/Lambda_Freighter)
(Star Wars), [Imperial Trader](https://wiki.alioth.net/index.php/Imperial_Trader_(Oolite)) (adapted
from Frontier), [Bushmaster](https://wiki.alioth.net/index.php/Bushmaster_Miner) (from ArcElite).

## Cockpits

- [Spaceship Cockpit](https://www.youtube.com/watch?v=s7iLzW3gXlg) by
  [msGameDevelopment](https://www.youtube.com/@MSGDI) (YouTube). Store listing, price and license
  not found yet; check the video description or the creator's CGTrader page.
- Other low-poly cockpits on CGTrader:
  [Sci-fi Lowpoly Cockpit With 2 Skins](https://www.cgtrader.com/3d-models/space/spaceship/cockpit),
  [Sci Fi Fighter Cockpit 8](https://www.cgtrader.com/3d-models/space/spaceship/sci-fi-fighter-cockpit-8)
  (three seat variants),
  [3DRT Sci-Fi Spacecraft Cockpit 3](https://www.cgtrader.com/3d-models/space/spaceship/3drt-sci-fi-spaceship-cockpit-3)
  (~2k polygons), [Spaceship Cockpit for VR (free)](https://www.cgtrader.com/free-3d-models/vehicle/sci-fi-vehicle/spaceship-cockpit-for-vr).
  The same licensing rules apply.

A cockpit is engine work, not just art. As far as the code shows, Oolite has no 3D cockpit
interior: the forward view is the 2D HUD from `hud.plist`. (`STATUS_COCKPIT_DISPLAY` in the source
is the status of demo ships on menu screens, not a cockpit mesh.) A 3D cockpit needs a mesh drawn
in the player's camera space, with a near clip plane and depth handling that don't fight the HUD
and the view-direction switching. This fits the "look left/right" and Everspace-style controls in
[Mining Summary](Mining%20Summary.md).

## Station interiors and the hangar view (future)

Docked, Oolite shows only the 2D screens (F3 equip, F5 status, F8 market and so on). Stations have
no interior. The idea is EVE's hangar: while docked, your own ship sits in a hangar and you can spin
it.

**Hangar models**

- [scifi modular hangar](https://www.cgtrader.com/3d-models/space/spaceship/scifi-modular-hangar) (msGameDevelopment): a modular pack meant as an in-game backdrop for changing, repairing or upgrading ships. Unrigged; door animations would be ours
- [SF - Modular Hangar](https://www.cgtrader.com/3d-models/space/spaceship/sf-modular-hangar) ($37): 17 parts, ~17.7k tris
- [NextGEN - Modular Hangar](https://cgtrader.com/3d-models/space/spaceship/nextgen-modular-hangar) ($43): 17 parts, Blender file, 4096 PSD for colour and logos
- [Sci-Fi Industrial Maintenance Bay Interior](https://www.cgtrader.com/3d-models/interior/other/sci-fi-industrial-maintenance-bay-interior) ($24.90): catwalks, gantry cranes, industrial doors. Fits the mining theme
- [Modular Mech Hangar](https://cgtrader.com/3d-models/vehicle/sci-fi/modular-mech-hangar) ($50–70): ~150k polygons, too heavy as it stands

**What the engine already has**

The pieces for a spinning ship exist already:

- `PlayerEntity::showShipModelWithKey` (`PlayerEntity.cpp:4393`) puts a rotating demo ship on a GUI
  screen. The scenario picker, contracts screens and the scripting layer (`showShipModel`) use it;
  the ship library's demo ships work the same way.
- A hidden default, `show-ship-model-in-status-screen`, already shows **your own ship** spinning on
  the F5 status screen (`PlayerEntity::setGuiToStatusScreen`, `PlayerEntity.cpp:8129`). That is the
  seed of the EVE hangar view.

**What it would take**

- Draw a hangar mesh behind the demo ship on docked screens. Demo ships are ordinary entities with
  `STATUS_COCKPIT_DISPLAY`, so the hangar could be one too, or a fixed backdrop.
- Mouse drag to orbit and zoom (the demo ship spins on a timer today).
- Lighting that suits an interior instead of the system's sun.
- Per-station variety: hangar style by station type or government, like the market rules.
- Showing fitted equipment on the model (subentities, weapon mounts) would make it more than a
  backdrop.

## Next steps

- [ ] Read prices and triangle counts for CFS24, CFS113 and the modular hangar off the listings.
- [ ] Ask msGameDevelopment about a GPLv2+/CC BY-NC-SA 3.0 license for the mining ship, freighters, cockpit and hangar as a set.
- [ ] Ask VattalusAssets, through their website's commissions page, for a quote on a cockpit and a hangar or station interior under the licence clause.
- [x] Try `show-ship-model-in-status-screen` to see the current spinning-ship view (done 2026-11-11).
- [ ] Ask Griff (or on the BB) about the license on Griff's Shipset Resources.
- [ ] Ask the C500M and MCCV-2 artists whether they'd sell a GPLv2+/CC BY-NC-SA 3.0 license, and at what price.
- [ ] Post a commission request on the Oolite BB, and get two or three freelance quotes for a three-ship set.
- [ ] Find the msGameDevelopment cockpit listing and its license.
- [ ] Try one CC0 model through OBJ → DAT to check the import pipeline end to end.
