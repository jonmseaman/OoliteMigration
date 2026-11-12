# Quickstart: validating the feature

Run everything from `oolite-dev`, on `feature/encapsulate-global-state` (built on spec 009's
branch), in an MSYS2 UCRT64 shell on Windows. The unit suites are Windows-only for now (research
R12); CI's `unit-tests-windows` job runs them on every push. The commands assume the `test` build
directory that `./mk.sh build test` creates (`build/meson_test`).

## 1. Build and guards

```bash
./mk.sh build test                            # Clang
./mk.sh build test --native-file=gcc.ini      # GCC; must also be warning-free
./mk.sh tidy                                  # spec 009's guards; no new findings
```

## 2. Inventory and ratchet (M0, then every stage)

```bash
meson test -C build/meson_test --suite core global-state --print-errorlogs
python3 tests/global_state_check.py --self-test
python3 tests/global_state_check.py --build-dir build/meson_test --count   # the current counts
```

**Expected:** exit 0, with a summary line of the form
`global-state: N globals, M todo, K kept; ratchet ok`.

**Proving the check bites.** In a scratch change, add `int sScratch = 0;` to any `src/Core` file
and rebuild. The check must exit 1 and name `sScratch` and the file. Revert afterwards.

## 3. Game context and controller pilot (M1)

```bash
meson test -C build/meson_test --suite core test_OOGameContext test_OOGame --print-errorlogs
meson test -C build/meson_test --suite core --print-errorlogs   # every existing test, unedited
```

**Expected:** both new tests pass. `test_OOGame` builds two games and schedules a deferred call
on one; the other never runs it. A lookup for a missing service raises, naming the type. A scope
swaps `gSharedUniverse`/`gOOPlayer` in and restores them. The whole `core` suite gives the same
results as on the base, with no test file changed (`git diff --stat <base> -- tests/unit` lists
only new files).

## 4. Moved services (each M2 stage)

```bash
meson test -C build/meson_test --suite core test_OOGameContext --print-errorlogs
```

**Expected:** the stage's destroy-a-context test (a context holding the moved service is built
and destroyed) passes, and ASan reports nothing on platforms that have it.

## 5. Headless scenarios (M3, M4)

```bash
meson test -C build/meson_test --suite scenario --print-errorlogs
```

**Expected:**
- `test_scenario_combat`: a police ship engages the pirate and survives, seed 20260910, within
  112.5 s of game time;
- `test_scenario_determinism`: 100 runs, identical event logs and per-tick state hashes;
- `test_scenario_two_scenes`: each scene produces its solo result while two run in turn;
- docking, asteroid field, script event and witchspace each pass.

**Proving it is headless (M3b and after).** Run the combat test as below. It must still pass, and
no window may appear.

```bash
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy \
  meson test -C build/meson_test --suite scenario test_scenario_combat
```

**Speed (SC-001).** Compare the wall time `meson test` reports for `test_scenario_combat` with
`tests/run.sh component -k police`. Including launch, the scenario must be at least 10× faster.

## 6. Regression gate (end of every milestone)

```bash
tests/run.sh all                       # Clang; rebuild with --native-file=gcc.ini, then again
```

**Expected:** the same results as the parent stage. The smoke run's frame time is within 2% of
the parent's, compared from the snapshot logs `launch_snapshot.py` writes under `OO_LOGSDIR`.

## 7. The finish lines

M6a (no bridge use in `src/`):

```bash
python3 tests/global_state_check.py --build-dir build/meson_test --check ratchet  # every src/ ceiling 0
git grep -nwE 'UNIVERSE|PLAYER' -- src ':!src/Core/Universe.h' ':!src/Core/Entities/PlayerEntity.h'   # no output
```

M6b (after Jon's sign-off, research R15):

```bash
git grep -nwE 'UNIVERSE|PLAYER|gSharedUniverse|gOOPlayer' -- src tests/unit   # no output
git grep -nE 'OOGameContext::(current|process)' -- src tests/unit              # no output
python3 tests/global_state_check.py --build-dir build/meson_test                # 0 todo rows
```
