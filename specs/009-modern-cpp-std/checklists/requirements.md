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
- First iteration failed four items, fixed in the second: SC-009 was not measurable (now a sampled
  review), SC-004's target was tighter than the files it counts (now 2,000 lines), FR-015's note
  left out Story 3, and `oo::EntityHold`'s fate was unstated (now an assumption, left to the plan).
  Second iteration passed.
