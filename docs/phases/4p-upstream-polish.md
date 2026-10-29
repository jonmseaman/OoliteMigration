# Phase 4p — Polish for upstream

**Status:** in progress · **Depends on:** Phase 4 (done 2026-10-21) · **Before:** [Phase 5](5-apple-silicon.md)

## Goal

Make the C++ fork something the Oolite maintainers can review and want: behaviour matches 1.93
where it should, the remaining differences are documented, the source is free of migration
scaffolding, and a write-up explains the work. Windows x64 only; macOS and Linux are Phase 5.

Inputs: `notes/Phase 4 Writeup.md` (draft write-up and open items),
`notes/2026-10-28 Modern C++ Idiom Review.md`, `notes/2026-10-26 Code Review.md`,
`notes/Follow Ups.md`, `notes/Playtest Notes.md`, and the [parity audit](../parity/README.md).

## Exit gate

- [ ] `tests/run.sh all` green on Clang and GCC.
- [ ] Every high and medium ❌ in [parity/README.md](../parity/README.md) is fixed (with a test) or
      moved to ⚠️ with a reason.
- [ ] `grep -rnE "ADR-[0-9]{4}|\boo-[0-9a-z]{3,}\b" oolite-dev/src` finds no migration bookkeeping
      in source comments (comments explain the code, not the project history).
- [ ] `grep -rn GNUSTEP oolite-dev/src oolite-dev/meson.build` finds only code that still needs it
      (or nothing).
- [ ] The write-up is final and sent upstream — Jon.

## Work items

1. **Behaviour parity.** Fix the parity audit's high/medium findings, starting with the cross-cutting
   ones (preference defaults with `oo_*ForKey` semantics; two `doubleValue` ports). Each fix gets a
   unit or component test.
2. **Real bugs from the idiom review** (§2.5): `SDL/main.cpp` `strcat` into the environment buffer
   and the `argv[argc]` dereference after `-load`; `OOCPUInfo.cpp` unchecked `strcpy`;
   `OOMeshToOctreeConverter.cpp` leak on `realloc` failure.
3. **Playtest bugs:** blank screen starting the tutorial; view keys 1–4 and W/A not working; menu
   controls unclear. Check each against upstream 1.93 first and note if it is upstream's too.
4. **Source hygiene:**
   - strip bead ids, ADR numbers and `docs/` paths from source comments (≈1,370 `ADR-NNNN` hits);
     keep the explanation, drop the bookkeeping;
   - remove dead GNUstep macros and scripts (bead oo-wm7);
   - Windows manifest (bead oo-1vw).
5. **Tooling** (idiom review §2.6): `.clang-tidy`, `.editorconfig`, a Google-style `.clang-format`
   applied in one reformat commit listed in `.git-blame-ignore-revs`; turn on the warnings that are
   already at zero hits (`-Wextra -Wpedantic`); fix build references to deleted scripts.
6. **QuickJS-ng 0.17.** Bump `oolite-dev/subprojects/quickjs-ng.wrap`; JS API snapshot and corpus
   must not regress.
7. **Expansion compatibility.** Keep [EXPANSION_MIGRATION.md](../EXPANSION_MIGRATION.md) and
   [expansions/](../expansions/README.md) current; it ships with the write-up.
8. **The write-up.** Finish `notes/Phase 4 Writeup.md` (Jon's motivation paragraph, final numbers).

Out of scope here (Phase 6): the mechanical modernisation sweeps of the idiom review §3 steps 3–8
(`nullptr`, `enum class`, `constexpr` constants, platform layer, structural splits). Do them after
upstream has seen the faithful version, so reviewers can still compare it line for line.

## Status log

- 2026-10-28 — Phase doc created during the docs cleanup; phases 0–4 docs and ADRs moved to the
  `archive/phase-0-4-docs` tag.
