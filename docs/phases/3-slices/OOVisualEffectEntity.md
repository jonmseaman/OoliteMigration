# Slice plan: OOVisualEffectEntity

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-xjga). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OOVisualEffectEntity.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Entities/OOVisualEffectEntity.mm` (1,064 lines) + header (168 lines). One class,
  `OOVisualEffectEntity : OOEntityWithDrawable <OOSubEntity, OOBeaconEntity>`, with ~90 methods,
  its private `Private` interface (declarations only, in the preamble), the category
  `SubEntityRelationship` (its override of `Entity`'s `-isShipWithSubEntityShip:`), and five
  file-local `oo::PList` / subentity-list helpers.
- **Why it is split:** the class is messaged by its own selectors (55 in its header, plus the
  binding category in `OOJSVisualEffect.mm`) from eight other files, so its conversion keeps a
  facade `@interface OOVisualEffectEntity : OOEntityWithDrawable` with one forwarder per selector
  (ADR-0056 amendments oo-up4b item 3, oo-0mxi, oo-wue8) on top of a ~1,000-line C++ class: about
  1,400 written lines in one story, against the 400-line story budget.
- **Shape:** the class splits into its entity side (construction from the effect definition,
  the mesh, subentities and flashers, scaling, orientation vectors, drawing, update, the break
  pattern flag, the subentity-relationship category) and its scripted surface (scanner colours,
  the JS script and its events, the beacon protocol, and the shader-bindable uniforms). The three
  dictionary helpers have no Objective-C and stay verbatim
  ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9); the two subentity-list
  helpers send messages, so they go with the subentities in slice 1.
- **Order:** after the `ooentity` pattern seam (oo-bj8), `OOEntityWithDrawable` (converted with it)
  and `OOFlasherEntity` (oo-bn5j, landed). Slice 1 first: it carries the class shell (the
  `@interface` and ivars become the C++ class declaration, and the facade with every selector's
  forwarder), which slice 2's member definitions attach to; until slice 2 lands, its methods stay
  Objective-C in a category of the facade that reads the C++ part (amendment oo-0otc item 2).
  Slice 1 also files the facade's deletion bead.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | class shell: initialisers, `dealloc`, flags, mesh, subentities and flashers, scaling, vectors, drawing, `update:`, break pattern, `SubEntityRelationship` | ~620 | ~930 |
| 2 | scanner colours, the script and its events, the beacon protocol, shader uniforms | ~330 | ~640 |
| verbatim | `ValueForKey()`, `OptionalStringForKey()`, `DictionaryForKey()` | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Entities/OOVisualEffectEntity.mm
header: upstream/oolite/src/Core/Entities/OOVisualEffectEntity.h

slice 1: class shell, lifecycle, mesh, subentities and flashers, scaling, drawing and update
  @OOVisualEffectEntity
  @OOVisualEffectEntity(SubEntityRelationship)
  SubEntitiesOf()
  VisualEffectsIn()

slice 2: scanner colours, scripting, beacons and shader uniforms
  -[OOVisualEffectEntity scannerDisplayColor*]
  -[OOVisualEffectEntity setScannerDisplayColor*]
  -[OOVisualEffectEntity setScript:]
  -[OOVisualEffectEntity script]
  -[OOVisualEffectEntity scriptInfo]
  -[OOVisualEffectEntity doScriptEvent:]
  -[OOVisualEffectEntity remove]
  -[OOVisualEffectEntity compareBeaconCodeWith:]
  -[OOVisualEffectEntity beaconCode]
  -[OOVisualEffectEntity setBeaconCode:]
  -[OOVisualEffectEntity beaconLabel]
  -[OOVisualEffectEntity setBeaconLabel:]
  -[OOVisualEffectEntity isBeacon]
  -[OOVisualEffectEntity beaconDrawable]
  -[OOVisualEffectEntity prevBeacon]
  -[OOVisualEffectEntity nextBeacon]
  -[OOVisualEffectEntity setPrevBeacon:]
  -[OOVisualEffectEntity setNextBeacon:]
  -[OOVisualEffectEntity isJammingScanning]
  -[OOVisualEffectEntity hullHeatLevel]
  -[OOVisualEffectEntity setHullHeatLevel:]
  -[OOVisualEffectEntity shader*]
  -[OOVisualEffectEntity setShader*]

verbatim: plain C++ helpers, no Objective-C (checked)
  ValueForKey()
  OptionalStringForKey()
  DictionaryForKey()
```
