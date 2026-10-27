# OoliteMigration

Planning and working repository for migrating [Oolite](https://oolite.space/) from
Objective-C/GNUstep to Modern C++ (C++20 during conversion, C++23 at the end), with native Apple Silicon, Windows x64, and Linux x64 targets,
while keeping all published expansions (OXP/OXZ) working unmodified.

**Start here: [ROADMAP.md](ROADMAP.md).** Agents: [CLAUDE.md](CLAUDE.md).
**Setting up the Windows machine:** [tools/setup-windows.sh](tools/setup-windows.sh) — MSYS2, the
pinned toolchain, `gh` and `git-town`, and a keep-awake tool.

## Layout

| Path | What |
|---|---|
| `ROADMAP.md` | Phase table, infra track, decisions — the entry point |
| `CLAUDE.md` / `GLOSSARY.md` | The agent contract and the terms |
| `docs/architecture.md` | Survey, target design, risks, expansion contracts |
| `docs/execution-model.md` | Verification tiers, agent authority, story sizing |
| `docs/phases/`, `docs/decisions/` | Per-phase docs, ADRs |
| `tools/gen-stories.py` | Generates the beads queue from the tree |
| `tools/check-file-modes.sh` | Guardrail: bare-program scripts are committed `100755` (see CLAUDE.md conventions) |
| `tools/guard/` | PATH shims: no agent closes a bead or pushes to an integration branch |
| `tools/sync-dev.sh` / `tools/phase-pr.sh` | Record merged work; open the phase's `develop → master` PR |
| `.claude/skills/beads-worker/` | The skill that works the queue, one bead per `/loop` iteration |
| `oolite-dev` | **Submodule**: `jonmseaman/oolite`, branch `develop`. **The migration target**; all game work happens here |
| `oolite-main` | Submodule: `jonmseaman/oolite`, branch `master` (what has been merged; reference only) |
| `upstream/oolite` | Submodule: `OoliteProject/oolite`, unmodified (reference: the Objective-C original) |
| `upstream/oolite-tests` | Submodule: `OoliteProject/oolite-tests`; test OXPs and the release-checklist save files (golden scenarios 13–17) |
| `upstream/oolite-expansion-catalog` | Submodule: `OoliteProject/oolite-expansion-catalog`; expansion URL list, source for the OXP corpus |
| `upstream/spidermonkey-ff4` | Submodule: `OoliteProject/spidermonkey-ff4`; the patched SpiderMonkey 1.8.5 Oolite embedded (reference only) |
| `upstream/oolite-debug-console` | Submodule: `OoliteProject/oolite-debug-console`; TCP debug console (protocol reference) |
| `upstream/oolite-mac-components` | Submodule: `OoliteProject/oolite-mac-components`; historical macOS Cocoa components (Phase 5 reference) |

Everything under `upstream/` is OoliteProject's own and unmodified; only `jonmseaman/oolite`
carries changes ([ADR-0067](docs/decisions/0067-submodules-replace-subtrees.md), which replaces
ADR-0017's subtree decision).

## Remotes

| Remote | URL | Role |
|---|---|---|
| `origin` | `jonmseaman/OoliteMigration` | this repo; `main` is the base branch |

The game's remotes live inside `oolite-dev`: `origin` there is `jonmseaman/oolite`; add
`upstream` = `OoliteProject/oolite` to merge upstream changes.

## Clone

```bash
git clone --recursive https://github.com/jonmseaman/OoliteMigration.git
```

On Windows first set `git config --global core.autocrlf false` and `core.longpaths true`. In an
existing clone: `git submodule update --init` (add `--recursive` only if you need upstream's own
submodules).

## Work on the game

`oolite-dev` is an ordinary clone of the fork. Check out `develop` there, commit, push, then
record the new commit here:

```bash
cd oolite-dev && git checkout develop
# ...edit, build (./mk.sh build test), commit...
git push origin develop
cd .. && git add oolite-dev && git commit -m "oolite-dev: <what changed>"
```

`develop` is merged into `master` on GitHub when it is ready; `git submodule update --remote
oolite-main` then moves the reference copy.

## Sync with upstream Oolite

```bash
cd oolite-dev && git remote add upstream https://github.com/OoliteProject/oolite.git  # once
git fetch upstream && git merge upstream/master        # into develop; resolve, build, test
cd .. && git submodule update --remote upstream/oolite  # move the reference copy to match
```
