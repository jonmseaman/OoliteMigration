#!/usr/bin/env bash
# Run once before the first tick. Proves the things a tick silently depends on:
#   1. the beads database answers;
#   2. the guard shim is actually first on PATH, so `bd close` cannot be run by hand. Claude Code
#      has no "export PATH before you start" ritual the way Hermes did, so this is ASSERTED rather
#      than assumed: if settings.json ever stops delivering it, hard rule 4 is honour-system only;
#   3. oolite-dev is checked out, clean, and knows that `develop` is its Git Town main branch, so
#      `git town append` stacks bead branches on develop and `git town propose` targets it.
# A dirty submodule means a previous tick died mid-bead — a human decides what to keep.
# Prints what the worker will branch from. Exits nonzero on any failure.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"
need gh git-town

if ! real_bd ping >/dev/null 2>&1; then
  real_bd dolt start >/dev/null 2>&1 || true
  real_bd ping >/dev/null 2>&1 || die "beads database unreachable. Start it with: bd dolt start"
fi

rc=0
bd close oo-preflight-no-such-bead >/dev/null 2>&1 || rc=$?
[ "$rc" -eq 77 ] || die "the bd guard shim is not first on PATH ('bd close' exited $rc, expected 77).
Nothing is stopping an agent closing its own bead (CLAUDE.md hard rule 4).
Relaunch claude with the shim first on PATH (settings.json cannot do this - env values are
copied literally, so \${PATH} is NOT expanded):
    PATH=\"$REPO_ROOT/tools/guard:\$PATH\" claude"

[ -e "$DEV/.git" ] || die "oolite-dev is not checked out; run: git submodule update --init"
# Local config only: oolite-dev is the game fork and carries no git-town.toml of its own, so these
# live in .git/modules/oolite-dev/config and never reach a pull request. Idempotent.
real_git -C "$DEV" config git-town.main-branch "${OOLITE_DEV_MAIN:-develop}"
real_git -C "$DEV" config git-town.forge-type github
real_git -C "$DEV" config git-town.github-connector gh
real_git -C "$DEV" config git-town.dev-remote origin

dev_clean || die "oolite-dev has uncommitted changes on $(dev_branch):
$(real_git -C "$DEV" status --short | head -20)
A previous tick may have died mid-bead. Commit, stash or discard them before working the queue."

gh auth status >/dev/null 2>&1 || die "gh is not authenticated; 'git town propose' cannot open a pull request. Run: gh auth login"

echo "preflight ok: beads up, guard live, oolite-dev clean, bead branches stack on $(dev_main)"
