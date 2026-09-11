# Phase 4 — Remove the Objective-C runtime

**Status:** not started · **Est.:** 1–2 eng-months · **Depends on:** [Phase 3](3-cpp-conversion.md)

## Goal

Delete `AutoreleaseScope`, drop `libobjc2` and every `-fobjc-*` flag, rename `.mm` → `.cpp`, restore
the GCC (MINGW64) build alongside Clang (UCRT64). Nearly mechanical if Phase 3 was disciplined.

## Entry gate

- [ ] Phase 3 exit gate green (zero `@implementation`)
- [ ] Renderer target is GL 3.3 Core (decided, ADR-0013); pull the Phase 6 renderer work forward if Apple has removed legacy GL by now (Phase 5 needs it)

## Exit gate

- [ ] No `.mm` files; no `-fobjc-*` in any build line; `libobjc2` gone from all platforms
- [ ] GCC (MINGW64) build green alongside Clang (UCRT64)
- [ ] Goldens reproduce on Windows; ASan clean
- [ ] Cross-platform golden policy (decision 11) implemented on Windows, since Phase 5 adds the first other platforms

## Notes

This is the last phase that runs entirely on the single Windows machine
([ADR-0010](../decisions/0010-single-windows-machine.md), [ADR-0017](../decisions/0017-native-windows-subtree.md)).
Its exit is the point at which the Mac and a Linux build environment join.

## Seams / sweeps

One mechanical pass. If it is not mechanical, something in Phase 3 was left undone; fix it there.

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §8 (Phase 4).
