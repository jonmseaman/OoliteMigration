# Make espeak-ng mandatory (retire the `espeak` build option)

Status: **undecided**. Not in `0_AI_Tasks.md`; Jon has not decided whether to do it.

## Context

Jon wants to remove the conditional macros around text-to-speech. Today speech hangs on one Meson
option:

```
meson.options:9  option('espeak', boolean, default true)
  → src/meson.build:31-33  dependency('espeak-ng') + -DHAVE_LIBESPEAK=1
    → OOFoundation.h:98-101  OOLITE_SPEECH_SYNTH 1, OOLITE_ESPEAK 1   (else :122-128 → 0)
```

There are 20 `#if OOLITE_ESPEAK` / `#if OOLITE_SPEECH_SYNTH` blocks across 7 files. Only two of them
have an `#else`, and both are trivial: the no-op stubs at `Universe.cpp:10505-10511` and the options
screen row layout at `PlayerEntity.h:210-211`.

**Nobody builds the "off" side.**
- **CI:** every job runs `mk.sh build … --setup-flags="-Ddocs=enabled"` (`.github/workflows/build-all.yaml`), so espeak is always on.
- **Dependency installers:** every platform installs espeak-ng: MSYS2 (`ShellScripts/Windows/install_deps.sh:16`), Linux (`install_packages_root.sh:83`), Homebrew (`macOS/install_packages.sh:18`). The Flatpak builds it from source (`space.oolite.Oolite.yaml:41-44`).
- **The two macros always move together.** `OOLITE_SPEECH_SYNTH` existed separately for upstream's macOS `NSSpeechSynthesizer` backend, which the C++ port removed. The 2026-11-12 code review (C4-13) found a latent uninitialised read that only an espeak-off build would compile.

So the off branch is rotting code that no tool checks.

## Pros and cons

**Pros**
- About 20 `#if` blocks, 2 macros, the Meson option and a `post_build.sh` argument go. The two `#else` stubs go too.
- Fewer configurations means less to reason about. The untested off path, and its latent C4-13 bug, disappear.
- The Piper idea (`notes/2026-11-14 Speech Synthesis.md`) also needs espeak-ng for pronunciation, so this doesn't close that door.

**Cons**
- **Hard dependency:** espeak-ng must be present to build. It is packaged for every current target. One open risk is the planned MSVC build (`notes/2026-11-08 Visual Studio MSVC Build.md:28` lists it as *optional*): check that vcpkg has an `espeak-ng` port before that work starts. If it doesn't, it would need a port or a stub.
- **Licence:** espeak-ng is GPL-3.0+. Oolite is GPL-2.0+, so the shipped binaries are already GPLv3 in effect, because espeak is on by default. Making espeak mandatory removes the option of a GPLv2-only build. This doesn't matter to the fork, but it is worth saying in the upstream PR.
- **Upstream divergence:** upstream keeps the option. That's a small rebase cost in 7 files, and upstream may decline this part of the series.

## Changes

1. **Build**
   - Delete the `espeak` option from `meson.options:9-10`.
   - In `src/meson.build:31-33`, always add `dependency('espeak-ng')` and drop the `-DHAVE_LIBESPEAK` define.
   - Drop the espeak argument at `src/meson.build:87`. In `ShellScripts/common/post_build.sh`, remove that positional parameter (`local espeak="$5"`, shifting the rest) and make the `espeak-ng-data` copy at `:62-97` unconditional. Check every caller of `post_build.sh` for the argument order.
2. **`OOFoundation.h`:** delete `:98-101` and the `#ifndef … 0` fallbacks at `:122-128`.
3. **Unwrap every `#if OOLITE_SPEECH_SYNTH` / `#if OOLITE_ESPEAK` block.** Keep the body and delete the `#else` branch:
   - `Universe.cpp:325, 366, 496, 7238-7292, 7264, 10445-10512, 10594`. The no-op stubs at `10505-10511` go.
   - `Universe.h:68 (the <espeak-ng/speak_lib.h> include), 463-467, 957-963`.
   - `PlayerEntity.cpp:1416, 1830, 2553, 9340, 9362`.
   - `PlayerEntity.h:200-212`: keep the speech rows. The `#else` row layout goes.
   - `PlayerEntityControls.cpp:156-161, 3808, 3858-3930, 4016`.
   - `MyOpenGLView.cpp:427-436`.

   Also remove the `// FIXME: should have voice option for OS X` comment at `PlayerEntity.h:203`, which only made sense for the macOS backend.
4. **Test, `tests/unit/core/test_Universe.cpp:1253,1275`:** remove the `#if OOLITE_ESPEAK` and `#endif` around `slice24Voices`, leaving the assertions unchanged. Jon signed off on this on 2026-11-15. Record it in a test-change ledger (the plan's notes, or the `0_AI_Tasks` entry) with the file, the two lines, and "assertions unchanged".
5. **Docs:** add a line to `Doc/CHANGELOG.TXT` saying espeak-ng is now required. Rewrite "optional espeak-ng" in the MSVC note as "espeak-ng (required)".

Leave alone: the comment in `tests/gui/test_g5_screen_round_trips.py:98`, which just names the old macro. Only edit it if it becomes misleading, and record that in the ledger, since it's a test file.

## Verification

- `./mk.sh build dev` passes with no new warnings, and `tests/run.sh unit` passes. `slice24Voices` still runs: check that it appears in the unit output.
- `git grep -nE 'HAVE_LIBESPEAK|OOLITE_SPEECH_SYNTH|OOLITE_ESPEAK|get_option\(.espeak.\)' -- src tests/unit meson.options ShellScripts` exits nonzero.
- Run `meson setup` once with `-Despeak=false`. It should now fail with "unknown option", which confirms the option is gone.
- Launch the game once (`tests/run.sh smoke`). The options screen still shows the speech rows, and speech works. The game's log header still lists features.
- Commit in `oolite-dev` on a `git town append` feature branch.
