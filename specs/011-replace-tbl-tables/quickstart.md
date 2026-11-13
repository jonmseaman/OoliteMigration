# Quickstart: verifying the OpenGL table

All commands are run in an MSYS2 UCRT64 shell, from `.agent-tmp/wt-tbl`, a checkout of
`seriesb/027-modern-cpp` (research R4).

```bash
./mk.sh build test
```

```bash
meson test -C build/meson_test --print-errorlogs test_OOOpenGLStateManager test_OOOpenGLStateVerifier
```

```bash
tests/run.sh unit
```

Then check three things:
- Both tests pass before the change and after it, and neither existing test file is edited.
- `ls src/Core/Tables/*.tbl` finds nothing, and `git grep -n '\.tbl"' -- src tests` finds nothing.
- The `warning:` lines for `OOOpenGLStateManager.cpp` in the build log, on Clang and on a GCC build
  directory (`meson setup build/gcc --native-file gcc.ini`), are the base's.

**SC-002 trials:**
- Add a field to `OOOpenGLState` with no item: the build fails at the field-count
  `static_assert`. Revert.
- Drop the setter from `SHADE_MODEL`'s `IntItem<…>`: the build fails at that line. Revert.

At the end:

```bash
tests/run.sh component
```

```bash
tests/run.sh smoke
```
