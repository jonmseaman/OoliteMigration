# Oolite in C++: a write-up after Phase 4

*Draft for the Oolite maintainers. Status as of 2026-10-27.*

## Summary

Oolite now builds and runs as a plain C++ program. As of 2026-10-21, the fork
[`jonmseaman/oolite`](https://github.com/jonmseaman/oolite) has:

- **No Objective-C.** There are no `.m` or `.mm` files left, and no libobjc or `-fobjc-*` flags.
- **No GNUstep.** `libgnustep-base` is gone. It was replaced by a small C++20 library, `oofnd`.
- **No SpiderMonkey.** The 2011 SpiderMonkey 1.8.5 engine was replaced by
  [QuickJS-ng](https://github.com/quickjs-ng/quickjs) v0.16.2, behind a thin C++ façade.
- **Two compilers.** It builds with both Clang and GCC on Windows x64. Both pass the unit suites and
  replay the recorded game-state goldens identically.

The whole conversion took about seven weeks of calendar time, from 2026-09-06 to 2026-10-21. It was
done almost entirely by AI coding agents (Claude) working through a queue of about 2,000 small,
individually tested work items ("beads"). I set up the plan, the tests and the guardrails, and
reviewed and merged pull requests. The game still plays.

This document covers:

1. Why I did it
2. How it was done
3. How it was tested
4. What each phase did, with its trade-offs
5. Known differences and open items
6. Ideas for what comes next

## 1. Why

- **Apple Silicon.** Oolite's SpiderMonkey 1.8.5 is from Firefox 4 (March 2011).
  - Its build system does not recognise `aarch64`, and its JIT has no arm64 backend.
  - That engine, not the game code, was the hard blocker for a native arm64 Mac build.
- **Unmaintained dependencies.**
  - The embedded JS engine gets no security fixes and builds with autoconf 2.13.
  - GNUstep works, but it is a heavy, niche dependency on Windows and Linux, and few contributors
    know it.
- **A bigger contributor pool.** Far more developers can read and modify C++ than Objective-C,
  and C++ tooling (clang-tidy, sanitizers, IDEs, CLion/VS Code) works out of the box.
- **An experiment in agent-driven migration.** I wanted to see whether a large legacy-language
  migration could be done by AI agents if the safety net was good enough. The answer looks like
  yes. For a game, the "good enough" part is most of the work.

> TODO(Jon): add a sentence or two on your personal motivation and history with Oolite.

### Scale

Before the migration, the game was:

- **506 Objective-C files and 224,817 lines:** 241 `.m` files with 183,603 lines, and 265 headers
  with 41,214 lines. Six files held 30% of the lines; ShipEntity alone was 14,945 lines with 565
  methods.
- **396 `@interface`s, 353 `@implementation`s, 210 categories and 22 protocols.**
- **About 2,100 retain/release/autorelease calls and about 11,000 Foundation references.**
- **3,828 SpiderMonkey `JS_*` call sites in 102 files.**

## 2. How

### Principles

The ground rules were written down as decision records (ADRs) before any code changed:

- **Conservative translation, no redesign.** Each class was translated in the same shape, so a
  reviewer could compare it side by side with the Objective-C. Ownership uses intrusive
  refcounting (`oo::Ref<T>`), not `shared_ptr`, so retain/release semantics carry over exactly.
- **C stays C.** Existing plain-C code and vendored C (MiniZip, etc.) were never rewritten. A file
  with no `@implementation` was not a conversion target.
- **The tests decide correctness.** No agent, me included, judged whether a change was "right".
  The goldens, sanitizers, the warning flags (`-Wall -Wextra`, never silenced) and a deny-list of
  forbidden symbols decided.
- **Bridge, then convert.** Each layer was replaced behind a seam while the rest of the game kept
  running:
  - a JS façade in front of SpiderMonkey before QuickJS-ng went in
  - `oofnd` in place of Foundation while the classes were still Objective-C
  - each class converted to C++ behind a thin Objective-C bridge, which was deleted afterwards
- **Every step is shippable.** At every merge the game built, launched and replayed the goldens.

### Workflow

- **Planning.** This planning repository holds the roadmap, phase docs, about 70 ADRs, the tooling
  and the goldens. The game is a submodule pointing at the fork's `develop` branch.
- **Work items.** A generator turned the phase docs into "beads" (issues in
  [beads](https://github.com/gastownhall/beads)). Each bead had to pass a seven-point sizing check:
  - it is small: at most 1,500 lines to read, 400 to write and 8 files
  - it has a command that fails before the change and passes after it
  - it introduces no new interfaces
  - it names an exemplar to copy the style from
- **Exemplars.** A stronger model converted the first classes (`OOColor`, then the OXP verifier)
  by hand, to set the house style. Every later conversion copied them.
- **Execution.** Claude Code ran a `beads-worker` skill in a loop. In each iteration it claimed a
  bead, branched with `git town`, implemented the change, passed the bead's acceptance command and
  opened a pull request. A bead closed only when I merged its PR; agents could not close their own
  work.
- **Hard rules, enforced by scripts.** Agents could never:
  - edit goldens
  - delete or weaken a test
  - silence a warning
  - push anything but their own feature branch
  - read untrusted expansion content outside a sandbox

### How the agents did

**What worked**

- **Throughput.** The bead count went from 155 closed to 2,009 closed in about four weeks.
- **The game kept running.** It stayed playable through the whole conversion. On 2026-10-07 I wrote
  "Amazingly, the game still runs and works even with all of Claude's changes."
- **Model choice.** Claude Opus could run the queue autonomously. Claude Sonnet needed about an hour
  of correction a day in the first week.
- **Testable plans.** Breaking work into small items, each with its own acceptance test, was what
  made this tractable.

**What didn't work**

- **Over-testing.** Early on, agents ran the full 30-minute suite on every commit. Per-bead gates
  had to be cut to a five-minute acceptance block, with the full suite (Tier C) run at phase
  boundaries.
- **Context loss.** Over days of context compaction the agents forgot instructions:
  - to parallelise
  - that they could use judgement on "human" items when otherwise blocked
  - that they were meant to run autonomously, so they prompted me again
  - The governance rules I wrote sometimes interacted badly with the agent's own interpretation of
    them, producing items that needlessly waited on me.
- **Resource hygiene.**
  - A worktree per bead, poorly cleaned up, reached about 300 GB of stale checkouts.
  - At one point there were about 250 background tasks, which saturated the CPU.
  - A fixed pool of workers, each in its own worktree, plus a proper merge queue (as in Gas Town)
    would have been better.
- **Stalling.** No supervisor restarted a stuck agent, so the loop sometimes just stopped.
- **Follow-up beads.** There was no reviewer gate before a PR, so many follow-up beads were filed
  after merge instead of being caught up front.
- **Undocumented compatibility.** The agents noticed that some expansions used SpiderMonkey-only
  JavaScript but did not document it at first. That documentation is now done; see §5.

## 3. Testing

The migration was only as safe as its tests, so Phase 0 built the safety net before any production
code changed.

### Making the game deterministic

- **Fixed seed.** A new `OO_RANDOM_SEED` environment variable seeds the RNG; previously it was
  seeded from the wall clock.
- **Stable iteration order.** The test harness shuffled `NSDictionary`/`NSSet` enumeration on
  purpose to expose code that depended on iteration order. Those bugs were fixed in the Objective-C
  first, so they could not show up as conversion "regressions".
- **Pinned floating point.** The build pins `-ffp-contract=off` and `-O2`. Every golden records the
  flags of each translation unit in its provenance file.

### Test tiers

| Tier | What | Budget | When |
|---|---|---|---|
| A | single-file compile, clang-tidy, deny-list, cast scan | < 30 s (measured 4–17 s) | every edit |
| B | full build, module tests, fast goldens, Tier-1 corpus subset | < 10 min | every PR |
| C | everything: all goldens, ASan, full Tier-1 corpus, JS API snapshot, GUI tier, unit suites, guard self-tests | 30–90 min | phase end |

### Test types

- **Goldens (state replay).** A scenario runs headless with a fixed seed. It dumps canonical,
  sorted JSON of:
  - every entity: role, position, velocity, AI state
  - the market (17 commodities)
  - the player: credits, cargo, legal status, ship
  - an evidence block: ticks, launch/dock counts
  - Floats are quantised to three decimals. A diff against the blessed golden fails the build, and
    only a human can re-bless.
  - Scenarios cover launch and dock, combat, trade cycles, missions, cloaking, save/load,
    Constrictor, Thargoid plans, novas, trumbles, shaders and materials, and the HUD.
- **Frame hashes.** Perceptual hashes of rendered frames, with a measured tolerance: the noise floor
  is about 0.0025 and a real change is 0.0075–0.065.
- **Unit tests.** 218 C++ test files: about 175 for core game classes and 40 for `oofnd`. `oofnd`
  alone has 353 tests and 4,856 checks, run plain and under AddressSanitizer.
- **Component tests (BDD).** pytest-bdd Gherkin scenarios drive a real game through the debug
  console and assert tolerant invariants rather than exact state. Examples: "police kill a
  pirate", "escorts converge on their mother", "a damaged ship flees".
- **GUI tests.** PyAutoGUI drives the real window (G1–G11): exit by mouse, keyboard and window
  close; the HUD renders; screens round-trip; first run creates defaults. A desktop lock stops two
  GUI runs from fighting over the foreground.
- **JS API snapshot.** The 1.93 scripting surface (61 globals, about 45 native classes) is recorded
  as JSON. Any drift fails.
- **Expansion corpus.** All 818 published expansions were scanned statically, and load-tested in
  three tiers: about 30 curated, 150, and all of them.
- **Fuzzing.** The new plist parser was fuzzed differentially against GNUstep:
  - 4,350 real plists from 813 archives, plus 320,384 mutants
  - result: 0 unexplained divergences; 6 `oofnd` bugs found and fixed, each with a unit test
- **Benchmark.** A string benchmark decided `std::string` vs. a custom string type. The
  representative copy model cost +0.1% golden wall-clock time, well inside the 5% threshold.
- **Mutation proofs for the tests themselves.** Each guardrail and tier has a self-test that plants
  a real violation and checks that it is caught. For example, a planted use-after-free must trip
  ASan, and a GUI test must not pass when nothing ran.

### Results at the end of Phase 4

- **Clang and GCC builds:** core unit tests 173/173 and `oofnd` 39/39 on each, and the goldens
  replay green. ASan is clean.
- **Phase 1 differential (SpiderMonkey vs. QuickJS-ng):** 0 golden diffs, 0 Tier-1 corpus diffs,
  0 JS API surface diffs.
- **Phase 4 review:** all 49 closed beads' acceptance commands were re-run, with no gaps found.

**Weakness, stated honestly:** only 2 goldens are blessed (`001` and `001-launch-dock`). Eighteen
more scenarios (002–020) are built and stable over 10 runs but are still waiting for me to bless
them. Most of the gameplay assurance therefore comes from the unit, component, GUI and corpus tiers
plus playtesting, not from goldens.

## 4. Phases

| Phase | What | Outcome |
|---:|---|---|
| 0 | Safety net | Done 2026-09-19 |
| 1 | JS engine: SpiderMonkey → QuickJS-ng | Done 2026-09-23 |
| 2 | `oofnd`: replace GNUstep Foundation | Done 2026-09-30 |
| 3 | Convert Objective-C classes to C++20 | Done 2026-10-20 |
| 4 | Remove the Objective-C runtime | Done 2026-10-21 |
| 5 | Apple Silicon and Linux x64 | Not started |
| 5b | JSON5 beside plists | Proposed |
| 6 | Modernise (C++23, GL 3.3 Core) | Not started |

### Phase 0: Safety net

- **What:** a reproducible Windows build (MSYS2 UCRT64, Clang), determinism fixes, the golden
  harness, the JS API snapshot, the expansion corpus, a JS lint for Mozilla-only constructs, the
  GUI and component tiers, the tier scripts, the guardrails, and the bead generator. Its first run
  produced 681 beads with 1,436 dependency edges.
- **Pros:** everything after this was measurable. The determinism fixes are small and could be
  taken upstream on their own.
- **Cons:** it was a large up-front investment before any visible progress, and some items
  (nightly scheduling, the full golden blessing) never finished.

### Phase 1: JS engine (SpiderMonkey 1.8.5 → QuickJS-ng)

- **What:**
  - A C++ façade, `ooscript/JSEngine.hpp`, sized to what Oolite actually uses.
  - All 3,828 `JS_*` sites retargeted onto it while SpiderMonkey still ran underneath.
  - A QuickJS-ng backend added and tested differentially against SpiderMonkey, then SpiderMonkey
    and NSPR deleted.
- **Why QuickJS-ng:** it is pure C, MIT-licensed, ES2023, and builds trivially on arm64, x64,
  Windows and Linux. It has a small embedding API and needs no Rust or autoconf. The alternatives
  were weaker:
  - Porting SM 1.8.5 to arm64 would keep an unpatched 2011 engine forever.
  - Modern mozjs would be a total API rewrite and would add Rust and Mozilla's build system on three
    platforms.
- **Pros:**
  - The engine is maintained, with modern JavaScript: `let`/`const`, classes, `Map`, `Promise`,
    and so on.
  - Engine symbols are confined to one file, so the engine can be swapped again later.
- **Cons:** this goes beyond a pure language conversion, and it is the main compatibility risk for
  expansions. SpiderMonkey-only JavaScript stops working; see §5.

### Phase 2: `oofnd`, the Foundation replacement

- **What:**
  - The build switched to Objective-C++ (`.m` → `.mm`, C++20).
  - A C++20 library replaced Foundation:
    - `Ref`/`WeakRef`/`AutoreleaseScope`
    - `PList`, with old-style and XML parsers and writers
    - typed `PList::get<T>`, which retired about 1,800 `oo_*ForKey:` sites
    - UTF-8 strings that reproduce GNUstep's answers
    - filesystem, defaults and logging
  - Every Foundation use was migrated while the classes were still Objective-C, and then
    `libgnustep-base` was unlinked.
- **Pros:** GNUstep is gone. The replacement is small, tested, and fuzzed against the original.
- **Cons:**
  - The plist fuzz oracle linked GNUstep, so it cannot be re-run now.
  - Some intentional plist differences exist; they are listed in an ADR.

### Phase 3: Objective-C → C++20

- **What:** about 500 files were converted, from the leaves inward.
  - Each class became `cxx::X` behind a temporary `X+ObjCBridge` façade, and a separate bead later
    deleted the bridge.
  - The six giant files were pre-split into checked "slice plans": ShipEntity 38 slices,
    PlayerEntity 28, Universe 26, and others. A stronger model handled them.
  - Selectors called by name became explicit tables.
  - 728 beads were filed: 203 conversions, 196 bridge deletions, 175 slices, and the rest presplits,
    renames and seams.
- **Pros:** conversions are line-for-line comparable with the original, and the game stayed playable
  between every merge.
- **Cons:**
  - The code reads as "Objective-C written in C++" rather than idiomatic C++. That is by design, and
    it is the main target of Phase 6.
  - The bridge/delete cycle doubled the number of PRs.
  - Mac-only code paths were deliberately not converted; Phase 5 rewrites them.

### Phase 4: Remove the Objective-C runtime

- **What:** libobjc2 and all `-fobjc-*` flags were dropped, `.mm` files were renamed to `.cpp`, and
  a GCC build was restored beside Clang. 52 beads; done 2026-10-21.
- **Pros:**
  - The program is a plain C++ program, and two compilers keep the code portable.
  - The GCC goldens replay takes 17 s.
- **Cons and leftovers:**
  - `oo::AutoreleaseScope` survives as a C++ deferred-release pool, in 25 files. Removing it changes
    object lifetimes, so it is a deliberate later decision.
  - The Mac-only `#if OOLITE_MAC_OS_X` Objective-C arms and `GameController+FullScreen.mm` remain,
    for Phase 5.
  - Dead GNUstep-era macros and scripts still need cleanup.

### Phase 5 (planned): Apple Silicon and Linux x64

- **Plan:**
  - A macOS meson build with Apple Clang, SDL3 and legacy GL 2.1.
  - An `.app` bundle with signing and notarisation.
  - Port the residual platform code.
  - Fix arm64 issues: alignment, `long` width, FMA. `-ffp-contract=off` is the insurance against
    FMA.
  - Add macOS arm64 and Linux x64 goldens and GUI tests to Tier C.
- **Estimate:** 1–2 engineer-months.
- **Upstream PRs:** this is also where the upstream pull requests were planned to be batched.

### Phase 6 (planned): Modernise

- **Plan:**
  - C++23 (`std::expected`, `std::print`)
  - a GL 3.3 Core renderer
  - value semantics for leaf classes, and `unique_ptr` where ownership is single
  - split up `Universe`
  - a `jthread` job system
  - revisit C++ modules

## 5. Known differences and open items

### Expansion (OXP/OXZ) compatibility

The biggest user-visible change is the JS engine.

- **Static lint of all 818 expansions (1,997 scripts):** only 5 Mozilla-only hits, in 2 expansions:
  - `toSource()` in Library
  - legacy `__defineGetter__`-style accessors in GalCopMissions
- **Load test on QuickJS-ng:**
  - Tier 1: 30 of 36 pass; the one failure also fails on SpiderMonkey.
  - Tier 2: 109 of 150 pass.
  - Tier 3: 595 of 813 pass.
  - Most non-passes are dependency or manifest issues that fail on any engine (e.g. a missing
    `requires_oxps`, bad plists, version-range mismatches).
- **Failures caused by the engine change:**
  - **Legacy JS 1.7 generators** (`yield` in a plain `function`) are now a `SyntaxError`. This
    affects Thargoid.Wildships, Thargoid.Aquatics and Montana05's Kestrel/Falcon.
  - **Strict-mode bugs SpiderMonkey tolerated now throw.** Examples: undeclared names
    (InterstellarTweaks, Towbar, Taranis, Untrumbled), writing a property onto a string
    (RoutePlanner), and deleting a permanent property (Snoopers).
  - Two cases were fixed in the game, so authors change nothing: `new` on a native function
    (Griff's Asteroids and others), and bare-name scope resolution (BUS MegaBat).
- **Removed and not polyfilled:** `for each`, E4X, `let (…)` blocks, expression closures,
  conditional `catch`, `watch`/`unwatch`, `Iterator`/`StopIteration`, `RegExp.$1`–`$9`,
  `toLocaleFormat`, and `fileName`/`lineNumber` on errors.
- **Polyfilled in the game:** `toSource`, `String.prototype.quote`, `uneval`, and the Array/String
  generics (e.g. `Array.forEach(list, fn)`). These are best-effort, not byte-identical.
- **Other observable changes:**
  - QuickJS-ng's error-message wording differs from SpiderMonkey's.
  - Writes to read-only native properties are silently ignored instead of throwing.
  - New standard globals (`Map`, `Promise`, `globalThis`) can trip "namespace pollution" checks.
- **Help for authors:**
  - a migration guide: `docs/EXPANSION_MIGRATION.md`
  - a lint tool: `tools/oxp-js-lint/`
  - a list of known content failures
- **Not compared:** JS performance against SpiderMonkey was never measured.

### Other open items

- Bless the remaining goldens, 002–020.
- Playtest findings:
  - a blank screen when starting the tutorial
  - unclear controls on the menus
  - some default key bindings not working: 1–4 views, W/A
  - a repeated-undock-on-`1` bug, now fixed
  - Some of these may already be in the base game; they need a check against upstream.
- Code hygiene:
  - remove obsolete `GNUSTEP` macros and scripts
  - remove bead and ADR references from source comments
  - reduce macro use
  - move unit tests beside their sources
  - adopt a real `.clang-format` and `.clang-tidy`; the current one is WebKit, left from the
    Objective-C era
- A systematic before/after behaviour comparison of Objective-C vs. C++, beyond what the tests
  cover.

## 6. Future ideas

- **Native Apple Silicon and Linux x64.** This is Phase 5 and the original goal.
- **Upgrade QuickJS-ng** to 0.17 and keep tracking releases.
- **Data formats:** JSON5 beside plists (proposed).
  - JSON5 parses into the same tree, and JSON5 wins if both formats exist.
  - A converter, `plist2json5`, comes with it.
  - Saved games stay as they are.
  - The risk is two formats forever, and expansions using JSON5 won't load on older builds.
- **Menus and controls:** fine-tune menu navigation, make controls discoverable, and check default
  bindings.
- **Rendering:** a GL 3.3 Core renderer. Later, possibly Vulkan or Metal via a portability layer.
- **Idiomatic C++:**
  - C++23
  - `unique_ptr` where ownership is single, and value types for small classes
  - remove `AutoreleaseScope`
  - break up `Universe`, `ShipEntity` and `PlayerEntity`
  - fewer macros
- **Tooling:**
  - a Google-style `.clang-format` and `.clang-tidy`, applied once in a single reformat commit
    recorded in `.git-blame-ignore-revs`
  - a CLion/VS Code setup guide for Windows
- **TypeScript for expansions.** Type definitions for the scripting API, so authors can write
  TypeScript that compiles to the JS QuickJS-ng runs.
- **Concurrency:** a job system for AI and physics updates.
- **CI:** hosted CI running Tier B on all three platforms. This project deliberately ran only local
  verification.

## Links

- Fork: <https://github.com/jonmseaman/oolite> (`develop`)
- Migration repo: `jonmseaman/OoliteMigration`. Start with `ROADMAP.md`; per-phase detail is in
  `docs/phases/` and decisions are in `docs/decisions/`.
- Expansion author guide: `docs/EXPANSION_MIGRATION.md`
