# Parity findings: graphics
Legend: ✅ equivalent · ⚠️ intentional divergence · ❌ suspected behaviour difference · ➖ removed/replaced.

## OOBasicMaterial

<a id="oobasicmaterial"></a>
Upstream `src/Core/Materials/OOBasicMaterial.m` ↔ `Core/Materials/OOBasicMaterial.cpp` (314 / 282 lines)

**Status:** done — 33 rows: 32 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOBasicMaterial initWithName:]` (41) | `OOBasicMaterial::initWithName` `Core/Materials/OOBasicMaterial.cpp:66` | ✅ white diffuse/ambient, spec/emission alpha 1 |
| `-[OOBasicMaterial initWithName:configuration:]` (57) | `OOBasicMaterial::initWithName(name, configuration)` `Core/Materials/OOBasicMaterial.cpp:75` | ✅ same order: diffuse, ambient (else diffuse), emission, exponent≠0 && permitSpecular → shininess + specular |
| `-[OOBasicMaterial dealloc]` (94) | implicit destructor | ⚠️ no `willDealloc` call (see Differences) |
| `-[OOBasicMaterial name]` (102) | `OOBasicMaterial::name` `Core/Materials/OOBasicMaterial.cpp:110` | ✅ |
| `-[OOBasicMaterial doApply]` (107) | `OOBasicMaterial::doApply` `Core/Materials/OOBasicMaterial.cpp:112` | ✅ `isMemberOfClass` → `typeid ==` |
| `-[OOBasicMaterial unapplyWithNext:]` (121) | `OOBasicMaterial::unapplyWithNext` `Core/Materials/OOBasicMaterial.cpp:126` | ✅ `isKindOfClass` → `dynamic_cast`; null next applies default |
| `-[OOBasicMaterial diffuseColor]` (130) | `OOBasicMaterial::diffuseColor` `Core/Materials/OOBasicMaterial.cpp:141` | ✅ |
| `-[OOBasicMaterial setDiffuseColor:]` (138) | `OOBasicMaterial::setDiffuseColor` `Core/Materials/OOBasicMaterial.cpp:145` | ✅ |
| `-[OOBasicMaterial setAmbientAndDiffuseColor:]` (148) | `OOBasicMaterial::setAmbientAndDiffuseColor` `Core/Materials/OOBasicMaterial.cpp:152` | ✅ |
| `-[OOBasicMaterial specularColor]` (154) | `OOBasicMaterial::specularColor` `Core/Materials/OOBasicMaterial.cpp:157` | ✅ |
| `-[OOBasicMaterial setSpecularColor:]` (162) | `OOBasicMaterial::setSpecularColor` `Core/Materials/OOBasicMaterial.cpp:162` | ✅ |
| `-[OOBasicMaterial ambientColor]` (172) | `OOBasicMaterial::ambientColor` `Core/Materials/OOBasicMaterial.cpp:169` | ✅ |
| `-[OOBasicMaterial setAmbientColor:]` (180) | `OOBasicMaterial::setAmbientColor` `Core/Materials/OOBasicMaterial.cpp:173` | ✅ |
| `-[OOBasicMaterial emmisionColor]` (190) | `OOBasicMaterial::emmisionColor` `Core/Materials/OOBasicMaterial.cpp:180` | ✅ |
| `-[OOBasicMaterial setEmissionColor:]` (198) | `OOBasicMaterial::setEmissionColor` `Core/Materials/OOBasicMaterial.cpp:185` | ✅ |
| `-[OOBasicMaterial getDiffuseComponents:]` (208) | `OOBasicMaterial::getDiffuseComponents` `Core/Materials/OOBasicMaterial.cpp:192` | ✅ |
| `-[OOBasicMaterial setDiffuseComponents:]` (213) | `OOBasicMaterial::setDiffuseComponents` `Core/Materials/OOBasicMaterial.cpp:196` | ✅ |
| `-[OOBasicMaterial setAmbientAndDiffuseComponents:]` (218) | `OOBasicMaterial::setAmbientAndDiffuseComponents` `Core/Materials/OOBasicMaterial.cpp:200` | ✅ |
| `-[OOBasicMaterial getSpecularComponents:]` (224) | `OOBasicMaterial::getSpecularComponents` `Core/Materials/OOBasicMaterial.cpp:206` | ✅ |
| `-[OOBasicMaterial setSpecularComponents:]` (229) | `OOBasicMaterial::setSpecularComponents` `Core/Materials/OOBasicMaterial.cpp:210` | ✅ |
| `-[OOBasicMaterial getAmbientComponents:]` (234) | `OOBasicMaterial::getAmbientComponents` `Core/Materials/OOBasicMaterial.cpp:214` | ✅ |
| `-[OOBasicMaterial setAmbientComponents:]` (239) | `OOBasicMaterial::setAmbientComponents` `Core/Materials/OOBasicMaterial.cpp:218` | ✅ |
| `-[OOBasicMaterial getEmissionComponents:]` (244) | `OOBasicMaterial::getEmissionComponents` `Core/Materials/OOBasicMaterial.cpp:222` | ✅ |
| `-[OOBasicMaterial setEmissionComponents:]` (249) | `OOBasicMaterial::setEmissionComponents` `Core/Materials/OOBasicMaterial.cpp:226` | ✅ |
| `-[OOBasicMaterial setDiffuseRed:green:blue:alpha:]` (254) | `OOBasicMaterial::setDiffuseRed` `Core/Materials/OOBasicMaterial.cpp:230` | ✅ |
| `-[OOBasicMaterial setAmbientAndDiffuseRed:green:blue:alpha:]` (262) | `OOBasicMaterial::setAmbientAndDiffuseRed` `Core/Materials/OOBasicMaterial.cpp:238` | ✅ |
| `-[OOBasicMaterial setSpecularRed:green:blue:alpha:]` (268) | `OOBasicMaterial::setSpecularRed` `Core/Materials/OOBasicMaterial.cpp:244` | ✅ |
| `-[OOBasicMaterial setAmbientRed:green:blue:alpha:]` (276) | `OOBasicMaterial::setAmbientRed` `Core/Materials/OOBasicMaterial.cpp:252` | ✅ |
| `-[OOBasicMaterial setEmissionRed:green:blue:alpha:]` (284) | `OOBasicMaterial::setEmissionRed` `Core/Materials/OOBasicMaterial.cpp:260` | ✅ |
| `-[OOBasicMaterial shininess]` (292) | `OOBasicMaterial::shininess` `Core/Materials/OOBasicMaterial.cpp:268` | ✅ |
| `-[OOBasicMaterial setShininess:]` (297) | `OOBasicMaterial::setShininess` `Core/Materials/OOBasicMaterial.cpp:270` | ✅ MIN 128 on uint8_t |
| `-[OOBasicMaterial permitSpecular]` (302) | `OOBasicMaterial::permitSpecular` `Core/Materials/OOBasicMaterial.cpp:274` | ✅ nil UNIVERSE → permit, as nil message |
| `-[OOBasicMaterial allTextures]` (308) | `OOBasicMaterial::allTextures` `Core/Materials/OOBasicMaterial.cpp:279` | ✅ empty set → empty vector |

**Differences:**

- ⚠️ **low** — `-dealloc`'s `[super willDealloc]` has no counterpart: the current-material slot holds a `std::shared_ptr`, so a material can't be destroyed while current. Justified in the comment at `Core/Materials/OOMaterial.h:126-131` (the earlier ADR-0056 citation is gone from the header) (still open) — upstream `Core/Materials/OOBasicMaterial.m:94-100` ↔ port `Core/Materials/OOMaterial.h:132`
- Subtle (✅): the colour helpers now return `std::shared_ptr<OOColor>` directly instead of a description fed to `+colorWithDescription:`; the null check and the ambient-falls-back-to-diffuse order are unchanged. The default material is a never-freed heap `shared_ptr` (T090), as the never-released static was — port `Core/Materials/OOBasicMaterial.cpp:88-107,129-136`

## OOCombinedEmissionMapGenerator

<a id="oocombinedemissionmapgenerator"></a>
Upstream `src/Core/Materials/OOCombinedEmissionMapGenerator.m` ↔ `Core/Materials/OOCombinedEmissionMapGenerator.cpp` (446 / 431 lines)

**Status:** done — 13 rows: 12 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOCombinedEmissionMapGenerator initWithEmissionMapSpec:emissionColor:diffuseMap:diffuseColor:illuminationMapSpec:illuminationColor:optionsSpecifier:]` (59) | `OOCombinedEmissionMapGenerator::generatorWithEmissionMapSpec` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:87` | ✅ isCombinedMap false |
| `-[OOCombinedEmissionMapGenerator initWithEmissionAndIlluminationMapSpec:diffuseMap:diffuseColor:emissionColor:illuminationColor:optionsSpecifier:]` (77) | `OOCombinedEmissionMapGenerator::generatorWithEmissionAndIlluminationMapSpec` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:102` | ✅ null illumination spec, combined true |
| `-[OOCombinedEmissionMapGenerator initWithEmissionMapSpec:emissionColor:diffuseMap:diffuseColor:illuminationMapSpec:illuminationColor:isCombinedMap:optionsSpecifier:]` (94) | `OOCombinedEmissionMapGenerator::initWithEmissionMapSpec` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:116` | ✅ colour modulate, white→nil, diffuse dropped w/o illumination, extra_shrink, cache check, loader reads |
| `-[OOCombinedEmissionMapGenerator constructCacheKey]` (193) | `OOCombinedEmissionMapGenerator::constructCacheKey` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:218` | ❌ `(null)` diffuse key text |
| `-[OOCombinedEmissionMapGenerator dealloc]` (232) | `~OOCombinedEmissionMapGenerator` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:265` | ✅ |
| `-[OOCombinedEmissionMapGenerator descriptionComponents]` (254) | `OOCombinedEmissionMapGenerator::descriptionComponents` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:273` | ✅ same pieces/order; nil desc ↔ empty string |
| `-[OOCombinedEmissionMapGenerator textureOptions]` (294) | `OOCombinedEmissionMapGenerator::textureOptions` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:314` | ✅ |
| `-[OOCombinedEmissionMapGenerator anisotropy]` (299) | `OOCombinedEmissionMapGenerator::anisotropy` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:318` | ✅ |
| `-[OOCombinedEmissionMapGenerator lodBias]` (304) | `OOCombinedEmissionMapGenerator::lodBias` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:320` | ✅ |
| `-[OOCombinedEmissionMapGenerator cacheKey]` (309) | `OOCombinedEmissionMapGenerator::cacheKey` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:322` | ✅ |
| `-[OOCombinedEmissionMapGenerator loadTexture]` (314) | `OOCombinedEmissionMapGenerator::loadTexture` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:326` | ✅ same pixmap op sequence; result buffer handed over via `OOPixMapOwnedBuffer` |
| `ModulateColor` (414) | `ModulateColor` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:53` | ✅ |
| `ScaleToMatch` (433) | `ScaleToMatch` `Core/Materials/OOCombinedEmissionMapGenerator.cpp:69` | ✅ |

**Differences:**

- ❌ **low** — with a nil `_diffuseMap`, upstream formats `[_diffuseMap cacheKey]` as `(null)` (`…*{(null)}`); the port writes `""` (`…*{}`). Only the cache-key text changes (still open) — upstream `Core/Materials/OOCombinedEmissionMapGenerator.m:223` ↔ port `Core/Materials/OOCombinedEmissionMapGenerator.cpp:249-251`
- Subtle (✅): the result handover changed with T017 (OOPixelBuffer): `_data = OOPixMapOwnedBuffer(_emissionPx)` then `OOFreePixMap`, instead of stealing `pixels` and nulling it. After `OOCompactPixMap` the shared buffer is returned without a copy, so the bytes and the `_data == nullptr` error path are the same — port `Core/Materials/OOCombinedEmissionMapGenerator.cpp:417-430`
- Subtle (✅): `SpecWithExtraShrink` only adds `extra_shrink` to a dictionary spec (upstream would have thrown on a non-dictionary `mutableCopy`); nil loaders are now guarded explicitly — port `Core/Materials/OOCombinedEmissionMapGenerator.cpp:44-51,186-209`

## OOConcreteTexture

<a id="ooconcretetexture"></a>
Upstream `src/Core/Materials/OOConcreteTexture.m` ↔ `Core/Materials/OOConcreteTexture.cpp` (641 / 639 lines)

**Status:** done — 26 rows: 26 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOConcreteTexture initWithLoader:key:options:anisotropy:lodBias:]` (71) | `OOConcreteTexture::initWithLoader` `Core/Materials/OOConcreteTexture.cpp:97` (+ ctor `:73`) | ✅ nil loader → nil; `OOClamp_0_1_f(aniso) * anisotropyScale`; addToCaches |
| `-[OOConcreteTexture initWithPath:key:options:anisotropy:lodBias:]` (109) | `OOConcreteTexture::initWithPath` `Core/Materials/OOConcreteTexture.cpp:113` | ✅ |
| `-[OOConcreteTexture dealloc]` (130) | `~OOConcreteTexture` `Core/Materials/OOConcreteTexture.cpp:133` | ✅ same log classes; GL delete; uncache |
| `-[OOConcreteTexture descriptionComponents]` (165) | `OOConcreteTexture::descriptionComponents` `Core/Materials/OOConcreteTexture.cpp:166` | ✅ `%u x %u` / LOAD ERROR / loading |
| `-[OOConcreteTexture shortDescriptionComponents]` (182) | `OOConcreteTexture::shortDescriptionComponents` `Core/Materials/OOConcreteTexture.cpp:183` | ✅ |
| `-[OOConcreteTexture name]` (188) | `OOConcreteTexture::name` `Core/Materials/OOConcreteTexture.cpp:189` | ✅ channel suffixes; nil path → nil |
| `-[OOConcreteTexture apply]` (225) | `OOConcreteTexture::apply` `Core/Materials/OOConcreteTexture.cpp:233` | ✅ |
| `-[OOConcreteTexture ensureFinishedLoading]` (242) | `OOConcreteTexture::ensureFinishedLoading` `Core/Materials/OOConcreteTexture.cpp:250` | ✅ |
| `-[OOConcreteTexture isFinishedLoading]` (248) | `OOConcreteTexture::isFinishedLoading` `Core/Materials/OOConcreteTexture.cpp:254` | ✅ |
| `-[OOConcreteTexture cacheKey]` (253) | `OOConcreteTexture::cacheKey` `Core/Materials/OOConcreteTexture.cpp:259` | ✅ |
| `-[OOConcreteTexture dimensions]` (258) | `OOConcreteTexture::dimensions` `Core/Materials/OOConcreteTexture.cpp:261` | ✅ |
| `-[OOConcreteTexture originalDimensions]` (265) | `OOConcreteTexture::originalDimensions` `Core/Materials/OOConcreteTexture.cpp:267` | ✅ |
| `-[OOConcreteTexture isMipMapped]` (272) | `OOConcreteTexture::isMipMapped` `Core/Materials/OOConcreteTexture.cpp:273` | ✅ |
| `-[OOConcreteTexture copyPixMapRepresentation]` (279) | `OOConcreteTexture::copyPixMapRepresentation` `Core/Materials/OOConcreteTexture.cpp:279` | ✅ duplicate of own bytes, else GL readback (2D / 6 cube faces) |
| `-[OOConcreteTexture isRectangleTexture]` (328) | `OOConcreteTexture::isRectangleTexture` `Core/Materials/OOConcreteTexture.cpp:325` | ✅ |
| `-[OOConcreteTexture isCubeMap]` (337) | `OOConcreteTexture::isCubeMap` `Core/Materials/OOConcreteTexture.cpp:333` | ✅ |
| `-[OOConcreteTexture texCoordsScale]` (346) | `OOConcreteTexture::texCoordsScale` `Core/Materials/OOConcreteTexture.cpp:341` | ✅ |
| `-[OOConcreteTexture glTextureName]` (370) | `OOConcreteTexture::glTextureName` `Core/Materials/OOConcreteTexture.cpp:365` | ✅ |
| `-[OOConcreteTexture(Private) setUpTexture]` (381) | `OOConcreteTexture::setUpTexture` `Core/Materials/OOConcreteTexture.cpp:373` | ✅ cube-map test `h == w*6`; failure path same |
| `-[OOConcreteTexture(Private) uploadTexture]` (418) | `OOConcreteTexture::uploadTexture` `Core/Materials/OOConcreteTexture.cpp:415` | ✅ wrap/filter/anisotropy (`1.0 < aniso`) and `texture.upload` text same |
| `-[OOConcreteTexture(Private) uploadTextureDataWithMipMap:format:]` (499) | `OOConcreteTexture::uploadTextureDataWithMipMap` `Core/Materials/OOConcreteTexture.cpp:502` | ✅ |
| `-[OOConcreteTexture(Private) uploadTextureCubeMapDataWithMipMap:format:]` (528) | `OOConcreteTexture::uploadTextureCubeMapDataWithMipMap` `Core/Materials/OOConcreteTexture.cpp:530` | ✅ side stride `*4/3` rounded to 16 |
| `-[OOConcreteTexture(Private) glTextureTarget]` (562) | `OOConcreteTexture::glTextureTarget` `Core/Materials/OOConcreteTexture.cpp:565` | ✅ |
| `-[OOConcreteTexture(Private) forceRebind]` (573) | `OOConcreteTexture::forceRebind` `Core/Materials/OOConcreteTexture.cpp:575` | ✅ |
| `-[OOConcreteTexture(Private) isReloadable]` (600) | `OOConcreteTexture::isReloadable` `Core/Materials/OOConcreteTexture.cpp:599` | ✅ |
| `DecodeFormat` (609) | `DecodeFormat` `Core/Materials/OOConcreteTexture.cpp:603` | ✅ |

**Differences:**

- Subtle (✅, new): `_bytes` is now an `OOPixelBuffer` taken with `OOPixMapOwnedBuffer(pm)` (T017); `free(_bytes)` became `_bytes = nullptr`. Upload pointers come from `_bytes->data()`. Byte layout and the reloadable-texture drop after upload are unchanged — port `Core/Materials/OOConcreteTexture.cpp:381,496,506-507,548-549`
- Subtle (✅ low): under `OO_DEBUG_MONITOR_ENABLED` the generator name is `"<" + className() + ">"`, and the dealloc log prints `oo::str::pointerDescription(this)` where upstream used `%p` — port `Core/Materials/OOConcreteTexture.cpp:89-91,136-138`

## OODefaultShaderSynthesizer

<a id="oodefaultshadersynthesizer"></a>
Upstream `src/Core/Materials/OODefaultShaderSynthesizer.m` ↔ `Core/Materials/OODefaultShaderSynthesizer.cpp` (1451 / 1391 lines)

**Status:** done — 47 rows: 46 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOSynthesizeMaterialShader` (264) | `OOSynthesizeMaterialShader` `Core/Materials/OODefaultShaderSynthesizer.cpp:89` | ✅ returns true even on failure (upstream quirk); outputs cleared |
| `-[OODefaultShaderSynthesizer initWithMaterialConfiguration:materialKey:entityName:]` (301) | `OODefaultShaderSynthesizer` ctor `Core/Materials/OODefaultShaderSynthesizer.cpp:122` | ✅ `_entityName` stays nil (upstream self-copy bug kept) |
| `-[OODefaultShaderSynthesizer dealloc]` (314) | implicit destructor (comment `:132-134`) | ✅ |
| `-[OODefaultShaderSynthesizer vertexShader]` (327) | `vertexShader` `Core/Materials/OODefaultShaderSynthesizer.cpp:136` | ✅ |
| `-[OODefaultShaderSynthesizer fragmentShader]` (332) | `fragmentShader` `Core/Materials/OODefaultShaderSynthesizer.cpp:138` | ✅ |
| `-[OODefaultShaderSynthesizer textureSpecifications]` (337) | `textureSpecifications` `Core/Materials/OODefaultShaderSynthesizer.cpp:142` | ✅ |
| `-[OODefaultShaderSynthesizer uniformSpecifications]` (346) | `uniformSpecifications` `Core/Materials/OODefaultShaderSynthesizer.cpp:146` | ✅ |
| `-[OODefaultShaderSynthesizer run]` (355) | `run` `Core/Materials/OODefaultShaderSynthesizer.cpp:150` | ✅ `@finally` → `oo::Finally`; catches game exceptions only |
| `-[OODefaultShaderSynthesizer materialKey]` (379) | `materialKey` `Core/Materials/OODefaultShaderSynthesizer.cpp:174` | ✅ |
| `-[OODefaultShaderSynthesizer entityName]` (384) | `entityName` `Core/Materials/OODefaultShaderSynthesizer.cpp:178` | ✅ |
| `AppendIfNotEmpty` (391) | `AppendIfNotEmpty` `Core/Materials/OODefaultShaderSynthesizer.cpp:186` | ✅ |
| `GetExtractMode` (402) | `GetExtractMode` `Core/Materials/OODefaultShaderSynthesizer.cpp:207` | ✅ 1-4 chars of `rgba` |
| `-[OODefaultShaderSynthesizer appendVariable:ofType:withPrefix:to:]` (424) | `appendVariable` `Core/Materials/OODefaultShaderSynthesizer.cpp:236` | ✅ `(23-len)/4` tabs |
| `-[OODefaultShaderSynthesizer addAttribute:ofType:]` (431) | `addAttribute` `Core/Materials/OODefaultShaderSynthesizer.cpp:245` | ✅ |
| `-[OODefaultShaderSynthesizer addVarying:ofType:]` (436) | `addVarying` `Core/Materials/OODefaultShaderSynthesizer.cpp:250` | ✅ |
| `-[OODefaultShaderSynthesizer addVertexUniform:ofType:]` (441) | `addVertexUniform` `Core/Materials/OODefaultShaderSynthesizer.cpp:255` | ✅ |
| `-[OODefaultShaderSynthesizer addFragmentUniform:ofType:]` (446) | `addFragmentUniform` `Core/Materials/OODefaultShaderSynthesizer.cpp:260` | ✅ |
| `-[OODefaultShaderSynthesizer defineBindingUniform:ofType:]` (451) | `defineBindingUniform` `Core/Materials/OODefaultShaderSynthesizer.cpp:265` | ✅ `u` + capitalised name, numeric suffix from 2 |
| `-[OODefaultShaderSynthesizer composeVertexShader]` (484) | `composeVertexShader` `Core/Materials/OODefaultShaderSynthesizer.cpp:303` | ✅ |
| `-[OODefaultShaderSynthesizer composeFragmentShader]` (505) | `composeFragmentShader` `Core/Materials/OODefaultShaderSynthesizer.cpp:319` | ✅ |
| `KeyFromTextureParameters` (537) | `KeyFromTextureParameters` `Core/Materials/OODefaultShaderSynthesizer.cpp:348` | ✅ `%@:%X:%g:%g` |
| `KeyFromTextureSpec` (549) | `KeyFromTextureSpec` `Core/Materials/OODefaultShaderSynthesizer.cpp:363` | ✅ |
| `-[OODefaultShaderSynthesizer assignIDForTexture:]` (562) | `assignIDForTexture` `Core/Materials/OODefaultShaderSynthesizer.cpp:378` | ✅ texName lookup bug (→ 0) kept, comment `:433-434` |
| `-[OODefaultShaderSynthesizer textureIDForSpec:]` (613) | `textureIDForSpec` `Core/Materials/OODefaultShaderSynthesizer.cpp:442` | ✅ |
| `-[OODefaultShaderSynthesizer setUpOneTexture:]` (618) | `setUpOneTexture` `Core/Materials/OODefaultShaderSynthesizer.cpp:448` | ✅ |
| `-[OODefaultShaderSynthesizer getSampleName:andSwizzleOp:forTextureSpec:]` (632) | `getSampleName` `Core/Materials/OODefaultShaderSynthesizer.cpp:463` | ✅ nil swizzle ↔ empty string |
| `-[OODefaultShaderSynthesizer readRGBForTextureSpec:mapName:]` (643) | `readRGBForTextureSpec` `Core/Materials/OODefaultShaderSynthesizer.cpp:476` | ✅ |
| `-[OODefaultShaderSynthesizer readOneChannelForTextureSpec:mapName:]` (664) | `readOneChannelForTextureSpec` `Core/Materials/OODefaultShaderSynthesizer.cpp:502` | ✅ |
| `-[OODefaultShaderSynthesizer performStage:]` (684) | `performStage` `Core/Materials/OODefaultShaderSynthesizer.cpp:526` | ✅ stage name ↔ selector |
| `-[OODefaultShaderSynthesizer createTemporaries]` (700) | `createTemporaries` `Core/Materials/OODefaultShaderSynthesizer.cpp:543` | ✅ |
| `-[OODefaultShaderSynthesizer destroyTemporaries]` (725) | `destroyTemporaries` `Core/Materials/OODefaultShaderSynthesizer.cpp:567` | ✅ `_textures` kept, as upstream |
| `-[OODefaultShaderSynthesizer writeTextureCoordRead]` (757) | `writeTextureCoordRead` `Core/Materials/OODefaultShaderSynthesizer.cpp:594` | ✅ |
| `-[OODefaultShaderSynthesizer writeDiffuseColorTermIfNeeded]` (806) | `writeDiffuseColorTermIfNeeded` `Core/Materials/OODefaultShaderSynthesizer.cpp:654` | ✅ |
| `-[OODefaultShaderSynthesizer writeDiffuseColorTerm]` (843) | `writeDiffuseColorTerm` `Core/Materials/OODefaultShaderSynthesizer.cpp:694` | ✅ |
| `-[OODefaultShaderSynthesizer writeDiffuseLighting]` (852) | `writeDiffuseLighting` `Core/Materials/OODefaultShaderSynthesizer.cpp:704` | ✅ |
| `-[OODefaultShaderSynthesizer writeLightVector]` (874) | `writeLightVector` `Core/Materials/OODefaultShaderSynthesizer.cpp:726` | ✅ |
| `-[OODefaultShaderSynthesizer writeEyeVector]` (887) | `writeEyeVector` `Core/Materials/OODefaultShaderSynthesizer.cpp:738` | ✅ |
| `-[OODefaultShaderSynthesizer writeVertexTangentBasis]` (898) | `writeVertexTangentBasis` `Core/Materials/OODefaultShaderSynthesizer.cpp:748` | ✅ |
| `-[OODefaultShaderSynthesizer writeNormalIfNeeded]` (910) | `writeNormalIfNeeded` `Core/Materials/OODefaultShaderSynthesizer.cpp:759` | ✅ |
| `-[OODefaultShaderSynthesizer writeNormal]` (936) | `writeNormal` `Core/Materials/OODefaultShaderSynthesizer.cpp:789` | ✅ |
| `-[OODefaultShaderSynthesizer writeSpecularLighting]` (945) | `writeSpecularLighting` `Core/Materials/OODefaultShaderSynthesizer.cpp:797` | ✅ scale factor/alpha fold, `%.1f` exponent |
| `-[OODefaultShaderSynthesizer writeLightMaps]` (1059) | `writeLightMaps` `Core/Materials/OODefaultShaderSynthesizer.cpp:927` | ✅ binding uses binding type as GLSL type (upstream bug kept) |
| `-[OODefaultShaderSynthesizer writeVertexPosition]` (1163) | `writeVertexPosition` `Core/Materials/OODefaultShaderSynthesizer.cpp:1056` | ✅ |
| `-[OODefaultShaderSynthesizer writeTotalColor]` (1170) | `writeTotalColor` `Core/Materials/OODefaultShaderSynthesizer.cpp:1062` | ✅ |
| `-[OODefaultShaderSynthesizer writeFinalColorComposite]` (1175) | `writeFinalColorComposite` `Core/Materials/OODefaultShaderSynthesizer.cpp:1066` | ✅ |
| `CanonicalizeMaterialSpecifier` (1198) | `CanonicalizeMaterialSpecifier` `Core/Materials/OODefaultShaderSynthesizer.cpp:1130` | ⚠️ throws avoided for nil key / bad light-map colour (comments) |
| `FormatFloat` (1443) | `FormatFloat` `Core/Materials/OODefaultShaderSynthesizer.cpp:1382` | ✅ `%lli.0` else `%g` |

**Differences:**

- ⚠️ **low** — `CanonicalizeMaterialSpecifier`: a `light_map` entry whose `color` is a non-array description that is not a colour has the key erased, where upstream did `setObject:nil` and threw outside `-run`'s `@try`; a nil `materialKey` no longer throws (port skips or uses `""`). Commented at `:1180-1181,1287-1288` (still open) — upstream `Core/Materials/OODefaultShaderSynthesizer.m:1236-1252,1368-1372` ↔ port `Core/Materials/OODefaultShaderSynthesizer.cpp:1170-1183,1281-1292`
- Subtle (✅): the emitted GLSL is the same text: format strings, tab padding, section headers, `"\t\n"` trimming, `FormatFloat`, `uTexture%zu`/`tex%zuSample` naming and stage order. Upstream bugs are kept (texture-ID lookup by name, nil `_entityName`, binding type used as the GLSL type, `OOSynthesizeMaterialShader` always YES).
- Note: none of this is live: `USE_NEW_SHADER_SYNTHESIZER` is 0 in both trees (`OOMaterialConvenienceCreators.m:29` ↔ `.cpp:29`).
- Subtle (✅ low): `material.canonicalForm` prints `oo::DescriptionOf()` of the dictionaries, so the formatting and key order can differ from `-[NSDictionary description]` — port `Core/Materials/OODefaultShaderSynthesizer.cpp:1374-1377`

## OOMaterial

<a id="oomaterial"></a>
Upstream `src/Core/Materials/OOMaterial.m` ↔ `Core/Materials/OOMaterial.cpp` (140 / 151 lines)

**Status:** done — 16 rows: 15 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOMaterial setUp]` (36) | `OOMaterial::setUp` `Core/Materials/OOMaterial.cpp:52` | ✅ empty |
| `-[OOMaterial dealloc]` (41) | implicit destructor | ⚠️ no `willDealloc` call (see Differences) |
| `-[OOMaterial descriptionComponents]` (49) | `OOMaterial::descriptionComponents` `Core/Materials/OOMaterial.cpp:58` | ✅ quoted name, `(null)` for none |
| `-[OOMaterial name]` (54) | `OOMaterial::name` `Core/Materials/OOMaterial.cpp:72` | ✅ logs generic parameter error, nil |
| `-[OOMaterial apply]` (61) | `OOMaterial::apply` `Core/Materials/OOMaterial.cpp:78` | ✅ unapply old with self, clear, set only if doApply |
| `+[OOMaterial applyNone]` (72) | `OOMaterial::applyNone` `Core/Materials/OOMaterial.cpp:88` | ✅ |
| `+[OOMaterial current]` (79) | `OOMaterial::current` `Core/Materials/OOMaterial.cpp:94` | ✅ |
| `-[OOMaterial ensureFinishedLoading]` (84) | `OOMaterial::ensureFinishedLoading` `Core/Materials/OOMaterial.cpp:107` | ✅ |
| `-[OOMaterial isFinishedLoading]` (88) | `OOMaterial::isFinishedLoading` `Core/Materials/OOMaterial.cpp:109` | ✅ |
| `-[OOMaterial setBindingTarget:]` (93) | `OOMaterial::setBindingTarget` `Core/Materials/OOMaterial.cpp:111` | ✅ |
| `-[OOMaterial wantsNormalsAsTextureCoordinates]` (97) | `OOMaterial::wantsNormalsAsTextureCoordinates` `Core/Materials/OOMaterial.cpp:113` | ✅ |
| `-[OOMaterial countOfTextureUnitsWithBaseCoordinates]` (103) | `OOMaterial::countOfTextureUnitsWithBaseCoordinates` `Core/Materials/OOMaterial.cpp:116` | ✅ 1 |
| `-[OOMaterial allTextures]` (110) | `OOMaterial::allTextures` `Core/Materials/OOMaterial.cpp:120` | ✅ nil → empty vector (debug monitor only) |
| `-[OOMaterial(OOSubclassInterface) doApply]` (120) | `OOMaterial::doApply` `Core/Materials/OOMaterial.cpp:123` | ✅ |
| `-[OOMaterial(OOSubclassInterface) unapplyWithNext:]` (126) | `OOMaterial::unapplyWithNext` `Core/Materials/OOMaterial.cpp:128` | ✅ |
| `-[OOMaterial(OOSubclassInterface) willDealloc]` (131) | `OOMaterial::willDealloc` `Core/Materials/OOMaterial.cpp:132` | ✅ same log class/text; slot detached into a leaked holder, not released |

**Differences:**

- ⚠️ **low** — `-dealloc`'s `[self willDealloc]` is gone; `willDealloc()` exists but nothing calls it, because the `std::shared_ptr` slot makes the imbalance impossible. Justified in the comment at `Core/Materials/OOMaterial.h:126-131` (still open) — upstream `Core/Materials/OOMaterial.m:41-47` ↔ port `Core/Materials/OOMaterial.cpp:132-142`
- Subtle (✅): `apply` stores `oo::share(this)` (shared-from-this), so `apply()` must be called on a shared-owned material; all creators return `std::shared_ptr` — port `Core/Materials/OOMaterial.cpp:78-86`

## OOMaterialConvenienceCreators

<a id="oomaterialconveniencecreators"></a>
Upstream `src/Core/Materials/OOMaterialConvenienceCreators.m` ↔ `Core/Materials/OOMaterialConvenienceCreators.cpp` (539 / 651 lines)

**Status:** done — 15 rows: 14 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOMaterial(OOConvenienceCreators) synthesizeMaterialDictionaryWithName:configuration:macros:]` (88) | `OOMaterial::synthesizeMaterialDictionaryWithName` `Core/Materials/OOMaterialConvenienceCreators.cpp:110` | ✅ reducedDetail → 3 units; synth order; hull-heat/time/fog uniforms at shader detail; same outConfig keys |
| `+[OOMaterial(OOConvenienceCreators) defaultShaderMaterialWithName:cacheKey:configuration:macros:bindingTarget:]` (142) | `OOMaterial::defaultShaderMaterialWithName` `Core/Materials/OOMaterialConvenienceCreators.cpp:173` | ✅ loop guard + `material.synthesize.loop`; cache in `synthesized shader materials` |
| `+[OOMaterial(OOConvenienceCreators) initialize]` (194) | `DumpShaderSource` `Core/Materials/OOMaterialConvenienceCreators.cpp:230` | ✅ dead branch (`USE_NEW_SHADER_SYNTHESIZER 0`) |
| `+[OOMaterial(OOConvenienceCreators) defaultShaderMaterialWithName:cacheKey:configuration:macros:bindingTarget:]` (200) | `OOMaterial::defaultShaderMaterialWithName` (new-synth branch) `Core/Materials/OOMaterialConvenienceCreators.cpp:239` | ❌ dead branch would not compile |
| `+[OOMaterial(OOConvenienceCreators) materialWithName:cacheKey:configuration:macros:bindingTarget:forSmoothedMesh:]` (254) | `OOMaterial::materialWithName(…, configuration, …)` `Core/Materials/OOMaterialConvenienceCreators.cpp:311` | ✅ same shader/multitexture/single/basic fallback chain and conditions |
| `+[OOMaterial(OOConvenienceCreators) materialWithName:cacheKey:materialDictionary:shadersDictionary:macros:bindingTarget:forSmoothedMesh:]` (309) | `OOMaterial::materialWithName(…, materialDict, shadersDict, …)` `Core/Materials/OOMaterialConvenienceCreators.cpp:384` | ✅ shaders dict first, then materials, then texture fallback with empty config |
| `SetUniform` (352) | `SetUniform` `Core/Materials/OOMaterialConvenienceCreators.cpp:429` | ✅ |
| `SetUniformFloat` (357) | `SetUniformFloat` `Core/Materials/OOMaterialConvenienceCreators.cpp:435` | ✅ |
| `AddTexture` (362) | `AddTexture` `Core/Materials/OOMaterialConvenienceCreators.cpp:440` | ✅ always writes `diffuse_map` for a non-nil key (upstream bug kept) |
| `AddColorIfAppropriate` (377) | `AddColorIfAppropriate` `Core/Materials/OOMaterialConvenienceCreators.cpp:460` | ✅ |
| `AddMacroColorIfAppropriate` (388) | `AddMacroColorIfAppropriate` `Core/Materials/OOMaterialConvenienceCreators.cpp:474` | ✅ `%g` ↔ `{:g}` (both 6 significant digits) |
| `SynthDiffuse` (402) | `SynthDiffuse` `Core/Materials/OOMaterialConvenienceCreators.cpp:485` | ✅ `diffuse_map = ""` when none |
| `SynthEmissionAndIllumination` (421) | `SynthEmissionAndIllumination` `Core/Materials/OOMaterialConvenienceCreators.cpp:509` | ✅ |
| `SynthNormalMap` (467) | `SynthNormalMap` `Core/Materials/OOMaterialConvenienceCreators.cpp:571` | ✅ |
| `SynthSpecular` (489) | `SynthSpecular` `Core/Materials/OOMaterialConvenienceCreators.cpp:596` | ✅ |

**Differences:**

- ❌ **low** — the dead `USE_NEW_SHADER_SYNTHESIZER` branch still would not compile (`ResourceManager::writeDiagnosticString(synthesized ?, std::string(), …)`), and it means to write empty strings where upstream dumped the shader sources. `#define USE_NEW_SHADER_SYNTHESIZER 0`, so there is no runtime effect (still open) — upstream `Core/Materials/OOMaterialConvenienceCreators.m:227-228` ↔ port `Core/Materials/OOMaterialConvenienceCreators.cpp:281-282`
- Subtle (✅, new): `materialWithName(…, materialDict, shadersDict, …)` now raises `OOInvalidArgumentException` ("shaders/materials is not a dictionary") when a script passes a non-dictionary (commit `10504da05`). Upstream raised too, because `-oo_dictionaryForKey:` was sent to a non-dictionary, but the exception text differs — port `Core/Materials/OOMaterialConvenienceCreators.cpp:377-382,394,404`
- Subtle (✅ low): the synthesized-config cache key is `cacheKey/name/<oo::DescriptionOf(config)>`, and a nil name gives `""` where `%@` gave `(null)`; the original `cacheKey` (not the long one) is passed on, which only the loop-guarded path reads (still as before) — port `Core/Materials/OOMaterialConvenienceCreators.cpp:193-194,216`

## OOMaterialSpecifier

<a id="oomaterialspecifier"></a>
Upstream `src/Core/Materials/OOMaterialSpecifier.m` ↔ `Core/Materials/OOMaterialSpecifier.cpp` (256 / 259 lines)

**Status:** done — 24 rows: 24 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `kOOMaterial*Name` string constants (35-66) | `Core/Materials/OOMaterialSpecifier.h:79-120` | ✅ every key spelling and `kOOMaterialDefaultParallaxScale` 0.01f match |
| `-[NSDictionary(OOMateralProperties) oo_rawSpecularExponentValue]` (73) | `RawSpecularExponentValue` `Core/Materials/OOMaterialSpecifier.cpp:67` | ✅ `specular_exponent` then `shininess`, default -1 |
| `-[NSDictionary(OOMateralProperties) oo_diffuseColor]` (81) | `OOMaterialDiffuseColor` `Core/Materials/OOMaterialSpecifier.cpp:76` | ✅ white dropped |
| `-[NSDictionary(OOMateralProperties) oo_ambientColor]` (92) | `OOMaterialAmbientColor` `Core/Materials/OOMaterialSpecifier.cpp:88` | ✅ |
| `-[NSDictionary(OOMateralProperties) oo_specularColor]` (100) | `OOMaterialSpecularColor` `Core/Materials/OOMaterialSpecifier.cpp:97` | ✅ 0.2 grey default |
| `-[NSDictionary(OOMateralProperties) oo_specularModulateColor]` (111) | `OOMaterialSpecularModulateColor` `Core/Materials/OOMaterialSpecifier.cpp:109` | ✅ white default |
| `-[NSDictionary(OOMateralProperties) oo_emissionColor]` (120) | `OOMaterialEmissionColor` `Core/Materials/OOMaterialSpecifier.cpp:118` | ✅ black dropped |
| `-[NSDictionary(OOMateralProperties) oo_emissionModulateColor]` (131) | `OOMaterialEmissionModulateColor` `Core/Materials/OOMaterialSpecifier.cpp:130` | ✅ |
| `-[NSDictionary(OOMateralProperties) oo_illuminationModulateColor]` (140) | `OOMaterialIlluminationModulateColor` `Core/Materials/OOMaterialSpecifier.cpp:140` | ✅ |
| `-[NSDictionary(OOMateralProperties) oo_diffuseMapSpecifierWithDefaultName:]` (149) | `OOMaterialDiffuseMapSpecifier` `Core/Materials/OOMaterialSpecifier.cpp:150` | ✅ |
| `-[NSDictionary(OOMateralProperties) oo_combinedSpecularMapSpecifier]` (154) | `OOMaterialCombinedSpecularMapSpecifier` `Core/Materials/OOMaterialSpecifier.cpp:157` | ✅ raw exponent 0 → nil |
| `-[NSDictionary(OOMateralProperties) oo_specularColorMapSpecifier]` (161) | `OOMaterialSpecularColorMapSpecifier` `Core/Materials/OOMaterialSpecifier.cpp:164` | ✅ |
| `-[NSDictionary(OOMateralProperties) oo_specularExponentMapSpecifier]` (171) | `OOMaterialSpecularExponentMapSpecifier` `Core/Materials/OOMaterialSpecifier.cpp:173` | ✅ `extract_channel = a`, nil stays nil |
| `-[NSDictionary(OOMateralProperties) oo_normalMapSpecifier]` (181) | `OOMaterialNormalMapSpecifier` `Core/Materials/OOMaterialSpecifier.cpp:184` | ✅ |
| `-[NSDictionary(OOMateralProperties) oo_parallaxMapSpecifier]` (188) | `OOMaterialParallaxMapSpecifier` `Core/Materials/OOMaterialSpecifier.cpp:191` | ✅ |
| `-[NSDictionary(OOMateralProperties) oo_normalAndParallaxMapSpecifier]` (200) | `OOMaterialNormalAndParallaxMapSpecifier` `Core/Materials/OOMaterialSpecifier.cpp:203` | ✅ |
| `-[NSDictionary(OOMateralProperties) oo_emissionMapSpecifier]` (205) | `OOMaterialEmissionMapSpecifier` `Core/Materials/OOMaterialSpecifier.cpp:209` | ✅ |
| `-[NSDictionary(OOMateralProperties) oo_illuminationMapSpecifier]` (210) | `OOMaterialIlluminationMapSpecifier` `Core/Materials/OOMaterialSpecifier.cpp:214` | ✅ |
| `-[NSDictionary(OOMateralProperties) oo_emissionAndIlluminationMapSpecifier]` (215) | `OOMaterialEmissionAndIlluminationMapSpecifier` `Core/Materials/OOMaterialSpecifier.cpp:219` | ✅ |
| `-[NSDictionary(OOMateralProperties) oo_parallaxScale]` (222) | `OOMaterialParallaxScale` `Core/Materials/OOMaterialSpecifier.cpp:228` | ✅ |
| `-[NSDictionary(OOMateralProperties) oo_parallaxBias]` (227) | `OOMaterialParallaxBias` `Core/Materials/OOMaterialSpecifier.cpp:233` | ✅ default 0 |
| `-[NSDictionary(OOMateralProperties) oo_gammaCorrect]` (232) | `OOMaterialGammaCorrect` `Core/Materials/OOMaterialSpecifier.cpp:237` | ✅ `!no-gamma-correct` |
| `-[NSDictionary(OOMateralProperties) oo_gloss]` (237) | `OOMaterialGloss` `Core/Materials/OOMaterialSpecifier.cpp:243` | ✅ 0.375 clamped 0-1 |
| `-[NSDictionary(OOMateralProperties) oo_specularExponent]` (242) | `OOMaterialSpecularExponent` `Core/Materials/OOMaterialSpecifier.cpp:247` | ✅ 128 with shaders + exponent map, else 10 |

**Differences:**

- Subtle (✅): "nil is neither white nor black" is kept with explicit null checks; a nil `UNIVERSE` answers `useShaders` false as a nil message did — port `Core/Materials/OOMaterialSpecifier.cpp:83,125,135,145,250`

## OOMultiTextureMaterial

<a id="oomultitexturematerial"></a>
Upstream `src/Core/Materials/OOMultiTextureMaterial.m` ↔ `Core/Materials/OOMultiTextureMaterial.cpp` (204 / 216 lines)

**Status:** done — 9 rows: 7 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOMultiTextureMaterial initWithName:configuration:]` (40) | `OOMultiTextureMaterial::initWithName` `Core/Materials/OOMultiTextureMaterial.cpp:48` | ✅ combiner check, emission-colour keys stripped, simple-case test, generator choice, `emissionSpec ?: illuminationSpec`, unit counting |
| `-[OOMultiTextureMaterial dealloc]` (108) | implicit destructor | ⚠️ no `willDealloc` (see OOMaterial) |
| `-[OOMultiTextureMaterial descriptionComponents]` (118) | `OOMultiTextureMaterial::descriptionComponents` `Core/Materials/OOMultiTextureMaterial.cpp:125` | ✅ `" - "` + comma-joined bits |
| `-[OOMultiTextureMaterial textureUnitCount]` (132) | `OOMultiTextureMaterial::textureUnitCount` `Core/Materials/OOMultiTextureMaterial.cpp:143` | ✅ |
| `-[OOMultiTextureMaterial countOfTextureUnitsWithBaseCoordinates]` (137) | `OOMultiTextureMaterial::countOfTextureUnitsWithBaseCoordinates` `Core/Materials/OOMultiTextureMaterial.cpp:145` | ✅ |
| `-[OOMultiTextureMaterial ensureFinishedLoading]` (142) | `OOMultiTextureMaterial::ensureFinishedLoading` `Core/Materials/OOMultiTextureMaterial.cpp:149` | ✅ |
| `-[OOMultiTextureMaterial apply]` (148) | `OOMultiTextureMaterial::apply` `Core/Materials/OOMultiTextureMaterial.cpp:154` | ✅ same GL env sequence and assert |
| `-[OOMultiTextureMaterial unapplyWithNext:]` (177) | `OOMultiTextureMaterial::unapplyWithNext` `Core/Materials/OOMultiTextureMaterial.cpp:185` | ✅ |
| `-[OOMultiTextureMaterial allTextures]` (194) | `OOMultiTextureMaterial::allTextures` `Core/Materials/OOMultiTextureMaterial.cpp:204` | ❌ null entry when no emission map |

**Differences:**

- ⚠️ **low** — `-dealloc`'s `[self willDealloc]` has no counterpart; same rationale as OOMaterial (`Core/Materials/OOMaterial.h:126-131`) (still open) — upstream `Core/Materials/OOMultiTextureMaterial.m:108-116` ↔ port none
- ❌ **low** — `allTextures` (debug monitor only) pushes a null `shared_ptr` when `_emissionMap` is nil; upstream `setWithObjects:_diffuseMap, nil, nil` dropped it (and `setWithObject:nil` raised) (still open) — upstream `Core/Materials/OOMultiTextureMaterial.m:194-199` ↔ port `Core/Materials/OOMultiTextureMaterial.cpp:204-213`

## OONullTexture

<a id="oonulltexture"></a>
Upstream `src/Core/Materials/OONullTexture.m` ↔ `Core/Materials/OONullTexture.cpp` (116 / 70 lines)

**Status:** done — 12 rows: 6 ✅ 0 ⚠️ 0 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OONullTexture sharedNullTexture]` (36) | `OONullTexture::sharedNullTexture` `Core/Materials/OONullTexture.cpp:38` | ✅ lazily made, never freed (T090 holder) |
| `-[OONullTexture apply]` (46) | `OONullTexture::apply` `Core/Materials/OONullTexture.cpp:51` | ✅ |
| `-[OONullTexture dimensions]` (51) | `OONullTexture::dimensions` `Core/Materials/OONullTexture.cpp:53` | ✅ |
| `-[OONullTexture isMipMapped]` (56) | `OONullTexture::isMipMapped` `Core/Materials/OONullTexture.cpp:55` | ✅ |
| `-[OONullTexture forceRebind]` (61) | `OONullTexture::forceRebind` `Core/Materials/OONullTexture.cpp:57` | ✅ |
| `-[OONullTexture name]` (66) | `OONullTexture::name` `Core/Materials/OONullTexture.cpp:60` | ✅ `#ifndef NDEBUG` kept |
| `+[OONullTexture(Singleton) allocWithZone:]` (83) | none (comment `Core/Materials/OONullTexture.cpp:65-70`) | ➖ only `sharedNullTexture` constructs |
| `-[OONullTexture(Singleton) copyWithZone:]` (92) | none | ➖ |
| `-[OONullTexture(Singleton) retain]` (97) | none | ➖ shared_ptr ownership |
| `-[OONullTexture(Singleton) retainCount]` (102) | none | ➖ |
| `-[OONullTexture(Singleton) release]` (107) | none | ➖ never freed holder |
| `-[OONullTexture(Singleton) autorelease]` (111) | none | ➖ |

**Differences:**

- ➖ **low** — the singleton retain/release boilerplate is not translated; the instance is held by a never-deleted heap `shared_ptr` (T090; was `leakRef()` last run), so it is never freed, matching the UINT_MAX retain count (still open, unchanged behaviour) — upstream `Core/Materials/OONullTexture.m:83-114` ↔ port `Core/Materials/OONullTexture.cpp:41-46,65-70`

## OOPNGTextureLoader

<a id="oopngtextureloader"></a>
Upstream `src/Core/Materials/OOPNGTextureLoader.m` ↔ `Core/Materials/OOPNGTextureLoader.cpp` (221 / 221 lines)

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOPNGTextureLoader loadTexture]` (49) | `OOPNGTextureLoader::loadTexture` `Core/Materials/OOPNGTextureLoader.cpp:57` | ✅ |
| `-[OOPNGTextureLoader dealloc]` (63) | `~OOPNGTextureLoader` `Core/Materials/OOPNGTextureLoader.cpp:68` | ✅ |
| `-[OOPNGTextureLoader(OOPrivate) doLoadTexture]` (77) | `OOPNGTextureLoader::doLoadTexture` `Core/Materials/OOPNGTextureLoader.cpp:75` | ✅ same libpng setup/transforms/format map/log classes |
| `-[OOPNGTextureLoader(OOPrivate) readBytes:count:]` (172) | `OOPNGTextureLoader::readBytes` `Core/Materials/OOPNGTextureLoader.cpp:153` | ✅ same truncation message |
| `PNGError` (199) | `PNGError` `Core/Materials/OOPNGTextureLoader.cpp:192` | ✅ |
| `PNGWarning` (211) | `PNGWarning` `Core/Materials/OOPNGTextureLoader.cpp:206` | ✅ |
| `PNGRead` (217) | `PNGRead` `Core/Materials/OOPNGTextureLoader.cpp:214` | ✅ null loader = no-op |

**Differences:**

- Subtle (✅): row pointers are now a member vector and `_data` a member `OOPixelBuffer` (T017/T025), so the `setjmp` frame holds no locals with destructors; the error path drops `_data` as upstream freed it. On allocation failure upstream logged `kOOLogAllocationFailure` and bailed; the port throws `std::bad_alloc` (unreachable in practice) — port `Core/Materials/OOPNGTextureLoader.cpp:91-95,139-150`
- Subtle (✅): a NULL io pointer prints `(null)` for the path as `[nil path]` did — port `Core/Materials/OOPNGTextureLoader.cpp:187-190`

## OOPixMap

<a id="oopixmap"></a>
Upstream `src/Core/Materials/OOPixMap.m` ↔ `Core/Materials/OOPixMap.cpp` (242 / 260 lines)

**Status:** done — 12 rows: 11 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOIsValidPixMap` (39) | `OOIsValidPixMap` `Core/Materials/OOPixMap.cpp:46` | ✅ identical predicate |
| `OOMakePixMap` (44) | `OOMakePixMap(void*…)` `Core/Materials/OOPixMap.cpp:54` (+ new buffer overload `:73`) | ✅ same defaults for rowBytes/bufferSize |
| `OOAllocatePixMap` (66) | `OOAllocatePixMap` `Core/Materials/OOPixMap.cpp:98` | ✅ same validity test; buffer now a zero-filled vector |
| `OOFreePixMap` (80) | `OOFreePixMap` `Core/Materials/OOPixMap.cpp:112` | ⚠️ drops a shared buffer ref instead of `free()` (T017) |
| `OODuplicatePixMap` (89) | `OODuplicatePixMap` `Core/Materials/OOPixMap.cpp:118` | ✅ upstream `width, width` height bug kept |
| `OOResizePixMap` (106) | `OOResizePixMap` `Core/Materials/OOPixMap.cpp:133` | ✅ same early returns; vector resize ↔ realloc |
| `OOExpandPixMap` (125) | `OOExpandPixMap` `Core/Materials/OOPixMap.cpp:154` | ✅ |
| `OODumpPixMap` (140) | `OODumpPixMap` `Core/Materials/OOPixMap.cpp:167` | ✅ nil universe/view guarded; same " rgb"/" alpha" names |
| `OOIsValidPixMapFormat` (180) | `OOIsValidPixMapFormat` `Core/Materials/OOPixMap.cpp:202` | ✅ |
| `OOPixMapBytesPerPixelForFormat` (195) | `OOPixMapBytesPerPixelForFormat` `Core/Materials/OOPixMap.cpp:216` | ✅ -1 → 65535 both |
| `OOPixMapFormatName` (212) | `OOPixMapFormatName` `Core/Materials/OOPixMap.cpp:232` | ✅ `invalid<%i>` |
| `OOPixMapFormatHasAlpha` (228) | `OOPixMapFormatHasAlpha` `Core/Materials/OOPixMap.cpp:247` | ✅ |

**Differences:**

- ⚠️ **low** (new) — T017 (`17cdb4edb`, "the pixel-buffer chain owns its bytes") gives `OOPixMap` a shared `OOPixelBuffer`; `OOFreePixMap` releases the reference instead of `free(pixels)`. Struct copies now keep the bytes alive where upstream aliases dangled, and freeing a pixmap made over borrowed memory no longer frees it. Documented at `Core/Materials/OOPixMap.h:66-71,115-119` — upstream `Core/Materials/OOPixMap.m:80-87` ↔ port `Core/Materials/OOPixMap.cpp:112-116`
- Subtle (✅ low, new): `OOAllocatePixMap` zero-fills (malloc left garbage) and throws `bad_alloc` where malloc returned a null pixmap. `OOResizePixMap` on a pixmap with no own buffer copies into a fresh one (upstream `realloc`ed whatever pointer it had) — port `Core/Materials/OOPixMap.cpp:98-109,133-151`

## OOPixMapChannelOperations

<a id="oopixmapchanneloperations"></a>
Upstream `src/Core/Materials/OOPixMapChannelOperations.m` ↔ `Core/Materials/OOPixMapChannelOperations.cpp` (331 / 355 lines)

**Status:** done — 11 rows: 11 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOExtractPixMapChannel` (38) | `OOExtractPixMapChannel` `Core/Materials/OOPixMapChannelOperations.cpp:49` | ✅ |
| `ExtractChannel_4` (56) | `ExtractChannel_4` `Core/Materials/OOPixMapChannelOperations.cpp:69` | ✅ |
| `OOPixMapToRGBA` (78) | `OOPixMapToRGBA` `Core/Materials/OOPixMapChannelOperations.cpp:92` | ✅ free/swap → buffer assignment |
| `ToRGBA_1` (118) | `ToRGBA_1` `Core/Materials/OOPixMapChannelOperations.cpp:126` | ✅ |
| `ToRGBA_2` (138) | `ToRGBA_2` `Core/Materials/OOPixMapChannelOperations.cpp:150` | ✅ |
| `OOPixMapModulateUniform` (166) | `OOPixMapModulateUniform` `Core/Materials/OOPixMapChannelOperations.cpp:181` | ✅ `* 256.0f` |
| `ModulateUniform_4` (178) | `ModulateUniform_4` `Core/Materials/OOPixMapChannelOperations.cpp:194` | ✅ reversed `f3..f0` params kept |
| `OOPixMapModulatePixMap` (220) | `OOPixMapModulatePixMap` `Core/Materials/OOPixMapChannelOperations.cpp:238` | ✅ |
| `ModulatePixMap_4` (236) | `ModulatePixMap_4` `Core/Materials/OOPixMapChannelOperations.cpp:255` | ✅ |
| `OOPixMapAddPixMap` (278) | `OOPixMapAddPixMap` `Core/Materials/OOPixMapChannelOperations.cpp:299` | ✅ |
| `AddPixMap_4` (294) | `AddPixMap_4` `Core/Materials/OOPixMapChannelOperations.cpp:316` | ✅ |

**Differences:**

- Subtle (✅): `diff -w` of the bodies shows only casts, `bool`, anonymous namespace and the `OOPixMapToRGBA` swap (`*ioPixMap = temp` releases the old buffer; an unused `temp` releases itself). The endian test now comes from `OOCPUInfoEndian.h` (same `OOLITE_BIG_ENDIAN`/`LITTLE` macros) — port `Core/Materials/OOPixMapChannelOperations.cpp:96,169-171`

## OOPixMapTextureLoader

<a id="oopixmaptextureloader"></a>
Upstream `src/Core/Materials/OOPixMapTextureLoader.m` ↔ `Core/Materials/OOPixMapTextureLoader.cpp` (86 / 92 lines)

**Status:** done — 4 rows: 4 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOPixMapTextureLoader initWithPixMap:textureOptions:freeWhenDone:]` (33) | `OOPixMapTextureLoader::initWithPixMap` `Core/Materials/OOPixMapTextureLoader.cpp:43` (factory `:35`) | ✅ upstream bug kept: duplicates empty `_pixMap` |
| `-[OOPixMapTextureLoader dealloc]` (50) | `~OOPixMapTextureLoader` `Core/Materials/OOPixMapTextureLoader.cpp:64` | ✅ |
| `-[OOPixMapTextureLoader loadTexture]` (57) | `OOPixMapTextureLoader::loadTexture` `Core/Materials/OOPixMapTextureLoader.cpp:66` | ✅ mip expand; fallback sets MipMap again (upstream quirk) |
| `-[OOPixMapTextureLoader textureOptions]` (81) | `OOPixMapTextureLoader::textureOptions` `Core/Materials/OOPixMapTextureLoader.cpp:92` | ✅ |

**Differences:**

- Subtle (✅, upstream bugs kept): `OODuplicatePixMap(_pixMap, 0)` copies the still-empty member, so `freeWhenDone == false` always fails; a failed `OOExpandPixMap` re-sets `kMinFilterMipMap` instead of Linear — port `Core/Materials/OOPixMapTextureLoader.cpp:54,76-77`
- Subtle (✅, new): ownership handover is now `_data = OOPixMapOwnedBuffer(_pixMap)` + `OOFreePixMap` (T017) instead of nulling `pixels`; a borrowed-memory pixmap is copied rather than adopted. The path name uses `oo::str::pointerDescription` where upstream used `%p` — port `Core/Materials/OOPixMapTextureLoader.cpp:47,82-89`

## OOPlanetTextureGenerator

<a id="ooplanettexturegenerator"></a>
Upstream `src/Core/Materials/OOPlanetTextureGenerator.m` ↔ `Core/Materials/OOPlanetTextureGenerator.cpp` (1261 / 1276 lines)

**Status:** done — 51 rows: 49 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOPlanetTextureGenerator initWithPlanetInfo:]` (143) | `OOPlanetTextureGenerator::initWithPlanetInfo` `Core/Materials/OOPlanetTextureGenerator.cpp:165` | ⚠️ seed is a parameter, not `noise_map_seed` |
| `+[OOPlanetTextureGenerator planetTextureWithInfo:]` (188) | `OOPlanetTextureGenerator::planetTextureWithInfo` `Core/Materials/OOPlanetTextureGenerator.cpp:222` | ✅ |
| `+[OOPlanetTextureGenerator generatePlanetTexture:andAtmosphere:withInfo:]` (200) | `generatePlanetTextureAndAtmosphere` `Core/Materials/OOPlanetTextureGenerator.cpp:234` | ✅ |
| `+[OOPlanetTextureGenerator generatePlanetTexture:secondaryTexture:withInfo:]` (221) | `generatePlanetTexture(texture, secondary, …)` `Core/Materials/OOPlanetTextureGenerator.cpp:255` | ✅ |
| `+[OOPlanetTextureGenerator generatePlanetTexture:secondaryTexture:andAtmosphere:withInfo:]` (247) | `generatePlanetTexture(texture, secondary, atmosphere, …)` `Core/Materials/OOPlanetTextureGenerator.cpp:281` | ✅ same log line, `(null)` for no atmosphere |
| `-[OOPlanetTextureGenerator dealloc]` (287) | `~OOPlanetTextureGenerator` `Core/Materials/OOPlanetTextureGenerator.cpp:325` | ✅ |
| `-[OOPlanetTextureGenerator descriptionComponents]` (295) | `descriptionComponents` `Core/Materials/OOPlanetTextureGenerator.cpp:327` | ✅ |
| `-[OOPlanetTextureGenerator textureOptions]` (300) | `textureOptions` `Core/Materials/OOPlanetTextureGenerator.cpp:333` | ✅ |
| `-[OOPlanetTextureGenerator cacheKey]` (305) | `cacheKey` `Core/Materials/OOPlanetTextureGenerator.cpp:337` | ✅ baked/raw/-atmo |
| `-[OOPlanetTextureGenerator cacheKeyForType:]` (313) | `cacheKeyForType` `Core/Materials/OOPlanetTextureGenerator.cpp:343` | ✅ same format (`%g`/`%f` ↔ `{:g}`/`{:f}`) |
| `-[OOPlanetTextureGenerator normalMapGenerator]` (324) | `normalMapGenerator` `Core/Materials/OOPlanetTextureGenerator.cpp:355` | ✅ |
| `-[OOPlanetTextureGenerator atmosphereGenerator]` (332) | `atmosphereGenerator` `Core/Materials/OOPlanetTextureGenerator.cpp:365` | ✅ |
| `-[OOPlanetTextureGenerator getResult:format:width:height:]` (340) | `getResultFormatWidthHeight` `Core/Materials/OOPlanetTextureGenerator.cpp:375` | ✅ dead in both (does not override) |
| `-[OOPlanetTextureGenerator loadTexture]` (362) | `loadTexture` `Core/Materials/OOPlanetTextureGenerator.cpp:400` | ✅ same buffers, colour maths, completion order, log text |
| `-[OOPlanetTextureGenerator dumpNoiseBuffer:]` (546) | `dumpNoiseBuffer` `Core/Materials/OOPlanetTextureGenerator.cpp:598` | ✅ debug dump |
| `Lerp` (570) | `Lerp` `Core/Materials/OOPlanetTextureGenerator.cpp:618` | ✅ token-identical |
| `Blend` (576) | `Blend` `Core/Materials/OOPlanetTextureGenerator.cpp:624` | ✅ |
| `BlendAlpha` (585) | `BlendAlpha` `Core/Materials/OOPlanetTextureGenerator.cpp:629` | ✅ |
| `CloudMix` (590) | `CloudMix` `Core/Materials/OOPlanetTextureGenerator.cpp:633` | ✅ |
| `PlanetMix` (636) | `PlanetMix` `Core/Materials/OOPlanetTextureGenerator.cpp:685` | ✅ |
| `FloatRGBFromDictColor` (697) | `FloatRGBFromDictColor` `Core/Materials/OOPlanetTextureGenerator.cpp:757` | ❌ non-colour → black |
| `Hermite` (705) | `Hermite` `Core/Materials/OOPlanetTextureGenerator.cpp:775` | ✅ |
| `fast_floor` (718) | `fast_floor` `Core/Materials/OOPlanetTextureGenerator.cpp:785` | ✅ type pun → `std::bit_cast` of the same words |
| `FillFBMBuffer` (727) | `FillFBMBuffer` `Core/Materials/OOPlanetTextureGenerator.cpp:795` | ✅ zeroed vector ↔ calloc |
| `TDot3` (795) | `TDot3` `Core/Materials/OOPlanetTextureGenerator.cpp:838` | ✅ |
| `SampleNoise3D` (806) | `SampleNoise3D` `Core/Materials/OOPlanetTextureGenerator.cpp:849` | ✅ |
| `MakePermutationTable` (884) | `MakePermutationTable` `Core/Materials/OOPlanetTextureGenerator.cpp:928` | ✅ |
| `GenerateFBMNoise3D` (900) | `GenerateFBMNoise3D` `Core/Materials/OOPlanetTextureGenerator.cpp:941` | ✅ |
| `FillRandomBuffer` (961) | `FillRandomBuffer` `Core/Materials/OOPlanetTextureGenerator.cpp:999` | ✅ |
| `AddNoise` (969) | `AddNoise` `Core/Materials/OOPlanetTextureGenerator.cpp:1006` | ✅ |
| `GenerateFBMNoise` (1013) | `GenerateFBMNoise` `Core/Materials/OOPlanetTextureGenerator.cpp:1053` | ✅ three vectors ↔ one malloc |
| `QFactor` (1048) | `QFactor` `Core/Materials/OOPlanetTextureGenerator.cpp:1088` | ✅ |
| `GetQ` (1059) | `GetQ` `Core/Materials/OOPlanetTextureGenerator.cpp:1099` | ✅ |
| `SetMixConstants` (1078) | `SetMixConstants` `Core/Materials/OOPlanetTextureGenerator.cpp:1119` | ✅ |
| `-[OOPlanetNormalMapGenerator initWithCacheKey:seed:]` (1088) | `OOPlanetNormalMapGenerator::initWithCacheKey` `Core/Materials/OOPlanetTextureGenerator.cpp:1132` | ✅ |
| `-[OOPlanetNormalMapGenerator dealloc]` (1099) | implicit destructor | ✅ |
| `-[OOPlanetNormalMapGenerator cacheKey]` (1106) | `cacheKey` `Core/Materials/OOPlanetTextureGenerator.cpp:1146` | ✅ |
| `-[OOPlanetNormalMapGenerator textureOptions]` (1111) | `textureOptions` `Core/Materials/OOPlanetTextureGenerator.cpp:1150` | ✅ |
| `-[OOPlanetNormalMapGenerator enqueue]` (1116) | `enqueue` `Core/Materials/OOPlanetTextureGenerator.cpp:1154` | ✅ |
| `-[OOPlanetNormalMapGenerator enqueued]` (1127) | `enqueued` `Core/Materials/OOPlanetTextureGenerator.cpp:1164` | ✅ |
| `-[OOPlanetNormalMapGenerator loadTexture]` (1132) | `loadTexture` `Core/Materials/OOPlanetTextureGenerator.cpp:1166` | ✅ |
| `-[OOPlanetNormalMapGenerator completeWithData:width:height:]` (1137) | `completeWithData` `Core/Materials/OOPlanetTextureGenerator.cpp:1170` | ✅ buffer moved in; super enqueue |
| `-[OOPlanetAtmosphereGenerator initWithCacheKey:seed:andParent:]` (1164) | `OOPlanetAtmosphereGenerator::initWithCacheKey` `Core/Materials/OOPlanetTextureGenerator.cpp:1194` | ✅ parent held strongly, as retained |
| `-[OOPlanetAtmosphereGenerator dealloc]` (1177) | implicit destructor | ✅ |
| `-[OOPlanetAtmosphereGenerator cacheKey]` (1184) | `cacheKey` `Core/Materials/OOPlanetTextureGenerator.cpp:1212` | ✅ |
| `-[OOPlanetAtmosphereGenerator textureOptions]` (1189) | `textureOptions` `Core/Materials/OOPlanetTextureGenerator.cpp:1216` | ✅ |
| `-[OOPlanetAtmosphereGenerator enqueue]` (1194) | `enqueue` `Core/Materials/OOPlanetTextureGenerator.cpp:1220` | ✅ |
| `-[OOPlanetAtmosphereGenerator enqueued]` (1200) | `enqueued` `Core/Materials/OOPlanetTextureGenerator.cpp:1225` | ✅ |
| `-[OOPlanetAtmosphereGenerator loadTexture]` (1205) | `loadTexture` `Core/Materials/OOPlanetTextureGenerator.cpp:1227` | ✅ |
| `-[OOPlanetAtmosphereGenerator getResult:format:originalWidth:originalHeight:]` (1219) | `getResult` `Core/Materials/OOPlanetTextureGenerator.cpp:1240` | ✅ waits on parent when not ready |
| `-[OOPlanetAtmosphereGenerator completeWithData:width:height:]` (1234) | `completeWithData` `Core/Materials/OOPlanetTextureGenerator.cpp:1252` | ✅ |

**Differences:**

- ⚠️ **low** — the noise seed is a `RANROTSeed` parameter instead of an `NSValue` under `noise_map_seed` in `planetInfo` (comment `:184`). Upstream, a missing key left the seed at 0,0; that path no longer exists (still open) — upstream `Core/Materials/OOPlanetTextureGenerator.m:157` ↔ port `Core/Materials/OOPlanetTextureGenerator.cpp:184`
- ❌ **low** — `FloatRGBFromDictColor`: a value that is not an `OOColor` now gives black `{0,0,0}` (commented `:766`); upstream only had an `NSCAssert`, so a release build sent `-redComponent` to the wrong class and threw. A missing key gives zeros in both (still open) — upstream `Core/Materials/OOPlanetTextureGenerator.m:697-703` ↔ port `Core/Materials/OOPlanetTextureGenerator.cpp:757-771`
- ✅ (emphasis: noise/RNG/colour) — a token diff of upstream 570-1085 against the port shows only `bool`, casts, `.data()` on vectors that replaced `malloc`/`calloc`/`FREE`, `enum` → `constexpr int`, and `fast_floor`'s pun → `std::bit_cast<std::array<int32_t,2>>` (same word index `iman_`). The RANROT call order, octave loops, constants and float expression order are unchanged.
- ✅ (emphasis: `loadTexture`) — the main loop is token-identical apart from `static_cast`s. Buffers are now `OOPixelBuffer`s (T017) moved into the sub-generators via `completeWithData`; on failure they go with their locals where upstream `FREE`d them. `p3dnsf` (debug only) reads `oo::Defaults` with default 1.0 — port `Core/Materials/OOPlanetTextureGenerator.cpp:409-458,564-580`

## OOShaderMaterial

<a id="ooshadermaterial"></a>
Upstream `src/Core/Materials/OOShaderMaterial.m` ↔ `Core/Materials/OOShaderMaterial.cpp` (794 / 793 lines)

**Status:** done — 24 rows: 21 ✅ 2 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `kOO*Key` string constants (47-55) | `Core/Materials/OOShaderMaterial.h:212-224` | ✅ same spellings |
| `+[OOShaderMaterial configurationDictionarySpecifiesShaderMaterial:]` (71) | `OOShaderMaterial::configurationDictionarySpecifiesShaderMaterial` `Core/Materials/OOShaderMaterial.cpp:86` | ✅ duplicated `vertex_shader` test (upstream typo) kept |
| `+[OOShaderMaterial shaderMaterialWithName:configuration:macros:bindingTarget:]` (88) | `OOShaderMaterial::shaderMaterialWithName` `Core/Materials/OOShaderMaterial.cpp:121` | ✅ |
| `-[OOShaderMaterial initWithName:configuration:macros:bindingTarget:]` (96) | `OOShaderMaterial::initWithName` `Core/Materials/OOShaderMaterial.cpp:130` | ✅ `OO_TEXTURE_UNIT_COUNT`, source/name lookup, `(null)` in cache key, log classes, uGloss 0.5 / uGammaCorrect float |
| `-[OOShaderMaterial dealloc]` (265) | `~OOShaderMaterial` (default) `Core/Materials/OOShaderMaterial.cpp:300` | ⚠️ no `willDealloc` (see OOMaterial) |
| `-[OOShaderMaterial bindUniform:toObject:property:convertOptions:]` (286) | `OOShaderMaterial::bindUniform` `Core/Materials/OOShaderMaterial.cpp:302` | ✅ |
| `-[OOShaderMaterial bindSafeUniform:toObject:propertyNamed:convertOptions:]` (313) | `OOShaderMaterial::bindSafeUniform` `Core/Materials/OOShaderMaterial.cpp:321` | ❌ class printed as `Entity` |
| `-[OOShaderMaterial setUniform:intValue:]` (334) | `OOShaderMaterial::setUniform(name, int)` `Core/Materials/OOShaderMaterial.cpp:341` | ✅ |
| `-[OOShaderMaterial setUniform:floatValue:]` (354) | `OOShaderMaterial::setUniform(name, float)` `Core/Materials/OOShaderMaterial.cpp:356` | ✅ |
| `-[OOShaderMaterial setUniform:vectorValue:]` (374) | `OOShaderMaterial::setUniform(name, GLfloat[4])` `Core/Materials/OOShaderMaterial.cpp:371` | ✅ |
| `-[OOShaderMaterial setUniform:vectorObjectValue:]` (394) | `OOShaderMaterial::setUniform(name, PList)` `Core/Materials/OOShaderMaterial.cpp:387` | ✅ 4-array → floats, else vector w=1 |
| `-[OOShaderMaterial setUniform:quaternionValue:asMatrix:]` (425) | `OOShaderMaterial::setUniform(name, Quaternion, asMatrix)` `Core/Materials/OOShaderMaterial.cpp:414` | ✅ |
| `-[OOShaderMaterial addUniformsFromDictionary:withBindingTarget:]` (446) | `OOShaderMaterial::addUniformsFromDictionary` `Core/Materials/OOShaderMaterial.cpp:430` | ✅ sorted keys, RANROT save/restore, type defaults, random types, convert-option defaults |
| `-[OOShaderMaterial doApply]` (589) | `OOShaderMaterial::doApply` `Core/Materials/OOShaderMaterial.cpp:585` | ✅ |
| `-[OOShaderMaterial ensureFinishedLoading]` (617) | `OOShaderMaterial::ensureFinishedLoading` `Core/Materials/OOShaderMaterial.cpp:613` | ✅ |
| `-[OOShaderMaterial isFinishedLoading]` (628) | `OOShaderMaterial::isFinishedLoading` `Core/Materials/OOShaderMaterial.cpp:623` | ✅ |
| `-[OOShaderMaterial unapplyWithNext:]` (642) | `OOShaderMaterial::unapplyWithNext` `Core/Materials/OOShaderMaterial.cpp:636` | ✅ |
| `-[OOShaderMaterial setBindingTarget:]` (669) | `OOShaderMaterial::setBindingTarget` `Core/Materials/OOShaderMaterial.cpp:663` | ✅ forwards to uniforms; the never-read `bindingTarget` ivar is gone |
| `-[OOShaderMaterial permitSpecular]` (676) | `OOShaderMaterial::permitSpecular` `Core/Materials/OOShaderMaterial.cpp:669` | ✅ |
| `-[OOShaderMaterial allTextures]` (682) | `OOShaderMaterial::allTextures` `Core/Materials/OOShaderMaterial.cpp:672` | ✅ |
| `-[OOShaderMaterial(OOPrivate) loadTexturesFromArray:unitCount:]` (692) | `OOShaderMaterial::loadTexturesFromArray` `Core/Materials/OOShaderMaterial.cpp:682` | ✅ nil → null texture |
| `-[OOShaderMaterial(OOPrivate) addTexturesFromArray:unitCount:]` (708) | `OOShaderMaterial::addTexturesFromArray` `Core/Materials/OOShaderMaterial.cpp:699` | ✅ |
| `MacrosToString` (731) | `MacrosToString` `Core/Materials/OOShaderMaterial.cpp:721` | ⚠️ `std::map` key order (comment `:725`) |
| `GetShaderSource` (761) | `GetShaderSource` `Core/Materials/OOShaderMaterial.cpp:756` | ✅ `vertex`/`vert`, `fragment`/`frag`; same not-found log |

**Differences:**

- ❌ **low** — `shader.uniform.unpermittedMethod` names the class as `-[Entity foo]` for every entity: `TargetClassName` → hook `ShaderClassName`, which answers the literal `"Entity"`. Upstream printed `[target class]` (`ShipEntity`, `PlayerEntity`, …) (still open) — upstream `Core/Materials/OOShaderMaterial.m:328` ↔ port `Core/Materials/OOShaderMaterial.cpp:332-335`, `Core/Entities/EntityShaderBindings.cpp:944-947`
- ⚠️ **low** — `MacrosToString` writes the `#define` lines in `std::map` order where upstream used `NSDictionary` hash order (comment `:725`); preprocessing is the same but the prefix text, and so the program cache key, differ (still open) — upstream `Core/Materials/OOShaderMaterial.m:740-747` ↔ port `Core/Materials/OOShaderMaterial.cpp:721-744`
- ⚠️ **low** — `-dealloc`'s `[self willDealloc]` has no counterpart; see OOMaterial (`Core/Materials/OOMaterial.h:126-131`) (still open) — upstream `Core/Materials/OOShaderMaterial.m:265-284` ↔ port `Core/Materials/OOShaderMaterial.cpp:300`
- (fixed since 2026-10-27, reclassified) — the previous ⚠️ for the dropped `bindingTarget` ivar: the ivar was only ever written, never read, so there is no observable difference; the bead comment the previous audit cited is gone. Now ✅ — port `Core/Materials/OOShaderMaterial.cpp:663-667`
- Subtle (✅ low): uniforms apply in `std::map` name order, not `-allValues` hash order (each has its own location); a string `float` value parses as double then narrows; `shader.load.noShader` and `badDescription` print `oo::DescriptionOf()` / the entity hook's description — port `Core/Materials/OOShaderMaterial.cpp:249,520,578,601`

## OOShaderProgram

<a id="ooshaderprogram"></a>
Upstream `src/Core/Materials/OOShaderProgram.m` ↔ `Core/Materials/OOShaderProgram.cpp` (550 / 665 lines)

**Status:** done — 14 rows: 14 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOShaderProgram shaderProgramWithVertexShader:fragmentShader:vertexShaderName:fragmentShaderName:prefix:attributeBindings:cacheKey:]` (69) | `OOShaderProgram::shaderProgramWithVertexShader` `Core/Materials/OOShaderProgram.cpp:107` | ✅ empty prefix → nil; weak cache; nil key never cached |
| `+[OOShaderProgram shaderProgramWithVertexShaderName:fragmentShaderName:prefix:attributeBindings:]` (108) | `OOShaderProgram::shaderProgramWithVertexShaderName` `Core/Materials/OOShaderProgram.cpp:148` | ✅ same `vertex:…\nfragment:…\n----\n` key; macOS 330→120 path |
| `-[OOShaderProgram dealloc]` (164) | `~OOShaderProgram` `Core/Materials/OOShaderProgram.cpp:212` | ✅ uncache, delete program; imbalance log kept |
| `-[OOShaderProgram apply]` (189) | `OOShaderProgram::apply` `Core/Materials/OOShaderProgram.cpp:241` | ✅ |
| `+[OOShaderProgram applyNone]` (201) | `OOShaderProgram::applyNone` `Core/Materials/OOShaderProgram.cpp:251` | ✅ |
| `-[OOShaderProgram program]` (212) | `OOShaderProgram::program` `Core/Materials/OOShaderProgram.cpp:260` | ✅ |
| `ValidateShaderObject` (219) | `ValidateShaderObject` `Core/Materials/OOShaderProgram.cpp:264` | ✅ `shader.link/compile.failure` text, `0x%.4X` ↔ `0x{:04X}` |
| `-[OOShaderProgram(OOPrivate) initWithVertexShaderSource:fragmentShaderSource:prefixString:vertexName:fragmentName:attributeBindings:key:]` (284) | `OOShaderProgram::initWithVertexShaderSource` `Core/Materials/OOShaderProgram.cpp:336` | ✅ `{prefix, "#line 0\n", src}`; `vs/fs` link name |
| `-[OOShaderProgram(OOPrivate) bindAttributes:]` (376) | `OOShaderProgram::bindAttributes` `Core/Materials/OOShaderProgram.cpp:429` | ✅ |
| `-[OOShaderProgram(OOPrivate) bindStandardMatrixUniforms]` (388) | `OOShaderProgram::bindStandardMatrixUniforms` `Core/Materials/OOShaderProgram.cpp:441` | ✅ nil type string compares equal to `mat3`, as nil `compare:` gave 0 |
| `GetShaderSource` (418) | `GetShaderSource` `Core/Materials/OOShaderProgram.cpp:480` | ✅ "failed to find fragment program" copy-paste kept |
| `GetGLSLInfoLog` (458) | `GetGLSLInfoLog` `Core/Materials/OOShaderProgram.cpp:560` | ✅ UTF-8 else Latin-1 of `length-1` bytes |
| `ReplaceRegex` (491) | `ReplaceRegex` `Core/Materials/OOShaderProgram.cpp:599` | ✅ macOS only; std::regex ECMAScript + multiline ↔ ICU AnchorsMatchLines |
| `TranslateGLSL330To120` (502) | `OOTranslateGLSL330To120` `Core/Materials/OOShaderProgram.cpp:608` | ✅ same patterns, reverse replacement order, isnan shim |

**Differences:**

- Subtle (✅): the cache is a never-freed `unordered_map` of raw (non-owning) pointers, erased in the destructor, matching the `NSValue`-wrapped weak cache — port `Core/Materials/OOShaderProgram.cpp:80-95,233-236`
- Subtle (✅ low): `GetGLSLInfoLog` reads at least 1 byte (upstream `malloc(0)` with a zero length was undefined); a NULL object answers `"(null)"`, which is what `%@` of nil printed — port `Core/Materials/OOShaderProgram.cpp:566-573`

## OOShaderUniform

<a id="ooshaderuniform"></a>
Upstream `src/Core/Materials/OOShaderUniform.m` ↔ `Core/Materials/OOShaderUniform.cpp` (542 / 563 lines)

**Status:** done — 14 rows: 10 ✅ 2 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOShaderUniform initWithName:shaderProgram:intValue:]` (50) | `OOShaderUniform::initWithName(…, GLint)` `Core/Materials/OOShaderUniform.cpp:50` | ✅ |
| `-[OOShaderUniform initWithName:shaderProgram:floatValue:]` (61) | `OOShaderUniform::initWithName(…, GLfloat)` `Core/Materials/OOShaderUniform.cpp:64` | ✅ |
| `-[OOShaderUniform initWithName:shaderProgram:vectorValue:]` (72) | `OOShaderUniform::initWithName(…, GLfloat[4])` `Core/Materials/OOShaderUniform.cpp:78` | ✅ |
| `-[OOShaderUniform initWithName:shaderProgram:colorValue:]` (83) | `OOShaderUniform::initWithName(…, OOColor*)` `Core/Materials/OOShaderUniform.cpp:93` | ✅ nil colour → nil |
| `-[OOShaderUniform initWithName:shaderProgram:quaternionValue:asMatrix:]` (102) | `OOShaderUniform::initWithName(…, Quaternion, asMatrix)` `Core/Materials/OOShaderUniform.cpp:114` | ✅ |
| `-[OOShaderUniform initWithName:shaderProgram:matrixValue:]` (121) | `OOShaderUniform::initWithName(…, OOMatrix)` `Core/Materials/OOShaderUniform.cpp:136` | ✅ |
| `-[OOShaderUniform initWithName:shaderProgram:boundToObject:property:convertOptions:]` (132) | `OOShaderUniform::initWithEntityTarget` `Core/Materials/OOShaderUniform.cpp:192` | ⚠️ property kept by name, resolved via member table (comment `:195-198`) |
| `-[OOShaderUniform dealloc]` (179) | `~OOShaderUniform` `Core/Materials/OOShaderUniform.cpp:234` | ✅ |
| `-[OOShaderUniform description]` (188) | `OOShaderUniform::description` `Core/Materials/OOShaderUniform.cpp:236` | ❌ binding prints `Entity`, not the real class |
| `-[OOShaderUniform apply]` (272) | `OOShaderUniform::apply` `Core/Materials/OOShaderUniform.cpp:335` | ✅ |
| `-[OOShaderUniform setBindingTarget:]` (282) | `OOShaderUniform::setEntityBindingTarget` `Core/Materials/OOShaderUniform.cpp:342` | ❌ `laserColor` unbindable; failure reason always one text |
| `-[OOShaderUniform(OOPrivate) initWithName:shaderProgram:]` (364) | `OOShaderUniform::initWithName(name, program)` `Core/Materials/OOShaderUniform.cpp:391` | ✅ |
| `-[OOShaderUniform(OOPrivate) applySimple]` (394) | `OOShaderUniform::applySimple` `Core/Materials/OOShaderUniform.cpp:413` | ✅ |
| `-[OOShaderUniform(OOPrivate) applyBinding]` (414) | `OOShaderUniform::applyBinding` `Core/Materials/OOShaderUniform.cpp:432` | ⚠️ Object type sets nothing; colour via new `kOOShaderUniformTypeColor` (comment `:529-532`) |

**Differences:**

- ❌ **med** — **`laserColor` still cannot be bound.** It is whitelisted (`Resources/Config/whitelist.plist:420`) and typed `color` (`shader-uniform-bindings.plist:57`); upstream bound it through `-[ShipEntity laserColor]` (`id` → Object → OOColor → vec4). `kEntityShaderBindings` has 86 rows for the 87 whitelisted names and the only one missing is `laserColor`. The comment at `EntityShaderBindings.cpp:98` says "laserColor has no method and no row", but `ShipEntity::laserColor()` now exists (`Core/Entities/ShipEntity.cpp:10937`). So `setEntityBindingTarget` finds no row, logs `shader.uniform.bind.failed … (target does not respond to selector)` and leaves the uniform inactive. OXP shaders that read `laserColor` get the GLSL default. (still open) — upstream `Core/Materials/OOShaderUniform.m:282-361`, `Core/Entities/ShipEntity.m:10152` ↔ port `Core/Materials/OOShaderUniform.cpp:362-387`, `Core/Entities/EntityShaderBindings.cpp:94-99,150`
- ❌ **low** — the `shader.uniform.bind.failed` reason is always "target does not respond to selector", where upstream told apart `unsupported type "<enc>"`, the argument-count problem and the missing-IMP problem; the class is printed as `Entity` (still open) — upstream `Core/Materials/OOShaderUniform.m:346-356` ↔ port `Core/Materials/OOShaderUniform.cpp:381-387`
- ❌ **low** — `description` (logged by `shader.uniform.set`) prints a binding as `[<Entity 0x…> prop]` where upstream printed `[<ShipEntity 0x…> prop]` (still open) — upstream `Core/Materials/OOShaderUniform.m:197` ↔ port `Core/Materials/OOShaderUniform.cpp:240-248`
- ⚠️ **low** — the selector initialiser became `initWithEntityTarget`, which keeps the property *name* and resolves it per target through the entity hooks and the member table (comment `:195-198`). The null checks, the location -1 log line, the convert-option bits and bind-to-super are the same (still open) — port `Core/Materials/OOShaderUniform.cpp:192-232`
- ⚠️ **low** — in `applyBinding`, a `kOOShaderUniformTypeObject` binding sets nothing; upstream sent an `NSNumber` result as a float. The comment says no bindable method returns a number; colours use `kOOShaderUniformTypeColor` (still open) — upstream `Core/Materials/OOShaderUniform.m:506-519` ↔ port `Core/Materials/OOShaderUniform.cpp:528-543`
- Subtle (✅, new): `setEntityBindingTarget` logs the failure only when the hook's class name is not `"(null)"` (an entity with no object); upstream logged for any non-nil target. The port also has a C++-target factory (`:150`) with no upstream counterpart; nothing in `Core/` calls it — port `Core/Materials/OOShaderUniform.cpp:150-190,381-382`

## OOShaderUniformMethodType

<a id="ooshaderuniformmethodtype"></a>
Upstream `src/Core/Materials/OOShaderUniformMethodType.m` ↔ `Core/Materials/OOShaderUniformMethodType.cpp` (280 / 116 lines)

**Status:** done — 21 rows: 0 ✅ 2 ⚠️ 0 ❌ 19 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOShaderUniformTypeFromMethodSignature` (59) | `OOShaderUniformTypeFromEncoding` `Core/Materials/OOShaderUniformMethodType.cpp:56` | ⚠️ compares a row's `@encode` literal, not a method signature |
| `InitTemplates` (100) | `InitTemplates` `Core/Materials/OOShaderUniformMethodType.cpp:86` | ⚠️ `kOOTypeEncoding<T>` literals; new `Color` slot before `Object` |
| `CopyTemplateForSelector` (127) | none | ➖ templates are static literals |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass signedCharMethod]` (143) | `kOOTypeEncoding<signed char>` `Core/Materials/OOShaderUniformMethodType.cpp:93` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass unsignedCharMethod]` (148) | `kOOTypeEncoding<unsigned char>` `:94` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass signedShortMethod]` (153) | `kOOTypeEncoding<signed short>` `:95` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass unsignedShortMethod]` (158) | `kOOTypeEncoding<unsigned short>` `:96` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass signedIntMethod]` (163) | `kOOTypeEncoding<signed int>` `:97` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass unsignedIntMethod]` (168) | `kOOTypeEncoding<unsigned int>` `:98` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass signedLongMethod]` (173) | `kOOTypeEncoding<signed long>` `:99` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass unsignedLongMethod]` (178) | `kOOTypeEncoding<unsigned long>` `:100` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass floatMethod]` (183) | `kOOTypeEncoding<float>` `:101` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass doubleMethod]` (188) | `kOOTypeEncoding<double>` `:102` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass vectorMethod]` (193) | `kOOTypeEncoding<Vector>` `:103` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass hpvectorMethod]` (199) | `kOOTypeEncoding<HPVector>` `:104` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass quaternionMethod]` (205) | `kOOTypeEncoding<Quaternion>` `:105` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass matrixMethod]` (211) | `kOOTypeEncoding<OOMatrix>` `:106` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass pointMethod]` (216) | `kOOTypeEncoding<NSPoint>` `:107` | ➖ |
| `-[OOShaderUniformTypeMethodSignatureTemplateClass idMethod]` (221) | `kOOTypeEncoding<OOObjCId>` `:111` | ➖ |
| `OOCallIntegerMethod` (228) | `StoreShaderBindingValue` `Core/Entities/EntityShaderBindings.cpp:117` | ➖ row getters fill `OOShaderBindingValue.i` |
| `OOCallFloatMethod` (266) | `StoreShaderBindingValue` `Core/Entities/EntityShaderBindings.cpp:117` | ➖ fills `.f` |

**Differences:**

- ⚠️ **low** — dispatch by selector is replaced by a static member table; each row's type is `@encode()` of the replaced method's return type (`kOOTypeEncoding<>`, `Core/OOTypeEncodings.h`; described in the file comment `:28-39`). The template set is unchanged apart from the new `kOOShaderUniformTypeColor` (`OOColor*`), inserted before `Object`. As upstream, `long long`/`unsigned long long` have no template (still open) — upstream `Core/Materials/OOShaderUniformMethodType.m:59-125` ↔ port `Core/Materials/OOShaderUniformMethodType.cpp:56-114`
- **Bindability check (re-run):** every name in the four `shader_*_binding_methods` whitelists was compared with `kEntityShaderBindings`: 86 of 87 names have a row, the missing one is still `laserColor` (see OOShaderUniform ❌ med), and there is no row that is not whitelisted.
- Subtle (✅): `StoreShaderBindingValue` sign-extends `signed char` (BOOL) as the `CharReturnMsgSend` call did, and widens other integers/enums to `long long`; floating types go to `f` — port `Core/Entities/EntityShaderBindings.cpp:117-140`

## OOSingleTextureMaterial

<a id="oosingletexturematerial"></a>
Upstream `src/Core/Materials/OOSingleTextureMaterial.m` ↔ `Core/Materials/OOSingleTextureMaterial.cpp` (115 / 121 lines)

**Status:** done — 10 rows: 9 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOSingleTextureMaterial initWithName:configuration:]` (35) | `OOSingleTextureMaterial::initWithName(name, configuration)` `Core/Materials/OOSingleTextureMaterial.cpp:52` | ✅ `diffuse_map` spec with default name; no config → name is the spec |
| `-[OOSingleTextureMaterial initWithName:texture:configuration:]` (50) | `OOSingleTextureMaterial::initWithName(name, texture, configuration)` `Core/Materials/OOSingleTextureMaterial.cpp:69` | ✅ nil name or texture → fail (factory returns null) |
| `-[OOSingleTextureMaterial dealloc]` (64) | implicit destructor | ⚠️ no `willDealloc` (see OOMaterial) |
| `-[OOSingleTextureMaterial descriptionComponents]` (72) | `OOSingleTextureMaterial::descriptionComponents` `Core/Materials/OOSingleTextureMaterial.cpp:82` | ✅ |
| `-[OOSingleTextureMaterial doApply]` (77) | `OOSingleTextureMaterial::doApply` `Core/Materials/OOSingleTextureMaterial.cpp:89` | ✅ |
| `-[OOSingleTextureMaterial unapplyWithNext:]` (86) | `OOSingleTextureMaterial::unapplyWithNext` `Core/Materials/OOSingleTextureMaterial.cpp:96` | ✅ |
| `-[OOSingleTextureMaterial ensureFinishedLoading]` (93) | `OOSingleTextureMaterial::ensureFinishedLoading` `Core/Materials/OOSingleTextureMaterial.cpp:103` | ✅ |
| `-[OOSingleTextureMaterial isFinishedLoading]` (98) | `OOSingleTextureMaterial::isFinishedLoading` `Core/Materials/OOSingleTextureMaterial.cpp:107` | ✅ nil texture → NO as nil message |
| `-[OOSingleTextureMaterial wantsNormalsAsTextureCoordinates]` (103) | `OOSingleTextureMaterial::wantsNormalsAsTextureCoordinates` `Core/Materials/OOSingleTextureMaterial.cpp:111` | ✅ |
| `-[OOSingleTextureMaterial allTextures]` (109) | `OOSingleTextureMaterial::allTextures` `Core/Materials/OOSingleTextureMaterial.cpp:116` | ✅ texture is never null after init |

**Differences:**

- ⚠️ **low** — `-dealloc`'s `[self willDealloc]` has no counterpart; same rationale as OOMaterial (`Core/Materials/OOMaterial.h:126-131`). The local comment the previous audit cited is gone (still open) — upstream `Core/Materials/OOSingleTextureMaterial.m:64-70` ↔ port none
- Subtle (✅): `textureWithConfiguration(texSpec).get()` passes a raw pointer from a temporary `shared_ptr`; the callee re-shares it with `oo::share` before the temporary dies, so ownership is kept — port `Core/Materials/OOSingleTextureMaterial.cpp:65-74`

## OOStandaloneAtmosphereGenerator

<a id="oostandaloneatmospheregenerator"></a>
Upstream `src/Core/Materials/OOStandaloneAtmosphereGenerator.m` ↔ `Core/Materials/OOStandaloneAtmosphereGenerator.cpp` (753 / 747 lines)

**Status:** done — 26 rows: 24 ✅ 1 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOStandaloneAtmosphereGenerator initWithPlanetInfo:]` (95) | `OOStandaloneAtmosphereGenerator::initWithPlanetInfo` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:102` | ⚠️ seed is a parameter (comment `:113`) |
| `+[OOStandaloneAtmosphereGenerator planetTextureWithInfo:]` (129) | `planetTextureWithInfo` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:146` | ✅ |
| `+[OOStandaloneAtmosphereGenerator generateAtmosphereTexture:withInfo:]` (141) | `generateAtmosphereTexture` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:158` | ✅ |
| `-[OOStandaloneAtmosphereGenerator dealloc]` (154) | implicit destructor | ✅ |
| `-[OOStandaloneAtmosphereGenerator descriptionComponents]` (159) | `descriptionComponents` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:173` | ✅ |
| `-[OOStandaloneAtmosphereGenerator textureOptions]` (164) | `textureOptions` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:177` | ✅ |
| `-[OOStandaloneAtmosphereGenerator cacheKey]` (169) | `cacheKey` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:181` | ✅ same format, `%f` ↔ `{:f}` |
| `-[OOStandaloneAtmosphereGenerator getResult:format:width:height:]` (180) | `getResultFormatWidthHeight` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:192` | ✅ dead in both (does not override) |
| `-[OOStandaloneAtmosphereGenerator loadTexture]` (204) | `loadTexture` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:219` | ✅ token-identical loop |
| `-[OOStandaloneAtmosphereGenerator dumpNoiseBuffer:]` (287) | `dumpNoiseBuffer` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:302` | ✅ debug dump |
| `Lerp` (311) | `Lerp` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:322` | ✅ |
| `Blend` (317) | `Blend` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:328` | ✅ |
| `BlendAlpha` (326) | `BlendAlpha` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:333` | ✅ |
| `CloudMix` (331) | `CloudMix` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:337` | ✅ |
| `FloatRGBFromDictColor` (377) | `FloatRGBFromDictColor` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:391` | ❌ non-colour → black |
| `Hermite` (385) | `Hermite` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:409` | ✅ |
| `fast_floor` (398) | `fast_floor` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:419` | ✅ `std::bit_cast` |
| `FillFBMBuffer` (407) | `FillFBMBuffer` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:429` | ✅ |
| `TDot3` (475) | `TDot3` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:472` | ✅ |
| `SampleNoise3D` (486) | `SampleNoise3D` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:483` | ✅ |
| `MakePermutationTable` (569) | `MakePermutationTable` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:568` | ✅ |
| `GenerateFBMNoise3D` (594) | `GenerateFBMNoise3D` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:591` | ✅ |
| `FillRandomBuffer` (655) | `FillRandomBuffer` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:649` | ✅ |
| `AddNoise` (663) | `AddNoise` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:656` | ✅ |
| `GenerateFBMNoise` (707) | `GenerateFBMNoise` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:703` | ✅ |
| `QFactor` (742) | `QFactor` `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:738` | ✅ |

**Differences:**

- ⚠️ **low** — the seed is a parameter rather than `noise_map_seed` in `planetInfo` (comment `:113`) (still open) — upstream `Core/Materials/OOStandaloneAtmosphereGenerator.m:102` ↔ port `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:113`
- ❌ **low** — `FloatRGBFromDictColor`: a non-`OOColor` value now gives black where upstream would have thrown (release build); same as OOPlanetTextureGenerator (still open) — upstream `Core/Materials/OOStandaloneAtmosphereGenerator.m:377-383` ↔ port `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:391-405`
- ✅ (emphasis) — a token diff of upstream 311-753 shows only the mechanical changes listed for OOPlanetTextureGenerator (vectors for `malloc`/`calloc`, `bool`, `constexpr`, `std::bit_cast`). The cache-key format and `PLANET_TEXTURE_OPTIONS` are unchanged, and the output buffer is an `OOPixelBuffer` (T017) — port `Core/Materials/OOStandaloneAtmosphereGenerator.cpp:181-189,219-300`

## OOTexture

<a id="ootexture"></a>
Upstream `src/Core/Materials/OOTexture.m` ↔ `Core/Materials/OOTexture.cpp` (884 / 903 lines)

**Status:** done — 51 rows: 40 ✅ 1 ⚠️ 2 ❌ 8 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOTexture textureWithName:inFolder:options:anisotropy:lodBias:]` (132) | `textureWithName` → `nameFactory` → `loadTextureWithName` `Core/Materials/OOTexture.cpp:126,133` (aniso/LOD zeroing, noFNF mask, cache lookup, FNF warning) | ✅ |
| `+[OOTexture textureWithName:inFolder:]` (176) | `textureWithName(name, dir)` `Core/Materials/OOTexture.cpp:181` | ✅ |
| `+[OOTexture textureWithConfiguration:]` (186) | `textureWithConfiguration` → `configurationFactory` → `loadTextureWithConfiguration` `Core/Materials/OOTexture.cpp:189,194` | ✅ |
| `+[OOTexture textureWithConfiguration:extraOptions:]` (191) | `textureWithConfiguration(cfg, extra)` `Core/Materials/OOTexture.cpp:199` | ✅ |
| `+[OOTexture nullTexture]` (204) | `nullTexture` `Core/Materials/OOTexture.cpp:214` | ✅ |
| `+[OOTexture textureWithGenerator:]` (209) | `textureWithGenerator(gen)` `Core/Materials/OOTexture.cpp:220` | ✅ |
| `+[OOTexture textureWithGenerator:enqueue:]` (214) | `textureWithGenerator(gen, enqueue)` `Core/Materials/OOTexture.cpp:225` (same log classes/texts) | ✅ |
| `-[OOTexture init]` (240) | `OOTexture()` `Core/Materials/OOTexture.cpp:251` | ✅ |
| `-[OOTexture dealloc]` (251) | `~OOTexture()` `Core/Materials/OOTexture.cpp:257` | ✅ |
| `-[OOTexture apply]` (258) | `apply` `Core/Materials/OOTexture.cpp:261` | ✅ |
| `+[OOTexture applyNone]` (263) | `applyNone` `Core/Materials/OOTexture.cpp:263` | ✅ |
| `-[OOTexture ensureFinishedLoading]` (278) | `ensureFinishedLoading` `Core/Materials/OOTexture.cpp:276` | ✅ |
| `-[OOTexture isFinishedLoading]` (282) | `isFinishedLoading` `Core/Materials/OOTexture.cpp:278` | ✅ |
| `-[OOTexture cacheKey]` (287) | `cacheKey` `Core/Materials/OOTexture.cpp:280` | ✅ |
| `-[OOTexture dimensions]` (292) | `dimensions` `Core/Materials/OOTexture.cpp:282` | ✅ |
| `-[OOTexture originalDimensions]` (298) | `originalDimensions` `Core/Materials/OOTexture.cpp:287` | ✅ |
| `-[OOTexture isMipMapped]` (303) | `isMipMapped` `Core/Materials/OOTexture.cpp:289` | ✅ |
| `-[OOTexture copyPixMapRepresentation]` (309) | `copyPixMapRepresentation` `Core/Materials/OOTexture.cpp:294` | ✅ |
| `-[OOTexture isRectangleTexture]` (314) | `isRectangleTexture` `Core/Materials/OOTexture.cpp:296` | ✅ |
| `-[OOTexture isCubeMap]` (319) | `isCubeMap` `Core/Materials/OOTexture.cpp:298` | ✅ |
| `-[OOTexture texCoordsScale]` (324) | `texCoordsScale` `Core/Materials/OOTexture.cpp:300` | ✅ |
| `-[OOTexture glTextureName]` (329) | `glTextureName` `Core/Materials/OOTexture.cpp:302` | ✅ |
| `+[OOTexture clearCache]` (335) | `clearCache` `Core/Materials/OOTexture.cpp:307` (live cache cleared, recent cache autoreleased) | ✅ |
| `+[OOTexture rebindAllTextures]` (350) | `rebindAllTextures` `Core/Materials/OOTexture.cpp:323` | ✅ |
| `-[OOTexture setTrace:]` (364) | `setTrace` `Core/Materials/OOTexture.cpp:374` | ✅ |
| `+[OOTexture cachedTexturesByAge]` (372) | `cachedTexturesByAge` `Core/Materials/OOTexture.cpp:339` | ✅ |
| `+[OOTexture allTextures]` (377) | `allTextures` `Core/Materials/OOTexture.cpp:349` | ✅ |
| `-[OOTexture dataSize]` (388) | `dataSize` `Core/Materials/OOTexture.cpp:360` | ✅ |
| `-[OOTexture name]` (400) | `name` `Core/Materials/OOTexture.cpp:369` | ✅ |
| `-[OOTexture forceRebind]` (407) | `forceRebind` `Core/Materials/OOTexture.cpp:421` | ✅ |
| `-[OOTexture addToCaches]` (412) | `addToCaches` `Core/Materials/OOTexture.cpp:423` (prune threshold 50, autoPrune, name) | ✅ |
| `-[OOTexture removeFromCaches]` (441) | `removeFromCaches` `Core/Materials/OOTexture.cpp:451` | ✅ |
| `+[OOTexture existingTextureForKey:]` (469) | `existingTextureForKey` `Core/Materials/OOTexture.cpp:487` | ✅ |
| `+[OOTexture checkExtensions]` (481) | `checkExtensions` `Core/Materials/OOTexture.cpp:501` (defaults keys and 0.5 / YES defaults same) | ✅ |
| `-[OOTexture retainInContext:]` (530) | — (no ObjC refcount hooks) | ➖ |
| `-[OOTexture releaseInContext:]` (542) | — | ➖ |
| `-[OOTexture autoreleaseInContext:]` (554) | — | ➖ |
| `-[OOTexture retain]` (566) | — | ➖ |
| `-[OOTexture release]` (571) | — | ➖ |
| `-[OOTexture autorelease]` (576) | — | ➖ |
| `-[NSDictionary(OOTextureConveniences) oo_textureSpecifierForKey:defaultName:]` (586) | helper `Core/Materials/OOMaterialSpecifier.cpp:50-55` (`OOTextureSpecFromObject(ValueFor(…))`) | ➖ |
| `-[NSArray(OOTextureConveniences) oo_textureSpecifierAtIndex:defaultName:]` (595) | — (callers call `OOTextureSpecFromObject` directly) | ➖ |
| `OOTextureSpecFromObject` (602) | `OOTextureSpecFromObject` `Core/Materials/OOTexture.cpp:565` (nil default → null; string/number name test) | ✅ |
| `OOTextureComponentsForFormat` (624) | `OOTextureComponentsForFormat` `Core/Materials/OOTexture.cpp:592` | ✅ |
| `OOCubeMapsAvailable` (643) | `OOCubeMapsAvailable` `Core/Materials/OOTexture.cpp:610` | ✅ |
| `OOInterpretTextureSpecifier` (648) | `OOInterpretTextureSpecifier` `Core/Materials/OOTexture.cpp:612` | ❌ |
| `OOMakeTextureSpecifier` (736) | `OOMakeTextureSpecifier` `Core/Materials/OOTexture.cpp:723` | ✅ |
| `OOApplyTextureOptionDefaults` (819) | `OOApplyTextureOptionDefaults` `Core/Materials/OOTexture.cpp:820` | ✅ |
| `OOGenerateTextureCacheKey` (862) | `OOGenerateTextureCacheKey` `Core/Materials/OOTexture.cpp:869` (`{:04X}`/`{:g}` = `%.4X`/`%g`) | ✅ |
| `OOTextureCacheKeyForSpecifier` (875) | `OOTextureCacheKeyForSpecifier` `Core/Materials/OOTexture.cpp:891` | ⚠️ |
| `-[NSObject(OOExtensions) shortDescription]` (inherited, `Core/OOFoundation.m:59`) | `OOTexture::shortDescription` `Core/Materials/OOTexture.cpp:410` | ❌ |

**Differences:**

- ❌ **low** — Bad-specifier log text differs: `__PRETTY_FUNCTION__` is the full C++ signature, and "got %@" prints the plist type name (or `(null)` for Object nodes) instead of the ObjC class name. Log class unchanged. (still open) — upstream `Core/Materials/OOTexture.m:717` ↔ port `Core/Materials/OOTexture.cpp:704-709`
- ❌ **low** — `shortDescription()` hard-codes `<OOTexture 0x…>`; upstream used `[self class]` (e.g. `<OOConcreteTexture …>`). `description()` uses the demangled class. (still open) — upstream `Core/OOFoundation.m:65` ↔ port `Core/Materials/OOTexture.cpp:410-417`
- ⚠️ **low** — `OOTextureCacheKeyForSpecifier` zero-initialises its outputs for an unparseable specifier (port comment); upstream left them uninitialised (UB). (still open) — upstream `:877-883` ↔ port `:891-902`
- ➖ **low** — Debug-monitor retain/release/autorelease tracing (`texture.allocTrace.retain/release/autoreleased`) is gone; `setTrace` (`allocTrace.begin`, now with `weak_from_this().use_count()`) remains. (still open) — upstream `:530-579` ↔ port —
- ✅ (subtle) — `rebindAllTextures` moves the recent cache into a local that dies at function end, so textures held only by it are released after the `forceRebind` loop rather than before (upstream `DESTROY` released first). Those textures just get a redundant rebind; the loop iterates a copy, so no dangling access. — upstream `:356` ↔ port `:326-335`
- ✅ (subtle, upstream bug preserved) — `OOMakeTextureSpecifier` still stores the min-filter name under the `no_shrink` key. upstream `:768` ↔ port `:763`
- ✅ (subtle) — The 2-arg `textureWithName` and `textureWithConfiguration:extraOptions:` call `loadTextureWithName` directly, bypassing the test-only `nameFactory` hook; production behaviour identical. port `:181-212`

## OOTextureGenerator

<a id="ootexturegenerator"></a>
Upstream `src/Core/Materials/OOTextureGenerator.m` ↔ `Core/Materials/OOTextureGenerator.cpp` (58 / 48 lines)

**Status:** done — 5 rows: 5 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOTextureGenerator textureOptions]` (33) | `textureOptions` `Core/Materials/OOTextureGenerator.cpp:33` | ✅ |
| `-[OOTextureGenerator anisotropy]` (38) | `anisotropy` `Core/Materials/OOTextureGenerator.cpp:37` | ✅ |
| `-[OOTextureGenerator lodBias]` (43) | `lodBias` `Core/Materials/OOTextureGenerator.cpp:39` | ✅ |
| `-[OOTextureGenerator cacheKey]` (48) | `cacheKey` `Core/Materials/OOTextureGenerator.cpp:41` (nil → nullopt) | ✅ |
| `-[OOTextureGenerator enqueue]` (53) | `enqueue` `Core/Materials/OOTextureGenerator.cpp:45` (medium priority) | ✅ |

**Differences:**

- ✅ (note) — All five bodies are one-liners with the same constants and the same `addTask(…, kMedium)` call. upstream `Core/Materials/OOTextureGenerator.m:33-56` ↔ port `Core/Materials/OOTextureGenerator.cpp:33-48`

## OOTextureLoader

<a id="ootextureloader"></a>
Upstream `src/Core/Materials/OOTextureLoader.m` ↔ `Core/Materials/OOTextureLoader.cpp` (505 / 546 lines)

**Status:** done — 18 rows: 17 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOTextureLoader loaderWithPath:options:]` (70) | `loaderWithPath` `Core/Materials/OOTextureLoader.cpp:71` (png-only, same log, addTask medium) | ✅ |
| `+[OOTextureLoader loaderWithTextureSpecifier:extraOptions:folder:]` (99) | `loaderWithTextureSpecifier` `Core/Materials/OOTextureLoader.cpp:108` (FNF warn + standards error) | ✅ |
| `-[OOTextureLoader initWithPath:options:]` (120) | `initWithPath` `Core/Materials/OOTextureLoader.cpp:137` (thresholds, extract-channel switch, error text) | ✅ |
| `-[OOTextureLoader dealloc]` (179) | `~OOTextureLoader` `Core/Materials/OOTextureLoader.cpp:197` (owned buffer) | ✅ |
| `-[OOTextureLoader descriptionComponents]` (189) | `descriptionComponents` `Core/Materials/OOTextureLoader.cpp:199` | ✅ |
| `-[OOTextureLoader shortDescriptionComponents]` (209) | `shortDescriptionComponents` `Core/Materials/OOTextureLoader.cpp:217` | ✅ |
| `-[OOTextureLoader path]` (214) | `path` `Core/Materials/OOTextureLoader.cpp:255` | ✅ |
| `-[OOTextureLoader isReady]` (219) | `isReady` `Core/Materials/OOTextureLoader.cpp:257` | ✅ |
| `-[OOTextureLoader getResult:format:originalWidth:originalHeight:]` (224) | `getResult` `Core/Materials/OOTextureLoader.cpp:259` | ✅ |
| `-[OOTextureLoader cacheKey]` (258) | `cacheKey` `Core/Materials/OOTextureLoader.cpp:292` (`%@:0x%.4X` → `{}:0x{:04X}`) | ✅ |
| `-[OOTextureLoader loadTexture]` (263) | `loadTexture` `Core/Materials/OOTextureLoader.cpp:297` | ✅ |
| `+[OOTextureLoader setUp]` (268) | `setUp` `Core/Materials/OOTextureLoader.cpp:299` | ✅ |
| `-[OOTextureLoader performAsyncTask]` (288) | `performAsyncTask` `Core/Materials/OOTextureLoader.cpp:326` | ✅ |
| `-[OOTextureLoader generateMipMapsForCubeMap]` (316) | `generateMipMapsForCubeMap` `Core/Materials/OOTextureLoader.cpp:357` | ✅ |
| `-[OOTextureLoader applySettings]` (347) | `applySettings` `Core/Materials/OOTextureLoader.cpp:383` | ✅ |
| `-[OOTextureLoader getDesiredWidth:andHeight:]` (445) | `getDesiredWidth` `Core/Materials/OOTextureLoader.cpp:494` | ✅ |
| `-[OOTextureLoader completeAsyncTask]` (500) | `completeAsyncTask` `Core/Materials/OOTextureLoader.cpp:546` | ✅ |
| `-[NSObject(OOExtensions) shortDescription]` (inherited, `Core/OOFoundation.m:59`) | `OOTextureLoader::shortDescription` `Core/Materials/OOTextureLoader.cpp:242` | ❌ |

**Differences:**

- ❌ **low** — `shortDescription()` prints the facade name `<OOTextureLoader …>` / `<OOTextureGenerator …>` rather than the concrete class (`[self class]`, e.g. `<OOPNGTextureLoader …>`); `description()` uses the demangled class. Seen in debug descriptions (e.g. `OOCombinedEmissionMapGenerator`). (still open) — upstream `Core/OOFoundation.m:65` ↔ port `Core/Materials/OOTextureLoader.cpp:242-253`
- ✅ (subtle) — `generateMipMapsForCubeMap` no longer has the `malloc`-failure branch (turn off mipmaps, switch min filter to linear); `OOMakePixelBuffer` failure is now an allocation exception. Only reachable on out-of-memory. — upstream `Core/Materials/OOTextureLoader.m:327-332` ↔ port `Core/Materials/OOTextureLoader.cpp:369`
- ✅ (emphasis: sizing arithmetic) — `getDesiredWidth` (`(2*w)/3` power-of-two rounding, `sGLMaxSize/8`, `sUserMaxSize/4`, 256 cube halving, shrink thresholds 512/128, cap 256), cube→lat/long `MIN(w*2,512)` halved above 256, and mip buffer `w*c*h*4/3 + 1` are verbatim. upstream `:316-498` ↔ port `:357-544`
- ✅ (emphasis: async/exceptions) — `performAsyncTask` catches only `OOException` (like `@catch (NSException*)`) and rethrows others; same log classes and texts. `max-texture-size` default `0x80000000`, min 64. upstream `:268-313` ↔ port `:299-355`

## OOConvertCubeMapToLatLong

<a id="ooconvertcubemaptolatlong"></a>
Upstream `src/Core/OOConvertCubeMapToLatLong.m` ↔ `Core/OOConvertCubeMapToLatLong.cpp` (146 / 153 lines)

**Status:** done — 1 rows: 1 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOConvertCubeMapToLatLong` (35) | `OOConvertCubeMapToLatLong` `Core/OOConvertCubeMapToLatLong.cpp:39` (line-for-line; VLAs → `std::vector<float>`) | ✅ |

**Differences:**

- ✅ (note) — Same validity guard, `height*=2`, `width*3/4 - y` latitude index, face selection and sign flips, `(x*r+1)*halfSize` truncation, and final half-size `OOScalePixMap`. Only the sin/cos tables changed container type and `NSCParameterAssert` → `OOCParameterAssert`. upstream `Core/OOConvertCubeMapToLatLong.m:35-146` ↔ port `Core/OOConvertCubeMapToLatLong.cpp:39-153`

## OODebugGLDrawing

<a id="oodebuggldrawing"></a>
Upstream `src/Core/OODebugGLDrawing.m` ↔ `Core/OODebugGLDrawing.cpp` (160 / 160 lines)

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `ApplyColor` (34) | `ApplyColor` `Core/OODebugGLDrawing.cpp:38` (nil → `lightGrayColor`) | ✅ |
| `OODebugDrawColoredBoundingBoxBetween` (46) | `OODebugDrawColoredBoundingBoxBetween` `Core/OODebugGLDrawing.cpp:49` (same 8+8 vertex order) | ✅ |
| `OODebugDrawColoredLine` (76) | `OODebugDrawColoredLine` `Core/OODebugGLDrawing.cpp:79` | ✅ |
| `OODebugDrawBasis` (91) | `OODebugDrawBasis` `Core/OODebugGLDrawing.cpp:93` | ✅ |
| `OODebugDrawPoint` (113) | `OODebugDrawPoint` `Core/OODebugGLDrawing.cpp:114` (point size 10) | ✅ |
| `OODebugBeginWireframe` (128) | `OODebugBeginWireframe` `Core/OODebugGLDrawing.cpp:128` (same attrib mask, ignoreZ branches, line width 1) | ✅ |
| `OODebugEndWireframe` (153) | `OODebugEndWireframe` `Core/OODebugGLDrawing.cpp:154` | ✅ |

**Differences:**

- ✅ (note) — The current material is held +1 (`OOMaterialRetainCurrent`) and re-applied/released by `OOMaterialApplyAndRelease` after `glPopAttrib`, in the same order as upstream's `[OOMaterial current]` … `[state.material apply]`. upstream `Core/OODebugGLDrawing.m:132,157` ↔ port `Core/OODebugGLDrawing.cpp:132,157`

## OODrawable

<a id="oodrawable"></a>
Upstream `src/Core/OODrawable.m` ↔ `Core/OODrawable.cpp` (86 / 84 lines)

**Status:** done — 11 rows: 10 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OODrawable renderOpaqueParts]` (33) | `OODrawable::renderOpaqueParts` `Core/OODrawable.cpp:37` | ✅ |
| `-[OODrawable renderTranslucentParts]` (37) | `OODrawable::renderTranslucentParts` `Core/OODrawable.cpp:39` | ✅ |
| `-[OODrawable hasOpaqueParts]` (41) | `OODrawable::hasOpaqueParts` `Core/OODrawable.cpp:41` | ✅ |
| `-[OODrawable hasTranslucentParts]` (46) | `OODrawable::hasTranslucentParts` `Core/OODrawable.cpp:43` | ✅ |
| `-[OODrawable collisionRadius]` (51) | `OODrawable::collisionRadius` `Core/OODrawable.cpp:45` | ✅ |
| `-[OODrawable maxDrawDistance]` (56) | `OODrawable::maxDrawDistance` `Core/OODrawable.cpp:47` | ✅ |
| `-[OODrawable boundingBox]` (61) | `OODrawable::boundingBox` `Core/OODrawable.cpp:49` | ✅ |
| `-[OODrawable setBindingTarget:]` (66) | `OODrawable::setBindingTarget` `Core/OODrawable.cpp:51` | ✅ |
| `-[OODrawable dumpSelfState]` (70) | `OODrawable::dumpSelfState` `Core/OODrawable.cpp:53` | ✅ |
| `-[OODrawable allTextures]` (75) | `OODrawable::allTextures` `Core/OODrawable.cpp:71` (nil → empty vector) | ✅ |
| `-[OODrawable totalSize]` (80) | `OODrawable::totalSize` `Core/OODrawable.cpp:74` → `objectSize()` `Core/OODrawable.h:95` | ⚠️ |

**Differences:**

- ⚠️ **low** — Debug-monitor-only `totalSize` uses virtual `objectSize()` (`sizeof *this`, "each subclass answering its own" per header comment) instead of `-oo_objectSize` (runtime instance size), so reported byte counts can differ. (still open; previous bead citation oo-9ht.9 no longer in the header) — upstream `Core/OODrawable.m:80` ↔ port `Core/OODrawable.cpp:74`, `Core/OODrawable.h:93-95`
- ✅ (note) — Port adds `description()`/`descriptionComponents()` and `OODrawableAutorelease`, which replace NSObject behaviour and are not rows of this file. port `Core/OODrawable.cpp:55-84`

## OOEnvironmentCubeMap

<a id="ooenvironmentcubemap"></a>
Upstream `src/Core/OOEnvironmentCubeMap.m` ↔ *(none — never in the upstream build; deleted as dead code, note at `Core/Universe.cpp:11509-11511`)*

**Status:** done — 10 rows: 0 ✅ 0 ⚠️ 0 ❌ 10 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOEnvironmentCubeMap initWithSideLength:]` (55) | — (deleted) | ➖ |
| `-[OOEnvironmentCubeMap dealloc]` (69) | — (deleted) | ➖ |
| `-[OOEnvironmentCubeMap render]` (76) | — (deleted) | ➖ |
| `-[OOEnvironmentCubeMap renderOnePassWithSky:sun:planets:]` (130) | — (deleted) | ➖ |
| `-[OOEnvironmentCubeMap setUp]` (166) | — (deleted) | ➖ |
| `-[OOEnvironmentCubeMap apply]` (216) | — (deleted) | ➖ |
| `-[OOEnvironmentCubeMap dimensions]` (222) | — (deleted) | ➖ |
| `-[OOEnvironmentCubeMap forceRebind]` (227) | — (deleted) | ➖ |
| `-[OOEnvironmentCubeMap isCubeMap]` (240) | — (deleted) | ➖ |
| `-[OOEnvironmentCubeMap copyPixMapRepresentation]` (245) | — (deleted) | ➖ |

**Differences:**

- ➖ **low** — Class gone with no replacement, matching the upstream binary: `OOEnvironmentCubeMap.m` is absent from upstream `src/Core/meson.build` (which lists `OOConvertCubeMapToLatLong.m` at :38), and the only upstream reference is a TODO comment (`Core/Universe.m:474`), kept in the port at `Core/Universe.cpp:11509`. No observable change. (still open, unchanged)

## OOGraphicsResetManager

<a id="oographicsresetmanager"></a>
Upstream `src/Core/OOGraphicsResetManager.m` ↔ `Core/OOGraphicsResetManager.cpp` (136 / 102 lines)

**Status:** done — 11 rows: 4 ✅ 1 ⚠️ 0 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOGraphicsResetManager dealloc]` (36) | `~OOGraphicsResetManager` `Core/OOGraphicsResetManager.cpp:42` | ✅ |
| `+[OOGraphicsResetManager sharedManager]` (45) | `sharedManager` `Core/OOGraphicsResetManager.cpp:46` (lazy, never freed) | ✅ |
| `-[OOGraphicsResetManager registerClient:]` (52) | `registerCxxClient` `Core/OOGraphicsResetManager.cpp:57` (null ignored) | ✅ |
| `-[OOGraphicsResetManager unregisterClient:]` (61) | `unregisterCxxClient` `Core/OOGraphicsResetManager.cpp:63` | ✅ |
| `-[OOGraphicsResetManager resetGraphicsState]` (66) | `resetGraphicsState` `Core/OOGraphicsResetManager.cpp:68` | ⚠️ |
| `+[OOGraphicsResetManager(Singleton) allocWithZone:]` (103) | — not translated (comment `Core/OOGraphicsResetManager.cpp:100-102`) | ➖ |
| `-[OOGraphicsResetManager(Singleton) copyWithZone:]` (112) | — not translated | ➖ |
| `-[OOGraphicsResetManager(Singleton) retain]` (117) | — not translated | ➖ |
| `-[OOGraphicsResetManager(Singleton) retainCount]` (122) | — not translated | ➖ |
| `-[OOGraphicsResetManager(Singleton) release]` (127) | — not translated | ➖ |
| `-[OOGraphicsResetManager(Singleton) autorelease]` (131) | — not translated | ➖ |

**Differences:**

- ⚠️ **low** — `resetGraphicsState` iterates a snapshot and skips clients unregistered mid-reset (port comment); upstream enumerated the live `NSMutableSet`, where mutation during the reset was undefined. Order is hash order in both. (still open) — upstream `Core/OOGraphicsResetManager.m:79-86` ↔ port `Core/OOGraphicsResetManager.cpp:77-94`
- ✅ (note) — Order of work matches: `glFinish`, `rendering.reset.start` + indent, extension-manager `reset`, `rebindAllTextures`, clients, outdent, `rendering.reset.end`. Exception text identical; only `OOException` is caught, others propagate as with NSException-only `@catch`. port `:68-98`

## OOMesh

<a id="oomesh"></a>
Upstream `src/Core/OOMesh.m` ↔ `Core/OOMesh.cpp` (2078 / 2024 lines)

**Status:** done — 66 rows: 61 ✅ 3 ⚠️ 2 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `Profile` (87) | `Profile` `Core/OOMesh.cpp:88` (OOMESH_PROFILE only) | ✅ |
| `IsLegacyNormalMode` (180) | `IsLegacyNormalMode` `Core/OOMesh.cpp:145` | ✅ |
| `IsPerVertexNormalMode` (201) | `IsPerVertexNormalMode` `Core/OOMesh.cpp:165` | ✅ |
| `+[OOMesh meshWithName:cacheKey:materialDictionary:shadersDictionary:smooth:shaderMacros:shaderBindingTarget:]` (223) | `OOMesh::meshWithName` (7-arg) `Core/OOMesh.cpp:184` (scale 1, cacheWriteable YES) | ✅ |
| `+[OOMesh meshWithName:cacheKey:materialDictionary:shadersDictionary:smooth:shaderMacros:shaderBindingTarget:scaleFactor:cacheWriteable:]` (242) | `OOMesh::meshWithName` (9-arg) `Core/OOMesh.cpp:197` | ✅ |
| `+[OOMesh placeholderMaterial]` (263) | `OOMesh::placeholderMaterial` `Core/OOMesh.cpp:208` | ✅ |
| `-[OOMesh init]` (274) | `OOMesh::OOMesh` `Core/OOMesh.cpp:230` | ✅ |
| `-[OOMesh dealloc]` (294) | `OOMesh::~OOMesh` `Core/OOMesh.cpp:243` | ✅ |
| `NormalModeDescription` (326) | `NormalModeDescription` `Core/OOMesh.cpp:262` | ✅ |
| `-[OOMesh descriptionComponents]` (340) | `OOMesh::descriptionComponents` `Core/OOMesh.cpp:277` | ✅ |
| `-[OOMesh copyWithZone:]` (345) | `OOMesh::copyWithZone` `Core/OOMesh.cpp:287` | ✅ |
| `-[OOMesh modelName]` (353) | `OOMesh::modelName` `Core/OOMesh.cpp:295` | ✅ |
| `-[OOMesh vertexCount]` (358) | `OOMesh::getVertexCount` `Core/OOMesh.cpp:297` | ✅ |
| `-[OOMesh faceCount]` (363) | `OOMesh::getFaceCount` `Core/OOMesh.cpp:299` | ✅ |
| `-[OOMesh renderOpaqueParts]` (368) | `OOMesh::renderOpaqueParts` `Core/OOMesh.cpp:301` | ❌ |
| `-[OOMesh rebindMaterials]` (530) | `OOMesh::rebindMaterials` `Core/OOMesh.cpp:486` (placeholder sentinel, deferred release) | ✅ |
| `-[OOMesh materials]` (565) | `OOMesh::getMaterials` `Core/OOMesh.cpp:519` | ✅ |
| `-[OOMesh shaders]` (570) | `OOMesh::shaders` `Core/OOMesh.cpp:521` | ✅ |
| `-[OOMesh hasOpaqueParts]` (575) | `OOMesh::hasOpaqueParts` `Core/OOMesh.cpp:523` | ✅ |
| `-[OOMesh collisionRadius]` (580) | `OOMesh::collisionRadius` `Core/OOMesh.cpp:525` | ✅ |
| `-[OOMesh maxDrawDistance]` (585) | `OOMesh::maxDrawDistance` `Core/OOMesh.cpp:527` | ✅ |
| `-[OOMesh octreeDepth]` (591) | `OOMesh::octreeDepth` `Core/OOMesh.cpp:530` (thresholds 900/20, depths 5/4) | ✅ |
| `-[OOMesh octreeDepth]` (625) | `OOMesh::octreeDepth` `Core/OOMesh.cpp:564` | ✅ |
| `-[OOMesh octree]` (631) | `OOMesh::getOctree` `Core/OOMesh.cpp:567` (nil-key guards inline) | ✅ |
| `-[OOMesh findBoundingBoxRelativeToPosition:ri:rj:rk:selfPosition:si:sj:sk:]` (664) | `OOMesh::findBoundingBoxRelativeToPosition` `Core/OOMesh.cpp:601` | ✅ |
| `-[OOMesh findSubentityBoundingBoxWithPosition:rotMatrix:]` (709) | `OOMesh::findSubentityBoundingBoxWithPosition` `Core/OOMesh.cpp:648` | ✅ |
| `-[OOMesh meshRescaledBy:]` (739) | `OOMesh::meshRescaledBy` `Core/OOMesh.cpp:680` | ✅ |
| `-[OOMesh setBindingTarget:]` (746) | `OOMesh::setBindingTarget` `Core/OOMesh.cpp:687` | ✅ |
| `-[OOMesh dumpSelfState]` (756) | `OOMesh::dumpSelfState` `Core/OOMesh.cpp:698` | ✅ |
| `-[OOMesh allTextures]` (768) | `OOMesh::allTextures` `Core/OOMesh.cpp:710` (vector with duplicates; sole caller inserts into sets, `Core/Debug/OODebugMonitor.cpp:403`) | ✅ |
| `-[OOMesh totalSize]` (779) | `OOMesh::totalSize` `Core/OOMesh.cpp:725` | ✅ |
| `-[OOMesh suppressClangStuff]` (808) | `OOMesh::suppressClangStuff` `Core/OOMesh.cpp:752` | ✅ |
| `-[OOMesh(Private) initWithName:cacheKey:materialDictionary:shadersDictionary:smooth:shaderMacros:shaderBindingTarget:scaleFactor:cacheWriteable:]` (817) | `OOMesh::initWithName` `Core/OOMesh.cpp:756` (`%@-%.3f` octree key) | ✅ |
| `-[OOMesh(Private) mutableCopyWithZone:]` (881) | `OOMesh::mutableCopyWithZone` `Core/OOMesh.cpp:814` (copy ctor, shared buffers, listsReady reset, register) | ✅ |
| `-[OOMesh(Private) deleteDisplayLists]` (913) | `OOMesh::deleteDisplayLists` `Core/OOMesh.cpp:1427` | ✅ |
| `-[OOMesh(Private) resetGraphicsState]` (923) | `OOMesh::resetGraphicsState` `Core/OOMesh.cpp:1436` | ✅ |
| `-[OOMesh(Private) modelData]` (930) | `OOMesh::modelData` `Core/OOMesh.cpp:830` | ⚠️ |
| `-[OOMesh(Private) setModelFromModelData:name:]` (992) | `OOMesh::setModelFromModelData` `Core/OOMesh.cpp:876` | ⚠️ |
| `-[OOMesh(Private) loadData:scaleFactor:]` (1080) | `OOMesh::loadData` `Core/OOMesh.cpp:974` | ❌ |
| `-[OOMesh(Private) checkNormalsAndAdjustWinding]` (1488) | `OOMesh::checkNormalsAndAdjustWinding` `Core/OOMesh.cpp:1676` | ✅ |
| `-[OOMesh(Private) generateFaceTangents]` (1534) | `OOMesh::generateFaceTangents` `Core/OOMesh.cpp:1723` | ✅ |
| `FaceArea` (1571) | `FaceArea` `Core/OOMesh.cpp:1650` | ✅ |
| `-[OOMesh(Private) calculateVertexNormalsAndTangentsWithFaceRefs:]` (1580) | `OOMesh::calculateVertexNormalsAndTangentsWithFaceRefs` `Core/OOMesh.cpp:1767` | ✅ |
| `FaceAreaCorrect` (1619) | `FaceAreaCorrect` `Core/OOMesh.cpp:1660` | ✅ |
| `-[OOMesh(Private) calculateVertexTangentsWithFaceRefs:]` (1634) | `OOMesh::calculateVertexTangentsWithFaceRefs` `Core/OOMesh.cpp:1811` | ✅ |
| `-[OOMesh(Private) getNormal:andTangent:forVertex:inSmoothGroup:]` (1681) | `OOMesh::getNormal` `Core/OOMesh.cpp:1860` | ✅ |
| `-[OOMesh(Private) setUpVertexArrays]` (1706) | `OOMesh::setUpVertexArrays` `Core/OOMesh.cpp:1442` | ✅ |
| `-[OOMesh(Private) calculateBoundingVolumes]` (1786) | `OOMesh::calculateBoundingVolumes` `Core/OOMesh.cpp:1890` | ✅ |
| `-[OOMesh(Private) rescaleByFactor:]` (1827) | `OOMesh::rescaleByFactor` `Core/OOMesh.cpp:1933` | ✅ |
| `-[OOMesh(Private) boundingBox]` (1850) | `OOMesh::boundingBox` `Core/OOMesh.cpp:1955` | ✅ |
| `-[OOMesh(Private) debugDrawNormals]` (1856) | `OOMesh::debugDrawNormals` `Core/OOMesh.cpp:1524` | ✅ |
| `-[OOMesh(Private) setRetainedObject:forKey:]` (1907) | `OOMesh::setRetainedObject` `Core/OOMesh.cpp:1574` | ✅ |
| `Scribble` (1919) | `Scribble` `Core/OOMesh.cpp:1410` (SCRIBBLE 0: no-op in both) | ✅ |
| `-[OOMesh(Private) allocateBytesWithSize:count:key:]` (1941) | `OOMesh::allocateBytesWithSize` `Core/OOMesh.cpp:1582` | ⚠️ |
| `-[OOMesh(Private) allocateVertexBuffersWithCount:]` (1956) | `OOMesh::allocateVertexBuffersWithCount` `Core/OOMesh.cpp:1598` (ignores arg, uses `vertexCount`, as upstream) | ✅ |
| `-[OOMesh(Private) allocateNormalBuffersWithCount:]` (1962) | `OOMesh::allocateNormalBuffersWithCount` `Core/OOMesh.cpp:1604` | ✅ |
| `-[OOMesh(Private) allocateFaceBuffersWithCount:]` (1969) | `OOMesh::allocateFaceBuffersWithCount` `Core/OOMesh.cpp:1612` | ✅ |
| `-[OOMesh(Private) allocateVertexArrayBuffersWithCount:]` (1975) | `OOMesh::allocateVertexArrayBuffersWithCount` `Core/OOMesh.cpp:1618` | ✅ |
| `-[OOMesh(Private) renameTexturesFrom:to:]` (1986) | `OOMesh::renameTexturesFrom` `Core/OOMesh.cpp:1637` | ✅ |
| `+[OOCacheManager(OOMesh) meshDataForName:]` (2006) | `OOCacheManagerMeshDataForName` `Core/OOMesh.cpp:1963` | ✅ |
| `+[OOCacheManager(OOMesh) setMeshData:forName:]` (2011) | `OOCacheManagerSetMeshData` `Core/OOMesh.cpp:1967` | ✅ |
| `+[OOCacheManager(Octree) octreeForModel:]` (2024) | `OOCacheManagerOctreeForModel` `Core/OOMesh.cpp:1981` (nil-key guard at caller `:569`) | ✅ |
| `+[OOCacheManager(Octree) setOctree:forModel:]` (2041) | `OOCacheManagerSetOctree` `Core/OOMesh.cpp:1994` (nil-key guard at caller `:588`) | ✅ |
| `VFRAddFace` (2048) | `VFRAddFace` `Core/OOMesh.cpp:2001` | ✅ |
| `VFRGetCount` (2061) | `VFRGetCount` `Core/OOMesh.cpp:2011` | ✅ |
| `VFRGetFaceAtIndex` (2068) | `VFRGetFaceAtIndex` `Core/OOMesh.cpp:2017` | ✅ |

**Differences:**

- ❌ **low** — `mesh.load.warning.nonTriangular` names the mesh "No Model" where upstream said "(null)": upstream `initWithName:` calls `[super init]`, so `baseFile` is still nil inside `loadData`, while the port constructor sets `baseFile = "No Model"` first. Log text matters to goldens. (still open) — upstream `Core/OOMesh.m:829,1275` ↔ port `Core/OOMesh.cpp:231,1171-1175`
- ❌ **low** — The render exception log prints `__PRETTY_FUNCTION__` as the C++ signature (`void OOMesh::renderOpaqueParts()`) instead of `-[OOMesh renderOpaqueParts]`. Exception path only. (new) — upstream `Core/OOMesh.m:482` ↔ port `Core/OOMesh.cpp:433-436`
- ⚠️ **low** — Mesh-cache data is copied in both directions (file header comment) where upstream aliased the mesh's own buffers; so `meshRescaledBy:` no longer rescales the cached vertices for later loads (an upstream bug). (still open) — upstream `Core/OOMesh.m:949,1049` ↔ port `Core/OOMesh.cpp:5-10,862-869,936-948`
- ⚠️ **low** — `allocateBytesWithSize` zero-fills (`oo::Data::setLength`, commented); upstream `malloc` left memory uninitialised, so unwritten slots after a failed parse are 0, not garbage. (still open) — upstream `Core/OOMesh.m:1947` ↔ port `Core/OOMesh.cpp:1589`
- ✅ (note) — `.dat` tokenizer, section order NVERTS→…→TANGENTS, every `failString` text, cache key `%@:%u:%.3f` in `OOMesh`, octree key/cache, `explicitTangents` never set, and smooth-group/edge-vertex logic all match. port `Core/OOMesh.cpp:974-1407,1442-1521`
- ✅ (note) — `meshRescaledBy` still shares vertex/display buffers with the source via the defaulted copy constructor, so rescaling mutates the source's arrays as `NSCopyObject` did. port `Core/OOMesh.cpp:814-828`

## OOOpenGL

<a id="ooopengl"></a>
Upstream `src/Core/OOOpenGL.m` ↔ `Core/OOOpenGL.cpp` (552 / 557 lines)

**Status:** done — 24 rows: 24 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `OOCheckOpenGLErrors` (38) | `OOCheckOpenGLErrors(fmt, …)` → `OOCheckOpenGLErrors(std::function)` `Core/OOOpenGL.cpp:46,65` (same class, `%#x`→`{:#x}`, noReenter guard) | ✅ |
| `OOGLWireframeModeOn` (85) | `OOGLWireframeModeOn` `Core/OOOpenGL.cpp:111` | ✅ |
| `OOGLWireframeModeOff` (100) | `OOGLWireframeModeOff` `Core/OOOpenGL.cpp:125` | ✅ |
| `GLDrawBallBillboard` (107) | `GLDrawBallBillboard` `Core/OOOpenGL.cpp:131` | ✅ |
| `GLDrawOvalPoints` (132) | `GLDrawOvalPoints` `Core/OOOpenGL.cpp:153` | ✅ |
| `GLDrawOval` (149) | `GLDrawOval` `Core/OOOpenGL.cpp:170` | ✅ |
| `GLDrawFilledOval` (158) | `GLDrawFilledOval` `Core/OOOpenGL.cpp:178` | ✅ |
| `GLDrawPoints` (167) | `GLDrawPoints` `Core/OOOpenGL.cpp:187` | ✅ |
| `GLDrawFilledPoints` (180) | `GLDrawFilledPoints` `Core/OOOpenGL.cpp:199` | ✅ |
| `GLDrawQuadStrip` (193) | `GLDrawQuadStrip` `Core/OOOpenGL.cpp:211` | ✅ |
| `GLScaledLineWidth` (206) | `GLScaledLineWidth` `Core/OOOpenGL.cpp:223` | ✅ |
| `GLScaledPointSize` (212) | `GLScaledPointSize` `Core/OOOpenGL.cpp:228` | ✅ |
| `GLGetDisplayScaleFactor` (218) | `GLGetDisplayScaleFactor` `Core/OOOpenGL.cpp:233` | ✅ |
| `GLSetDisplayScaleFactor` (223) | `GLSetDisplayScaleFactor` `Core/OOOpenGL.cpp:235` | ✅ |
| `LogOpenGLState` (239) | `LogOpenGLState` `Core/OOOpenGL.cpp:250` | ✅ |
| `OOGLColorToString` (270) | `OOGLColorToString` `Core/OOOpenGL.cpp:279` (`%.2ff` → `{:.2f}f`) | ✅ |
| `GLDumpLightState` (292) | `GLDumpLightState` `Core/OOOpenGL.cpp:302` (upstream's always-`GL_LIGHT1` quirk kept) | ✅ |
| `GLDumpMaterialState` (317) | `GLDumpMaterialState` `Core/OOOpenGL.cpp:327` | ✅ |
| `GLDumpCullingState` (380) | `GLDumpCullingState` `Core/OOOpenGL.cpp:392` | ✅ |
| `GLDumpFogState` (402) | `GLDumpFogState` `Core/OOOpenGL.cpp:415` (fog-index-reads-density quirk kept) | ✅ |
| `GLDumpStateFlags` (439) | `GLDumpStateFlags` `Core/OOOpenGL.cpp:448` | ✅ |
| `OOGLEnumToString` (471) | `OOGLEnumToString` `Core/OOOpenGL.cpp:480` | ✅ |
| `OOGLFlagToString` (541) | `OOGLFlagToString` `Core/OOOpenGL.cpp:549` | ✅ |
| `LogOpenGLState` (548) | `LogOpenGLState` (NDEBUG stub) `Core/OOOpenGL.cpp:555` | ✅ |

**Differences:**

- ✅ (subtle) — `OOCheckOpenGLErrors` formats the context once per call; upstream re-ran `initWithFormat:` on the already-formatted string for each further queued error (a bug that only mattered if the context contained `%`). Single-error output is identical, including the `rendering.opengl.error` class and `"OpenGL error: \"%s\" (%#x), context: %@"` text. upstream `Core/OOOpenGL.m:54-69` ↔ port `Core/OOOpenGL.cpp:77-94`

## OOOpenGLExtensionManager

<a id="ooopenglextensionmanager"></a>
Upstream `src/Core/OOOpenGLExtensionManager.m` ↔ `Core/OOOpenGLExtensionManager.cpp` (826 / 947 lines)

**Status:** done — 40 rows: 33 ✅ 1 ⚠️ 0 ❌ 6 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `ArrayOfExtensions` (173) | `ArrayOfExtensions` `Core/OOOpenGLExtensionManager.cpp:247` (empty parts dropped) | ✅ |
| `-[OOOpenGLExtensionManager init]` (187) | implicit ctor + `reset()` called from `sharedManager` `Core/OOOpenGLExtensionManager.cpp:425` | ✅ |
| `-[OOOpenGLExtensionManager reset]` (202) | `OOOpenGLExtensionManager::reset` `Core/OOOpenGLExtensionManager.cpp:265` | ⚠️ |
| `-[OOOpenGLExtensionManager dealloc]` (308) | `~OOOpenGLExtensionManager` `Core/OOOpenGLExtensionManager.cpp:411` | ✅ |
| `+[OOOpenGLExtensionManager sharedManager]` (323) | `sharedManager` `Core/OOOpenGLExtensionManager.cpp:415` (singleton recorded before `reset`, as `allocWithZone:` did) | ✅ |
| `-[OOOpenGLExtensionManager haveExtension:]` (331) | `haveExtension` `Core/OOOpenGLExtensionManager.cpp:430` | ✅ |
| `-[OOOpenGLExtensionManager shadersSupported]` (347) | `shadersSupported` `Core/OOOpenGLExtensionManager.cpp:442` | ✅ |
| `-[OOOpenGLExtensionManager shadersForceDisabled]` (356) | `shadersForceDisabled` `Core/OOOpenGLExtensionManager.cpp:450` | ✅ |
| `-[OOOpenGLExtensionManager defaultDetailLevel]` (365) | `defaultDetailLevel` `Core/OOOpenGLExtensionManager.cpp:458` | ✅ |
| `-[OOOpenGLExtensionManager maximumDetailLevel]` (378) | `maximumDetailLevel` `Core/OOOpenGLExtensionManager.cpp:470` | ✅ |
| `-[OOOpenGLExtensionManager textureImageUnitCount]` (391) | `textureImageUnitCount` `Core/OOOpenGLExtensionManager.cpp:482` | ✅ |
| `-[OOOpenGLExtensionManager vboSupported]` (400) | `vboSupported` `Core/OOOpenGLExtensionManager.cpp:490` | ✅ |
| `-[OOOpenGLExtensionManager fboSupported]` (409) | `fboSupported` `Core/OOOpenGLExtensionManager.cpp:498` | ✅ |
| `-[OOOpenGLExtensionManager textureCombinersSupported]` (418) | `textureCombinersSupported` `Core/OOOpenGLExtensionManager.cpp:506` | ✅ |
| `-[OOOpenGLExtensionManager textureUnitCount]` (427) | `textureUnitCount` `Core/OOOpenGLExtensionManager.cpp:514` | ✅ |
| `-[OOOpenGLExtensionManager majorVersionNumber]` (436) | `majorVersionNumber` `Core/OOOpenGLExtensionManager.cpp:522` | ✅ |
| `-[OOOpenGLExtensionManager minorVersionNumber]` (441) | `minorVersionNumber` `Core/OOOpenGLExtensionManager.cpp:524` | ✅ |
| `-[OOOpenGLExtensionManager releaseVersionNumber]` (446) | `releaseVersionNumber` `Core/OOOpenGLExtensionManager.cpp:526` | ✅ |
| `-[OOOpenGLExtensionManager getVersionMajor:minor:release:]` (451) | `getVersionMajor` `Core/OOOpenGLExtensionManager.cpp:530` | ✅ |
| `-[OOOpenGLExtensionManager versionIsAtLeastMajor:minor:]` (461) | `versionIsAtLeastMajor` `Core/OOOpenGLExtensionManager.cpp:538` | ✅ |
| `-[OOOpenGLExtensionManager vendorString]` (466) | `vendorString` `Core/OOOpenGLExtensionManager.cpp:543` | ✅ |
| `-[OOOpenGLExtensionManager rendererString]` (471) | `rendererString` `Core/OOOpenGLExtensionManager.cpp:547` | ✅ |
| `-[OOOpenGLExtensionManager usePointSmoothing]` (476) | `usePointSmoothing` `Core/OOOpenGLExtensionManager.cpp:551` | ✅ |
| `-[OOOpenGLExtensionManager useLineSmoothing]` (481) | `useLineSmoothing` `Core/OOOpenGLExtensionManager.cpp:555` | ✅ |
| `-[OOOpenGLExtensionManager useDustShader]` (486) | `useDustShader` `Core/OOOpenGLExtensionManager.cpp:557` | ✅ |
| `IntegerFromString` (493) | `IntegerFromString` `Core/OOOpenGLExtensionManager.cpp:559` | ✅ |
| `-[OOOpenGLExtensionManager(OOPrivate) checkShadersSupported]` (517) | `checkShadersSupported` `Core/OOOpenGLExtensionManager.cpp:579` (same 5 extensions, order, log texts) | ✅ |
| `-[OOOpenGLExtensionManager(OOPrivate) checkVBOSupported]` (588) | `checkVBOSupported` `Core/OOOpenGLExtensionManager.cpp:672` | ✅ |
| `-[OOOpenGLExtensionManager(OOPrivate) checkFBOSupported]` (608) | `checkFBOSupported` `Core/OOOpenGLExtensionManager.cpp:696` (incl. `"glDeleteRenderbuffer"` typo kept) | ✅ |
| `-[OOOpenGLExtensionManager(OOPrivate) checkTextureCombinersSupported]` (665) | `checkTextureCombinersSupported` `Core/OOOpenGLExtensionManager.cpp:802` | ✅ |
| `CheckRegExps` (685) | `CheckRegExps` `Core/OOOpenGLExtensionManager.cpp:840` (+ `MatchesRegExp` `:829`; nil subject never matches) | ✅ |
| `CompareGPUSettingsByPriority` (712) | sort lambda `Core/OOOpenGLExtensionManager.cpp:888-900` (precedence default 1, non-dict 0, then case-insensitive) | ✅ |
| `-[OOOpenGLExtensionManager(OOPrivate) lookUpPerGPUSettingsWithVersionString:extensionsString:]` (730) | `lookUpPerGPUSettingsWithVersionString` `Core/OOOpenGLExtensionManager.cpp:875` | ✅ |
| `+[OOOpenGLExtensionManager(Singleton) allocWithZone:]` (783) | — not translated (comment `Core/OOOpenGLExtensionManager.cpp:934-936`) | ➖ |
| `-[OOOpenGLExtensionManager(Singleton) copyWithZone:]` (792) | — not translated | ➖ |
| `-[OOOpenGLExtensionManager(Singleton) retain]` (797) | — not translated | ➖ |
| `-[OOOpenGLExtensionManager(Singleton) retainCount]` (802) | — not translated | ➖ |
| `-[OOOpenGLExtensionManager(Singleton) release]` (807) | — not translated | ➖ |
| `-[OOOpenGLExtensionManager(Singleton) autorelease]` (811) | — not translated | ➖ |
| `OOBadOpenGLExtensionUsed` (820) | `OOBadOpenGLExtensionUsed` `Core/OOOpenGLExtensionManager.cpp:940` | ✅ |

**Differences:**

- ⚠️ **low** — The `rendering.opengl.extensions` log lists extensions in byte order (`std::set`); upstream used `NSSet` hash order. Count and separators unchanged; port comment acknowledges it (the previous ADR-0043 citation is no longer in the comment). (still open) — upstream `Core/OOOpenGLExtensionManager.m:241` ↔ port `Core/OOOpenGLExtensionManager.cpp:311-320`
- ✅ (note) — Version parse, min 3.3 with `OoliteOpenGLTooOldException` text, shader-level defaults `"SHADERS_FULL"`, `<= SHADERS_OFF` disable path naming the GPU (string/number `name`, else renderer), clamp, `texture_image_units`/`texture_units` lowering floored at 0, and `smooth_points`/`smooth_lines`/`use_dust_shader` default YES are unchanged. upstream `:202-306` ↔ port `:265-409`
- ✅ (note) — NULL `glGetString` results become `nullopt` and log as "(null)"; only reachable without a GL context. port `:257-261,304-310`

## OOOpenGLMatrixManager

<a id="ooopenglmatrixmanager"></a>
Upstream `src/Core/OOOpenGLMatrixManager.m` ↔ `Core/OOOpenGLMatrixManager.cpp` (591 / 514 lines)

**Status:** done — 59 rows: 59 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOOpenGLMatrixStack init]` (51) | implicit ctor (`std::vector` member; comment `Core/OOOpenGLMatrixManager.cpp:48-49`) | ✅ |
| `-[OOOpenGLMatrixStack dealloc]` (59) | implicit dtor | ✅ |
| `-[OOOpenGLMatrixStack push:]` (65) | `OOOpenGLMatrixStack::push` `Core/OOOpenGLMatrixManager.cpp:51` | ✅ |
| `-[OOOpenGLMatrixStack pop]` (70) | `OOOpenGLMatrixStack::pop` `Core/OOOpenGLMatrixManager.cpp:53` (empty → identity) | ✅ |
| `-[OOOpenGLMatrixStack stackCount]` (81) | `OOOpenGLMatrixStack::stackCount` `Core/OOOpenGLMatrixManager.cpp:62` | ✅ |
| `-[OOOpenGLMatrixManager(Private) updateModelView]` (97) | `updateModelView` `Core/OOOpenGLMatrixManager.cpp:64` (same 11 invalidations) | ✅ |
| `-[OOOpenGLMatrixManager(Private) updateProjection]` (112) | `updateProjection` `Core/OOOpenGLMatrixManager.cpp:78` (same 7) | ✅ |
| `-[OOOpenGLMatrixManager init]` (127) | `OOOpenGLMatrixManager()` `Core/OOOpenGLMatrixManager.cpp:88` | ✅ |
| `-[OOOpenGLMatrixManager dealloc]` (150) | implicit dtor (comment `:107`) | ✅ |
| `-[OOOpenGLMatrixManager loadModelView:]` (157) | `loadModelView` `Core/OOOpenGLMatrixManager.cpp:109` | ✅ |
| `-[OOOpenGLMatrixManager resetModelView]` (164) | `resetModelView` `Core/OOOpenGLMatrixManager.cpp:115` | ✅ |
| `-[OOOpenGLMatrixManager multModelView:]` (170) | `multModelView` `Core/OOOpenGLMatrixManager.cpp:120` (`matrix × current` order kept) | ✅ |
| `-[OOOpenGLMatrixManager translateModelView:]` (176) | `translateModelView` `Core/OOOpenGLMatrixManager.cpp:126` (row 3) | ✅ |
| `-[OOOpenGLMatrixManager rotateModelView:axis:]` (185) | `rotateModelView` `Core/OOOpenGLMatrixManager.cpp:134` | ✅ |
| `-[OOOpenGLMatrixManager scaleModelView:]` (190) | `scaleModelView` `Core/OOOpenGLMatrixManager.cpp:138` | ✅ |
| `-[OOOpenGLMatrixManager lookAtWithEye:center:up:]` (195) | `lookAtWithEye` `Core/OOOpenGLMatrixManager.cpp:142` | ✅ |
| `-[OOOpenGLMatrixManager pushModelView]` (209) | `pushModelView` `Core/OOOpenGLMatrixManager.cpp:153` | ✅ |
| `-[OOOpenGLMatrixManager popModelView]` (214) | `popModelView` `Core/OOOpenGLMatrixManager.cpp:157` | ✅ |
| `-[OOOpenGLMatrixManager getModelView]` (221) | `getModelView` `Core/OOOpenGLMatrixManager.cpp:163` | ✅ |
| `-[OOOpenGLMatrixManager countModelView]` (226) | `countModelView` `Core/OOOpenGLMatrixManager.cpp:167` | ✅ |
| `-[OOOpenGLMatrixManager syncModelView]` (231) | `syncModelView` `Core/OOOpenGLMatrixManager.cpp:171` | ✅ |
| `-[OOOpenGLMatrixManager loadProjection:]` (239) | `loadProjection` `Core/OOOpenGLMatrixManager.cpp:178` | ✅ |
| `-[OOOpenGLMatrixManager multProjection:]` (246) | `multProjection` `Core/OOOpenGLMatrixManager.cpp:184` | ✅ |
| `-[OOOpenGLMatrixManager translateProjection:]` (252) | `translateProjection` `Core/OOOpenGLMatrixManager.cpp:190` (column 3, as upstream) | ✅ |
| `-[OOOpenGLMatrixManager rotateProjection:axis:]` (261) | `rotateProjection` `Core/OOOpenGLMatrixManager.cpp:198` | ✅ |
| `-[OOOpenGLMatrixManager scaleProjection:]` (266) | `scaleProjection` `Core/OOOpenGLMatrixManager.cpp:202` | ✅ |
| `-[OOOpenGLMatrixManager frustumLeft:right:bottom:top:near:far:]` (271) | `frustumLeft` `Core/OOOpenGLMatrixManager.cpp:206` (same guards and 16 terms) | ✅ |
| `-[OOOpenGLMatrixManager orthoLeft:right:bottom:top:near:far:]` (282) | `orthoLeft` `Core/OOOpenGLMatrixManager.cpp:215` | ✅ |
| `-[OOOpenGLMatrixManager perspectiveFovy:aspect:zNear:zFar:]` (293) | `perspectiveFovy` `Core/OOOpenGLMatrixManager.cpp:224` | ✅ |
| `-[OOOpenGLMatrixManager resetProjection]` (305) | `resetProjection` `Core/OOOpenGLMatrixManager.cpp:234` | ✅ |
| `-[OOOpenGLMatrixManager pushProjection]` (311) | `pushProjection` `Core/OOOpenGLMatrixManager.cpp:239` | ✅ |
| `-[OOOpenGLMatrixManager popProjection]` (316) | `popProjection` `Core/OOOpenGLMatrixManager.cpp:243` | ✅ |
| `-[OOOpenGLMatrixManager getProjection]` (323) | `getProjection` `Core/OOOpenGLMatrixManager.cpp:249` | ✅ |
| `-[OOOpenGLMatrixManager syncProjection]` (328) | `syncProjection` `Core/OOOpenGLMatrixManager.cpp:253` | ✅ |
| `-[OOOpenGLMatrixManager getMatrix:]` (336) | `getMatrix` `Core/OOOpenGLMatrixManager.cpp:260` (normal-matrix `powf(fabsf(d), 1.0/3)` scaling kept) | ✅ |
| `-[OOOpenGLMatrixManager standardMatrixUniformLocations:]` (398) | `standardMatrixUniformLocations` `Core/OOOpenGLMatrixManager.cpp:327` (same `[loc, i, "mat3"/"mat4"]` entries) | ✅ |
| `OOGLPushModelView` (431) | `OOGLPushModelView` `Core/OOOpenGLMatrixManager.cpp:366` | ✅ |
| `OOGLPopModelView` (438) | `OOGLPopModelView` `Core/OOOpenGLMatrixManager.cpp:372` (nil → zero matrix) | ✅ |
| `OOGLGetModelView` (446) | `OOGLGetModelView` `Core/OOOpenGLMatrixManager.cpp:380` | ✅ |
| `OOGLResetModelView` (453) | `OOGLResetModelView` `Core/OOOpenGLMatrixManager.cpp:387` | ✅ |
| `OOGLLoadModelView` (460) | `OOGLLoadModelView` `Core/OOOpenGLMatrixManager.cpp:393` | ✅ |
| `OOGLMultModelView` (467) | `OOGLMultModelView` `Core/OOOpenGLMatrixManager.cpp:399` | ✅ |
| `OOGLTranslateModelView` (474) | `OOGLTranslateModelView` `Core/OOOpenGLMatrixManager.cpp:405` | ✅ |
| `OOGLRotateModelView` (481) | `OOGLRotateModelView` `Core/OOOpenGLMatrixManager.cpp:411` | ✅ |
| `OOGLScaleModelView` (488) | `OOGLScaleModelView` `Core/OOOpenGLMatrixManager.cpp:417` | ✅ |
| `OOGLLookAt` (495) | `OOGLLookAt` `Core/OOOpenGLMatrixManager.cpp:423` | ✅ |
| `OOGLResetProjection` (502) | `OOGLResetProjection` `Core/OOOpenGLMatrixManager.cpp:429` | ✅ |
| `OOGLPushProjection` (509) | `OOGLPushProjection` `Core/OOOpenGLMatrixManager.cpp:435` | ✅ |
| `OOGLPopProjection` (516) | `OOGLPopProjection` `Core/OOOpenGLMatrixManager.cpp:441` | ✅ |
| `OOGLGetProjection` (524) | `OOGLGetProjection` `Core/OOOpenGLMatrixManager.cpp:449` | ✅ |
| `OOGLLoadProjection` (531) | `OOGLLoadProjection` `Core/OOOpenGLMatrixManager.cpp:456` | ✅ |
| `OOGLMultProjection` (538) | `OOGLMultProjection` `Core/OOOpenGLMatrixManager.cpp:462` | ✅ |
| `OOGLTranslateProjection` (545) | `OOGLTranslateProjection` `Core/OOOpenGLMatrixManager.cpp:468` | ✅ |
| `OOGLRotateProjection` (552) | `OOGLRotateProjection` `Core/OOOpenGLMatrixManager.cpp:474` | ✅ |
| `OOGLScaleProjection` (559) | `OOGLScaleProjection` `Core/OOOpenGLMatrixManager.cpp:480` | ✅ |
| `OOGLFrustum` (566) | `OOGLFrustum` `Core/OOOpenGLMatrixManager.cpp:486` | ✅ |
| `OOGLOrtho` (573) | `OOGLOrtho` `Core/OOOpenGLMatrixManager.cpp:494` | ✅ |
| `OOGLPerspective` (580) | `OOGLPerspective` `Core/OOOpenGLMatrixManager.cpp:502` | ✅ |
| `OOGLGetModelViewProjection` (587) | `OOGLGetModelViewProjection` `Core/OOOpenGLMatrixManager.cpp:509` | ✅ |

**Differences:**

- ✅ (note) — The `OOGL*` wrappers resolve the manager through `GameViewMatrixManager()` and guard each call, matching nil-messaging (no-op, or a zero matrix for the getters/pops). `standardMatrixUniformLocations` returns by value where upstream over-retained its result (a leak), with no observable change. port `Core/OOOpenGLMatrixManager.cpp:327-364`

## OOOpenGLStateManager

<a id="ooopenglstatemanager"></a>
Upstream `src/Core/OOOpenGLStateManager.m` ↔ `Core/OOOpenGLStateManager.cpp` (629 / 904 lines)

**Status:** done — 23 rows: 23 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `GetState_DEPTH_WRITEMASK` (97) | `GetState_DEPTH_WRITEMASK` `Core/OOOpenGLStateManager.cpp:323` (now defined in all builds; used only by the verifier) | ✅ |
| `GetState_TEXTURE_ENV_MODE` (112) | `GetState_TEXTURE_ENV_MODE` `Core/OOOpenGLStateManager.cpp:343` | ✅ |
| `GetState_ACTIVE_TEXTURE` (126) | `GetState_ACTIVE_TEXTURE` `Core/OOOpenGLStateManager.cpp:358` | ✅ |
| `GetState_CLIENT_ACTIVE_TEXTURE` (139) | `GetState_CLIENT_ACTIVE_TEXTURE` `Core/OOOpenGLStateManager.cpp:372` | ✅ |
| `GetState_ACTIVE_TEXTURE` (152) | `!OO_MULTITEXTURE` stub `Core/OOOpenGLStateManager.cpp:387` | ✅ |
| `SetState_ACTIVE_TEXTURE` (153) | `!OO_MULTITEXTURE` stub `Core/OOOpenGLStateManager.cpp:388` (real one `:366`) | ✅ |
| `GetState_CLIENT_ACTIVE_TEXTURE` (154) | `!OO_MULTITEXTURE` stub `Core/OOOpenGLStateManager.cpp:389` | ✅ |
| `SetState_CLIENT_ACTIVE_TEXTURE` (155) | `!OO_MULTITEXTURE` stub `Core/OOOpenGLStateManager.cpp:390` (real one `:380`) | ✅ |
| `SetState_CULL_FACE_MODE` (158) | `SetState_CULL_FACE_MODE` `Core/OOOpenGLStateManager.cpp:393` (+ macro setters for DEPTH_WRITEMASK/SHADE_MODEL/TEXTURE_ENV_MODE/FRONT_FACE as functions `:331-403`) | ✅ |
| `OOGLNoteCurrentFunction` (209) | `OOGLNoteCurrentFunction` `Core/OOOpenGLStateManager.cpp:717` | ✅ |
| `SetFunctionTracking` (226) | `SetFunctionTracking` `Core/OOOpenGLStateManager.cpp:733` | ✅ |
| `OOGLNoteCurrentFunction` (233) | no-op stub `Core/OOOpenGLStateManager.cpp:740` | ✅ |
| `SetFunctionTracking` (234) | no-op stub `Core/OOOpenGLStateManager.cpp:742` | ✅ |
| `OOSetOpenGLState_` (238) | `OOSetOpenGLState_` `Core/OOOpenGLStateManager.cpp:747` | ✅ |
| `OOVerifyOpenGLState_` (255) | `OOVerifyOpenGLState_` `Core/OOOpenGLStateManager.cpp:768` | ✅ |
| `GetCurrentOpenGLState` (265) | `GetCurrentOpenGLState` `Core/OOOpenGLStateManager.cpp:777` (loops `kStateItems`, then blend src/dst) | ✅ |
| `StatesEqual` (290) | `StatesEqual` `Core/OOOpenGLStateManager.cpp:791` (kMaybe on either side matches; blend not compared, as upstream) | ✅ |
| `VerifyOpenGLStateInternal` (325) | `VerifyOpenGLStateInternal` `Core/OOOpenGLStateManager.cpp:804` (same texts; specials shown as ENABLED/disabled as upstream's macro did) | ✅ |
| `OOSetOpenGLState` (385) | `OOSetOpenGLState` `Core/OOOpenGLStateManager.cpp:864` | ✅ |
| `SwitchOpenGLStateInternal` (397) | `SwitchOpenGLStateInternal` `Core/OOOpenGLStateManager.cpp:880` (blend func reset when source BLEND is false, not maybe) | ✅ |
| `OOResetGLStateVerifier` (443) | `OOResetGLStateVerifier` `Core/OOOpenGLStateManager.cpp:901` | ✅ |
| state-item table `Core/Tables/OOOpenGLStates.tbl:25-58` (ITEM_* list, included by the functions above) | `kStateItems` `Core/OOOpenGLStateManager.cpp:584-636` + `OOOpenGLState` fields `:73-111` (static_assert `:658`) | ✅ |
| `kStandardStates` definitions (450-629) | `kStandardStates` `Core/OOOpenGLStateManager.cpp:114-298` (positional, matching `OOOpenGLStateID` order `Core/OOOpenGL.h:142-152`) | ✅ |

**Differences:**

- ✅ (emphasis: state table, spec 011) — `kStateItems` lists the same 30 items in the same order as `OOOpenGLStates.tbl` (LIGHTING, LIGHT0-7, TEXTURE_2D, COLOR_MATERIAL, BLEND, FOG, DEPTH_TEST, NORMALIZE, RESCALE_NORMAL, the six client arrays, DEPTH_WRITEMASK special, CULL_FACE, SHADE_MODEL int, TEXTURE_ENV_MODE/ACTIVE_TEXTURE/CLIENT_ACTIVE_TEXTURE specials, CULL_FACE_MODE, FRONT_FACE int), each with the same kind, so reads, compares, verifier log order and writes are unchanged. upstream `Core/Tables/OOOpenGLStates.tbl:25-58` ↔ port `Core/OOOpenGLStateManager.cpp:584-636`
- ✅ (emphasis: state values) — Every field of all five states (canonical initial, OPAQUE, TRANSLUCENT_PASS, ADDITIVE_BLENDING, OVERLAY) was compared one by one, including the kMaybe LIGHT0/LIGHT1/FOG entries, the blend src/dst pairs (ONE/ZERO, SA/1-SA, SA/ONE) and DEPTH_WRITEMASK/CULL_FACE per state; all match. upstream `Core/OOOpenGLStateManager.m:450-629` ↔ port `Core/OOOpenGLStateManager.cpp:114-298`

## OOPlanetDrawable

<a id="ooplanetdrawable"></a>
Upstream `src/Core/OOPlanetDrawable.m` ↔ `Core/OOPlanetDrawable.cpp` (389 / 358 lines)

**Status:** done — 29 rows: 28 ✅ 0 ⚠️ 0 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `+[OOPlanetDrawable planetWithTextureName:radius:]` (57) | `planetWithTextureName` `Core/OOPlanetDrawable.cpp:46` | ✅ |
| `+[OOPlanetDrawable atmosphereWithRadius:]` (66) | `atmosphereWithRadius` `Core/OOPlanetDrawable.cpp:55` | ✅ |
| `-[OOPlanetDrawable init]` (74) | `OOPlanetDrawable()` `Core/OOPlanetDrawable.cpp:63` (radius 1, LOD 0.5) | ✅ |
| `-[OOPlanetDrawable initAsAtmosphere]` (85) | `initAsAtmosphere` `Core/OOPlanetDrawable.cpp:71` | ✅ |
| `-[OOPlanetDrawable dealloc]` (94) | `_material` member destructor (comment `Core/OOPlanetDrawable.cpp:80`) | ➖ |
| `-[OOPlanetDrawable copyWithZone:]` (101) | `copy` `Core/OOPlanetDrawable.cpp:82` | ✅ |
| `-[OOPlanetDrawable material]` (113) | `material` `Core/OOPlanetDrawable.cpp:95` | ✅ |
| `-[OOPlanetDrawable setMaterial:]` (118) | `setMaterial` `Core/OOPlanetDrawable.cpp:97` (old one autoreleased) | ✅ |
| `-[OOPlanetDrawable textureName]` (124) | `textureName` `Core/OOPlanetDrawable.cpp:102` | ✅ |
| `-[OOPlanetDrawable setTextureName:]` (129) | `setTextureName` `Core/OOPlanetDrawable.cpp:107` (same `{diffuse_map={repeat_s=yes;cube_map=yes};}` spec) | ✅ |
| `-[OOPlanetDrawable radius]` (138) | `radius` `Core/OOPlanetDrawable.cpp:121` | ✅ |
| `-[OOPlanetDrawable setRadius:]` (143) | `setRadius` `Core/OOPlanetDrawable.cpp:123` | ✅ |
| `-[OOPlanetDrawable levelOfDetail]` (149) | `levelOfDetail` `Core/OOPlanetDrawable.cpp:128` | ✅ |
| `-[OOPlanetDrawable setLevelOfDetail:]` (154) | `setLevelOfDetail` `Core/OOPlanetDrawable.cpp:132` | ✅ |
| `-[OOPlanetDrawable calculateLevelOfDetailForViewDistance:]` (159) | `calculateLevelOfDetailForViewDistance` `Core/OOPlanetDrawable.cpp:136` (100/40 factors, nil universe/view → NO / width 0) | ✅ |
| `-[OOPlanetDrawable renderOpaqueParts]` (173) | `renderOpaqueParts` `Core/OOPlanetDrawable.cpp:156` | ✅ |
| `-[OOPlanetDrawable renderTranslucentParts]` (184) | `renderTranslucentParts` `Core/OOPlanetDrawable.cpp:166` | ✅ |
| `-[OOPlanetDrawable renderTranslucentPartsOnOpaquePass]` (196) | `renderTranslucentPartsOnOpaquePass` `Core/OOPlanetDrawable.cpp:177` | ✅ |
| `-[OOPlanetDrawable renderCommonParts]` (212) | `renderCommonParts` `Core/OOPlanetDrawable.cpp:192` (same GL call order; nil material skips apply, NO for normals-as-texcoords) | ✅ |
| `-[OOPlanetDrawable hasOpaqueParts]` (286) | `hasOpaqueParts` `Core/OOPlanetDrawable.cpp:268` | ✅ |
| `-[OOPlanetDrawable hasTranslucentParts]` (291) | `hasTranslucentParts` `Core/OOPlanetDrawable.cpp:270` | ✅ |
| `-[OOPlanetDrawable collisionRadius]` (296) | `collisionRadius` `Core/OOPlanetDrawable.cpp:272` | ✅ |
| `-[OOPlanetDrawable maxDrawDistance]` (301) | `maxDrawDistance` `Core/OOPlanetDrawable.cpp:274` | ✅ |
| `-[OOPlanetDrawable boundingBox]` (307) | `boundingBox` `Core/OOPlanetDrawable.cpp:279` | ✅ |
| `-[OOPlanetDrawable setBindingTarget:]` (312) | `setBindingTarget` `Core/OOPlanetDrawable.cpp:284` | ✅ |
| `-[OOPlanetDrawable dumpSelfState]` (317) | `dumpSelfState` `Core/OOPlanetDrawable.cpp:289` | ✅ |
| `-[OOPlanetDrawable recalculateTransform]` (324) | `recalculateTransform` `Core/OOPlanetDrawable.cpp:295` | ✅ |
| `-[OOPlanetDrawable debugDrawNormals]` (331) | `debugDrawNormals` `Core/OOPlanetDrawable.cpp:301` | ✅ |
| `-[OOPlanetDrawable allTextures]` (380) | `allTextures` `Core/OOPlanetDrawable.cpp:352` | ✅ |

**Differences:**

- ➖ **low** — `-dealloc`'s `DESTROY(_material)` is the `_material` member destructor; no observable change. (still open, unchanged) — upstream `Core/OOPlanetDrawable.m:94` ↔ port `Core/OOPlanetDrawable.cpp:80`
- ✅ (note) — The `#if NEW_PLANETS` guard is gone; upstream hard-codes `NEW_PLANETS 1`, so the same code is compiled. A nil `textureName` can no longer arrive (`const std::string&`). upstream `Core/OOPlanetDrawable.m:26,129` ↔ port `Core/OOPlanetDrawable.cpp:25,107`

## OOPolygonSprite

<a id="oopolygonsprite"></a>
Upstream `src/Core/OOPolygonSprite.m` ↔ `Core/OOPolygonSprite.cpp` (862 / 834 lines)

**Status:** done — 26 rows: 24 ✅ 0 ⚠️ 1 ❌ 1 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOPolygonSprite initWithDataArray:outlineWidth:name:]` (131) | `OOPolygonSprite::initWithDataArray` `Core/OOPolygonSprite.cpp:152` (empty → null, array-of-arrays normalisation, register) | ✅ |
| `-[OOPolygonSprite dealloc]` (158) | `~OOPolygonSprite` `Core/OOPolygonSprite.cpp:182` | ✅ |
| `-[OOPolygonSprite descriptionComponents]` (172) | `descriptionComponents` `Core/OOPolygonSprite.cpp:187` (+ `description` `:192`) | ✅ |
| `-[OOPolygonSprite drawWithData:count:VBO:]` (178) | `drawWithData` `Core/OOPolygonSprite.cpp:202` | ✅ |
| `-[OOPolygonSprite drawFilled]` (219) | `drawFilled` `Core/OOPolygonSprite.cpp:243` (count = floats/2) | ✅ |
| `-[OOPolygonSprite drawOutline]` (230) | `drawOutline` `Core/OOPolygonSprite.cpp:251` | ✅ |
| `-[OOPolygonSprite resetGraphicsState]` (241) | `resetGraphicsState` `Core/OOPolygonSprite.cpp:259` | ✅ |
| `-[OOPolygonSprite loadPolygons:outlineWidth:]` (257) | `loadPolygons` `Core/OOPolygonSprite.cpp:272` (same two passes, width halved, outer then inner, POSITIVE winding on outline only) | ✅ |
| `SubmitVertices` (408) | `SubmitVertices` `Core/OOPolygonSprite.cpp:392` | ✅ |
| `DataArrayToPoints` (426) | `DataArrayToPoints` `Core/OOPolygonSprite.cpp:411` | ❌ |
| `BuildOutlineContour` (491) | `BuildOutlineContour` `Core/OOPolygonSprite.cpp:477` (mitre test, `(count*2-3-i)%count` walk, NaN drop) | ✅ |
| `GrowTessPolygonData` (585) | — replaced by `std::vector<GLfloat>` growth (`reserve(100*2)` `Core/OOPolygonSprite.cpp:292,342`) | ➖ |
| `AppendVertex` (612) | `AppendVertex` `Core/OOPolygonSprite.cpp:572` (`push_back`; always true) | ✅ |
| `TessBeginCallback` (625) (missed by extractor: `APIENTRY`) | `TessBeginCallback` `Core/OOPolygonSprite.cpp:580` | ✅ |
| `TessVertexCallback` (636) (missed by extractor) | `TessVertexCallback` `Core/OOPolygonSprite.cpp:590` (fan/strip split and pending0/1 parity, error log text) | ✅ |
| `TessCombineCallback` (723) (missed by extractor) | `TessCombineCallback` `Core/OOPolygonSprite.cpp:681` (vertex owned by `combinedVertices`) | ✅ |
| `TessEndCallback` (729) (missed by extractor) | `TessEndCallback` `Core/OOPolygonSprite.cpp:690` | ✅ |
| `ErrorCallback` (740) (missed by extractor) | `ErrorCallback` `Core/OOPolygonSprite.cpp:700` | ✅ |
| `SVGDumpBegin` (760) | `SVGDumpBegin` `Core/OOPolygonSprite.cpp:721` | ✅ |
| `SVGDumpEnd` (771) | `SVGDumpEnd` `Core/OOPolygonSprite.cpp:732` | ✅ |
| `SVGDumpBeginGroup` (781) | `SVGDumpBeginGroup` `Core/OOPolygonSprite.cpp:742` | ✅ |
| `SVGDumpEndGroup` (789) | `SVGDumpEndGroup` `Core/OOPolygonSprite.cpp:749` | ✅ |
| `SVGDumpAppendBaseContour` (796) | `SVGDumpAppendBaseContour` `Core/OOPolygonSprite.cpp:755` (empty contour still raises) | ✅ |
| `SVGDumpBeginPrimitive` (815) | `SVGDumpBeginPrimitive` `Core/OOPolygonSprite.cpp:787` (`%2X` → `{:2X}`, uint8_t formats as integer) | ✅ |
| `SVGDumpEndPrimitive` (849) | `SVGDumpEndPrimitive` `Core/OOPolygonSprite.cpp:822` | ✅ |
| `SVGDumpAppendTriangle` (856) | `SVGDumpAppendTriangle` `Core/OOPolygonSprite.cpp:827` | ✅ |

**Differences:**

- ❌ **low** — A contour entry that is not an array: upstream sent `-count`/`-oo_doubleAtIndex:` to it, which raises for NSNumber/NSString/NSDictionary (sprite creation threw); the port's `PList::count()` gives 0 (or a dict's size) and `at<double>` 0, so the entry becomes an empty or (0,0) contour and is silently skipped. (still open) — upstream `Core/OOPolygonSprite.m:445-455` ↔ port `Core/OOPolygonSprite.cpp:430-441`
- ➖ **low** — `GrowTessPolygonData` and the manual `realloc`/shrink of `_solidData`/`_outlineData` are replaced by `std::vector` (`reserve`, `shrink_to_fit`); only the out-of-memory paths differ (exception instead of `OK = NO`). (new: refactor since the previous audit) — upstream `Core/OOPolygonSprite.m:274-277,311-328,376-393,585-623` ↔ port `Core/OOPolygonSprite.cpp:292,327-331,379-382,572-578`
- ✅ (subtle) — `ErrorCallback` formats `gluErrorString` with `{}`; a NULL result (upstream printed "(null)" via `%s`) would be UB, but GLU returns a string for every tessellator error code. upstream `:750-752` ↔ port `:709-713`
- ✅ (note) — Contours are `std::vector<NSPoint>`; the tessellator's vertex pointers stay valid because `contours`/`outlineContours` (reserved `count*2`) and `combinedVertices` live until `loadPolygons` returns. Duplicate end trimming uses `NSEqualPoints` (only -0.0 vs 0.0 could differ from `isEqual:`). A nil `_name` printed "(null)" upstream; the port's string prints "" (debug only). port `:62-85,277-280,364-374,458-461`

## OOProbabilisticTextureManager

<a id="ooprobabilistictexturemanager"></a>
Upstream `src/Core/OOProbabilisticTextureManager.m` ↔ `Core/OOProbabilisticTextureManager.cpp` (229 / 220 lines)

**Status:** done — 9 rows: 8 ✅ 0 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOProbabilisticTextureManager initWithPListName:options:anisotropy:lodBias:]` (36) | `createWithPListName` (4-arg) `Core/OOProbabilisticTextureManager.cpp:60` (`RANROTGetFullSeed()`) | ✅ |
| `-[OOProbabilisticTextureManager initWithPListName:options:anisotropy:lodBias:seed:]` (48) | `createWithPListName` (5-arg) `Core/OOProbabilisticTextureManager.cpp:70` → `initWithPListName` `:85` | ✅ |
| `-[OOProbabilisticTextureManager dealloc]` (147) | `~OOProbabilisticTextureManager` (defaulted; vectors of `shared_ptr`) `Core/OOProbabilisticTextureManager.cpp:161` | ✅ |
| `-[OOProbabilisticTextureManager description]` (168) | `descriptionComponents` `Core/OOProbabilisticTextureManager.cpp:165` (same `{%u textures, cumulative probability=%g}` text via the base `description`) | ✅ |
| `-[OOProbabilisticTextureManager selectTexture]` (173) | `selectTexture` `Core/OOProbabilisticTextureManager.cpp:171` | ❌ |
| `-[OOProbabilisticTextureManager textureCount]` (205) | `textureCount` `Core/OOProbabilisticTextureManager.cpp:208` | ✅ |
| `-[OOProbabilisticTextureManager ensureTexturesLoaded]` (210) | `ensureTexturesLoaded` `Core/OOProbabilisticTextureManager.cpp:210` | ✅ |
| `-[OOProbabilisticTextureManager seed]` (219) | `seed` `Core/OOProbabilisticTextureManager.cpp:218` | ✅ |
| `-[OOProbabilisticTextureManager setSeed:]` (224) | `setSeed` `Core/OOProbabilisticTextureManager.cpp:220` | ✅ |

**Differences:**

- ❌ **low** — The overrun logs (`probabilisticTextureManager.internalWarning` / `.internalFailure`) print `__PRETTY_FUNCTION__` as `OOTexture* OOProbabilisticTextureManager::selectTexture()` instead of `-[OOProbabilisticTextureManager selectTexture]`. Only on a cumulative-probability overrun. (still open) — upstream `Core/OOProbabilisticTextureManager.m:197,201` ↔ port `Core/OOProbabilisticTextureManager.cpp:196-204`
- ✅ (note) — Loading reads entries in array order; dict `texture` via `oo_stringForKey` semantics, `probability` default 1.0, non-string `galaxy` logs `textures.load` with "(null)" for a missing name; cumulative `_prob[n] = p + (gal ≥ 0 ? _probMaxGal[gal] : _probMax)` unchanged. `selectTexture` draws one `randfWithSeed(&_seed)` per call, scaled by `_probMaxGal[galID]`, with the same `hold`/last fallbacks; nil `PLAYER` → galaxy 0. upstream `:86-145,173-203` ↔ port `:98-159,171-206`

## OOSkyDrawable

<a id="ooskydrawable"></a>
Upstream `src/Core/OOSkyDrawable.m` ↔ `Core/OOSkyDrawable.cpp` (685 / 677 lines)

**Status:** done — 24 rows: 23 ✅ 1 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| constants `SKY_ELEMENT_SCALE_FACTOR`, `NEBULA_SHUFFLE_FACTOR`, `sMinTexCoord`/`sMaxTexCoord`, `kSkyQuadSet*EntriesPerVertex` (40-64) | `Core/OOSkyDrawable.cpp:42-70` (same values) | ✅ |
| `-[OOSkyDrawable initWithColor1:Color2:Color3:Color4:starCount:nebulaCount:nebulaHueFix:clusterFactor:alpha:scale:]` (120) | `OOSkyDrawable::OOSkyDrawable` `Core/OOSkyDrawable.cpp:122` (inset-coords default, stars then nebulae unless reducedDetail, register reset client) | ✅ |
| `-[OOSkyDrawable dealloc]` (166) | `OOSkyDrawable::~OOSkyDrawable` `Core/OOSkyDrawable.cpp:152` | ✅ |
| `-[OOSkyDrawable renderOpaqueParts]` (178) | `OOSkyDrawable::renderOpaqueParts` `Core/OOSkyDrawable.cpp:159` (same GL state, fog colour, display-list build) | ✅ |
| `-[OOSkyDrawable hasOpaqueParts]` (223) | `OOSkyDrawable::hasOpaqueParts` `Core/OOSkyDrawable.cpp:205` | ✅ |
| `-[OOSkyDrawable maxDrawDistance]` (228) | `OOSkyDrawable::maxDrawDistance` `Core/OOSkyDrawable.cpp:207` | ✅ |
| `-[OOSkyDrawable allTextures]` (234) | `OOSkyDrawable::allTextures` `Core/OOSkyDrawable.cpp:210` (vector, debug monitor only) | ✅ |
| `-[OOSkyDrawable totalSize]` (246) | `OOSkyDrawable::totalSize` `Core/OOSkyDrawable.cpp:221` | ✅ |
| `DebugColor` (262) | `DebugColor` `Core/OOSkyDrawable.cpp:235` (both `#if DEBUG_COLORS`, = 0) | ✅ |
| `-[OOSkyDrawable(OOPrivate) setUpStarsWithColor1:color2:]` (271) | `OOSkyDrawable::setUpStars` `Core/OOSkyDrawable.cpp:247` (RNG order, `%6`, corner maths) | ✅ |
| `-[OOSkyDrawable(OOPrivate) setUpNebulaeWithColor1:color2:clusterFactor:nebulaHueFix:alpha:scale:]` (322) | `OOSkyDrawable::setUpNebulae` `Core/OOSkyDrawable.cpp:307` (RNG order, `&15`, `/32`, shuffle, double-increment kept) | ✅ |
| `-[OOSkyDrawable(OOPrivate) addQuads:count:]` (412) | `OOSkyDrawable::addQuads` `Core/OOSkyDrawable.cpp:398` | ✅ |
| `-[OOSkyDrawable(OOPrivate) loadStarTextures]` (420) | `OOSkyDrawable::loadStarTextures` `Core/OOSkyDrawable.cpp:402` (same plist, flags, lodBias -0, exception, reseed) | ✅ |
| `-[OOSkyDrawable(OOPrivate) loadNebulaTextures]` (436) | `OOSkyDrawable::loadNebulaTextures` `Core/OOSkyDrawable.cpp:427` | ✅ |
| `-[OOSkyDrawable(OOPrivate) ensureTexturesLoaded]` (452) | `OOSkyDrawable::ensureTexturesLoaded` `Core/OOSkyDrawable.cpp:452` (null guards = nil messaging) | ✅ |
| `-[OOSkyDrawable(OOPrivate) resetGraphicsState]` (458) | `OOSkyDrawable::resetGraphicsState` `Core/OOSkyDrawable.cpp:457` | ✅ |
| `+[OOSkyQuadSet addQuads:count:toArray:]` (472) | `OOSkyQuadSet::addQuads` `Core/OOSkyDrawable.cpp:468` (first-seen identity grouping) | ✅ |
| `-[OOSkyQuadSet initWithQuadsWithTexture:inArray:count:]` (500) | `OOSkyQuadSet::initWithQuadsWithTexture` `Core/OOSkyDrawable.cpp:496` (colour correction 0/1/tonemap, tex coords, `sky.setup` log) | ✅ |
| `-[OOSkyQuadSet dealloc]` (616) | `OOSkyQuadSet::~OOSkyQuadSet` `Core/OOSkyDrawable.cpp:609` (members) | ✅ |
| `-[OOSkyQuadSet description]` (630) | `OOSkyQuadSet::descriptionComponents` `Core/OOSkyDrawable.cpp:613` | ✅ |
| `-[OOSkyQuadSet render]` (635) | `OOSkyQuadSet::render` `Core/OOSkyDrawable.cpp:619` | ✅ |
| `-[OOSkyQuadSet totalSize]` (649) | `OOSkyQuadSet::totalSize` `Core/OOSkyDrawable.cpp:635` | ⚠️ |
| `-[OOSkyQuadSet texture]` (654) | `OOSkyQuadSet::texture` `Core/OOSkyDrawable.cpp:642` | ✅ |
| `SaturatedColorInRange` (662) | `SaturatedColorInRange` `Core/OOSkyDrawable.cpp:647` (randf drawn even for nil colour; `0.5*s+0.5`; `/360` only with hueFix) | ✅ |

**Differences:**

- ⚠️ **low** — Debug-monitor `OOSkyQuadSet::totalSize` uses `sizeof *this` instead of `-oo_objectSize`, so reported byte counts differ; port comment states it (still open) — upstream `Core/OOSkyDrawable.m:651` ↔ port `Core/OOSkyDrawable.cpp:635-640`
- ✅ (note) — Star and nebula RNG call order re-checked and unchanged: star loop `OORandomQuaternion`, `randf` (blend, drawn even when `color1` is nil), `selectTexture`, `ranrot_rand()%6`; nebula loop as upstream incl. short-circuit `i<_nebulaCount` before `randf()`. — upstream `Core/OOSkyDrawable.m:287-398` ↔ port `Core/OOSkyDrawable.cpp:266-385`
- ✅ (note) — Test hook `sSetUpStarsStandIn` is null in the game, so the upstream path runs. — port `Core/OOSkyDrawable.cpp:248-251`
- ✅ (note, low) — Edge cases unreachable in practice: a nil texture from `selectTexture` made upstream's `[seenTextures addObject:nil]` raise, while the port groups it as a null-texture set; `allTextures` returns a vector (no dedup, may hold null) where upstream built an `NSMutableSet` (debug monitor only). — upstream `Core/OOSkyDrawable.m:236-241,485-486` ↔ port `Core/OOSkyDrawable.cpp:210-219,482-485`
- ✅ (note) — Destructor unregisters the reset client before the quad sets are freed (upstream released `_quadSets` first); no observable effect. — upstream `Core/OOSkyDrawable.m:170-171` ↔ port `Core/OOSkyDrawable.cpp:155`

## OOTextureScaling

<a id="ootexturescaling"></a>
Upstream `src/Core/OOTextureScaling.m` ↔ `Core/OOTextureScaling.cpp` (1578 / 1690 lines)

**Status:** done — 30 rows: 23 ✅ 6 ⚠️ 1 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `StretchVertically` (91) | `StretchVertically` `Core/OOTextureScaling.cpp:118` | ✅ |
| `StretchVertically` (104) | `StretchVertically` `Core/OOTextureScaling.cpp:130` | ✅ |
| `SqueezeVertically` (115) | `SqueezeVertically` `Core/OOTextureScaling.cpp:140` (same dispatch; exception text same) | ✅ |
| `StretchHorizontally` (142) | `StretchHorizontally` `Core/OOTextureScaling.cpp:167` | ✅ |
| `SqueezeHorizontally` (171) | `SqueezeHorizontally` `Core/OOTextureScaling.cpp:196` | ✅ |
| `OOScalePixMap` (244) | `OOScalePixMap` `Core/OOTextureScaling.cpp:276` (same branches and 4/3 sizes; manual frees replaced by shared pixel buffers) | ✅ |
| `OOGenerateMipMaps` (336) | `OOGenerateMipMaps` `Core/OOTextureScaling.cpp:357` | ❌ |
| `GenerateMipMaps1` (365) | `GenerateMipMaps1` `Core/OOTextureScaling.cpp:394` | ✅ |
| `ScaleToHalf_1_x1` (414) | `ScaleToHalf_1_x1` `Core/OOTextureScaling.cpp:444` | ✅ |
| `ScaleToHalf_1_x4` (453) | `ScaleToHalf_1_x4` `Core/OOTextureScaling.cpp:484` | ✅ |
| `ScaleToHalf_1_x8` (502) | `ScaleToHalf_1_x8` `Core/OOTextureScaling.cpp:536` | ✅ |
| `GenerateMipMaps2` (551) | `GenerateMipMaps2` `Core/OOTextureScaling.cpp:604` | ✅ |
| `ScaleToHalf_2_x1` (605) | `ScaleToHalf_2_x1` `Core/OOTextureScaling.cpp:659` | ✅ |
| `GenerateMipMaps4` (643) | `GenerateMipMaps4` `Core/OOTextureScaling.cpp:700` | ✅ |
| `ScaleToHalf_4_x1` (690) | `ScaleToHalf_4_x1` `Core/OOTextureScaling.cpp:748` | ✅ |
| `ScaleToHalf_4_x2` (743) | `ScaleToHalf_4_x2` `Core/OOTextureScaling.cpp:802` | ✅ |
| `DumpMipMap` (818) | `DumpMipMap` `Core/OOTextureScaling.cpp:882` (`#if DUMP_MIP_MAPS`; same format string) | ✅ |
| `StretchVerticallyN_x1` (825) | `StretchVerticallyN_x1` `Core/OOTextureScaling.cpp:892` | ⚠️ |
| `StretchVerticallyN_x4` (869) | `StretchVerticallyN_x4` `Core/OOTextureScaling.cpp:941` | ⚠️ |
| `StretchVerticallyN_x8` (917) | `StretchVerticallyN_x8` `Core/OOTextureScaling.cpp:995` | ⚠️ |
| `StretchHorizontally1` (964) | `StretchHorizontally1` `Core/OOTextureScaling.cpp:1049` | ⚠️ |
| `StretchHorizontally2` (1019) | `StretchHorizontally2` `Core/OOTextureScaling.cpp:1112` | ⚠️ |
| `StretchHorizontally4` (1081) | `StretchHorizontally4` `Core/OOTextureScaling.cpp:1182` | ✅ |
| `SqueezeHorizontally1` (1144) | `SqueezeHorizontally1` `Core/OOTextureScaling.cpp:1249` | ✅ |
| `SqueezeVertically1` (1202) | `SqueezeVertically1` `Core/OOTextureScaling.cpp:1307` | ⚠️ |
| `SqueezeHorizontally2` (1283) | `SqueezeHorizontally2` `Core/OOTextureScaling.cpp:1396` | ✅ |
| `SqueezeVertically2` (1340) | `SqueezeVertically2` `Core/OOTextureScaling.cpp:1453` | ✅ |
| `SqueezeHorizontally4` (1433) | `SqueezeHorizontally4` `Core/OOTextureScaling.cpp:1549` | ✅ |
| `SqueezeVertically4` (1490) | `SqueezeVertically4` `Core/OOTextureScaling.cpp:1606` | ✅ |
| `EnsureCorrectDataSize` (1548) | `EnsureCorrectDataSize` `Core/OOTextureScaling.cpp:1666` (realloc → `OOResizePixMap`) | ✅ |

**Differences:**

- ⚠️ **med** — `SqueezeVertically1` uses `endY <= lastRow` (as the 2/4-channel versions do) instead of upstream `<`; upstream dropped the last row's `endWeight` from `accum` but kept it in `weight`, darkening the last output row of a grayscale non-integer vertical squeeze (port comment: 90 → 33 for 8 → 5). Pixels differ there (still open) — upstream `Core/OOTextureScaling.m:1245` ↔ port `Core/OOTextureScaling.cpp:1353-1359`
- ⚠️ **low** — `StretchVerticallyN_x1/x4/x8` re-point the copied last row at source row `height-1` (port comment: ASan OOB read). Upstream's pointer is the same row when it was row `H-2` and one past the buffer otherwise, so only UB reads change (still open) — upstream `Core/OOTextureScaling.m:860,908,956` ↔ port `Core/OOTextureScaling.cpp:932,986,1041`
- ⚠️ **low** — `StretchHorizontally1/2` clamp the last row's look-ahead to `width-1`. It fires only when `fractX>>12 == width`, where `weight1 = 0`, so output is unchanged and only the OOB read goes (still open) — upstream `Core/OOTextureScaling.m:1003-1016,1062-1075` ↔ port `Core/OOTextureScaling.cpp:1104-1105,1171-1172`
- ❌ **low** — `OOGenerateMipMaps` parameter-error logs print `__PRETTY_FUNCTION__`; in C++ that is the full signature (`bool OOGenerateMipMaps(void *, …)`), while a GCC-compiled upstream `.m` C function gives the bare name, so the `kOOLogParameterError` text differs (still open) — upstream `Core/OOTextureScaling.m:339,361` ↔ port `Core/OOTextureScaling.cpp:361-365,388-390`
- ✅ (note) — `EnsureCorrectDataSize`: upstream returned YES with `pixels = NULL` when `realloc` failed; the port returns `OOResizePixMap`'s result (false only on invalid size). Only allocation failure differs. — upstream `Core/OOTextureScaling.m:1569-1573` ↔ port `Core/OOTextureScaling.cpp:1685-1686`
- ✅ (note) — Apart from the items above, a whitespace-normalised diff shows only casts, `BOOL`→`bool`, `NSException`→`OORaiseException` (same name and text), `OSAtomicAdd32`→`std::atomic` in the disabled dump code, and buffer ownership via `OOPixMap::buffer`. All fixed-point (24.8, 20.12) maths, masks and `ScaleToHalf` averaging are verbatim. — upstream `Core/OOTextureScaling.m` ↔ port `Core/OOTextureScaling.cpp`

## OOTextureSprite

<a id="ootexturesprite"></a>
Upstream `src/Core/OOTextureSprite.m` ↔ `Core/OOTextureSprite.cpp` (115 / 104 lines)

**Status:** done — 7 rows: 7 ✅ 0 ⚠️ 0 ❌ 0 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `-[OOTextureSprite initWithTexture:]` (32) | `OOTextureSprite::initWithTexture(OOTexture*)` `Core/OOTextureSprite.cpp:30` (nil texture → zero size, then null) | ✅ |
| `-[OOTextureSprite initWithTexture:size:]` (37) | `OOTextureSprite::initWithTexture(OOTexture*, NSSize)` `Core/OOTextureSprite.cpp:39` + ctor `:49` | ✅ |
| `-[OOTextureSprite dealloc]` (52) | `std::shared_ptr<OOTexture> texture` member `Core/OOTextureSprite.h:55` | ✅ |
| `-[OOTextureSprite size]` (59) | `OOTextureSprite::getSize` `Core/OOTextureSprite.cpp:54` | ✅ |
| `-[OOTextureSprite blitToX:Y:Z:alpha:]` (64) | `OOTextureSprite::blitToX` `Core/OOTextureSprite.cpp:56` (overlay state, alpha clamp, ACW quad and tex coords) | ✅ |
| `-[OOTextureSprite blitCentredToX:Y:Z:alpha:]` (95) | `OOTextureSprite::blitCentredToX` `Core/OOTextureSprite.cpp:86` | ✅ |
| `-[OOTextureSprite blitBackgroundCentredToX:Y:Z:alpha:]` (102) | `OOTextureSprite::blitBackgroundCentredToX` `Core/OOTextureSprite.cpp:92` (512 scale/unscale, z*distance) | ✅ |

**Differences:**

- ✅ (note) — Bodies are line-for-line the same; the only change is the nil guard on `texture->apply()`, matching a message to nil. — upstream `Core/OOTextureSprite.m:32-113` ↔ port `Core/OOTextureSprite.cpp:30-104`

## TextureStore

<a id="texturestore"></a>
Upstream `src/Core/TextureStore.m` ↔ *(no port counterpart: upstream compiled it out with `#if !NEW_PLANETS`; planet textures come from `OOPlanetTextureGenerator`)*

**Status:** done — 9 rows: 0 ✅ 0 ⚠️ 0 ❌ 9 ➖

| Upstream (line) | C++ counterpart | Verdict |
|---|---|---|
| `FloatRGBFromDictColor` (46) | — (compiled out upstream) | ➖ |
| `Blend` (59) | — (compiled out upstream) | ➖ |
| `PlanetTextureColor` (68) | — (compiled out upstream) | ➖ |
| `+[TextureStore getPlanetTextureNameFor:intoData:width:height:]` (100) | — (compiled out upstream) | ➖ |
| `+[TextureStore getCloudTextureNameFor:impress:bias:intoData:width:height:]` (139) | — (compiled out upstream) | ➖ |
| `fillRanNoiseBuffer` (167) | — (compiled out upstream) | ➖ |
| `addNoise` (176) | — (compiled out upstream) | ➖ |
| `q_factor` (201) | — (compiled out upstream) | ➖ |
| `fillSquareImageDataWithCloudTexture` (236) | — (compiled out upstream) | ➖ |

**Differences:**

- ➖ **low** — The whole file sits inside `#if !NEW_PLANETS`, and `NEW_PLANETS` is 1 (`Core/Entities/OOStellarBody.h:33-35`), so upstream never compiled `TextureStore`. The port has no `TextureStore`, `PlanetTextureColor`, `q_factor` or `fillRanNoiseBuffer` symbol under `src/`; no shipped behaviour is lost (still open, unchanged) — upstream `Core/TextureStore.m:27,338`, `Core/TextureStore.h:33,56` ↔ port —

