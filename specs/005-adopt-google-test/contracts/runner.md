# Contract: runner

How a converted program is built, run and reported, and the checks (R1–R9) that prove it. R1–R6
are cases in `tests/unit/oofnd/test_gtest_harness.cpp` and in two tiny probe programs built only
for the harness test; R7–R9 are commands in [../quickstart.md](../quickstart.md).

## Build

```meson
# top level, inside the branches that build unit tests (never in a deployment-only build)
gtest_dep = dependency('gtest', fallback: ['gtest', 'gtest_dep'])     # wrap: subprojects/gtest.wrap
# tests/unit/meson.build
oo_gtest_main = static_library('oo_gtest_main', 'oo_gtest_main.cpp', dependencies: gtest_dep)
oo_gtest_dep = declare_dependency(link_with: oo_gtest_main, dependencies: gtest_dep,
                                  include_directories: include_directories('.'))
# a converted program
test(name, exe, suite: ..., timeout: 60, protocol: 'gtest')
```

`project()` gains `force_fallback_for=quickjs-ng,gtest`. No `include_type: 'system'`, no
`warning_level` override for the subproject.

## The shared `main` (`tests/unit/oo_gtest_main.cpp`)

1. `GTEST_FLAG_SET(fail_if_no_test_linked, true);` then `::testing::InitGoogleTest(&argc, argv);`
   (the command line may override the flag).
2. Install a `SIGABRT` handler that prints `oo_gtest: abort() in case <Suite>.<name>` to stderr
   and flushes, using the current test's info.
3. `return RUN_ALL_TESTS();`

Nothing else: no shuffling, no repeat, no output-format default (meson adds `--gtest_output`).

## Exit codes and output

| Situation | Exit | Output |
|---|---|---|
| all cases pass | 0 | `[  PASSED  ] N tests.` |
| a check fails | 1 | file:line, the expression, both values for `EXPECT_EQ`; `[  FAILED  ] <Suite>.<name>` |
| no `TEST` linked | 1 | Google Test's "no test linked" message |
| filter matches nothing | 0 | `0 tests ran` |
| `abort()` in a case | nonzero (signal) | `[ RUN      ] <Suite>.<name>` already flushed, then `oo_gtest: abort() in case <Suite>.<name>` |
| uncaught exception or SEH fault in a case | 1 | the case fails with the exception's description; later cases still run |

## Running a subset

- One program: `build/meson_debug/tests/unit/core/core_test_OOColor.exe --gtest_filter=OOColor.blendWorks`
- Through meson: `meson test -C build/meson_debug test_OOColor --test-args=--gtest_filter=OOColor.blendWorks`
- A suite: `tests/run.sh unit -k 'OOColor.*'` → `meson test --suite <s> --test-args=--gtest_filter=OOColor.*`
  for each unit suite. Old-harness programs ignore the argument and run in full until converted.

## Checks

| Id | What | Pass when |
|---|---|---|
| R1 | a passing and a failing `EXPECT_EQ(2, 1 + 2)` in a probe | probe exits 1; output names the case and shows `1 + 2` with value `3` and `2` |
| R2 | a probe with no `TEST` | exits nonzero |
| R3 | `--gtest_filter=NoSuch.*` on `test_gtest_harness` | exits 0, 0 tests ran |
| R4 | case order | `test_gtest_harness` records the order its cases ran in and checks it is source order |
| R5 | value sites | `OO_EXPECT_V(false)` returns false and fails the case once; `OO_EXPECT_EQ_V(f(), 1)` calls `f` once |
| R6 | a probe whose case calls `abort()` | stderr has `oo_gtest: abort() in case` and the case name |
| R7 | meson protocol | `meson test --suite oofnd` on a tree with one converted program lists its cases in `testlog.junit.xml` |
| R8 | `tests/run.sh unit -k 'gtest_harness.*'` | runs only those cases in the converted program; exits 0 |
| R9 | a deployment build without unit tests | `meson introspect --dependencies` shows no `gtest`; `subprojects/googletest-*` not created by that build |

R1, R2 and R6 are probes because a failing or aborting case cannot live in a program that must
pass. The probes are built as executables but registered as meson tests with `should_fail: true`
(R1, R2) or run by `test_gtest_harness` as child processes checking their output (R6), so the
suite stays green.
