# Parity findings: Maths, geometry, collision

Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

Each section: method coverage table (every upstream method / C function → C++ counterpart → verdict), then differences with `upstream:line` ↔ `oolite-dev:line`, severity and intent.

Method used for every section: `diff -w` of upstream `.m`/`.h` against the port `.cpp`/`.h`, then reading every hunk and its surrounding body. Functions with no hunk have textually identical bodies.
Cross-cutting check (applies to all sections): the C maths that was compiled as C/Objective-C under `<tgmath.h>` is now compiled as C++ (OOMatrix.cpp and OOQuaternion.cpp as plain `OO_PLAIN_CPP_UNIT` units, the header inlines in every game unit). I verified with `clang++ -std=gnu++20 -fsyntax-only` and the port's include paths (ucrt64 clang, libstdc++) that unqualified `cos`, `sin`, `acos`, `atan2`, `sqrt`, `fabs` and `fmax` on `float` arguments resolve to the `float` overloads (`static_assert` on `decltype`), in both plain and game units. So single-precision maths stays single-precision, as tgmath made it upstream. No `abs()`, `floor`, `round`, `pow`, `exp` or `log` call exists in these files, so C's int `abs(float)` trap cannot occur. OOVoxel.c is still compiled as C.


## OOMaths (headers)

<a id="oomaths"></a>
Upstream `src/Core/OOMaths.h`, `src/Core/OOFastArithmetic.h` ↔ `Core/OOMaths.h`, `Core/OOFastArithmetic.h`

**Status:** done — 13 rows: 11 ✅ 2 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `typedef GLfloat OOScalar` / `typedef double OOHPScalar` (OOMaths.h:49, 51) | same (`float` when `!OOMATHS_OPENGL_INTEGRATION`; the game build has it on) `Core/OOMaths.h:68-74` | ✅ |
| `M_PI` … `M_SQRT1_2` fallbacks (OOMaths.h:53-76) | identical `Core/OOMaths.h:76-99` | ✅ |
| `MIN` / `MAX` / `ABS` macros (OOMaths.h:78-99) | identical `Core/OOMaths.h:101-122` (see Differences for which `MAX` wins) | ✅ |
| `OOClamp_0_1_f()` (OOFastArithmetic.h:65) | `Core/OOFastArithmetic.h:77` | ✅ |
| `OOClamp_n1_1_f()` (70) | `Core/OOFastArithmetic.h:82` | ✅ |
| `OOClamp_0_1_d()` (75) | `Core/OOFastArithmetic.h:87` (same `0.0f`/`1.0f` literals, promoted to double) | ✅ |
| `OOClamp_0_max_f()` (80) | `Core/OOFastArithmetic.h:92` | ✅ |
| `OOClamp_0_max_d()` (85) | `Core/OOFastArithmetic.h:97` | ✅ |
| `OOLerp()` (90) | `Core/OOFastArithmetic.h:109`, same `v0 + fraction * (v1 - v0)` operand order | ✅ |
| `OOLerpd()` (96) | `Core/OOFastArithmetic.h:115` | ✅ |
| `OORoundUpToPowerOf2_32()` (41) | `Core/OOFastArithmetic.h:47` | ⚠️ |
| `OORoundUpToPowerOf2_64()` (46) | `Core/OOFastArithmetic.h:55` | ⚠️ |
| `OORoundUpToPowerOf2_NS()` (53/58) | `Core/OOFastArithmetic.h:65/70` (forwards to _64/_32) | ✅ |

**Differences:**

- ⚠️ **low**: `OORoundUpToPowerOf2_32/_64`. Upstream evaluated `__builtin_clz(0)` for input 1 and shifted by −1 for input 0 and for inputs above the high bit, which is undefined behaviour. The port pins those results to what the optimised x86-64 build returned: 1→2, and 0 or above the high bit→1. The old comment said those cases return 0. Bead oo-lglaq, as the code comment says. — upstream `Core/OOFastArithmetic.h:41-49` ↔ port `Core/OOFastArithmetic.h:42-61`
- ✅ note: `MAX` tie/NaN order. In game units, port OOMaths.h includes `OOFoundation.h` first, so its `MAX` (`__a > __b ? __a : __b`, `Core/OOFoundation.h:137`) wins. That is the same form as gnustep-base's `GSConfig.h:386`, which upstream ObjC units got through `<Foundation/Foundation.h>`. NaN and ±0 tie-breaking is therefore unchanged. The plain units (OOMatrix.cpp, OOQuaternion.cpp, OOVoxel.c) would get OOMaths' `<` form, but none of them uses `MIN`/`MAX`/`ABS`.
- note: the port adds `OOClampInteger()` (`Core/OOFastArithmetic.h:102-107`), moved from the retired collection extractors (oo-snzn). It is not upstream maths.
- note: the include order changed (OOFastArithmetic → OOVector → OOHPVector → OOQuaternion → OOMatrix → OOVoxel/OOTriangle/OOBoundingBox/legacy_random), and the sub-headers now `#error` if included directly. This has no runtime effect.


## CollisionRegion

<a id="collisionregion"></a>
Upstream `src/Core/CollisionRegion.m` ↔ `Core/CollisionRegion.cpp`

**Status:** done — 20 rows: 19 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[CollisionRegion init]` (46) | `CollisionRegion::CollisionRegion()` `Core/CollisionRegion.cpp:68` | ⚠️ |
| `-[CollisionRegion initAsUniverse]` (61) | `CollisionRegion(AsUniverse)` `Core/CollisionRegion.cpp:83` | ✅ |
| `-[CollisionRegion initAtLocation:withRadius:withinRegion:]` (69) | `CollisionRegion(HPVector, GLfloat, CollisionRegion*)` `Core/CollisionRegion.cpp:91` | ✅ |
| `-[CollisionRegion dealloc]` (80) | `~CollisionRegion` `Core/CollisionRegion.cpp:102` | ✅ |
| `-[CollisionRegion description]` (88) | `descriptionComponents` `Core/CollisionRegion.cpp:110` (wrapped as `<CollisionRegion 0x…>{…}`) | ✅ |
| `-[CollisionRegion clearSubregions]` (93) | `clearSubregions` `Core/CollisionRegion.cpp:115` | ✅ |
| `-[CollisionRegion addSubregionAtPosition:withRadius:]` (99) | `addSubregionAtPosition` `Core/CollisionRegion.cpp:122` | ✅ |
| `positionIsWithinRegion()` (126) | static member `Core/CollisionRegion.cpp:147` | ✅ |
| `sphereIsWithinRegion()` (143) | static member `Core/CollisionRegion.cpp:164` | ✅ |
| `positionIsWithinBorders()` (160) | static member `Core/CollisionRegion.cpp:181` | ✅ |
| `-[CollisionRegion clearEntityList]` (179) | `clearEntityList` `Core/CollisionRegion.cpp:200` | ✅ |
| `-[CollisionRegion addEntity:]` (186) | `addEntity` `Core/CollisionRegion.cpp:208` | ✅ |
| `-[CollisionRegion checkEntity:]` (205) | `checkEntity` `Core/CollisionRegion.cpp:227` | ✅ |
| `-[CollisionRegion findCollisions]` (226) | `findCollisions` `Core/CollisionRegion.cpp:247` | ✅ |
| `entityByEntityOcclusionToValue()` (377) | anon-namespace fn `Core/CollisionRegion.cpp:410` | ✅ |
| `shadowAtPointOcclusionToValue()` (387) | `Core/CollisionRegion.cpp:422` | ✅ |
| `testEntityOccludedByEntity()` (496) | anon-namespace inline `Core/CollisionRegion.cpp:533` | ✅ |
| `-[CollisionRegion findShadowedEntities]` (502) | `findShadowedEntities` `Core/CollisionRegion.cpp:541` | ✅ |
| `-[CollisionRegion collisionDescription]` (618) | `collisionDescription` `Core/CollisionRegion.cpp:657` | ✅ |
| `-[CollisionRegion debugOut]` (623) | `debugOut` `Core/CollisionRegion.cpp:662` | ✅ |

**Differences:**

- ⚠️ **low**: when the `entity_array` malloc fails, `-init` released itself and returned nil. The constructor instead raises `OOMallocException` ("Not enough memory to create collision region member list."), per ADR-0056 amendment oo-44gg as the code comment cites. This only happens on OOM. — upstream `Core/CollisionRegion.m:50-54` ↔ port `Core/CollisionRegion.cpp:72-76`
- ✅ note: in `findCollisions`, `[se shipIsInDockingCorridor:(ShipEntity*)e2]` with a non-ship `e2` became `se->shipIsInDockingCorridor(oo::ToShip(e2))`, which passes nullptr. Both return NO: upstream through `[ship isShip]` (`Entities/StationEntity.m:702`), the port through the null check (`Entities/StationEntity.cpp:1566`). — upstream `Core/CollisionRegion.m:316-337` ↔ port `Core/CollisionRegion.cpp:341-366`
- ✅ note: `[e collisionArray]` became `getCollidingEntities()`. That is always non-null (`Entities/Entity.cpp:890`), as upstream's `collidingEntities` was always allocated (`Entities/Entity.m:78`), so add/remove still always happen. The `e->collider` vs other choice and the add order are unchanged.
- note: the variable-length arrays `entities_to_test[n]`, `planets[n]` and `ships[n]` are now `std::vector`. The debug log `%@ self` is rebuilt as the same `<CollisionRegion 0x…>{ID: …}` text. Both are cosmetic or performance-only.


## OOHPVector

<a id="oohpvector"></a>
Upstream `src/Core/OOHPVector.m` (+ `.h` inlines) ↔ `Core/OOHPVector.cpp` (+ `Core/OOHPVector.h`)

**Status:** done — 36 rows: 36 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `kZeroHPVector`, `kBasis{X,Y,Z}HPVector`, `kZeroHPVector2D`, `kBasis{X,Y}HPVector2D` (27-34) | `Core/OOHPVector.cpp:30-37` | ✅ |
| `HPVectorDescription()` (37) | `cxx_HPVectorDescription` `Core/OOHPVector.cpp:39` (same `"(%g, %g, %g)"`) | ✅ |
| `ArrayFromHPVector()` (42) | `cxx_ArrayFromHPVector` `Core/OOHPVector.cpp:44` (`std::vector<double>{x,y,z}`) | ✅ |
| `OORandomUnitHPVector()` (62) | `Core/OOHPVector.cpp:60` | ✅ |
| `OOHPVectorRandomSpatial()` (75) | `Core/OOHPVector.cpp:76` | ✅ |
| `OOHPVectorRandomRadial()` (88) | `Core/OOHPVector.cpp:92` | ✅ |
| `OOHPRandomPositionInBoundingBox()` (93) | `Core/OOHPVector.cpp:99` | ✅ |
| `OORandomPositionInCylinder()` (102) | `Core/OOHPVector.cpp:108` | ✅ |
| `OORandomPositionInShell()` (116) | `Core/OOHPVector.cpp:124` | ✅ |
| `OOProjectHPVectorToPlane()` (126) | `Core/OOHPVector.cpp:134` | ✅ |
| h: `make_HPvector()` (149) | `Core/OOHPVector.h:158` | ✅ |
| h: `MakeHPVector2D()` (158) | `Core/OOHPVector.h:167` | ✅ |
| h: `vectorToHPVector()` (166) | `Core/OOHPVector.h:175` | ✅ |
| h: `HPVectorToVector()` (175) | `Core/OOHPVector.h:184` | ✅ |
| h: `HPscale_vector()` (184) | `Core/OOHPVector.h:193` | ✅ |
| h: `HPvector_multiply_scalar()` (198) | `Core/OOHPVector.h:207` | ✅ |
| h: `HPvector_add()` (213) | `Core/OOHPVector.h:222` | ✅ |
| h: `OOHPVectorInterpolate()` (222) | `Core/OOHPVector.h:231` | ✅ |
| h: `OOHPVectorTowards()` (229) | `Core/OOHPVector.h:238` | ✅ |
| h: `HPvector_subtract()` (236) | `Core/OOHPVector.h:245` | ✅ |
| h: `HPvector_flip()` (245) | `Core/OOHPVector.h:254` | ✅ |
| h: `HPvector_equal()` (250) | `Core/OOHPVector.h:259` | ✅ |
| h: `HPmagnitude2()` (255) | `Core/OOHPVector.h:264` | ✅ |
| h: `HPmagnitude()` (260) | `Core/OOHPVector.h:269` | ✅ |
| h: `HPvector_normal_or_fallback()` (265) | `Core/OOHPVector.h:274` | ✅ |
| h: `HPvector_normal_or_xbasis()` (273) | `Core/OOHPVector.h:282` | ✅ |
| h: `HPvector_normal_or_ybasis()` (278) | `Core/OOHPVector.h:287` | ✅ |
| h: `HPvector_normal_or_zbasis()` (283) | `Core/OOHPVector.h:292` | ✅ |
| h: `HPvector_normal()` (288) | `Core/OOHPVector.h:297` | ✅ |
| h: `HPdistance2()` (293) | `Core/OOHPVector.h:302` | ✅ |
| h: `HPdistance()` (298) | `Core/OOHPVector.h:307` | ✅ |
| h: `HPtrue_cross_product()` (303) | `Core/OOHPVector.h:312` | ✅ |
| h: `HPcross_product()` (312) | `Core/OOHPVector.h:321` | ✅ |
| h: `HPdot_product()` (317) | `Core/OOHPVector.h:326` | ✅ |
| h: `HPtriple_product()` (322) | `Core/OOHPVector.h:331` | ✅ |
| h: `HPnormal_to_surface()` (327) | `Core/OOHPVector.h:336` | ✅ |

**Differences:**

- ✅ note: header inline bodies are textually identical (`diff -w`). Only include guards and `#if !OOMATHS_STANDALONE` / `OOMATHS_OPENGL_INTEGRATION` wrappers were added, and both are on in the game build.
- ✅ note: random draws that were nested in one call are now one per line, per ADR-0063 item 5. They keep the left-to-right argument order clang gave upstream (x, y, z; then direction before length; interpolation before offset). A GCC-built upstream, which evaluates right to left, would have consumed `randf()` in a different order. — upstream `Core/OOHPVector.m:68,81,90,111` ↔ port `Core/OOHPVector.cpp:66-69,82-85,94-96,117-119`
- note: `HPVectorDescription`/`ArrayFromHPVector` were renamed `cxx_*` and now return `std::string` / `std::vector<double>`. The caller builds the plist (`Entities/PlayerEntity.cpp:1366`). Log `%f`→`{:f}` gives the same 6-decimal fixed output, and the message class `position.cylinder.error` is unchanged (`Core/OOHPVector.cpp:113`).


## OOMatrix

<a id="oomatrix"></a>
Upstream `src/Core/OOMatrix.m` (+ `.h` inlines) ↔ `Core/OOMatrix.cpp` (+ `Core/OOMatrix.h`)

**Status:** done — 44 rows: 44 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `kIdentityMatrix`, `kZeroMatrix` (28, 33) | `Core/OOMatrix.cpp:35, 40` | ✅ |
| `OOMatrixForRotation()` (40) | `Core/OOMatrix.cpp:47` | ✅ |
| `OOMatrixForQuaternionRotation()` (56) | `Core/OOMatrix.cpp:63` | ✅ |
| `OOMatrixEqual()` (91) | `Core/OOMatrix.cpp:98` | ✅ |
| `OOMatrixMultiply()` (105) | `Core/OOMatrix.cpp:112` | ✅ |
| `OOVectorMultiplyMatrix()` (121) | `Core/OOMatrix.cpp:128` | ✅ |
| `OOHPVectorMultiplyMatrix()` (137) | `Core/OOMatrix.cpp:144` | ✅ |
| `OOMatrixOrthogonalize()` (150) | `Core/OOMatrix.cpp:157` | ✅ |
| `OOMatrixDescription()` (176) | `Core/OOMatrix.cpp:183` (`std::string`, same format) | ✅ |
| `OOMatrixForBillboard()` (186) | `Core/OOMatrix.cpp:193` | ✅ |
| `OOMatrixRowSwap()` (207) | `Core/OOMatrix.cpp:214` | ✅ |
| `OOMatrixRowScale()` (222) | `Core/OOMatrix.cpp:229` | ✅ |
| `OOMatrixRowOperation()` (234) | `Core/OOMatrix.cpp:241` | ✅ |
| `OOMatrixColumnSwap()` (246) | `Core/OOMatrix.cpp:253` | ✅ |
| `OOMatrixColumnScale()` (261) | `Core/OOMatrix.cpp:268` | ✅ |
| `OOMatrixColumnOperation()` (273) | `Core/OOMatrix.cpp:280` | ✅ |
| `OOMatrixLeftTransform()` (285) | `Core/OOMatrix.cpp:292` | ✅ |
| `OOMatrixRightTransform()` (320) | `Core/OOMatrix.cpp:327` | ✅ |
| `OOMatrixInverse()` (359) | `Core/OOMatrix.cpp:366` | ✅ |
| `OOMatrixInverseWithDeterminant()` (364) | `Core/OOMatrix.cpp:371` | ✅ |
| `GLUniformMatrix3()` (411) | `Core/OOMatrix.cpp:420` | ✅ |
| h: `OOMatrixConstruct()` (158) | `Core/OOMatrix.h:166` | ✅ |
| h: `OOMatrixFromOrientationAndPosition()` (170) | `Core/OOMatrix.h:178` | ✅ |
| h: `OOMatrixFromBasisVectorsAndPosition()` (176) | `Core/OOMatrix.h:184` | ✅ |
| h: `OOMatrixFromBasisVectors()` (185) | `Core/OOMatrix.h:193` | ✅ |
| h: `OOMatrixForTranslationComponents()` (232) | `Core/OOMatrix.h:240` | ✅ |
| h: `OOMatrixForTranslation()` (241) | `Core/OOMatrix.h:249` | ✅ |
| h: `OOMatrixTranslateComponents()` (246) | `Core/OOMatrix.h:254` | ✅ |
| h: `OOMatrixTranslate()` (254) | `Core/OOMatrix.h:262` | ✅ |
| h: `OOMatrixHPTranslate()` (259) | `Core/OOMatrix.h:267` | ✅ |
| h: `OOMatrixForScale()` (264) | `Core/OOMatrix.h:272` | ✅ |
| h: `OOMatrixForScaleUniform()` (273) | `Core/OOMatrix.h:281` | ✅ |
| h: `OOMatrixScale()` (278) | `Core/OOMatrix.h:286` | ✅ |
| h: `OOMatrixScaleUniform()` (283) | `Core/OOMatrix.h:291` | ✅ |
| h: `OOMatrixRotateX()` (288) | `Core/OOMatrix.h:296` | ✅ |
| h: `OOMatrixRotateY()` (293) | `Core/OOMatrix.h:301` | ✅ |
| h: `OOMatrixRotateZ()` (298) | `Core/OOMatrix.h:306` | ✅ |
| h: `OOMatrixRotate()` (303) | `Core/OOMatrix.h:311` | ✅ |
| h: `OOMatrixRotateQuaternion()` (308) | `Core/OOMatrix.h:316` | ✅ |
| h: `OOMatrixIsIdentity()` (313) | `Core/OOMatrix.h:321` | ✅ |
| h: `OOMatrixGetBasisVectors()` (318) | `Core/OOMatrix.h:326` | ✅ |
| h: `OOMatrixTranspose()` (327) | `Core/OOMatrix.h:335` | ✅ |
| h: `OOMatrixLoadGLMatrix()` (336) | `Core/OOMatrix.h:345` | ✅ |
| h: GL macros `OOMatrixValuesForOpenGL`, `GLMultOOMatrix`, `GLLoadOOMatrix`, `GL*TransposeOOMatrix`, `GLUniformMatrix` (90-119) | identical `Core/OOMatrix.h:92-122` | ✅ |

**Differences:**

- ✅ note: the function bodies are textually identical (`diff -w`), including every constant, operand order and loop order. The only code change is in `GLUniformMatrix3`, where the transpose flag `NO` became `GL_FALSE` (both 0). — upstream `Core/OOMatrix.m:423` ↔ port `Core/OOMatrix.cpp:432`
- ✅ note: OOMatrix.cpp is now a plain C++ unit (`OO_PLAIN_CPP_UNIT`). Its `cos`/`sin`/`sqrt` calls on `OOScalar` resolve to the float overloads (see the cross-cutting check at the top), so precision is unchanged.
- note (build-level, not source): the port pins `-ffp-contract=off` for every unit (`meson.build:79`, decision 11). Clang's default is `on`, but the x86-64 baseline target has no FMA instructions, so no fusion happens in either build. The pin only matters if a build enables FMA.


## OOMeshToOctreeConverter

<a id="oomeshtooctreeconverter"></a>
Upstream `src/Core/OOMeshToOctreeConverter.m` ↔ `Core/OOMeshToOctreeConverter.cpp`

**Status:** done — 19 rows: 19 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `kOOMeshToOctreeConverterSmallDataCapacity = 16` (h:34) | `Core/OOMeshToOctreeConverter.h:42` | ✅ |
| `InitGeometryData()` (181) | `Core/OOMeshToOctreeConverter.cpp:185` | ✅ |
| `DestroyGeometryData()` (191) | `Core/OOMeshToOctreeConverter.cpp:195` | ✅ |
| `AddTriangle()` (210) | `Core/OOMeshToOctreeConverter.cpp:214` | ✅ |
| `-[OOMeshToOctreeConverter initWithCapacity:]` (223) | ctor `Core/OOMeshToOctreeConverter.cpp:225` | ✅ |
| `-[OOMeshToOctreeConverter dealloc]` (236) | dtor `Core/OOMeshToOctreeConverter.cpp:236` | ✅ |
| `+[OOMeshToOctreeConverter converterWithCapacity:]` (243) | `converterWithCapacity` `Core/OOMeshToOctreeConverter.cpp:241` | ✅ |
| `-[OOMeshToOctreeConverter descriptionComponents]` (248) | `descriptionComponents` `Core/OOMeshToOctreeConverter.cpp:246` | ✅ |
| `-[OOMeshToOctreeConverter addTriangle:]` (253) | `addTriangle` `Core/OOMeshToOctreeConverter.cpp:251` | ✅ |
| `-[OOMeshToOctreeConverter findOctreeToDepth:]` (260) | `findOctreeToDepth` `Core/OOMeshToOctreeConverter.cpp:258` | ✅ |
| `MaxDimensionFromOrigin()` (272) | `Core/OOMeshToOctreeConverter.cpp:268` | ✅ |
| `BuildSubOctree()` (289) | `Core/OOMeshToOctreeConverter.cpp:285` | ✅ |
| `TranslateGeometryX()` (414) | `Core/OOMeshToOctreeConverter.cpp:410` | ✅ |
| `TranslateGeometryY()` (428) | `Core/OOMeshToOctreeConverter.cpp:424` | ✅ |
| `TranslateGeometryZ()` (442) | `Core/OOMeshToOctreeConverter.cpp:438` | ✅ |
| `SplitGeometryX()` (456) | `Core/OOMeshToOctreeConverter.cpp:452` | ✅ |
| `SplitGeometryY()` (565) | `Core/OOMeshToOctreeConverter.cpp:561` | ✅ |
| `SplitGeometryZ()` (676) | `Core/OOMeshToOctreeConverter.cpp:672` | ✅ |
| `AddTriangle_slow()` (802) | `Core/OOMeshToOctreeConverter.cpp:798` | ✅ |

**Differences:**

- ✅ note: the geometry split, translate and build bodies are textually identical (`diff -w`). Only `[builder …]` became `builder->…`.
- note: in `AddTriangle_slow`, `MAX(pendingCapacity, kSmall * 2)` now has the enum operand cast to `uint32_t`. The result type is unchanged, since the comparison was already unsigned. The log class `kOOLogAllocationFailure` became the literal `"general.error.allocationFailure"`, which is the same string (`Core/OOLogging.m:598`). — upstream `Core/OOMeshToOctreeConverter.m:808,820` ↔ port `Core/OOMeshToOctreeConverter.cpp:804,816`
- **low** (failure-path text only): `NSParameterAssert` in `-initWithCapacity:` became `OOCParameterAssert`. On failure the reason names `__PRETTY_FUNCTION__` instead of "OOMeshToOctreeConverter(instance), method initWithCapacity:". The trigger condition is unchanged. — upstream `Core/OOMeshToOctreeConverter.m:225` ↔ port `Core/OOMeshToOctreeConverter.cpp:227`


## OOQuaternion

<a id="ooquaternion"></a>
Upstream `src/Core/OOQuaternion.m` (+ `.h` inlines) ↔ `Core/OOQuaternion.cpp` (+ `Core/OOQuaternion.h`)

**Status:** done — 26 rows: 26 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `kIdentityQuaternion`, `kZeroQuaternion` (27-28) | `Core/OOQuaternion.cpp:29-30` | ✅ |
| `quaternion_multiply()` (30) | `Core/OOQuaternion.cpp:32` | ✅ |
| `quaternion_set_random()` (41) | `Core/OOQuaternion.cpp:44` | ✅ |
| `vector_forward_from_quaternion()` (50) | `Core/OOQuaternion.cpp:54` | ✅ |
| `HPvector_forward_from_quaternion()` (83) | `Core/OOQuaternion.cpp:87` | ✅ |
| `vector_up_from_quaternion()` (89) | `Core/OOQuaternion.cpp:93` | ✅ |
| `vector_right_from_quaternion()` (122) | `Core/OOQuaternion.cpp:126` | ✅ |
| `basis_vectors_from_quaternion()` (154) | `Core/OOQuaternion.cpp:158` | ✅ |
| `quaternion_rotation_between()` (213) | `Core/OOQuaternion.cpp:217` | ✅ |
| `quaternion_rotation_betweenHP()` (237) | `Core/OOQuaternion.cpp:241` | ✅ |
| `quaternion_limited_rotation_between()` (261) | `Core/OOQuaternion.cpp:265` | ✅ |
| `quaternion_rotate_about_x()` (291) | `Core/OOQuaternion.cpp:295` | ✅ |
| `quaternion_rotate_about_y()` (309) | `Core/OOQuaternion.cpp:313` | ✅ |
| `quaternion_rotate_about_z()` (327) | `Core/OOQuaternion.cpp:331` | ✅ |
| `quaternion_rotate_about_axis()` (345) | `Core/OOQuaternion.cpp:349` | ✅ |
| `QuaternionDescription()` (361) | `Core/OOQuaternion.cpp:365` (`std::string`, same `"(%g %c %gi %c %gj %c %gk)"`) | ✅ |
| `quaternion_rotate_vector()` (378) | `Core/OOQuaternion.cpp:382` | ✅ |
| `quaternion_rotate_HPvector()` (394) | `Core/OOQuaternion.cpp:398` | ✅ |
| h: `make_quaternion()` (96) | `Core/OOQuaternion.h:106` | ✅ |
| h: `quaternion_equal()` (106) | `Core/OOQuaternion.h:116` | ✅ |
| h: `quaternion_negate()` (111) | `Core/OOQuaternion.h:121` | ✅ |
| h: `quaternion_conjugate()` (116) | `Core/OOQuaternion.h:126` | ✅ |
| h: `quaternion_set_rotate_about_axis()` (121) | `Core/OOQuaternion.h:131` | ✅ |
| h: `quaternion_dot_product()` (132) | `Core/OOQuaternion.h:142` | ✅ |
| h: `quaternion_normalize()` (137) | `Core/OOQuaternion.h:147` | ✅ |
| h: `OORandomQuaternion()` (152) | `Core/OOQuaternion.h:163` | ✅ |

**Differences:**

- ✅ note: the `.m` and the `.h` inlines are textually identical (`diff -w`), including epsilons, the `quaternion_limited_rotation_between` arc clamp, and operand order. The `.cpp` is a plain C++ unit (`OO_PLAIN_CPP_UNIT`). The float overload resolution of `sqrt`/`acos`/`sin`/`cos` was verified (see top).


## OOSpatialReference

<a id="oospatialreference"></a>
Upstream `src/Core/OOSpatialReference.m` ↔ *(absorbed: no same-named file; the only method lives on `Entity`)*

**Status:** done — 3 rows: 1 ✅ 0 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `@protocol OOSpatialReference` `-transformationMatrix` (h:34-38) | none: the protocol is gone, and nothing upstream referenced it outside its own `.h`/`.m` | ➖ |
| `@interface Entity (OOSpatialReference)` (h:40-41; `.m` only `#import`s the header, no `@implementation`) | none (empty category) | ➖ |
| `-[Entity transformationMatrix]` (`Entities/Entity.m:813`), the method the protocol named | `Entity::transformationMatrix` `Core/Entities/Entity.cpp:858` (same `OOMatrixHPTranslate(rotMatrix, position)`) | ✅ |

**Differences:**

- ➖ **low**: the formal protocol and its empty category are dropped. There is no behaviour: the upstream `.m` is just an `#import`. A source search found no upstream conformance checks or callers. — upstream `Core/OOSpatialReference.h:34-41` ↔ port (none)


## OOVector

<a id="oovector"></a>
Upstream `src/Core/OOVector.m` (+ `.h` inlines) ↔ `Core/OOVector.cpp` (+ `Core/OOVector.h`)

**Status:** done — 33 rows: 33 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `kZeroVector`, `kBasis{X,Y,Z}Vector`, `kZeroVector2D`, `kBasis{X,Y}Vector2D`, `kZeroBoundingBox` (27-36) | `Core/OOVector.cpp:29-39` | ✅ |
| `VectorDescription()` (39) | `Core/OOVector.cpp:42` (same `"(%g, %g, %g)"`) | ✅ |
| `-[OONativeVector initWithVector:]` (46) | `OONativeVector::OONativeVector` `Core/OOVector.cpp:47` | ✅ |
| `-[OONativeVector getVector]` (57) | `OONativeVector::getVector` `Core/OOVector.cpp:52` | ✅ |
| `OORandomUnitVector()` (76) | `Core/OOVector.cpp:78` | ✅ |
| `OOVectorRandomSpatial()` (89) | `Core/OOVector.cpp:94` | ✅ |
| `OOVectorRandomRadial()` (102) | `Core/OOVector.cpp:110` | ✅ |
| `OORandomPositionInBoundingBox()` (107) | `Core/OOVector.cpp:117` | ✅ |
| h: `make_vector()` (149) | `Core/OOVector.h:169` | ✅ |
| h: `MakeVector2D()` (158) | `Core/OOVector.h:178` | ✅ |
| h: `scale_vector()` (166) | `Core/OOVector.h:186` | ✅ |
| h: `vector_multiply_scalar()` (180) | `Core/OOVector.h:200` | ✅ |
| h: `vector_add()` (195) | `Core/OOVector.h:215` | ✅ |
| h: `OOVectorInterpolate()` (204) | `Core/OOVector.h:224` | ✅ |
| h: `OOVectorTowards()` (211) | `Core/OOVector.h:231` | ✅ |
| h: `vector_subtract()` (218) | `Core/OOVector.h:238` | ✅ |
| h: `vector_flip()` (227) | `Core/OOVector.h:247` | ✅ |
| h: `vector_equal()` (232) | `Core/OOVector.h:252` | ✅ |
| h: `magnitude2()` (237) | `Core/OOVector.h:257` | ✅ |
| h: `magnitude()` (242) | `Core/OOVector.h:262` | ✅ |
| h: `vector_normal_or_fallback()` (247) | `Core/OOVector.h:267` | ✅ |
| h: `vector_normal_or_xbasis()` (255) | `Core/OOVector.h:275` | ✅ |
| h: `vector_normal_or_ybasis()` (260) | `Core/OOVector.h:280` | ✅ |
| h: `vector_normal_or_zbasis()` (265) | `Core/OOVector.h:285` | ✅ |
| h: `vector_normal()` (270) | `Core/OOVector.h:290` | ✅ |
| h: `distance2()` (275) | `Core/OOVector.h:295` | ✅ |
| h: `distance()` (280) | `Core/OOVector.h:300` | ✅ |
| h: `true_cross_product()` (285) | `Core/OOVector.h:305` | ✅ |
| h: `cross_product()` (294) | `Core/OOVector.h:314` | ✅ |
| h: `dot_product()` (299) | `Core/OOVector.h:319` | ✅ |
| h: `triple_product()` (304) | `Core/OOVector.h:324` | ✅ |
| h: `normal_to_surface()` (309) | `Core/OOVector.h:329` | ✅ |
| h: GL macros `GLVertexOOVector`, `GLTranslateOOVector` (134-145) | identical `Core/OOVector.h:153-165` | ✅ |

**Differences:**

- I deleted a false row: `OORandomPositionInShell()` (130) is inside a `/* … */` comment upstream, and in the port too.
- ✅ note: random draws now go on separate lines, per ADR-0063 item 5. They keep clang's left-to-right order (x, y, z; direction before length). — upstream `Core/OOVector.m:82,95,104` ↔ port `Core/OOVector.cpp:84-87,100-103,112-114`
- note: `OONativeVector` is now an `oo::PListForeign` (bead oo-9ht.5) instead of an NSObject. `description()` gives `<OONativeVector 0x…>`, the same as the NSObject default `<%@ %p>` (`Core/OOFoundation.m:50`). The added `className()` (`Core/OOVector.cpp:57`) is only used for writer errors.


## OOVoxel

<a id="oovoxel"></a>
Upstream `src/Core/OOVoxel.m` ↔ `Core/OOVoxel.c`

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `checkFace()` (29) | `Core/OOVoxel.c:29` | ✅ |
| `checkBevel()` (47) | `Core/OOVoxel.c:47` | ✅ |
| `checkCorner()` (78) | `Core/OOVoxel.c:78` | ✅ |
| `lineIntersectionWithFace()` (101) | `Core/OOVoxel.c:101` | ✅ |
| `checkPoint()` (135) | `Core/OOVoxel.c:135` | ✅ |
| `checkLine()` (144) | `Core/OOVoxel.c:144` | ✅ |
| `lineCubeIntersection()` (164) | `Core/OOVoxel.c:164` | ✅ |

**Differences:**

- ✅ verbatim (ADR-0012, C stays C): `diff -w` shows only line 25, `#import "OOMaths.h"` → `#include`. The header only gains the include guard. The file is still compiled as C, so tgmath semantics are unchanged.


## Octree

<a id="octree"></a>
Upstream `src/Core/Octree.m` ↔ `Core/Octree.cpp`

**Status:** done — 38 rows: 34 ✅ 2 ⚠️ 0 ❌ 2 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OctreeDebugLog` macro / `Octree_details` struct (36, 47-52) | `Core/Octree.cpp:37, 48-52` | ✅ |
| `-[Octree init]` (80) | none: no default constructor | ➖ |
| `-[Octree initWithData:]` (89) | `Octree::Octree` + `Octree::initWithData` `Core/Octree.cpp:64, 82` | ✅ |
| `-[Octree initWithDictionary:]` (112) | `Octree::initWithDictionary` `Core/Octree.cpp:92` | ✅ |
| `-[Octree dealloc]` (124) | `~Octree` `Core/Octree.cpp:104` | ✅ |
| `-[Octree hasCollision]` (132) | `hasCollision` `Core/Octree.cpp:110` | ✅ |
| `-[Octree setHasCollision:]` (137) | `setHasCollision` `Core/Octree.cpp:115` | ✅ |
| `-[Octree octreeDetails]` (142) | `octreeDetails` `Core/Octree.cpp:120` | ✅ |
| `-[Octree octreeScaledBy:]` (152) | `octreeScaledBy` `Core/Octree.cpp:130` | ✅ |
| `offsetForOctant()` (158) | `Core/Octree.cpp:136` | ✅ |
| `-[Octree drawOctree]` (165) | `drawOctree` `Core/Octree.cpp:143` | ✅ |
| `-[Octree drawOctreeFromLocation:scale:offset:]` (191) | `drawOctreeFromLocation` `Core/Octree.cpp:169` | ✅ |
| `-[Octree drawOctreeCollisions]` (254) | `drawOctreeCollisions` `Core/Octree.cpp:232` | ✅ |
| `-[Octree drawOctreeCollisionFromLocation:scale:offset:]` (269) | `drawOctreeCollisionFromLocation` `Core/Octree.cpp:247` | ✅ |
| `isHitByLineSub()` (336) | `Core/Octree.cpp:314` | ✅ |
| `isHitByLine()` (347) | `Core/Octree.cpp:325` | ✅ |
| `-[Octree isHitByLine:v1:]` (457) | `Octree::isHitByLine` `Core/Octree.cpp:433` | ✅ |
| `isHitByOctree()` static C fn (473) | `Core/Octree.cpp:449` | ✅ |
| `-[Octree isHitByOctree:withOrigin:andIJK:]` (597) | `isHitByOctree(Octree*, Vector, Triangle)` `Core/Octree.cpp:573` | ✅ |
| `-[Octree isHitByOctree:withOrigin:andIJK:s1:s2:]` (610) | `isHitByOctree(…, GLfloat, GLfloat)` `Core/Octree.cpp:586` | ✅ |
| `-[Octree dictionaryRepresentation]` (626) | `dictionaryRepresentation` `Core/Octree.cpp:603` | ✅ |
| `volumeOfOctree()` (634) | `Core/Octree.cpp:612` | ✅ |
| `-[Octree volume]` (669) | `volume` `Core/Octree.cpp:647` | ✅ |
| `randomFullNodeFrom()` (683) | `Core/Octree.cpp:661` | ✅ |
| `-[Octree randomPoint]` (716) | `randomPoint` `Core/Octree.cpp:694` | ✅ |
| `-[Octree totalSize]` (722) | `totalSize` `Core/Octree.cpp:700` | ⚠️ |
| `State()` (743) | static member `Core/Octree.cpp:719` | ✅ |
| `SetNode()` (750) | static member `Core/Octree.cpp:725` | ✅ |
| `InsertNode()` (760) | static member `Core/Octree.cpp:735` | ✅ |
| `-[OOOctreeBuilder init]` (768) | `OOOctreeBuilder::OOOctreeBuilder` `Core/Octree.cpp:743` | ⚠️ |
| `-[OOOctreeBuilder dealloc]` (788) | `~OOOctreeBuilder` `Core/Octree.cpp:763` | ✅ |
| `-[OOOctreeBuilder buildOctreeWithRadius:]` (795) | `buildOctreeWithRadius` `Core/Octree.cpp:768` | ✅ |
| `-[OOOctreeBuilder writeSolid]` (818) | `writeSolid` `Core/Octree.cpp:790` | ✅ |
| `-[OOOctreeBuilder writeEmpty]` (823) | `writeEmpty` `Core/Octree.cpp:795` | ✅ |
| `-[OOOctreeBuilder beginInnerNode]` (828) | `beginInnerNode` `Core/Octree.cpp:800` | ✅ |
| `-[OOOctreeBuilder endInnerNode]` (851) | `endInnerNode` `Core/Octree.cpp:823` | ✅ |
| `SetNode_slow()` (881) | static member `Core/Octree.cpp:853` | ✅ |
| `-[OOOctreeBuilder suppressClangStuff]` (900) | none: it existed only to silence the Clang static analyser (`#ifndef NDEBUG`) | ➖ |

**Differences:**

- ⚠️ **low**: `totalSize` (only under `OO_DEBUG_MONITOR_ENABLED`). Upstream summed `_nodeCount * [_data oo_objectSize]`, the NSData instance size; the port uses `_nodeCount * sizeof _data`, and `sizeof *this` replaces `[self oo_objectSize]`. The port comment states the change. Only debug memory-usage figures differ. — upstream `Core/Octree.m:724` ↔ port `Core/Octree.cpp:702-704`
- ⚠️ **low**: when the builder's malloc fails, `-[OOOctreeBuilder init]` returned nil, and `findOctreeToDepth:` then messaged nil and got a nil octree. The constructor instead raises `OOMallocException` "Failed to allocate memory for octree." (ADR-0056 amendment oo-44gg, cited in code). This only happens on OOM. — upstream `Core/Octree.m:773-776` ↔ port `Core/Octree.cpp:748-752`
- ➖ **low**: `-[Octree init]` raised `NSInternalInconsistencyException` at runtime. The port has no default constructor, so the misuse is now a compile error. — upstream `Core/Octree.m:80-85` ↔ port `Core/Octree.cpp:62`
- ✅ note: in `isHitByOctree:…s1:s2:`, a nil `other` gave zeroed `Octree_details` through nil-messaging. The port builds `Octree_details { }` explicitly and skips `setHasCollision`, which was a nil no-op upstream. — upstream `Core/Octree.m:613,621` ↔ port `Core/Octree.cpp:589,597-598`
- ✅ note: empty data now gives `_octree = NULL` explicitly, so `initWithData` returns null as before. `octreeScaledBy` copies the node data instead of sharing it (memory only). `initWithDictionary` reads `radius` with `get<float>`, which has the same `oo_floatForKey:` conversions and 0 default (`oofnd/PListGet.hpp:586`). — upstream `Core/Octree.m:100,155,121` ↔ port `Core/Octree.cpp:75,133,101`
- ✅ note: debug-log format strings are converted printf→fmt with the same output (`0x%2x`→`0x{:2x}`, `%.2f`→`{:.2f}`, `%d`→`{}` with `int` casts). The GL-error context text is still `<Octree 0x…>`. — e.g. upstream `Core/Octree.m:397` ↔ port `Core/Octree.cpp:374`
- **low** (failure-path text only): the method-form `NSAssert`/`NSAssert1` in `OOOctreeBuilder` became `OOCAssert`. On failure the reason names `__PRETTY_FUNCTION__`, and `__FUNCTION__` in "Unbalanced call to %s" now gives `endInnerNode` instead of `-[OOOctreeBuilder endInnerNode]`. The conditions are unchanged. — upstream `Core/Octree.m:797,830,853-854,869` ↔ port `Core/Octree.cpp:770,802,825-826,841`
