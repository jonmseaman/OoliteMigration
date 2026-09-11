# ADR-0012: Existing C stays C; only Objective-C is converted

**Status:** Accepted · **Date:** 2026-09-10

## Context

The plan listed `oomath` (`OOVector`, `OOHPVector`, `OOMatrix`, `OOQuaternion`, `OOTriangle`,
`Octree`) as the first Phase 3 conversion and the house-style exemplar, describing it as "near-pure
C". Measured 2026-09-10 in `upstream/oolite/src/Core`:

| File | Lines | `@interface`/`@implementation` | What it is |
|---|---:|---:|---|
| `OOVector.m` | 155 | 1 (one tiny helper declaration) | C functions |
| `OOHPVector.m` | 146 | 0 | C functions |
| `OOMatrix.m` | 473 | 0 | C functions |
| `OOQuaternion.m` | 415 | 0 | C functions |
| `OOTriangle.h` | — | 0 | header-only C |
| `Octree.m` | 973 | 3 | a real Objective-C class |

Plus the true `.c` files, ~59k lines: `OOPlanetData.c` (48,170, generated tables), `miniz.c`
(7,853, vendored), `MiniZip/` (2,378, vendored), `legacy_random.c` (343, the deterministic LCG),
`OOTCPStreamDecoder.c` (245). C is callable from C++ unchanged.

Jon's decision: do not rewrite C. Reuse it.

## Decision

1. **A file is a conversion target iff it contains `@implementation`.** The Phase 3 inventory is
   `grep -l '@implementation'`, not `find -name '*.m'`.
2. **`.m` files with no Objective-C are renamed to `.c`** (or their content moved into the existing
   header as `static inline`) in one mechanical Phase 3 story per file. Their headers get
   `extern "C"` guards. No behaviour change, no restyling; goldens must not move.
3. **True `.c` files are never touched** by the migration except for build-system plumbing.
4. **Inside a converted class, method bodies that are plain C stay verbatim.** Conversion changes
   the class shell (`@interface` → `class`, message sends → member calls, refcounting → `oo::Ref`);
   it does not rewrite arithmetic, parsing loops, or table lookups that already compile as C.
5. The Phase 6 "value semantics for leaf types" item no longer covers `Vector`/`Quaternion`/
   `Matrix`: they are already C structs passed by value.

## Consequences

- **The house-style exemplar changes.** `oomath` cannot set C++ class style because it has no
  classes. The exemplar sequence is now: a small leaf class (`OOColor`), then `Core/OXPVerifier`
  (27 files, a real hierarchy with its own test data). `Octree` joins the leaf-utility sweep.
- Phase 3's story count drops slightly (the four math `.m` files become four rename stories).
- Anything in the docs that says "convert `oomath` first" is superseded by this ADR.
- The rule generalises: if the fleet is about to rewrite something that already compiles as C,
  the story is wrong. CLAUDE.md carries this as a hard rule.
