# Quickstart: verifying Modern C++ on the standard library

How to prove each milestone ([plan.md](plan.md) *Milestones*). The category searches are in
[data-model.md](data-model.md#converted-category). All commands run from `oolite-dev` on
`seriesb/027-modern-cpp`.

## Prerequisites

- **macOS** (this machine): Homebrew `llvm@22` (clang-format and clang-tidy 22), meson, ninja,
  ccache. `./mk.sh` re-runs itself under Homebrew bash.
- **Windows** (for the unit, component and GUI tiers by hand): the MSYS2 UCRT64 shell set up by
  `tools/setup-windows.sh` in the planning repo.
- **CI** runs on every push of the branch: the Windows unit tests, and the Linux and macOS builds.
  The unit suites build only on Windows (`meson.build:130-148`), so from this Mac CI is how they run.

## Every step

```bash
./mk.sh build test
```

```bash
./mk.sh test test
```

```bash
./mk.sh tidy
```

Then the step's own search (it must find nothing outside `exceptions.md`), then push and read CI:

```bash
git push origin seriesb/027-modern-cpp
```

```bash
gh run list --branch seriesb/027-modern-cpp --limit 1
```

Expected: build clean at `-Wall -Wextra`; smoke passes; `tidy` exits 0; CI's jobs pass, with only
the base's known failures (`test_http`, `test_OOOXZManager`) in `unit-tests-windows`.

Format only the `src/` files you changed:

```bash
/opt/homebrew/opt/llvm@22/bin/clang-format -i path/to/changed.cpp
```

## M0 — groundwork

- After the `c++23` switch, the build and CI are exactly as on the base, and
  `compile_commands.json` shows `-std=c++23`:

  ```bash
  grep -c -- '-std=c++23' compile_commands.json
  ```

- `./mk.sh tidy` runs and exits 0 with the new checks reporting (non-fatal).
- The FR-016 tests added in M0 pass on the base (save round trip of every enum-valued entry,
  unknown-name fallbacks, quitting with a background task).
- Baselines recorded in `specs/009-modern-cpp-std/baselines.md`: smoke start-up
  time (`tests/launch_snapshot.py` prints it), and frame rate by the method in
  `notes/2026-11-10 Frame Rate Comparison.md`, five runs, median.

## M1 — C allocation (US1)

- The `alloc` search finds nothing (the demangling deleter's `&std::free` is not a call).
- Plant `void* p = malloc(1);` in any `src/Core` file: `./mk.sh tidy` fails naming the line.
  Remove it.
- ASan smoke run clean:

  ```bash
  meson setup build/meson_asan --native-file darwin.ini -Ddebug=true -Db_sanitize=address
  ```

  ```bash
  meson compile -C build/meson_asan
  ```

  then run the smoke snapshot against `build/meson_asan` and expect no ASan report. On Windows,
  the unit suites under the same setup.
- Leaks on macOS: `leaks --atExit -- <the built game binary> …` shows nothing the base did not.

## M2 — threads (US3)

- The `thread` search finds nothing.
- The quit-with-task test passes, and quitting takes no longer than the base's recorded time.
- TSan smoke run (Homebrew clang, a `build/meson_tsan` set up with `-Db_sanitize=thread`) reports
  nothing the base does not.

## M3 — `oofnd` (US4)

- The `oofnd` search finds nothing; `src/oofnd/Expected.hpp` is gone; no game file includes
  `oofnd/StdLib.hpp`.
- `src/oofnd/README.md` lists every remaining component with its reason (data-model
  *Surviving component*).
- For the format conversion, before each area's commit: a local build with
  `-Wformat-signedness` reports nothing for the area (not committed until the whole tree is clean),
  and the save round-trip test and the log-capturing tests pass.

## M4 — enums P1–P9 (US5)

- The `enum` search finds only `exceptions.md` rows; `ls src/Core/Tables/*.tbl` lists only
  `OOOpenGLStates.tbl`.
- Save round trip: the M0 round-trip test passes. It loads the baseline save on the branch,
  saves without play, and compares every enum-valued entry (a plain `diff` of the two files is
  not the check: the save records its own time).
- The JS API contract and the expansion corpus do not regress (planning repo):

  ```bash
  bash ../tools/corpus.sh tier1
  ```

- Every row in *External names and values* has its `static_assert` or test, and they pass in both
  `OO_FOV_INFLIGHT_CONTROL_ENABLED` configurations.

## M5 — ownership (US2)

- Before the bridge commit: Jon has signed the `test_ref.cpp:514` and construction-form rows in
  `test-ledger.md`, and every D2 *disposal reader* has a test that passes on the base.
- The `ownership` search finds nothing; `src/oofnd/Ref.hpp` is gone.
- Disposal-order and script-finalisation tests pass; the component scenarios that kill, dock and
  jump (`tests/run.sh component`) produce the same logged event order as the base (Windows).
- ASan and leaks clean as in M1.
- Frame rate and start-up within the base's run-to-run spread (five runs, median).

## M6 — close-out

- P10 done (after sign-off); `./mk.sh tidy` with `readability-identifier-naming` fatal exits 0.
- On a Windows machine: `tests/run.sh all`, on Clang (and GCC with `--native-file=gcc.ini`).
- SC-001 to SC-009 checked and recorded in the spec's checklist notes; the converted-category
  table in data-model.md shows every category `fatal`.
