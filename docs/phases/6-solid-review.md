# Phase 6: SOLID design review of the converted tree

A design review of `oolite-dev/src` against the five SOLID principles, as a planning input to
[Phase 6](6-modernise.md). It is the **design** axis; [docs/parity/](../parity/README.md) is the
**behavioural** axis. Parity asks whether the C++ does what the Objective-C did (complete: 7,476
rows, 170 ❌, 2 high). This asks whether the class design the conversion landed on is sound. The two
are orthogonal, and parity being complete is what makes design change safe now
([Phase 6](6-modernise.md) entry rationale).

**Reviewed:** `oolite-dev` at `21c3048a2` (61 commits ahead of the `736572b6` this repo records;
re-run the counts if the submodule has moved). 231 `.cpp` and 296 headers, 201,923 lines under
`Core`, plus `oofnd` and `SDL`. Source references are paths under `oolite-dev/src`.

**Method:** structural counts over the tree (class/base declarations, access specifiers, `virtual`
and `= 0` occurrences, `dynamic_cast` and macro-token frequencies, per-class member counts from
header indentation), then each candidate read in context. Counts come from one pass at the commit
above; they are indicative, not parser-exact — a member count is lines matching a declaration
shape, so it over-counts overloads and under-counts macro-expanded members.

**No bead.** `bd` was unreachable when this was written (Dolt refused on `127.0.0.1:3307`), so the
work items in §8 are not filed. File them before Phase 6 entry.

## Summary

The tree is bimodal. `oofnd` and the leaf classes are sound modern C++. Four god objects —
`Universe`, `Entity`, `ShipEntity`, `PlayerEntity` — carry essentially every violation, and carry
all five principles at once.

Most of what follows was a deliberate, documented conversion compromise to keep Objective-C
subclasses working, and the source says so where it happens. **Those constraints are now gone:**
zero `.m`/`.mm` files remain. The compromises outlived their reason, which is what makes them Phase
6 work rather than open questions.

| Principle | Verdict | Sharpest evidence |
|---|---|---|
| SRP | severe, concentrated | `Universe`: 264 methods, 0 `private:`, ≥15 responsibilities |
| OCP | three parallel type-discrimination mechanisms | type-tag bitfield + 7 virtual predicates + 140 `dynamic_cast` |
| LSP | one documented violation; contracts unenforced | `orientation.w` reversed for player; 640 virtuals, 16 pure |
| ISP | good where present, absent in the core | 6 narrow role interfaces; `Entity` has 49 virtual members |
| DIP | most pervasive | 3,577 `UNIVERSE` uses; tests substitute by ODR violation |

## 1. Single Responsibility

**`Universe` is the worst offender in the tree.** 11,857 lines of implementation, a 1,046-line
header, 264 member functions, and **no `private:` section at all** — `Core/Universe.h:221` is the
only access specifier in the file. Its method names group into at least fifteen responsibilities:

| Responsibility | Representative members |
|---|---|
| Entity registry & lifetime | `entityForUniversalID`, `doRemoveEntity`, `ensureEntityReallyRemoved` |
| Spatial queries | `entitiesWithinRange`, `nearestShipMatchingPredicate`, `countEntitiesMatchingPredicate` |
| Collision detection | `findCollisionsAndShadows`, `dumpCollisions`, `isVectorClearFromEntity` |
| Rendering & framebuffers | `drawUniverse`, `initTargetFramebufferWithViewSize`, `defineFrustum`, `currentPostFX`, `bloom` |
| GUI & comms log | `addCommsMessage`, `showCommsLog`, `clearGUIs`, `setMessageGuiBackgroundColor` |
| Text-to-speech | `startSpeakingString`, `nextVoice`, `voiceName`, `isSpeaking` |
| Commodity market | `commodityDataForType`, `getStationMarkets`, `loadStationMarkets`, `marketSeed` |
| Galaxy & system generation | `generateSystemData`, `findSystemAtCoords`, `routeFromSystem`, `neighboursToSystem` |
| Populators | `populateNormalSpace`, `repopulateSystem`, `clearSystemPopulator` |
| Settings & preferences | `setDetailLevel`, `getWireframeGraphics`, `setAutoSave`, `nextColorblindMode` |
| Game lifecycle | `pauseGame`, `quitGame`, `handleGameOver`, `handleOoliteException` |
| Ship construction | `addShipWithRole`, `canInstantiateShip`, `setUpCargoPods`, `fillCargopodWithRandomCargo` |
| String & description expansion | `chooseStringForKey`, `expressPosition`, `timeDescription`, `addNumericRefsInString` |
| Debug tooling | `debugDumpEntities`, `dumpDebugGraphViz`, `runLocalizationTools` |
| Shipyard & demo screens | `shipsForSaleForSystem`, `setLibraryTextForDemoShip`, `selectIntro2Next` |

**`PlayerEntity` is second.** 918 declared members in a 2,052-line header; 13,994 lines in its main
`.cpp`; **31,603 lines across the `PlayerEntity*.cpp` family.** The Objective-C categories
(Controls, Contracts, LoadSave, KeyMapper, Sound, StickMapper, StickProfile, ScriptMethods,
LegacyScriptEngine) split the *files* but were collapsed into one class declaration during
conversion; each of those headers now reduces to a note that its category "is members of
`PlayerEntity`, declared in `PlayerEntity.h`".

Upstream knew. `Core/Entities/PlayerEntityLoadSave.h:8` still carries the original comment —
*"PlayerEntity.m has gotten far too big and is in danger of becoming"* — truncated mid-sentence in
2004, and the diagnosis survived the conversion intact.

`ShipEntity` is third: 778 members, 17,449 lines across its family. `PlayerEntity` inherits all of
it, so the player's effective interface is roughly 1,700 members.

**Sound by contrast:** `OOColor` (182-line header, `private:` at :155 — the designated house-style
exemplar, [ADR-0056](../decisions/0056-phase3-class-conversion-house-style.md), and it earns it),
`OOCommodityMarket`, `OOEquipmentType`, `OOShipRegistry`, `OORoleSet`, `OOProbabilitySet`, and
effectively all of `oofnd`. The mass is in four files; the tree is not diffusely bad.

## 2. Open/Closed

Three type-discrimination mechanisms coexist, so adding an entity kind means touching all three:

1. **A public bitfield of type tags** on `Entity` (`Core/Entities/Entity.h:350`):
   `isShip`, `isStation`, `isPlayer`, `isWormhole`, `isSubEntity`, `isVisualEffect`, each `: 1`.
2. **Virtual type predicates** — `isDock()`, `isPlanet()`, `isSun()`, `isSky()`, `isEffect()`,
   `getIsVisualEffect()`, `isWaypoint()`: 7 of `Entity`'s 49 virtual members exist only to answer
   "what am I?" (`Core/Entities/EntityVirtualMembers.h:63`).
3. **140 `dynamic_cast` sites**, concentrated in `OOEntityCalledByName.cpp` (19),
   `EntityShaderBindings.cpp` (18), `PlayerEntityStickProfile.cpp` (14), `ShipEntity.cpp` (10).

`Core/Entities/ShipEntity.cpp:9777` uses two of the three in one statement: `if (target->isShip)`
then `oo::ToShip(target)`.

**The by-name dispatch table.** `Core/Entities/OOEntityCalledByNameTable.h` is 3,022 generated lines
holding **968 distinct entity methods** reachable by string, with a 163-row companion
(`OOEntityObjectNamesTable.h`) for names the facade merely answered. Flags: 494 player, 408 ship,
41 station, 23 effect, 15 dock, 11 proxy (a method may carry several). It is what the legacy AI
state machines and plist scripting dispatch through — `Core/AI.cpp:567`,
`Core/Entities/PlayerEntityLegacyScriptEngine.cpp:326`.

Generated, isolated and parity-tested, this is the right containment. The consequence matters for
Phase 6 planning: **those 968 names are an externally-observable contract**, so any SRP split of
`ShipEntity`/`PlayerEntity` must keep them resolving. That coupling, not the file sizes, is why the
god classes resist breaking up — and it is not currently in [6-modernise.md](6-modernise.md).

**Where OCP works:** the `OOOXPVerifierStage` hierarchy (abstract stage with
`dependencies()`/`dependents()`/`shouldRun()`/`run()`, a dependency-ordered driver, 12 subclasses)
and the `OOMaterial` family. `OOMaterial` is a correct Template Method: `apply()` public,
`doApply()` the override point, commented "Override instead of `apply()`"
(`Core/Materials/OOMaterial.h:111`). One nit — `apply()` is itself still `virtual`, which gives up
the pattern's guarantee; make it non-virtual.

## 3. Liskov Substitution

**The orientation wart.** The base class's own virtual-member list carries the admission at
`Core/Entities/EntityVirtualMembers.h:83`: *"Historical wart: orientation.w is reversed for
player"*. `Entity::normalOrientation()` returns `getOrientation()` unchanged
(`Core/Entities/Entity.cpp:660`); `PlayerEntity::normalOrientation()` negates `w`
(`Core/Entities/PlayerEntity.cpp:4672`). The `orientation` member means something different
depending on the runtime type, and because it is a *public data member* the virtual accessor can be
bypassed.

On severity, precisely: both direct `->orientation` reads through a base pointer are guarded.
`Core/Entities/ShipEntity.cpp:9783` sits in the `else` of `if (target->isShip)`, and the player is
always a ship, so it cannot be reached today. **This is a latent hazard, not a live defect** — but
it is latent only because of a type-tag check, i.e. because of §2. The two defects hold each other
up, so they should be fixed together.

**Contracts are enforced at runtime, not compile time.** The most mechanically fixable finding here:

- **640 `virtual` declarations in `Core` headers; 16 are pure virtual.** (`oofnd`: 5 and 1.)
- "Subclass responsibility" is instead signalled by a *logging call* carried over from the
  Objective-C idiom: `OOLogGenericSubclassResponsibility()` at **24 sites** — `OOTexture.cpp` (6),
  `OOFullScreenController.cpp` (6), `OOAsyncWorkManager.cpp` (3), `Entity.cpp` (2),
  `OOOXPVerifierStage.cpp` (2), `OOALSound.cpp` (2), and one each in `OOMaterial.cpp`,
  `OOTextureLoader.cpp`, `OOScriptTimer.cpp`.

In Objective-C that was the only option available. In C++ each of those 24 should be `= 0`, which
converts a shipped runtime log into a link error.

**Minor.** `OOMutableProbabilitySet : OOProbabilitySet` is the `NSMutableArray`/`NSArray` shape — a
mutable subtype of an immutable supertype, which breaks any caller caching on immutability. An
inherited Cocoa-ism; low priority, worth a contract comment at minimum.
`DockEntity : ShipEntity` and `StationEntity : ShipEntity` are defensible: in Oolite's model a
station genuinely is a ship, and `DockEntity` overrides narrowly (10 members) rather than disabling
inherited behaviour.

## 4. Interface Segregation

**Done well.** Six genuine role interfaces, all narrow, pure-virtual, with virtual destructors:

| Interface | Declared at | Members |
|---|---|---|
| `OOGraphicsResetClient` | `Core/OOGraphicsResetManager.h:44` | 1 |
| `OOSoundChannelDelegate` | `Core/OOALSoundChannel.h:53` | 1 |
| `oo::PListForeign` | `oofnd/PList.hpp:100` | 2 |
| `OOSubEntityInterface` | `Core/Entities/Entity.h:430` | 3 |
| `OOJSPrivateObject` | `Core/Scripting/OOJSPrivateObject.h:46` | 3 |
| `OOPListSchemaVerifierDelegate` | `Core/OXPVerifier/OOPListSchemaVerifier.h:75` | 2 |

They are used as mixins exactly as ISP prescribes: `OOMesh : OODrawable, OOGraphicsResetClient`,
`OOSoundSource : oo::RefCounted, OOSoundChannelDelegate`,
`OOPolygonSprite : OOHUDBeaconIcon, OOGraphicsResetClient`.

**The violation is that `Entity` is not one of them.** Its 49-member virtual interface forces every
subclass to carry concerns it has no use for: `warnAboutHostiles()` and `throwSparks()`
(player/ship), `subEntityReallyDied(ShipEntity*)` — a base class with a parameter typed as one of
its own grandchildren — and the 7 type predicates. `OOWaypointEntity` and `OORingEffectEntity`
inherit the lot. The natural segregation (`Collidable`, `Drawable`, `Updatable`, `Scriptable`) is
absent; `OODrawable` exists as a parallel hierarchy but `Entity` does not use it as an interface.

Likewise no client of `Universe` wants 264 methods. Its 59 virtual members exist for test stand-ins
(§5), not for segregation.

## 5. Dependency Inversion

**Globals, reached rather than injected.**

| | Count |
|---|---|
| `UNIVERSE` token in `.cpp` | 3,577 |
| `PLAYER` token in `.cpp` | 678 |
| `shared*()` singleton accessors | 14 classes |

Both are macros over free functions: `#define UNIVERSE OOGetUniverse()` (`Core/Universe.h:996`),
`#define PLAYER OOGetPlayer()` (`Core/Entities/PlayerEntity.h:2029`). The 14 singletons are
`GameController`, `OOJavaScriptEngine`, `OOShipRegistry`, `OOJoystickManager`, `OOSoundMixer`,
`OOOpenALController`, `OOAsyncWorkManager`, `OOCacheManager`, `OOGraphicsResetManager`,
`OOOpenGLExtensionManager`, `OOMusicController`, `OOOXZManager`, `OODebugMonitor`, `OONullTexture`.
No abstraction sits between caller and concretion anywhere in that set.

**`Core` depends downward on the platform layer.** 38 files under `Core/` include SDL or
`MyOpenGLView.h` directly; 44 name `MyOpenGLView`. `MyOpenGLView` is a concrete 97-member class in
`SDL/`. There is no `IGameView`: high-level game logic depends on the low-level windowing class.

**The sharpest evidence in the review.** With no interface to depend on, the test suite substitutes
by *replacing the class at link time*. `Universe` and `MyOpenGLView` were made partly virtual for
exactly this (`SDL/MyOpenGLView.h:173`: "The members marked virtual are the ones the whole-game
tests' recording views answer"), and `UniverseVirtualMembers.h` / `EntityVirtualMembers.h` expose
the virtual list as a macro so a test can declare a *different class with the same name and a
matching vtable*:

```cpp
// tests/unit/core/test_OOBasicMaterial.cpp:66-87
class Universe;
Universe* gSharedUniverse = nullptr;
#include "UniverseStandIn.h"
class Universe : public oo::RefCounted {   // not the game's Universe
 public:
  OO_UNIVERSE_STAND_IN_VIRTUAL_MEMBERS
  ...
};
class TestUniverse : public Universe { ... };
```

That is a deliberate ODR violation, sound only while two unrelated classes keep identical vtable
layouts. The headers say so: `Core/Entities/EntityVirtualMembers.h:13` — *"Never reorder without
rebuilding every test."* 16 test files expand the stand-in macros. A single abstract `IUniverse`
would delete the whole mechanism and make the substitution type-safe.

**Where DIP works:** `OOJoystickManager` → `OOSDLJoystickManager` (platform behind an abstract
base), `OOSound` → `OOALBufferedSound`/`OOALStreamedSound`/`OOMusic`, `OODebuggerInterface` →
`OODebugTCPConsoleClient`, and the `setDelegate`/`setBindingTarget` seams on `OOSoundChannel`,
`OOMaterial`, `OODrawable`, `OOPListSchemaVerifier`.

## 6. Encapsulation

Not a SOLID principle, but the enabler for all five findings above. `ShipEntity` has **111 public
data members** and a single `public:` run from `Core/Entities/ShipEntity.h:218` to `:1536` — 1,318
lines before the first `private:`. `Universe` has no `private:` at all. Both justifications are in
the source, and **both are now obsolete:**

- `Core/Entities/Entity.h:345` — *"we forego encapsulation for some variables in order to lose the
  overheads of Obj-C accessor methods"*. There are no Obj-C accessor methods; a C++ inline getter
  compiles to nothing.
- `Core/Entities/Entity.h:76` — *"the game reads them directly (`ent->position`), and Objective-C
  subclasses cannot be granted protected access to a C++ class"*. There are no Objective-C
  subclasses: 0 `.m`/`.mm` files, no `@implementation` in the tree
  ([Phase 4](4-remove-objc-runtime.md) exit).

This is why the §3 wart cannot be contained and why `Universe` cannot be split: 122 sites read
`->position` directly, and every public field is a dependency edge no interface can mediate.

## 7. `oofnd` — the counter-example

Worth stating plainly, because it sets the standard the Phase 6 work should be held to: **80
class/struct declarations, 5 `virtual` keywords in total.** `String`, `PList`, `Expected`, `Data`,
`Date`, `Encoding`, `FileSystem`, `Scanner`, `Http`, `Thread` are value types with no inheritance.
SOLID is largely *not applicable* to them, which is the correct outcome, not a gap — the
replacement Foundation needed no polymorphism, so it has none. `oo::PListForeign` is its one
2-method extension seam, used by `OOColor`, `OOTexture`, `OOCharacter`, `OOScript`,
`OOEquipmentType`, `OOShipGroup`, `OOSystemInfo`. Consistent with
[ADR-0003](../decisions/0003-intrusive-refcount.md) and [ADR-0012](../decisions/0012-c-stays-c.md).

## 8. Work items for Phase 6

[6-modernise.md](6-modernise.md) already lists "Break up `Universe`: separate scene graph,
simulation, and presentation" and value semantics for leaf classes. These are the items it does not,
ordered by payoff over risk. Each needs a bead; none is filed (see the header).

| # | Item | Size | Gate | Notes |
|--:|---|---|---|---|
| 1 | Convert the 24 `OOLogGenericSubclassResponsibility()` stubs to `= 0` | hours | compiler | Mechanical, no behaviour change on correct code; turns a shipped runtime log into a link error. Do first. |
| 2 | Privatise `Entity`/`ShipEntity` fields behind inline accessors | large, mechanical | Tier C + goldens | Stated reasons are void (§6). Prerequisite for 3, 4 and 5. clang-tidy-assistable. |
| 3 | Extract `IUniverse` and `IGameView` | medium | Tier C | Deletes the ODR stand-in mechanism (§5); must land **before** the `Universe` split so the split has a stable seam. |
| 4 | Collapse the three type-discrimination mechanisms to one | medium | Tier C | Keep virtual dispatch; drop the bitfield and `isX()` predicates as their last callers go. |
| 5 | Fix the player orientation wart | small, risky | goldens | Normalise `w` where player input is read; delete the `normalOrientation`/`setNormalOrientation` override pair. Sequence with 4 — the hazard is currently masked by the tags. |
| 6 | Audit the 968-name by-name surface against any SRP split | investigation | parity test | **Gate on 1–5 ever reaching the god classes.** Levers: `tools/gen-entity-by-name-table.py` and its parity test. Not in the phase doc. |
| 7 | Segregate `Entity`'s 49-member interface | large | Tier C + goldens | `Collidable`/`Drawable`/`Updatable`/`Scriptable`. Highest value, highest risk; last. |

Items 1 and 2 are safe before the C++23 upgrade. Items 3–7 should follow it, so the split classes
are written once in the target dialect rather than converted twice.

## Status log

- 2026-11-02 — Review written against `oolite-dev` `21c3048a2`. No code changed; no beads filed
  (`bd` unreachable).
