# Upstream PRs since the migration began

The fork's first migration commit is dated 2026-09-05. This list covers every PR merged into
`OoliteProject/oolite` `master` since then, plus the PRs still open, so each one can be reviewed for
whether the seriesb stack keeps its behaviour. Sources: `gh pr list -R OoliteProject/oolite`, and
`git log --first-parent upstream/master` up to `4bb1f53de` (fetched 2026-11-10).

The stack's base is `4bb1f53de` (#792) since Sync 2 (2026-11-11), when 000a/000b were reset to #767 `079fce06c` and #768 `cacb3c6a0`. Every PR up to #792 is therefore already in the code the
stack starts from; the question for those is whether the conversion steps keep their behaviour.
Steps use the numbers after T076's renumbering (old 019–025 are now 018–024). "Where" names the
step that converts or carries the PR's code and the test that pins it, where one exists. Step
numbers come from `series/review/placement-018-023.md` and the replay entries in `plan.md` Notes.
Each PR has a review document in [`series/upstream-review/`](series/upstream-review/README.md)
(reviewed 2026-11-10 at `oolite-dev` `518520d43`); the Reviewed column links it.

## Merged

| PR | Merged | Author | Title | In the stack | Where | Reviewed |
|--:|---|---|---|---|---|---|
| #734 | 2026-09-05 | mcarans | Fix all compiler warnings | base | converted by every step | [ ] [doc](series/upstream-review/pr-734.md) |
| #730 | 2026-09-06 | mcarans | Split MyOpenGLView into two | base | converted with `MyOpenGLView` (010–016) | [ ] [doc](series/upstream-review/pr-730.md) |
| #735 | 2026-09-07 | mcarans | Replace more Win32 code | base | converted (010–016) | [ ] [doc](series/upstream-review/pr-735.md) |
| #736 | 2026-09-07 | mcarans | Wrap clang pragma in `#ifdef __clang__` | base | converted | [ ] [doc](series/upstream-review/pr-736.md) |
| #717 | 2026-09-10 | mcarans | Switch to `--filesystem=/dev/input:ro` | base | flatpak manifest; 021 changes that manifest's QuickJS-ng source | [ ] [doc](series/upstream-review/pr-717.md) |
| #369 | 2026-09-12 | dybal | Allow installing equipment once an incompatible item has been removed | base | `test_OoliteEquipmentControlScript` at 009 | [ ] [doc](series/upstream-review/pr-369.md) |
| #737 | 2026-09-15 | mcarans | Rename OOCocoa to OOFoundation | base | naming kept 004–016; comment follow-ups on 004–009 | [ ] [doc](series/upstream-review/pr-737.md) |
| #740 | 2026-09-15 | mcarans | Remember last saved game and go to it when loading commander | base | 014; `lastsaveNameIsRememberedInTheDefaults` | [ ] [doc](series/upstream-review/pr-740.md) |
| #742 | 2026-09-17 | mcarans | Fix `decodeButtonEvent` warning on GCC (decoding in `OOSDLJoystickManager`) | base | layout kept from 003; `test_OOJoystickDecoding` at 010 | [ ] [doc](series/upstream-review/pr-742.md) |
| #744 | 2026-09-19 | mcarans | Remove usage of an undocumented Microsoft API | base | 011 | [ ] [doc](series/upstream-review/pr-744.md) |
| #745 | 2026-09-20 | mcarans | Add missing selectors | base | Objective-C selectors; retired with the classes that use them (008–016) | [ ] [doc](series/upstream-review/pr-745.md) |
| #747 | 2026-09-23 | mcarans | Common SDL3 `stringToClipboard`; Linux mouse control in line with Windows | base | 011; `copyUrlKey` test | [ ] [doc](series/upstream-review/pr-747.md) |
| #748 | 2026-09-23 | mcarans | Fix includes so include sorting doesn't break anything | base | include order 016; maths headers 018; `test_OOOpenGLOnly` at 009; `OOOpenGLOnly.h` Linux fix at 024 | [ ] [doc](series/upstream-review/pr-748.md) |
| #749 | 2026-09-24 | mcarans | clang-format code only | base | AnyKeyPressed reads at 014; layout redone by 023 | [ ] [doc](series/upstream-review/pr-749.md) |
| #751 | 2026-09-24 | mcarans | Add a clang-format workflow | base | CI on every step (T058); every step 003–024 passes clang-format 22 | [ ] [doc](series/upstream-review/pr-751.md) |
| #758 | 2026-10-09 | mcarans | Clang 23 and deployment build fixes | base | deployment build gated at every step from 011 on | [ ] [doc](series/upstream-review/pr-758.md) |
| #765 | 2026-10-17 | mcarans | Fix Windows build and make GNUstep versions consistent | base | GNUstep removed at 009; Windows build gated at every step | [ ] [doc](series/upstream-review/pr-765.md) |
| #756 | 2026-10-25 | mcarans | Debug monitor enabled in release build | base | `OO_DEBUG_MONITOR_ENABLED` guards 006–015; `check_debug_monitor_guards.py` from 021 | [ ] [doc](series/upstream-review/pr-756.md) |
| #766 | 2026-10-26 | hobleyd | Native Apple Silicon macOS build: app bundle, DMG installer and CI | base | macOS code converted 010, 012, 013 (MSAA renderbuffer), 016; packaging 022. macOS not verified | [ ] [doc](series/upstream-review/pr-766.md) |
| #778 | 2026-10-27 | stickleprojects | AppImage: set `LIB_DIR=/usr/lib64` on Fedora | base | reverted upstream by #782 | [ ] [doc](series/upstream-review/pr-778.md) |
| #774 | 2026-10-29 | stickleprojects | Fix blank game window after splash on Linux/X11 (#773) | base | 011 (splash window) | [ ] [doc](series/upstream-review/pr-774.md) |
| #781 | 2026-10-29 | hobleyd | macOS: keep the high-resolution Dock icon; document Developer ID signing | base | macOS bundle files (022). macOS not verified | [ ] [doc](series/upstream-review/pr-781.md) |
| #780 | 2026-11-01 | hobleyd | Use engine-neutral JavaScript names outside the scripting layer | base | carried through every step; `test_EntityScriptEvents` at 016 | [ ] [doc](series/upstream-review/pr-780.md) |
| #782 | 2026-11-01 | stickleprojects | CI: stop building the AppImage on Fedora; revert #778 | base | CI only | [ ] [doc](series/upstream-review/pr-782.md) |
| #783 | 2026-11-03 | phkb | Joystick control of GUI screens | ported | 022 (`022-upstream-28ceaaba0-ports`), with unit tests for each behaviour | [ ] [doc](series/upstream-review/pr-783.md) |
| #784 | 2026-11-04 | mcarans | Include documentation in builds | base | present at HEAD | [ ] [doc](series/upstream-review/pr-784.md) |
| #785 | 2026-11-04 | phkb | Add the missing Commander's Log page to Oolite RS; fix a typo | base | present at HEAD | [ ] [doc](series/upstream-review/pr-785.md) |
| #786 | 2026-11-05 | phkb | Move more text into `descriptions.plist` for localisation | base | present at HEAD | [ ] [doc](series/upstream-review/pr-786.md) |
| #787 | 2026-11-05 | hobleyd | Fix intermittent macOS snapshot test failures | base | present at HEAD | [ ] [doc](series/upstream-review/pr-787.md) |
| #788 | 2026-11-05 | mcarans | Release only deployment builds; include the documentation zip in releases | base | CI; release trigger narrowed by the fork's 977698a93 | [ ] [doc](series/upstream-review/pr-788.md) |
| #789 | 2026-11-05 | phkb | Add missing info to various Oolite RS pages | base (stack's base commit) | documentation only | [ ] [doc](series/upstream-review/pr-789.md) |
| #792 | 2026-11-08 | hobleyd | Build the documentation with typst only, and make it optional | base (since Sync 2) | merged into every step by hand on 2026-11-11; `post_build.sh` reads `build_docs` as `${13}`, and as `${12}` from 026, where the GNUstep argument goes | [ ] [doc](series/upstream-review/pr-792.md) |

## Open (as of 2026-11-10)

| PR | Opened | Author | Title | Relation to the stack | Review |
|--:|---|---|---|---|---|
| #767 | 2026-10-21 | hobleyd | Replace SpiderMonkey 1.8.5 with QuickJS-ng behind `-Djs_engine=quickjs` | the stack's first base branch, `seriesb/000a` | [doc](series/upstream-review/pr-767.md) |
| #768 | 2026-10-21 | hobleyd | Make QuickJS-ng the only JavaScript engine; remove SpiderMonkey | `seriesb/000b` at `cacb3c6a0` (10 Nov); its binding, with the 9 Nov fixes, is carried through every step | [doc](series/upstream-review/pr-768.md) |
| #771 | 2026-10-21 | hobleyd | SDL_GPU renderer, opt-in with `-Drenderer=sdl_gpu` | not in the stack | [doc](series/upstream-review/pr-771.md) |
| #772 | 2026-10-22 | hobleyd | Test more of the game: in-game JavaScript tests, a longer smoke test and a wider parity probe | not in the stack | [doc](series/upstream-review/pr-772.md) |
| #794 | 2026-11-06 | hobleyd | Add a key bindings screen on '9' | not in the stack | [doc](series/upstream-review/pr-794.md) |
| #738 | 2026-09-13 | mcarans | Rebased Rescaling Experiment IV | not in the stack | [doc](series/upstream-review/pr-738.md) |
