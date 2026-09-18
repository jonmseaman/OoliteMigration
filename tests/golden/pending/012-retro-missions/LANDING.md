# Landing scenario 012 into the guarded paths — blocked on a re-bless approval

## The blocker, measured rather than assumed

`tools/guardrails.sh` protects two prefixes (`PROTECTED_PREFIXES` at `tools/guardrails.sh:260`):

```
goldens/   tests/golden/scenarios/
```

The protected-path check does **not** distinguish a modification from a brand-new file. Every path
in the change whose status is not `R`/`C`/`D` falls into the catch-all branch
(`tools/guardrails.sh:449-452`), which demands an approval for *any* change under a protected
prefix, additions included.

That was verified in this worktree, not inferred, by creating two empty placeholder files and
running the guard:

```
$ mkdir -p goldens/windows-x64/012-probe tests/golden/scenarios/012-probe
$ echo '{}' > goldens/windows-x64/012-probe/state.json
$ echo '{}' > tests/golden/scenarios/012-probe/spec.json
$ git add -A && bash tools/guardrails.sh
guardrails: base a733ba491c03f7198df2891a914c0b621b235582 (a733ba4)
guardrails: goldens: goldens/ is populated (6 files) but is still listed in
  PROTECTED_PREFIXES_PENDING - that exemption is stale and should be deleted
guardrails: goldens: goldens/windows-x64/012-probe/state.json is under a protected golden path
  and is changed and has no re-bless approval in tools/rebless-approvals.txt (CLAUDE.md rule 1:
  re-blessing a golden is Jon's decision alone)
guardrails: goldens: tests/golden/scenarios/012-probe/spec.json is under a protected golden path
  and is changed and has no re-bless approval in tools/rebless-approvals.txt (CLAUDE.md rule 1:
  re-blessing a golden is Jon's decision alone)
guardrails: tests: classifier matches 79 tracked test files
guardrails: deny-list: 18 patterns, canary scores 2
guardrails: FAIL
```

The probe files were deleted immediately and nothing under either prefix is touched by this bead's
commit. **`tools/rebless-approvals.txt` was NOT edited** — the guard refuses a change that edits
both a protected path and the approvals file (`tools/guardrails.sh:424-425`, *"a change may not
approve itself"*), and adding an approval is Jon's decision alone.

So the three artefacts are staged here instead:

| staged now | lands at |
|---|---|
| `tests/golden/pending/012-retro-missions/spec.json` | `tests/golden/scenarios/012-retro-missions/spec.json` |
| `tests/golden/pending/012-retro-missions/README.md` | `tests/golden/scenarios/012-retro-missions/README.md` |
| `tests/golden/pending/012-retro-missions/state.json` | `goldens/windows-x64/012-retro-missions/state.json` |
| `tests/golden/pending/012-retro-missions/provenance.json` | `goldens/windows-x64/012-retro-missions/provenance.json` |

## Why no code has to change when they land

`retro_missions.py`, `check_retro_missions_evidence.py` and `test_retro_missions.py` all search
**both** locations, blessed path first (`SPEC_CANDIDATES` / `GOLDEN_CANDIDATES` in the script,
`GOLDEN_CANDIDATES` / `SPEC_CANDIDATES` / `PROVENANCE_CANDIDATES` in the tests). Landing is a pure
`git mv`; the stored acceptance block keeps passing on either side of the move because it invokes
the tools, not the paths.

## The procedure, once Jon has added the approvals

1. Jon lands, in a **separate commit of his own**, four lines starting in column one of
   `tools/rebless-approvals.txt`:

   ```
   tests/golden/scenarios/012-retro-missions/spec.json    Jon <date>, bead oo-3ya: new scenario
   tests/golden/scenarios/012-retro-missions/README.md    Jon <date>, bead oo-3ya: new scenario
   goldens/windows-x64/012-retro-missions/state.json      Jon <date>, bead oo-3ya: first bless
   goldens/windows-x64/012-retro-missions/provenance.json Jon <date>, bead oo-3ya: first bless
   ```

   An approval names **one file**; a directory prefix is not accepted.

2. On a branch based on that commit:

   ```bash
   cd <repo root>
   mkdir -p tests/golden/scenarios/012-retro-missions goldens/windows-x64/012-retro-missions
   git mv tests/golden/pending/012-retro-missions/spec.json \
          tests/golden/scenarios/012-retro-missions/spec.json
   git mv tests/golden/pending/012-retro-missions/README.md \
          tests/golden/scenarios/012-retro-missions/README.md
   git mv tests/golden/pending/012-retro-missions/state.json \
          goldens/windows-x64/012-retro-missions/state.json
   git mv tests/golden/pending/012-retro-missions/provenance.json \
          goldens/windows-x64/012-retro-missions/provenance.json
   ```

3. Prove the move changed nothing (this is the whole point of the dual search):

   ```bash
   export PATH=/ucrt64/bin:$PATH
   bash tools/guardrails.sh                                   # must print PASS
   python3 -m pytest tests/golden/test_retro_missions.py -q   # must stay 30 passed
   python3 tests/golden/check_retro_missions_evidence.py \
       goldens/windows-x64/012-retro-missions/state.json      # must stay rc=0
   git show --stat                                            # must be 4 pure renames, R100
   ```

   `git mv` of an unmodified file is reported by git as `R100`, which the guard credits as a
   rename into a protected path — hence the approvals in step 1 cover it.

3a. **Verify the landed bytes are the bytes that were blessed.** The digests below were taken
    from the staged artefacts at commit time; the landed copies must match them exactly. Pass
    forward-slash paths — GNU `md5sum` prefixes its output with a backslash when the filename
    contains one, silently yielding a truncated 31-character digest.

   ```bash
   md5sum goldens/windows-x64/012-retro-missions/state.json \
          goldens/windows-x64/012-retro-missions/provenance.json \
          tests/golden/scenarios/012-retro-missions/spec.json
   ```

   | file | md5 | bytes |
   |---|---|---|
   | `state.json` | `4c49d2295a33232f7ca477178b32eb1c` | 1973 |

   `state.json`'s digest is also the one all 10 stability runs produced, so a mismatch here means
   the file changed in transit, not that the scenario drifted. `provenance.json` and `spec.json`
   are small enough to diff directly against the staged originals in the parent commit:

   ```bash
   git diff <this-bead-commit>:tests/golden/pending/012-retro-missions/provenance.json \
            HEAD:goldens/windows-x64/012-retro-missions/provenance.json   # must be empty
   ```


4. Replay the bead's stored acceptance block. Nothing in it names `pending/`.

**Do not** move these files without step 1 on record, and do not add the approval lines yourself:
the guard refuses a self-approving change, and that refusal is the mechanism, not an obstacle.
