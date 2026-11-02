# Warnings in the history's own tests

The history's unit tests were written for the compilers the history built with. The series builds
every step with Clang 23, which adds diagnostics those compilers did not have
(`-Wunused-but-set-global`, for example). A warning in game code is fixed, in the form the history
reaches later. A warning in a test file can be neither fixed (the series never edits a test) nor
silenced (no `-Wno-*`, pragma or attribute). It is listed here instead.

`verify` reads this table. A listed warning, in a file under `tests/`, at a step inside its range,
does not fail `warnings_clang` or `build_gcc`; the check records how many there were. Any other
warning still fails. Every row ends where the history itself removes the variable or the test.

| Steps | File | Warning | Why it stays | Gone from |
|---|---|---|---|---|
| 11–15 | `tests/unit/core/test_OOJSConsole.mm` | `unused variable 'sEntityProto'` | the history's test; Clang 23 reports a stand-in it never reads | 16 (the history rewrites the test) |
| 11–16 | `tests/unit/core/test_OOJSShipGroup.mm` | `variable 'sFinalized' set but not used` | the history's test counts finalizer calls and never checks the count; Clang 23 adds `-Wunused-but-set-global` | 17 (the file becomes `.cpp`) |
| 17–18 | `tests/unit/core/test_OOJSShipGroup.cpp` | `variable 'sFinalized' set but not used` | the same counter, in the C++ test | 19 (the history removes it) |
| 11–15 | `tests/unit/core/test_OOJSWormhole.mm` | `variable 'sFinalized' set but not used` | as for the ship-group test | 16 (the history rewrites the test) |
| 12–16 | `tests/unit/core/test_OOMaterialConvenienceCreators.mm` | `expression with side effects will be evaluated despite being used as an operand to 'typeid'` | the history's test asks `typeid` of a dereferenced material (polymorphic, so evaluated, which the test means) | 17 (the file becomes `.cpp`; extended if the C++ era warns) |
| 13–15 | `tests/unit/core/test_Universe.mm` | `the only well defined values for 'BOOL' are YES and NO` | the history's test passes 7 and 2 to `BOOL` setters on purpose, to check they are normalised | 16 (the history rewrites the test) |
