# Audit brief (for each auditor)

You are auditing **behavioural parity** between the original Objective-C Oolite and its C++ port.

- **Upstream (reference, read-only):** `C:\Users\jon\OoliteMigration\upstream\oolite\src\<path>.m` (+ `.h`)
- **Port (read-only except Doc/parity):** `C:\Users\jon\OoliteMigration\oolite-dev\.claude\worktrees\cpp-objc-code-comparison-e96d6e\src\<path>.cpp` (+ `.h`/`.hpp`)
- Foundation replacement library: `src/oofnd/*.hpp` (see `src/oofnd/README.md`). JS engine façade: `src/Core/Scripting/ooscript/JSEngine.hpp` + `JSEngine_quickjs.cpp` (SpiderMonkey 1.8.5 → QuickJS-ng; see `ooscript/README.md`).

## What to do, per file assigned

1. Open your findings file's section for the file. It has a pre-filled **coverage table**: one row per upstream ObjC method / C function, with its upstream line. The extractor is regex-based. Add any rows it missed (e.g. static functions defined over several lines, property tables, JSFunctionSpec/JSPropertySpec tables) and delete false rows.
2. For **every row**, find the C++ counterpart and read **both bodies side by side**. Fill the `C++ counterpart` column with `Name` + `file:line` (port path relative to `src/`). Fill `Verdict` with one of:
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
4. Set `**Status:**` to `done — N rows: a ✅ b ⚠️ c ❌ d ➖`.
5. Don't judge from names or comments alone: read the code. Don't speculate about behaviour without citing lines. Keep each bullet to 1–3 lines.

## Hard rules

- Write **only** the findings file(s) named in your assignment, inside `Doc/parity/`.
- Never touch `src/`, tests, goldens or `Doc/parity/README.md`. Never commit, push or run `bd`.
- Do not read OXP/OXZ expansion content.
- Do not fix anything. This is an audit.
- Use Edit for exact replacements. If your assignment says "part file", create that new file containing your completed `## <Name>` section(s) verbatim (same heading and anchor as in the main findings file), so they can be merged.

## Final reply (keep it under 20 lines)

One line per file: `<file> — <status line> — top issue (if any)`. Then up to 5 most important ❌ findings with severity. Nothing else.
