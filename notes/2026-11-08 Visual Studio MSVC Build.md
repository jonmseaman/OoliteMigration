# Building Oolite with Visual Studio (MSVC ABI): assessment and plan

## Context
Jon asked how hard it would be to build `oolite-dev` with C++ in Visual Studio. Today the only
Windows toolchain is MSYS2 UCRT64 (MinGW Clang/GCC, libstdc++, winpthreads, `-mwindows`), driven by
Meson + `mk.sh`. "Visual Studio" means a different ABI (MSVC STL, UCRT, MSVC import libs), so every
dependency changes and some GNU-only source constructs must go.

## Verdict
**Moderate, not hard.** The phase 0–4 work left the code far more portable than upstream's:
234 `.cpp` files, all C++20, no Objective-C, no GNUstep, Windows already a first-class target
(LLP64 `long`, `_WIN32` paths for threads, sockets, files). Meson already supports MSVC and can
emit a `.sln` (`--backend=vs2022`). QuickJS-ng officially supports MSVC.

Two tiers:

| Route | Effort | What breaks |
|---|---|---|
| **clang-cl** (VS's bundled LLVM toolset, MSVC ABI) | small: a few days | build files, deps, `cxxabi.h`, a couple of stray POSIX includes |
| **cl.exe** (MSVC proper) | medium: roughly 1–2 weeks on top | GNU extensions in hot headers, ~50 compound literals, warnings |

### What the survey found (src/, excluding vendored stb/tinyexr/miniz which already handle `_MSC_VER`)
Needed for **both** routes:
- **Meson flags are GNU-shaped**: `-mwindows` and `-pthread` in `src/meson/windows/meson.build` and
  `src/meson/meson.build`; `-O0` in `meson.build`; `-flto=auto` else-branch; `-gcodeview`/`-Wl,-pdb=`.
  Gate on `cc.get_argument_syntax() == 'msvc'` (win_subsystem already handles the GUI subsystem).
- **Dependencies** must be MSVC-built: SDL3, libpng, OpenAL Soft, libvorbis/vorbisfile, zlib, ICU
  (icu-uc, icu-i18n), optional espeak-ng. vcpkg (manifest mode, `x64-windows`) supplies all of these
  with pkg-config files Meson can read.
- **`abi::__cxa_demangle`** (`<cxxabi.h>`) in 9 files (e.g. `src/Core/OODrawable.cpp:64`,
  `src/Core/Scripting/OOScript.cpp:66`): one shared helper; on MSVC `typeid().name()` is already
  readable (strip the `class `/`struct ` prefix).
- `src/Core/OOCPUInfo.cpp:41` includes `<unistd.h>` on Windows; the GCC-style `cpuid` asm there →
  `__cpuid` from `<intrin.h>` under `_MSC_VER` (clang-cl accepts the asm, but the intrinsic is cleaner).
- `post_build.sh` / `generate_manifest_fn.sh` need `bash` on PATH (Git for Windows' is fine).
- Source files with non-ASCII (26) → `/utf-8`.

Additional for **cl.exe**:
- `MIN`/`MAX`/`ABS` are statement expressions with `__typeof__` (`src/Core/OOFoundation.h:109`,
  `src/Core/OOMathsBase.h:83`), ~200 call sites → one constexpr template using
  `std::common_type_t` (keeps single evaluation and mixed-type semantics).
- `(Vector){…}`-style compound literals: ~50 real ones (Vector, FloatRGB(A), NSPoint, Quaternion,
  HPVector, BoundingBox…) → `Vector{…}`.
- `__builtin_clz/clzll` (`src/Core/OOFastArithmetic.h:51`) → `std::countl_zero`;
  `__builtin_unreachable` in `src/oofnd/objc/OOAssert.cpp:36` → `__assume(0)`/guarded.
- Unguarded `__attribute__`: `OOStringExpander.cpp:244`, `MiniZip/unzip.cpp:125` (guarded),
  `oofnd/objc/OOAssert.h:55`, `oofnd/Exception.hpp:69` → `[[noreturn]]`; `OO_PRINTF_FORMAT` → empty
  under MSVC (`src/oofnd/PrintfFormat.h`).
- `alloca` (`OOLogHeader.cpp:334`) → `_alloca`; `__PRETTY_FUNCTION__` (18 files) → a macro mapping to
  `__FUNCSIG__`; `, ##__VA_ARGS__` (5) needs `/Zc:preprocessor`.
- Unknown-size tail: MSVC `/permissive-` conformance differences that Clang/GCC let through. Expect
  some dozens of small errors, found only by compiling.

### Risks
- **Warnings policy.** Hard rule 2 forbids silencing. MSVC `/W4` will print many C4244/C4267
  (narrowing, size_t→int) the GCC/Clang `-Wall -Wextra` set never flagged. Follow the oofnd
  precedent (`werror` under Clang only); fixing them is a separate, large job.
- **Floating-point output.** UCRT's libm differs from mingw-w64's in last-bit results; anything
  that compares numbers in dumps (component scenarios, `tests/unit/sysdesc`, `expander`) may diff.
  That would be a real finding for Jon to adjudicate, not something to "fix" in the tests.
- **Tests**: the unit suites are Windows-only and already use MSVC-native APIs (`_putenv_s`,
  `<process.h>`), so they should port; `tests/meson.build`'s libstdc++/libwinpthread PATH hack
  becomes unnecessary. `tests/run.sh` stays bash (Git Bash/MSYS) driving an MSVC-built binary.
- The VS IDE experience: Meson's VS backend works but is second-class (regeneration, custom
  targets). Alternative: Ninja + MSVC from a VS Developer prompt, with VS used as debugger via the
  existing PDB support. CMake would be "native" in VS but is a second build system: not proposed.

## Plan (if Jon wants to proceed): new spec `specs/0xx-msvc-build`, feature branch in `oolite-dev`
1. **vcpkg manifest** (`oolite-dev/vcpkg.json`) for the dependency list above; a native file
   `msvc.ini` / `clang-cl.ini` beside `clang.ini`/`gcc.ini`, plus `mk.sh` option to pick it.
2. **Meson gating**: MSVC-syntax branches for `-mwindows`, `-pthread`, `-O0`, LTO, PDB; add `/utf-8`,
   `/Zc:preprocessor`, `/Zc:__cplusplus`; drop the MinGW toolchain PATH test setup under MSVC.
3. **clang-cl first**: demangle helper, `OOCPUInfo` fixes; get `oolite.exe` + `oofnd`/`core`/`headers`
   suites green.
4. **cl.exe second**: MIN/MAX/ABS template, compound literals, builtins/attributes/`__PRETTY_FUNCTION__`
   macros, then iterate on conformance errors.
5. CI job (`.github/workflows/build-all.yaml`) on `windows-latest` with the VS toolchain, alongside the
   existing MSYS2 job (MSYS2 stays the reference build).

## Verification
- `meson setup build/msvc --native-file=msvc.ini` + `meson compile -C build/msvc` exits 0 (nonzero today).
- `meson test -C build/msvc --suite oofnd --suite core --suite headers` passes.
- `tests/run.sh component` and `smoke` against the MSVC binary; any numeric diff vs the MSYS2 build is
  reported, not patched.
- Existing MSYS2 Clang and GCC builds still pass `./mk.sh build test` (no regression).
