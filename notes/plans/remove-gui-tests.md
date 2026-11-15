# Remove the PyAutoGUI GUI tier (`oolite-dev/tests/gui`)

## Why
Jon asked for it on 2026-11-15. The tier takes over the desktop, runs only on Windows, and the
component tiers (`tests/component-cpp`, `tests/component`) now cover whole-game behaviour. Jon
asked for the removal, so this doesn't fall under hard rule 1 (deleting a test to make it pass).

## Done check (from `oolite-dev`)
```bash
! git ls-files --error-unmatch tests/gui >/dev/null 2>&1 && ! git grep -qE 'tests/gui|run_gui|OO_GUI_REQUIRE' -- tests mk.sh
```
Run it along with `./mk.sh build dev`, `tests/run.sh unit` and `tests/run.sh component --cpp`.

## Design: who uses the tier
- `tests/gui/`: 22 tracked files (conftest, pytest.ini, requirements.txt, README, .gitignore,
  G1–G11, double-click timing, win32 declarations, the vacuity guard). Delete them all.
- `tests/run.sh`, the only runner that calls it:
  - `:6`, `:8`: the usage text. Drop the `gui` line, and make `all` read "unit, component, then smoke".
  - `:26`: becomes `REQ_FILES=(tests/component/requirements.txt)`.
  - `:99-103`: delete `run_gui()`.
  - `:117`, `:119`: delete the `gui)` case and drop `run_gui` from `all)`.
- Component-tier comments that mention the GUI tier. These are comments only: no code or assertion changes.
  - `tests/component/keyboard.py:7-9`: names `tests/gui/conftest.py`. Describe the recipe directly.
  - `tests/component/conftest.py:117`, `tests/component/console.py:67`,
    `tests/component/steps/world_steps.py:123`, `tests/component/README.md:94,98`: delete or reword
    each GUI-tier mention. For example, "Longer than the GUI tier's 0.15 s" becomes a plain statement
    of the hold time and why.
- Outer repo docs that describe the tier (they're in OoliteMigration, so leave them uncommitted):
  - `CLAUDE.md`: the `run.sh gui` command, the GUI exemplar row and the "GUI tests own the desktop" bullet.
  - `GLOSSARY.md`: the G1–G11 row, and "the GUI tests" in Component test and Windowed.
  - `docs/current-state.md:85,99`, `docs/workflow.md:8,22`, `docs/phases/5-apple-silicon.md:50`.
  - Leave history alone (specs/002, notes, `.claude/worktrees`).
- CI: `.github/workflows/build-all.yaml` doesn't mention the tier, so it needs no change.

## Steps
1. On an oolite-dev feature branch (the existing `seriesb/032-cleanup` is fine): `git rm -r tests/gui`.
2. Edit `tests/run.sh` and the component comments as listed above.
3. Run the done check, `bash -n tests/run.sh`, `tests/run.sh venv`, `./mk.sh build dev`,
   `tests/run.sh unit` and `tests/run.sh component --cpp`.
4. Commit only these paths. Don't sweep up unrelated changes in the work tree (as of 2026-11-15:
   `src/oofnd/objc/OOObject.h` modified, `package-lock.json` untracked).
5. Update the outer docs.

## Test-change ledger
| File | Edit | Assertions kept? |
|---|---|---|
| `tests/gui/**` (22 files) | deleted (Jon, 2026-11-15) | n/a, the tier is removed |
| `tests/component/keyboard.py`, `conftest.py`, `console.py`, `steps/world_steps.py`, `README.md` | comments/docs only | yes, no code touched |

## Decisions
- Don't keep a stub `gui` tier. `tests/run.sh gui` falls through to the usage text and exits 2, which is how it handles any other unknown tier.
- Keep `keyboard.py`'s SendInput recipe in the component tier as it is. Only its comment changes.

## Out of scope
- `tests/launch_snapshot.py` (the smoke tier) stays.
