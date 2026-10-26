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
- oo-31u.9 (batch BF): the two scope-less `oo::autorelease` calls (OOTexture::clearCache, the uncached sound)
  keep upstream's semantics: released at the drain of the nearest enclosing `oo::AutoreleaseScope`, which
  oo-31u.8 already opened where upstream's pools were; no new owner, no new scope (ADR-0056 amendment
  oo-31u.9). Jon: "I approve you working through human decisions whenever it makes sense to unblock you."
- oo-dbz (batch BH, BG's open question (b)): the by-name "has no signature a by-name call can use (type encoding ...)"
  log line stays byte-identical, so each `@encode()` becomes the literal clang's `@encode()` measured on main
  eae8c876d, generated, never hand-pasted: `tools/type-encodings.tsv` (the measurement) renders
  `upstream/oolite/src/Core/OOTypeEncodings.h` (`kOOTypeEncoding<T>`) through `tools/gen-type-encodings.py`, whose
  `--check` keeps them in step (bead oo-dbz.3, ADR-0056 amendment oo-dbz.2/.3/.4). Jon: "I approve you working
  through human decisions whenever it makes sense to unblock you."
- oo-ebds4 (batch BI): tools/check-selector-types.py, its probe and data files retire (no Objective-C
  selector is left to check, ADR-0043 Amendment 4); libobjc2 and gnustep-make stay in
  tools/setup-windows.sh, documented as the GNUstep reference tools' dependencies only, because a
  documented reference tool, the capture script under tools/captures/plist-description, needs them. Jon: "I approve
  you working through human decisions whenever it makes sense to unblock you."
- oo-r3ffn item 5 (ADR-0063, GCC goldens): orchestrator decision, 2026-10-21. Where one call's
  arguments draw more than one random number (e.g. `make_vector(randf()-0.5f, randf()-0.5f,
  randf()-0.5f)`), each draw moves into a local variable in the order Clang evaluates them today, so
  the Clang build is unchanged and GCC reproduces the same goldens. This applies to the plain-C
  bodies in OOVector.cpp/OOHPVector.cpp too: making an unspecified evaluation order explicit is a
  portability fix, not a rewrite (rule 9 forbids converting C, not fixing it); no other line of those
  bodies changes. No golden is re-blessed. Jon: "I approve you working through human decisions
  whenever it makes sense to unblock you."
- oo-r3ffn item 4 (ADR-0063, GCC-only -Werror false positives in two oofnd tests): orchestrator
  decision, 2026-10-21. Those tests keep -Werror under Clang; under GCC they build without -Werror,
  so the warnings still print in the log (no -Wno-*, no pragma, no attribute: rule 3 holds). The
  GCC false positives are listed in ADR-0063 item 3 for a later GCC upgrade to re-check. Jon: "I
  approve you working through human decisions whenever it makes sense to unblock you."
- oo-4d403 (proposed ADR-0064, GCC spelling of __PRETTY_FUNCTION__): orchestrator decision,
  2026-10-21, on the recorded default. The four checks that pin the compiler's spelling of
  `__PRETTY_FUNCTION__` (test_OOJSConsole.cpp ~623/639, test_objc_assert.cpp ~70/74) keep Clang's
  expected strings byte-identical; under GCC (`#if defined(__GNUC__) && !defined(__clang__)`) they
  expect GCC's spelling of the same function. No check is removed or loosened, and the game does
  not change; each check still pins one exact string per compiler. Approval lines cite ADR-0064.
  Jon: "I approve you working through human decisions whenever it makes sense to unblock you."

## 2026-10-25: upstream-sync test expectations (oo-p6rtw, oo-1dcpm)

Both are changes std-2026-10-19 does not cover (an expected value; a check's threshold), so they
went to Jon as `human` beads with recorded defaults. Jon, in chat 2026-10-25: "yes, apply both".
Each has its path line in `tools/retire-test-approvals.txt`, landed on `main` before the change.

- oo-p6rtw: `test_string_expander.cpp` re-captures `kKeysDigest` and `kStringsDigest` from upstream
  #747's `descriptions.plist` (new key `oolite-keydesc-key_oxzmanager_copyurl`, four OXZ-manager help
  strings, "URL:" to "Info URL:"), to 0xea38daecff933503 / 0x338f336558c7db67 (were
  0x6349f869900cf779 / 0xef7448c0016ba2ed). The plist is the only input that changed: the same
  build run against the pre-sync plist (main 56603ca31) still gives the old digests. Nothing else
  about the check changes.
- oo-1dcpm: `test_live_captures_cost_what_a_game_launch_costs` lowers its floor from 5 s to 3.7 s.
  Upstream #744 lets the game quit on `quit()`, so a clean capture now measures 4.1 s (launch to
  console-ready 0.8 s, the rest ~3.25 s). A capture attached to a leftover game skips only the
  launch and would still spend the ~3.25 s, so the floor sits between the two and keeps failing that
  fake. Only the floor and its docstring change.
