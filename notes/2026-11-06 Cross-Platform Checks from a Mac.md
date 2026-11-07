# Cross-platform checks from an Apple Silicon Mac

Plan, 2026-11-06. Nothing here is built yet; the tool behaviour below is from general knowledge,
not tried on this repo.

## Why

Two Windows-only breaks reached CI on 2026-11-06 because the Mac build never compiles the
Windows branches:

- `src/Core/OOProfilingStopwatch.h`: the Google-style reformat (`9157d0993`, `IncludeBlocks:
  Regroup`) sorted `<timeapi.h>` ahead of `<windef.h>`. Windows-only, so macOS never saw it. Fixed
  in `812377a83` with `// clang-format off`.
- The unit suites (`oofnd`, `core`, `headers`) are only built on Windows (`meson.build:130`), so a
  green Mac `tests/run.sh unit` runs nothing.

The goal is to catch this class of break before pushing, from the Mac (arm64), without waiting for
GitHub's Windows runner.

## Options

| Target | Method | Checks | Cost |
|---|---|---|---|
| Windows x64 | `llvm-mingw` (clang, mingw-w64 headers), `--target=x86_64-w64-mingw32 -fsyntax-only` | compiles the `OOLITE_WINDOWS` branches against real Windows headers | low; third-party headers needed |
| Windows x64 | Wine (`brew install --cask wine-stable`, runs x86_64 through Rosetta) running cross-compiled `oofnd` tests | console tests such as `test_http` and its winsock server | medium; not for the game or the GUI tests |
| Windows x64 | Windows 11 ARM VM (Parallels, UTM, VMware Fusion) with MSYS2 UCRT64 | the exact CI commands, `./mk.sh build test`, `tests/run.sh unit` | high; slow, closest to CI |
| Ubuntu x64 | Docker `--platform linux/amd64` | CI's architecture under emulation; unit tests | medium; slow |
| Ubuntu | Docker `linux/arm64` | glibc, GCC and Linux differences, natively fast | low |
| Both | push the feature branch, `gh run watch` | the real CI | none to set up; slow loop |

`act` runs GitHub workflows locally in Docker but only the Linux jobs, never the Windows ones.

## Plan

Do these in order; stop when the cost outweighs the catch rate.

1. **Windows syntax check (script).** `tools/check-windows-syntax.sh` in `oolite-dev`.
   - Obtain `llvm-mingw` (release tarball into `.agent-tmp/` or a cache directory, not in the
     repo) and a sysroot of MSYS2 UCRT64 packages for the dependencies (SDL3, OpenAL, libvorbis,
     libpng, zlib, libcurl, ICU, espeak-ng). Fetch and unpack in their own empty directories.
   - Run `clang++ --target=x86_64-w64-mingw32 -std=c++20 -fsyntax-only -DOOLITE_WINDOWS=1 ...`
     over `src/` (and `tests/unit/oofnd`), using the flags from the Windows meson build.
     No `-Wno-*` (hard rule 2).
   - First milestone: `src/oofnd/*.hpp` and `tests/unit/oofnd/*.cpp`, which need only libcurl and
     ICU. Second milestone: the game sources.
   - Verification: the script exits nonzero on `812377a83^` (timeapi.h before windef.h) and zero on
     the current tree.
2. **Linux container script.** `tools/check-linux-docker.sh`.
   - An Ubuntu image matching CI, installing packages through
     `ShellScripts/Linux/install_packages_root.sh`.
   - Builds with Clang and with GCC (`--native-file=gcc.ini`), default `linux/arm64`, with an
     option for `--platform linux/amd64`.
3. **Unit tests on macOS and Linux.** The `oofnd`, `core` and `headers` suites are Windows-only in
   `meson.build` because they use `<process.h>`, `_putenv_s`, winsock and a 32-bit `long`. Porting
   them is the larger fix; until then, a hand-compiled test such as
   `clang++ -std=c++20 -Isrc -Itests/unit/oofnd tests/unit/oofnd/test_http.cpp -lcurl` is the
   workaround.
4. **Wine run of the `oofnd` tests** from step 1's cross-compiled executables, if step 1 pays off.
5. **Windows ARM VM**, only when something needs a real Windows run (GUI tests, installer).

## Decisions and defaults

- Syntax-only first. Linking and running need Windows builds of every dependency; add them only if
  syntax checks leave real gaps.
- Scripts live in `oolite-dev/tools/` and are committed `100755` with a `#!` shebang
  (`git ls-files -s`).
- Scratch and downloaded toolchains go under `.agent-tmp/` or a cache directory outside the
  workspace only if the user approves; downloaded archives are untrusted input.
- Format shell with the repo's conventions; C++ helpers with clang-format 22
  (`/opt/homebrew/opt/llvm@22/bin/clang-format`).

## Open questions (default taken)

- Which mingw sysroot: MSYS2 package extraction (matches CI's packages) over a hand-built one.
- Whether to gate pushes on step 1 (a git hook): not yet; run it by hand until it is stable.
