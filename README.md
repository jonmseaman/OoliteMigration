# OoliteMigration

Planning and working repository for migrating [Oolite](https://oolite.space/) from
Objective-C/GNUstep to Modern C++ (C++20 during conversion, C++23 at the end), with native Apple Silicon, Windows x64, and Linux x64 targets,
while keeping all published expansions (OXP/OXZ) working unmodified.

**Start here: [ROADMAP.md](ROADMAP.md).** Agents: [CLAUDE.md](CLAUDE.md).
**Before the first fleet run on the Windows machine:** the checklist in [docs/infra/0-machines.md](docs/infra/0-machines.md)
(keep-awake tool, MSYS2, `bd dolt pull`, Hermes and `claude` logins).

## Layout

| Path | What |
|---|---|
| `ROADMAP.md` | Phase table, infra track, decisions — the entry point |
| `CLAUDE.md` / `GLOSSARY.md` / `.hermes.md` | Agent contracts (Claude Code; Hermes) and terms |
| `docs/architecture.md` | Survey, target design, risks, expansion contracts |
| `docs/execution-model.md` | Verification tiers, agent authority, story sizing |
| `docs/phases/`, `docs/infra/`, `docs/decisions/` | Per-phase docs, infra track, ADRs |
| `tools/gen-stories.py` | Generates the beads queue from the tree |
| `.agents/skills/beads-worker/` | The Hermes skill that drains the queue |
| `upstream/oolite` | **Subtree** of the fork `jonmseaman/oolite`. **The migration target.** |
| `upstream/oolite-tests` | Subtree: test OXPs and the release-checklist save files (golden scenarios 13–17) |
| `upstream/oolite-expansion-catalog` | Subtree: expansion URL list — source for the OXP corpus |
| `upstream/spidermonkey-ff4` | Submodule (fork `jonmseaman/spidermonkey-ff4`): the patched SpiderMonkey 1.8.5 Oolite embeds (reference only) |
| `upstream/oolite-debug-console` | Submodule (fork): TCP debug console (protocol reference) |
| `upstream/oolite-mac-components` | Submodule (fork): historical macOS Cocoa components (Phase 5 reference) |

Subtrees are part of this repo's tree and every worktree; submodules are reference only and are
absent from worktrees ([ADR-0017](docs/decisions/0017-native-windows-subtree.md)).

## Remotes

| Remote | URL | Role |
|---|---|---|
| `origin` | `jonmseaman/OoliteMigration` | this repo; `main` is the base branch |
| `fork` | `jonmseaman/oolite` | receives `upstream/oolite` by `git subtree push` (branch `migration`) |
| `upstream` | `OoliteProject/oolite` | source of truth; `git subtree pull --squash` monthly |
| `oolite-tests`, `oolite-expansion-catalog` | `jonmseaman/<repo>` | push targets for the other two subtrees |
| `oolite-tests-upstream`, `oolite-expansion-catalog-upstream` | `OoliteProject/<repo>` | pull sources for them |

Every Oolite repository is forked under `jonmseaman/` (2026-09-11); the remaining submodules point at
those forks in `.gitmodules`. Remotes are local config: add them after cloning.

## Clone

```bash
git clone --recursive https://github.com/jonmseaman/OoliteMigration.git
```

On Windows first set `git config --global core.autocrlf false` and `core.longpaths true`.

## Sync with upstream Oolite (upstream-tracker task)

```bash
git subtree pull --prefix=upstream/oolite upstream master --squash
```

## Mirror the converted tree to the fork (merge queue after each green batch; weekly by hand until then)

```bash
git push origin main
git subtree push --prefix=upstream/oolite fork migration
```
