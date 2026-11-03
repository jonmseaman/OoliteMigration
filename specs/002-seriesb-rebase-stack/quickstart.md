# Quickstart: build and check the `seriesb` stack

Run these from the OoliteMigration root in an MSYS2 UCRT64 shell. `S="python -I tools/series/series.py --series seriesb"`.

## 0. The tool still works for the old series

```bash
python -I -m unittest discover -s tools/series/tests -t . # all pass, old and new
python -I tools/series/series.py check --verified          # old series: exit 0, nothing moved
```

## 1. Parents and the gate

```bash
$S parents --setup            # remote hobleyd, 000a/000b observed, lineage develop→000a→000b
$S parents                    # each tip = its PR head (3758f8a09, db4920103 or newer)
$S gate seriesb/000a-upstream-767-quickjs-option
$S gate seriesb/000b-upstream-768-quickjs-only
```

Expected: both gates `pass`. If either is `flagged`, stop: the flag is in the plan's Notes and in
the handover, and Jon chooses between `000c` and holding (spec FR-003a).

## 2. Build the steps

```bash
$S cut --replay
$S tree 1 && $S build 1 && $S verify 1     # then 2, 3, … in order; resolve with tree --show/--record
$S drop <n> --covered-by 768 --reason "…"  # only if a replayed step is empty (old 005 is the candidate)
$S renumber
```

Expected:

- `git town branch` in `oolite-dev` shows `develop` → `000a` → `000b` → `001` → … as one chain.
- Each step is one commit.
- `git -C oolite-dev branch --list 'series/*' -v` is unchanged.

## 3. Final checks

```bash
$S check --verified           # exit 0: lineage, mirrors, no develop leak, final tree = develop ± lists
$S describe --handover        # specs/002-seriesb-rebase-stack/series/HANDOVER.md
```

## 4. When upstream moves (Jon, or an agent with the flags)

```bash
$S parents --refresh                          # fetch hobleyd; reset parents to the PR heads (research R2)
cd oolite-dev && git checkout seriesb/001-random-seed-env
git town sync --stack --detached --no-push    # resolve conflicts by hand; git town continue
cd .. && $S sync-record --conflict 003:src/Core/Scripting/OOJSShip.mm:"#768 renamed …"
$S verify --from 1 && $S check --verified
```

Expected:

- The parents equal the new PR heads.
- Each step has one new merge commit.
- `check` rule 4 confirms that no `develop` commit entered.
- All verification records are dated after the sync.
