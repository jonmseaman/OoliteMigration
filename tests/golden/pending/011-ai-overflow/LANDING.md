# Landing scenario 011 into the guarded paths — blocked on a re-bless approval

## The blocker, measured in THIS worktree rather than inherited

`tools/guardrails.sh` protects two prefixes (`PROTECTED_PREFIXES`), and the protected-path check
does **not** distinguish a modification from a brand-new file. A/B control run here, one variable
changed:

**A — this bead's tree as committed, nothing under a protected prefix:**

```
$ git add -A && bash tools/guardrails.sh
guardrails: base 9094649e46d5d0359234cc50fef7331ea83dd074 (9094649)
guardrails: tests: classifier matches 108 tracked test files
guardrails: deny-list: 18 patterns, canary scores 2
guardrails: OK (goldens, suppression, tests, deny-list) against 9094649
RC_A=0
```

**B — same tree plus two brand-new files under the protected prefixes:**

```
$ mkdir -p goldens/windows-x64/011-ai-overflow tests/golden/scenarios/011-ai-overflow
$ echo '{}' > goldens/windows-x64/011-ai-overflow/state.json
$ echo '{}' > tests/golden/scenarios/011-ai-overflow/spec.json
$ git add -A && bash tools/guardrails.sh
guardrails: goldens: goldens/windows-x64/011-ai-overflow/state.json is under a protected golden
  path and is changed and has no re-bless approval in tools/rebless-approvals.txt (CLAUDE.md
  rule 1: re-blessing a golden is Jon's decision alone)
guardrails: goldens: tests/golden/scenarios/011-ai-overflow/spec.json is under a protected golden
  path and is changed and has no re-bless approval in tools/rebless-approvals.txt (CLAUDE.md
  rule 1: re-blessing a golden is Jon's decision alone)
guardrails: FAIL
RC_B=1
```

The probe files were deleted and unstaged immediately; nothing under either prefix is touched by
this bead's commit, and `git status --porcelain` is clean at commit time.

**`tools/rebless-approvals.txt` was NOT edited.** The guard refuses a change that touches both a
protected path and the approvals file — *"a change may not approve itself"* — and adding an
approval is Jon's decision alone. That refusal is the mechanism, not an obstacle.

So the four artefacts are staged outside the guarded paths:

| staged now | lands at |
|---|---|
| `tests/golden/pending/011-ai-overflow/spec.json` | `tests/golden/scenarios/011-ai-overflow/spec.json` |
| `tests/golden/pending/011-ai-overflow/README.md` | `tests/golden/scenarios/011-ai-overflow/README.md` |
| `tests/golden/pending/011-ai-overflow/state.json` | `goldens/windows-x64/011-ai-overflow/state.json` |
| `tests/golden/pending/011-ai-overflow/provenance.json` | `goldens/windows-x64/011-ai-overflow/provenance.json` |

## Why no code has to change when they land

`ai_overflow.py`, `check_ai_overflow_evidence.py` and `test_ai_overflow.py` all search **both**
locations, blessed path first (`SPEC_CANDIDATES` / `GOLDEN_CANDIDATES` in the script;
`GOLDEN_CANDIDATES` / `SPEC_CANDIDATES` / `PROVENANCE_CANDIDATES` in the tests). The stored
acceptance block resolves the same pair with `ls <blessed> <pending> | head -1`, so it keeps
passing on either side of the move because it invokes the tools, not the paths. Landing is a pure
`git mv`.

## The procedure, once Jon has added the approvals

1. Jon lands, in a **separate commit of his own**, four lines starting in column one of
   `tools/rebless-approvals.txt`:

   ```
   tests/golden/scenarios/011-ai-overflow/spec.json      Jon <date>, bead oo-dto: new scenario
   tests/golden/scenarios/011-ai-overflow/README.md      Jon <date>, bead oo-dto: new scenario
   goldens/windows-x64/011-ai-overflow/state.json        Jon <date>, bead oo-dto: first bless
   goldens/windows-x64/011-ai-overflow/provenance.json   Jon <date>, bead oo-dto: first bless
   ```

   An approval names **one file**; a directory prefix is not accepted.

2. On a branch based on that commit:

   ```bash
   cd <repo root>
   mkdir -p tests/golden/scenarios/011-ai-overflow goldens/windows-x64/011-ai-overflow
   git mv tests/golden/pending/011-ai-overflow/spec.json \
          tests/golden/scenarios/011-ai-overflow/spec.json
   git mv tests/golden/pending/011-ai-overflow/README.md \
          tests/golden/scenarios/011-ai-overflow/README.md
   git mv tests/golden/pending/011-ai-overflow/state.json \
          goldens/windows-x64/011-ai-overflow/state.json
   git mv tests/golden/pending/011-ai-overflow/provenance.json \
          goldens/windows-x64/011-ai-overflow/provenance.json
   ```

3. Prove the move changed nothing — this is the whole point of the dual search:

   ```bash
   export PATH=/ucrt64/bin:$PATH
   bash tools/guardrails.sh                                  # must print OK, rc=0
   python3 -m pytest tests/golden/test_ai_overflow.py -q     # must stay 40 passed
   python3 tests/golden/check_ai_overflow_evidence.py \
       goldens/windows-x64/011-ai-overflow/state.json        # must stay rc=0
   git show --stat                                           # must be 4 pure renames, R100
   ```

   `git mv` of an unmodified file is reported by git as `R100`, which the guard credits as a
   rename into a protected path — hence the approvals in step 1 cover it.

3a. **Verify the landed bytes are the bytes that were blessed.** Pass forward-slash paths — GNU
    `md5sum` prefixes its output with a backslash when the filename contains one, silently
    yielding a truncated 31-character digest.

   ```bash
   md5sum goldens/windows-x64/011-ai-overflow/state.json
   ```

   | file | md5 | bytes |
   |---|---|---|
   | `state.json` | `e2e87932e32339ae750b3994d2ecd12f` | 2166 |

   That digest is also the one all 10 stability runs produced, so a mismatch here means the file
   changed in transit, not that the scenario drifted. `provenance.json` and `spec.json` are small
   enough to diff directly against the staged originals in the parent commit:

   ```bash
   git diff <this-bead-commit>:tests/golden/pending/011-ai-overflow/provenance.json \
            HEAD:goldens/windows-x64/011-ai-overflow/provenance.json   # must be empty
   ```

4. Replay the bead's stored acceptance block. Nothing in it names `pending/` exclusively; every
   line resolves blessed-path-first.

**Do not** move these files without step 1 on record, and do not add the approval lines yourself.
