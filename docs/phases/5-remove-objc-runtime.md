# Phase 5 — Remove the Objective-C runtime

**Status:** not started · **Est.:** 1–2 eng-months · **Depends on:** [Phase 4](4-cpp-conversion.md)

## Goal

Delete `AutoreleaseScope`, drop `libobjc2` and every `-fobjc-*` flag, rename `.mm` → `.cpp`, restore
GCC to CI. Nearly mechanical if Phase 4 was disciplined.

## Entry gate

- [ ] Phase 4 exit gate green (zero `@implementation`)
- [ ] Renderer target for Phase 6 decided (open decision 5) — **do not defer past this phase**

## Exit gate

- [ ] No `.mm` files; no `-fobjc-*` in any build line; `libobjc2` gone from all platforms
- [ ] GCC build green on Linux alongside Clang
- [ ] Goldens reproduce on all three platforms; ASan/UBSan clean

## Seams / sweeps

One mechanical pass. If it is not mechanical, something in Phase 4 was left undone; fix it there.

## Status log

- 2026-09-06 — Phase doc created from MIGRATION_PLAN §8 (Phase 5).
