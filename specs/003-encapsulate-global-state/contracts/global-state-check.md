# Contract: `tests/global_state_check.py`, the inventory and the ratchet

A stdlib-only Python 3 script, committed `100755` with a `#!/usr/bin/env python3` shebang
(research R9, R10). It imports `strip_comments_and_literals` from
`tests/check_debug_monitor_guards.py`, the remaining Python check, and keeps that script's exit
codes (0 clean, 1 findings), adding 2 for a usage error.

## Command line

```text
global_state_check.py --build-dir DIR [--inventory FILE] [--ratchet FILE]
                      [--check inventory|ratchet|all] [--list] [--count] [--self-test]
```

| Mode | What it does |
|---|---|
| `--check inventory` | Lists the mutable globals in the objects under `DIR` and compares them with the inventory. |
| `--check ratchet` | Counts the tracked tokens in comment-stripped source under `src/` and compares them with the ratchet. |
| `--check all` | Both. The default. |
| `--list` | Prints every mutable global found as an inventory row with `status=todo`. Used once, to seed the inventory. |
| `--count` | Prints the current token counts in ratchet JSON shape. |
| `--self-test` | Runs built-in fixtures: sample `nm` output, sample source. |

**Exit codes:** `0` clean · `1` findings · `2` usage or environment error (no `nm`, no objects).

**Output:** one finding per line, `path: symbol: message`, then a summary line,
`global-state: N globals, M todo, K kept; ratchet ok|N over`.

## How symbols are found

- **Objects:** the object files of the `oolite` target, found through `compile_commands.json`
  in `DIR`.
- **Tool:** `llvm-nm --defined-only --demangle` with Clang, `nm -C --defined-only` with GCC.
- **Mutable:** symbol types `b B d D`, plus `s S` on Mach-O when the section is a data section.
  Spec 009's never-deleted singletons (`static auto& s = *new T()`) appear as the reference's
  storage and are inventoried like any other static.
- **Excluded:** guard variables (`_ZGV`, "guard variable for"), `vtable for`, `typeinfo`,
  `__emutls_`, and `.refptr.`/`__imp_` stubs.
- **Vendored code:** symbols from `src/Core/MiniZip/`, `src/SDL/EXRSnapshotSupport/` and the
  `stb_*` headers are included, and must be rows with `status=kept`.

## Inventory: `tests/global-state/inventory.tsv`

Header row, tab-separated values, rows sorted by `object` then `symbol`:

```text
symbol	object	category	owner	headless	status	reason
(anonymous namespace)::sDeferredCalls	Core/GameController.cpp	session	OODeferredCalls	yes	todo
gSharedUniverse	Core/Universe.cpp	session	bridge	yes	todo	register until M6b
sRANROT	Core/legacy_random.cpp	session	OORandomState	yes	todo
```

**Findings (exit 1) when:**
- a symbol is found that has no row;
- a row marked `todo` or `kept` has no matching symbol;
- a row marked `encapsulated` still has a matching symbol;
- a `kept` row, or any row with category `process-kept`, has an empty reason;
- a field holds a value outside the allowed set in [data-model.md](../data-model.md);
- the rows are not sorted.

`(object, symbol)` is the key, because a static's name is not unique across objects.

## Ratchet: `tests/global-state/ratchet.json`

```json
{
  "tokens": ["UNIVERSE", "PLAYER", "gSharedUniverse", "gOOPlayer", "OOGameContext::current",
             "OOGameContext::process", "sharedController", "sharedRegistry", "sharedEngine",
             "sharedCache", "sharedMixer", "..."],
  "ceilings": {
    "UNIVERSE": {"total": 3632, "Core/Entities": 2600, "Core/Scripting": 400, "...": 0}
  }
}
```

Counts are whole-word matches in comment- and literal-stripped source **under `src/` only**.
Tests may keep using the bridge until M6b (research R10, R15).

**Findings when:**
- a count is above its ceiling;
- a count is below its ceiling: the ceiling must be lowered in the same commit, so progress is
  recorded.

## meson

```meson
test('global-state', python3, args: [files('tests/global_state_check.py'), '--build-dir',
     meson.project_build_root()], suite: 'core', depends: oolite_bin, timeout: 120)
```

Registered beside the `headers` suite, inside the Windows guard like the other unit suites; it
moves out when Phase 5 lifts the guard.
