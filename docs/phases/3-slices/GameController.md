# Slice plan: GameController

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-q9l2w). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/GameController.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/GameController.mm` (1,252 lines, of which ~330 are the Mac-only category) +
  header (236 lines). One class, `GameController`, the application controller: the singleton,
  pause and mouse-mode state, the frame loop with its deferred calls (`OOScheduleDeferredCall`),
  start-up and the splash / progress messages, exit, and the save-directory lookup. Its
  `FullScreen` category lives in two more files: `SDL/GameController+SDLFullScreen.mm` (177 lines,
  compiled; bead oo-qinv) and `Core/GameController+FullScreen.mm` (173 lines, wholly
  `OOLITE_MAC_OS_X`, in no `meson.build`; bead oo-b7hg).
- **Mechanical split (this bead, behaviour-neutral):** every whole Mac-only unit of the class moved
  verbatim, in the same file, into one `@implementation GameController (MacOSX)` at the end of
  `GameController.mm`, wholly under `#if OOLITE_MAC_OS_X`, beside `SetUpSparkle()`: the menu
  actions, the snapshots-folder and add-ons helpers, the dock menu, `-awakeFromNib`, the
  application-delegate methods, and the Mac arms of `-performGameTick:`,
  `-cxx_exitAppWithContext:` and the two debug-progress accessors. The compiled arms left behind
  are guarded `#if !OOLITE_MAC_OS_X` / `#if OOLITE_SDL`, and the `#error Unknown environment!`
  guards stay. The Windows/SDL translation unit is token-for-token the same (preprocessed before
  and after, line markers aside). Same file, so the deny-list's per-file count is unchanged; a new
  file would have no baseline (the "file split" limitation in `tools/guardrails.sh`).
- **mac-only:** the plan's `mac-only:` group (new in `tools/check-slice-plan.py`, bead oo-q9l2w)
  holds that category and `SetUpSparkle()`. The checker proves each of its units lies wholly in an
  `OOLITE_MAC_OS_X` arm; no slice reads it, `tools/gen-stories.py` emits no story for it, and a
  mac-only entry claims the Mac arm of a method a slice names exactly. The fleet never compiles
  it and does not convert it: Phase 5 writes the Mac layer again (ADR-0009; ADR-0056 amendment
  oo-bgmb item 2; ADR-0043 item 18(b)). When slice 1 turns `GameController` into a C++ class
  this category stays, fenced, as a category of the façade. `#if OOLITE_MAC_OS_X` fragments
  *inside* compiled methods (`-dealloc`, `-applicationDidFinishLaunching`, `-cxx_logProgress:`,
  `-endSplashScreen`, the startup-exception alert) stay where they are, fenced as they are.
- **Shape:** three slices of `GameController.mm`: (1) the class shell, state and accessors;
  (2) the frame loop and the deferred calls; (3) start-up, splash and progress messages, exit,
  and the player-file / save-directory methods.
- **Slice 1 carries the façade.** 34 files message `GameController` by selector, so slice 1 makes
  `cxx::GameController` and a façade under the old name that copies the whole old `@interface`
  including the `FullScreen` category declarations (house style, ADR-0056). Methods of slices 2
  and 3 stay Objective-C on the façade until their slice. The `FullScreen` category files stay
  Objective-C categories of the façade after slice 1, reading the full-screen state through the
  façade's `@public _cxxController` (amendment oo-bj8 item 2's mechanical `_cxxController->`
  rewrite, done in slice 1 for the compiled `SDL/GameController+SDLFullScreen.mm`).
- **The deferred calls** (`OOScheduleDeferredCall()`, `FireOneDueDeferredCall()`,
  `NextDeferredCallDeadline()`, `NextGameTick()`) are file-scope functions with Objective-C in
  their bodies (retain / release / perform of an `id` target and `SEL`), so they are slice 2 units,
  not verbatim. `OOScheduleDeferredCall(id, SEL, id, NSTimeInterval)` has ten callers outside this
  file: its signature does not change (no new interface); only the bodies do.
- **Category files:** oo-qinv converts `SDL/GameController+SDLFullScreen.mm`'s methods into
  `cxx::GameController` members after slice 1 (amendment oo-o89 item 4). oo-b7hg's file is
  Mac-only and uncompiled: by amendment oo-bgmb item 2 it is not adapted in Phase 3 (recommended
  default: defer it to Phase 5 with the rest of the Mac layer); it waits on oo-b5e4.
- **Order:** after the module pattern seam and this pre-split. Slice 1 first; slices 2 and 3 and
  oo-qinv are then independent. oo-b5e4 ("Convert to C++20: GameController.m") is the umbrella:
  it depends on the three slices and oo-qinv; its acceptance is every slice's `--slice-done` plus
  the header grep (a whole-file grep of `GameController.mm` would also hit the fenced Mac
  category, which ADR-0043 item 18(b) skips).

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | class shell: `+sharedController`, `init`, `dealloc`, pause, EcoQoS, mouse interaction modes, `gameView`, `finishedLaunching`, `suppressClangStuff`; the façade | ~180 | ~630 |
| 2 | frame loop: `performGameTick:`, `doPerformGameTick`, animation timer, due timers / deadlines, `runFrameLoop`; the deferred-call functions | ~235 | ~680 |
| 3 | start-up (`applicationDidFinishLaunching`, `loadPlayerIfRequired`, splash), progress and debug-progress messages, exit, player file / save directory, startup-exception report | ~300 | ~750 |
| mac-only | `GameController (MacOSX)` and `SetUpSparkle()`: fenced, not converted (Phase 5) | ~330 | not read |

```slice-plan
source: upstream/oolite/src/Core/GameController.mm
header: upstream/oolite/src/Core/GameController.h

slice 1: class shell, state and accessors
  +[GameController sharedController]
  -[GameController init]
  -[GameController dealloc]
  -[GameController isGamePaused]
  -[GameController setGamePaused:]
  -[GameController setEcoQoS:]
  -[GameController mouseInteractionMode]
  -[GameController setMouseInteractionMode*]
  -[GameController gameView]
  -[GameController setGameView:]
  -[GameController finishedLaunching]
  -[GameController suppressClangStuff]

slice 2: frame loop and deferred calls
  -[GameController performGameTick:]
  -[GameController doPerformGameTick]
  -[GameController startAnimationTimer]
  -[GameController stopAnimationTimer]
  -[GameController performGameTickIfDue]
  -[GameController fireDueDeadlines]
  -[GameController fireDueTimers]
  -[GameController runFrameLoop]
  NextGameTick()
  OOScheduleDeferredCall()
  FireOneDueDeferredCall()
  NextDeferredCallDeadline()

slice 3: start-up, splash and progress messages, exit, player file
  @GameController

mac-only: the Mac layer (menu actions, NIB, application delegate, Sparkle); Phase 5
  @GameController(MacOSX)
  SetUpSparkle()
```
