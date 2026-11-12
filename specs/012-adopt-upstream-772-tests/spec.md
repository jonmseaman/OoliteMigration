# Feature Specification: Adopt upstream PR #772's tests to find migration bugs

**Feature Branch**: `012-adopt-upstream-772-tests` (in `oolite-dev`, based on `seriesb/025-libcurl-http`)

**Created**: 2026-11-12

**Status**: Draft (pilot run recorded below)

**Input**: User description: "Plan how you can integrate tests from this branch:
https://github.com/OoliteProject/oolite/pull/772. I would like to know if the js test framework can
be adopted in oolite-dev in my c++ code to enhance the test coverage to discover if my c++
migration introduced any other bugs." Then: "convert this to github speckit. You'll need a worktree
for doing the pilot, which should be based off the 025 seriesb branch."

## Purpose

Upstream's PR #772 adds tests that drive the real game and check what scripts can see and do. They
use only the debug console and the scripting API, not the C++ classes, so they run unchanged
against the C++ port. Their stored outputs come from upstream's Objective-C build. Any difference
between those outputs and the C++ build is either a migration bug or a known difference, and this
feature finds and sorts every one.

## Context

- **The seriesb stack is built on upstream's QuickJS-ng port** (#767, #768; spec 002). The
  scripting layer is upstream's binding, translated to C++. The C++ build and upstream's
  Objective-C build therefore use the *same* engine and the same binding logic, so a difference
  between them points at the ObjC → C++ translation rather than at the engine.
- **PR #772** (`hobleyd:test-harness`, open, head `12c39549e`, last updated 2026-11-08) is based on
  `master` and carries #768 inside its diff. Its own work is the last 18 commits,
  `7aad850b3`…`12c39549e`. The three #768 follow-ups it also includes (`51f4ddd02` global object
  converts to nil, `b9c9ed3e4` `Vector3D.toCoordinateSystem()`, `0701f8a17` deferred `quitGame()`
  with the leak-check log line and the `ooliteDefined` warning class) are already in
  `seriesb/025-libcurl-http`.
- **What #772 adds:**

  | Part | Files | Use here |
  |---|---|---|
  | In-game JavaScript tests: 69 tests over five phases (docked, flight, arrived after a jump, redocked, after a galactic jump), with an event-recorder OXP and a SpiderMonkey-compat OXP | `tests/js/`, `tests/oxp/`, `tests/run_js_tests.py`, `tests/oolite_harness.py` | adopt unchanged |
  | Parity probe: lists every scriptable property of the player ship, station, a spawned ship, the system and the player; flies through a jump, docking and a galactic jump; sweeps every script method with a wrong `this`, on a removed ship and with 8 kinds of bad argument | `tools/js-parity/` (replaces #768's older probe already in seriesb) | adopt unchanged |
  | Stored outputs: `baseline-quickjs.txt` (Linux x86-64), `baseline-quickjs-macos.txt`, the SpiderMonkey ones, `expected-differences.txt`, `noise.txt` | `tools/js-parity/` | the reference this feature compares with |
  | Longer smoke test: fire a missile at an asteroid, dock with the docking computer | `tests/launch_snapshot.py` | the fork has its own `launch_snapshot.py`; carry the two checks over as component scenarios instead |
  | Engine unit tests (`quickjs-poc`) built by `mk.sh` | `src/Core/Scripting/poc`, `mk.sh` | seriesb already has the harness; wiring it into `tests/run.sh unit` is in scope |
  | Downloaded OXPs: `fetch_oxps.py`, `test-oxps.txt`, nightly `oxp_corpus.py` | `tests/`, `tools/js-parity/` | out of scope (Hard rule 4) |
  | CI workflows | `.github/workflows/` | out of scope (the fork's CI is separate work) |

- **What the fork already tests:** unit suites, Gherkin component scenarios over the debug console
  (each scenario on its own port), PyAutoGUI GUI tests, a smoke snapshot, and a parity audit of
  ~170 suspected differences in `docs/parity/`. Nothing in the fork compares script-visible
  behaviour against upstream's build automatically.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Jon compares the C++ build's script-visible behaviour with upstream's (Priority: P1)

Jon runs one command on Windows against a seriesb build. The game starts, the probe flies its
route and sweeps every script method, the game quits, and the command prints the lines that differ
from upstream's stored output, each sorted as engine difference, platform noise, or suspected
migration bug.

**Why this priority**: This is the question that was asked: did the migration introduce bugs the
existing tests miss? The method sweep reaches every native binding, including error paths no
existing test covers.

**Independent Test**: `tools/js-parity/run_probe.py build/meson_test/oolite.app out.txt --check-leaks`
finishes, then `tools/js-parity/compare.sh tools/js-parity/baseline-quickjs.txt out.txt` prints a
diff; every differing line appears in the triage record with a class.

**Acceptance Scenarios**:

1. **Given** a `test` build of the feature branch, **When** Jon runs the probe, **Then** it reaches
   `ready for external quit`, the game exits, and the runtime reports no leaked objects.
2. **Given** a probe output, **When** it is compared with `baseline-quickjs.txt`, **Then** every
   differing line is recorded in `triage.md` as *engine*, *platform*, *noise* or *migration*.
3. **Given** a line classed *migration*, **When** Jon reads its entry, **Then** it names the
   method, the upstream source line and the C++ source line, and links the task that fixes it.

---

### User Story 2 - Jon runs the in-game JavaScript tests as a test tier (Priority: P1)

Jon runs `tests/run.sh js`. The game moves through the five phases and every test reports pass or
fail with its message.

**Why this priority**: The 69 tests check behaviour over time (events in order, timers, frame
callbacks, coordinate round trips, a hyperspace and a galactic jump), which the probe's snapshot
does not.

**Independent Test**: `tests/run.sh js` exits 0 when all tests pass and nonzero, naming the failing
tests, when any fail or the log shows a script exception, a time-limit kill or a leak.

**Acceptance Scenarios**:

1. **Given** a `test` build, **When** Jon runs `tests/run.sh js`, **Then** all five phases run and
   69 results are printed.
2. **Given** a failing test, **When** the run ends, **Then** the failure is recorded in
   `triage.md` with a class, and a *migration* failure gets a fix task; the test is not edited.

---

### User Story 3 - Each migration bug the tests find is fixed with a test (Priority: P2)

For each *migration* entry, the fix lands on its own branch in the series with a test that fails
before and passes after: the imported test or probe line itself, or a unit or component test where
that is narrower.

**Why this priority**: Finding bugs is the point; fixing them follows, but each fix is its own
small change.

**Independent Test**: For each fix, the probe line or JS test that exposed it matches the
reference after the fix and not before.

---

### User Story 4 - The smoke test's missile and docking checks run in the fork (Priority: P3)

Two component scenarios: the player fires a missile at an asteroid and has one fewer missile; the
docking computer docks the player at the main station.

**Why this priority**: Useful coverage of combat and autopilot code that the migration rewrote, but
narrower than stories 1 and 2.

**Independent Test**: `tests/run.sh component -k missile` and `-k docking_computer` pass.

---

### User Story 5 - Jon brings in later versions of #772 cheaply (Priority: P3)

When #772 changes upstream, Jon re-imports its files from the new commit and sees only the
upstream changes plus the fork's short list of local adaptations.

**Independent Test**: Re-importing the pinned commit produces no diff; the adaptation ledger lists
every file that differs from upstream, with its reason.

### Edge Cases

- **No Windows baseline.** Upstream stores Linux x86-64 and macOS arm64 outputs only. Lines that
  differ only by float formatting, path separators or timing are *platform*, recorded once in
  `windows-noise.txt` in this feature, never in upstream's `noise.txt`.
- **Fixed console port.** The probe and the JS tests use port 8563; the component tier gives each
  scenario its own port. These tiers run one at a time and never alongside the GUI tier.
- **The game hangs or crashes mid-run.** The runner times out (scaled by
  `OOLITE_TEST_TIMEOUT_SCALE`), kills the game, keeps the log and the partial output, and exits
  nonzero.
- **Test OXPs.** `tests/oxp/` and `oojs_probe.oxp` are upstream's own test fixtures, committed in
  source, not downloaded expansions. They are treated as test code (decision D2).
- **A test is wrong for the fork.** If a test fails because the fork *intentionally* differs (a
  documented known difference), it is recorded as such in `triage.md`; the test is not edited
  (Hard rule 1) and Jon decides.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The feature MUST import the #772 files listed as "adopt unchanged" from one pinned
  upstream commit (now `12c39549e`), byte-identical, in a single commit whose message names the
  commit.
- **FR-002**: Every file that must differ from upstream to run on the fork MUST be listed in
  `adaptations.md` with its reason. Adaptations go in new files or in the fork's runner where
  possible, not in the imported files.
- **FR-003**: `tests/run.sh` MUST gain `js` and `parity` tiers that run the JS tests and the probe
  against `build/meson_${BUILD_TYPE}/oolite.app`, exit nonzero on any failure, script exception,
  time-limit kill or leak, and keep the log and outputs under `build/test-output/`.
- **FR-004**: The `parity` tier MUST compare against `baseline-quickjs.txt` (same engine, Linux)
  after filtering upstream's `noise.txt`, `expected-differences.txt` and this feature's
  `windows-noise.txt`, and fail on any remaining difference.
- **FR-005**: `js` and `parity` MUST NOT join `tests/run.sh all` until `triage.md` classes every
  difference and failure (so the phase exit gate does not go red on untriaged results).
- **FR-006**: `triage.md` MUST record every differing probe line and every failing JS test with a
  class (*engine*, *platform*, *noise*, *migration*, *known difference*), the evidence, and for
  *migration* the upstream and C++ source locations and the fixing task.
- **FR-007**: Imported tests and stored outputs MUST NOT be edited to make them pass (Hard rule 1).
  Adding lines to upstream's `noise.txt` or `expected-differences.txt` is not allowed; Windows
  noise goes in `windows-noise.txt`, and each line there needs Jon's sign-off in `triage.md`.
- **FR-008**: The `quickjs-poc` engine unit tests MUST run in `tests/run.sh unit` if they build on
  Windows; if they don't, `triage.md` records why.
- **FR-009**: The missile and docking-computer checks MUST be component scenarios in the style of
  `s1_police_kills_pirate.feature`.
- **FR-010**: Nothing in this feature MUST download or read third-party expansion content
  (Hard rule 4): `fetch_oxps.py`, `test-oxps.txt` and `oxp_corpus.py` are not imported.

### Key Entities

- **Probe output**: one line per property, event or swept method, as `run_probe.py` writes it.
- **Reference**: upstream's stored probe output for a platform (`baseline-quickjs*.txt`).
- **Triage record** (`triage.md`): one entry per differing line or failing test, with class,
  evidence and outcome.
- **Adaptation ledger** (`adaptations.md`): every fork-side change needed to run the imported files.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe and the JS tests each complete on Windows against a `test` build in under
  5 minutes, with no leaked JavaScript objects.
- **SC-002**: 100% of differing probe lines and failing JS tests are classed in `triage.md`.
- **SC-003**: Every *migration* entry has a fix whose test fails before and passes after.
- **SC-004**: After the fixes, `tests/run.sh parity` and `tests/run.sh js` pass and are part of
  `tests/run.sh all`.
- **SC-005**: Re-importing #772 at the pinned commit produces no diff outside the files listed in
  `adaptations.md`.

## Assumptions

- The pilot and the feature branch are based on `seriesb/025-libcurl-http`, the newest seriesb
  step with a verified tree; the result can be rebased later in the stack.
- Upstream's Linux QuickJS output is a good enough reference for Windows once platform noise is
  filtered; a Windows reference from upstream's Objective-C build would need a GNUstep toolchain
  (decision D1).
- The `test` build type has the debug console, which both runners need.

## Decisions

Defaults taken under Hard rule 8; Jon may overturn any of them.

- **D1 — Reference.** Compare with `baseline-quickjs.txt`, not the SpiderMonkey baselines and not a
  newly generated Windows reference. Same engine and binding, so differences isolate the
  translation. *Why:* building upstream's Objective-C game on Windows needs GNUstep, which the
  fork has removed (Hard rule 6).
- **D2 — Test OXPs.** `tests/oxp/` and `tools/js-parity/oojs_probe.oxp` are upstream test
  fixtures and count as test code, not expansion content. *Why:* they are committed source, written
  as tests, and contain no third-party content; Hard rule 4 is about untrusted downloads.
- **D3 — Smoke test.** Keep the fork's `launch_snapshot.py`; carry #772's two new checks over as
  component scenarios. *Why:* the two files diverge by ~700 lines; component scenarios are the
  fork's exemplar for game-driving checks.
- **D4 — Branch.** `seriesb/028-upstream-772-tests`, from `seriesb/025-libcurl-http`: the import,
  then one commit per fix. *Why:* Jon (2026-11-12) made it a series step because it produced a fix;
  027 is already taken (`027-modern-cpp`, `027-ship-library-keys`), and nothing in it needs 026 or
  027.

## Pilot

Run 2026-11-12 in a worktree of `oolite-dev` at `.agent-tmp/wt-772` (branch
`012-adopt-upstream-772-tests`, since renamed `seriesb/028-upstream-772-tests`, from `seriesb/025-libcurl-http` at `ab6ac68b3`), `test` build,
Clang, Windows 11, with the #772 files imported unchanged.

Answer to the original question: **yes, the framework runs on the C++ build without changing a
single imported file**, and it has already found one class of migration difference.

- **JS tests**: 69 of 69 pass in all five phases, with the leak check and no unexpected script
  errors. About 7 s of game time at 16x, under a minute in all.
- **Probe**: runs to the end in about 30 s, no leaked objects, deterministic between Windows runs.
  37 of 1,100 lines differ from upstream's Linux output:
  - 31 are the AddOns path written with `/` instead of `\` (runner adaptation A2);
  - 1 is the shipyard's ship list, which differs between upstream's own Linux and macOS outputs
    too (platform, unconfirmed: follow-up F1);
  - 1 is `"government" in system.info`, a documented fork difference;
  - **4 are a migration difference**: `setMaterials`, `setShaders`, `markSystem` and `unmarkSystem`
    accept an array where upstream threw. Upstream sends a dictionary method to an Objective-C
    array, which raises an exception; `oo::PList::get` returns the default instead. Jon chose to
    match upstream; fixed with a component test (triage run 2).

Details, evidence and proposed outcomes are in [triage.md](triage.md); fork-side changes needed to
run the files are in [adaptations.md](adaptations.md). Implication for scope: the parity tier
and JS tier can join `tests/run.sh all` as soon as A2 is in and Jon has decided triage rows 3 and 4
(SC-004), and the probe's single wrong-type argument is too narrow to find every case of the
row-4 pattern (follow-up F2).

Pilot outputs (not committed): `.agent-tmp/pilot-772/` in OoliteMigration.
