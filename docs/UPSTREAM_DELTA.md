# Upstream delta

Upstream changes to modules Phase 3 has frozen, ported by hand. The policy is
[architecture §6.3](architecture.md) item 5, made concrete by
[proposed ADR-0059](decisions/0059-upstream-freeze-policy.md); the monthly
[upstream-tracker task](fleet/upstream-tracker-prompt.md) is the only writer of the delta table.
`bash tools/upstream-delta.sh --check` proves this file well formed and the policy in force.

## How the freeze works

- **A module is one directory** under `upstream/oolite/src` (not its subdirectories).
- **Frozen** means: the monthly `git subtree pull --squash` does not change it. The tracker pulls,
  then `tools/upstream-delta.sh --restore-frozen <pre-pull commit>` puts every frozen module back
  as it was, and each upstream commit that touched a frozen module becomes a row below and a
  `fleet` bead that ports it by hand into the converted code (goldens decide whether the port is
  right, as for any bead).
- **Open** means: the pull's merge is taken as is; the tracker resolves its conflicts in the
  sync commit, under the same gates as any bead.
- A module is frozen the moment it holds Phase 3 work (a `cxx::` class or an `+ObjCBridge`
  facade). `--check` fails when such a module is still open, and when a new source directory is
  not in the table, so a conversion that starts a module cannot forget to freeze it. Freezing is
  one-way until Phase 6.
- Migration-owned directories (no upstream counterpart: `oofnd`, `Core/Scripting/ooscript`) are
  listed frozen; upstream never touches them, so they cost nothing.
- Everything outside `src/` (`Resources/`, `Doc/`, `Schemata/`, build files, ...) is open.

Baseline: `dc55e3e05cd283ff3a0c5e04d5d6a6d001a92c20` (the upstream commit `upstream/oolite` was
added from, 2026-09-10, `05bbbda17`). The tracker moves it forward after each sync.

## Modules

Frozen since Phase 3 began (2026-09-29, the OOColor exemplar, bead oo-11m) unless noted.

<!-- modules:begin -->
| Module | Status | Why |
|---|---|---|
| `src/Core` | frozen | Phase 3 classes (OOColor and successors) |
| `src/Core/Debug` | open | no Phase 3 work yet |
| `src/Core/Entities` | frozen | Phase 3 classes (Entity) |
| `src/Core/Materials` | frozen | Phase 3 classes |
| `src/Core/MiniZip` | open | vendored C, never converted (ADR-0012) |
| `src/Core/OXPVerifier` | frozen | Phase 3 classes (verifier stages) |
| `src/Core/Scripting` | frozen | Phase 3 classes; the ooscript facade replaced SpiderMonkey (Phase 1) |
| `src/Core/Scripting/ooscript` | frozen | migration-owned (ADR-0002); not in upstream |
| `src/Core/Tables` | open | data tables, no classes |
| `src/oofnd` | frozen | migration-owned (oofnd); not in upstream |
| `src/oofnd/objc` | frozen | migration-owned (ADR-0029); not in upstream |
| `src/SDL` | frozen | Phase 3 classes (joystick manager) |
| `src/SDL/EXRSnapshotSupport` | open | no Phase 3 work yet |
| `src/SDL/OOResourcesWin` | open | resources only |
<!-- modules:end -->

## Delta

One row per upstream commit that touched a frozen module since the baseline. Status is `to-port`
(bead filed), `ported` (bead closed) or `not-applicable` (the change is to code the migration
deleted or replaced; say why in the subject cell).

<!-- delta:begin -->
| Upstream commit | Date | Module | Subject | Status | Bead |
|---|---|---|---|---|---|
<!-- delta:end -->
