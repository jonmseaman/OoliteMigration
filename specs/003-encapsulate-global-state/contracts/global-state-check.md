# Contract: `tests/global_state_check.py`, the inventory and the ratchet

A stdlib-only Python 3 script, committed `100755` with a `#!/usr/bin/env python3` shebang. It is
modelled on `tests/idiom_check.py` (research R9, R10).

## Command line

```text
global_state_check.py --build-dir DIR [--inventory FILE] [--ratchet FILE]
                      [--check inventory|ratchet|all] [--list] [--count] [--self-test]
```

| Mode | What it does |
|---|---|
| `--check inventory` | Lists the mutable globals in the objects under `DIR` and compares them with the inventory. |
| `--check ratchet` | Counts the tracked tokens in comment-stripped source under `src/` and compares them with the ratchet. |
| `--check all` | Both. This is the default. |
| `--list` | Prints every mutable global found as an inventory row with `status=todo`. It is used once, to seed the inventory. |
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
- **Excluded:** symbols starting `_ZGV` (guard variables), `vtable for`, `typeinfo`,
  `__emutls_`, and `.refptr.`/`__imp_` stubs.
- **Vendored code:** symbols from `src/Core/MiniZip/` and `src/SDL/stb_image_write.h` are
  included, and must be rows with `status=kept`.

## Inventory: `tests/global-state/inventory.tsv`

The file has a header row, tab-separated values, and rows sorted by `object` then `symbol`:

```text
symbol	object	category	owner	headless	status	reason
(anonymous namespace)::sDeferredCalls	Core/GameController.cpp	session	OOGame	yes	todo
sRANROT	Core/legacy_random.cpp	session	OORandomState	yes	todo
```

**Findings (exit 1) when:**
- a symbol is found that has no row;
- a row marked `todo` or `kept` has no matching symbol;
- a row marked `encapsulated` still has a matching symbol;
- a `kept` row, or any row with category `process-kept`, has an empty reason;
- a field holds a value outside the allowed set in [data-model.md](../data-model.md);
- the rows are not sorted.

A static symbol's name is not unique across objects, so `(object, symbol)` is the key.

## Ratchet: `tests/global-state/ratchet.json`

```json
{
  "tokens": ["UNIVERSE", "PLAYER", "OOGameContext::current", "sharedController",
             "sharedRegistry", "sharedEngine", "sharedMixer", "..."],
  "ceilings": {
    "UNIVERSE": {"total": 3600, "Core/Entities": 2600, "Core/Scripting": 400, "...": 0}
  }
}
```

Counts are whole-word matches in comment- and literal-stripped source, using `idiom_check.py`'s
stripper.

**Findings when:**
- a count is above its ceiling;
- a count is below its ceiling. The ceiling must be lowered in the same commit, so that progress
  is recorded.

## meson

```meson
test('global-state', python3, args: [files('tests/global_state_check.py'), '--build-dir',
     meson.project_build_root()], suite: 'core', depends: oolite_bin, timeout: 120)
```

It is registered beside the `headers` suite. For now it sits inside the Windows guard, like the
other unit suites; it moves out when Phase 5 lifts the guard.
