#!/usr/bin/env bash
# Run once before the first tick. Proves the things a tick silently depends on:
#   1. the beads database answers;
#   2. oolite-dev is checked out, has a local `develop` branch, and is clean.
# A dirty submodule means a previous tick died mid-bead — a human decides what to keep.
# Prints what the worker will branch from. Exits nonzero on any failure.
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

if ! real_bd ping >/dev/null 2>&1; then
  real_bd dolt start >/dev/null 2>&1 || true
  real_bd ping >/dev/null 2>&1 || die "beads database unreachable. Start it with: bd dolt start"
fi

[ -e "$DEV/.git" ] || die "oolite-dev is not checked out; run: git submodule update --init"
real_git -C "$DEV" show-ref --verify --quiet "refs/heads/$(dev_main)" \
  || die "oolite-dev has no local $(dev_main) branch; epic branches start from it"

dev_clean || die "oolite-dev has uncommitted changes on $(dev_branch):
$(real_git -C "$DEV" status --short | head -20)
A previous tick may have died mid-bead. Commit, stash or discard them before working the queue."

echo "preflight ok: beads up, oolite-dev clean on $(real_git -C "$DEV" rev-parse --abbrev-ref HEAD), epic branches start from $(dev_main)"
