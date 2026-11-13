# Contract: running the component tests

The component tier has two halves after this feature:

| Half | Where | What it needs |
|---|---|---|
| **C++ (headless)** | `tests/component/cpp/` | nothing: no display, no desktop, any platform |
| **Windowed (Python)** | `tests/component/*.py`, `features/`, `steps/` | the real game window; one at a time |

Both are "component tests". The words *headless* and *windowed* tell them apart where it matters.

## `tests/run.sh`

| Command | Does |
|---|---|
| `tests/run.sh component` | the C++ half, then the windowed half |
| `tests/run.sh component --cpp` | the C++ half only: `meson test -C build/meson_$BUILD_TYPE --suite component --print-errorlogs` |
| `tests/run.sh component --windowed` | the windowed half only (pytest, as today) |
| `tests/run.sh component [--cpp\|--windowed] -k <name>` | the same, filtered by name |
| `tests/run.sh all` | unit, component (both halves), smoke, then gui: the order is unchanged |

- With no flag, the C++ half runs first because it is fast and needs nothing. If it fails, the
  windowed half still runs, and the exit status is nonzero.
- `tests/run.sh component` with no flag keeps meaning "all the component tests", so nobody who
  runs it today loses coverage.
- The help text at the top of `run.sh` lists the two flags.
- The C++ half needs the built application directory, because the programs read `Resources` from
  it.
- CI on macOS, Fedora and in the Flatpak build runs `--cpp` only.

## Meson

- `tests/component/cpp/meson.build` is included from the top-level `meson.build` on every host,
  with no platform guard.
- Each program is `executable(name, source, oo_component sources, objects:
  oolite_bin.extract_objects(all game sources except src/SDL/main.cpp), …)` with the game's
  include directories, dependencies and options, as `tests/unit/core/meson.build` does for
  `['*']`.
- On Linux and macOS each program also compiles `gl_trap.cpp`, a `custom_target` output of
  `tests/component/cpp/gl_trap_gen.py` run over the game's objects.
- `test(name, exe, suite: 'component', timeout: 60, workdir: <built application directory>,
  env: …)`. The environment carries the source root, for the layouts and fixtures, and the build
  root, for scratch.
- A C++ scenario has the same base name as its windowed original:
  `cpp/test_s1_police_kills_pirate.cpp` beside `test_s1_police_kills_pirate.py`.
- Programs run in parallel. None declares `is_parallel: false`.
- A program that registers no cases exits 2, by the harness's own rule.

## Scratch

`<build>/component/scratch/<program>-<pid>/`. Created by `oo_component` at start. Left in place
after a failure, removed after a pass.

## The GL trap generator

`tests/component/cpp/gl_trap_gen.py <objects…> -o gl_trap.cpp`

- Runs the toolchain's `nm` on the objects, collects every undefined symbol that is a GL
  function, and writes one definition per symbol that prints `GL call <name> while headless` and
  aborts.
- Exit 0 on success, 2 on a usage error or if `nm` is missing.
- `--self-test` runs it over a fixture object and checks the output.
- Committed `100755` with a `#!` line.

## Repeat check

`tests/component/cpp/repeat_100.sh <program>` runs the program 100 times with `--digest-out`,
compares the digest files and exits nonzero at the first difference, printing the run number and
the step. Committed `100755`. It is run at milestone M3 and before the feature is finished. It is
not part of `tests/run.sh component`, because it takes 100 start-ups.

## Sanitizers

```text
meson setup build/meson_asan -Db_sanitize=address,undefined -Db_lto=false   (once)
meson test -C build/meson_asan --suite component --print-errorlogs
```

No suppression is added for the C++ component tests. A report is a finding.

## CI (`.github/workflows/build-all.yaml`)

| Job | Added step |
|---|---|
| `unit-tests-windows` | `tests/run.sh component --cpp` after `tests/run.sh unit` |
| `build-macos` | a test-flavour build with LTO off, then `tests/run.sh component --cpp` |
| `build-fedora` | `tests/run.sh component --cpp` after its test-flavour build |
| `build-flatpak` | sets `OO_FLATPAK_RUN_COMPONENT=1`; the manifest's Oolite module then runs `meson test --suite component` inside the build sandbox before install |

The Flatpak step is opt-in by the variable, so a packager building the Flatpak elsewhere is not
made to run tests.

## Exit status

`tests/run.sh component --cpp` exits zero only if every C++ program passed, including the census.
