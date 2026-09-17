#!/usr/bin/env python3
"""Generate the beads for Phases 0-4: one epic per phase, small frontier seam tasks, and one fleet
bead per file for every sweep, derived from the upstream tree. Idempotent by title: re-running
creates only what is missing. Dependencies keep sweep beads out of `bd ready` until their exemplar
seam and the previous phase's gate are closed.

  tools/gen-stories.py --dry-run      # counts, no writes; plan written to build/gen-stories-plan.json
  tools/gen-stories.py --apply        # bd create --graph <plan> (one call), then wire deps to pre-existing beads
  tools/gen-stories.py --apply --phase 3

Acceptance commands live in the bead body under "## Acceptance" (graph plans cannot set the
acceptance field); the beads-worker scripts read them from there.
"""
import argparse, json, os, re, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "upstream/oolite/src"
PROHIBITIONS = """## Prohibitions (verbatim in every story)
- Do not modify anything under `goldens/`.
- Do not modify or delete tests. If the test is wrong, stop and report. **Adding** a test is not prohibited and is expected where this unit changes observable behaviour: add a scenario under `upstream/oolite/tests/component/features/` using steps that already exist (`tests/component/README.md`). Needing a *new step* fails sizing check 5: stop and file a bead (ADR-0018).
- Do not add `-Wno-*`, `#pragma` diagnostic suppressions, or unused-attributes to silence a warning.
- Do not run `bd close`; the orchestrator's accept step does that after review.
- Do not read expansion (OXP/OXZ) content. If the task appears to need it, stop and report.
- Do not rewrite code that already compiles as C.
- Commit only on your worktree branch. Never push."""
SIZING = "Sizing: reads <= ~1,500 lines, writes <= ~400 lines, <= 8 files, no new interfaces, exemplar named. If it does not fit, stop and report which check fails."

# ---------------------------------------------------------------- bd helpers
def bd(*args, check=True):
    p = subprocess.run(["bd", *args], capture_output=True, text=True)
    if check and p.returncode != 0:
        raise SystemExit(f"bd {' '.join(args[:3])}... failed: {p.stderr.strip() or p.stdout.strip()}")
    return p.stdout.strip()

def existing_issues():
    out = subprocess.run(["bd", "list", "--all", "--json", "-n", "0"], capture_output=True, text=True).stdout
    try:
        return {x["title"]: x for x in (json.loads(out) or [])}
    except json.JSONDecodeError:
        return {}

def existing_titles():
    return {t: x["id"] for t, x in existing_issues().items()}

# Title changes and removals applied by --refresh before anything else (old title -> new title / None).
RENAMED = {
    "Define scenarios 13-20 (beyond the twelve named in the plan)": "Define scenarios 18-20 (beyond the seventeen named in the plan)",
    "Base image: GNUstep at pinned commits + mozillajs-linux 0.0.1, prebuilt": "tools/setup-windows.sh: MSYS2 UCRT64 provisioned once (deps, Mesa opengl32.dll, ccache, python)",
    "Parameterise tests/launch_snapshot.py: port, DISPLAY, output dir": "Parameterise tests/launch_snapshot.py: port, output dir, --load <save>",
    "Golden harness container: one scenario per container, Xvfb inside": "Golden harness runner: one scenario per native game process, Mesa llvmpipe, parameterised port",
    "tools/tier-c.sh: both legs, all goldens, ASan+UBSan, full Tier 1, JS API snapshot, GUI tier": "tools/tier-c.sh: all goldens, ASan, full Tier 1, JS API snapshot, GUI tier under the desktop lock",
    "QuickJS-ng vendored + built on both legs behind a meson option": "QuickJS-ng vendored + built behind a meson option",
    "Delete libgnustep-base from both legs; deny-list on": "Delete libgnustep-base from the build; deny-list on",
    "Phase 3 exit gate: zero @implementation; goldens; ASan; both legs clean": "Phase 3 exit gate: zero @implementation; goldens; ASan; build clean at -Wall -Wextra",
    "Restore the GCC build on Linux alongside Clang": "GCC (MINGW64) build alongside the Clang (UCRT64) build",
    "tools/build-linux.sh: clean-clone Linux build in WSL2 matching upstream's workflow": None,   # ADR-0017: Linux joins at Phase 5
    "Exercise the cross-platform golden policy Linux vs Windows before any arm64 exists": None,  # moved to Phase 5
    "tools/merge-queue: batch Tier-B-green branches, run tier-c locally, fast-forward, bisect on red": "tools/merge-queue: batch Tier-B-green branches, run tier-c locally, fast-forward, bisect on red, push",
    "tools/tier-b.sh: one-platform build + module tests + 3-5 fast goldens + Tier-1 subset, under 10 min": "tools/tier-b.sh: build + module tests + 3-5 fast goldens + fast component subset + Tier-1 subset, under 10 min",
}

def refresh():
    """Apply RENAMED, then rewrite the description/metadata of every existing bead whose generated text changed.
    Dependencies are only added (run with --apply --rewire afterwards); removed deps must be dropped by hand."""
    issues = existing_issues(); changed = 0
    for old, new in RENAMED.items():
        x = issues.get(old)
        if not x: continue
        if new is None:
            if x["status"] != "closed":
                bd("delete", x["id"], "--force"); print(f"deleted {x['id']}: {old}")
            issues.pop(old, None); continue
        bd("update", x["id"], "--title", new, "-q"); print(f"renamed {x['id']}: {new}")
        issues[new] = issues.pop(old)
    wanted = {}
    for key, n, title, desc, acc, dk, pri in SEAMS:
        wanted[title] = (seam_body(key, n, title, desc, acc), None)
    for skey, n, gen in SWEEPS:
        items, presplit = (sweep_convert() if skey == "convert" else (gen(), []))
        for title, desc, acc, dk, exemplar, pri in items: wanted[title] = (body(desc, acc, exemplar, skey, n), exemplar)
        for title, desc, acc, dk, exemplar, pri in presplit:
            wanted[title] = (body(desc, [], exemplar, "presplit", n, prose="Slice plan in the bead notes; each slice reads under 1,500 lines."), None)
    for title, (text, exemplar) in wanted.items():
        x = issues.get(title)
        if not x or x["status"] == "closed": continue
        if (x.get("description") or "").strip() == text.strip(): continue
        args = ["update", x["id"], "--description", text, "-q"]
        if exemplar: args += ["--metadata", json.dumps({"exemplar": exemplar})]
        bd(*args); changed += 1
    print(f"refreshed {changed} bead descriptions")

# ---------------------------------------------------------------- inventory
def count_lines(p): 
    try: return sum(1 for _ in open(p, errors="replace"))
    except OSError: return 0

def grep(p, pat):
    try: return re.search(pat, open(p, errors="replace").read()) is not None
    except OSError: return False

def m_files():
    return sorted(SRC.rglob("*.m"))

GIANT = {"ShipEntity.m", "PlayerEntity.m", "Universe.m", "PlayerEntityControls.m", "HeadUpDisplay.m", "OOJSShip.m"}

def module_of(p: Path):
    rel = p.relative_to(SRC).as_posix()
    if rel.startswith("Core/Materials/"): return "materials"
    if rel.startswith("Core/OXPVerifier/"): return "oxpverifier"
    if rel.startswith("Core/Scripting/"): return "scripting"
    if rel.startswith("Core/Entities/"): return "entities"
    if rel.startswith("Core/Debug/"): return "debug"
    if rel.startswith("SDL/"): return "platform"
    if p.name.startswith(("OOAL", "OOSound", "OOMusic")): return "audio"
    return "leaf"

MODULE_ORDER = {"leaf": 1, "oxpverifier": 1, "materials": 2, "audio": 2, "debug": 2, "scripting": 3, "entities": 3, "platform": 3}
MODULE_SEAM = {"leaf": "3.exemplar-oocolor", "oxpverifier": "3.exemplar-oxpverifier", "materials": "3.pattern-materials",
               "audio": "3.pattern-audio", "debug": "3.pattern-debug", "scripting": "3.pattern-scripting",
               "entities": "3.pattern-entities", "platform": "3.pattern-platform"}

def header_for(p: Path):
    h = p.with_suffix(".h")
    return h if h.exists() else None

# ---------------------------------------------------------------- content
PHASES = {
    0: ("Safety net", "docs/phases/0-safety-net.md"),
    1: ("JS engine replacement (De-Mozilla)", "docs/phases/1-js-engine.md"),
    2: ("oofnd — Foundation replacement", "docs/phases/2-oofnd.md"),
    3: ("Objective-C → C++20 conversion", "docs/phases/3-cpp-conversion.md"),
    4: ("Remove the Objective-C runtime", "docs/phases/4-remove-objc-runtime.md"),
}

# Seams: key, phase, title, description, acceptance, deps (keys), priority. Small steps.
SEAMS = [
 # ---- Phase 0
 ("0.1a", 0, "Instrument NSDictionary/NSSet enumeration order shuffle (debug build)", "Add a debug-only shuffle of GNUstep NSDictionary/NSSet enumeration order behind an env var so order-dependent gameplay paths can be found. No behaviour change when the env var is unset.", "Debug build with OO_SHUFFLE_ENUMERATION=1 launches and reaches the main menu; without it, byte-identical behaviour to before.", [], 1),
 ("0.1b", 0, "Find and fix iteration-order-dependent gameplay paths; upstreamable", "Run the smoke test and the first scenarios under the shuffle; sort explicitly in Objective-C at every site where the outcome changes. Prime suspects: populator scripts, role selection, ship registry, equipment ordering.", "Ten consecutive shuffled runs of the smoke test produce identical Latest.log gameplay lines; each fix is a separate commit suitable for an upstream PR.", ["0.1a"], 1),
 ("0.13a", 0, "OO_RANDOM_SEED: honour an env var seed in GameController (determinism fix, upstreamable)", "src/Core/GameController.m:100 seeds RANROT from the wall clock. When OO_RANDOM_SEED is set, seed from it; otherwise unchanged. ~3 lines. Prerequisite of the component tier (0.13b) and of the goldens (0.4): neither can be deterministic without it (ADR-0018 §3).", "Two launches with OO_RANDOM_SEED=20260910 produce identical randf() sequences (log the first 5 draws under OOLog 'debug.random' in a debug build); without the variable, behaviour is unchanged.", [], 1),
 ("0.13b", 0, "Component tier seam: tests/component console client, launch fixture, step library, and S1", "Per docs/stories/S1-police-kills-pirate.md and docs/phases/0-component-tier.md: pytest + pytest-bdd under upstream/oolite/tests/component/ (console.py shared with the golden harness later, conftest.py with seed injection and hard timeout, steps/world_steps.py, features/s1_police_kills_pirate.feature, requirements.txt, README.md step catalogue). Headless, one native game process, parameterised port, OO_RANDOM_SEED set. No new native interfaces.", ["python3 -m pytest upstream/oolite/tests/component/ -x -q", "for i in 1 2 3 4 5; do python3 -m pytest upstream/oolite/tests/component/ -x -q || exit 1; done"], ["0.13a", "0.3b"], 1),
 ("0.2", 0, "tools/setup-windows.sh: MSYS2 UCRT64 provisioned once (deps, Mesa opengl32.dll, ccache, python)", "Script the one-time provisioning that upstream's workflow repeats per run: ShellScripts/Windows/install_deps.sh clang, mingw-w64-ucrt-x86_64-mesa (the llvmpipe opengl32.dll the goldens use), ccache, python with pytest/pytest-bdd/pyautogui, jq. Idempotent. See docs/infra/1-base-images.md.", "Run twice on the Windows machine: the second run installs nothing; ./mk.sh build test succeeds afterwards.", [], 1),  # provisions pytest-bdd too
 ("0.3b", 0, "tools/build-windows.sh: native MSYS2 UCRT64 build from a clean clone", "Script the Windows build from a clean clone with MSYS2 provisioned by 0.2 (no setup-msys2 step); same flavours as upstream build-all.yaml; ccache on.", "tools/build-windows.sh exits 0 from a fresh clone on the Windows machine and produces the test binary.", ["0.2"], 1),
 ("0.4a", 0, "Parameterise tests/launch_snapshot.py: port, output dir, --load <save>", "Today PORT=8563 and HOST are hardcoded. Make port and artifact directory arguments/env so N instances run at once; add --load <file.oolite-save>, passed through as the game's -load argument (scenarios 013-017 load the checklist saves).", "Two instances run concurrently on different ports and both produce a screenshot; --load with a checklist save reaches the docked screen.", ["0.3b"], 1),
 ("0.4b", 0, "Golden harness runner: one scenario per native game process, Mesa llvmpipe, parameterised port", "tests/golden/run.sh <scenario>: launches one game process natively with MSYS2's Mesa opengl32.dll beside the binary (as upstream/oolite/tests/run_test_fn.sh does), drives it over the debug-console TCP channel on its own port using the component tier's console client (tests/component/console.py, ADR-0018), writes artifacts to a per-run directory. No containers (ADR-0017).", "N scenarios (N = the RAM budget in docs/infra/0-machines.md, at least 4) run concurrently on the machine with no port or output collision.", ["0.4a", "0.13b"], 1),
 ("0.4c", 0, "Canonical state dump: sorted JSON of entities, positions, velocities, AI states, market, player", "A debug-console JS command that serialises the world after N ticks to canonical sorted JSON; float fields quantised per decision 11.", "Two runs of the same scenario on the same build produce byte-identical dumps.", ["0.4b"], 1),
 ("0.4d", 0, "Frame hashes with tolerance at fixed camera positions", "Perceptual hash of rendered frames at fixed camera positions; tolerance documented; llvmpipe pinned as the rasteriser.", "Same scenario, two runs: hashes within tolerance; a deliberately moved ship changes the hash beyond tolerance.", ["0.4b"], 2),
 ("0.4e", 0, "Golden storage policy: per-platform goldens + quantised floats; -ffp-contract=off; pinned -O", "Implement decision 11: goldens/<platform>/<scenario>/ layout (windows-x64 first; macos-arm64 and linux-x64 join at Phase 5), quantisation in the dump, golden build flags pinned.", "Windows goldens for scenario 001 stored under goldens/windows-x64/; a diff tool reports zero differences between two runs after quantisation.", ["0.4c"], 1),
 ("0.4f", 0, "Scenario 001 launch/dock: script, bless, 10-run stability", "The first golden scenario and the exemplar for all others: fixed seed (OO_RANDOM_SEED, 0.13a), fixed system, fixed tick count, dump + frame hash, blessed under the policy.", "10 consecutive runs reproduce the golden byte-for-byte on Windows.", ["0.4e", "0.13a"], 1),
 ("0.4g", 0, "Define scenarios 18-20 (beyond the seventeen named in the plan)", "Name the remaining scenarios so the list reaches 20 with broad coverage (equipment, station services, NPC AI states, HUD modes, etc.). Output: a list with one line each, added to docs/phases/0-safety-net.md.", "docs/phases/0-safety-net.md lists 20 scenarios with a one-line purpose each.", ["0.4f"], 2),
 ("0.5", 0, "JS API conformance snapshot: oxp-contract/js-api-1.93.json", "Via the debug console enumerate all 61 JS globals and every native class's properties, methods, arities and types; commit; add a check that regenerates and diffs.", "tools/js-api-snapshot.sh regenerates the file and `git diff --exit-code` passes on the current build.", ["0.4a"], 1),
 ("0.6a", 0, "OXP corpus: fetch and cache the catalog (818 unique URLs) with checksums", "Download every expansion from upstream/oolite-expansion-catalog into a local cache with a manifest of checksums; resumable.", "Manifest lists every URL with size and sha256; a second run downloads nothing.", [], 2),
 ("0.6b", 0, "OXP corpus Tier 1 list (~30 most-installed + 6 test-oxps) and per-commit runner", "Choose Tier 1, script loading each on a headless build and asserting no ERROR lines in Latest.log.", "tools/corpus.sh tier1 exits 0 on the current build.", ["0.6a", "0.4a"], 1),
 ("0.6c", 0, "OXP corpus Tier 2 (~150, category coverage) and Tier 3 (all) runners", "Nightly (Tier 2) and weekly (Tier 3) load-only smoke runs with clustered error reports.", "tools/corpus.sh tier3 completes and writes a report grouping failures by first error line.", ["0.6b"], 2),
 ("0.7a", 0, "Mozilla-only-JS static scan: ESLint config + runner over the corpus", "tools/oxp-js-lint flags for each, catch-if, E4X, .quote(), toSource, uneval, let blocks, legacy getters, expression closures.", "Runs over the whole cached corpus and writes a per-expansion report; zero hits on the 31 in-tree scripts.", ["0.6a"], 1),
 ("0.7b", 0, "Expansion-scan model pilot: classify ambiguous hits with a local model, hand-audit 50", "Sandboxed (no repo mount, no secrets): local model classifies the lint's ambiguous hits; a random 50 are hand-audited and the agreement rate recorded in docs/fleet/LEARNINGS.md.", "Report published with agreement rate; sandbox verified to have no repo write access.", ["0.7a"], 3),
 ("0.8a", 0, "GUI tier: row->screen-point helper, launch/kill fixture, and G1 exit-via-mouse", "The calibration seam: upstream/oolite/tests/gui/conftest.py and test_g1_exit_via_mouse.py per docs/stories/G1-exit-via-mouse.md. Runs against a real window on the desktop and takes the GUI-tier desktop lock (tools/gui-lock, created here) while it runs.", "python3 -m pytest upstream/oolite/tests/gui/test_g1_exit_via_mouse.py -x -q passes natively on Windows with the desktop unlocked.", ["0.3b"], 1),
 ("0.9a", 0, "tools/tier-a.sh <file>: single-TU compile + clang-tidy + deny-list, under 30 s, offline", "The agent inner loop. Compile one translation unit via meson/ninja target, run clang-tidy on it, grep the deny-list; measure on OOColor.m and OORoleSet.m.", "tools/tier-a.sh upstream/oolite/src/Core/OOColor.m completes in under 30 s with the network disabled.", ["0.3b"], 1),
 ("0.9b", 0, "tools/tier-b.sh: build + module tests + 3-5 fast goldens + fast component subset + Tier-1 subset, under 10 min", "Runs in a clean worktree; headless (no GUI tier); includes the tagged fast subset of the component tier (pytest -m fast under tests/component, ADR-0018); `--fast` variant for accept.sh.", "tools/tier-b.sh exits 0 on main in under 10 minutes on a warm cache.", ["0.9a", "0.4f", "0.6b"], 1),
 ("0.9c", 0, "tools/tier-c.sh: all goldens, ASan, full Tier 1, JS API snapshot, GUI tier under the desktop lock", "The merge gate, run locally (ADR-0016) in a clean worktree on Windows: full component suite (ADR-0018), all goldens, corpus, snapshot, ASan. The GUI tier runs here and nightly only, under tools/gui-lock, never per bead (ADR-0017).", "tools/tier-c.sh exits 0 on main; a deliberate use-after-free in a scratch branch is caught by ASan under MSYS2 clang, or the ADR-0017 sanitizer fallback is filed as a proposed ADR.", ["0.9b", "0.5", "0.8a"], 1),
 ("0.10", 0, "tools/merge-queue: batch Tier-B-green branches, run tier-c locally, fast-forward, bisect on red, push", "Batch-and-bisect over local branches; requeues the culprit's bead with the failure in its notes. accept.sh's base branch becomes an integration branch this promotes. After every green batch: `git push origin main` and `git subtree push --prefix=upstream/oolite fork migration` (ADR-0017); the weekly hand-push bead is closed when this lands.", "A batch of 8 branches with one bad one: the queue bisects to the culprit and merges the other 7; after a green batch origin/main and fork/migration match the local tree.", ["0.9c"], 2),
 ("0.11", 0, "Guardrail checks: goldens/ protection, warning-suppression grep, deleted-test detection, deny-list", "tools/guardrails.sh run by tier-b and tier-c: fails on any change under goldens/ without a rebless approval, on new -Wno-/#pragma diagnostic, on deleted/emptied test files (including .feature files and the component step library, ADR-0018 §5), on reintroduced libgnustep-base/JS_* symbols.", "Each of the four violations, introduced in a scratch branch, fails tools/guardrails.sh with a specific message.", ["0.9b"], 1),
 ("0.12", 0, "Verify story generator output against the first real sweep (Phase 1 façade retarget)", "tools/gen-stories.py exists (v0). Once tier-a/tier-b exist, re-run with --apply and confirm the first generated bead is completable by a worker end to end through the beads-worker skill.", "One generated Phase 1 bead closed by accept.sh with no human edits to the bead text.", ["0.9b", "1.1"], 2),
 ("0.14", 0, "tools/fleet/run-story: frontier driver (claude -p --model claude-opus-5) over frontier beads", "bd ready filtered to frontier beads -> claim -> beads-worker worktree.sh -> claude -p --model claude-opus-5 with the bead body as the prompt and CLAUDE.md in scope, allow-list excluding bd close / git push / goldens -> accept.sh -> worktree cleanup. Memoryless per story; parallelism flag from docs/infra/0-machines.md. The frontier model is Claude Opus 5 by default (BEADS_FRONTIER_MODEL overrides); a bead whose metadata carries model=<id> runs on that model instead (the phase reviews use claude-fable-5-1).", "run-story given a scratch frontier bead with acceptance `test -f tools/fleet/.smoke` completes it in its own worktree and the bead is closed by accept.sh, not by the agent; `claude -p` was invoked with --model claude-opus-5 (logged).", [], 2),
 ("0.15", 0, "Reporter: scheduled read-only Claude Code task posting the I4 metrics", "A scheduled task (claude -p --model claude-opus-5, read-only tools) that reads bd, the tier logs, git and the goldens and writes docs/fleet/REPORT-<date>.md with every docs/infra/4-metrics.md daily metric (zeros allowed), including days since origin/main and fork/migration matched.", "One report file exists with every daily metric populated; the task holds no write authority beyond docs/fleet/.", [], 3),
 ("0.gate", 0, "Phase 0 exit gate: every item in docs/phases/0-safety-net.md checked", "Walk the exit-gate checklist; each unchecked item becomes a new bead. Close only when all are checked.", "All exit-gate boxes checked in docs/phases/0-safety-net.md with the commit that satisfied each.", ["0.1b","0.3b","0.4d","0.4g","0.6c","0.7b","0.10","0.11","0.13b","0.14","0.15"], 1),
 # ---- Phase 1
 ("1.1", 1, "Design ooscript/JSEngine.hpp façade against the JS_* call-site histogram", "Value, Context, Object, ClassDef, PropertySpec, FunctionSpec, rooted handles, exception plumbing; sized to what Oolite uses. Header + SpiderMonkey-backed implementation, no call sites moved yet.", "Header compiles; tools/tier-a.sh passes on the implementation file; a doc comment maps each of the top 20 JS_* functions to its façade call.", ["0.gate"], 1),
 ("1.1x", 1, "Retarget one binding file (OOJSVector.m) onto the façade as the exemplar", "The first retargeted file; every later retarget bead points here.", "! grep -nE '\\bJS_[A-Za-z]+' src/Core/Scripting/OOJSVector.m; tier-a passes; goldens unchanged (tier-b).", ["1.1"], 1),
 ("1.2", 1, "clang-refactor scripts for the stub/init and numeric-conversion JS_* patterns", "tools/refactor/js-stubs.sh covering JS_PropertyStub/ResolveStub/ConvertStub/EnumerateStub/InitClass and JS_NewNumberValue/ValueToNumber/ValueToBoolean (~40% of sites).", "Script applied to one file produces a diff identical to the hand-retargeted exemplar for those patterns.", ["1.1x"], 1),
 ("1.4a", 1, "QuickJS-ng vendored + built behind a meson option", "Add QuickJS-ng as a subproject; build with -Djs_backend=quickjs; nothing wired yet.", "meson configure -Djs_backend=quickjs builds libquickjs on Windows (UCRT64).", ["1.1"], 1),
 ("1.4b", 1, "QuickJS-ng backend: Context/Value/Object/ClassDef with exotic-method mapping", "Implement the façade over QuickJS-ng; JSClass resolve/enumerate → JSClassExoticMethods; private pointer attach.", "Façade unit tests pass on both backends.", ["1.4a"], 1),
 ("1.4c", 1, "Rooting/GC handles and exception plumbing on the QuickJS-ng backend", "Rooted handles map to QuickJS GC semantics; JS exceptions ↔ C++ exceptions per the façade contract.", "Façade unit tests for rooting and exceptions pass on both backends; ASan clean.", ["1.4b"], 1),
 ("1.5a", 1, "tools/tier-c.sh --backend=<sm|quickjs>: differential run of goldens and corpus", "Run everything on both backends and produce a divergence report.", "Report lists every golden/corpus divergence with the first differing line.", ["1.4c", "0.9c"], 1),
 ("1.6a", 1, "docs/EXPANSION_MIGRATION.md: removed SpiderMonkey syntax, newly strict, newly available", "Publish the guide from the plan's table plus the corpus scan results.", "Doc exists and links each construct to a replacement and to the lint rule that flags it.", ["0.7a"], 2),
 ("1.6b", 1, "Compatibility shim OXP polyfilling toSource/quote for abandoned expansions", "Loaded first; polyfills what can be polyfilled.", "Tier 3 failures attributable to toSource/quote drop to zero with the shim installed.", ["1.6a", "1.5a"], 3),
 ("1.7", 1, "Delete the SpiderMonkey backend, mozillajs-linux and nspr; enable JS_* deny-list", "Remove the old backend and dependencies; guardrails deny JS_* symbols from now on.", "No JS_* symbol in src/; builds; tier-c green on quickjs.", ["1.5a"], 1),
 ("1.gate", 1, "Phase 1 exit gate: goldens, corpus, JS API snapshot on QuickJS-ng; deny-list on", "Walk docs/phases/1-js-engine.md exit gate.", "All exit-gate boxes checked.", ["1.7", "1.6b"], 1),
 # ---- Phase 2
 ("2.1", 2, "The .m -> .mm switch: one atomic, behaviour-free commit (.m without @implementation -> .c)", "Rename, -x objective-c++, -std=c++20; fix the few hundred mechanical errors with the compiler as oracle. Per ADR-0012 files with no @implementation become .c with extern \"C\" guards.", "Builds; goldens unchanged (tier-b); zero .m files remain.", ["0.gate"], 1),
 ("2.2", 2, "oofnd: RefCounted, Ref<T>, WeakRef<T>, AutoreleaseScope with unit tests", "src/oofnd/Ref.hpp mirroring ObjC refcounting 1:1 (ADR-0003); replaces OOWeakReference/OOWeakSet semantics.", "meson test --suite oofnd passes; ASan clean.", ["2.1"], 1),
 ("2.9", 2, "oofnd: oo::Expected<T,E> polyfill with std::expected's API", "ADR-0011: small polyfill or vendored tl::expected; used by every oofnd error path.", "Unit tests pass; a canary TU compiles at -std=c++20.", ["2.1"], 1),
 ("2.3a", 2, "oofnd PList: value type (null/bool/int/double/string/data/date/array/dict) + tests", "The variant and its accessors; no parsing yet.", "meson test --suite oofnd-plist passes.", ["2.2", "2.9"], 1),
 ("2.3b", 2, "oofnd PList: old-style OpenStep scanner — strings and escapes", "Quoted/unquoted strings, \\U escapes, comments. Cases 1-14 in test_plist_oldstyle_strings.cpp.", "test_plist_oldstyle_strings cases go green.", ["2.3a"], 1),
 ("2.3c", 2, "oofnd PList: old-style OpenStep scanner — arrays, dicts, data, nesting", "Remaining old-style grammar with GNUstep quirks reproduced.", "test_plist_oldstyle_structures green.", ["2.3b"], 1),
 ("2.3d", 2, "oofnd PList: XML plist parser incl. ChangeDTDIfApplicable behaviour", "Reproduce OOPListParsing.m quirk-for-quirk.", "test_plist_xml green.", ["2.3a"], 1),
 ("2.3e", 2, "oofnd PList: old-style and XML writers", "writeOldStylePList (required by the expansion catalogue API) and writeXMLPList.", "Round-trip tests green; output byte-identical to OldSchoolPropertyListWriting.m on the fixtures.", ["2.3c", "2.3d"], 1),
 ("2.3f", 2, "oofnd PList: fuzz parser/writer against GNUstep on the OXP corpus", "Every plist in the cached corpus parsed by both; any difference is a bug.", "Zero divergences over the corpus; fuzz harness committed.", ["2.3e", "0.6a"], 1),
 ("2.4", 2, "oofnd PList::get<T> typed accessor + one migrated consumer as the exemplar", "Retire OOCollectionExtractors' oo_*ForKey shape with one template; migrate one small file completely.", "The migrated file has zero oo_*ForKey; tier-a passes; goldens unchanged.", ["2.3e"], 1),
 ("2.5a", 2, "Benchmark std::string vs NSString copying on golden wall-clock (decision 4, 5% threshold)", "Measure before/after on a representative migrated module; escalate via the Reporter only if regression > 5%.", "Numbers recorded in docs/fleet/LEARNINGS.md; decision confirmed or a proposed ADR filed.", ["2.4"], 2),
 ("2.5b", 2, "oofnd string utilities: OOStringParsing, OOStringExpander, OOEncodingConverter, NSString categories as free functions", "namespace oo::str; one migrated consumer as exemplar.", "Unit tests green; exemplar file has no NSString category calls.", ["2.5a"], 1),
 ("2.6", 2, "oofnd FileSystem, ResourcePaths, Data (retires NSFileManager/NSBundle/NSData usage)", "With one migrated consumer as exemplar.", "Unit tests green; exemplar migrated; tier-b unchanged.", ["2.2"], 1),
 ("2.7", 2, "oofnd Defaults (retires NSUserDefaults and the two Override categories)", "Same on-disk format so saves and prefs are untouched; exemplar consumer.", "Existing prefs file loads identically; unit tests green.", ["2.3e"], 1),
 ("2.8", 2, "oofnd Logging (retires OOLogging on NSLog)", "std::format-based oo::log; identical Latest.log line format.", "Latest.log from a golden run is byte-identical before/after.", ["2.5b"], 1),
 ("2.10", 2, "oofnd components complete: Ref, PList, get<T>, strings, FileSystem, Defaults, Logging all landed", "Aggregate gate for the Foundation sweep: closes when 2.2-2.8 are closed and their exemplar consumers are on main.", "All of 2.2, 2.3e, 2.4, 2.5b, 2.6, 2.7, 2.8 closed.", ["2.2", "2.3e", "2.4", "2.5b", "2.6", "2.7", "2.8"], 1),
 ("2.12", 2, "Delete libgnustep-base from the build; deny-list on", "Remove the dependency; only libobjc2 remains.", "Link lines contain no gnustep-base; tier-c green; guardrails deny it.", [], 1),  # deps wired to sweeps by generator
 ("2.gate", 2, "Phase 2 exit gate per docs/phases/2-oofnd.md", "Walk the exit gate.", "All boxes checked.", ["2.12", "2.3f"], 1),
 # ---- Phase 3 seams
 ("3.exemplar-oocolor", 3, "Convert OOColor to C++20 as the house-style exemplar", "First class conversion. Sets naming, header layout, Ref usage, error shape for every leaf story.", "! grep -nE '@implementation|@interface' src/Core/OOColor.mm src/Core/OOColor.h; tier-a passes; goldens unchanged.", ["1.gate", "2.gate"], 1),
 ("3.exemplar-oxpverifier", 3, "Convert the OXPVerifier base class + one stage as the hierarchy exemplar", "A real class hierarchy with its own test data; the remaining OXPVerifier files become fleet beads.", "The two files converted; verifier test data passes; tier-a passes.", ["3.exemplar-oocolor"], 1),
 ("3.pattern-materials", 3, "Materials module pattern: convert OOMaterial + OODrawable as the module exemplar", "Sets the pattern behind which the rest of Materials converts.", "Two files converted; tier-b unchanged.", ["3.exemplar-oxpverifier"], 2),
 ("3.pattern-audio", 3, "Audio module pattern: convert OOALSound as the module exemplar", "", "File converted; tier-b unchanged.", ["3.exemplar-oocolor"], 2),
 ("3.pattern-debug", 3, "Debug module pattern: convert OODebugMonitor as the module exemplar (the harness must keep working)", "", "File converted; golden harness still drives the game.", ["3.exemplar-oocolor"], 2),
 ("3.pattern-scripting", 3, "Scripting bindings pattern: convert one OOJS* class (OOJSVector) to C++20", "The façade already isolates the engine; this sets the binding-class shape.", "File converted; JS API snapshot unchanged.", ["3.exemplar-oxpverifier"], 3),
 ("3.pattern-entities", 3, "Entities pattern: convert Entity and OOEntityWithDrawable base classes", "The base of the hierarchy; everything under Entities depends on it.", "Both converted; goldens unchanged.", ["3.pattern-materials"], 3),
 ("3.pattern-platform", 3, "Platform (SDL/) pattern: convert one platform file", "", "File converted; GUI tier G1-G4 green.", ["3.exemplar-oocolor"], 3),
 ("3.upstream-delta", 3, "docs/UPSTREAM_DELTA.md and the per-module freeze policy in force", "Once conversion starts on a module, upstream changes to it are ported by hand and tracked here.", "File exists; the upstream-tracker task references it.", ["3.exemplar-oocolor"], 2),
 ("3.giant-ShipEntity", 3, "Convert ShipEntity (14,945 lines, 186 ivars, 565 methods) — frontier, category by category", "Not fleet work. Pre-split by existing category files; convert with the entity pattern.", "Zero @implementation in the ShipEntity files; goldens unchanged; ASan clean.", ["3.pattern-entities"], 4),
 ("3.giant-PlayerEntity", 3, "Convert PlayerEntity (13,718 lines, 10 category files) — frontier", "", "Zero @implementation in PlayerEntity*.mm; goldens unchanged.", ["3.giant-ShipEntity"], 4),
 ("3.giant-PlayerEntityControls", 3, "Convert PlayerEntityControls (5,690 lines) — frontier", "", "Converted; GUI tier green.", ["3.giant-PlayerEntity"], 4),
 ("3.giant-HeadUpDisplay", 3, "Convert HeadUpDisplay (4,497 lines, immediate-mode GL) — frontier", "", "Converted; frame hashes within tolerance.", ["3.pattern-entities"], 4),
 ("3.giant-OOJSShip", 3, "Convert OOJSShip (4,399 lines, largest JS binding) — frontier", "", "Converted; JS API snapshot unchanged.", ["3.pattern-scripting"], 4),
 ("3.giant-Universe", 3, "Convert Universe (11,297 lines, 122 ivars) — frontier, last", "Everything points at it; convert when nothing else is left.", "Zero @implementation in src/; goldens unchanged.", ["3.giant-PlayerEntityControls", "3.giant-HeadUpDisplay", "3.giant-OOJSShip"], 4),
 ("3.gate", 3, "Phase 3 exit gate: zero @implementation; goldens; ASan; build clean at -Wall -Wextra", "Walk docs/phases/3-cpp-conversion.md exit gate.", "grep -rc '@implementation' src is 0; all boxes checked.", ["3.giant-Universe"], 1),
 # ---- Phase 4
 ("4.1", 4, "Delete oo::AutoreleaseScope and every autorelease call", "No returned object relies on deferred release any more.", "grep -rn 'AutoreleaseScope\\|autorelease' src is empty; tier-b unchanged.", ["3.gate"], 1),
 ("4.2", 4, "Drop libobjc2 and all -fobjc-* flags; rename .mm -> .cpp", "Mechanical if Phase 3 was disciplined.", "No .mm files; no -fobjc- in build lines; builds.", ["4.1"], 1),
 ("4.3", 4, "GCC (MINGW64) build alongside the Clang (UCRT64) build", "Upstream supports both MSYS2 environments; with the Objective-C gone, both must be green.", "GCC build green; tier-c green.", ["4.2"], 1),
 ("4.gate", 4, "Phase 4 exit gate per docs/phases/4-remove-objc-runtime.md", "", "All boxes checked; Phase 5 adds macOS arm64 and Linux x64 (ADR-0017).", ["4.3"], 1),
]

# Fleet sweeps derived from the tree.
SAVES = [("Constrictor", "mission_conhunt"), ("Nova", "mission_nova / mission_novacount"), ("Trumbles", "mission_trumbles"),
         ("CloakingDevice", "mission_cloakcounter"), ("ThargoidPlans", "mission_thargplans")]

def sweep_scenarios():
    names = ["witchspace jump", "combat encounter", "trade cycle", "mission trigger", "save/load round-trip",
             "test-oxp: JS interface", "test-oxp: materials", "test-oxp: shaders", "test-oxp: PNG", "test-oxp: AI overflow", "test-oxp: retro missions"]
    out = [(f"Golden scenario {i:03d}: {n}", f"Write scenario {i:03d} ({n}) the way scenario 001 is written: fixed seed, fixed system, fixed tick count, canonical dump and frame hash; bless it under the golden policy and prove 10-run stability.",
            ["tests/golden/scenarios/%03d/run.sh --check" % i, "tests/golden/scenarios/%03d/run.sh --stability 10" % i], ["0.4f"], "tests/golden/scenarios/001/", 2)
           for i, n in enumerate(names, start=2)]
    # Scenarios 013-017: the upstream release checklist's mission saves (1.75-era, mid-mission). They
    # pin the save-format compatibility contract, mission-variable round-trip, and each mission
    # script's state machine, none of which the scenarios above exercise.
    for j, (save, var) in enumerate(SAVES, start=len(names) + 2):
        path = f"upstream/oolite-tests/Checklist-files/Missions/{save}.oolite-save"
        out.append((f"Golden scenario {j:03d}: load checklist save {save}",
                    f"Write scenario {j:03d} the way scenario 001 is written, but starting from {path} via the harness's --load (the game's -load argument): fixed seed, fixed tick count, canonical dump (must include mission_variables, in particular {var}) and frame hash; bless under the golden policy; prove 10-run stability. The save is a 1.75-era file, so this also pins the save-format compatibility contract.",
                    ["tests/golden/scenarios/%03d/run.sh --check" % j, "tests/golden/scenarios/%03d/run.sh --stability 10" % j], ["0.4f"], "tests/golden/scenarios/001/", 2))
    return out

def sweep_gui():
    g = {2: "Exit via keyboard (Down x5, Enter)", 3: "Exit via window close (SDL_EVENT_QUIT)", 4: "Start a game: confirm row 22 then row 3, HUD renders, exit",
         5: "Screen round-trips: Ship Library, Game Options, Expansion Manager", 6: "Window lifecycle: resize, minimise/restore, fullscreen", 7: "First run: no prefs dir, defaults created",
         8: "Scenario-screen back-out: row 22 then row 1", 9: "Post-exit hygiene assertions shared by every GUI test"}
    return [(f"GUI test G{i}: {t}", f"Add upstream/oolite/tests/gui/test_g{i}_*.py the way test_g1_exit_via_mouse.py is written, per docs/phases/0-gui-tier.md. Runs against a real window on the desktop under the GUI-tier desktop lock.",
             [f"python3 -m pytest upstream/oolite/tests/gui/test_g{i}_*.py -x -q"], ["0.8a"], "upstream/oolite/tests/gui/test_g1_exit_via_mouse.py", 2) for i, t in g.items()]

COMPONENT = {2: ("Pirate attacks; the target registers an attacker", "the damage path independently of the kill path"),
             3: ("A hostile spawn drives a ship into ATTACK", "AI state-machine transitions via Ship.AIState, independent of whether combat resolves"),
             4: ("A missile-armed ship kills by missile", "the second weapon path; missiles are simulated projectiles, lasers are hitscan"),
             5: ("Escorts converge on their mother", "group and formation behaviour (OOShipGroup), which no other tier touches"),
             6: ("A damaged ship flees and range increases", "the FLEE branch, the most commonly broken AI transition"),
             7: ("8 neutral ships, 900 ticks, nobody dies, no ERROR in Latest.log", "the canary: accidental carnage, NaN blowups, scan-class confusion"),
             8: ("Destroyed ships leave system.allShips", "entity lifetime: a leaked entity shows here long before ASan catches the use-after-free")}

def sweep_component():
    return [(f"Component scenario S{i}: {t}",
             f"Add upstream/oolite/tests/component/features/s{i}_*.feature the way s1_police_kills_pirate.feature is written (docs/stories/S1-police-kills-pirate.md, docs/phases/0-component-tier.md), using only steps that already exist in the step library (tests/component/README.md). Catches: {why}. Assert 'within N ticks' and counts, never exact positions. If the scenario needs a step that does not exist, stop and report blocked (new interface, ADR-0018 §5).",
             [f"python3 -m pytest upstream/oolite/tests/component/ -k s{i}_ -x -q", f"for i in 1 2 3; do python3 -m pytest upstream/oolite/tests/component/ -k s{i}_ -x -q || exit 1; done"],
             ["0.13b"], "upstream/oolite/tests/component/features/s1_police_kills_pirate.feature", 2) for i, (t, why) in COMPONENT.items()]

def sweep_js_retarget():
    out = []
    for p in m_files():
        if not grep(p, r'jsapi\.h|OOJavaScriptEngine\.h'): continue
        if p.name == "OOJSVector.m": continue
        n = count_lines(p); rel = p.relative_to(ROOT).as_posix()
        if p.name in GIANT: continue
        out.append((f"Retarget JS_* calls onto the façade: {p.name}",
                    f"Move every JS_* call in {rel} ({n} lines) onto ooscript/JSEngine.hpp, SpiderMonkey still underneath. Apply tools/refactor/js-stubs.sh first, then hand-retarget the rest. Behaviour must not change.",
                    [f"! grep -nE '\\bJS_[A-Za-z]+' {rel}", f"tools/tier-a.sh {rel}", "tools/tier-b.sh --fast"], ["1.1x", "1.2"], "upstream/oolite/src/Core/Scripting/OOJSVector.m", 2 if n < 1500 else 3))
    return out

def sweep_extractors():
    out = []
    for p in m_files():
        if not grep(p, r'oo_[a-zA-Z]+ForKey'): continue
        if p.name in GIANT: continue
        n = count_lines(p); rel = p.relative_to(ROOT).as_posix().replace(".m", ".mm")
        out.append((f"Retire oo_*ForKey in {p.name}", f"Replace every oo_*ForKey:defaultValue: call in {rel} ({n} lines) with PList::get<T>, the way the exemplar consumer does it. No other change.",
                    [f"! grep -nE 'oo_[a-zA-Z]+ForKey' {rel}", f"tools/tier-a.sh {rel}", "tools/tier-b.sh --fast"], ["2.4"], "the consumer migrated in bead 2.4 (see its notes)", 2 if n < 1500 else 3))
    return out

def sweep_foundation():
    out = []
    for p in m_files():
        header_ns = header_declares_ns(p)
        if not grep(p, r'\bNS(String|Array|Dictionary|Set|Number|Data|Enumerator|Mutable\w+)\b') and not header_ns: continue
        if p.name in GIANT: continue
        n = count_lines(p); rel = p.relative_to(ROOT).as_posix().replace(".m", ".mm"); mod = module_of(p)
        h = header_for(p); hrel = h.relative_to(ROOT).as_posix() if h else None
        grep_files = rel + (f" {hrel}" if header_ns and hrel else "")
        extra = ""
        if header_ns:
            # ADR-0012: this file's body is plain C, but its header declares NS* types in a public
            # signature, so renaming it to .c would change an interface used across the tree. The
            # Foundation migration comes first and must clean the header too; the rename bead for
            # this file is emitted by a later tools/gen-stories.py run, once this bead has closed.
            extra = (f" Its header {hrel} declares NS* types in public signatures, so the header must be migrated too:"
                     " every declared NS* parameter/return becomes its oofnd equivalent, and every caller in the tree"
                     " is updated in the same commit. Until that lands this file cannot be renamed to .c"
                     " (ADR-0012); the rename bead is emitted only after this bead closes.")
        out.append((f"Migrate Foundation usage to oofnd: {p.name}", f"Replace NSString/NSArray/NSDictionary/NSSet/NSNumber/NSData usage in {rel} ({n} lines, module {mod}) with oofnd types, the class still Objective-C. Do not convert the class.{extra}",
                    [f"! grep -nE '\\bNS(String|Array|Dictionary|Set|Number|Data|Enumerator|Mutable[A-Za-z]+)\\b' {grep_files}", f"tools/tier-a.sh {rel}", "tools/tier-b.sh --fast"],
                    ["2.10"], "the exemplar consumers named in beads 2.4-2.8", MODULE_ORDER[mod]))
    return out

def objc_usage(p):
    """(message-send-ish count, @-keyword count, has @interface) for a file with no @implementation."""
    try: t = open(p, errors="replace").read()
    except OSError: return (0, 0, False)
    sends = len(re.findall(r'\[[A-Za-z_][A-Za-z0-9_]* [a-zA-Z_]+[\]:]', t))
    kw = len(re.findall(r'@(selector|protocol|try|catch|synchronized|autoreleasepool|class|property|end)', t))
    return (sends, kw, '@interface' in t)

def body_is_c(p):
    """The old is_c_file test: the .m body alone has no class and little enough Objective-C
    (sends, @"" literals, OOLog) to be replaced in one small step."""
    if grep(p, r'@implementation'): return False
    sends, kw, iface = objc_usage(p)
    try: t = open(p, errors="replace").read()
    except OSError: return False
    literals = t.count('@"'); oolog = len(re.findall(r'\bOOLog', t))
    return not iface and kw == 0 and (sends + literals + oolog) <= 8

# An NS* type used in a declared signature: a pointer to any NS class, or one of the NS value
# structs passed by value. Comment and preprocessor lines are stripped first so a mention in a
# doc comment (`// @"(w + xi)"`, `// returns an NSString`) does not count as a declaration.
NS_SIG = re.compile(r'\bNS[A-Z]\w*\s*\*|\bNS(Size|Rect|Point|Range)\b')

def _blank(seg):
    """seg with every character except newlines replaced by a space: removes the text while
    keeping byte offsets and line structure intact."""
    return re.sub(r'[^\n]', ' ', seg)

def strip_noncode(text):
    """Blank out everything that is not code: block comments, line comments, the bodies of string
    and character literals, and whole preprocessor lines.

    Scanned left to right in ONE pass so the constructs nest correctly (a `/*` inside a string is
    not a comment, a `"` inside a comment does not open a string). String bodies are blanked as
    well as comments (bead oo-mnzc) because header_declares_ns now matches ACROSS line breaks, so
    a literal such as @"NSString *Thing(int);" would otherwise read as a real declaration."""
    out = []; i = 0; n = len(text)
    while i < n:
        c = text[i]
        if c == '/' and text[i+1:i+2] == '*':
            j = text.find('*/', i + 2)
            seg = text[i:] if j < 0 else text[i:j+2]
            out.append(_blank(seg)); i += len(seg)
        elif c == '/' and text[i+1:i+2] == '/':
            j = text.find('\n', i)
            if j < 0: j = n
            out.append(_blank(text[i:j])); i = j
        elif c == '"' or c == "'":
            q = c; j = i + 1
            while j < n and text[j] != q:
                if text[j] == '\\': j += 1          # \" and \' do not close the literal
                if text[j:j+1] == '\n': break        # unterminated: do not run past the line
                j += 1
            seg = text[i:min(j + 1, n)]
            out.append(c + _blank(seg[1:])); i += len(seg)
        else:
            out.append(c); i += 1
    return "\n".join("" if ln.lstrip().startswith('#') else ln
                     for ln in "".join(out).splitlines())

def text_declares_ns(code):
    """True when already-stripped C text contains an NS* type in a DECLARATION.

    Matched per declaration, not per physical line (bead oo-mnzc). A C declaration is terminated by
    ';' and may be split over any number of lines, so

        NSString *
        ThingDescription(int n);

    is one declaration even though no single line carries both the NS* type and the ';' — the
    line-by-line scan this replaced missed exactly that (and the NSSize/NSRect/NSPoint/NSRange
    by-value cases) whenever the return type sat on its own line, a common C header style."""
    parts = code.split(';')
    for decl in parts[:-1]:              # each of these was terminated by a ';': a declaration
        if NS_SIG.search(decl): return True
    tail = parts[-1]                     # unterminated remainder: keep the old per-line guard
    for line in tail.splitlines():
        if not NS_SIG.search(line): continue
        if re.search(r'[(),]', line) or re.search(r'\bNS[A-Z]\w*\s*\*\s*\w', line): return True
    return False

def header_declares_ns(p):
    """True when this file's OWN header declares an NS* type in a signature. Renaming such a file
    to .c would change an interface used across the tree (bead oo-qnmv), so it is not a mechanical
    rename: the Foundation sweep has to clean the header first."""
    h = header_for(p)
    if h is None: return False
    try: t = open(h, errors="replace").read()
    except OSError: return False
    return text_declares_ns(strip_noncode(t))

# The "can this be renamed to .c in one mechanical step" rule (plain-C body AND a header that
# declares no NS* types) has exactly ONE definition, and it is the "renames" branch of classify()
# below. A second helper used to state it (is_c_file, bead oo-yg8p); it was called from nowhere in
# the generator and only from the tests, so it could drift away from the live rule silently. Do not
# reintroduce it: ask classify(p) == "renames".

def classify(p):
    """Which sweep owns this file: 'renames' (mechanical .m -> .c), 'foundation' (plain-C body but
    the header declares NS* types: migrate Foundation first, rename bead emitted after it closes),
    or 'convert' (real Objective-C, Phase 3 C++20 conversion)."""
    if not body_is_c(p): return "convert"
    return "foundation" if header_declares_ns(p) else "renames"

def sweep_renames():
    out = []
    for p in m_files():
        if classify(p) != "renames": continue
        rel = p.relative_to(ROOT).as_posix(); c = rel[:-2] + ".c"; sends = objc_usage(p)[0]
        h = header_for(p); hrel = h.relative_to(ROOT).as_posix() if h else None
        extra = f" It has {sends} residual Objective-C call(s); replace each with the plain C equivalent (usually a logging macro or a Foundation call that oofnd now provides)." if sends else ""
        acc = [f"test -f {c}", f"! test -f {rel} && ! test -f {rel}m", f"! grep -nE '@(implementation|interface|selector|protocol)|@\"' {c}"]
        if hrel:  # the header must stay free of NS* signatures, or this is an interface change, not a rename (bead oo-qnmv)
            acc.append(f"! grep -nE '\\bNS[A-Z][A-Za-z0-9_]*\\s*\\*|\\bNS(Size|Rect|Point|Range)\\b' {hrel}")
        acc.append(f"tools/tier-a.sh {c}")
        out.append((f"Rename C-in-.m file to .c: {p.name}", f"{rel} contains no Objective-C class (ADR-0012). Rename to {c}, add extern \"C\" guards to its header, adjust meson. Otherwise byte-identical code.{extra}",
                    acc, ["2.10"], "docs/decisions/0012-c-stays-c.md", 1))
    return out

def sweep_convert():
    out = []; presplit = []
    for p in m_files():
        # 'foundation' files (plain-C body, NS* in the header) belong to the Foundation sweep; their
        # rename bead appears on the next generator run, once that migration has closed (oo-qnmv).
        if classify(p) != "convert": continue
        if p.name in GIANT or p.name in ("OOColor.m",): continue
        n = count_lines(p); h = header_for(p); hn = count_lines(h) if h else 0
        freefn = not grep(p, r'@implementation')
        rel = p.relative_to(ROOT).as_posix().replace(".m", ".mm"); hrel = h.relative_to(ROOT).as_posix() if h else None
        mod = module_of(p); seam = MODULE_SEAM[mod]
        if n + hn > 1500:
            presplit.append((f"Pre-split {p.name} ({n} lines) into story-sized slices", f"Write a slice plan for {rel}: which categories/methods go in which .cpp, so each slice reads under 1,500 lines. Output: a plan in the bead notes; re-run tools/gen-stories.py to emit the slice beads.",
                             [], [seam], "docs/phases/3-cpp-conversion.md", MODULE_ORDER[mod]))
            continue
        files = f"- {rel} ({n} lines)" + (f"\n- {hrel} ({hn} lines)" if hrel else "")
        what = (f"Convert the free functions in {rel} from Objective-C++ to C++20: every message send becomes a member call on the converted classes, Foundation usage is already oofnd. No class here; keep the file as .mm until Phase 4." if freefn
                else f"Convert the class in {rel} (and {hrel or 'its header'}) from Objective-C to conservative C++20 per the recipe in docs/phases/3-cpp-conversion.md: class shell, member functions, oo::Ref, dynamic_cast where isKindOfClass: genuinely needs it. Plain-C method bodies stay verbatim.")
        what += " If the conversion touches observable ship, AI or weapon behaviour, add a component scenario under upstream/oolite/tests/component/features/ using existing steps (ADR-0018); a missing step is a new interface, so report it rather than writing one."
        out.append((f"Convert to C++20: {p.name}", f"{what}\n\n## Files\n{files}",
                    [f"! grep -nE '@implementation|@interface|@selector|@protocol' {rel}" + (f" {hrel}" if hrel else ""), f"tools/tier-a.sh {rel}", "tools/tier-b.sh --fast"], [seam], f"seam:{seam}", MODULE_ORDER[mod]))
    return out, presplit

SWEEPS = [  # key, phase, label, generator
    ("scenarios", 0, sweep_scenarios), ("gui", 0, sweep_gui), ("component", 0, sweep_component), ("js-retarget", 1, sweep_js_retarget),
    ("extractors", 2, sweep_extractors), ("foundation", 2, sweep_foundation), ("renames", 3, sweep_renames), ("convert", 3, None),
]

REVIEW_MODEL = "claude-fable-5-1"

def review_seam(n):
    """The phase review (Jon, 2026-09-11): Claude Fable 5.1 verifies every item of phase n is really done
    and files whatever work is missing, before the exit gate walks the checklist."""
    name, doc = PHASES[n]
    desc = (f"Delegated to Claude Fable 5.1 (bead metadata model={REVIEW_MODEL}; run-story passes it as --model). "
            f"Procedure: (1) `bd list --label phase:{n} --all --json`: every bead other than this review and the gate is closed or escalated; work every escalated bead (they are frontier work) or file a replacement. "
            f"(2) For a sample of at least 20 closed beads and every seam, check the merge commit on main and re-run its acceptance block; anything that no longer holds gets a new bead. "
            f"(3) Walk {doc}: every exit-gate box has evidence in the tree, every work item landed; grep the tree for the phase's leftovers (the phase doc says what must be gone). "
            f"(4) For each gap: `bd create --parent <phase {n} epic> --labels phase:{n},<fleet|frontier>,sweep:review-{n}` with a fenced ## Acceptance block, then `bd dep add <this review> <new bead>` so this review reopens behind it. "
            f"(5) Append findings to docs/fleet/LEARNINGS.md and the phase doc's status log; re-run tools/gen-stories.py --dry-run and file a generator-bug bead if the generator should have emitted the missing work. "
            f"Close only when nothing is left; the exit gate ({n}.gate) then walks the checklist. Never close beads yourself: accept.sh does.")
    acc = [f"test \"$(bd list --label phase:{n} --status open,in_progress --json -n 0 | jq '[.[] | select((.labels | index(\"seam:{n}.review\")) or (.labels | index(\"seam:{n}.gate\")) | not)] | length')\" = 0",
           f"grep -q 'review {n} ' docs/fleet/LEARNINGS.md"]
    return (f"{n}.review", n, f"Phase {n} review (Claude Fable 5.1): every item verified done, missing work filed as beads", desc, acc, [], 1)

SEAMS += [review_seam(n) for n in PHASES]
REVIEW_META = {f"{n}.review": {"model": REVIEW_MODEL, "exemplar": "docs/execution-model.md"} for n in PHASES}

# ---------------------------------------------------------------- main
def body(desc, acceptance, exemplar, sweep, phase, prose=None):
    if acceptance:
        acc = "\n".join(acceptance)
    else:  # a seam or pre-split: prose definition of done; the guard line keeps accept.sh from closing it
        acc = ("# Frontier work: the definition of done is prose. Replace this block with executable commands\n"
               "# (bd update <id> --description) when the work lands; accept.sh refuses comment-only blocks.\n"
               f"# DONE WHEN: {prose or desc}\n"
               "exit 1  # no executable acceptance yet")
    return f"Generated by tools/gen-stories.py · sweep {sweep} · Phase {phase} · exemplar: {exemplar}\n\n## Task\n{desc}\n\n**Do it the way `{exemplar}` does it.**\n\n## Acceptance (run by accept.sh in a clean checkout)\n```\n{acc}\n```\n\n{PROHIBITIONS}\n\n{SIZING}"

def seam_body(key, n, title, desc, acc):
    """A seam's acceptance is prose (guarded) unless the table gives a list of commands."""
    if isinstance(acc, list): return body(desc or title, acc, "n/a (seam)", f"seam {key}", n)
    return body(desc or title, [], "n/a (seam)", f"seam {key}", n, prose=acc)

SWEEP_BUILDERS = {"renames": lambda: sweep_renames(), "convert": lambda: sweep_convert()[0], "presplit": lambda: sweep_convert()[1],
                  "foundation": lambda: sweep_foundation(), "extractors": lambda: sweep_extractors(), "js-retarget": lambda: sweep_js_retarget()}
SWEEP_PHASE = {"renames": 3, "convert": 3, "presplit": 3, "foundation": 2, "extractors": 2, "js-retarget": 1}

def item_for_file(sweep, fname):
    """The (title, desc, acc, deps, exemplar, pri) the generator would emit for this file under this sweep, ignoring the classifier."""
    saved = globals()["classify"]
    try:
        globals()["classify"] = lambda p: sweep if sweep in ("renames", "foundation") else "convert"
        pat = re.compile(r"(^|[\s:/])" + re.escape(fname) + r"m?([\s(]|$)")
        for it in SWEEP_BUILDERS[sweep]():
            if pat.search(it[0]): return it
    finally:
        globals()["classify"] = saved
    return None

def reclassify(bead_id, sweep):
    """Rewrite an existing bead in place under another sweep: title, labels, body, metadata, deps. Notes and id survive."""
    show = json.loads(bd("show", bead_id, "--json")); show = show[0] if isinstance(show, list) else show
    fname = show["title"].split(": ")[-1].split(" ")[-1].split("/")[-1]
    if fname.endswith(".mm"): fname = fname[:-1]
    it = item_for_file(sweep, fname)
    if not it: raise SystemExit(f"no {sweep} story for {fname}")
    title, desc, acc, dk, exemplar, pri = it
    n = SWEEP_PHASE[sweep]; old_sweep = [l for l in show.get("labels", []) if l.startswith("sweep:")]
    existing = existing_titles().get(title)
    if existing and existing != bead_id:
        # The target sweep already has this file's bead: do not duplicate it. This bead now waits on it.
        subprocess.run(["bd", "dep", "add", bead_id, existing, "-q"], capture_output=True)
        bd("update", bead_id, "--append-notes", f"reclassify to sweep:{sweep} requested, but {existing} already covers this file there; this bead now depends on it and keeps its own sweep", "--status", "open", "--assignee", "", "-q")
        print(f"{bead_id} now depends on existing {sweep} bead {existing}; not duplicated"); return
    labels = [l for l in show.get("labels", []) if not l.startswith(("sweep:", "phase:", "fleet", "frontier"))]
    labels += [f"phase:{n}", "frontier" if sweep == "presplit" else "fleet", f"sweep:{sweep}"]
    epic = existing_titles().get(f"Phase {n} — {PHASES[n][0]}")
    args = ["update", bead_id, "--title", title, "--set-labels", ",".join(labels), "--description", body(desc, acc, exemplar, sweep, n), "--priority", str(pri), "--metadata", json.dumps({"exemplar": exemplar}), "-q"]
    if epic: args += ["--parent", epic]
    bd(*args)
    for d in dk:
        sid = subprocess.run(["bd", "list", "--all", "--json", "-n", "0", "--label", f"seam:{d}"], capture_output=True, text=True).stdout
        try: sid = (json.loads(sid) or [{}])[0].get("id")
        except json.JSONDecodeError: sid = None
        if sid: subprocess.run(["bd", "dep", "add", bead_id, sid, "-q"], capture_output=True)
    bd("update", bead_id, "--append-notes", f"reclassified {old_sweep[0] if old_sweep else '?'} -> sweep:{sweep} by tools/gen-stories.py", "-q")
    print(f"reclassified {bead_id}: {title}")

def check_classification():
    """Report existing rename/convert beads whose file the classifier now puts in another sweep.

    Only sweep:renames and sweep:convert are checked: they are the two Phase 3 sweeps that partition
    the .m files, so a file in both is a contradiction. sweep:foundation is Phase 2 and orthogonal —
    a file legitimately carries a Foundation bead *and* a later Phase 3 bead — so it is never
    reported here. A renames bead whose header declares NS* types shows up as `renames -> foundation`
    (bead oo-qnmv): the Foundation migration has to clean the header before the rename is mechanical.

    Read-only: prints a report and exits 0, so it is safe in an acceptance block. Nothing is mutated;
    `--reclassify <bead> <sweep>` applies one line of the report at a time."""
    out = subprocess.run(["bd", "list", "--all", "--json", "-n", "0", "--label-any", "sweep:renames,sweep:convert"], capture_output=True, text=True).stdout
    by_name = {p.name: p for p in m_files()}
    try: issues = json.loads(out) or []
    except json.JSONDecodeError: issues = []
    checked = 0; bad = 0
    for x in issues:
        fname = x["title"].split(": ")[-1].split(" ")[-1]; fname = fname[:-1] if fname.endswith(".mm") else fname
        p = by_name.get(fname)
        if not p: continue
        have = next((l[6:] for l in x.get("labels", []) if l.startswith("sweep:")), "?")
        if have not in ("renames", "convert") or x["status"] == "closed": continue
        checked += 1
        want = classify(p)
        if want != have:
            bad += 1; print(f"{x['id']}\t{have} -> {want}\t{fname}")
    print(f"checked {checked} rename/convert bead(s); {bad} misclassified")
    return 0

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--apply", action="store_true"); ap.add_argument("--dry-run", action="store_true"); ap.add_argument("--phase", type=int)
    ap.add_argument("--reclassify", nargs=2, metavar=("BEAD", "SWEEP"), help="rewrite one existing bead under another sweep")
    ap.add_argument("--check-classification", action="store_true", help="list rename/convert beads that disagree with the classifier")
    ap.add_argument("--rewire", action="store_true", help="also re-add deps between beads that already existed (slow; default skips them)")
    ap.add_argument("--refresh", action="store_true", help="rename/delete per RENAMED and rewrite existing beads whose generated text changed")
    a = ap.parse_args(); apply = a.apply and not a.dry_run
    if a.refresh: refresh()
    if a.reclassify: return reclassify(*a.reclassify)
    if a.check_classification: return check_classification()
    titles = existing_titles()
    nodes = []; edges = []; ids = {}; node_title = {}
    def create(title, kind, phase, labels, desc, priority, parent=None, meta=None):
        if title in titles:  # already in bd: reference by id, do not recreate
            ids_key = "existing:" + titles[title]; ids[ids_key] = ids_key; return ids_key
        key = f"n{len(nodes)}"
        node = {"key": key, "title": title, "type": kind, "labels": labels, "description": desc, "priority": priority}
        if parent and parent.startswith("existing:"): late_parents.append((key, parent.split(":", 1)[1]))
        elif parent: node["parent_key"] = parent
        if meta: node["metadata"] = meta
        nodes.append(node); node_title[key] = title; return key
    deps = []; late_parents = []  # (node key, existing epic id): the graph schema cannot reference pre-existing parents
    for n, (name, doc) in PHASES.items():
        if a.phase is not None and n != a.phase: continue
        ids[f"epic{n}"] = create(f"Phase {n} — {name}", "epic", n, [f"phase:{n}", "epic"], f"See {doc}. Children are the seams (frontier) and the generated sweep beads (fleet).", 1)
    gate_deps = {key: dk for key, n, title, desc, acc, dk, pri in SEAMS if key.endswith(".gate")}
    for key, n, title, desc, acc, dk, pri in SEAMS:
        if a.phase is not None and n != a.phase: continue
        labels = [f"phase:{n}", "frontier", f"seam:{key}"] + (["review"] if key.endswith(".review") else [])
        ids[key] = create(title, "task", n, labels, seam_body(key, n, title, desc, acc), pri, parent=ids.get(f"epic{n}"), meta=REVIEW_META.get(key))
        if key.endswith(".review"): dk = gate_deps.get(f"{n}.gate", [])   # the review checks everything the gate used to wait on
        if key.endswith(".gate"): dk = list(dk) + [f"{n}.review"]           # and the gate waits on the review
        for d in dk: deps.append((key, d))
    counts = {}; file_to_extractor = {}; file_to_foundation = {}
    for skey, n, gen in SWEEPS:
        if a.phase is not None and n != a.phase: continue
        presplit = []
        items, presplit = (sweep_convert() if skey == "convert" else (gen(), []))
        for i, (title, desc, acc, dk, exemplar, pri) in enumerate(items):
            k = f"{skey}:{i}"
            ids[k] = create(title, "task", n, [f"phase:{n}", "fleet", f"sweep:{skey}"], body(desc, acc, exemplar, skey, n), pri, parent=ids.get(f"epic{n}"), meta={"exemplar": exemplar})
            for d in dk: deps.append((k, d))
            fname = title.split(": ")[-1].split(" ")[-1]
            if skey == "extractors": file_to_extractor[fname] = k
            if skey == "foundation":
                file_to_foundation[fname] = k
                if fname in file_to_extractor: deps.append((k, file_to_extractor[fname]))
            # A rename bead for a file that also has a Foundation bead waits on it: the header and
            # body must be free of NS* before the .m -> .c rename is mechanical (bead oo-qnmv).
            if skey == "renames" and fname in file_to_foundation: deps.append((k, file_to_foundation[fname]))
        counts[skey] = len(items)
        for i, (title, desc, acc, dk, exemplar, pri) in enumerate(presplit):
            k = f"presplit:{i}"; ids[k] = create(title, "task", n, [f"phase:{n}", "frontier", "sweep:presplit"], body(desc, [], exemplar, "presplit", n, prose="Slice plan in the bead notes; each slice reads under 1,500 lines."), pri, parent=ids.get(f"epic{n}"))
            for d in dk: deps.append((k, d))
        if presplit: counts["presplit"] = len(presplit)
    for k in list(ids):
        if ":" in k and not k.startswith(("epic", "existing:")):
            if k.startswith(("scenarios:", "gui:", "component:")): deps.append(("0.review", k))
            elif k.startswith("js-retarget:"): deps.append(("1.7", k)); deps.append(("1.review", k))
            elif k.startswith(("foundation:", "extractors:")): deps.append(("2.12", k)); deps.append(("2.review", k))
            elif k.startswith(("renames:", "convert:", "presplit:")): deps.append(("3.giant-Universe", k)); deps.append(("3.review", k))
    late = []  # deps involving pre-existing beads: wired with bd dep add after the graph
    for blocked, blocker in deps:
        if blocked not in ids or blocker not in ids: continue
        b1, b2 = ids[blocked], ids[blocker]
        if b1.startswith("existing:") and b2.startswith("existing:"):
            if a.rewire: late.append((b1, b2))
        elif b1.startswith("existing:") or b2.startswith("existing:"): late.append((b1, b2))
        else: edges.append({"from_key": b1, "to_key": b2, "type": "blocks"})
    plan = {"nodes": nodes, "edges": edges}
    out = ROOT / "build" / "gen-stories-plan.json"; out.parent.mkdir(exist_ok=True); out.write_text(json.dumps(plan, indent=1))
    print(f"plan: {len(nodes)} nodes, {len(edges)} edges, {len(late)} late deps -> {out}")
    for k, v in counts.items(): print(f"  sweep {k}: {v}")
    if not apply:
        print("dry run; nothing written to bd"); return
    if nodes:
        res = subprocess.run(["bd", "create", "--graph", str(out)], capture_output=True, text=True)
        print(res.stdout.strip()[-2000:]); 
        if res.returncode != 0: raise SystemExit(res.stderr.strip()[-2000:])
        created = dict(re.findall(r"^\s*(n\d+) -> (\S+)$", res.stdout, re.M))
    else:
        created = {}
    def real(x): return x.split(":", 1)[1] if x.startswith("existing:") else created.get(x, x)
    if late:
        pairs = [{"from": real(b1), "to": real(b2)} for b1, b2 in late]
        res = subprocess.run(["bd", "dep", "add", "--file", "-"], capture_output=True, text=True,
                             input="\n".join(json.dumps(p) for p in pairs))
        if res.returncode != 0:  # bulk validation is all-or-nothing: one stale id would drop every edge
            print(f"bulk dep add failed ({res.stderr.strip()[:200]}); falling back to per-edge")
            for p in pairs: subprocess.run(["bd", "dep", "add", p["from"], p["to"], "-q"], capture_output=True)
    for k, epic in late_parents:
        if k in created: subprocess.run(["bd", "update", created[k], "--parent", epic, "-q"], capture_output=True)
    print(f"created {len(created)} beads; wired {len(late)} late deps; parented {len(late_parents)}")

if __name__ == "__main__":
    main()
