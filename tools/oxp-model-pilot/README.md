# oxp-model-pilot — classifying the JS lint's ambiguous hits with a local model

Bead **oo-l7u**. Builds on `tools/oxp-js-lint` (bead oo-ctq).

## What this is

`oo-ctq`'s detectors mask comments, strings, templates and regexes before
matching, because four of the eight Mozilla-only constructs are *syntax* no
conforming parser accepts (so an AST rule for them is unreachable). A
deliberately naive **unmasked** cross-check flagged ~218 extra hits that the
masked detectors reject. Those hits are the **ambiguity corpus**: the places
where "is this really Mozilla-only JS?" is a judgement call.

This pilot asks whether a sandboxed local model can make that judgement, and
measures it against ground truth that a human actually produced.

## The pieces

| file | role |
|---|---|
| `pilot.js` | `extract` re-derives the ambiguous population; `sample` draws a reproducible seeded sample and appends the known-positive controls |
| `classify.js` | the sandboxed payload — the only code that talks to a model |
| `sandbox.js` | launches `classify.js` under Node's `--permission` model with a scrubbed env |
| `sandbox-probe.js` | negative tests: each refusal is paired with the same op succeeding unenforced |
| `score.js` | confusion matrix + the anti-vacuity checks |
| `verify-audit.js` | ground-truth integrity (reproducible, evidence-bound, two-class, controls present) |
| `verify-report.js` | every figure in `docs/fleet/LEARNINGS.md` recomputed from the committed data |
| `server-probe.js` | detects the local inference server so the live line can skip loudly |
| `mutation-proof.sh` | breaks each protected property and shows the gate go red, then green |
| `data/` | `ambiguous.jsonl`, `sample.jsonl`, `audit.jsonl` (ground truth), per-model verdicts, scores |

## Results (2026-09-18, this machine)

Ground truth: **61 records** — a 50-record random sample at **seed 20260918**
plus 11 known-positive controls (8 fixture constructs + the real corpus
findings). 11 mozilla / 50 false-positive.

| classifier | agreement | TP | FN | FP | TN | control recall | gate |
|---|---|---|---|---|---|---|---|
| constant stub (always "false-positive") | 82.0% | 0 | 11 | 0 | 50 | 0/11 | **REJECTED** |
| qwen3-4b-2507 (local) | 85.2% | 3 | 8 | 1 | 49 | 3/11 | **REJECTED** |
| deepseek-r1-0528-qwen3-8b (local) | 91.8% | 6 | 5 | 0 | 50 | 6/11 | PASS |

The constant-stub row is why a single agreement number is worthless here: the
population is 82% negative, so *answering nothing* scores 82%. qwen3-4b beats
it by 3.2 points and is, in substance, the same always-negative answer.

Cost: 10.7s (4B) vs 652.2s (8B reasoning) for 61 items.

## Sandboxing — what is and is not claimed

The classifier child runs as `node --permission` with `--allow-fs-read` /
`--allow-fs-write` naming **one scratch directory outside the repo**, plus read
on its own script. Its environment is **rebuilt from a whitelist**, not
inherited. It gets no `--allow-child-process` and no `--allow-worker`, so it
cannot re-exec its way out.

`sandbox-probe.js` proves ten axes, each by running the same operation twice —
refused under enforcement, **succeeding** with enforcement stripped:

    repo write · repo read · .beads/issues.jsonl append · .git internals ·
    ~/.ssh · ~/.gitconfig · network · child_process re-exec ·
    env scrubbing (parent must *have* secrets, child must have none) ·
    no artifact left in the repo

**Residual exposure, stated plainly:** the model leg needs `--allow-net` to
reach the inference server on `127.0.0.1:1234`. Node's permission model has
**no host or port scoping** — `--allow-net` is all-or-nothing. So when the model
runs, the child can in principle open any socket. The bead's "no repo mount, no
secrets" is therefore satisfied as *filesystem and credential* isolation; it is
not a network jail. The stub path runs with `--no-net` and is fully network
isolated, and the probe proves the switch is real by showing a socket refused
when the flag is withheld.

## The expansion-content boundary

CLAUDE.md rule 6 prohibits reading expansion content except in the sandboxed
scan role. `pilot.js extract` *is* that role, and it emits only the hit line
plus at most two lines either side, truncated to 200 chars. Everything
downstream — the audit, the model, the scorer — sees those snippets and nothing
else. No expansion source was browsed at large, and the model never receives a
file path into the corpus.

## Running it

```bash
node tools/oxp-model-pilot/verify-audit.js      # ground truth integrity
node tools/oxp-model-pilot/sandbox-probe.js     # sandbox negative tests
node tools/oxp-model-pilot/score.js --verdicts tools/oxp-model-pilot/data/verdicts-deepseek.jsonl
bash tools/oxp-model-pilot/mutation-proof.sh    # prove the gate can fail

# live model (needs LM Studio on :1234; skips loudly otherwise)
node tools/oxp-model-pilot/server-probe.js
node tools/oxp-model-pilot/sandbox.js --mode model --model qwen/qwen3-4b-2507 --out /tmp/v.jsonl
```

The model is behind a seam: `--mode`, `--model`, `--url`, and the
`OXP_MODEL_URL` / `OXP_MODEL_NAME` / `OXP_CLASSIFIER_MODE` environment
variables. Any OpenAI-compatible `/v1/chat/completions` endpoint works.

## Acceptance and the absent-server problem

`accept.sh` replays the stored block in a fresh checkout that may have no
inference server. Lines L1–L5 are deterministic and use only committed
artifacts and the stub. **L6 is the only line that touches the live server**: it
calls `server-probe.js` first and prints `SKIP: live-model line skipped, no
local inference server` with exit 0 when nothing is listening. It never fails on
absence and never silently passes — a server that is present but broken still
fails the line.
