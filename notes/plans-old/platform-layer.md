# Platform layer: platform-specific code behind one interface

Status: **Prepare**. Replaces the platform parts of `2026-10-28 Modern C++ Idiom Review.md` (§1.3),
`2026-10-28 Idiom Epics and Beads Outline.md` (B5) and `2026-11-01 Platform-Specific Code.md`. The
idiom work is in [modern-cpp-idioms.md](modern-cpp-idioms.md).

## Why

Linux and Apple Silicon are next. Platform tests are scattered through function bodies, so each
port means hunting through 35+ files. The goal is to make a port mean writing `*_posix.cpp` or
`*_darwin.cpp` files that satisfy an interface. The linker then lists what is missing, and no
`#else` branch sits in the tree rotting unseen.

## Where it stands (2026-11-15, `oolite-dev` `1ad3e3e3e` + working tree)

**Done**
- The dead Mac code is gone (`OOLITE_MAC_OS_X`: 0).
- SpiderMonkey's `MOZ_TRACE_JSCALLS` survives only in 5 comments.
- `oofnd/Http.hpp` runs on libcurl on every platform.
- SDL3 abstracts the window and input.

**Left**

| What | Count |
|---|---:|
| `#if` on `OOLITE_WINDOWS` / `_WIN32` / `WIN32` | 89 in 35 files |
| `#if` on `OOLITE_LINUX` / `__linux__` | 14 in 10 files |
| `#if` on `OOLITE_MACOS` / `__APPLE__` | 21 in 9 files |
| `#if` on `OOLITE_SDL` | 21 in 11 files (always 1: the SDL front end is the only one) |
| Endian macros (`OOLITE_BIG/LITTLE_ENDIAN`, `BYTE_ORDER`) | 41 in 8 files |
| Hand-declared Win32 prototypes (to avoid `<windows.h>`) | 10 in 4 files (`oofnd/Process.hpp`, `Thread.hpp`, `Defaults.hpp`, `ResourcePaths.hpp`) |
| `OO_DEBUG_MONITOR_ENABLED` directives | 187 in 87 files (177 test it with `#ifdef`, the rest by value) |
| Other feature switches | `OO_SHADERS` 49, `OO_OXP_VERIFIER_ENABLED` 29, `OO_DEBUG` 27, `OO_MULTITEXTURE` 22, `OO_TEXTURE_CUBE_MAP` 17, `OO_FOV_INFLIGHT_CONTROL_ENABLED` 16, `OO_DUMP_PLANETINFO` 16, `OO_VARIABLE_TORUS_SPEED` 13, `OO_USE_VBO` 13, `DEBUG_GRAPHVIZ` 13, `OOLITE_NATIVE_64_BIT` 11, `OO_LOCALIZATION_TOOLS` 10 … |
| Foundation-collision guard `oofnd/objc/OOFoundationTypes.h:41-43` | dead (Foundation is never included; rule 6) |

Worst files for platform directives: `SDL/MyOpenGLView.cpp` 15, `GameController.cpp` 11,
`OOLogHeader.cpp` 8, `SDL/main.cpp` 7, `OOOpenGLExtensionManager.cpp` 7, `OOFoundation.h` 7,
`OOCPUInfo.cpp` 6, `PlayerEntityControls.cpp` 6, `PlayerEntity.cpp` 4,
`OODebugTCPConsoleClient.cpp` 4, and the `oofnd` headers at 3–4 each (`Process`, `Thread`,
`ResourcePaths`, `LogFile`, `Http`, `FileSystem`, `Defaults`).

Recount any row with
`git grep -cE '^\s*#\s*(if|ifdef|ifndef|elif).*(OOLITE_WINDOWS|_WIN32\b|\bWIN32\b|OOLITE_LINUX|__linux__|OOLITE_MACOS|__APPLE__|OOLITE_SDL)' -- src`.

## Rules the work establishes

1. **The layer lives in `src/platform/`, not in `oofnd`.** Jon is retiring `oofnd` (2026-11-15), so
   nothing in `src/platform/` includes an `oofnd` header. The dependency runs one way: `oofnd` and
   the game may call `oo::platform`, never the reverse.
2. Raw platform macros (`_WIN32`, `__APPLE__`, `__linux__`, and the `OOLITE_WINDOWS`/`LINUX`/`MACOS`
   derived from them) are read in **one header**, `src/platform/Platform.hpp`, and in Meson. Nowhere
   else, except vendored code under `third_party/` and plain C, which stay as they are (rule 7).
3. Platform headers (`<windows.h>`, `<winsock2.h>`, `<unistd.h>`, `<mach/...>`) are included only from
   `src/platform/*_<os>.cpp` files.
4. Name a condition by capability, not by OS, for example `kHasThreadNames`.
5. `if constexpr (oo::platform::kIsWindows)` is fine for constants and logic. OS API calls go in the
   per-OS files.

## Design

**`src/platform/Platform.hpp`** (new), with no OS headers:

```cpp
namespace oo::platform {
enum class OS { kWindows, kMacOS, kLinux };
inline constexpr OS kOS = /* the one #if chain in the tree */;
inline constexpr bool kIsWindows = kOS == OS::kWindows;   // and kIsMacOS, kIsLinux
}
```

`OOFoundation.h` keeps defining `OOLITE_WINDOWS` and the others from `Platform.hpp` until the last
caller is gone, then stops.

**Per-OS implementation files**, all in `src/platform/`:
- `<Module>.hpp` declares a module's functions in `oo::platform`, with no `#if` and no OS header.
- `<Module>_win32.cpp` and `<Module>_posix.cpp` implement it, plus `<Module>_darwin.cpp` only where
  macOS really differs from POSIX.
- The module names follow what they do (`Thread`, `Process`, `Paths`, `Files`, `Http`, `Cpu`, `Gl`,
  `Socket`, `Console`), not the `oofnd` or Core file the code came from.

**Build:** `src/platform/meson.build` builds a static library, `platform_lib`, and declares
`platform_dep`. `src/meson.build` runs `subdir('platform')` before `subdir('oofnd')`, and both
`oofnd_dep` and the game depend on `platform_dep`. Each module adds its file by OS:

```meson
platform_src += files('Thread_' + (host_os == 'windows' ? 'win32' : 'posix') + '.cpp')
```

Unit tests for the layer go in a new suite, `tests/unit/platform/`, following `tests/unit/oofnd`.
Adding tests is allowed; editing existing ones is not.

**Feature switches:** a generated `config.hpp` holding `inline constexpr bool`s (e.g.
`oo::config::kDebugMonitor`). It is written by Meson's `configure_file` from the same options that
pass `-D…` today.
- Where a switch only gates logic, use `if constexpr` on the switch.
- Where it gates whole files or declarations that don't exist otherwise, use Meson source lists. The
  debug monitor's `.cpp` files, for instance, are added only when the option is on.
- If neither works, keep the `#if`, but test by value (`#if OO_DEBUG_MONITOR_ENABLED`) with the macro
  always defined to 0 or 1, so that `-Wundef` can check it.

## Workstreams

Each workstream is one commit, or a few, on a `git town append` branch.

- **P1. `src/platform/`, `Platform.hpp` and the Meson library.** Add the directory, the header,
  `src/platform/meson.build` (`platform_lib`, `platform_dep`) and the `subdir` ordering, and route
  `OOFoundation.h`'s OS macros through `Platform.hpp`.
  - Done: `test -f src/platform/Platform.hpp`, `! git grep -q 'oofnd' -- src/platform`, and
    `./mk.sh build dev` passes.
- **P2. The OS code in `oofnd`, one module at a time:** `Thread`, `Process`, `Defaults`,
  `ResourcePaths`, `FileSystem`, `LogFile`, `Http`, `Date`.
  - Move each `#if` body out of `oofnd` into `src/platform/`, as an `oo::platform` function with a
    `_win32.cpp` and a `_posix.cpp`. The `oofnd` header calls it, and keeps only the
    platform-neutral behaviour (the GNUstep semantics its tests pin).
  - Where a whole `oofnd` function is nothing but OS code (thread naming, the OS version string, the
    user's home and app-data paths), move it to `src/platform/` and point callers at
    `oo::platform` directly, rather than leaving an `oofnd` forwarder. This shrinks `oofnd`, which
    is the point.
  - The hand-declared kernel32 prototypes go. The `_win32.cpp` file includes `<windows.h>` and uses
    the `W` APIs.
  - Done per module: `git grep -nE '_WIN32|OOLITE_WINDOWS|__APPLE__|__linux__' -- src/oofnd/<Module>.hpp`
    finds nothing, and `tests/run.sh unit` (oofnd and core) passes with the `oofnd` tests unedited.
    If a caller's move would mean editing an `oofnd` test, keep a forwarder instead and record it.
- **P3. Core/SDL clusters,** in this order (worst first):
  1. `SDL/MyOpenGLView.cpp` + `MyOpenGLView.h` + `MyOpenGLView+Input.cpp`.
  2. `GameController.cpp`.
  3. `SDL/main.cpp`: Windows start-up uses `W` APIs and `std::filesystem::path`.
  4. `OOLogHeader.cpp` + `OOCPUInfo.{h,cpp}`: CPU count from `std::thread::hardware_concurrency()`,
     the OS name from `oo::process`.
  5. `OOOpenGLExtensionManager.cpp` + `OOOpenGLOnly.h`: `gl_proc_address`.
  6. `PlayerEntityControls.cpp`, `PlayerEntity.cpp`, `PlayerEntityKeyMapper.cpp` (keymap file name
     by OS) and `ResourceManager.cpp` (`USERPROFILE` vs `HOME`).
  7. `Debug/OODebugTCPConsoleClient.cpp`: Winsock start-up becomes `socket_init`.
  8. `Scripting/OOJavaScriptEngine.cpp`, `OOJSOolite.cpp`, `OOJSEngineTimeManagement` and
     `OOProfilingStopwatch.h`: the stopwatch's platform branches become `std::chrono::steady_clock`.
  9. `OXPVerifier/OOOXPVerifier.cpp`, `Universe.cpp` and the rest.

  For each, route through an existing `oofnd` facility, add a small `oo::platform` function, or
  delete the branch because SDL3 or `std::filesystem` already covers it.
  - Done per cluster: the platform grep above finds nothing in its files, `./mk.sh build dev` passes,
    `tests/run.sh unit` and `tests/run.sh smoke` pass.
- **P4. `OOLITE_SDL`.** It is always 1, so unwrap its 21 blocks and delete its `#else` branches. Same
  approach as the `OOLITE_OPENAL` task.
  - Done: `! git grep -q OOLITE_SDL -- src`.
- **P5. Endianness.** Replace the endian macros with `std::endian` (and `std::byteswap` where bytes
  are swapped).
  - Done: `! git grep -qE 'OOLITE_(BIG|LITTLE)_ENDIAN|__BYTE_ORDER|\bBYTE_ORDER\b' -- src`.
- **P6. Feature switches.** Generate `config.hpp`, then convert `OO_DEBUG_MONITOR_ENABLED` first,
  because it is the biggest (two commits: Debug/ and Scripting/, then the rest), then the others in
  the order of the table above.
  - Switches that are always on or always off in every build type (check `mk.sh`, `meson.options`
    and CI) get unwrapped or deleted instead, like `OOLITE_ESPEAK` in
    [make-espeak-mandatory.md](make-espeak-mandatory.md). Record each one.
  - Done per switch: no `#ifdef`/`defined()` test of it remains, and every build type in `mk.sh`
    builds. Build only `dev` locally; CI covers the others.
- **P7. Guard against regressions.** Add a CI step (in `build-all.yaml`'s clang-tidy job) that fails
  on a raw platform macro outside `src/platform/` and `third_party/`:
  `! git grep -nE '^\s*#\s*(if|ifdef|ifndef|elif).*(_WIN32\b|\bWIN32\b|__APPLE__|__linux__)' -- src ':!src/platform'`.
  It also fails if `src/platform/` includes an `oofnd` header: `! git grep -q 'oofnd/' -- src/platform`.
  Once P2 and P3 are done, also reject the `OOLITE_WINDOWS`/`LINUX`/`MACOS` macros themselves.
- **P8. Dead-code leftovers.** Delete the Foundation-collision guard
  (`oofnd/objc/OOFoundationTypes.h:37-43`). Leave the `MOZ_TRACE_JSCALLS` comments where they
  describe behaviour kept from SpiderMonkey, and the `GNUSTEP_*` names in `Defaults.hpp`, which are
  real environment-variable and config names.

## Done check for the whole plan

From `oolite-dev`, the P7 grep finds nothing. `./mk.sh build dev`, `tests/run.sh unit`,
`component --cpp` and `smoke` pass. CI's Linux and macOS jobs build.

## Decisions (defaults taken)

- **Windows is the only platform built here.** Linux and macOS files are written to the POSIX API
  and checked by CI's Linux and macOS jobs. Don't build GCC or Linux locally.
- **`_darwin.cpp` only where macOS really differs from POSIX.** Default to `_posix.cpp` for macOS.
- **`OO_DEBUG_MONITOR_ENABLED` and the other switches stay build options.** This plan changes how
  they're tested, not whether they exist. Retiring one, as with espeak, is its own decision.
- **Vendored C is left alone:** `third_party/` (MiniZip, miniz, tinyexr, stb) and QuickJS-ng.
- **Tests:** no test edits are expected. If a test names a moved macro, stop and list it for Jon's
  sign-off (rule 1); the platform move isn't covered by the std-equivalent exception.

---

## Appendix A: `notes/2026-11-01 Platform-Specific Code.md`, verbatim

Kept for reference (the note itself is deleted). Counts and line numbers are as of 2026-11-01 and may have drifted.

### Platform-Specific Code

How to structure platform-specific code in modern C++, and how that applies to Oolite. The
codebase has ~150 platform conditionals (`_WIN32`, `__APPLE__`, `__linux__`, `OOLITE_*`) across
~50 files in `oolite-dev/src`, with no encapsulated platform interface.

#### The modern approach

Modern C++ treats this as a build-structure problem more than a language one.

##### 1. Let the standard library do it first

Much `#ifdef _WIN32` code predates standard coverage. Check these before wrapping anything:

- `std::filesystem`: paths, directory iteration, wide-char paths on Windows
  (`std::ofstream(std::filesystem::path)` handles UTF-16)
- `std::thread`, `std::jthread`, `std::chrono`, `std::this_thread`
- `std::endian` (C++20), `std::bit_cast`
- `std::to_chars` / `std::format` instead of locale-sensitive printf workarounds

Every macro deleted this way is one less to abstract.

##### 2. One interface, one implementation file per platform, selected by the build

The main technique. The header has no `#ifdef` and no OS headers:

```cpp
// oofnd/Thread.hpp
namespace oo::platform {
  void setCurrentThreadName(std::string_view utf8Name);
  bool setCurrentThreadPriority(ThreadPriority p);
}
```

Implementations live in per-platform files:

```
oofnd/platform/Thread_win32.cpp   // includes <windows.h>; nothing else sees it
oofnd/platform/Thread_posix.cpp
oofnd/platform/Thread_darwin.cpp  // only if it genuinely differs from POSIX
```

Meson picks one:

```meson
if host_machine.system() == 'windows'
  oofnd_src += files('platform/Thread_win32.cpp')
else
  oofnd_src += files('platform/Thread_posix.cpp')
endif
```

Benefits:

- `<windows.h>` stays out of every other translation unit (no `min`/`max` macro clashes,
  faster builds).
- Each file only compiles on its platform, so it is plain code with no `#else` branches that
  rot unseen.
- Porting is "write a file that satisfies the interface"; the linker lists what is missing.
- A clean seam for tests and fakes.

##### 3. `if constexpr` for small inline differences

For things too small to split into files (a separator, a flag):

```cpp
// oofnd/Platform.hpp — the ONLY file that reads predefined platform macros
namespace oo::platform {
  enum class OS { Windows, MacOS, Linux };
  inline constexpr OS kOS =
  #if defined(_WIN32)
    OS::Windows;
  #elif defined(__APPLE__)
    OS::MacOS;
  #else
    OS::Linux;
  #endif
  inline constexpr bool kIsWindows = kOS == OS::Windows;
}

// elsewhere
if constexpr (oo::platform::kIsWindows) { ... } else { ... }
```

Unlike `#ifdef`, both branches are parsed and type-checked everywhere, so a typo in the Linux
branch breaks the Windows build too. Limitation: outside a template, the discarded branch must
still name only declared things, so it cannot call `SetThreadPriority` on Linux. OS API calls
belong in section 2's files; `if constexpr` is for constants and logic.

##### 4. Rules that keep macros from spreading again

- Raw `_WIN32` / `__APPLE__` / `__linux__` tests appear only in `Platform.hpp` or in meson.
  Enforce with a grep in CI.
- Platform headers (`<windows.h>`, `<unistd.h>`, `<mach/…>`) are included only from
  `platform/*.cpp`.
- Name conditions by capability, not OS: `OO_HAVE_EXR_SNAPSHOTS`, `kHasPthreadSetName`, not
  `#ifdef __APPLE__`. The real reason is usually "this API exists here", not "this is Apple".

#### Applying it to Oolite

The conditionals fall into three groups.

##### `oofnd/*.hpp`: right abstractions, wrong place

`Thread`, `Process`, `FileSystem`, `Http`, `LogFile`, `ResourcePaths`, `Defaults`, `Date`.
These already present a platform-neutral API, but they are header-only with `#ifdef` inside
inline bodies. `Thread.hpp` and `Process.hpp` even hand-declare kernel32 functions to avoid
pulling `<windows.h>` into every includer, a workaround that is unnecessary once the bodies move
to `platform/*_win32.cpp`.

This is the cheapest, highest-value step: interfaces barely change; macros leave the headers.

##### Core and SDL: direct OS calls

`OOCPUInfo`, `OOLogOutputHandler`, `OOOpenGLExtensionManager`, `OOOpenGLOnly.h`,
`OOFoundation.h`, `MyOpenGLView`, `GameController`, `OODebugTCPConsoleClient`, the
`PlayerEntity*` files, `OOJSEngineTimeManagement`, and others. For each cluster, either:

- route it through an existing `oofnd` facility,
- add a small `oo::platform` function, or
- delete it because SDL2 or `std::filesystem` already covers it.

##### Vendored C: leave alone

`tinyexr.h`, `miniz`, `stb_image_write.h`, `MiniZip`. Their `#ifdef`s belong to upstream, and
the "don't rewrite C for its own sake" rule applies.

#### Suggested order

1. Add `oofnd/Platform.hpp` (OS enum and capability constants) and the `platform/` directory
   with meson selection.
2. Move `oofnd` header bodies into `platform/*_win32.cpp` / `*_posix.cpp`, one module at a
   time.
3. Sweep Core/SDL clusters onto `oofnd` / `oo::platform`.
4. Add the CI grep that rejects raw platform macros outside `Platform.hpp` and vendored code.

Doing steps 1–2 before the Apple Silicon and Linux work turns each port into "add
`*_posix.cpp` / `*_darwin.cpp` files" instead of a hunt through 50 files. This would fit as an
epic with one bead per `oofnd` module plus one per Core/SDL cluster.

---

## Appendix B: `notes/2026-10-28 Modern C++ Idiom Review.md` section 1.3, verbatim

Kept for reference (the note itself is deleted). Counts and line numbers are as of 2026-10-28 and may have drifted.

### 1.3 Platform-specific macros

> Jon: Fully address section 1.3

- 1,235 conditional directives in 241 files. **201 are OS/toolkit/compiler platform tests in 53 files**, and ~123 of ~230 platform/feature directives sit inside function bodies.
- Counts: `OOLITE_WINDOWS` 63, `OOLITE_MAC_OS_X` 60, `_WIN32` 29, `OOLITE_SDL` 18, `OOLITE_LINUX` 16, endian macros 27.
- Feature switches are heavier than platform ones: `OO_DEBUG_MONITOR_ENABLED` has 186 directives in 86 files, and it is tested by `#ifdef` 173 times and by `defined()` 11 times while siblings are tested by value.
- Worst files: `GameController.cpp` (23 OS directives; 33 total), `Universe.cpp` (62 total), `OOLogHeader.cpp` (36), `OOOpenGLExtensionManager.cpp`, `OOFoundation.h`, `OOLogOutputHandler.cpp`, `OOCPUInfo.cpp`, `PlayerEntityControls.cpp`, `MyOpenGLView.cpp`.
- Body-level examples:
  - `PlayerEntityKeyMapper.cpp:147-155` (keymap file name by OS)
  - `ResourceManager.cpp:670-674` (`USERPROFILE` vs `HOME`)
  - `OOCPUInfo.cpp:91-122` (CPU count by OS, plus inline asm; `std::thread::hardware_concurrency()` is already used in `oofnd/Process.hpp:111`)
  - `OOOpenGLExtensionManager.cpp:581,646,669`
  - `OOJSOolite.cpp:290,373` (a feature gated by platform)
  - `main.cpp:89-156`
  - `Debug/OODebugTCPConsoleClient.cpp:426,597` (Winsock start-up)
  - oofnd itself: `Process.hpp`, `Thread.hpp`, `Http.hpp`, with `_WIN32` inside inline function bodies. `Http.hpp:366` has no non-Windows implementation.
- Build structure: every platform compiles the identical source list. `src/meson/{windows,linux}/meson.build` only add `-D` flags and libraries. `-DGNUSTEP_BASE_LIBRARY=1` is passed globally, so `OOLITE_MAC_OS_X` is always 0, and **about 787 lines of Mac code (43 blocks) are dead**, for example `GameController.cpp` (354 lines), `OOLogHeader.cpp` (155) and `OOLogOutputHandler.cpp` (145). `MOZ_TRACE_JSCALLS` branches (SpiderMonkey) are dead too.
- Win32 prototypes are hand-declared to avoid `<windows.h>` (`Process.hpp:50-58`, `Defaults.hpp:84-87`, `Thread.hpp:54-67`, `ResourcePaths.hpp:80`, `Http.hpp:73`), which accounts for most of the first-party `extern "C"`.
- Windows ANSI APIs are used without the `W` form (`main.cpp:95,106,145`, `OOCPUInfo.cpp:198`), so non-ASCII install paths will break.
- Already abstracted: SDL3 for window and input (only 30 `SDL_` lines in 8 Core files), OpenAL, and `oo::fs/process/env/thread/ResourcePaths/Defaults`, though those wrappers use `#if` inside the functions.
- **Fix:**
  - A `platform::` interface (`cpu_count`, `os_name`, `keymap_file`, `user_dir`, `message_box`, `socket_init`, `gl_proc_address`), with one source file per OS chosen in `src/meson/<os>/meson.build`.
  - A generated `config.hpp` of `inline constexpr bool`s with `if constexpr`.
  - `std::endian` instead of the endian macros.
  - Delete the Mac and SpiderMonkey dead code.
