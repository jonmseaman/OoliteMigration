# ADR-0028 — `oofnd` FileSystem, ResourcePaths and Data; Objective-C++ builds as C++20

**Status:** Proposed — default in effect (Claude Code, frontier agent, bead oo-i9q, 2026-09-23;
ADR-0013). Jon may override.
**Date:** 2026-09-23
**Implements** seam 2.6 of [Phase 2](../phases/2-oofnd.md) in
`upstream/oolite/src/oofnd/{FileSystem,ResourcePaths,Data}.hpp`; applies
[ADR-0011](0011-cpp20-then-cpp23.md) to the game build.

## Context

Seam 2.6 retires `NSFileManager`, `NSBundle` and `NSData` usage. Nothing fixed the shape of the
replacements, how faithfully they must reproduce GNUstep's path spellings, or how the game build
gets to C++20 so that an Objective-C++ file can include any `oofnd` header at all (every `oofnd`
header needs C++20; the game's `.mm` files were compiling as clang's default `gnu++17`).

## Decision

1. **`oo::fs` is a thin layer over `std::filesystem`**, `Path = std::filesystem::path`, using only
   the `std::error_code` overloads; fallible calls return `oo::Expected<T, std::error_code>`.
   Semantics are GNUstep's, not `std::filesystem`'s, where they differ: existence follows links
   and never fails; creating an existing directory succeeds; removing a missing path fails;
   `moveItem` never overwrites (`file_exists`); atomic writes go through a sibling temporary and
   a rename.
2. **Paths are UTF-8 at the Objective-C boundary**, converted only by `pathFromUTF8` /
   `utf8String` (a `std::string` fed straight to `path` is decoded in the ANSI code page on
   Windows). `utf8String` spells separators `/`, because GNUstep does (`NSHomeDirectory()` is
   `C:/Games/Oolite/oolite.app` even under `GNUSTEP_PATH_HANDLING=windows`; probed on
   gnustep-base 1.31), so strings built from `oofnd` paths are byte-identical to today's.
3. **`oo::ResourcePaths` reproduces today's lookups, not a new layout.** Home is GNUstep's rule on
   Windows (`HOMEPATH`, `HOMEDRIVE`-prefixed if it has no drive, else `USERPROFILE`), which
   `SDL/main.mm` points at the executable's directory; `$HOME` on POSIX. User library is
   `~/GNUstep/Library` (`ApplicationSupport`, `Caches` under it), every `OO_*DIR` override is
   honoured, the Windows extract path stays the relative `../AddOns`. It is a pure function of a
   `PathEnvironment` (platform, getenv, cwd) so it is unit-tested with fakes; the real
   environment is read with `GetEnvironmentVariableW`, which sees variables set at run time by
   `SDL_setenv_unsafe`. It never creates directories; that stays with the consumer. macOS
   (`NSBundle` resource paths, `~/Library`) is not reproduced: outside ADR-0017.
4. **`oo::Data` is a value type** over `std::vector<std::uint8_t>`, not `RefCounted`: NSData is
   immutable and shared by retain, which `const Data&` and moves already give without a count.
   `subdata` clamps instead of raising; `bytes()` of empty data is never null.
5. **Objective-C++ builds as `gnu++20`** (`cpp_std=gnu++20` in `src/meson.build`; meson's
   `cpp_std` also governs `objcpp`). `gnu`, not `c++20`, because the default it replaces was
   `gnu++17`. Two source consequences, both behaviour-free:
   - `OOCocoa.h` keeps `#define true 1` / `#define false 0` (game code keeps its int-typed
     `true`/`false`; changing 476 sites to `bool` could change `@()` boxing and overload choice),
     but first parses `<compare>` and `<optional>`, which break in C++20 when parsed under those
     macros (`bool(x) <=> false`). Every `oofnd` header that Objective-C++ includes suspends the
     two macros with `push_macro`/`pop_macro` around itself; `test_cocoa_macros.cpp` pins that.
   - `requires` is a C++20 keyword; the one local variable so named (`OOOXZManager.mm`) is renamed.

## Consequences

- Exemplar: `Core/OXPVerifier/OOOXPVerifier.mm` has no `NSFileManager` left (`oo::fs::fileType`;
  `-displayNameAtPath:` was GNUstep's `-lastPathComponent`, probed, so it is now that call).
- The C++20 switch adds a few C++20 deprecation warnings in existing files
  (`-Wdeprecated-enum-float-conversion`, `-Wdeprecated-anon-enum-enum-conversion`); they are
  left visible, not silenced. Golden-relevant flags (`-O2`, `-ffp-contract=off`) are unchanged.
- `Expected.hpp`, `Ref.hpp`, `WeakSet.hpp` do not yet carry the true/false guard; they are only
  reached today through a guarded header. The first game file to include one directly must add
  the same four lines (or `test_cocoa_macros.cpp` should be extended to include it).
- The Phase 3 conversion of `NSFileManagerOOExtensions` can delegate `defaultCommanderPath`,
  `chdirToSnapshotPath` and the log/managed/extract path helpers to `ResourcePaths` without moving
  a user's files.
