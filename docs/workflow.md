# Workflow

How a change is made and verified. The hard rules are in [CLAUDE.md](../CLAUDE.md); this is the
detail behind them.

## Tools decide correctness, not models

Whether behaviour changed is decided by the goldens, the unit/component/GUI suites, the JS API
snapshot, the expansion corpus, ASan, the symbol deny-list and `-Wall -Wextra`. A model (or a
reviewer) may propose and explain; it never declares a change correct. A failing golden is either
a bug to fix or a diff to justify — and **only Jon re-blesses a golden**.

## The three tiers

| Tier | When | Command | Budget | Content |
|---|---|---|---|---|
| A | every edit | `tools/tier-a.sh <file>` | < 30 s | compile the one TU, clang-tidy, deny-list, that module's tests |
| B | before a PR | `tools/tier-b.sh` | < 10 min | full Clang build, module tests, fast goldens, Tier-1 corpus subset |
| C | end of a phase, before the phase PR | `tools/tier-c.sh` | 30–90 min | everything: all goldens, ASan, full Tier-1 corpus, JS API snapshot, GUI tier, unit suites, deployment flavour, guard self-tests |

There are no scheduled or nightly runs. A slow check a change wants kept goes into a Tier C stage,
not into a bigger per-change budget. The full expansion corpus (`bash tools/corpus.sh tier3`) is
run by hand when wanted.

**Every shipped flavour is tested:** Clang, GCC (`tools/build-windows.sh --gcc test`) and the
deployment build (LTO, stripped: `tools/check-deployment-tests.sh`,
`tools/check-deployment-goldens.sh`).

## A unit of work (a bead)

Work is tracked as beads (`bd ready`, `bd show <id>`). A bead is ready to hand to an agent when:

1. it needs ≤ ~1,500 lines read, ≤ ~400 written, ≤ 8 files touched;
2. it has an acceptance command that exits nonzero before the change and zero after;
3. it adds no new interfaces (or quotes them verbatim);
4. it fits in 2–3 sentences;
5. it names an existing file to copy the style from.

If a bead fails 1, 3 or 4, split it. If only 2 fails, write the test first as its own bead. If only
3 and 5 fail, it is design work: do it in an interactive session, not in the loop.

Template: [templates/story.md](templates/story.md). The bead's notes are the only state that
survives between agent iterations.

## Done, for one bead

1. Its acceptance command passes; Tier B passes.
2. Goldens reproduce (or a re-bless is proposed with a justification and left for Jon).
3. Clean at `-Wall -Wextra` on Clang and GCC; no new warnings.
4. ASan clean where the change touches memory ownership.
5. No `libgnustep-base` or `JS_*` symbols (deny-list).
6. A pull request into `oolite-dev`'s `develop` via `git town propose`. The bead closes when Jon
   merges it (`.claude/skills/beads-worker/scripts/land.sh` reads the merge back); the implementing
   agent never closes it.

## Repo mechanics

- Branch in `oolite-dev` with `git town append`; push only that feature branch.
- Anything that launches the game on the desktop takes `tools/gui-lock` (`tools/desktop_lock.py`).
- Scripts called as bare programs are committed `100755` with a shebang
  (`tools/check-file-modes.sh`); check with `git ls-files -s`, never `test -x`.
- Vendored code (`src/Core/MiniZip/`, `src/SDL/stb_image_write.h`) is not edited to satisfy the
  warning gate; the gate skips exactly those two paths.
- Upstream changes to a frozen module are ported by hand and recorded in
  [UPSTREAM_DELTA.md](UPSTREAM_DELTA.md); `bash tools/upstream-delta.sh --check` enforces it.
- Expansion (OXP/OXZ) content is untrusted input: tools read it, agents with write access don't.
- Scratch goes in `.agent-tmp/`, never outside the repo.
