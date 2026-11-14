# Cutting the four build flavours to three

**Status:** draft proposal, not started · **Written:** 2026-11-13 · **Target:** upstream
(OoliteProject), not the fork alone

Nothing in `oolite-dev` has changed. `mk.sh` takes one of four build types: `deployment`, `test`,
`dev` and `debug`. This note explains what each one is for, which of them are worth keeping, and
how to get rid of the rest without the fork drifting from upstream.

**Recommendation: three flavours, and the change goes to upstream first.** Keep `deployment` and
`debug`. Merge `test` and `dev` into a single optimised build with assertions on, and make
`DEV_RELEASE` a setup flag rather than a flavour of its own. Cutting to two (debug/release) loses
the one combination that has actually caught a shipped-game bug: optimised code with assertions
still live.

## What the four are now

They come from upstream's `mk.sh` (identical in `upstream/oolite` at `4bb1f53de`, 2026-11-08) and
the options in `meson.options`. Upstream's GNUmakefile had the same four years before meson
(`release-deployment`, `release`, `release-snapshot`, `debug`).

| Flavour | `meson setup` flags | Preprocessor | Unit tests |
|---|---|---|---|
| `deployment` | `deployment_release`, `debug=false`, strip, LTO | `NDEBUG`, `OO_CHECK_GL_HEAVY=0`, `OO_LOCALIZATION_TOOLS=0`, `DEBUG_GRAPHVIZ=0`, FOV control off; debug monitor and OXP verifier on | not built |
| `test` | `debug=false`, strip, LTO | assertions and every debug option on (option defaults) | built |
| `dev` | `dev_release`, `debug=false`, no strip, no LTO | as `test`, plus `DEV_RELEASE` | built |
| `debug` | `debug=true`, no strip | as `test` | built |

`DEV_RELEASE` affects two things, both cosmetic: the log header says "development version …"
(`src/Core/OOLogHeader.cpp:156`), and the HUD draws a "Development version" watermark
(`src/Core/Universe.cpp:5698`).

### Which CI job uses which (upstream `build-all.yaml`)

| Job | Flavour | Publishes |
|---|---|---|
| `build-appimage` (Arch) | `deployment` | AppImage |
| `build-flatpak` | `deployment` | Flatpak |
| `build-windows` | `deployment` | NSIS installer |
| `build-macos` | `deployment` | DMG |
| `build-ubuntu` | `dev` | nothing (builds an AppImage, doesn't upload it) |
| `build-fedora` | `test` | nothing |
| none | `debug` | none |

Every artefact users can download is `deployment`. `dev` and `test` each appear in one Linux job,
and the two jobs differ in distro as much as in flavour. No CI job builds `debug`.

## What each flavour is actually for

- **`deployment`** is the build players get. It can't go.
- **`debug`** is the build you put under a debugger. It costs CI nothing, and every C++ project has
  one. Keep it.
- **`test`** exists because `deployment` compiles assertions out. The test suites need a build
  that is optimised like the shipped one but still has the assertion and debug paths. That
  combination matters: `meson.build:117` records that compiling `OOCAssert` out under `NDEBUG`
  broke `PlayerEntity`'s `-deferredInit` ship setup in the shipped game, while every suite on the
  `test` flavour still passed. (`deployment_unit_tests` exists to close that gap from the other
  side.)
- **`dev`** is `test` with no LTO, no stripping and a watermark. It is a labelling variant for
  snapshot builds, and those snapshots are no longer published.

So `test` and `dev` overlap. Each is the same build ("optimised, assertions on") with different
link and strip settings.

## Options

### A. Leave it alone

No work and no divergence from upstream. The cost is a choice users have to make without guidance,
four `build/meson_*` directories for anyone who tries them all, and two CI jobs that look like
they test something different and mostly don't.

### B. Three flavours: `deployment`, `checked`, `debug` (recommended)

- `checked` (the name is open; `release-assert` and keeping `test` also work) replaces `test` and
  `dev`: `debug=false`, no `deployment_release`, no strip, LTO left at meson's default. Unstripped
  because the point of the build is diagnosis.
- `DEV_RELEASE` stays a meson option (`-Ddev_release=true`). Anyone who wants the watermarked
  snapshot passes it through `--setup-flags`. `build-ubuntu` either does that or drops it.
- `build-fedora` and `build-ubuntu` both build `checked`, so the distro is the only difference.
  One of them could also build `debug`, so that flavour stops going untested.

Every test that runs today still runs on a build with the same optimisation and assertion
settings. The only coverage lost is `test`'s LTO + strip with assertions on, which no other
flavour has. If that matters, `checked` turns LTO on and `dev` can go without anything changing.

### C. Two flavours: `release` (= `deployment`) and `debug`

The simplest list, but the suites then run either without assertions (on `release`) or
unoptimised (on `debug`). The `OOCAssert` / `-deferredInit` kind of bug, where behaviour depends
on whether assertions are compiled in *and* on optimisation, falls between the two. The only fix
would be a third build directory with hand-picked flags, which is option B left undocumented.
Not recommended.

## Why upstream first

The fork's job right now is getting ready to go upstream (ROADMAP), so every line of `mk.sh`, the
meson options, `build-all.yaml` and the installer scripts that differs from upstream turns into a
conflict at the next rebase onto `upstream-master`. The installer scripts take the flavour name as
an argument and put it in the artefact's file name (`Oolite-<ver>-<build_type>-<arch>.AppImage`,
`.dmg`, Flatpak suffix), so renaming a flavour also changes artefact names users can see.

Order of work:

1. Raise B with upstream as a discussion, citing the CI table above.
2. If they agree, open the change as an upstream PR (it touches `mk.sh`, `build-all.yaml`,
   `tests/run_test_fn.sh` (whose default build type is `dev`) and the installers' comments), then
   observe it into the stack like the other `seriesb/000*` branches.
3. If they don't, keep option A in the fork. The fork-only docs (`CLAUDE.md`,
   `docs/workflow.md`, `tests/run.sh`) can still point contributors at `test` and `debug` and say
   `dev` is a labelling variant.

## Open questions

- Is anyone upstream still using `dev` builds as nightly snapshots outside CI? The watermark only
  makes sense if they are.
- Name of the merged flavour. Keeping it as `test` means the fork's docs don't change and
  `./mk.sh build test` keeps working, but "test" also names the `mk.sh test` action
  (`./mk.sh test test`).
- Should `checked` keep LTO? With it, `checked` matches what ships more closely; without it,
  incremental builds are faster. Default if nobody decides: keep LTO, since what this build adds
  is that it matches what ships.
