# Platform-Specific Code

How to structure platform-specific code in modern C++, and how that applies to Oolite. The
codebase has ~150 platform conditionals (`_WIN32`, `__APPLE__`, `__linux__`, `OOLITE_*`) across
~50 files in `oolite-dev/src`, with no encapsulated platform interface.

## The modern approach

Modern C++ treats this as a build-structure problem more than a language one.

### 1. Let the standard library do it first

Much `#ifdef _WIN32` code predates standard coverage. Check these before wrapping anything:

- `std::filesystem`: paths, directory iteration, wide-char paths on Windows
  (`std::ofstream(std::filesystem::path)` handles UTF-16)
- `std::thread`, `std::jthread`, `std::chrono`, `std::this_thread`
- `std::endian` (C++20), `std::bit_cast`
- `std::to_chars` / `std::format` instead of locale-sensitive printf workarounds

Every macro deleted this way is one less to abstract.

### 2. One interface, one implementation file per platform, selected by the build

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

### 3. `if constexpr` for small inline differences

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

### 4. Rules that keep macros from spreading again

- Raw `_WIN32` / `__APPLE__` / `__linux__` tests appear only in `Platform.hpp` or in meson.
  Enforce with a grep in CI.
- Platform headers (`<windows.h>`, `<unistd.h>`, `<mach/…>`) are included only from
  `platform/*.cpp`.
- Name conditions by capability, not OS: `OO_HAVE_EXR_SNAPSHOTS`, `kHasPthreadSetName`, not
  `#ifdef __APPLE__`. The real reason is usually "this API exists here", not "this is Apple".

## Applying it to Oolite

The conditionals fall into three groups.

### `oofnd/*.hpp`: right abstractions, wrong place

`Thread`, `Process`, `FileSystem`, `Http`, `LogFile`, `ResourcePaths`, `Defaults`, `Date`.
These already present a platform-neutral API, but they are header-only with `#ifdef` inside
inline bodies. `Thread.hpp` and `Process.hpp` even hand-declare kernel32 functions to avoid
pulling `<windows.h>` into every includer, a workaround that is unnecessary once the bodies move
to `platform/*_win32.cpp`.

This is the cheapest, highest-value step: interfaces barely change; macros leave the headers.

### Core and SDL: direct OS calls

`OOCPUInfo`, `OOLogOutputHandler`, `OOOpenGLExtensionManager`, `OOOpenGLOnly.h`,
`OOFoundation.h`, `MyOpenGLView`, `GameController`, `OODebugTCPConsoleClient`, the
`PlayerEntity*` files, `OOJSEngineTimeManagement`, and others. For each cluster, either:

- route it through an existing `oofnd` facility,
- add a small `oo::platform` function, or
- delete it because SDL2 or `std::filesystem` already covers it.

### Vendored C: leave alone

`tinyexr.h`, `miniz`, `stb_image_write.h`, `MiniZip`. Their `#ifdef`s belong to upstream, and
the "don't rewrite C for its own sake" rule applies.

## Suggested order

1. Add `oofnd/Platform.hpp` (OS enum and capability constants) and the `platform/` directory
   with meson selection.
2. Move `oofnd` header bodies into `platform/*_win32.cpp` / `*_posix.cpp`, one module at a
   time.
3. Sweep Core/SDL clusters onto `oofnd` / `oo::platform`.
4. Add the CI grep that rejects raw platform macros outside `Platform.hpp` and vendored code.

Doing steps 1–2 before the Apple Silicon and Linux work turns each port into "add
`*_posix.cpp` / `*_darwin.cpp` files" instead of a hunt through 50 files. This would fit as an
epic with one bead per `oofnd` module plus one per Core/SDL cluster.
