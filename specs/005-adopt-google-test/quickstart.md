# Quickstart: verifying each milestone

All commands from `oolite-dev` in an MSYS2 UCRT64 shell, on `feature/adopt-google-test`. `B` is
`build/meson_debug`. Each milestone also needs `./mk.sh build test && tests/run.sh unit` to pass on
Clang and with `--native-file=gcc.ini`.

## M0: baselines

Recorded by hand (nothing to script yet): three timed clean builds of the test programs
(`meson compile -C $B --clean` then `time meson compile -C $B`), three timed `tests/run.sh unit`,
and copy `$B/meson-logs/testlog.txt` to `.agent-tmp/005/before/`. Done when `baselines.md` has the
six numbers and their medians.

## M1: Google Test in the build (US1)

```bash
meson subprojects download gtest                 # populates subprojects/packagecache
meson test -C $B --suite oofnd test_gtest_harness probe_gtest_fails probe_gtest_empty
meson setup --wipe $B --wrap-mode=nodownload ... # offline: builds from the cache (US1 scenario 3)
```

Fails before M1 (no such tests); passes after. Then runner.md R1–R6 pass, and `grep -rnE
"Wno-|diagnostic|include_type" meson.build tests/unit` finds nothing new (FR-002).

## M2: diagnose and isolate (US2)

```bash
meson test -C $B --suite oofnd                   # then:
python -I -c "import xml.etree.ElementTree as E;print(len(E.parse('$B/meson-logs/testlog.junit.xml').findall('.//testcase')))"
tests/run.sh unit -k 'gtest_harness.*'
python -I ../specs/005-adopt-google-test/parity.py selftest
```

Passes when the JUnit report has one `<testcase>` per `test_gtest_harness` case (R7), the `-k` run
runs only those (R8), and `parity.py selftest` passes on its fixtures: a dropped case, a dropped
site, a changed expression, a fatal check and a moved site are each reported, and an exact
conversion is not.

## M3: `oofnd` converted (US3)

Needs the hard-rule-1 line in `CLAUDE.md` (research R11).

```bash
python -I ../specs/005-adopt-google-test/convert.py tests/unit/oofnd/test_*.cpp
python -I ../specs/005-adopt-google-test/parity.py static <base-ref> tests/unit/oofnd
./mk.sh build test && meson test -C $B --suite oofnd
python -I ../specs/005-adopt-google-test/parity.py run .agent-tmp/005/before $B/meson-logs/testlog.junit.xml
meson setup build/meson_deploytests -Ddeployment_release=true -Ddeployment_unit_tests=true -Db_lto=false && meson test -C build/meson_deploytests --suite oofnd
grep -l oo_test.hpp tests/unit/oofnd/*.cpp      # prints nothing
```

Both parity modes exit 0; the deployment `oofnd` suite passes (FR-014); build time re-measured into
`baselines.md` (decides the precompiled header, R8).

## M4: docs

```bash
grep -n "Unit test" ../CLAUDE.md                          # exemplar row names a Google Test program
grep -rn "oo_test" ../docs/workflow.md ../docs/current-state.md   # only "being migrated away" wording
grep -n "005-adopt-google-test" ../specs/003-*/spec.md    # the FR-019 note
```

## M5: `core` converted, one family at a time

As M3 with `tests/unit/core/<family files>` and `--suite core`, plus once per family a sanitized
build (`./mk.sh build test --setup-flags="-Db_sanitize=address,undefined"`, then `meson test
--suite core --no-suite openal`) with no new reports (FR-015).

## M6: retire the old harness (US4)

```bash
git rm tests/unit/oofnd/oo_test.hpp
grep -rnE "oo_test\.hpp|OO_TEST\(|OO_CHECK(_EQ)?\(|OO_TEST_MAIN" . --include=*.cpp --include=*.hpp --include=*.h --include=*.build   # nothing (SC-006)
tests/run.sh unit
```

And a throwaway probe (in `.agent-tmp/`, not committed) that uses `OO_CHECK` fails to compile
(FR-017). SC-001: `parity.py static <pre-M3 ref> tests/unit` totals equal the M0 counts (1,835 cases).
