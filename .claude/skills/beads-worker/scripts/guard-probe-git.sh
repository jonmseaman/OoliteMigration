#!/usr/bin/env bash
# guard-probe-git.sh: drive tools/guard/git against real throwaway repos and check that a bead's
# feature branch may reach the game fork (that is what `git town propose` pushes) while develop,
# master, main and this planning repo may not. Offline: the "remote" is a local bare repo.
# Run: bash .claude/skills/beads-worker/scripts/guard-probe-git.sh
set -u
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shim="$(cd "$here/../../../../tools/guard" && pwd)/git"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
fail=0; pass=0

git init -q --bare "$tmp/oolite.git"
git init -q --bare "$tmp/OoliteMigration.git"
make_clone() { # make_clone <name> <origin-path>
  git clone -q "$2" "$tmp/$1"
  git -C "$tmp/$1" -c user.email=p@l -c user.name=p commit -q --allow-empty -m init
  git -C "$tmp/$1" branch -M develop
  git -C "$tmp/$1" config git-town.main-branch develop
  git -C "$tmp/$1" checkout -q -b feature/1027-probe
  git -C "$tmp/$1" -c user.email=p@l -c user.name=p commit -q --allow-empty -m work
}
make_clone dev "$tmp/oolite.git"
make_clone outer "$tmp/OoliteMigration.git"

run() { # run <expected-exit> <label> <args...>
  local want="$1" label="$2"; shift 2
  bash "$shim" "$@" >/dev/null 2>&1
  local got=$?
  if [ "$got" = "$want" ]; then pass=$((pass + 1)); else fail=$((fail + 1)); echo "FAIL: $label exit $got, want $want"; fi
}

# Allowed: the bead's branch reaching the fork — this is `git town propose`'s push.
run 0  "feature branch"        -C "$tmp/dev" push origin feature/1027-probe
run 0  "feature, lease force"  -C "$tmp/dev" push --force-with-lease origin feature/1027-probe
# Refused: the planning repo is never pushed by an agent.
run 77 "outer repo"            -C "$tmp/outer" push origin feature/1027-probe
# Refused: integration branches move only by merging a pull request.
run 77 "develop"               -C "$tmp/dev" push origin develop
run 77 "master"                -C "$tmp/dev" push origin master
run 77 "main"                  -C "$tmp/dev" push origin main
run 77 "HEAD:master"           -C "$tmp/dev" push origin HEAD:master
run 77 "refs/heads/develop"    -C "$tmp/dev" push origin feature/1027-probe:refs/heads/develop
# Refused: a bare force discards the remote.
run 77 "bare --force"          -C "$tmp/dev" push --force origin feature/1027-probe
# Everything that is not a push passes through untouched.
run 0  "status"                -C "$tmp/dev" status --short
run 0  "log"                   -C "$tmp/dev" log --oneline -1

echo "guard-probe-git: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
