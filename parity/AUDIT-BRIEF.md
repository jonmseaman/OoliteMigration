# Audit brief (for each auditor)

You are auditing **behavioural parity** between the original Objective-C Oolite and its C++ port.
The coordinator follows [METHOD.md](METHOD.md) and gives you an assignment with the exact paths below.

- **Upstream (reference, read-only):** `<UPSTREAM>/<path>.m` (+ `.h`), normally `C:\Users\jon\OoliteMigration\upstream\oolite\src`
- **Port (read-only):** `<PORT>/<path>.cpp` (+ `.h`/`.hpp`), a detached worktree of the audited oolite-dev commit, normally `C:\Users\jon\OoliteMigration\.worktrees\parity-<branch>\src`
- **Your part file (the only file you write):** `<RUN>/parts/<area>.<NN>.md`
- **The previous audit's findings (read-only, for comparison):** `<PREV>/<area>.md`
- Foundation replacement library: `src/oofnd/*.hpp` (see `src/oofnd/README.md`). JS engine façade: `src/Core/Scripting/ooscript/JSEngine.hpp` + `JSEngine_quickjs.cpp` (SpiderMonkey 1.8.5 → QuickJS-ng; see `ooscript/README.md`).

## What to do, per section in your part file

1. Each `## <Name>` section has a pre-filled **coverage table**: one row per upstream ObjC method or C function, with its upstream line. The extractor is regex-based. Add any rows it missed (e.g. static functions defined over several lines, functions defined by macros, property tables, JSFunctionSpec/JSPropertySpec tables) and delete false rows (declarations, macros that aren't functions). If the section header names no port file, find where the behaviour went and name it in the `Upstream … ↔ …` line.
   - A comment like `<!-- rows 1-200 of 645 -->` means another auditor has the rest of this section. Audit only your rows. Add missed rows only if they fall inside your line range.
2. For **every row**, find the C++ counterpart and read **both bodies side by side**. Fill the `C++ counterpart` column with `Name` + `file:line` (port path relative to `src/`). Fill `Verdict` with exactly one of:
   - ✅ equivalent (same logic, same constants, same edge cases, same order of side effects)
   - ⚠️ intentional divergence (only if code/comment/ADR/bead id says so; cite it)
   - ❌ suspected behaviour difference
   - ➖ removed/replaced (say where the behaviour went, or that it is gone)
3. Under **Differences:**, list every non-✅ item, plus anything subtle, as bullets in this form:
   `- ❌ **high|med|low** — <what differs and the observable effect> — upstream \`Core/X.m:123\` ↔ port \`Core/X.cpp:456\``
   Things to look for:
   - changed constants or defaults
   - inverted or dropped conditions
   - missing nil-messaging semantics (ObjC `[nil foo]` returns 0/nil; C++ null deref or different default)
   - integer vs float math, signed/unsigned changes, and `NSUInteger` → `int` narrowing
   - dictionary key spelling changes (`oo_*ForKey:` defaults vs `get<T>(key, fallback)`)
   - string formatting/localisation, and the iteration order of dict/set (`NSDictionary` order vs `std::map`/`unordered_map`)
   - retain/autorelease lifetime vs `oo::Ref`, weak refs
   - exception vs error-return paths
   - missing logging (log message classes matter to goldens)
   - floating-point order changes
   - early returns, and for JS bindings: argument validation, error/warning text, return types, property enumerability and read-only flags
4. **Compare with the previous audit.** Open the same section in `<PREV>/<area>.md`. For every previous non-✅ finding, check whether it still holds on this commit and mark the bullet:
   - `(still open)`, with the new port line;
   - `(fixed since <prev date>)`, citing the commit, the code that changed, or the test that now covers it. It then gets a ✅ row; keep the bullet so the change is recorded;
   - `(new)` for a finding the previous audit did not have, including regressions in rows that were ✅.
   Don't copy the previous verdicts: re-read the code. The previous file only tells you where to look harder.
5. Set `**Status:**` to `done — N rows: a ✅ b ⚠️ c ❌ d ➖` (the merge script recomputes it from the Verdict column, so every row must have exactly one verdict symbol).
6. Don't judge from names or comments alone: read the code. Don't speculate about behaviour without citing lines. Keep each bullet to 1–3 lines.

## Hard rules

- Write **only** your assigned part file. Never touch `src/`, tests, goldens, `parity/README.md` or any other part file. Never commit, push, switch branches or run `bd`.
- Do not read OXP/OXZ expansion content.
- Do not fix anything. This is an audit.
- Fill verdicts by hand with Edit, after reading both bodies. Never generate rows or verdicts with a script: a scripted ✅ can't be told apart from one that was checked. On ✅ rows that aren't obvious, add a few words on what you compared.
- Keep the section headings, anchors (`<a id=…>`) and `<!-- rows … -->` comments exactly as given, so the parts can be merged.
- Keep the table to three columns. Don't put `|` inside a cell (write `\|` or "or").

## Final reply (keep it under 20 lines)

One line per section: `<Name> — <status line> — top issue (if any)`. Then up to 5 most important ❌ findings with severity, marking each (new), (still open) or (fixed). Nothing else.
