# Test-change ledger: spec 009

Every test file edited, in the commit that edits it (FR-015, data-model.md *Test-change ledger*).
Hard rule 1's third exception (Jon, 2026-11-11) allows an edit where a type, function, enumerator
or header the test names is replaced by its standard equivalent, keeping every assertion's
meaning. `borderline` and `needs sign-off` rows wait for Jon's date in `signed` before the change
that needs them; `reported` rows record a test this feature cannot edit, for Jon to decide.

| test file | lines | forced by | assertions | coverage | commit | signed |
|---|---|---|---|---|---|---|
| `tests/unit/oofnd/test_ref.cpp` | 514 (`willDisposeRunsOnceWithTheObjectWhole`) | `oo::WeakRef` → `std::weak_ptr`: a `std::weak_ptr` is already empty when the disposing deleter runs, so weak references can no longer be live during `willDispose()` (research R5) | changed: weak references read empty from the start of disposal instead of after `willDispose()` | needs sign-off | — | |
| `tests/unit/core/test_OOShaderMaterial.cpp` | 309, 501, 588 (stack `TestTarget`) | `oo::RefCounted` → `oo::Object`: a weak reference needs a `std::shared_ptr` owner, so the stack instance becomes `oo::makeShared<TestTarget>()` | unchanged | borderline | — | |
| `tests/unit/core/test_OODebugMonitor.cpp` | 780 (`static PlayerEntity sStandInPlayer`) | as above: the static instance becomes a never-deleted `std::shared_ptr` | unchanged | borderline | — | |
| `tests/unit/oofnd/test_ref.cpp` | 35 (copying a `RefCounted`) | as above: the copied object is made with `oo::makeShared` | unchanged | borderline | — | |
| the tests that name the enumerators of the 20 existing `enum class` types (`oo::PList::Type`, `oo::FileType`, `oo::Http::Scheme`, `OOJSCallEntityMethodForm`, …) | throughout | P10 renames existing `enum class` enumerators to `kPascalCase`; that is a rename, not a replacement by a standard equivalent, so rule 1's third exception does not plainly cover it | unchanged | needs sign-off | — | |
| `tests/unit/oofnd/test_stdlib.cpp` | whole file | `oofnd/StdLib.hpp` leaves game code (T031); the test checks that header, which has no standard counterpart to port to | — | reported: Jon decides whether the test is retired (write `retire` or `keep` in this row with the date) | — | |
| `tests/unit/core/test_OOALSoundDecoder.cpp`, `tests/unit/core/test_OOMusic.cpp`, `tests/unit/core/test_OOSound.cpp` | 116, 124, 132, 155, 182; 66; 104 | `OOALSoundDecoder::readCreatingBuffer(char** outBuffer, size_t* outSize)`, which returns a `malloc` buffer the caller frees, becomes `bool readCreatingBuffer(std::vector<char>& out)` (T015): the tests call it, and two define stubs with its signature | unchanged | borderline: the function keeps its name but changes shape | — | |
| `tests/unit/core/test_OOTextureScaling.cpp`, `test_OOPixMapTextureLoader.cpp`, `test_OOPNGTextureLoader.cpp`, `test_OOTextureLoader.cpp` (and the other pixmap tests T017/T018 reach) | the `free(pixMap.pixels)` and `malloc` lines (33 in `test_OOTextureScaling.cpp` alone) | the pixel-buffer chain (`OOPixMap`, `OOAllocatePixMap`/`OOFreePixMap`/`OOResizePixMap`, the loaders, scaling and the generators) stops using the C allocator (T017, T018); the tests free game-made pixmaps with `free()` and give loaders `malloc` buffers, so each such line becomes `OOFreePixMap`/the owning buffer the chain uses | unchanged | borderline: a release and construction form, not a name | — | |
