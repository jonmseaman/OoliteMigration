# Syncing the seriesb stack with upstream

The `seriesb/*` branches in `oolite-dev` are the migration's PR series rebuilt on upstream's
QuickJS-ng PRs (`specs/002-seriesb-rebase-stack`):

```text
develop
└ seriesb/000a-upstream-767-quickjs-option   = upstream #767 (observed: follows the PR, never edited)
  └ seriesb/000b-upstream-768-quickjs-only   = upstream #768 (observed)
    └ seriesb/001-random-seed-env … seriesb/024-post-conversion-fixes   (feature: a bare `git town sync` pushes them)
```

When #767 or #768 gains commits, the change reaches the stack through Git Town. Conflicts are
resolved by hand and recorded. Nothing is rebuilt from scratch.

## Commands

Run them in this order, from the OoliteMigration root (`S="python -I tools/series/series.py --series seriesb"`):

```bash
$S parents --refresh                         # 1. fetch hobleyd; reset each parent to its PR head
git -C oolite-dev checkout seriesb/024-post-conversion-fixes
cd oolite-dev && git town sync --stack --detached --no-push && cd ..   # 2. merge down the stack
$S sync-record --conflict 'N:PATH:why'       # 3. record the sync and every hand-resolved conflict
$S verify --from 1 && $S check --verified    # 4. re-verify every step
git -C oolite-dev checkout develop
```

Why each part is there:

- **`parents --refresh` first.** Git Town's sync fetches only `origin`, so without it the parents
  never see upstream's new commits. And if upstream force-pushes a PR branch, Git Town's rebase of
  an observed branch replays the dropped commits onto the new head. Refresh resets each parent to
  its PR head (`update-ref`) before the sync. It refuses while a parent is checked out.
- **`--detached`** keeps the sync from pulling, pushing or upstream-syncing `develop`. Without it,
  `git town sync` also syncs the root branch.
- **`--no-push`**: agents never push. Jon may run `git town sync --stack` bare from his own shell;
  agents always add both flags.
- **The `hobleyd` remote** has `pushurl no-push`, so no default push can reach the PR author's
  repository. Its fetch refspecs map `quickjs-poc` and `quickjs-default` onto the parents' own
  names, because Git Town only observes a branch whose `<remote>/<local name>` exists.

## Conflicts

The sync merges each parent into the next branch down. When a merge conflicts, Git Town stops in
that step:

1. Resolve it the way the step's notes resolve its other conflicts. A test file takes one side
   whole: a test is never edited to make a step pass (hard rule 1).
2. `git add` the files, then `git town continue`.
3. Note the step, path and reason for step 3 above.

`git town undo` puts every branch back as it was before the sync.

## When upstream rebases #767 or #768

A force-pushed (rebased) PR leaves the merge base of each step and its parent at the old upstream
fork point, so `git merge` sees the whole PR as changed on both sides. It conflicts where nothing
changed, and where it merges cleanly it can bring back code the rebase dropped. In that case merge
each step by hand, bottom up, instead of letting the sync commit its merges:

1. Before anything moves, save every tip (`git update-ref refs/seriesb-presync/<branch> <branch>`).
2. Per step: `git merge --no-commit <parent>`, then resolve every path as a three-way merge of
   base = the parent's saved tip, ours = the step, theirs = the parent now. That is the step's
   own change re-applied to the new parent.
3. Build the step before moving on. Code that merges cleanly can still be in an idiom the step
   removed (an Objective-C call in a step that converted the file to C++); fix it in that step.
4. A fix to an earlier step reaches the later ones by ordinary `git merge`: their merge base is
   correct again.

The `git town sync --stack --detached` that follows finds nothing left to merge and pushes.

The documentation build in `post_build.sh` needs pandoc, typst, cairo/pango and a `.venv` with
weasyprint at the checkout's root, as upstream's `ShellScripts/Windows/install_deps.sh` installs
them. `verify.py` keeps `.venv/` when it cleans its worktrees.

## After the sync

- Every step is `stale` until it is verified again. `check --verified` fails until then.
- `check` accepts the sync's merge commits: each one's second parent is in the step's parent.
- Paths that upstream changed in the sync may now differ from `develop` at the end of the stack.
  The sync record lists them, and the final-tree rule accepts them.
- `build` no longer resets a synced step unless given `--reset`, which throws the merges away.

## When upstream merges #767 and #768

`$S parents --retire` fetches upstream `master`. If both PR heads are in it, it:

- adds the perennial branch `seriesb/000m-upstream-master`;
- moves step 001 onto it;
- marks the two parents retired.

Gate the new parent (`$S gate 000m`), then sync and re-verify as above. The old parent branches
are left for Jon to delete.
