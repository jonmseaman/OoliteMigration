# Quickstart: checking the C++ component tests work

Run these to see the feature working end to end. Each block says what it proves. Interfaces are in
[contracts/](contracts/); values are in [data-model.md](data-model.md).

## Prerequisites

- The `oolite-dev` worktree at `.agent-tmp/wt-component-tests` on `feature/headless-component-tests`.
- A build: `./mk.sh build test --setup-flags=-Db_lto=false`.
- On Windows, an MSYS2 UCRT64 shell. On macOS and Linux, the ordinary shell.

All commands are run from the worktree.

## 1. The C++ component tests run (M0)

```bash
tests/run.sh component --cpp
```

Expected: every C++ program in the `component` suite passes; exit 0.

## 2. A scene with no window (US1)

```bash
tests/run.sh component --cpp -k s1_police_kills_pirate
```

Expected: passes. No window appears. The output's last line gives game seconds, real seconds and
their ratio; the ratio is at least 20 and the real time is under 15 s (SC-001).

To prove it needs no display, on Linux:

```bash
env -u DISPLAY -u WAYLAND_DISPLAY tests/run.sh component --cpp -k s1_police_kills_pirate
```

## 2a. One behaviour at a time (US6)

```bash
tests/run.sh component --cpp -k laser_fires
tests/run.sh component --cpp -k ship_attacks
tests/run.sh component --cpp -k mining_laser
tests/run.sh component --cpp -k fire_key
```

Expected: each passes. (`fire_key` needs milestone M5.)

To prove each can fail, run it with its weapon left off:

```bash
build/meson_test/tests/component-cpp/test_laser_fires --without-weapon
```

Expected: exit 1, with the failed check saying the target's energy did not drop. The same flag
works on the other three (SC-012).

## 3. The same result every time (SC-002)

```bash
tests/component-cpp/repeat_100.sh test_s1_police_kills_pirate
```

Expected: `100 runs, identical`; exit 0.

## 4. A GL call is caught (M2; Linux or macOS)

Temporarily remove the guard in `OOSunEntity::setSunColor`, rebuild and run:

```bash
tests/run.sh component --cpp -k boot
```

Expected: fails with `GL call glLightfv while headless`. Restore the guard; it passes.

## 5. Every ship and equipment item (US2)

```bash
tests/run.sh component --cpp -k census
```

Expected: exit 0 and a summary line counting 194 ships and 41 equipment items (or whatever the
data then holds). The report is at `build/meson_test/component/census-report.tsv`.

To prove it can fail:

```bash
build/meson_test/tests/component-cpp/component_census --data-overlay tests/component-cpp/fixtures/broken-ship
```

Expected: exit 1, naming the fixture's one definition.

## 6. Menus and the tutorial by key (US3)

```bash
tests/run.sh component --cpp -k menus
tests/run.sh component --cpp -k tutorial_keys
```

Expected: both pass, under the `us`, `fr_azerty` and `ru` layouts. Run them on each platform; CI
does this in the Windows, macOS and Fedora jobs.

To prove the tutorial test can fail, run it with the mutated layout:

```bash
build/meson_test/tests/component-cpp/test_tutorial_keys --layout tests/component-cpp/fixtures/us-n-remapped.tsv
```

Expected: fails with `pressing n had no effect at GUI_SCREEN_MAIN, game time …` (SC-007).

## 7. Under the sanitizers (FR-015)

```bash
meson setup build/meson_asan -Db_sanitize=address,undefined -Db_lto=false
meson test -C build/meson_asan --suite component --print-errorlogs
```

Expected: no sanitizer report.

## 8. The key-fault cases (US4)

```bash
tests/run.sh component --cpp -k key_faults
```

Expected at the end of the feature: each case passes, or the case is named in the finding in
`tasks.md` with the reason it is still failing.

## 9. Nothing else moved (FR-031)

```bash
tests/run.sh all
```

Expected: the same results as on the base commit for unit, the windowed component scenarios, smoke and gui, plus the
C++ component tests passing.

## Where the outcome of the `n` report is written

`specs/011-headless-component-tests/tasks.md`, section *Finding: the Flatpak `n` report*. It holds
either the failing-then-passing test and its fix, or what was covered, what could not be, and the
manual check.
