# Delegated human decisions, 2026-10-19

On 2026-10-19 Jon approved the pending Phase 3/4 test changes ("I approve", twice), then asked the
orchestrator to "Please help me approve whatever is needed" (Jon, in chat, 2026-10-19). This file
records the standing ADR-0049 approval that follows from that request, so the remaining Phase 3
and Phase 4 beads do not stop for each test path. A decision Jon later reverses gets a new ADR or
bead, as usual.

## std-2026-10-19: test re-bases and subject-deleted retirements for Phases 3-4

- Question: may Phase 3 and Phase 4 beads (labels phase:3, phase:4) change tests as the
  Objective-C language and runtime are removed (CLAUDE.md rule 2, ADR-0049)?
- Decision: a standing approval, scoped to exactly two kinds of change:
  1. **Re-base, expectations kept.** A test's spelling follows the code it tests: imports and
     includes, link lists in meson.build, stand-ins/fakes re-based from Objective-C to C++ giving
     the same answers, `@autoreleasepool` to `oo::AutoreleaseScope`, Objective-C exceptions to
     `oo::Exception`, selectors to names, `.mm` to `.cpp`, comments. Every case stays, and every
     input and expected value is unchanged.
  2. **Retire with the subject.** A whole test file or case may be retired only when its sole
     subject is code the same change deletes (for example the Objective-C root classes, libobjc2
     floor tests, a deleted category), and a C++ test of any surviving behaviour stays and passes.
- Not covered (still Jon's alone): changing any expected value or golden, weakening or deleting a
  check whose subject survives, quarantining a flaky test, and anything under `goldens/`.
- Mechanics: each use still needs one path line in `tools/retire-test-approvals.txt`, reason
  starting `std-2026-10-19:`, saying ONLY what changes, landed on `main` in its own commit before
  the change (a change that edits a listed test may not also edit that file). The bead lists the
  paths and cases.
- Delegation: Jon, 2026-10-19: "Please help me approve whatever is needed".

## 2026-10-20: ADR-0062 accepted; human decisions delegated to the orchestrator

- Jon, in chat 2026-10-20: "I approve ADR-0062. Also, you are an autonomous worker. I approve you
  working through human decisions whenever it makes sense to unblock you."
- ADR-0062 is Accepted. Its three rules are covered for Phase 4 beads the same way as
  std-2026-10-19: each use gets a path line in `tools/retire-test-approvals.txt`, reason starting
  `ADR-0062:`, landed on `main` in its own commit before the change.
- Human-assigned decisions (proposed ADRs, `human` beads) may be taken by the orchestrator on their
  recorded default (CLAUDE.md rule 10), each recorded here with Jon's quote. Goldens (rule 1) and
  re-blessing remain Jon's alone.
