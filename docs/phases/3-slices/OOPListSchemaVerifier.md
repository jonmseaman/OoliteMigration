# Slice plan: OOPListSchemaVerifier

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-4plo). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OOPListSchemaVerifier.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/OXPVerifier/OOPListSchemaVerifier.mm` (1,637 lines) + header (175 lines).
  One class, `OOPListSchemaVerifier`, its private category `OOPrivate`, and about forty static
  helpers in anonymous namespaces (Phase 2 already moved their values to `oo::PList`).
- **Shape:** the class is small (~320 lines); most of the file is the per-type `Verify_*`
  functions. All but four of those, and all the string/error helpers, contain no Objective-C and
  stay verbatim ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9).
- **Order:** slice 1, then slice 2. Slice 2 calls the class's private methods, so it needs the
  converted class from slice 1. The OXPVerifier hierarchy exemplar (oo-cwz) lands first.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | class shell, public API, `OOPrivate` verification core | ~350 | ~870 |
| 2 | the four `Verify_*` functions that message the verifier | ~250 | ~770 |
| verbatim | string filters, error builders, the other `Verify_*` | — | not read |

```slice-plan
source: upstream/oolite/src/Core/OXPVerifier/OOPListSchemaVerifier.mm
header: upstream/oolite/src/Core/OXPVerifier/OOPListSchemaVerifier.h

slice 1: class shell, public API and the OOPrivate verification core
  @OOPListSchemaVerifier
  @OOPListSchemaVerifier(OOPrivate)
  KeyPathDescriptionOfError()
  KeyPathToString()
  SubstringToIndex()

slice 2: type verifiers that call back into the verifier or its delegate
  Verify_Array()
  Verify_Dictionary()
  Verify_OneOf()
  Verify_DelegatedType()

verbatim: plain C/C++ helpers, no Objective-C (checked)
  *
```
