---
status: New
branch: seriesb/030-json5-data-files
parent: seriesb/029-cpp-component-tests
---

On hold with 029 (Jon, 2026-11-17). Restacked 2026-11-17 to the top of the stack (028 → 031 →
032 → 033 → 029 → 030). The tip commit, `Restack: 032's cleanups and 033's renames in 030's code`,
leaves the tree identical to the old `seriesb/033-drop-oo-prefix` tip (`136a77bb7`). 032's
`Restack fix: the JSON5 writer's date year is std::int64_t` moved here because it only touches
030's code.
