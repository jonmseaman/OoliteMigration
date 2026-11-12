# Contract: check mapping

What `convert.py` does to a test file, and what `parity.py static` accepts as "the same check".
Anything not in this table is a hand edit and goes in `test-ledger.md`.

## Structure

| Old | New |
|---|---|
| `#include "oo_test.hpp"` | `#include <gtest/gtest.h>` (plus `#include "oo_gtest.hpp"` only if the file has a value site) |
| `OO_TEST(name) { ... }` | `TEST(<Stem>, name) { ... }` |
| `OO_TEST_MAIN()` | removed (the shared `main` is linked) |
| hand registration in a custom `main` (`test_plist_hdr_brightness_index`) | a `TEST(<Stem>, name)` per registered function, in registration order |
| set-up in a custom `main` (`test_OoliteEquipmentControlScript`) | a `::testing::Environment` subclass whose `SetUp` does the same, registered by `AddGlobalTestEnvironment` from a static initialiser; its checks move into `TEST`s in the order `main` ran them |

## Checks

| Old | New | Notes |
|---|---|---|
| `OO_CHECK(c);` | `EXPECT_TRUE(c);` | non-fatal, as before |
| `OO_CHECK_EQ(a, b);` | `EXPECT_EQ(a, b);` | prints both values on failure (FR-007) |
| `CHECK(c)` (equipment-control test) | `EXPECT_TRUE(c)` | |
| `CHECK_JS(cx, code)` | the macro's body keeps its evaluation; its inner check becomes `EXPECT_TRUE` | wrapper rule below |
| `x = OO_CHECK(c)`, `if (OO_CHECK(c))`, `return OO_CHECK(c)`, `OO_CHECK(c) && ok` | `OO_EXPECT_V(c)` in the same position | value site |
| the same with `OO_CHECK_EQ(a, b)` | `OO_EXPECT_EQ_V(a, b)` | value site |

A site is a **value site** when the macro is not the whole of an expression statement: the token
before it is not `{`, `;`, `}`, `)` closing an `if`/`for`/`while` head, or `else`, or the token
after its closing parenthesis is not `;`.

## Wrapper macros

`OO_CHECK_EVAL`, `OO_CHECK_LOG`, `OO_CHECK_TEXT`, `OO_CHECK_PAGE`, `OO_CHECK_CALLS`, `CHECK_JS`:
only the definition changes (its inner `OO_CHECK_EQ` → `EXPECT_EQ`, `OO_CHECK` → `EXPECT_TRUE`).
Call sites are untouched, and `parity.py` counts each call site as one site of the wrapper's
kind. The helpers they call (`EvalShown`, `LogShown`) are unchanged.

## `oo_gtest.hpp`

```cpp
// Expression forms for the sites that use a check's result. Non-fatal; each operand once.
#define OO_EXPECT_V(cond)      ::oo_gtest::expectTrue(static_cast<bool>(cond), #cond, __FILE__, __LINE__)
#define OO_EXPECT_EQ_V(a, b)   ::oo_gtest::expectEq((a), (b), #a, #b, __FILE__, __LINE__)
```

`expectTrue` reports through `ADD_FAILURE_AT(file, line) << expr` and returns `ok`. `expectEq`
compares with `==` once, and on failure reports `ADD_FAILURE_AT(file, line)` with `#a == #b`
and both values via `::testing::PrintToString`, then returns the result. Public Google Test API
only.

## Known differences (fix in the test, ledger it; never suppress)

| Difference | Symptom | Fix |
|---|---|---|
| `EXPECT_EQ` compares through a template | GCC `-Wsign-compare` on `EXPECT_EQ(3, v.size())` | matching literal: `3u` |
| operands bind to `const T&` | a bit-field operand does not compile | `+s.field` |
| operands must be printable | none: Google Test prints the bytes of a type with no `<<` or `PrintTo` | none needed; a `PrintTo` for a game type may be added later as a new file, not in a batch |
| `EXPECT_EQ(nullptr, p)` vs `OO_CHECK_EQ(p, nullptr)` | none: argument order is kept as written | none |
| `EXPECT_EQ` on two `const char*` | compares pointers, as `==` did | none (not `EXPECT_STREQ`, which would be a change of meaning) |

## What `parity.py static` checks

For each file: the ordered list of case names is equal before and after; within each case and
each helper function, the ordered list of (mapped kind, expression) is equal; the totals per file
are equal. It prints every difference and exits 1 on any, 0 otherwise, 2 on a parse failure.
