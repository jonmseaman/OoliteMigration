# Specification Quality Checklist: Reproducible, fast builds

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

- This is a build-infrastructure feature. Its users are the people and agents who build the game,
  and the build files, flavours, compiler cache and tools it names are the subject of the
  request, not implementation choices. On that reading the content-quality and
  technology-agnostic items pass, as for specs 009, 011 and 013. The requirements state outcomes
  (one version unit, a fixed timestamp, one compile per source, no LTO per test link). The plan
  chooses how: `vcs_tag` or a custom target, linker flags, a static library, which cache.
- The success criteria are counts of build steps, byte comparisons and CPU time of a single
  process, not wall time, because the machine runs other builds (Jon, 2026-11-12). The baseline
  for every count is in `baseline/counts.md`. It was taken without compiling, except for one real
  deployment build that confirmed the method (230 recompiles predicted and measured).
- The base is the top of the `seriesb/*` stack, `seriesb/026-migration-completion` at a3d651a4d
  (Jon, 2026-11-12), not `develop`. The counts, SC targets and "today" figures were redone there:
  5 compiles per version change, 71 test relinks, 831 compiles in test and dev (465 targeted).
  `develop`'s numbers stay as the comparison for the version on the compile line. The dev `-O0`
  decision was re-argued, because the base dropped the golden tests' float pins (3902c8903).
- No clarification markers. Jon's two questions are answered in the spec. The date/time cost is
  the Context table and SC-001. Dev at `-O0` is measured and defaulted to "stay at `-O2`" in
  *Decisions taken by default*, with the override stated.
- Scope bounds: installers are out (follow-up). Reproducibility covers clean trees on one machine
  with one toolchain. The debug flavour is held to its edge case. macOS is checked when a Mac is
  available.
- SC-006's baseline (CPU time of one LTO core test link) is not measured yet. Jon's ninja logs
  give about 90 s of wall time per link, and the plan's first task measures it.
- `.specify/feature.json` still names spec 012 (see the spec's decisions). Run `/speckit-plan`
  with `specs/014-reproducible-fast-builds`.
- Validation iterations: 2. A count was corrected while writing (215 links is the game plus 214
  test executables), and the spec was re-validated after the base moved to the stack. All items
  pass.
