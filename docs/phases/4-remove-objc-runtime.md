# Phase 4 — Remove the Objective-C runtime

**Status:** not started · **Est.:** 1–2 eng-months · **Depends on:** [Phase 3](3-cpp-conversion.md)

## Goal

Delete `AutoreleaseScope`, drop `libobjc2` and every `-fobjc-*` flag, rename `.mm` → `.cpp`, restore
GCC to CI. Nearly mechanical if Phase 3 was disciplined.

## Entry gate

- [ ] Phase 3 exit gate green (zero `@implementation`)
- [ ] Renderer target for Phase 6 decided (open decision 5) — **do not defer past this phase**, and pull the renderer work forward if Apple has removed legacy GL by now (Phase 5 needs it)

## Exit gate

- [ ] No `.mm` files; no `-fobjc-*` in any build line; `libobjc2` gone from all platforms
- [ ] GCC build green on Linux alongside Clang
- [ ] Goldens reproduce on Linux (WSL2) and Windows; ASan/UBSan clean
- [ ] Cross-platform golden policy (open decision 11) implemented, since Phase 5 is the first non-x86-64 target

## Notes

This is the last phase that runs entirely on the single Windows machine
([ADR-0010](../decisions/0010-single-windows-machine.md)). Its exit is the point at which the Mac
is set up as a runner.

## Seams / sweeps

One mechanical pass. If it is not mechanical, something in Phase 3 was left undone; fix it there.

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §8 (Phase 4).
