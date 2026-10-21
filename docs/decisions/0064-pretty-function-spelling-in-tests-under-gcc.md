# ADR-0064: Tests that pin `__PRETTY_FUNCTION__` text, under GCC

- Status: Accepted on recorded default by the orchestrator under Jon's 2026-10-20 delegation
  (bead oo-4d403; docs/decisions/delegated-2026-10-19.md). Proposed in bead oo-1q4, batch BJ,
  2026-10-21.
- Date: 2026-10-21
- Beads: oo-1q4 (seam 4.3, GCC build green), the human bead filed with this ADR

## Context

With ADR-0063 items 4 and 5 done, the GCC `test` build compiles every target and its game matches
every blessed golden. Three test failures were left (batch BJ, GCC 16.2); one was evaluation order
in a test (test_OOCombinedEmissionMapGenerator, fixed under std-2026-10-19). The other two pin the
text of `__PRETTY_FUNCTION__`, which the language leaves to the compiler:

| Check | Clang spells | GCC spells |
|---|---|---|
| test_OOJSConsole.cpp:623, :639 (OOJSConsole.cpp `ReportNotTheMonitor(..., __PRETTY_FUNCTION__)`) | `bool ConsoleConsoleMessage(ooscript::Context, ooscript::CallArgs &)` | `... ooscript::CallArgs&)` |
| oofnd test_objc_assert.cpp:70, :74 (`OOCAssert`, `OOCParameterAssert`) | `void (anonymous namespace)::CFail(int)`, `CParam(void *)` | `void {anonymous}::CFail(int)`, `CParam(void*)` |

The game's text is the compiler's own: a JavaScript "internal error, please report it" message and
an assertion reason, both diagnostics. Upstream Oolite built with GCC on Linux printed GCC's spelling.

## Decision

Under GCC (`!defined(__clang__)`), those four checks expect GCC's spelling of the same signature;
under Clang every expected string stays byte-identical. Nothing in the game changes. The
alternative - normalising the function name in the game so both compilers print Clang's spelling -
rewrites diagnostic plumbing to hide a compiler difference and is not recommended.

## Consequences

Before this decision, oo-1q4's acceptance (GCC core and oofnd suites) fails on exactly these four
checks; the GCC build itself, its 171 other core tests, 38 other oofnd tests and the goldens on the
GCC game are green.
