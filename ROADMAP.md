# Oolite migration roadmap

Objective-C/GNUstep → C++, native on Apple Silicon, Windows x64 and Linux x64, with published
expansions working. **Start here.**

**Status (2026-10-28):** Phases 0–4 are done: Oolite builds and runs as plain C++20 on Windows x64
with Clang and GCC, with no Objective-C, GNUstep or SpiderMonkey. The current work is
**[Phase 4p — polish for upstream](docs/phases/4p-upstream-polish.md)**: behaviour parity fixes,
source hygiene, and the write-up for the Oolite maintainers. `bd ready` lists what can start.

## Phases

| Phase | Name | Doc | Status |
|---:|---|---|---|
| 0–4 | Safety net · JS engine (QuickJS-ng) · `oofnd` (Foundation replacement) · ObjC → C++ · remove ObjC runtime | `notes/Phase 4 Writeup.md`; old docs under the git tag `archive/phase-0-4-docs` | done 2026-10-21 |
| 4p | Polish for upstream | [4p-upstream-polish.md](docs/phases/4p-upstream-polish.md) | **in progress** |
| 5 | Apple Silicon 🎯 and Linux x64 | [5-apple-silicon.md](docs/phases/5-apple-silicon.md) | not started; needs the Mac and a Linux build environment |
| 5b | JSON5 beside plists | [5b-data-formats.md](docs/phases/5b-data-formats.md) | proposed |
| 6 | Modernise (C++23, GL 3.3 Core, idiomatic C++) | [6-modernise.md](docs/phases/6-modernise.md) | not started |

## Where things are

| Doc | What |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Agent contract: hard rules, commands, exemplars |
| [docs/README.md](docs/README.md) | Index of the docs, and what to read for which task |
| [docs/current-state.md](docs/current-state.md) | What the code is now: layout, builds, tests, known differences |
| [docs/workflow.md](docs/workflow.md) | Tiers A/B/C, bead sizing, definition of done |
| [GLOSSARY.md](GLOSSARY.md) | Terms |
| [tools/setup-windows.sh](tools/setup-windows.sh) | Setting up the Windows machine from scratch |

## Where Jon is

Re-blessing goldens; accounts, credentials, hardware and macOS TCC/signing grants; merging pull
requests; and any decision he wants to override. Everything else is an agent's job, and an agent
that needs a decision takes the conservative default and records it.
