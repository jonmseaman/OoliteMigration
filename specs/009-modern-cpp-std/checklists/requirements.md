# Specification Quality Checklist: Modern C++ on the standard library

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-11-11
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- **Implementation details.** This feature is a change to the code's own idiom, and the request
  names the target facilities (`std::unique_ptr`, `std::shared_ptr`, `std::weak_ptr`,
  `std::thread`, `enum class`). The spec therefore names the types it removes and the standard
  facilities that replace them, as specs 003, 005 and 006 name the code they measure. It leaves how
  each conversion is done (tools, order inside a story, whether `oo::EntityHold` survives, which
  static check guards each category) to the plan.
- **Audience.** The stakeholders are Jon, agents and upstream maintainers, all technical. Purpose
  and the user-story summaries are written so a non-programmer can follow them; Context is
  technical on purpose.
- **Success criteria.** SC-001 to SC-004 are counts by search with before figures from the
  2026-11-11 survey. SC-005 and SC-006 compare with the base commit. SC-008 relies on spec 006's
  performance measurements where they exist. SC-009 is a sampled review.
- **Clarifications.** None left open. Hard rule 8 (CLAUDE.md) says to take the conservative default
  and record it, so the open choices are in the spec's "Decisions and notes": placement on
  `seriesb/027-modern-cpp`, standard types directly, C++23 in scope, `std::jthread`, and
  `kPascalCase` enumerators.
- **Test edits: no longer blocking.** Jon approved the proposed rule 1 amendment on 2026-11-11; it
  is hard rule 1's third exception in CLAUDE.md and FR-015 applies it. It covers edits only;
  deleting a test still needs his sign-off.
- **Template resolution.** `pwsh` is not installed on this machine, so `resolve-template.ps1` could
  not run. The repository has no `.specify/templates/overrides/`, `.specify/presets/` or
  `.specify/extensions/`, so `.specify/templates/spec-template.md` is the resolved template.
- **Stories 6 and 7 added (2026-11-11, Jon):** C-style casts and C strings, with FR-024 to FR-028,
  SC-010 and SC-011, and five edge cases. Re-validated: each acceptance scenario is a search or a
  check that fails before and passes after; no clarification markers.
- First iteration failed four items, fixed in the second: SC-009 was not measurable (now a sampled
  review), SC-004's target was tighter than the files it counts (now 2,000 lines), FR-015's note
  left out Story 3, and `oo::EntityHold`'s fate was unstated (now an assumption, left to the plan).
  Second iteration passed.

## Success criteria (T105, 2026-11-13, Windows, MSYS2 Clang 23, `oolite-dev` `655a52994`)

- SC-001: met (`check.sh alloc` finds nothing outside `exceptions.md`; `cppcoreguidelines-no-malloc` is fatal; a planted `malloc(1)` fails clang-tidy naming its line)
- SC-002: met (`check.sh ownership` finds nothing; `src/oofnd/Ref.hpp` is deleted, so `oo::RefCounted`, `oo::Ref` and `oo::WeakRef` no longer exist, `a8eb25f3f`)
- SC-003: met (`check.sh enum` finds nothing; no `.tbl` file remains, one fewer than the target: spec 011 converted `OOOpenGLStates.tbl`; `cppcoreguidelines-use-enum-class` is fatal)
- SC-004: met (`oofnd` is 11,596 lines against the base's 13,322, 1,726 fewer; `src/oofnd/README.md` gives each remaining component its reason. Jon's review of 2026-11-13 questions whether `Object.hpp`, the thread-priority helper and the case functions should stay; recorded for later, not part of this count)
- SC-005: not met — the evidence is incomplete: on Windows (Clang) the unit tier passes (42/189/1), the component tier passes 19 of 20 and smoke passes; `test_t1_tutorial_walkthrough` fails, but it fails the same way before this session's commits (`77e9f9cdf`) and postdates the base, so it is not this feature's; the GUI tier and the GCC build were skipped (Jon); ASan could not run on Windows (MSYS2's clang has no sanitizer runtime installed); the macOS ASan, leaks and TSan runs are T099's; CI was not read
- SC-006: met (save: `test_SaveEnumValues` and the enum round-trip tests pass; script API: the Windows base snapshot reproduces the recorded base hash, and the branch differs only by the 26 ECMAScript globals upstream's QuickJS-ng binding (#580) removes, every Oolite global, class and member identical; corpus: Tier 1 on the branch and the base test builds, 36 groups each, PASS 30, KNOWN 1, NOMANIF 5, 0 failed, the same expansion in every outcome)
- SC-007: met (one planted line each for `malloc`, a C-style cast, `strcpy`, an unscoped enum and a non-`kPascalCase` enumerator fails clang-tidy as an error naming its line; ownership and thread types are deleted, so they cannot compile)
- SC-008: not met — not measured: T099's frame-rate, start-up and quit timings against the base are still to run (on the Mac, with `leaks`)
- SC-009: met (20 real allocations, the first in `shuf --random-source=<(yes 009)` order of the allocation search, prose matches skipped: 18 owned by `std::shared_ptr` (`oo::makeShared` or `oo::Dispose`) or `std::unique_ptr`; `OOAsyncWorkManager`'s raw `_operationQueue` became a value member (`001a76280`) and the immortal `NotificationCenter` an exceptions row; `.agent-tmp/cc/alloc-sample20.txt`)
- SC-010: met (`google-readability-casting` is fatal and `./mk.sh tidy` passes on Windows; a clean `meson_test` build with `-Wold-style-cast` has no warning outside vendored `EXRSnapshotSupport`, `655a52994`)
- SC-011: met (`check.sh cstring` finds nothing and `check.sh cstring-types --unclassified` exits 0: every `const char*` or `char[N]` line is a literal's type or an exceptions row; `bugprone-unsafe-functions` is fatal)
