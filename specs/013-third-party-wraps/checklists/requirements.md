# Specification Quality Checklist: Third-party code by wrap

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

- This is a source-structure feature: its users are the people who read, build and package the
  game, and the files, wraps, meson options and licence document it names are the subject of the
  request, not implementation choices. On that reading the content-quality and technology-agnostic
  items pass, the same reading specs 009 and 011 use. How each overlay is written, the dependency
  names and the exact tinyexr tag and stb commit are left to the plan.
- No clarification markers. The six points the brief asked the spec to settle each have a default
  in *Decisions taken by default* or a requirement: which edits come back as patches (edit table,
  FR-003); pristine sources that warn (FR-006); wrap always via `force_fallback_for` (FR-008);
  licences (FR-013); offline builds (FR-012); keep `subprojects/` (FR-017).
- Versions: the latest of each (Jon, 2026-11-12): miniz 3.1.2, zlib 1.4's MiniZip, tinyexr
  v3.4.0 (its single header only), stb `48fb1c9` (stb_image_write v1.17). Because of the upgrade,
  FR-011 and SC-005 compare decoded snapshots, with stated bounds, instead of file bytes.
- Verified without reading expansion content: tinyexr v3.4.0's `tinyexr.h` still declares every
  call `OOSaveEXRSnapshot.cpp` makes and still defaults to miniz; every `unz*` name the game uses
  has the same declaration in zlib 1.4's `unzip.h`; zlib 1.4 still lacks the MiniZip
  compression-method fix (kept as the only behavioural patch); stb v1.17 does the HDR negative
  clamp itself (patch dropped); miniz and tinyexr are Windows-only today.
- `.specify/feature.json` was not repointed at this spec because it points at spec 012, which
  another session is writing (recorded in the spec's decisions). `/speckit-plan` for this feature
  must be given `specs/013-third-party-wraps` explicitly.
- SC-005 needs a new fixed-image snapshot test that passes on the unmoved code first (plan M0). The
  plan changed FR-011's wording: expected values come from the input and the formats' rules, the
  `.exr` signature is checked by prefix (it carries a timestamp), and the `.hdr` bound is 1/128,
  one RGBE step.
- Validation iterations: 2 (the second after the version change), all items pass.
