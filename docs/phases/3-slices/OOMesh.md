# Slice plan: OOMesh

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-sw6m). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OOMesh.md`, which recounts the file
every time, so the numbers below are only a snapshot.

- **File:** `Core/OOMesh.mm` (2,273 lines) + header (201 lines). Class `OOMesh` (a drawable) with
  a primary block, a large `Private` category, and two small categories on `OOCacheManager`
  (mesh-data and octree caching) whose static helpers (`VFR*`) are plain C.
- **Shape:** four slices. `loadData:scaleFactor:` alone is ~475 lines, so loading gets its own
  slice; geometry (normals, tangents, bounds, octree) and GL rendering/buffers split the rest of
  the `Private` category. `octreeDepth` appears twice (preprocessor alternatives).
- **Order:** slice 1 (class shell) first; 2, 3 and 4 are independent of each other. The
  `OOCacheManager` categories become free functions next to the cache (recipe row
  `@interface X (Feature)` for a class converted elsewhere): they ride with slice 1.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | class shell, factories, lifecycle, accessors, `OOCacheManager` categories | ~355 | ~805 |
| 2 | loading: designated init, copy, `modelData`, `setModelFromModelData`, `loadData` | ~720 | ~1,170 |
| 3 | geometry: winding, normals, tangents, bounds, rescale, octree, bounding boxes | ~465 | ~915 |
| 4 | rendering: `renderOpaqueParts`, vertex arrays, display lists, buffers, debug draw | ~480 | ~930 |

```slice-plan
source: upstream/oolite/src/Core/OOMesh.mm
header: upstream/oolite/src/Core/OOMesh.h

slice 1: class shell, factories, lifecycle, accessors, OOCacheManager categories
  @OOMesh
  @OOCacheManager(OOMesh)
  @OOCacheManager(Octree)
  Profile()
  IsLegacyNormalMode()
  IsPerVertexNormalMode()
  NormalModeDescription()         # was in @OOMesh; slice 1 (oo-dnbf) made the class C++ (oo-7j62d)
  OOCacheManager*()               # the @OOCacheManager(OOMesh)/(Octree) bodies, now free functions
  VFR*()                          # was in @OOCacheManager(Octree)

slice 2: loading - designated initialiser, copying, model data, the .dat parser
  -[OOMesh initWithName:cacheKey:materialDictionary:shadersDictionary:smooth:shaderMacros:shaderBindingTarget:scaleFactor:cacheWriteable:]
  -[OOMesh mutableCopyWithZone:]
  -[OOMesh modelData]
  -[OOMesh setModelFromModelData:name:]
  -[OOMesh loadData:scaleFactor:]

slice 3: geometry - winding, normals, tangents, bounding volumes, rescaling, octree
  @OOMesh(Private)
  FaceArea*()                     # was in @OOMesh(Private); free since slice 1 landed (oo-7j62d)
  -[OOMesh octree]
  -[OOMesh octreeDepth]
  -[OOMesh findBoundingBoxRelativeToPosition:basis:ri:rj:selfPosition:selfBasis:si:sj:]
  -[OOMesh findSubentityBoundingBoxWithPosition:rotMatrix:]
  -[OOMesh meshRescaledBy:]

slice 4: rendering - opaque parts, vertex arrays, display lists, buffer allocation, debug draw
  -[OOMesh renderOpaqueParts]
  -[OOMesh rebindMaterials]
  -[OOMesh setUpVertexArrays]
  -[OOMesh deleteDisplayLists]
  -[OOMesh resetGraphicsState]
  -[OOMesh debugDrawNormals]
  -[OOMesh allocate*]
  -[OOMesh setRetainedObject:forKey:]
  -[OOMesh renameTexturesFrom:to:]
  Scribble()
```
