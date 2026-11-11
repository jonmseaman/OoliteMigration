# Upstream PR review against the seriesb stack

One document per upstream `OoliteProject/oolite` PR merged since 2026-09-05, plus the open ones,
saying whether the stack's tip keeps that PR's behaviour. Reviewed at `oolite-dev` `518520d43`
(`seriesb/026-migration-completion`) on 2026-11-10, with upstream fetched the same day. The review
used read-only git and grep only: nothing was built or run, so each verdict is a reviewer's reading
of the code for Jon to adjudicate, not a test result.

The stack's base is upstream master `148575aab` (#789), so every PR up to #789 is below the
conversion. For those, the question is whether the conversion steps kept the behaviour. #792 came
after the base and is not in the stack.

## Needs action

1. **#766, macOS user-data locations lost (regression).** `a78613a9d` deleted the
   `OOLITE_MAC_OS_X` branches as dead code. Nothing macOS-specific replaces them:
   - **Logs:** `src/Core/OOLogOutputHandler.cpp:310-322` has no macOS branch, so the logs go to a
     relative `Logs`, inside the app bundle. Upstream wrote to `~/Library/Logs/Oolite`.
   - **Add-ons:** `src/oofnd/ResourcePaths.hpp:191-247` uses `~/GNUstep/Library/...` paths and
     drops `~/Library/Application Support/Oolite/AddOns`.
   - **Cache and preferences:** `OOCacheManager.cpp` and `Defaults.hpp` also move off `~/Library`.

   Merged upstream as it stands, this would move existing macOS players' add-ons and settings. See
   [pr-766.md](pr-766.md). I confirmed the log-path part myself against
   `148575aab:src/Core/OOLogOutputHandler.m:562`.
2. **#768, the stack's copy is behind upstream.** 000a and 000b are upstream's 7 Nov copy.
   Upstream pushed nine binding fixes on 9 Nov (`fd0ca9304` .. `16e5f84be`) that HEAD doesn't
   have. One example is the `rfind('(')` paths fix: HEAD still has the old code at
   `OOJavaScriptEngine.cpp:654`. Refreshing 000a and 000b also brings in #792, because upstream's
   heads sit on it. See [pr-768.md](pr-768.md) and [pr-767.md](pr-767.md).
3. **#788 and #751, CI policy.** These come from the fork's own 977698a93:
   - **Narrower release trigger:** the release job runs only on master and develop, where upstream
     also covers `*maintenance`. The maintenance clean-up conditions can no longer be true.
   - **Same-repo PRs skip all of CI:** the clang-format job is skipped on them, and every build
     job needs it.

   Decide this before upstreaming. See [pr-788.md](pr-788.md).
4. **#792, not in the stack.** Taking it conflicts in `post_build.sh`, `Windows/install_deps.sh`
   and `build-all.yaml`. The new `post_build.sh` argument is `${12}` in the fork, not upstream's
   `${13}`. See [pr-792.md](pr-792.md).

## Smaller notes

- **#787:** the fork's snapshot wait is stronger than upstream's, but two `sample` diagnostics
  #787 added are missing.
- **#730:** the key-array bound is `<`, not `<=`. That fixes an out-of-bounds write upstream makes
  on every F12 press, but F12 now also logs an unhandled-keydown line.
- **#783:** `clearMappings()` also resets the GUI button table. This fixes an upstream bug where
  unassigned buttons drive increase-thrust, and it is worth offering upstream.
- **Inherited from upstream, unchanged in the fork (worth raising upstream):**
  - #734: `OOTCPStreamDecoder.cpp:164-169` passes `(unsigned long)` to `%zu`.
  - #742: the SDL joystick decoder treats gamepad button-down as up
    (`OOSDLJoystickManager.cpp:134-145,258`).
- **Stale comments:**
  - `OOCocoa` named in five test comments, and `OOFoundation.cpp:3` still calls the file
    `OOFoundation.m` (#737).
  - `PlayerEntityLoadSave.h:56-59` describes macros that no longer exist (#740).

## All PRs

| PR | Title | In the stack | Verdict |
|--:|---|---|---|
| [#369](pr-369.md) | Allow installing equipment once an incompatible item is removed | base | Ported correctly |
| [#717](pr-717.md) | Flatpak `--filesystem=/dev/input:ro` | base | Ported correctly |
| [#730](pr-730.md) | Split MyOpenGLView into two | base | Ported with deviations (fork fixes) |
| [#734](pr-734.md) | Fix all compiler warnings | base | Ported correctly |
| [#735](pr-735.md) | Replace more Win32 code | base | Ported correctly |
| [#736](pr-736.md) | Wrap clang pragma in `#ifdef __clang__` | base | Superseded |
| [#737](pr-737.md) | Rename OOCocoa to OOFoundation | base | Ported correctly |
| [#740](pr-740.md) | Remember last saved game | base | Ported correctly |
| [#742](pr-742.md) | `decodeButtonEvent` GCC warning | base | Ported with deviations |
| [#744](pr-744.md) | Remove undocumented Microsoft API | base | Ported correctly |
| [#745](pr-745.md) | Add missing selectors | base | Superseded |
| [#747](pr-747.md) | Common SDL3 clipboard; Linux mouse | base | Ported correctly |
| [#748](pr-748.md) | Fix includes for include sorting | base | Ported correctly |
| [#749](pr-749.md) | clang-format code only | base | Ported with deviations (Google style) |
| [#751](pr-751.md) | clang-format workflow | base | Ported with deviations |
| [#756](pr-756.md) | Debug monitor in release build | base | Ported correctly |
| [#758](pr-758.md) | Clang 23 and deployment build fixes | base | Ported correctly |
| [#765](pr-765.md) | Fix Windows build; GNUstep versions | base | Ported correctly |
| [#766](pr-766.md) | Native Apple Silicon macOS build | base | **Regression** (macOS paths) |
| [#774](pr-774.md) | Blank window after splash on X11 | base | Ported correctly |
| [#778](pr-778.md) | AppImage `LIB_DIR` on Fedora | base, reverted by #782 | Not in the stack (expected) |
| [#780](pr-780.md) | Engine-neutral JavaScript names | base | Ported correctly |
| [#781](pr-781.md) | macOS Dock icon; signing docs | base | Ported correctly (macOS unverified) |
| [#782](pr-782.md) | Stop Fedora AppImage; revert #778 | base | Ported correctly |
| [#783](pr-783.md) | Joystick control of GUI screens | ported at 022 | Ported with deviations (one fix) |
| [#784](pr-784.md) | Include documentation in builds | base | Ported correctly |
| [#785](pr-785.md) | Commander's Log page in Oolite RS | base | Ported correctly |
| [#786](pr-786.md) | More text into `descriptions.plist` | base | Ported correctly |
| [#787](pr-787.md) | macOS snapshot test waits for console | base | Ported with deviations |
| [#788](pr-788.md) | Release only deployment builds; docs zip | base | Ported with deviations (CI policy) |
| [#789](pr-789.md) | Missing info in Oolite RS pages | base | Ported correctly |
| [#792](pr-792.md) | Docs with typst only, optional | **no** (merged 2026-11-08) | Not in the stack |
| [#767](pr-767.md) | QuickJS-ng behind `-Djs_engine` (open) | 000a (7 Nov copy) | Superseded by #768 |
| [#768](pr-768.md) | QuickJS-ng only (open) | 000b (7 Nov copy) | Ported with deviations (behind upstream) |
| [#771](pr-771.md) | SDL_GPU renderer (open) | no | Not in the stack (expected) |
| [#772](pr-772.md) | More game tests (open) | no | Not in the stack (expected) |
| [#794](pr-794.md) | Key bindings screen on '9' (open) | no | Not in the stack (expected) |
| [#738](pr-738.md) | Rescaling Experiment IV (open) | no | Not in the stack (expected) |

The 59 "(#580)" commits in HEAD's history are all upstream's (#767/#768). Each patch appears twice,
an earlier copy and the 7 Nov copy, merged in at `c6fe941e2`.
