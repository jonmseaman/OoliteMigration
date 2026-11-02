# Port upstream #766, #774 and #781

**Series:** step 24 of 25 · base `series/023-c-as-cxx` · next `series/025-google-style-format` **(gen)**

**From:** `develop` commits `7912222ed`, `f80c74210`, `a1e2ce889`, `ac193cfe7`, `ec2462f6f`, `35d0ef8a0` · 1.1k src, 198 tests, 169 other changed lines; 223 lines in deleted files **(gen)**

## What this changes

The fork merged upstream `49a5eb9fc`, the base of this series, and ported the changes that
touch code the migration rewrote:

- #774: in windowed mode the splash window is replaced by a new game window that shares its GL
  context, instead of being re-decorated (the blank window after the splash on Linux/X11).
- #766, the parts that run everywhere: the mouse converts between SDL's points and the view's
  pixels (high-DPI displays); `addShipToShipyard` without a personality stores 0;
  `OOGLProgramName`; `OOLITE_MAC_COCOA_UI` names the AppKit front end, so `OOLITE_MAC_OS_X` means
  Apple Foundation and the OS, as upstream.
- #766 and #781, macOS: SDL's GL headers on Apple, the 2.1 legacy context's extension check, the
  MSAA renderbuffer, GLSL 330 to 120 translation (built everywhere and tested), the window
  surface, the bundle's working directory. Compiled out until a macOS build defines
  `OOLITE_MAC_OS_X`, except the shader translator; the macOS meson file and package script
  follow the C++ tree (QuickJS-ng, no Foundation, no SpiderMonkey).
- Where the merge resolved upstream's side differently, the fork's resolution: upstream's
  SpiderMonkey build script for macOS and its patch go, and the workflow files and `README`
  follow the fork's build.

## Why

These are upstream's own changes since the history last pulled it, written once against the C++
code. With them the series' code matches upstream at `49a5eb9fc`, on every platform the C++
code builds for.

## Behaviour changes

- Windowed start-up on Linux/X11 shows the game window instead of a blank one (#774).
- Mouse warping and motion are right on high-DPI displays (#766).
- `addShipToShipyard` without a personality no longer fails (#766).

## How to review

Compare each port with the upstream commit it names (`7f5ad9e0b` for #774, `3193dfe80` and
`d290865ec` for #766 and #781). The macOS code is dormant; `OOShaderProgram`'s translator is the
part that runs everywhere and has tests. The tests pass under the GL test context.

## Verified **(gen)**

Not verified yet.

macOS (its platform code is not converted yet) and Linux are not verified by this series.
