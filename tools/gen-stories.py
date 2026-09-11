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
- Do not modify or delete tests. If the test is wrong, stop and report.
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

def existing_titles():
    out = subprocess.run(["bd", "list", "--all", "--json", "-n", "0"], capture_output=True, text=True).stdout
    try:
        return {x["title"]: x["id"] for x in (json.loads(out) or [])}
    except json.JSONDecodeError:
        return {}

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
 ("0.2", 0, "Base image: GNUstep at pinned commits + mozillajs-linux 0.0.1, prebuilt", "Build oolite-ci-linux:gnustep-<pin> once in WSL2 from ShellScripts/Linux/build_gnustep.sh and install_mozilla_js.sh; document the rebuild trigger (pin moves). See docs/infra/1-base-images.md.", "docker run <image> ./mk.sh build test succeeds in under 10 minutes on a warm ccache, without rebuilding GNUstep.", [], 1),
 ("0.3a", 0, "tools/build-linux.sh: clean-clone Linux build in WSL2 matching upstream's workflow", "Script the Linux leg from a clean clone using the base image; same flavours as upstream build-all.yaml.", "tools/build-linux.sh exits 0 from a fresh clone and produces the AppImage/test binary.", ["0.2"], 1),
 ("0.3b", 0, "tools/build-windows.sh: native MSYS2 UCRT64 build from a clean clone", "Script the Windows leg with MSYS2 pre-provisioned once; no setup-msys2 step.", "tools/build-windows.sh exits 0 from a fresh clone on the Windows machine.", [], 1),
 ("0.4a", 0, "Parameterise tests/launch_snapshot.py: port, DISPLAY, output dir", "Today PORT=8563 and HOST are hardcoded. Make port, display and artifact directory arguments/env so N instances can run at once.", "Two instances run concurrently on different ports and both produce a screenshot.", ["0.3a"], 1),
 ("0.4b", 0, "Golden harness container: one scenario per container, Xvfb inside", "Container image built on the base image that runs one scenario script via the debug-console TCP channel and writes artifacts to a mounted directory.", "20 containers run concurrently on the machine with no port or display collision.", ["0.4a", "0.2"], 1),
 ("0.4c", 0, "Canonical state dump: sorted JSON of entities, positions, velocities, AI states, market, player", "A debug-console JS command that serialises the world after N ticks to canonical sorted JSON; float fields quantised per decision 11.", "Two runs of the same scenario on the same build produce byte-identical dumps.", ["0.4b"], 1),
 ("0.4d", 0, "Frame hashes with tolerance at fixed camera positions", "Perceptual hash of rendered frames at fixed camera positions; tolerance documented; llvmpipe vs Windows GL compared.", "Same scenario, two runs: hashes within tolerance; a deliberately moved ship changes the hash beyond tolerance.", ["0.4b"], 2),
 ("0.4e", 0, "Golden storage policy: per-platform goldens + quantised floats; -ffp-contract=off; pinned -O", "Implement decision 11: goldens/<platform>/<scenario>/ layout, quantisation in the dump, golden build flags pinned.", "Linux and Windows goldens for scenario 001 both stored; a diff tool reports zero differences after quantisation.", ["0.4c"], 1),
 ("0.4f", 0, "Scenario 001 launch/dock: script, bless, 10-run stability", "The first golden scenario and the exemplar for all others: fixed seed, fixed system, fixed tick count, dump + frame hash, blessed under the policy.", "10 consecutive runs reproduce the golden byte-for-byte on both legs.", ["0.4e"], 1),
 ("0.4g", 0, "Define scenarios 13-20 (beyond the twelve named in the plan)", "Name the remaining scenarios so the list reaches ~20 with broad coverage (equipment, station services, NPC AI states, HUD modes, etc.). Output: a list with one line each, added to docs/phases/0-safety-net.md.", "docs/phases/0-safety-net.md lists 20 scenarios with a one-line purpose each.", ["0.4f"], 2),
 ("0.5", 0, "JS API conformance snapshot: oxp-contract/js-api-1.92.json", "Via the debug console enumerate all 61 JS globals and every native class's properties, methods, arities and types; commit; add a check that regenerates and diffs.", "tools/js-api-snapshot.sh regenerates the file and `git diff --exit-code` passes on the current build.", ["0.4a"], 1),
 ("0.6a", 0, "OXP corpus: fetch and cache the catalog (818 unique URLs) with checksums", "Download every expansion from upstream/oolite-expansion-catalog into a local cache with a manifest of checksums; resumable.", "Manifest lists every URL with size and sha256; a second run downloads nothing.", [], 2),
 ("0.6b", 0, "OXP corpus Tier 1 list (~30 most-installed + 6 test-oxps) and per-commit runner", "Choose Tier 1, script loading each on a headless build and asserting no ERROR lines in Latest.log.", "tools/corpus.sh tier1 exits 0 on the current build.", ["0.6a", "0.4a"], 1),
 ("0.6c", 0, "OXP corpus Tier 2 (~150, category coverage) and Tier 3 (all) runners", "Nightly (Tier 2) and weekly (Tier 3) load-only smoke runs with clustered error reports.", "tools/corpus.sh tier3 completes and writes a report grouping failures by first error line.", ["0.6b"], 2),
 ("0.7a", 0, "Mozilla-only-JS static scan: ESLint config + runner over the corpus", "tools/oxp-js-lint flags for each, catch-if, E4X, .quote(), toSource, uneval, let blocks, legacy getters, expression closures.", "Runs over the whole cached corpus and writes a per-expansion report; zero hits on the 31 in-tree scripts.", ["0.6a"], 1),
 ("0.7b", 0, "Expansion-scan model pilot: classify ambiguous hits with a local model, hand-audit 50", "Sandboxed (no repo mount, no secrets): local model classifies the lint's ambiguous hits; a random 50 are hand-audited and the agreement rate recorded in docs/fleet/LEARNINGS.md.", "Report published with agreement rate; sandbox verified to have no repo write access.", ["0.7a"], 3),
 ("0.8a", 0, "GUI tier: row->screen-point helper, launch/kill fixture, and G1 exit-via-mouse", "The calibration seam: tests/gui/conftest.py and test_g1_exit_via_mouse.py per docs/stories/G1-exit-via-mouse.md.", "xvfb-run -a python3 -m pytest tests/gui/test_g1_exit_via_mouse.py -x -q passes on Linux; passes natively on Windows.", ["0.3a"], 1),
 ("0.9a", 0, "tools/tier-a.sh <file>: single-TU compile + clang-tidy + deny-list, under 30 s, offline", "The agent inner loop. Compile one translation unit via meson/ninja target, run clang-tidy on it, grep the deny-list; measure on OOColor.m and OORoleSet.m.", "tools/tier-a.sh src/Core/OOColor.m completes in under 30 s with the network disabled.", ["0.3a"], 1),
 ("0.9b", 0, "tools/tier-b.sh: one-platform build + module tests + 3-5 fast goldens + Tier-1 subset, under 10 min", "Runs in a clean worktree in WSL2; `--fast` variant for accept.sh.", "tools/tier-b.sh exits 0 on main in under 10 minutes on a warm cache.", ["0.9a", "0.4f", "0.6b"], 1),
 ("0.9c", 0, "tools/tier-c.sh: both legs, all goldens, ASan+UBSan, full Tier 1, JS API snapshot, GUI tier", "The merge gate, run locally (ADR-0016) in a clean worktree; Windows leg invoked from WSL2.", "tools/tier-c.sh exits 0 on main; a deliberate use-after-free in a scratch branch is caught by ASan.", ["0.9b", "0.5", "0.8a"], 1),
 ("0.10", 0, "tools/merge-queue: batch Tier-B-green branches, run tier-c locally, fast-forward, bisect on red", "Batch-and-bisect over local branches; requeues the culprit's bead with the failure in its notes. accept.sh's base branch becomes an integration branch this promotes.", "A batch of 8 branches with one bad one: the queue bisects to the culprit and merges the other 7.", ["0.9c"], 2),
 ("0.11", 0, "Guardrail checks: goldens/ protection, warning-suppression grep, deleted-test detection, deny-list", "tools/guardrails.sh run by tier-b and tier-c: fails on any change under goldens/ without a rebless approval, on new -Wno-/#pragma diagnostic, on deleted/emptied test files, on reintroduced libgnustep-base/JS_* symbols.", "Each of the four violations, introduced in a scratch branch, fails tools/guardrails.sh with a specific message.", ["0.9b"], 1),
 ("0.12", 0, "Verify story generator output against the first real sweep (Phase 1 façade retarget)", "tools/gen-stories.py exists (v0). Once tier-a/tier-b exist, re-run with --apply and confirm the first generated bead is completable by a worker end to end through the beads-worker skill.", "One generated Phase 1 bead closed by accept.sh with no human edits to the bead text.", ["0.9b", "1.1"], 2),
 ("0.gate", 0, "Phase 0 exit gate: every item in docs/phases/0-safety-net.md checked", "Walk the exit-gate checklist; each unchecked item becomes a new bead. Close only when all are checked.", "All exit-gate boxes checked in docs/phases/0-safety-net.md with the commit that satisfied each.", ["0.1b","0.3b","0.4d","0.4g","0.6c","0.7b","0.10","0.11"], 1),
 # ---- Phase 1
 ("1.1", 1, "Design ooscript/JSEngine.hpp façade against the JS_* call-site histogram", "Value, Context, Object, ClassDef, PropertySpec, FunctionSpec, rooted handles, exception plumbing; sized to what Oolite uses. Header + SpiderMonkey-backed implementation, no call sites moved yet.", "Header compiles on both legs; tools/tier-a.sh passes on the implementation file; a doc comment maps each of the top 20 JS_* functions to its façade call.", ["0.gate"], 1),
 ("1.1x", 1, "Retarget one binding file (OOJSVector.m) onto the façade as the exemplar", "The first retargeted file; every later retarget bead points here.", "! grep -nE '\\bJS_[A-Za-z]+' src/Core/Scripting/OOJSVector.m; tier-a passes; goldens unchanged (tier-b).", ["1.1"], 1),
 ("1.2", 1, "clang-refactor scripts for the stub/init and numeric-conversion JS_* patterns", "tools/refactor/js-stubs.sh covering JS_PropertyStub/ResolveStub/ConvertStub/EnumerateStub/InitClass and JS_NewNumberValue/ValueToNumber/ValueToBoolean (~40% of sites).", "Script applied to one file produces a diff identical to the hand-retargeted exemplar for those patterns.", ["1.1x"], 1),
 ("1.4a", 1, "QuickJS-ng vendored + built on both legs behind a meson option", "Add QuickJS-ng as a subproject; build with -Djs_backend=quickjs; nothing wired yet.", "meson configure -Djs_backend=quickjs builds libquickjs on Linux and Windows.", ["1.1"], 1),
 ("1.4b", 1, "QuickJS-ng backend: Context/Value/Object/ClassDef with exotic-method mapping", "Implement the façade over QuickJS-ng; JSClass resolve/enumerate → JSClassExoticMethods; private pointer attach.", "Façade unit tests pass on both backends.", ["1.4a"], 1),
 ("1.4c", 1, "Rooting/GC handles and exception plumbing on the QuickJS-ng backend", "Rooted handles map to QuickJS GC semantics; JS exceptions ↔ C++ exceptions per the façade contract.", "Façade unit tests for rooting and exceptions pass on both backends; ASan clean.", ["1.4b"], 1),
 ("1.5a", 1, "tools/tier-c.sh --backend=<sm|quickjs>: differential run of goldens and corpus", "Run everything on both backends and produce a divergence report.", "Report lists every golden/corpus divergence with the first differing line.", ["1.4c", "0.9c"], 1),
 ("1.6a", 1, "docs/EXPANSION_MIGRATION.md: removed SpiderMonkey syntax, newly strict, newly available", "Publish the guide from the plan's table plus the corpus scan results.", "Doc exists and links each construct to a replacement and to the lint rule that flags it.", ["0.7a"], 2),
 ("1.6b", 1, "Compatibility shim OXP polyfilling toSource/quote for abandoned expansions", "Loaded first; polyfills what can be polyfilled.", "Tier 3 failures attributable to toSource/quote drop to zero with the shim installed.", ["1.6a", "1.5a"], 3),
 ("1.7", 1, "Delete the SpiderMonkey backend, mozillajs-linux and nspr; enable JS_* deny-list", "Remove the old backend and dependencies; guardrails deny JS_* symbols from now on.", "No JS_* symbol in src/; builds on both legs; tier-c green on quickjs.", ["1.5a"], 1),
 ("1.gate", 1, "Phase 1 exit gate: goldens, corpus, JS API snapshot on QuickJS-ng; deny-list on", "Walk docs/phases/1-js-engine.md exit gate.", "All exit-gate boxes checked.", ["1.7", "1.6b"], 1),
 # ---- Phase 2
 ("2.1", 2, "The .m -> .mm switch: one atomic, behaviour-free commit (.m without @implementation -> .c)", "Rename, -x objective-c++, -std=c++20; fix the few hundred mechanical errors with the compiler as oracle. Per ADR-0012 files with no @implementation become .c with extern \"C\" guards.", "Both legs build; goldens unchanged (tier-b); zero .m files remain.", ["0.gate"], 1),
 ("2.2", 2, "oofnd: RefCounted, Ref<T>, WeakRef<T>, AutoreleaseScope with unit tests", "src/oofnd/Ref.hpp mirroring ObjC refcounting 1:1 (ADR-0003); replaces OOWeakReference/OOWeakSet semantics.", "meson test --suite oofnd passes; ASan clean.", ["2.1"], 1),
 ("2.9", 2, "oofnd: oo::Expected<T,E> polyfill with std::expected's API", "ADR-0011: small polyfill or vendored tl::expected; used by every oofnd error path.", "Unit tests pass; a canary TU compiles at -std=c++20 on both legs.", ["2.1"], 1),
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
 ("2.12", 2, "Delete libgnustep-base from both legs; deny-list on", "Remove the dependency; only libobjc2 remains.", "Link lines contain no gnustep-base; tier-c green; guardrails deny it.", [], 1),  # deps wired to sweeps by generator
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
 ("3.gate", 3, "Phase 3 exit gate: zero @implementation; goldens; ASan; both legs clean", "Walk docs/phases/3-cpp-conversion.md exit gate.", "grep -rc '@implementation' src is 0; all boxes checked.", ["3.giant-Universe"], 1),
 # ---- Phase 4
 ("4.1", 4, "Delete oo::AutoreleaseScope and every autorelease call", "No returned object relies on deferred release any more.", "grep -rn 'AutoreleaseScope\\|autorelease' src is empty; tier-b unchanged.", ["3.gate"], 1),
 ("4.2", 4, "Drop libobjc2 and all -fobjc-* flags; rename .mm -> .cpp", "Mechanical if Phase 3 was disciplined.", "No .mm files; no -fobjc- in build lines; both legs build.", ["4.1"], 1),
 ("4.3", 4, "Restore the GCC build on Linux alongside Clang", "", "GCC build green in WSL2; tier-c green.", ["4.2"], 1),
 ("4.4", 4, "Exercise the cross-platform golden policy Linux vs Windows before any arm64 exists", "Decision 11 must already hold between the two x86-64 legs; fix any dump drift.", "Linux and Windows dumps identical after quantisation for all 20 scenarios.", ["4.2"], 1),
 ("4.gate", 4, "Phase 4 exit gate per docs/phases/4-remove-objc-runtime.md", "", "All boxes checked; this is the last phase on the single Windows machine.", ["4.3", "4.4"], 1),
]

# Fleet sweeps derived from the tree.
def sweep_scenarios():
    names = ["witchspace jump", "combat encounter", "trade cycle", "mission trigger", "save/load round-trip",
             "test-oxp: JS interface", "test-oxp: materials", "test-oxp: shaders", "test-oxp: PNG", "test-oxp: AI overflow", "test-oxp: retro missions"]
    return [(f"Golden scenario {i:03d}: {n}", f"Write scenario {i:03d} ({n}) the way scenario 001 is written: fixed seed, fixed system, fixed tick count, canonical dump and frame hash; bless it under the golden policy and prove 10-run stability.",
             ["tests/golden/scenarios/%03d/run.sh --check" % i, "tests/golden/scenarios/%03d/run.sh --stability 10" % i], ["0.4f"], "tests/golden/scenarios/001/", 2)
            for i, n in enumerate(names, start=2)]

def sweep_gui():
    g = {2: "Exit via keyboard (Down x5, Enter)", 3: "Exit via window close (SDL_EVENT_QUIT)", 4: "Start a game: confirm row 22 then row 3, HUD renders, exit",
         5: "Screen round-trips: Ship Library, Game Options, Expansion Manager", 6: "Window lifecycle: resize, minimise/restore, fullscreen", 7: "First run: no prefs dir, defaults created",
         8: "Scenario-screen back-out: row 22 then row 1", 9: "Post-exit hygiene assertions shared by every GUI test"}
    return [(f"GUI test G{i}: {t}", f"Add tests/gui/test_g{i}_*.py the way test_g1_exit_via_mouse.py is written, per docs/phases/0-gui-tier.md.",
             [f"xvfb-run -a python3 -m pytest tests/gui/test_g{i}_*.py -x -q"], ["0.8a"], "upstream/oolite/tests/gui/test_g1_exit_via_mouse.py", 2) for i, t in g.items()]

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
        if not grep(p, r'\bNS(String|Array|Dictionary|Set|Number|Data|Enumerator|Mutable\w+)\b'): continue
        if p.name in GIANT: continue
        n = count_lines(p); rel = p.relative_to(ROOT).as_posix().replace(".m", ".mm"); mod = module_of(p)
        out.append((f"Migrate Foundation usage to oofnd: {p.name}", f"Replace NSString/NSArray/NSDictionary/NSSet/NSNumber/NSData usage in {rel} ({n} lines, module {mod}) with oofnd types, the class still Objective-C. Do not convert the class.",
                    [f"! grep -nE '\\bNS(String|Array|Dictionary|Set|Number|Data|Enumerator|Mutable[A-Za-z]+)\\b' {rel}", f"tools/tier-a.sh {rel}", "tools/tier-b.sh --fast"],
                    ["2.10"], "the exemplar consumers named in beads 2.4-2.8", MODULE_ORDER[mod]))
    return out

def objc_usage(p):
    """(message-send-ish count, @-keyword count, has @interface) for a file with no @implementation."""
    try: t = open(p, errors="replace").read()
    except OSError: return (0, 0, False)
    sends = len(re.findall(r'\[[A-Za-z_][A-Za-z0-9_]* [a-zA-Z_]+[\]:]', t))
    kw = len(re.findall(r'@(selector|protocol|try|catch|synchronized|autoreleasepool|class|property|end)', t))
    return (sends, kw, '@interface' in t)

def is_c_file(p):
    if grep(p, r'@implementation'): return False
    sends, kw, iface = objc_usage(p)
    return not iface and kw == 0 and sends <= 5

def sweep_renames():
    out = []
    for p in m_files():
        if not is_c_file(p): continue
        rel = p.relative_to(ROOT).as_posix(); c = rel[:-2] + ".c"; sends = objc_usage(p)[0]
        extra = f" It has {sends} residual Objective-C call(s); replace each with the plain C equivalent (usually a logging macro or a Foundation call that oofnd now provides)." if sends else ""
        out.append((f"Rename C-in-.m file to .c: {p.name}", f"{rel} contains no Objective-C class (ADR-0012). Rename to {c}, add extern \"C\" guards to its header, adjust meson. Otherwise byte-identical code.{extra}",
                    [f"test -f {c}", f"! test -f {rel} && ! test -f {rel}m", f"! grep -nE '@(implementation|interface|selector|protocol)' {c}", f"tools/tier-a.sh {c}"], ["2.1"], "docs/decisions/0012-c-stays-c.md", 1))
    return out

def sweep_convert():
    out = []; presplit = []
    for p in m_files():
        if is_c_file(p): continue
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
        out.append((f"Convert to C++20: {p.name}", f"{what}\n\n## Files\n{files}",
                    [f"! grep -nE '@implementation|@interface|@selector|@protocol' {rel}" + (f" {hrel}" if hrel else ""), f"tools/tier-a.sh {rel}", "tools/tier-b.sh --fast"], [seam], f"seam:{seam}", MODULE_ORDER[mod]))
    return out, presplit

SWEEPS = [  # key, phase, label, generator
    ("scenarios", 0, sweep_scenarios), ("gui", 0, sweep_gui), ("js-retarget", 1, sweep_js_retarget),
    ("extractors", 2, sweep_extractors), ("foundation", 2, sweep_foundation), ("renames", 3, sweep_renames), ("convert", 3, None),
]

# ---------------------------------------------------------------- main
def body(desc, acceptance, exemplar, sweep, phase):
    acc = "\n".join(acceptance) if acceptance else "(human-verified; see acceptance field)"
    return f"Generated by tools/gen-stories.py · sweep {sweep} · Phase {phase} · exemplar: {exemplar}\n\n## Task\n{desc}\n\n**Do it the way `{exemplar}` does it.**\n\n## Acceptance (run by accept.sh in a clean checkout)\n```\n{acc}\n```\n\n{PROHIBITIONS}\n\n{SIZING}"

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--apply", action="store_true"); ap.add_argument("--dry-run", action="store_true"); ap.add_argument("--phase", type=int)
    ap.add_argument("--rewire", action="store_true", help="also re-add deps between beads that already existed (slow; default skips them)")
    a = ap.parse_args(); apply = a.apply and not a.dry_run
    titles = existing_titles()
    nodes = []; edges = []; ids = {}; node_title = {}
    def create(title, kind, phase, labels, desc, priority, parent=None, meta=None):
        if title in titles:  # already in bd: reference by id, do not recreate
            ids_key = "existing:" + titles[title]; ids[ids_key] = ids_key; return ids_key
        key = f"n{len(nodes)}"
        node = {"key": key, "title": title, "type": kind, "labels": labels, "description": desc, "priority": priority}
        if parent: node["parent_key"] = parent
        if meta: node["metadata"] = meta
        nodes.append(node); node_title[key] = title; return key
    deps = []
    for n, (name, doc) in PHASES.items():
        if a.phase is not None and n != a.phase: continue
        ids[f"epic{n}"] = create(f"Phase {n} — {name}", "epic", n, [f"phase:{n}", "epic"], f"See {doc}. Children are the seams (frontier) and the generated sweep beads (fleet).", 1)
    for key, n, title, desc, acc, dk, pri in SEAMS:
        if a.phase is not None and n != a.phase: continue
        ids[key] = create(title, "task", n, [f"phase:{n}", "frontier", f"seam:{key}"], body(desc or title, [], "n/a (seam)", f"seam {key}", n) + f"\n\n## Acceptance (human-verified)\n{acc}", pri, parent=ids.get(f"epic{n}"))
        for d in dk: deps.append((key, d))
    counts = {}; file_to_extractor = {}
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
            if skey == "foundation" and fname in file_to_extractor: deps.append((k, file_to_extractor[fname]))
        counts[skey] = len(items)
        for i, (title, desc, acc, dk, exemplar, pri) in enumerate(presplit):
            k = f"presplit:{i}"; ids[k] = create(title, "task", n, [f"phase:{n}", "frontier", "sweep:presplit"], body(desc, [], exemplar, "presplit", n) + "\n\n## Acceptance (human-verified)\nSlice plan in the bead notes; each slice reads under 1,500 lines.", pri, parent=ids.get(f"epic{n}"))
            for d in dk: deps.append((k, d))
        if presplit: counts["presplit"] = len(presplit)
    for k in list(ids):
        if ":" in k and not k.startswith(("epic", "existing:")):
            if k.startswith(("scenarios:", "gui:")): deps.append(("0.gate", k))
            elif k.startswith("js-retarget:"): deps.append(("1.7", k))
            elif k.startswith(("foundation:", "extractors:")): deps.append(("2.12", k))
            elif k.startswith(("renames:", "convert:", "presplit:")): deps.append(("3.giant-Universe", k))
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
    for b1, b2 in late:
        subprocess.run(["bd", "dep", "add", real(b1), real(b2), "-q"], capture_output=True)
    print(f"created {len(created)} beads; wired {len(late)} late deps")

if __name__ == "__main__":
    main()
