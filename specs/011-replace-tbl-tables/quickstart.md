# Quickstart: verifying the `.tbl` replacement

How to show each part works. All commands run in an MSYS2 UCRT64 shell from the implementation
worktree (research R10), which is a checkout of `feature/replace-tbl-tables` in `oolite-dev`.
Design: [contracts/](contracts/), [data-model.md](data-model.md).

## Once, before the first conversion

From the planning repo's root:

```bash
git -C oolite-dev worktree add ../.agent-tmp/wt-tbl -b feature/replace-tbl-tables origin/seriesb/026-migration-completion
```

```bash
git -C .agent-tmp/wt-tbl town set-parent seriesb/026-migration-completion
```

then work in `.agent-tmp/wt-tbl` (copy `oolite-dev/subprojects/quickjs-0.17.0` into its
`subprojects/` to avoid a download):

```bash
./mk.sh build test
```

Then add `tests/unit/core/test_OOConstToStringEnums.cpp` (research R9) and check it passes on the
unconverted tree:

```bash
tests/run.sh unit
```

It must pass here, before any table changes; it is the before-and-after check for every group.

## After each group (G1–G4)

```bash
./mk.sh build test
```

```bash
tests/run.sh unit
```

```bash
tools/check-enum-headers.sh
```

- No new warnings in the build log on Clang; repeat the build with `--native-file=gcc.ini`.
- The group's `.tbl` files are gone, for example for G1:
  `test ! -e src/Core/Tables/OOScanClass.tbl && test ! -e src/Core/Tables/OOEntityStatus.tbl && test ! -e src/Core/Tables/OOShipDamageType.tbl`
  (spec 009 T060–T063's own acceptance commands).
- `git diff --stat seriesb/026-migration-completion` lists only the group's consumers, its definition files, the R2
  call-site files for its types, and (G1) `test_OOJSSound.cpp` with its ledger row.

**SC-004 trial (once, recorded in plan.md's notes):** add a member with no `case` to one converted
enum; `tools/check-enum-headers.sh` must fail and the game build must warn `-Wswitch`; revert.

## After G4

```bash
tests/run.sh component
```

```bash
tests/run.sh smoke
```

**Saved game, by hand (SC-003):** on a base build, open the long-range chart, cycle the colour
mode to *economy*, save. On the branch build, load that save and open the chart: it is in
*economy*. Save again and compare the two files' `chart_colour_mode` values (both `2`).

## After G5

```bash
./mk.sh build test
```

```bash
tests/run.sh unit -k OOOpenGLStateManager
```

- `test_OOOpenGLStateManager` passes with the file unchanged.
- `ls src/Core/Tables/*.tbl` finds nothing, and `rg -n '\.tbl"' src tests` finds nothing.
- **Log check (US3 acceptance 3):** `test_OOOpenGLStateVerifier` (tasks T005), written on the base,
  passes unchanged. Only if T005 recorded that the log cannot be captured in a unit test: run a
  debug build with `rendering.opengl.state` logging on, once on the base and once on the branch,
  with T005's mismatch, and compare the lines by hand.
- **SC-004 trial:** add a field to `OOOpenGLState` with no item: the build fails at the field-count
  `static_assert`; revert.

## At the end

```bash
tests/run.sh all
```

and the corpus, as for any change (`bash tools/corpus.sh tier1` from the planning repo), compared
with its result on the base. Then `docs/parity/c-and-tables.md` and `docs/current-state.md`
describe the tables as they are (FR-015).
