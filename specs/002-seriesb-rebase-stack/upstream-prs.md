# Upstream PRs since the migration began

The fork's first migration commit is dated 2026-09-05. This list covers every PR merged into
`OoliteProject/oolite` `master` since then, plus the PRs still open, so each one can be reviewed for
whether the seriesb stack keeps its behaviour. Sources: `gh pr list -R OoliteProject/oolite`, and
`git log --first-parent upstream/master` up to `09ef336e7` (fetched 2026-11-05).

The stack's base is `7437f22a5` (#780). Every PR up to #780 is therefore already in the code the
stack starts from; the question for those is whether the conversion steps keep their behaviour.
Steps use the numbers after T076's renumbering (old 019–025 are now 018–024). "Where" names the
step that converts or carries the PR's code and the test that pins it, where one exists. Step
numbers come from `series/review/placement-018-023.md` and the replay entries in `plan.md` Notes.
Each one should be checked during the review.

## Merged

| PR | Merged | Author | Title | In the stack | Where | Reviewed |
|--:|---|---|---|---|---|---|
| #734 | 2026-09-05 | mcarans | Fix all compiler warnings | base | converted by every step | [ ] |
| #730 | 2026-09-06 | mcarans | Split MyOpenGLView into two | base | converted with `MyOpenGLView` (010–016) | [ ] |
| #735 | 2026-09-07 | mcarans | Replace more Win32 code | base | converted (010–016) | [ ] |
| #736 | 2026-09-07 | mcarans | Wrap clang pragma in `#ifdef __clang__` | base | converted | [ ] |
| #717 | 2026-09-10 | mcarans | Switch to `--filesystem=/dev/input:ro` | base | flatpak manifest; 021 changes that manifest's QuickJS-ng source | [ ] |
| #369 | 2026-09-12 | dybal | Allow installing equipment once an incompatible item has been removed | base | `test_OoliteEquipmentControlScript` at 009 | [ ] |
| #737 | 2026-09-15 | mcarans | Rename OOCocoa to OOFoundation | base | naming kept 004–016; comment follow-ups on 004–009 | [ ] |
| #740 | 2026-09-15 | mcarans | Remember last saved game and go to it when loading commander | base | 014; `lastsaveNameIsRememberedInTheDefaults` | [ ] |
| #742 | 2026-09-17 | mcarans | Fix `decodeButtonEvent` warning on GCC (decoding in `OOSDLJoystickManager`) | base | layout kept from 003; `test_OOJoystickDecoding` at 010 | [ ] |
| #744 | 2026-09-19 | mcarans | Remove usage of an undocumented Microsoft API | base | 011 | [ ] |
| #745 | 2026-09-20 | mcarans | Add missing selectors | base | Objective-C selectors; retired with the classes that use them (008–016) | [ ] |
| #747 | 2026-09-23 | mcarans | Common SDL3 `stringToClipboard`; Linux mouse control in line with Windows | base | 011; `copyUrlKey` test | [ ] |
| #748 | 2026-09-23 | mcarans | Fix includes so include sorting doesn't break anything | base | include order 016; maths headers 018; `test_OOOpenGLOnly` at 009; `OOOpenGLOnly.h` Linux fix at 024 | [ ] |
| #749 | 2026-09-24 | mcarans | clang-format code only | base | AnyKeyPressed reads at 014; layout redone by 023 | [ ] |
| #751 | 2026-09-24 | mcarans | Add a clang-format workflow | base | CI on every step (T058); every step 003–024 passes clang-format 22 | [ ] |
| #758 | 2026-10-09 | mcarans | Clang 23 and deployment build fixes | base | deployment build gated at every step from 011 on | [ ] |
| #765 | 2026-10-17 | mcarans | Fix Windows build and make GNUstep versions consistent | base | GNUstep removed at 009; Windows build gated at every step | [ ] |
| #756 | 2026-10-25 | mcarans | Debug monitor enabled in release build | base | `OO_DEBUG_MONITOR_ENABLED` guards 006–015; `check_debug_monitor_guards.py` from 021 | [ ] |
| #766 | 2026-10-26 | hobleyd | Native Apple Silicon macOS build: app bundle, DMG installer and CI | base | macOS code converted 010, 012, 013 (MSAA renderbuffer), 016; packaging 022. macOS not verified | [ ] |
| #778 | 2026-10-27 | stickleprojects | AppImage: set `LIB_DIR=/usr/lib64` on Fedora | base | reverted upstream by #782 | [ ] |
| #774 | 2026-10-29 | stickleprojects | Fix blank game window after splash on Linux/X11 (#773) | base | 011 (splash window) | [ ] |
| #781 | 2026-10-29 | hobleyd | macOS: keep the high-resolution Dock icon; document Developer ID signing | base | macOS bundle files (022). macOS not verified | [ ] |
| #780 | 2026-11-01 | hobleyd | Use engine-neutral JavaScript names outside the scripting layer | base (stack starts here) | carried through every step; `test_EntityScriptEvents` at 016 | [ ] |
| #782 | 2026-11-01 | stickleprojects | CI: stop building the AppImage on Fedora; revert #778 | base | CI only | [ ] |
| #783 | 2026-11-03 | phkb | Joystick control of GUI screens | ported | 022 (`022-upstream-28ceaaba0-ports`), with unit tests for each behaviour | [ ] |
| #784 | 2026-11-04 | mcarans | Include documentation in builds | **not yet** | T077 | [ ] |
| #785 | 2026-11-04 | phkb | Add the missing Commander's Log page to Oolite RS; fix a typo | **not yet** | T077 | [ ] |
| #786 | 2026-11-05 | phkb | Move more text into `descriptions.plist` for localisation | **not yet** | T077 | [ ] |
| #787 | 2026-11-05 | hobleyd | Fix intermittent macOS snapshot test failures | **not yet** | T077 | [ ] |

## Open (as of 2026-11-05)

| PR | Opened | Author | Title | Relation to the stack |
|--:|---|---|---|---|
| #767 | 2026-10-21 | hobleyd | Replace SpiderMonkey 1.8.5 with QuickJS-ng behind `-Djs_engine=quickjs` | the stack's first base branch, `seriesb/000a` |
| #768 | 2026-10-21 | hobleyd | Make QuickJS-ng the only JavaScript engine; remove SpiderMonkey | `seriesb/000b`; its binding is carried through every step |
| #771 | 2026-10-21 | hobleyd | SDL_GPU renderer, opt-in with `-Drenderer=sdl_gpu` | not in the stack |
| #772 | 2026-10-22 | hobleyd | Test more of the game: in-game JavaScript tests, a longer smoke test and a wider parity probe | not in the stack |
| #788 | 2026-11-05 | mcarans | Build and test only deployment builds; include the documentation zip in releases | not in the stack |
| #738 | 2026-09-13 | mcarans | Rebased Rescaling Experiment IV | not in the stack |
