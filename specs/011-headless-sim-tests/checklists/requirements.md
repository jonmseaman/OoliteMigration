# Specification Quality Checklist: Headless simulation tests

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-11-13
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

Validated in one pass on 2026-11-13. Three items pass with a qualification:

- **Implementation details.** The request itself names C++ and the Flatpak build, and the spec
  names the files and scenarios it measures against (`s1_police_kills_pirate.feature`,
  `shipdata.plist`, the `n` key), as specs 003, 005 and 009 do. It does not say how a headless game
  is built, where keys are injected in the code, which harness macros are used or what the tier is
  called. Those are left to the plan.
- **Audience.** The stakeholders are Jon, the agents and the upstream maintainers, all technical.
  The Purpose section is written for a reader who knows the game but not the code.
- **Technology-agnostic success criteria.** SC-001 to SC-011 are stated as outcomes a person can
  observe (passes with no display, time ratio, counts, minutes). SC-005 and SC-007 name the three
  platforms because per-platform behaviour is the thing being measured.

Things the planner should know:

- **No clarification markers.** Hard rule 8 forbids waiting for Jon, so every open point has a
  recorded default in the spec's "Decisions taken by default" and "Assumptions" sections. The ones
  most likely to be overridden: not waiting for spec 003; "module" read as equipment; keyboard
  only; tutorial lessons 0 and 1 only; the speed targets.
- **The speed and duration targets are unmeasured.** SC-001, SC-004 and SC-010 were set before any
  baseline exists. The plan's first task should measure start-up and stepping cost.
- **Story 4 may end without a fix.** The Flatpak report has no known cause and no located source.
  FR-030 accepts a written finding as a valid outcome.
- **Template resolution.** `.specify/scripts/powershell/resolve-template.ps1` could not be run:
  PowerShell (`pwsh`) is not installed on this Mac. The resolver's layers were checked by hand
  instead. There is no `.specify/templates/overrides/`, no `.specify/presets/` and no
  `.specify/extensions/`, so `.specify/templates/spec-template.md` is the whole composition and
  was used as it is.
- **Hooks.** `.specify/extensions.yml` does not exist, so no `before_specify` or `after_specify`
  hook ran and no branch was created by this command.
- **Constitution.** `.specify/memory/constitution.md` is still the unfilled template. The project's
  rules were taken from `CLAUDE.md`.
- **`.specify/feature.json`** now points at `specs/011-headless-sim-tests`. It pointed at
  `specs/009-modern-cpp-std`, which is still being implemented. A session working on 009 must name
  its directory explicitly.
