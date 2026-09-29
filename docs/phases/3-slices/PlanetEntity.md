# Slice plan: PlanetEntity

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-lzsr). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/PlanetEntity.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Entities/PlanetEntity.mm` (1,688 lines) + header (142 lines). One class,
  `PlanetEntity` (the legacy planet and atmosphere entity), its private `OOPrivate` interface
  (declarations only, in the preamble), and a few `oo::PList` lookup helpers.
- **Shape:** the class splits cleanly into its entity side (construction, collision, update,
  accessors, shuttles) and its rendering side (draw, the subdivided sphere mesh, vertex painting,
  textures). The dictionary helpers and `baseVertexIndexForEdge()` contain no Objective-C and
  stay verbatim ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9).
- **Order:** after the `ooentity` pattern seam (oo-bj8) and after `OOEntityWithDrawable` is C++.
  Slice 1 first: it converts the class shell (`init`, the two initialisers, `dealloc`), which
  slice 2's member definitions attach to.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | class shell: initialisers, `dealloc`, collision, `update:`, accessors, shuttles | ~715 | ~1,065 |
| 2 | rendering: `drawUnconditionally`, mesh setup and painting, textures, graphics reset | ~675 | ~1,025 |
| verbatim | dictionary helpers, `baseVertexIndexForEdge()` | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Entities/PlanetEntity.mm
header: upstream/oolite/src/Core/Entities/PlanetEntity.h

slice 1: class shell, lifecycle, collision, update, accessors and shuttles
  @PlanetEntity

slice 2: rendering: draw, sphere mesh, vertex painting and textures
  -[PlanetEntity setUseTexturedModel:]
  -[PlanetEntity drawImmediate:translucent:]
  -[PlanetEntity drawUnconditionally]
  -[PlanetEntity drawModelWithVertexArraysAndSubdivision:]
  -[PlanetEntity setTextureColorForPlanet:inSystem:]
  -[PlanetEntity setUpPlanetFromTexture:]
  -[PlanetEntity initialiseBaseVertexArray]
  -[PlanetEntity initialiseBaseTerrainArray:]
  -[PlanetEntity paintVertex:*]
  -[PlanetEntity scaleVertices]
  -[PlanetEntity deleteDisplayLists]
  -[PlanetEntity resetGraphicsState]
  -[PlanetEntity isExplicitlyTextured]
  -[PlanetEntity texture]
  -[PlanetEntity loadTexture:]
  -[PlanetEntity planetTextureWithInfo:]
  -[PlanetEntity cloudTextureWithCloudColor:*]
  -[PlanetEntity cxx_allTextures]

verbatim: plain C/C++ helpers, no Objective-C (checked)
  baseVertexIndexForEdge()
  *
```
