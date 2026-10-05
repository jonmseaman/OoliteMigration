# Slice plan: MyOpenGLView

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-pjy4). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/MyOpenGLView.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `SDL/MyOpenGLView.mm` (1,644 lines) + header (386 lines). One class, `MyOpenGLView`,
  the SDL3 window and OpenGL context owner (its input handling lives in `MyOpenGLView+Input`, a
  separate story). Two file-scope helpers, `DefaultsString()` and `SameMode()`, have no
  Objective-C and stay verbatim ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9).
- **Shape:** three groups: the window / GL lifecycle (window creation, `init`, the splash screen,
  GL state, `dealloc`); display modes, window and full-screen settings, the Windows display / HDR
  block with its non-Windows stubs, FOV / MSAA; and the snapshot and debug image dumps. Methods in
  both arms of `#if OOLITE_WINDOWS … #else` have the same selector and go to the same slice.
- **Lexer note:** `-adjustColorSaturation:` is defined with a stray `;` before its body (legal
  Objective-C). `tools/check-slice-plan.py` keeps a method head across such a `;`; before that fix
  the lexer lost the head and crashed on this file.
- **Order:** after the platform pattern seam (oo-o89). Slice 1 first: it converts the class shell
  and lifecycle; slices 2 and 3 are then independent.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | window / GL lifecycle: display id, native size, `createWindowWithSize:`, `init`, splash screen, GL setup, `dealloc`, `updateScreen` | ~695 | ~1,195 |
| 2 | accessors, screen-mode switching, full-screen mode list, saved window / full-screen settings, display / HDR / dark-mode (Windows and stubs), FOV, MSAA, shift-key poll | ~520 | ~1,020 |
| 3 | `cxx_snapShot:` and the debug image dumps | ~290 | ~790 |
| verbatim | `DefaultsString()`, `SameMode()` | — | not read |

```slice-plan
source: upstream/oolite/src/SDL/MyOpenGLView.mm
header: upstream/oolite/src/SDL/MyOpenGLView.h

slice 1: window and OpenGL lifecycle, splash screen
  -[MyOpenGLView getDisplayId]
  -[MyOpenGLView getNativeSize]
  -[MyOpenGLView getWindowCaption]
  -[MyOpenGLView createWindowWithSize:]
  -[MyOpenGLView init]
  -[MyOpenGLView endSplashScreen]
  -[MyOpenGLView initSplashScreen]
  -[MyOpenGLView updateGLSize:]
  -[MyOpenGLView setUpBasicOpenGLStateWithSize]
  -[MyOpenGLView initialiseGLWithSize:]
  -[MyOpenGLView dealloc]
  -[MyOpenGLView updateScreen]

slice 2: accessors, display modes, settings, display / HDR, FOV and MSAA
  @MyOpenGLView

slice 3: snapshots and debug image dumps
  -[MyOpenGLView cxx_snapShot:]
  -[MyOpenGLView cxx_dump*]

verbatim: plain C/C++ helpers, no Objective-C (checked)
  *
```
