# Specification Quality Checklist: Adopt cpplint

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-11-02
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — see note 1
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders — see note 1
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — see note 2
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details) — see note 1
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification — see note 1

## Notes

1. The feature is a developer tool, and its readers are the game's developers. The tool (cpplint)
   and the tools it has to agree with (clang-format, clang-tidy, `mk.sh`, `tests/run.sh`, CI) are
   the subject of the spec, not an implementation choice, so they are named. The spec doesn't
   choose how the gate is built: the script language, the baseline file format, the
   configuration's file name, or how the version is pinned. Those are left to the plan.
2. Open choices were settled with conservative defaults instead of markers, per the project's
   "never wait for Jon" rule. They are listed with reasons in the spec's "Notes — decisions taken
   without Jon". The classification of four large whitespace and brace categories is deferred to
   the plan on purpose (note 4 there), because it depends on a configured run over a formatted
   tree.
3. The numbers in Context come from a run of cpplint 2.0.2 with default settings on 2026-11-02
   over 522 git-tracked files under `oolite-dev/src`, leaving out MiniZip and
   `stb_image_write.h`. The plan should re-measure with the configured settings.
4. The spec template came from `.specify/templates/spec-template.md` directly. The resolver
   script needs PowerShell, which this macOS machine lacks. No overrides, presets or extensions
   exist, so the core template is the full resolution.
