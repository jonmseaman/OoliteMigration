# Quickstart: build, verify and hand over the series

Run from the OoliteMigration root in Git Bash unless noted; game builds and tests run in MSYS2
UCRT64 (`tools/series` invokes `C:/Users/jon/scoop/apps/msys2/current/usr/bin/bash -lc` with
`MSYSTEM=UCRT64` itself). Commands are defined in [contracts/series-cli.md](contracts/series-cli.md).

## Prerequisites

- `oolite-dev` clean, with `upstream` fetched (`git -C oolite-dev fetch upstream`).
- The history is reachable from `oolite-dev`:
  `git -C oolite-dev fetch .. 338463308` (fetches OoliteMigration's objects into the submodule;
  nothing is pushed).
- clang-format 22 in `.agent-tmp/series-venv` (`python -m venv .agent-tmp/series-venv &&
  .agent-tmp/series-venv/Scripts/pip install "clang-format>=22,<23"`).
- The MSYS2 packages from `tools/setup-windows.sh`, including GNUstep base, libobjc2 and
  SpiderMonkey (`libjs32ECMAv5`) for the Objective-C era steps.

## 1. Plan the cuts

```bash
python tools/series/series.py inventory          # writes series/inventory.tsv
python tools/series/series.py cut --chapters     # writes R14's 25 steps to manifest.json
python tools/series/series.py check              # exit 1 until steps are built
```

Expected: 25 planned steps (001–019 history chapters, 020–025 the `develop` tail), each with its
chapter, history range and measured size.

## 2. Build the stack

```bash
python tools/series/series.py build --from 1
git -C oolite-dev town branch    # shows series/000-upstream-base → 001 → 002 → …
```

Expected: one branch per step, each one commit on its parent, and Git Town's tree matches the
manifest order.

## 3. Verify in order

```bash
python tools/series/series.py verify --from 1          # incremental builds, step by step
python tools/series/series.py verify <last> --clean    # clean build of the last step
python tools/series/series.py check --verified          # exit 0 only when every step passes
```

Expected: every step's record shows Clang and, where the era allows, GCC builds with zero warnings,
plus unit and smoke tests passing; `check --verified` exits 0.

## 4. The end state is `develop`

```bash
git -C oolite-dev diff --stat series/<last> 3aa8d65e8    # only paths in the exclusions list
```

## 5. Hand over (Jon)

From the manifest, in order. Pushing and proposing are Jon's steps, not the agent's:

```bash
git -C oolite-dev push origin series/000-upstream-base series/001-… …   # Git for Windows git
gh pr create -R OoliteProject/oolite --base master --head jonmseaman:series/001-… \
   --title "$(head -1 specs/001-split-migration-prs/series/pr/001-….md | sed 's/^# //')" \
   --body-file specs/001-split-migration-prs/series/pr/001-….md
```

Later PRs are opened against the previous step's branch in the fork for a dry run, or one at a
time against upstream `master` as each earlier step merges.
