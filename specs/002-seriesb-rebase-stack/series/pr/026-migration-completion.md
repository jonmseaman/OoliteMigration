# Drop GNUstep and the last Objective-C; cache builds in CI

<!-- Written by tools/series/series.py --series seriesb describe. A rerun keeps the four hand-written sections and rewrites the rest. -->

Step 26/28.

## What this changes

- GNUstep leaves build, launchers and packaging (`build_gnustep.sh`, Flatpak modules,
  `.travis.yml`, `debian/`). `run_oolite.sh` still computes `OO_GNUSTEPDEFAULTSDIR` for
  preferences. `post_build.sh` loses `gnustep_folder`: `stamp_file` is now `${11}`, `build_docs`
  `${12}`.
- Objective-C tools: `tools/icosmesh` is one C++20 file (`icosmesh.cpp`, `-ffp-contract=off`);
  JSErrorMunger and the fonttexgen app go; `tools/distancemap` is plain C.
- Dead Objective-C under always-false conditions goes (`OOLITE_MAC_OS_X`, `OO_SALVAGE_SUPPORT`,
  CoreFoundation branches, `OOFoundation.h`'s Objective-C macros); `DEBUG_DUMP` switches now
  build.
- Build and CI: a generated `OOVersion.h` replaces the version `-D` flags; `./mk.sh` uses ccache
  when installed (`--ccache`, `--no-ccache`). CI drops the GNUstep builds, adds
  `unit-tests-windows` (llvmpipe `opengl32.dll`), caches ccache and packages, and runs `release`
  only on `master`/`develop` pushes. `LICENSE.md` adds the QuickJS-ng, libcurl and ICU notices.
- Tests: new `test_OOMatrix`, `test_OOQuaternion`, `test_OOHPVector`; removed `headers_standalone`,
  `idiom_check.py`, `source_paths.py`.

## Why

Nothing used the GNUstep set-up or the remaining Objective-C, and the version header, ccache and
CI changes cut rebuild and job time.

## Behaviour changes

- Game logic: none; the removed code was never compiled.
- The Linux launcher no longer creates `$GAME_DATA/.GNUstep` or a temporary `GNUstep.conf`, and the
  Windows launcher and `main.cpp` no longer set `GNUSTEP_*`. Not pinned.
- An EXR snapshot frees its attribute array and keeps its full signature (was leaked; cut at 255
  bytes). Not pinned.
- `test_OOShaderProgram`'s four failed-initialiser checks accept `GL_INVALID_VALUE` or no error from
  `glDeleteObjectARB(0)` (NVIDIA reports it, Mesa does not); they still require nothing else left
  behind. Game code unchanged.
- Found, not fixed: `OOMatrixForRotation`'s third row starts `t*x*y + s*y`, should be
  `t*x*z + s*y` (wrong for x ≠ 0, y ≠ z; upstream too). `test_OOMatrix` pins current behaviour on
  axis (0, 1, 1). Upstream may want to fix it.
- `OOPlanetData.cpp` is regenerated with the same data; only its header comment's file name
  changes.

## How to review

Read by commit. Most of the 217 files are deletions (`debian/`, Xcode projects, fonttexgen nib,
Objective-C icosmesh). Read by hand: `icosmesh.cpp` against the deleted `main.m`/`JAIcos*.m`;
`post_build.sh` and `src/meson.build` (argument positions); `meson.build` and `src/Core/meson.build`
for `OOVersion.h`; `mk.sh`'s ccache block; the CI workflow. macOS and Linux builds are not
verified by this series.

Test edits:
- `test_OOShaderProgram.cpp`: accepts either driver's answer for deleting program 0.
- `check_headers_standalone.py`: removed with the `headers_standalone` test.
- `tests/unit/core/meson.build`: adds `test_OOMatrix`, `test_OOQuaternion`, `test_OOHPVector`.
- `idiom_check.py` removed; `check_debug_monitor_guards.py` carries its own scanning helpers.
- `source_paths.py`, `gui/test_source_paths.py` removed; `test_double_click_timing.py` opens
  `src/<path>.cpp` directly.

## Test changes

Existing test files changed (ledger `test-changes.md`):

- `tests/check_debug_monitor_guards.py`
- `tests/check_headers_standalone.py`
- `tests/gui/test_double_click_timing.py`
- `tests/gui/test_source_paths.py`
- `tests/idiom_check.py`
- `tests/source_paths.py`
- `tests/unit/core/meson.build`
- `tests/unit/core/test_OOShaderProgram.cpp`

## Verified

Not verified yet.
