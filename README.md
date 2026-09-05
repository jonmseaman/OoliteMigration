# OoliteMigration

Planning and working repository for migrating [Oolite](https://oolite.space/) from
Objective-C/GNUstep to Modern C++23, with native Apple Silicon, Windows x64, and Linux x64 targets,
while keeping all published expansions (OXP/OXZ) working unmodified.

**Start here: [MIGRATION_PLAN.md](MIGRATION_PLAN.md).**

## Layout

| Path | What |
|---|---|
| `MIGRATION_PLAN.md` | The migration plan — survey, risks, phased approach, expansion strategy |
| `upstream/oolite` | Submodule: the main Oolite repo. **The migration target.** |
| `upstream/spidermonkey-ff4` | Submodule: the patched SpiderMonkey 1.8.5 Oolite embeds (see plan §4/R1) |
| `upstream/oolite-tests` | Submodule: test OXPs and legacy test projects |
| `upstream/oolite-debug-console` | Submodule: TCP debug console — drives the golden test harness |
| `upstream/oolite-mac-components` | Submodule: historical macOS Cocoa components (Phase 3 reference) |
| `upstream/oolite-expansion-catalog` | Submodule: expansion URL list — source for the OXP corpus |

## Remotes

`origin` is the fork; `upstream` is the source of truth.

| Repo | `origin` | `upstream` |
|---|---|---|
| this repo | `jonmseaman/OoliteMigration` | — |
| `upstream/oolite` | `jonmseaman/oolite` | `OoliteProject/oolite` |
| other submodules | `OoliteProject/<repo>` (read-only reference) | same |

### Before the first push

Two GitHub repos need to exist:

1. `jonmseaman/OoliteMigration` — new and empty (no README/licence, to avoid a merge on first push)
2. `jonmseaman/oolite` — a fork of `OoliteProject/oolite`

Until the fork exists, `.gitmodules` points at a URL a fresh `git clone --recursive` cannot reach.
The local working copy is unaffected.

## Clone

```bash
git clone --recursive https://github.com/jonmseaman/OoliteMigration.git
```

`upstream/oolite` is ~560 MB and `upstream/spidermonkey-ff4` ~65 MB, so this takes a while.

## Sync with upstream Oolite

```bash
cd upstream/oolite
git fetch upstream
git rebase upstream/master     # see MIGRATION_PLAN.md §10.3 — rebase, don't merge
```
