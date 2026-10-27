# ADR-0067: Submodules replace the subtrees; the game lives in `oolite-dev`

- Status: Accepted (Jon, in chat 2026-10-27)
- Date: 2026-10-27
- Supersedes: [ADR-0017](0017-native-windows-subtree.md) on the subtree layout only (its native
  Windows decisions stand)
- Bead: oo-s2xwp

## Context

Jon, 2026-10-27: "I want to change to a submodule approach. upstream/* can hold the OoliteProject
source repositories as submodules that I can view for reference. Then, create another folder for
my modifications as a submodule. ... I would like two submodules oolite-dev and oolite-main which
track the develop and main branches, respectively." Then "use oolite-dev and oolite-main [in] the
root directory of the project", and "I'm done with the beads worker for now ... My current goal is
to prepare the phase 4 code for merging back into upstream, so I'll be doing manual work".

ADR-0017 chose a subtree because the beads pipeline (`worktree.sh`, `harvest.sh`, `accept.sh`, the
merge queue, `guardrails.sh`) needs the game's files in this repository's own commits. With the
fleet stopped that reason no longer applies, and the subtree had costs of its own: pushing it to the
fork meant a split or a hand-made commit, and upstream syncs were squashed subtree pulls.

Measured before the switch: of the six repositories involved, only `jonmseaman/oolite` carries
changes. `oolite-tests` and `oolite-expansion-catalog` were untouched since they were added as
subtrees, and the forks of `spidermonkey-ff4`, `oolite-debug-console` and `oolite-mac-components`
were 0 commits ahead of and 0 behind OoliteProject.

## Decision

1. `oolite-dev` = `jonmseaman/oolite`, branch `develop`: the game, where all work on it happens.
   At the switch it is `develop` @ 66567dc26 (the undock fix 5346a1800, plus one commit for the
   path changes below), whose tree is exactly the old `upstream/oolite` with those path changes.
2. `oolite-main` = `jonmseaman/oolite`, branch `master` (the fork has no `main`), @ 0e1cc17a4:
   reference only.
3. `upstream/` holds OoliteProject's repositories, unmodified, reference only:
   - `upstream/oolite` @ 9ee8ff22f, the commit last merged into the game;
   - `upstream/oolite-tests` @ ef000a26e;
   - `upstream/oolite-expansion-catalog` @ c6fdf86b5;
   - `spidermonkey-ff4`, `oolite-debug-console` and `oolite-mac-components` at the same commits
     as before, with their URLs moved from Jon's forks to OoliteProject.
4. Every path in this repository's tools, tests and living docs that named `upstream/oolite` now
   names `oolite-dev`. These are not rewritten:
   - the ADRs, which are append-only;
   - `goldens/`, which is Jon's: its two `provenance.json` files keep the old path as a record,
     and nothing reads it;
   - the bead database.
   Inside the game tree, the three GUI tests that find this repository's `tools/` climb one
   directory less, and its README links into `docs/` do the same.
5. Upstream syncs are ordinary merges of `OoliteProject/oolite` `master` into `develop`, inside
   `oolite-dev`. Publishing is `git push` of `develop`. No subtree split, pull or push remains.

## Consequences

- The beads pipeline is **not** submodule-aware and is retired until someone needs it. If it comes
  back it needs a two-repository design:
  - submodule worktrees on `bead/<id>` and a submodule merge inside `accept`;
  - automatic resolution of the conflict on the recorded `oolite-dev` commit;
  - `guardrails.sh` diffing inside the submodule, since today it sees only the recorded-commit
    change.
- The merge queue's subtree mirror (`tools/merge-queue.sh` and its self-tests) and
  `tools/upstream-delta.sh --restore-frozen` describe the old layout and are dormant.
- A change to the game is two commits: one in `oolite-dev`, then one here recording it. A commit
  recorded here must be pushed to the fork, or other clones cannot check it out.
- OoliteProject `master` has moved past 9ee8ff22f (ee2198f3c on 2026-10-27, 53 files); merging it
  into `develop` is a normal follow-up, not part of this switch.
