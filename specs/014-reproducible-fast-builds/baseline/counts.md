# Baseline counts (2026-11-12)

Taken on a throwaway worktree of `develop` (3aa8d65e8), Windows, MSYS2 UCRT64, Clang 23.1.4. The
machine was running other builds, so the comparison is by **count of build steps**, not by time
(Jon, 2026-11-12). Nothing was compiled for the counts: each flavour was configured twice, with
`--ver-full=1.93.1-alpha.9001 --buildtime="2026.11.01 10:00"` and then with `…9002` /
`"2026.11.02 11:00"`, which is what a new commit changes, and `graph.py` walked the build graph.

How `graph.py` counts: a compile reruns when its command line changes (the two compile databases
differ) or when a header it includes changes (sources that include the generated `OOVersion.h`).
Every step downstream of a rerun step (archives, links, the post-build bundle step) reruns too.
The method was checked against a real build: on `develop`, a deployment build after the version
bump compiled 230 objects, the number `graph.py` predicts.

"Fix" is `oolite-dev` commit fa5e7e7e6 (version macros in a generated header), which is on
`feature/double-wide-support` and `seriesb/026-migration-completion` but not on `develop`. It
was ported by hand onto `develop` for the count, because its `src/SDL/main.cpp` hunk conflicts.

## Steps in a full build

| Flavour | Compiles | Core test links | oofnd test links | Game link | Other links |
|---|---:|---:|---:|---:|---:|
| deployment | 240 | 0 | 0 | 1 (LTO) | 3 |
| test | 806 | 174 (LTO) | 40 (LTO) | 1 (LTO) | 3 |
| dev | 806 | 174 | 40 | 1 | 3 |

In test and dev, `src/oofnd/Exception.cpp` and `src/oofnd/objc/OOAssert.cpp` are each compiled
177 times: once for the game and once for every test executable. That is 352 of the 806 compiles.

## What a version change (a new commit) reruns

| Flavour | `develop` today | `develop` + fa5e7e7e6 |
|---|---|---|
| deployment | 230 compiles, game link, bundle step | 5 compiles, game link, bundle step |
| test | 796 compiles, game link, 174 core + 40 oofnd test links, bundle step | 5 compiles, game link, 66 core test links, bundle step |
| dev | 796 compiles, game link, 174 core + 40 oofnd test links, bundle step | 5 compiles, game link, 66 core test links, bundle step |

The five files that include `OOVersion.h` are `PlayerEntity.cpp`, `Universe.cpp`,
`OOLogHeader.cpp`, `MyOpenGLView.cpp` and `main.cpp`. The first two are the two slowest compiles
in the game (17.4 s and 15.1 s in the deployment build's ninja log).

## What touching one game source reruns

| Flavour | `OOColor.cpp` | `Universe.cpp` |
|---|---|---|
| deployment | 1 compile, game link (LTO), bundle step | 1 compile, game link (LTO), bundle step |
| dev | 1 compile, game link, 84 core test links, bundle step | 1 compile, game link, 66 core test links, bundle step |

## Compile cost at -O2 and -O0 (`o0_vs_o2.py`)

CPU time of one compile (GetProcessTimes; the best of two runs), dev flavour's own command line
with only `-O2` swapped for `-O0`. CPU time moves much less than wall time on a busy machine.

| Source | -O2 | -O0 | -O0 / -O2 | Parse only (`-fsyntax-only`) | Preprocessed lines |
|---|---:|---:|---:|---:|---:|
| `OOColor.cpp` | 2.2 s | 2.0 s | 0.90 | 1.8 s | 201,711 |
| `ShipEntity.cpp` | 7.2 s | 3.5 s | 0.49 | 2.7 s | 239,310 |
| `PlayerEntity.cpp` | 10.4 s | 4.1 s | 0.39 | 3.0 s | 246,369 |

## Times from existing logs (wall time, machine busy: indicative only)

From the `.ninja_log` files of Jon's own `build/meson_*` directories:

- Reconfigure (`build.ninja` regenerated): 17–20 s. `mk.sh build` reconfigures on every run.
  Of that, the version script's PowerShell parent-process probe takes 0.35–0.65 s, and
  `gitversion` 2.7 s when the commit has changed.
- Game link: deployment 17–29 s (ThinLTO), test 38–47 s (ThinLTO), dev 1.5–2.4 s.
- Bundle step after each link: 1–16 s, once 262 s. It deletes and rebuilds every documentation
  PDF each time.
- Test-flavour core test links: 182 links summing 16,341 s of edge time, about 90 s each.

## Reproducibility observations

- No source in `src/`, `tests/`, `tools/` or `subprojects/` uses `__DATE__`, `__TIME__` or
  `__TIMESTAMP__`.
- On `develop`, 230 of the deployment build's 240 compile lines carry
  `-DOO_VERSION_FULL="…" -DOO_BUILD_DATE="YYYY-MM-DD" -DOO_BUILDER="unknown"`. With fa5e7e7e6,
  none do. Upstream OoliteProject (`4bb1f53de`) and the fork's `master` pass the same three.
- Every date and time `get_version.sh` produces is HEAD's committer time, not the wall clock. In
  Jon's build directories, the recorded `buildtime` equals the commit's UTC committer time: a3d651a
  `2026.11.12 04:26`, 518520d `2026.11.11 01:36`, 96bc042 `2026.11.12 12:01`.
- The version string carries the branch name (`gitversion` SemVer), so switching branches changes
  it as a new commit does.
- Every `oolite.exe` carries its link time in the PE header (`TimeDateStamp`), and `strip`
  stamps the copy it strips again: deployment `src/oolite.exe` 02:00:25 and the stripped
  `oolite.app/oolite.exe` 02:06:51 on 2026-11-11.
- The documentation PDFs carry the wall-clock time of the build to the second
  (`/CreationDate`, `xmp:CreateDate`). With `SOURCE_DATE_EPOCH` set, two typst runs are
  byte-identical.
- The stripped test-flavour `oolite.exe` holds 202 absolute paths into the toolchain
  (`C:/Users/jon/scoop/apps/msys2/2025-12-13/ucrt64/include/c++/16.2.0/...`, libstdc++ assertion
  messages). Paths into the checkout appear 234 times in the debug flavour (debug information),
  once in the unstripped deployment and test binaries, and not at all in dev or the stripped
  bundles.
