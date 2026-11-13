# Contract: running the `sim` tier

## `tests/run.sh`

| Command | Does |
|---|---|
| `tests/run.sh sim` | `meson test -C build/meson_$BUILD_TYPE --suite sim --print-errorlogs` |
| `tests/run.sh sim -k <name>` | the same, for the one program named |
| `tests/run.sh all` | unit, **sim**, component, smoke, then gui |

- The help text at the top of `run.sh` lists the tier.
- `sim` needs the built application directory, like the other tiers, because the programs read
  `Resources` from it.
- On hosts where the unit suites are not declared (macOS, Linux), `all` skips `unit` as it does
  today and still runs `sim`.

## Meson

- `tests/sim/meson.build` is included from the top-level `meson.build` on every host, with no
  platform guard.
- Each program is `executable(name, source, oo_sim sources, objects:
  oolite_bin.extract_objects(all game sources except src/SDL/main.cpp), …)` with the game's
  include directories, dependencies and options, as `tests/unit/core/meson.build` does for
  `['*']`.
- On Linux and macOS each program also compiles `gl_trap.cpp`, a `custom_target` output of
  `tests/sim/gl_trap_gen.py` run over the game's objects.
- `test(name, exe, suite: 'sim', timeout: 60, workdir: <built application directory>, env: …)`.
  The environment carries the source root, for the layouts and fixtures, and the build root, for
  scratch.
- Programs run in parallel. None declares `is_parallel: false`.
- A program that registers no cases exits 2, by the harness's own rule.

## Scratch

`<build>/sim/scratch/<program>-<pid>/`. Created by `oo_sim` at start. Left in place after a
failure, removed after a pass.

## The GL trap generator

`tests/sim/gl_trap_gen.py <objects…> -o gl_trap.cpp`

- Runs the toolchain's `nm` on the objects, collects every undefined symbol that is a GL
  function, and writes one definition per symbol that prints `GL call <name> while headless` and
  aborts.
- Exit 0 on success, 2 on a usage error or if `nm` is missing.
- `--self-test` runs it over a fixture object and checks the output.
- Committed `100755` with a `#!` line.

## Repeat check

`tests/sim/repeat_100.sh <program>` runs the program 100 times with `--digest-out`, compares the
digest files and exits nonzero at the first difference, printing the run number and the step.
Committed `100755`. It is run at milestone M3 and before the feature is finished. It is not part
of `tests/run.sh sim`, because it takes 100 start-ups.

## Sanitizers

```text
meson setup build/meson_asan -Db_sanitize=address,undefined -Db_lto=false   (once)
meson test -C build/meson_asan --suite sim --print-errorlogs
```

No suppression is added for the `sim` suite. A report is a finding.

## CI (`.github/workflows/build-all.yaml`)

| Job | Added step |
|---|---|
| `unit-tests-windows` | `tests/run.sh sim` after `tests/run.sh unit` |
| `build-macos` | a test-flavour build with LTO off, then `tests/run.sh sim` |
| `build-fedora` | `tests/run.sh sim` after its test-flavour build |
| `build-flatpak` | sets `OO_FLATPAK_RUN_SIM=1`; the manifest's Oolite module then runs `meson test --suite sim` inside the build sandbox before install |

The Flatpak step is opt-in by the variable, so a packager building the Flatpak elsewhere is not
made to run tests.

## Exit status

`tests/run.sh sim` exits zero only if every program in the suite passed, including the census.
