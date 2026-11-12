# Specification Quality Checklist: Replace the `.tbl` tables

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-11-12
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

- This is a source-structure feature: its users are the people who read and change the game's
  code, and the files, types and include sites it names are the subject of the request, not
  implementation choices. On that reading the content-quality items pass, the same reading spec
  009 uses. How each header is built (the mapping, the derived table, the OpenGL item list's form)
  is left to the plan, which follows `notes/2026-11-07 Enum Tables from tbl X-Macros.md` and spec
  009's enum contract.
- No clarification markers: the three open choices (taking over spec 009's P8, including
  `OOOpenGLStates.tbl`, leaving the call-site rename to spec 009) have defaults recorded in the
  spec's *Notes and decisions*, per hard rule 8.
- Success criteria are measured by file counts, the script API snapshot, a saved-game round trip,
  the test suites and the corpus; SC-004 needs a recorded trial per kind, which the plan must
  schedule.
- Validation iterations: 1, all items pass.
