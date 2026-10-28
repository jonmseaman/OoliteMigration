# ADR-0069: Scan every catalogued expansion for QuickJS-ng incompatibilities; notes per expansion, no code in the repo

- Status: Proposed — default in effect (Claude Code, 2026-10-27, on Jon's direction in chat; rule 10)
- Date: 2026-10-27
- Refines: [ADR-0002](0002-quickjs-ng.md) (the corpus scan is a deliverable),
  [ADR-0023](0023-built-in-mozilla-compat-polyfills.md) (no new polyfills),
  [execution-model §5.5](../execution-model.md) (untrusted input never meets write authority)

## Context

Phase 1 replaced SpiderMonkey 1.8.5 with QuickJS-ng. The evidence that expansions still work is:

- a 9-rule regex lint (`tools/oxp-js-lint`): 9 findings in 5 of 818 expansions;
- load-only corpus runs. Tier 2/3 had 45/813 failing, triaged by inference, because no Tier 2/3
  SpiderMonkey baseline exists ([report](../phases/1-corpus-tier23-report.md)).

The lint has known holes. There is no `for each` rule, nothing for the removed APIs, and nothing for
code that parses but behaves differently.

Jon, 2026-10-27, made four decisions:

1. **Scan all 818 expansions first.** Look carefully at the code for incompatibilities, record notes
   for each expansion, and write the migration how-to. He will update the expansions himself later,
   if the C++ conversion is going well.
2. **Engine divergences are documented, not emulated.**
3. **Generated caches stay out of the repo.**
4. **The later behavioural differential uses the official 1.93.1.16 release as its SpiderMonkey
   reference.**

## Decision

1. **Three layers.** Programs read the code first. A model reads it only inside a sandbox.
   - **Parse.** `tools/oxp-js-parse` compiles every `.js` member of every cached expansion with the
     game's own pinned QuickJS-ng (`oolite-dev/subprojects/quickjs-ng.wrap`). It compiles only and
     never runs anything. It uses the game's flags: `JS_EVAL_TYPE_GLOBAL`, `JS_EVAL_FLAG_COMPILE_ONLY`,
     line 1. It runs twice: as shipped, and with the `"use strict";` prefix the game adds under
     `OOEnforceStandards()` (`OOJSScript.cpp`).
   - **Rules.** `tools/oxp-js-lint` rules flag code that parses but behaves differently. They are
     graded BREAKS, CHANGED or INFO.
   - **Model review.** A model reviews the code in a sandbox: a headless agent with read-only tools
     confined to one extracted expansion outside the repo, no repo, no network, no MCP and no
     secrets. Only schema-constrained JSON comes out, and a deterministic ingester validates it.
2. **The parse is the ground truth for syntax.** Every QuickJS-ng `SyntaxError` is a BREAKS
   finding, whatever rule names it. A failure that no rule explains is `syntax-other`, which points
   at a gap in the guide.
3. **No expansion code enters any repo.**
   - Findings carry the file, line, column, rule, severity and the engine's message, truncated to 160
     characters.
   - The ingester rejects any model note that contains a 40-character run of the source.
   - The before/after examples in the guide are synthetic.
4. **Notes are committed; bytes and extracts are not.**
   - Notes live in `tools/oxp-scan/expansion-notes.json` (818 entries, pinned to each expansion's
     sha256), `docs/expansions/README.md`, and one page per expansion with findings.
   - Archives stay in the existing out-of-repo cache. Extracts go to
     `%LOCALAPPDATA%/OoliteMigration/oxp-scan/`.
5. **The model's recall is measured, not trusted.**
   - A deterministic BREAKS finding that the model did not report is recorded as `model-miss`.
   - A first-party injection fixture proves that an instruction planted in a comment cannot hide a
     finding.
   - A random audit list of 50 expansions is produced for Jon ([ADR-0005](0005-defer-dgx-spark.md)).
     It is non-blocking.
6. **This pass changes nothing in the game and fixes no expansion.**

## Consequences

- `docs/EXPANSION_MIGRATION.md` becomes the how-to: a workflow, then one anchored section per rule
  id, linked from every note.
- The bulk model review costs money. The spike measures tokens per expansion and projects the cost
  before the bulk run.
- A re-fetched expansion whose bytes change makes its note stale. Notes are never silently reused.
- The behavioural differential (a tracer OXP on 1.93.1.16 and on HEAD, run three times each for a
  noise floor) is the next pass, ordered by these notes.

## History

Planned 2026-10-27 in a Claude Code session. Jon chose the official-release reference, out-of-repo
storage, document-only divergences, and all 818 expansions up front. He then narrowed the first
pass to a code scan with notes and a guide.
