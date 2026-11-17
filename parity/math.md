# Parity findings: math
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## CollisionRegion

<a id="collisionregion"></a>
Upstream `src/Core/CollisionRegion.m` ↔ `Core/CollisionRegion.cpp` (633 / 663 lines)

**Status:** done — 20 rows: 18 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[CollisionRegion init]` (46) | `CollisionRegion::CollisionRegion()` `Core/CollisionRegion.cpp:64` (reserve, then `crid = crid_counter++`) | ⚠️ |
| `-[CollisionRegion initAsUniverse]` (61) | `CollisionRegion(AsUniverse)` `Core/CollisionRegion.cpp:73` (delegates, so one crid) | ✅ |
| `-[CollisionRegion initAtLocation:withRadius:withinRegion:]` (69) | `CollisionRegion(HPVector, GLfloat, CollisionRegion*)` `Core/CollisionRegion.cpp:79` | ✅ |
| `-[CollisionRegion dealloc]` (80) | `~CollisionRegion` `Core/CollisionRegion.cpp:90` | ✅ |
| `-[CollisionRegion description]` (88) | `descriptionComponents` `Core/CollisionRegion.cpp:94` (same "ID: %d, %zu subregions, %u ents" inside `<CollisionRegion 0x…>{…}`) | ✅ |
| `-[CollisionRegion clearSubregions]` (93) | `clearSubregions` `Core/CollisionRegion.cpp:99` | ✅ |
| `-[CollisionRegion addSubregionAtPosition:withRadius:]` (99) | `addSubregionAtPosition` `Core/CollisionRegion.cpp:104` (same fit/cross order, append) | ✅ |
| `positionIsWithinRegion` (126) | static member `Core/CollisionRegion.cpp:128` | ✅ |
| `sphereIsWithinRegion` (143) | static member `Core/CollisionRegion.cpp:145` | ✅ |
| `positionIsWithinBorders` (160) | static member `Core/CollisionRegion.cpp:162` | ✅ |
| `-[CollisionRegion clearEntityList]` (179) | `clearEntityList` `Core/CollisionRegion.cpp:181` | ✅ |
| `-[CollisionRegion addEntity:]` (186) | `addEntity` `Core/CollisionRegion.cpp:187` (`push_back`) | ⚠️ |
| `-[CollisionRegion checkEntity:]` (205) | `checkEntity` `Core/CollisionRegion.cpp:192` | ✅ |
| `-[CollisionRegion findCollisions]` (226) | `findCollisions` `Core/CollisionRegion.cpp:211` (filter, clear, chain walk, proximity, docking corridor and collider order all match) | ✅ |
| `entityByEntityOcclusionToValue` (377) | anon-namespace fn `Core/CollisionRegion.cpp:390` | ✅ |
| `shadowAtPointOcclusionToValue` (387) | `Core/CollisionRegion.cpp:403` (same constants 1.5f/0.90f/0.1; `sqrt`/`asin`/`acos` float overloads, `asin(1)` double, as tgmath) | ✅ |
| `testEntityOccludedByEntity` (496) | anon-namespace inline `Core/CollisionRegion.cpp:520` | ✅ |
| `-[CollisionRegion findShadowedEntities]` (502) | `findShadowedEntities` `Core/CollisionRegion.cpp:528` | ✅ |
| `-[CollisionRegion collisionDescription]` (618) | `collisionDescription` `Core/CollisionRegion.cpp:652` (same "p%u - c%u") | ✅ |
| `-[CollisionRegion debugOut]` (623) | `debugOut` `Core/CollisionRegion.cpp:656` | ✅ |

**Differences:**

- ⚠️ **low** — out-of-memory path only: `-init` released itself and returned nil when the `entity_array` malloc failed; the constructor's `entity_array.reserve(COLLISION_MAX_ENTITIES)` now throws `std::bad_alloc`. Commit 724accb9c says so ("Running out of memory now throws std::bad_alloc where these raised OOMallocException"). (still open, changed form: it was an `OOMallocException` at the previous run) — upstream `Core/CollisionRegion.m:48-54` ↔ port `Core/CollisionRegion.cpp:64-71`
- ⚠️ **low** — out-of-memory path only: growing the list raised `NSMallocException` "Not enough memory to grow collision region member list."; `push_back` now throws `std::bad_alloc`. The growth policy (`1 + 2n`) is gone, but that only changes capacity. Same commit 724accb9c. (new) — upstream `Core/CollisionRegion.m:186-203` ↔ port `Core/CollisionRegion.cpp:187-190`
- ✅ note: in `findCollisions`, each ObjC message to a cast `ShipEntity*`/`StationEntity*` became a call guarded by `oo::ToShip`/`oo::ToStation`. The guards sit behind the same `isShip`/`isStation` tests, so they never skip a call. `getCollidingEntities()` always returns a non-null pointer (`Core/Entities/Entity.cpp:729-731`), so add and clear always happen. — upstream `Core/CollisionRegion.m:263-345` ↔ port `Core/CollisionRegion.cpp:255-365`
- note: the variable-length arrays `entities_to_test`, `planets` and `ships` are now `std::vector`. The debug log's `%@ self` is rebuilt as the same `<CollisionRegion 0x…>{ID: …}` text, and the log class `collisionRegion.debug` is unchanged.

## OOHPVector

<a id="oohpvector"></a>
Upstream `src/Core/OOHPVector.m` ↔ `Core/OOHPVector.cpp` (129 / 154 lines)

**Status:** done — 9 rows: 9 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `HPVectorDescription` (37) | `HPVectorDescription` `Core/OOHPVector.cpp:40` (`"({:g}, {:g}, {:g})"` = `%g`) | ✅ |
| `ArrayFromHPVector` (42) | `ArrayFromHPVector` `Core/OOHPVector.cpp:44` (`std::vector<double>{x,y,z}`) | ✅ |
| `OORandomUnitHPVector` (62) | `Core/OOHPVector.cpp:58` (same 0.25 / 0.0 rejection) | ✅ |
| `OOHPVectorRandomSpatial` (75) | `Core/OOHPVector.cpp:77` | ✅ |
| `OOHPVectorRandomRadial` (88) | `Core/OOHPVector.cpp:96` (direction drawn before length) | ✅ |
| `OOHPRandomPositionInBoundingBox` (93) | `Core/OOHPVector.cpp:104` | ✅ |
| `OORandomPositionInCylinder` (102) | `Core/OOHPVector.cpp:115` (same 1.2 factor, log class and `%f`→`{:f}` text) | ✅ |
| `OORandomPositionInShell` (116) | `Core/OOHPVector.cpp:138` | ✅ |
| `OOProjectHPVectorToPlane` (126) | `Core/OOHPVector.cpp:148` | ✅ |

**Differences:**

- ✅ note: the random draws that were nested in one call are now one per local. They keep the left-to-right order that clang evaluated upstream (x, y, z; direction before length; interpolation before offset), and the code comments say so. — upstream `Core/OOHPVector.m:68,81,90,111` ↔ port `Core/OOHPVector.cpp:63-68,82-87,97-100,128-132`
- note: `HPVectorDescription` and `ArrayFromHPVector` no longer have the `cxx_` prefix (commit 0d2f6072c). They return `std::string` and `std::vector<double>`.

## OOMatrix

<a id="oomatrix"></a>
Upstream `src/Core/OOMatrix.m` ↔ `Core/OOMatrix.cpp` (424 / 419 lines)

**Status:** done — 20 rows: 20 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOMatrixForRotation` (40) | `Core/OOMatrix.cpp:47` (same terms, including the shared upstream typo; see Differences) | ✅ |
| `OOMatrixForQuaternionRotation` (56) | `Core/OOMatrix.cpp:63` | ✅ |
| `OOMatrixEqual` (91) | `Core/OOMatrix.cpp:95` | ✅ |
| `OOMatrixMultiply` (105) | `Core/OOMatrix.cpp:107` (same operand order) | ✅ |
| `OOVectorMultiplyMatrix` (121) | `Core/OOMatrix.cpp:127` | ✅ |
| `OOHPVectorMultiplyMatrix` (137) | `Core/OOMatrix.cpp:142` (still single-precision `OOScalar` temporaries) | ✅ |
| `OOMatrixOrthogonalize` (150) | `Core/OOMatrix.cpp:154` | ✅ |
| `OOMatrixDescription` (176) | `Core/OOMatrix.cpp:179` (`std::string`, `{:g}` with the same braces and commas) | ✅ |
| `OOMatrixForBillboard` (186) | `Core/OOMatrix.cpp:189` | ✅ |
| `OOMatrixRowSwap` (207) | `Core/OOMatrix.cpp:209` | ✅ |
| `OOMatrixRowScale` (222) | `Core/OOMatrix.cpp:223` | ✅ |
| `OOMatrixRowOperation` (234) | `Core/OOMatrix.cpp:234` | ✅ |
| `OOMatrixColumnSwap` (246) | `Core/OOMatrix.cpp:246` | ✅ |
| `OOMatrixColumnScale` (261) | `Core/OOMatrix.cpp:261` | ✅ |
| `OOMatrixColumnOperation` (273) | `Core/OOMatrix.cpp:272` | ✅ |
| `OOMatrixLeftTransform` (285) | `Core/OOMatrix.cpp:284` | ✅ |
| `OOMatrixRightTransform` (320) | `Core/OOMatrix.cpp:318` | ✅ |
| `OOMatrixInverse` (359) | `Core/OOMatrix.cpp:356` | ✅ |
| `OOMatrixInverseWithDeterminant` (364) | `Core/OOMatrix.cpp:360` (same `fabsf`/`fabs` pivot search) | ✅ |
| `GLUniformMatrix3` (411) | `Core/OOMatrix.cpp:406` (`NO`→`GL_FALSE`, both 0) | ✅ |

**Differences:**

- subtle — shared upstream bug (found 2026-11-08): the third row of `OOMatrixForRotation(axis, angle)` starts `t * x * y + s * y`, where the axis-angle matrix needs `t * x * z + s * y`. Port and upstream agree, so this is not a parity ❌. Upstream `t * x * y + s * y, t * y * z - s * x, t * z * z + c, 0.0f,` (`Core/OOMatrix.m:52`) ↔ port `0.0f, t * x * y - s * z, t * y * y + c, t * y * z + s * x, 0.0f, t * x * y + s * y, t * y * z - s * x, t * z * z + c, …` (`Core/OOMatrix.cpp:56-59`)
- ✅ note: apart from clang-format, the function bodies are token-identical. I compared them with whitespace and comments stripped. OOMatrix.cpp is a plain C++ unit (`OO_PLAIN_CPP_UNIT`). On this commit I re-checked with `clang++ -std=gnu++20 -fsyntax-only` and the port's headers: in both plain and game units, `sin`, `cos`, `sqrt`, `acos`, `asin`, `atan2`, `fabs`, `fmax` and `fmin` on `float` resolve to the `float` overloads, and `asin(1)` to `double`. That matches upstream tgmath.

## OOMeshToOctreeConverter

<a id="oomeshtooctreeconverter"></a>
Upstream `src/Core/OOMeshToOctreeConverter.m` ↔ `Core/OOMeshToOctreeConverter.cpp` (825 / 842 lines)

**Status:** done — 18 rows: 18 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `InitGeometryData` (181) | `Core/OOMeshToOctreeConverter.cpp:197` | ✅ |
| `DestroyGeometryData` (191) | `Core/OOMeshToOctreeConverter.cpp:206` (`free` of the heap block → release of the `heap` vector; same debug scribble) | ✅ |
| `AddTriangle` (210) | `Core/OOMeshToOctreeConverter.cpp:226` | ✅ |
| `-[OOMeshToOctreeConverter initWithCapacity:]` (223) | ctor `Core/OOMeshToOctreeConverter.cpp:236` (same `capacity == 0 → 1`) | ✅ |
| `-[OOMeshToOctreeConverter dealloc]` (236) | dtor `Core/OOMeshToOctreeConverter.cpp:245` | ✅ |
| `+[OOMeshToOctreeConverter converterWithCapacity:]` (243) | `converterWithCapacity` `Core/OOMeshToOctreeConverter.cpp:249` | ✅ |
| `-[OOMeshToOctreeConverter descriptionComponents]` (248) | `descriptionComponents` `Core/OOMeshToOctreeConverter.cpp:254` ("%u triangles") | ✅ |
| `-[OOMeshToOctreeConverter addTriangle:]` (253) | `addTriangle` `Core/OOMeshToOctreeConverter.cpp:259` (drops degenerate triangles first) | ✅ |
| `-[OOMeshToOctreeConverter findOctreeToDepth:]` (260) | `findOctreeToDepth` `Core/OOMeshToOctreeConverter.cpp:265` (same 0.5f pad) | ✅ |
| `MaxDimensionFromOrigin` (272) | `Core/OOMeshToOctreeConverter.cpp:277` (`fmax`/`fabs` float overloads) | ✅ |
| `BuildSubOctree` (289) | `Core/OOMeshToOctreeConverter.cpp:293` (same Z→Y→X split order, `kFactor = 2`, child order 000…111) | ✅ |
| `TranslateGeometryX` (414) | `Core/OOMeshToOctreeConverter.cpp:416` | ✅ |
| `TranslateGeometryY` (428) | `Core/OOMeshToOctreeConverter.cpp:429` | ✅ |
| `TranslateGeometryZ` (442) | `Core/OOMeshToOctreeConverter.cpp:442` | ✅ |
| `SplitGeometryX` (456) | `Core/OOMeshToOctreeConverter.cpp:455` | ✅ |
| `SplitGeometryY` (565) | `Core/OOMeshToOctreeConverter.cpp:567` | ✅ |
| `SplitGeometryZ` (676) | `Core/OOMeshToOctreeConverter.cpp:681` | ✅ |
| `AddTriangle_slow` (802) (missed by extractor: `static NO_INLINE_FUNC`) | `Core/OOMeshToOctreeConverter.cpp:816` (`heap.resize`; same capacity rule; OOM → same log + `exit`) | ✅ |

**Differences:**

- ✅ note: the translate, split and build bodies are token-identical to upstream, with whitespace and comments stripped; only `[builder …]` became `builder->…`.
- ✅ note (new since the previous run): the growable triangle store is now a `std::vector<Triangle> heap` member, and `triangles` points at `smallData` or `heap.data()`. In `AddTriangle_slow` the first growth is `MAX(pendingCapacity, 32)` and each later growth is `1 + 2n`, as upstream. On OOM, `std::bad_alloc` is caught and `OutOfGeometryMemory()` logs `general.error.allocationFailure` "!!!!! Ran out of memory to allocate more geometry!" and calls `exit(EXIT_FAILURE)`, as upstream did on a NULL `malloc`/`realloc`. — upstream `Core/OOMeshToOctreeConverter.m:802-825` ↔ port `Core/OOMeshToOctreeConverter.cpp:794-842`
- **low** (failure-path text only, still open): `NSParameterAssert`/`NSCParameterAssert` became `OOCParameterAssert`, so the reason names `__PRETTY_FUNCTION__`. The conditions are unchanged. — upstream `Core/OOMeshToOctreeConverter.m:225` ↔ port `Core/OOMeshToOctreeConverter.cpp:237`

## OOQuaternion

<a id="ooquaternion"></a>
Upstream `src/Core/OOQuaternion.m` ↔ `Core/OOQuaternion.cpp` (408 / 407 lines)

**Status:** done — 17 rows: 17 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `quaternion_multiply` (30) | `Core/OOQuaternion.cpp:34` | ✅ |
| `quaternion_set_random` (41) | `Core/OOQuaternion.cpp:45` (same `(Ranrot() % 1024) - 511.5f`, w-x-y-z draw order) | ✅ |
| `vector_forward_from_quaternion` (50) | `Core/OOQuaternion.cpp:57` | ✅ |
| `HPvector_forward_from_quaternion` (83) | `Core/OOQuaternion.cpp:89` | ✅ |
| `vector_up_from_quaternion` (89) | `Core/OOQuaternion.cpp:94` | ✅ |
| `vector_right_from_quaternion` (122) | `Core/OOQuaternion.cpp:126` | ✅ |
| `basis_vectors_from_quaternion` (154) | `Core/OOQuaternion.cpp:157` (NULL checks → nullptr) | ✅ |
| `quaternion_rotation_between` (213) | `Core/OOQuaternion.cpp:216` | ✅ |
| `quaternion_rotation_betweenHP` (237) | `Core/OOQuaternion.cpp:240` | ✅ |
| `quaternion_limited_rotation_between` (261) | `Core/OOQuaternion.cpp:265` | ✅ |
| `quaternion_rotate_about_x` (291) | `Core/OOQuaternion.cpp:297` | ✅ |
| `quaternion_rotate_about_y` (309) | `Core/OOQuaternion.cpp:314` | ✅ |
| `quaternion_rotate_about_z` (327) | `Core/OOQuaternion.cpp:331` | ✅ |
| `quaternion_rotate_about_axis` (345) | `Core/OOQuaternion.cpp:348` | ✅ |
| `QuaternionDescription` (361) | `Core/OOQuaternion.cpp:363` (`"({:g} {} {:g}i {} {:g}j {} {:g}k)"`, `char` signs print as characters as with `%c`) | ✅ |
| `quaternion_rotate_vector` (378) | `Core/OOQuaternion.cpp:379` | ✅ |
| `quaternion_rotate_HPvector` (394) | `Core/OOQuaternion.cpp:394` | ✅ |

**Differences:**

- ✅ note: with whitespace and comments stripped, the bodies are token-identical. The only changes are C casts → `static_cast` in `quaternion_set_random`, `NULL` → `nullptr`, and `NSString` → `std::format`. The epsilons, the arc clamp and the operand order are the same. This is a plain C++ unit, and the float overloads of `sqrt`/`acos`/`sin`/`cos` were re-checked (see OOMatrix).

## OOSpatialReference

<a id="oospatialreference"></a>
Upstream `src/Core/OOSpatialReference.m` ↔ *(absorbed: no same-named file; the only method lives on `Entity`, `Core/Entities/Entity.cpp`)*

**Status:** done — 3 rows: 1 ✅ 0 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `@protocol OOSpatialReference` `-transformationMatrix` (h:34-38) (added: the `.m` has no functions) | none: the protocol is gone, and upstream referenced it only in its own `.h`/`.m` | ➖ |
| `@interface Entity (OOSpatialReference)` (h:40-41; the `.m` only `#import`s the header) | none (empty category) | ➖ |
| `-[Entity transformationMatrix]` (`Entities/Entity.m:813`), the method the protocol named | `Entity::transformationMatrix` `Core/Entities/Entity.cpp:711` (same `OOMatrixHPTranslate(rotMatrix, position)`) | ✅ |

**Differences:**

- ➖ **low** (still open) — the formal protocol and its empty category are dropped. There is no behaviour to lose: the upstream `.m` is just an `#import`, and a port source search finds no `OOSpatialReference`. — upstream `Core/OOSpatialReference.h:34-41` ↔ port (none)

## OOVector

<a id="oovector"></a>
Upstream `src/Core/OOVector.m` ↔ `Core/OOVector.cpp` (139 / 144 lines)

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `VectorDescription` (39) | `Core/OOVector.cpp:42` (`"({:g}, {:g}, {:g})"`) | ✅ |
| `-[OONativeVector initWithVector:]` (46) | `OONativeVector::OONativeVector` `Core/OOVector.cpp:46` | ✅ |
| `-[OONativeVector getVector]` (57) | `OONativeVector::getVector` `Core/OOVector.cpp:48` | ✅ |
| `OORandomUnitVector` (76) | `Core/OOVector.cpp:66` (same 0.25f / 0.0f rejection) | ✅ |
| `OOVectorRandomSpatial` (89) | `Core/OOVector.cpp:85` | ✅ |
| `OOVectorRandomRadial` (102) | `Core/OOVector.cpp:104` (direction before length) | ✅ |
| `OORandomPositionInBoundingBox` (107) | `Core/OOVector.cpp:111` | ✅ |

**Differences:**

- I deleted a false row: `OORandomPositionInShell` (130) sits inside a `/* … */` comment upstream, and in the port (`Core/OOVector.cpp:120-144`).
- ✅ note: the random draws are one per local, in clang's left-to-right order, as the comments say. — upstream `Core/OOVector.m:82,95,104` ↔ port `Core/OOVector.cpp:71-76,90-95,105-108`
- note: `OONativeVector` is an `oo::PListForeign`. Its `description()` is `<OONativeVector 0x…>`, matching the ObjC default; `className()` (`Core/OOVector.cpp:50`) is new and only names the type.

## OOVoxel

<a id="oovoxel"></a>
Upstream `src/Core/OOVoxel.m` ↔ `Core/OOVoxel.cpp` (197 / 168 lines)

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `checkFace` (29) | `Core/OOVoxel.cpp:29` | ✅ |
| `checkBevel` (47) | `Core/OOVoxel.cpp:40` (same 0x001…0x800 bits) | ✅ |
| `checkCorner` (78) | `Core/OOVoxel.cpp:58` | ✅ |
| `lineIntersectionWithFace` (101) | `Core/OOVoxel.cpp:72` (same face order R, L, T, B, F, Bk) | ✅ |
| `checkPoint` (135) | `Core/OOVoxel.cpp:100` | ✅ |
| `checkLine` (144) | `Core/OOVoxel.cpp:108` (same `0x3f - face` masks) | ✅ |
| `lineCubeIntersection` (164) | `Core/OOVoxel.cpp:139` (same `<< 8` / `<< 24` packing) | ✅ |

**Differences:**

- ✅ note (changed since the previous run): the file is now `OOVoxel.cpp`, compiled as C++ (commit 48cbd7abf, "Compile the remaining C sources as C++"), not `OOVoxel.c` compiled as C. Apart from formatting, the bodies match upstream line for line, and they call no `<math.h>` functions, so C++ overload resolution cannot change anything. The `CUBE_FACE_*` macros became `inline constexpr int` with the same values 0x01…0x20. — upstream `Core/OOVoxel.h:29-34` ↔ port `Core/OOVoxel.h:37-42`

## Octree

<a id="octree"></a>
Upstream `src/Core/Octree.m` ↔ `Core/Octree.cpp` (906 / 901 lines)

**Status:** done — 37 rows: 31 ✅ 4 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[Octree init]` (80) | none: no default constructor (comment `Core/Octree.cpp:68`) | ➖ |
| `-[Octree initWithData:radius:]` (89) | `Octree::Octree` + `Octree::initWithData` `Core/Octree.cpp:70, 90` (null when `_octree` is null) | ⚠️ |
| `-[Octree initWithDictionary:]` (112) | `Octree::initWithDictionary` `Core/Octree.cpp:101` (`octree` must be data with length % sizeof(int) == 0; `radius` via `get<float>`) | ✅ |
| `-[Octree dealloc]` (124) | `~Octree` `Core/Octree.cpp:114` | ✅ |
| `-[Octree hasCollision]` (132) | `hasCollision` `Core/Octree.cpp:116` | ✅ |
| `-[Octree setHasCollision:]` (137) | `setHasCollision` `Core/Octree.cpp:118` | ✅ |
| `-[Octree octreeDetails]` (142) | `octreeDetails` `Core/Octree.cpp:120` (designated-init order follows the reordered struct) | ✅ |
| `-[Octree octreeScaledBy:]` (152) | `octreeScaledBy` `Core/Octree.cpp:127` | ✅ |
| `offsetForOctant` (158) | `Core/Octree.cpp:132` | ✅ |
| `-[Octree drawOctree]` (165) | `drawOctree` `Core/Octree.cpp:140` | ✅ |
| `-[Octree drawOctreeFromLocation:scale:offset:]` (191) | `drawOctreeFromLocation` `Core/Octree.cpp:168` | ✅ |
| `-[Octree drawOctreeCollisions]` (254) | `drawOctreeCollisions` `Core/Octree.cpp:247` | ✅ |
| `-[Octree drawOctreeCollisionFromLocation:scale:offset:]` (269) | `drawOctreeCollisionFromLocation` `Core/Octree.cpp:264` | ✅ |
| `isHitByLineSub` (336) | `Core/Octree.cpp:348` | ✅ |
| `isHitByLine` (347) | static `Core/Octree.cpp:361` (`hit_dist = sqrt(float)` stays float; octant test order unchanged) | ✅ |
| `-[Octree isHitByLine:v1:]` (457) | `Octree::isHitByLine` `Core/Octree.cpp:484` (`memset` → `std::ranges::fill`) | ✅ |
| `isHitByOctree` static C fn (473) (missed by extractor: multi-line signature) | `Core/Octree.cpp:500` | ✅ |
| `-[Octree isHitByOctree:withOrigin:andIJK:]` (597) | `isHitByOctree(Octree*, Vector, Triangle)` `Core/Octree.cpp:641` | ✅ |
| `-[Octree isHitByOctree:withOrigin:andIJK:s1:s2:]` (610) | `isHitByOctree(…, GLfloat, GLfloat)` `Core/Octree.cpp:652` (nil `other` → zeroed details, as nil-messaging gave) | ✅ |
| `-[Octree dictionaryRepresentation]` (626) | `dictionaryRepresentation` `Core/Octree.cpp:670` (`radius` as `singleReal`, i.e. `numberWithFloat:`) | ✅ |
| `volumeOfOctree` (634) | `Core/Octree.cpp:679` | ✅ |
| `-[Octree volume]` (669) | `volume` `Core/Octree.cpp:714` (depth limit 5) | ✅ |
| `randomFullNodeFrom` (683) | `Core/Octree.cpp:727` (`Ranrot() & 7`) | ✅ |
| `-[Octree randomPoint]` (716) | `randomPoint` `Core/Octree.cpp:757` | ✅ |
| `-[Octree totalSize]` (722) | `totalSize` `Core/Octree.cpp:762` | ⚠️ |
| `State` (743) (missed by extractor: `OOINLINE struct …*`) | static member `Core/Octree.cpp:779` | ✅ |
| `SetNode` (750) | static member `Core/Octree.cpp:785` (bound `_capacity` → `_octree.size()`) | ✅ |
| `InsertNode` (760) | static member `Core/Octree.cpp:796` | ✅ |
| `-[OOOctreeBuilder init]` (768) | `OOOctreeBuilder::OOOctreeBuilder` `Core/Octree.cpp:804` | ⚠️ |
| `-[OOOctreeBuilder dealloc]` (788) | `~OOOctreeBuilder` (defaulted) `Core/Octree.cpp:817` | ✅ |
| `-[OOOctreeBuilder buildOctreeWithRadius:]` (795) | `buildOctreeWithRadius` `Core/Octree.cpp:819` (copies `_nodeCount` ints; resets buffer and `_nodeCount`) | ✅ |
| `-[OOOctreeBuilder writeSolid]` (818) | `writeSolid` `Core/Octree.cpp:833` | ✅ |
| `-[OOOctreeBuilder writeEmpty]` (823) | `writeEmpty` `Core/Octree.cpp:835` | ✅ |
| `-[OOOctreeBuilder beginInnerNode]` (828) | `beginInnerNode` `Core/Octree.cpp:837` | ✅ |
| `-[OOOctreeBuilder endInnerNode]` (851) | `endInnerNode` `Core/Octree.cpp:860` (same solid-fold) | ✅ |
| `SetNode_slow` (881) | static member `Core/Octree.cpp:893` (same `MAX(2·cap, 16 Ki, index+1)`) | ⚠️ |
| `-[OOOctreeBuilder suppressClangStuff]` (900) | none: it existed only to silence the Clang static analyser (`#ifndef NDEBUG`) | ➖ |

**Differences:**

- ⚠️ **low** — out-of-memory paths only. Commit 724accb9c moved the collision marks and the builder's node buffer to `std::vector` and documents the change: "Running out of memory now throws std::bad_alloc where these raised OOMallocException". (still open, changed form: at the previous run these raised `OOMallocException`.) In each case the port now throws `std::bad_alloc`:
  - `-initWithData:radius:` returned nil when `calloc` failed (`_collisionOctree.assign`); — upstream `Core/Octree.m:102-106` ↔ port `Core/Octree.cpp:84`
  - `-[OOOctreeBuilder init]` returned nil, so `findOctreeToDepth:` gave a nil octree; — upstream `Core/Octree.m:771-776` ↔ port `Core/Octree.cpp:806`
  - `SetNode_slow` raised `NSMallocException` "Failed to allocate memory for octree." — upstream `Core/Octree.m:886-889` ↔ port `Core/Octree.cpp:899`
- ⚠️ **low** (still open) — `totalSize` (only under `OO_DEBUG_MONITOR_ENABLED`): `_nodeCount * [_data oo_objectSize]` became `_nodeCount * sizeof _data`, and `[self oo_objectSize]` became `sizeof *this`. The code comment states the change. Only debug memory figures differ. — upstream `Core/Octree.m:724` ↔ port `Core/Octree.cpp:762-767`
- ➖ **low** (still open) — `-[Octree init]` raised `NSInternalInconsistencyException`. With no default constructor, the misuse is now a compile error. — upstream `Core/Octree.m:80-85` ↔ port `Core/Octree.cpp:68`
- ✅ note: empty data now gives `_octree = nullptr` explicitly (code comment), so `initWithData` returns null as before. `octreeScaledBy` copies the node data instead of sharing it, which affects memory only. The builder buffer is zero-filled by `resize`, where upstream's `malloc` left it uninitialised; every slot below `_nodeCount` is written before it is read (`endInnerNode` checks only the last eight, all of them written), so the output is unchanged. — port `Core/Octree.cpp:79-84,128,806,825`
- ✅ note: the debug-log formats were converted printf→fmt with the same output (`0x%2x`→`0x{:2x}`, `%.2f`→`{:.2f}`, `%d`→`{}` with `int` casts), and the class is still `octree.debug`. The GL-error context is still `<Octree 0x…>`. — e.g. upstream `Core/Octree.m:397` ↔ port `Core/Octree.cpp:413-417`
- **low** (failure-path text only, still open): `NSAssert`/`NSAssert1`/`NSCAssert` became `OOCAssert`, whose reason names `__PRETTY_FUNCTION__`; in "Unbalanced call to %s", `__FUNCTION__` is now `endInnerNode`. The conditions are unchanged. — upstream `Core/Octree.m:762,797,830,853-854,869` ↔ port `Core/Octree.cpp:797,820,838,861-864,879`

## OOMaths

<a id="oomaths"></a>
Upstream `src/Core/OOMaths.h`, `OOFastArithmetic.h`, `OOVector.h`, `OOHPVector.h`, `OOQuaternion.h`, `OOMatrix.h` (inline functions and macros) ↔ `Core/OOMathsBase.h` (OOMaths.h's body; `Core/OOMaths.h` now only includes the sub-headers), `Core/OOFastArithmetic.h`, `Core/OOVector.h`, `Core/OOHPVector.h`, `Core/OOQuaternion.h`, `Core/OOMatrix.h`

**Status:** done — 95 rows: 93 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| OOMaths.h: `typedef GLfloat OOScalar` / `typedef double OOHPScalar` (49, 51) | `Core/OOMathsBase.h:54, 56` | ✅ |
| OOMaths.h: `M_PI` … `M_SQRT1_2` fallbacks (53-76) | identical `Core/OOMathsBase.h:58-81` | ✅ |
| OOMaths.h: `MIN` / `MAX` / `ABS` macros (78-99) | identical `Core/OOMathsBase.h:83-118` (in game units OOFoundation.h's `MAX` wins; see Differences) | ✅ |
| OOFastArithmetic.h: `OORoundUpToPowerOf2_32()` (41) | `Core/OOFastArithmetic.h:49` | ⚠️ |
| OOFastArithmetic.h: `OORoundUpToPowerOf2_64()` (46) | `Core/OOFastArithmetic.h:55` | ⚠️ |
| OOFastArithmetic.h: `OORoundUpToPowerOf2_NS()` (53/58) | `Core/OOFastArithmetic.h:63/68` (forwards to _64/_32; `NSUInteger` → `std::size_t`) | ✅ |
| OOFastArithmetic.h: `OOClamp_0_1_f()` (65) | `Core/OOFastArithmetic.h:75` (`fmax(0.0f, fmin(v, 1.0f))`, float overloads) | ✅ |
| OOFastArithmetic.h: `OOClamp_n1_1_f()` (70) | `Core/OOFastArithmetic.h:79` | ✅ |
| OOFastArithmetic.h: `OOClamp_0_1_d()` (75) | `Core/OOFastArithmetic.h:83` (same `0.0f`/`1.0f` literals, promoted to double in both) | ✅ |
| OOFastArithmetic.h: `OOClamp_0_max_f()` (80) | `Core/OOFastArithmetic.h:87` | ✅ |
| OOFastArithmetic.h: `OOClamp_0_max_d()` (85) | `Core/OOFastArithmetic.h:91` | ✅ |
| OOFastArithmetic.h: `OOLerp()` (90) | `Core/OOFastArithmetic.h:103` (`v0 + fraction * (v1 - v0)`) | ✅ |
| OOFastArithmetic.h: `OOLerpd()` (96) | `Core/OOFastArithmetic.h:109` | ✅ |
| OOVector.h: `make_vector()` (149) | `Core/OOVector.h:191` | ✅ |
| OOVector.h: `MakeVector2D()` (158) | `Core/OOVector.h:199` | ✅ |
| OOVector.h: `scale_vector()` (166) | `Core/OOVector.h:206` | ✅ |
| OOVector.h: `vector_multiply_scalar()` (180) | `Core/OOVector.h:219` | ✅ |
| OOVector.h: `vector_add()` (195) | `Core/OOVector.h:233` | ✅ |
| OOVector.h: `OOVectorInterpolate()` (204) | `Core/OOVector.h:241` | ✅ |
| OOVector.h: `OOVectorTowards()` (211) | `Core/OOVector.h:246` | ✅ |
| OOVector.h: `vector_subtract()` (218) | `Core/OOVector.h:250` | ✅ |
| OOVector.h: `vector_flip()` (227) | `Core/OOVector.h:258` | ✅ |
| OOVector.h: `vector_equal()` (232) | `Core/OOVector.h:262` | ✅ |
| OOVector.h: `magnitude2()` (237) | `Core/OOVector.h:266` | ✅ |
| OOVector.h: `magnitude()` (242) | `Core/OOVector.h:270` (`sqrt(float)` → float overload) | ✅ |
| OOVector.h: `vector_normal_or_fallback()` (247) | `Core/OOVector.h:272` | ✅ |
| OOVector.h: `vector_normal_or_xbasis()` (255) | `Core/OOVector.h:278` | ✅ |
| OOVector.h: `vector_normal_or_ybasis()` (260) | `Core/OOVector.h:282` | ✅ |
| OOVector.h: `vector_normal_or_zbasis()` (265) | `Core/OOVector.h:286` | ✅ |
| OOVector.h: `vector_normal()` (270) | `Core/OOVector.h:290` | ✅ |
| OOVector.h: `distance2()` (275) | `Core/OOVector.h:294` | ✅ |
| OOVector.h: `distance()` (280) | `Core/OOVector.h:298` | ✅ |
| OOVector.h: `true_cross_product()` (285) | `Core/OOVector.h:302` | ✅ |
| OOVector.h: `cross_product()` (294) | `Core/OOVector.h:310` | ✅ |
| OOVector.h: `dot_product()` (299) | `Core/OOVector.h:314` | ✅ |
| OOVector.h: `triple_product()` (304) | `Core/OOVector.h:318` | ✅ |
| OOVector.h: `normal_to_surface()` (309) | `Core/OOVector.h:322` | ✅ |
| OOVector.h: GL macros `GLVertexOOVector`, `GLTranslateOOVector` (136-145) | identical `Core/OOVector.h:178-187` | ✅ |
| OOHPVector.h: `make_HPvector()` (149) | `Core/OOHPVector.h:192` | ✅ |
| OOHPVector.h: `MakeHPVector2D()` (158) | `Core/OOHPVector.h:200` | ✅ |
| OOHPVector.h: `vectorToHPVector()` (166) | `Core/OOHPVector.h:207` (C casts → `static_cast`) | ✅ |
| OOHPVector.h: `HPVectorToVector()` (175) | `Core/OOHPVector.h:215` (C casts → `static_cast`) | ✅ |
| OOHPVector.h: `HPscale_vector()` (184) | `Core/OOHPVector.h:223` | ✅ |
| OOHPVector.h: `HPvector_multiply_scalar()` (198) | `Core/OOHPVector.h:236` | ✅ |
| OOHPVector.h: `HPvector_add()` (213) | `Core/OOHPVector.h:250` | ✅ |
| OOHPVector.h: `OOHPVectorInterpolate()` (222) | `Core/OOHPVector.h:258` | ✅ |
| OOHPVector.h: `OOHPVectorTowards()` (229) | `Core/OOHPVector.h:264` | ✅ |
| OOHPVector.h: `HPvector_subtract()` (236) | `Core/OOHPVector.h:268` | ✅ |
| OOHPVector.h: `HPvector_flip()` (245) | `Core/OOHPVector.h:276` | ✅ |
| OOHPVector.h: `HPvector_equal()` (250) | `Core/OOHPVector.h:280` | ✅ |
| OOHPVector.h: `HPmagnitude2()` (255) | `Core/OOHPVector.h:284` | ✅ |
| OOHPVector.h: `HPmagnitude()` (260) | `Core/OOHPVector.h:288` | ✅ |
| OOHPVector.h: `HPvector_normal_or_fallback()` (265) | `Core/OOHPVector.h:292` | ✅ |
| OOHPVector.h: `HPvector_normal_or_xbasis()` (273) | `Core/OOHPVector.h:298` | ✅ |
| OOHPVector.h: `HPvector_normal_or_ybasis()` (278) | `Core/OOHPVector.h:302` | ✅ |
| OOHPVector.h: `HPvector_normal_or_zbasis()` (283) | `Core/OOHPVector.h:306` | ✅ |
| OOHPVector.h: `HPvector_normal()` (288) | `Core/OOHPVector.h:310` | ✅ |
| OOHPVector.h: `HPdistance2()` (293) | `Core/OOHPVector.h:314` | ✅ |
| OOHPVector.h: `HPdistance()` (298) | `Core/OOHPVector.h:318` | ✅ |
| OOHPVector.h: `HPtrue_cross_product()` (303) | `Core/OOHPVector.h:322` | ✅ |
| OOHPVector.h: `HPcross_product()` (312) | `Core/OOHPVector.h:330` | ✅ |
| OOHPVector.h: `HPdot_product()` (317) | `Core/OOHPVector.h:334` | ✅ |
| OOHPVector.h: `HPtriple_product()` (322) | `Core/OOHPVector.h:338` | ✅ |
| OOHPVector.h: `HPnormal_to_surface()` (327) | `Core/OOHPVector.h:343` | ✅ |
| OOQuaternion.h: `make_quaternion()` (96) | `Core/OOQuaternion.h:130` | ✅ |
| OOQuaternion.h: `quaternion_equal()` (106) | `Core/OOQuaternion.h:140` | ✅ |
| OOQuaternion.h: `quaternion_negate()` (111) | `Core/OOQuaternion.h:144` | ✅ |
| OOQuaternion.h: `quaternion_conjugate()` (116) | `Core/OOQuaternion.h:148` | ✅ |
| OOQuaternion.h: `quaternion_set_rotate_about_axis()` (121) | `Core/OOQuaternion.h:152` (`angle * 0.5f`, `sin`/`cos` float overloads) | ✅ |
| OOQuaternion.h: `quaternion_dot_product()` (132) | `Core/OOQuaternion.h:163` | ✅ |
| OOQuaternion.h: `quaternion_normalize()` (137) | `Core/OOQuaternion.h:167` (`1.0f / sqrt(float)`) | ✅ |
| OOQuaternion.h: `OORandomQuaternion()` (152) | `Core/OOQuaternion.h:181` | ✅ |
| OOMatrix.h: `OOMatrixConstruct()` (158) | `Core/OOMatrix.h:204` | ✅ |
| OOMatrix.h: `OOMatrixFromOrientationAndPosition()` (170) | `Core/OOMatrix.h:215` | ✅ |
| OOMatrix.h: `OOMatrixFromBasisVectorsAndPosition()` (176) | `Core/OOMatrix.h:221` | ✅ |
| OOMatrix.h: `OOMatrixFromBasisVectors()` (185) | `Core/OOMatrix.h:227` | ✅ |
| OOMatrix.h: `OOMatrixForTranslationComponents()` (232) | `Core/OOMatrix.h:258` | ✅ |
| OOMatrix.h: `OOMatrixForTranslation()` (241) | `Core/OOMatrix.h:263` | ✅ |
| OOMatrix.h: `OOMatrixTranslateComponents()` (246) | `Core/OOMatrix.h:267` | ✅ |
| OOMatrix.h: `OOMatrixTranslate()` (254) | `Core/OOMatrix.h:275` | ✅ |
| OOMatrix.h: `OOMatrixHPTranslate()` (259) | `Core/OOMatrix.h:279` (`(OOScalar)` → `static_cast<OOScalar>` on each component) | ✅ |
| OOMatrix.h: `OOMatrixForScale()` (264) | `Core/OOMatrix.h:285` | ✅ |
| OOMatrix.h: `OOMatrixForScaleUniform()` (273) | `Core/OOMatrix.h:289` | ✅ |
| OOMatrix.h: `OOMatrixScale()` (278) | `Core/OOMatrix.h:293` | ✅ |
| OOMatrix.h: `OOMatrixScaleUniform()` (283) | `Core/OOMatrix.h:298` | ✅ |
| OOMatrix.h: `OOMatrixRotateX()` (288) | `Core/OOMatrix.h:302` | ✅ |
| OOMatrix.h: `OOMatrixRotateY()` (293) | `Core/OOMatrix.h:306` | ✅ |
| OOMatrix.h: `OOMatrixRotateZ()` (298) | `Core/OOMatrix.h:310` | ✅ |
| OOMatrix.h: `OOMatrixRotate()` (303) | `Core/OOMatrix.h:314` (calls `OOMatrixForRotation`, with its shared upstream typo; see OOMatrix) | ✅ |
| OOMatrix.h: `OOMatrixRotateQuaternion()` (308) | `Core/OOMatrix.h:318` | ✅ |
| OOMatrix.h: `OOMatrixIsIdentity()` (313) | `Core/OOMatrix.h:322` | ✅ |
| OOMatrix.h: `OOMatrixGetBasisVectors()` (318) | `Core/OOMatrix.h:326` | ✅ |
| OOMatrix.h: `OOMatrixTranspose()` (327) | `Core/OOMatrix.h:335` | ✅ |
| OOMatrix.h: `OOMatrixLoadGLMatrix()` (336) | `Core/OOMatrix.h:342` | ✅ |
| OOMatrix.h: GL macros `OOMatrixValuesForOpenGL`, `GLMultOOMatrix`, `GLLoadOOMatrix`, `GL*TransposeOOMatrix`, `GLUniformMatrix` (92-118) | `Core/OOMatrix.h:118-143` (`GLUniformMatrix` transpose flag `NO` → `false`, both 0) | ✅ |

**Differences:**

- ⚠️ **low** (still open) — `OORoundUpToPowerOf2_32/_64`: upstream evaluated `__builtin_clz(0)` for input 1, and shifted by −1 for input 0 and for inputs above the high bit, which is undefined behaviour. The port pins those cases to what the optimised x86-64 build returned: 1→2, and 0 or above the high bit→1. The code comment states this. The bead id oo-lglaq cited at the previous run is no longer in the comment, which commit 6ae90bb08 ("Make comments describe the code") rewrote. — upstream `Core/OOFastArithmetic.h:41-49` ↔ port `Core/OOFastArithmetic.h:43-59`
- ✅ note: I compared every header inline body above with whitespace and comments stripped. Apart from C casts → `static_cast`, `NO` → `false` in `GLUniformMatrix`, and the guards (`#pragma once`, `#ifndef OO_PLAIN_CPP_UNIT` around the `std::string` description declarations), they are token-identical.
- ✅ note: the headers are now compiled as C++ under `<tgmath.h>` (`Core/OOMathsBase.h:31`). I re-ran on this commit: `clang++ -std=gnu++20 -fsyntax-only` with the port's include paths, plain unit (`OO_PLAIN_CPP_UNIT`) and game unit. It confirmed with `static_assert` that `sin`, `cos`, `sqrt`, `acos`, `asin`, `atan2`, `fabs`, `fmax` and `fmin` on `float` return `float`, and `asin(1)` returns `double`, as tgmath gave upstream.
- ✅ note: `MAX` tie/NaN order. In game units, `Core/OOMathsBase.h` includes `OOFoundation.h` first, so its `MAX` (`__a > __b ? __a : __b`, `Core/OOFoundation.h:96-103`) wins. That is the gnustep-base form that upstream ObjC units got. The plain units (OOMatrix.cpp, OOQuaternion.cpp, OOVoxel.cpp) use none of `MIN`/`MAX`/`ABS`.
- note: `OOClampInteger()` (`Core/OOFastArithmetic.h:95-101`) is port-only; it is not upstream maths. `OOMaths.h` was split into `OOMathsBase.h` plus an umbrella, which has no runtime effect.

