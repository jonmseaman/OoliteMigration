# Workflow

How a change is made and verified. The hard rules are in [CLAUDE.md](../CLAUDE.md); this is the
detail behind them.

## Tools decide correctness, not models

Whether behaviour changed is decided by the unit, component and GUI suites, the JS API contract in
`oxp-contract/`, the expansion corpus, sanitizers, and `-Wall -Wextra`. A model (or a reviewer) may
propose and explain; it never declares a change correct.

## Running the tests

Everything lives in `oolite-dev/tests`, driven by `tests/run.sh` (see [CLAUDE.md](../CLAUDE.md)
for the commands):

| Suite | What it decides | Cost |
|---|---|---|
| `unit` | class behaviour (`oofnd`, `core`, headers); meson | seconds |
| `component` | pytest-bdd scenarios against a real game over the debug console | minutes |
| `gui` | PyAutoGUI against the real window | minutes; one at a time |
| `smoke` | the game launches and renders | seconds |

Before a pull request run `unit` and whatever `component` scenarios touch your change. Before a
phase pull request run `all`, on Clang and on GCC. The expansion corpus (`bash tools/corpus.sh
tier1`) is run by hand when a change could affect what expansions see.

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

1. Its acceptance commands pass, and `tests/run.sh unit` passes.
2. Clean at `-Wall -Wextra` on Clang and GCC; no new warnings.
3. ASan clean where the change touches memory ownership.
4. No `libgnustep-base` or `JS_*` symbols (`git grep -nE 'JS_[A-Za-z_]+|gnustep'` over the files you changed).
5. A pull request into `oolite-dev`'s `develop` via `git town propose`. The bead closes when Jon
   merges it (`.claude/skills/beads-worker/scripts/land.sh` reads the merge back); the implementing
   agent never closes it.

## Repo mechanics

- Branch in `oolite-dev` with `git town append`; push only that feature branch.
- Scripts called as bare programs are committed `100755` with a shebang; check with
  `git ls-files -s`, never `test -x`.
- Vendored code (`src/Core/MiniZip/`, `src/SDL/stb_image_write.h`) is not edited to satisfy the
  warning gate; the gate skips exactly those two paths.
- Upstream changes to a frozen module are ported by hand and recorded in
  [UPSTREAM_DELTA.md](UPSTREAM_DELTA.md); `bash tools/upstream-delta.sh --check` enforces it.
- Expansion (OXP/OXZ) content is untrusted input: tools read it, agents with write access don't.
- Scratch goes in `.agent-tmp/`, never outside the repo.
