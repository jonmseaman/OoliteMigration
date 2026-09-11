# ADR-0011: Conversion targets C++20; the C++23 upgrade is part of Phase 6

**Status:** Accepted · **Date:** 2026-09-10 · **Amends:** [ADR-0001](0001-bridge-then-convert.md)

## Context

The original plan compiled the tree as `-std=c++23` from the Objective-C++ switch onward and used
`std::expected` as the error-handling backbone of `oofnd`. C++23 *language* support is fine on all
three toolchains; the *library* is uneven (`std::print` needs libc++ 18, `flat_map` and `generator`
are missing on Apple, C++23 ranges adaptors are partial on MSVC), and every C++23 feature used
during translation is one more thing that differs per platform while the goldens are the only test.
Jon's decision (2026-09-10): convert to C++20 first; modernise to C++23 in Phase 6.

## Decision

- `-std=c++20` from the `.m` → `.mm` switch (Phase 2) through Phase 5. No C++23 library or
  language features in translated or `oofnd` code.
- `oo::Expected<T, E>` with `std::expected`'s API (a small in-tree polyfill or a vendored
  `tl::expected`), so the Phase 6 swap is a search-and-replace.
- C++20 features used freely: `std::span`, `std::string_view`, `std::format`, concepts, C++20
  ranges core, `std::jthread`, designated initialisers, `<=>`.
- Phase 6 raises the standard to C++23 on all three toolchains at their pinned minimums and adopts
  the "Phase 6" rows of the [architecture §3.2](../architecture.md) table: `std::expected`,
  `std::print`, deducing `this`, C++23 ranges adaptors, `if consteval`, multidimensional `[]`.
- The project's end goal is still C++23. Only the conversion target changed.

## Consequences

- Fewer per-platform surprises during the phase where the fleet is doing the most work and the
  goldens are the only oracle. Stories reference one stable standard and one exemplar style.
- The Windows toolchain question (open decision 7, MinGW-clang vs clang-cl) loses urgency: C++20
  library coverage is fine on both. It returns for the Phase 6 upgrade.
- `oo::Expected` is one more piece of `oofnd` to write and test in Phase 2, small.
- The "canary TU on all three toolchains" CI job compiles at C++20 until Phase 6, then C++23.

## History

`MIGRATION_PLAN.md` §3.1–3.2 (git `ee2de41`) chose C++23 throughout; the 2026-09-06 phase docs
carried that forward.
