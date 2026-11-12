# Drop GNUstep and the last Objective-C; cache builds in CI

**Series:** step 26 of 26 · base `seriesb/025-libcurl-http` · next `—` **(gen)**

**Source:** the tree of `seriesb/026-migration-completion` (`48c6c56a03`), with the series' exclusions and additions · 1.6k src, 452 tests, 1.2k other changed lines; 7.4k lines in deleted files **(gen)**

**Based on:** upstream #768's branch, so this step is not independent of upstream's QuickJS-ng PRs (#767, #768). **(gen)**

## What this changes

- **GNUstep leaves the build, launchers and packaging.** The game links no GNUstep, so nothing
  sets up its runtime any more:
  - Linux: `build_gnustep.sh` and its `dep_location_fn.sh` helper go; `run_oolite.sh` no longer
    writes a `GNUstep.conf` or creates `$GAME_DATA/.GNUstep` (`OO_GNUSTEPDIR` goes from its help).
    It still computes `OO_GNUSTEPDEFAULTSDIR`, where the preferences live.
  - `post_build.sh` no longer copies `GNUstep.conf` or GNUstep libraries, and loses its
    `gnustep_folder` argument, with `meson.build`'s empty value and `src/meson.build`'s use of it:
    `stamp_file` is now `${11}` and `build_docs` `${12}`.
  - Windows: `install_deps.sh` no longer downloads and installs libobjc2 and gnustep-make;
    `main.cpp` and `RunOolite.bat` stop setting `GNUSTEP_*`.
  - Flatpak: the libobjc2, robin-map, gnustep-make and gnustep-base modules go, and so does the
    FreeDesktop `GNUstep.conf.template`.
  - `.travis.yml` (Xcode 7, a project that no longer exists) and the `debian/` packaging go;
    `README.md` drops the GNUstep build step.
- **The Objective-C tools.** `tools/icosmesh`, which generates `src/Core/OOPlanetData.{cpp,h}`,
  is one C++20 file with no dependencies (`tools/icosmesh/icosmesh.cpp`), built by default by
  `tools/icosmesh/meson.build` with `-ffp-contract=off`; its GNUmakefile, Xcode project and
  `generatemesh.c` go. JSErrorMunger, which turned SpiderMonkey's `js.msg` into
  `javascript-errors.plist`, goes with SpiderMonkey. The fonttexgen Cocoa app goes; its source
  assets stay, with a README, and `OOEncodingConverter` loses the guard that existed only for it.
  `tools/distancemap` is plain C (current libpng typedefs) with a README build line instead of an
  Xcode project.
- **Dead Objective-C in the C++ sources.** Code under conditions that are always false held
  Objective-C that could not compile if the condition were set. It goes: the `OOLITE_MAC_OS_X`
  blocks (the Cocoa log filter, crash-reporter info, Time Machine exclusion and `~/Library` log
  folder, the AppleScript iTunes control, the Mac cache file name, the Mac-only
  `OO_RESOLUTION_OPTION` and command-key branches), `OO_SALVAGE_SUPPORT`, `OOShipRegistry`'s
  `PRELOAD`, the CoreFoundation branch of the TCP stream decoder's abstraction layer, Objective-C
  in `#if 0` and comment blocks, and `OOFoundation.h`'s Objective-C macros (`OOSortFunction`,
  `IBOutlet`/`IBAction`, `OOLITE_PROPERTY_SYNTAX`, `OOLITE_OPTIONAL`, and others). The planet and
  atmosphere generators' `DEBUG_DUMP` blocks call `MyOpenGLView`'s C++ dump methods, and the
  texture scaler's dump IDs use `std::atomic` instead of `OSAtomicAdd32`, so those debug
  switches build. Comments that named `.mm` files name the `.cpp` files, and the hand-kept
  by-name tables lose their compiler/ARC and salvage rows.
- **Small tidies.** The EXR snapshot builds its signature in a `std::string` instead of `strcat`
  into a 255-byte buffer, and frees `custom_attributes`, which it leaked. macOS's
  `GetSysCtlString` uses a `std::string` buffer instead of `alloca`. `.git-blame-ignore-revs`
  lists the reformat and clang-tidy commits. The Windows manifest's comment says the Windows 10
  ID also covers Windows 11.
- **Version header.** `OO_VERSION_FULL`, `OO_BUILD_DATE` and `OO_BUILDER` move from `-D` flags on
  every compile into a generated `OOVersion.h` (`src/Core`'s build directory), included by the
  five files that print them. `main.cpp`'s `"Undefined"` fallback goes.
- **ccache.** `./mk.sh` compiles through ccache when it is installed: it writes a copy of the
  native file whose `c` and `cpp` are `['ccache', <compiler>]`, since meson wraps a compiler only
  when it detects it itself. `--ccache` insists on it, `--no-ccache` turns it off.
- **CI (`.github/workflows/build-all.yaml`).** The Linux jobs no longer build libobjc2,
  tools-make and libs-base. A new `unit-tests-windows` job builds the test flavour without LTO
  and runs `tests/run.sh unit`, with Mesa's llvmpipe `opengl32.dll` beside the core tests (the
  runner has no GPU). Builds compile through ccache, and the ccache store and downloaded
  packages (pacman, apt, dnf) are cached; every job has a timeout; the token is read-only by
  default; `release` runs only for pushes to `master` and `develop`; a pull request from this
  repository no longer runs the jobs its push already ran; `actions/cache` is v6.
- **Licences.** `LICENSE.md` carries the QuickJS-ng, libcurl and ICU notices, and names the wrap
  and the patches applied to QuickJS-ng; `Doc/SpidermonkeyChanges.txt` goes.
- **Tests.** New: `test_OOMatrix`, `test_OOQuaternion` and `test_OOHPVector` (identities,
  inverses, rotations keeping lengths, translation and scale, double precision far from the
  origin, the description texts). `test_OOShaderProgram` accepts either driver's answer for
  deleting program 0. Removed: the `headers_standalone` test (`tests/check_headers_standalone.py`),
  `tests/idiom_check.py` (`check_debug_monitor_guards.py` carries its own copy of the scanning
  helpers it used), and `tests/source_paths.py` with its `test_source_paths.py`;
  `test_double_click_timing.py` opens `src/<path>.cpp` directly.

## Why

The conversion left GNUstep's build, runtime set-up and packaging in place with nothing using
them, and Objective-C in tools and in code no build compiles. Removing them leaves a tree that
builds with a C++ compiler and the libraries `meson.build` names. The version header and ccache
let a rebuild reuse unchanged objects; the CI changes run the unit suites on Windows and keep
the jobs' time down. The licence notices are required for the libraries the Windows package
ships.

## Behaviour changes

- None in the game's logic: the removed code was never compiled.
- The Linux launcher no longer creates `$GAME_DATA/.GNUstep` or a temporary `GNUstep.conf`, and
  the Windows launcher and `main.cpp` no longer set `GNUSTEP_*`. Not pinned by a test.
- An EXR snapshot no longer leaks its attribute array, and its signature is not cut at 255
  bytes. Not pinned by a test.
- `test_OOShaderProgram`'s four failed-initialiser checks accept `GL_INVALID_VALUE` or no error
  from the teardown's `glDeleteObjectARB(0)`: NVIDIA reports the error, Mesa does not. The game
  code is unchanged; the checks still require nothing else to be left behind.
- The new maths tests pin current behaviour. Writing them found that `OOMatrixForRotation`
  (`src/Core/OOMatrix.cpp`) is not a rotation for an axis with x ≠ 0 and y ≠ z: its third row
  starts `t*x*y + s*y` where it should be `t*x*z + s*y`. Upstream has the same code; this step
  does not change it, and `test_OOMatrix` uses the unaffected axis (0, 1, 1). Upstream may want
  to fix it.
- `OOPlanetData.cpp` is regenerated by the C++ `icosmesh` with the same data; only its header
  comment's file name changes.

## How to review

Read it by commit; each says what it removes or adds. Most of the 217 files are deletions
(`debian/`, the Xcode projects, the fonttexgen nib, the Objective-C icosmesh). Read by hand:
`tools/icosmesh/icosmesh.cpp` against the deleted `main.m` and `JAIcos*.m`, `post_build.sh` and
`src/meson.build` (the argument positions), `meson.build` and `src/Core/meson.build` for
`OOVersion.h`, `mk.sh`'s ccache block, and the CI workflow. The `OOFoundation.h`,
`OOLogOutputHandler.cpp` and `OOTCPStreamDecoderAbstractionLayer.h` hunks are deletions of
`OOLITE_MAC_OS_X` and CoreFoundation branches. macOS and Linux builds of this step are not
verified by this series.

## Test changes **(gen)**

Existing test files this step changes, each listed in the series' test ledger (`test-changes.md`):

- `tests/check_debug_monitor_guards.py`
- `tests/check_headers_standalone.py`
- `tests/gui/test_double_click_timing.py`
- `tests/gui/test_source_paths.py`
- `tests/idiom_check.py`
- `tests/source_paths.py`
- `tests/unit/core/meson.build`
- `tests/unit/core/test_OOShaderProgram.cpp`

## Verified **(gen)**

Not verified yet.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
