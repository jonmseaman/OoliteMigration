# Upstream delta

Upstream changes to modules Phase 3 has frozen, ported by hand. The policy is
architecture §6.3 item 5, made concrete by
proposed ADR-0059; the monthly
upstream-tracker task is the only writer of the delta table.
`bash tools/upstream-delta.sh --check` proves this file well formed and the policy in force.

## How the freeze works

- **A module is one directory** under `oolite-dev/src` (not its subdirectories).
- **Frozen** means: the monthly `git subtree pull --squash` does not change it. The tracker pulls,
  then `tools/upstream-delta.sh --restore-frozen <pre-pull commit>` puts every frozen module back
  as it was, and each upstream commit that touched a frozen module becomes a row below and a
  `fleet` bead that ports it by hand into the converted code (goldens decide whether the port is
  right, as for any bead).
- **Open** means: the pull's merge is taken as is; the tracker resolves its conflicts in the
  sync commit, under the same gates as any bead.
- A module is frozen the moment it holds Phase 3 work (a `cxx::` class or an `+ObjCBridge`
  facade). `--check` fails when such a module is still open, and when a new source directory is
  not in the table, so a conversion that starts a module cannot forget to freeze it:
  `tools/guardrails.sh` runs `--check` on every change (bead oo-9ht.70). Freezing is
  one-way until Phase 6.
- Migration-owned directories (no upstream counterpart: `oofnd`, `Core/Scripting/ooscript`) are
  listed frozen; upstream never touches them, so they cost nothing.
- Everything outside `src/` (`Resources/`, `Doc/`, `Schemata/`, build files, ...) is open.

Baseline: `9ee8ff22f20f4552530e4ee2696d680538b068d7` (OoliteProject master, synced 2026-10-25 by
bead oo-we7mm, subtree squash `566695b05`; the first baseline was `dc55e3e05`, 2026-09-10,
`05bbbda17`). The tracker moves it forward after each sync.

## Modules

Frozen since Phase 3 began (2026-09-29, the OOColor exemplar, bead oo-11m) unless noted.

<!-- modules:begin -->
| Module | Status | Why |
|---|---|---|
| `src/Core` | frozen | Phase 3 classes (OOColor and successors) |
| `src/Core/Debug` | frozen | Phase 3 classes (OODebugMonitor, bead oo-kq7; frozen 2026-10-01 by oo-9ht.70) |
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
| 822d4a9b5 | 2026-09-15 | `src/Core` | #737 Rename OOCocoa to OOFoundation and remove some crud: OOCocoa.h/.cpp became OOFoundation.h/.cpp, every include follows, the Mac crud and GameController+FullScreen.mm are gone | ported | oo-we7mm |
| 822d4a9b5 | 2026-09-15 | `src/Core/Debug` | #737 Rename OOCocoa to OOFoundation and remove some crud: OOCocoa.h/.cpp became OOFoundation.h/.cpp, every include follows, the Mac crud and GameController+FullScreen.mm are gone | ported | oo-we7mm |
| 822d4a9b5 | 2026-09-15 | `src/Core/Entities` | #737 Rename OOCocoa to OOFoundation and remove some crud: OOCocoa.h/.cpp became OOFoundation.h/.cpp, every include follows, the Mac crud and GameController+FullScreen.mm are gone | ported | oo-we7mm |
| 822d4a9b5 | 2026-09-15 | `src/Core/Materials` | #737 Rename OOCocoa to OOFoundation and remove some crud: OOCocoa.h/.cpp became OOFoundation.h/.cpp, every include follows, the Mac crud and GameController+FullScreen.mm are gone | ported | oo-we7mm |
| 822d4a9b5 | 2026-09-15 | `src/Core/OXPVerifier` | #737 Rename OOCocoa to OOFoundation and remove some crud: OOCocoa.h/.cpp became OOFoundation.h/.cpp, every include follows, the Mac crud and GameController+FullScreen.mm are gone | ported | oo-we7mm |
| 822d4a9b5 | 2026-09-15 | `src/Core/Scripting` | #737 Rename OOCocoa to OOFoundation and remove some crud: OOCocoa.h/.cpp became OOFoundation.h/.cpp, every include follows, the Mac crud and GameController+FullScreen.mm are gone | ported | oo-we7mm |
| 822d4a9b5 | 2026-09-15 | `src/SDL` | #737 Rename OOCocoa to OOFoundation and remove some crud: OOCocoa.h/.cpp became OOFoundation.h/.cpp, every include follows, the Mac crud and GameController+FullScreen.mm are gone | ported | oo-we7mm |
| 75cf78f51 | 2026-09-16 | `src/Core/Entities` | #740 Remember last saved game: "last_savename" in the user defaults, AppKit panels and load/save macros removed (tables regenerated; test lastsaveNameIsRememberedInTheDefaults) | ported | oo-we7mm |
| 663dd2a99 | 2026-09-17 | `src/Core` | #742 OOJoystickManager GCC warning: one STICK_DEADZONE for every platform ported; the decoder move is not (the C++ base class keeps them, the unit tests drive them there, and the GCC build has no such warning, ADR-0063) | ported | oo-we7mm |
| 663dd2a99 | 2026-09-17 | `src/SDL` | #742 decoders moved into OOSDLJoystickManager: not applicable, the C++ OOJoystickManager decodes (see the src/Core row) | not-applicable | oo-we7mm |
| dfe203868 | 2026-09-19 | `src/SDL` | #744 Remove undocumented Microsoft API usage (dark mode) and the WINDOW_MOVED re-grab | ported | oo-we7mm |
| ad5288b4a | 2026-09-20 | `src/Core` | #745 Add missing selectors: renames Objective-C selector labels; the C++ has no selectors and no by-name or callObjC row names one (generators --check unchanged) | not-applicable | oo-we7mm |
| ad5288b4a | 2026-09-20 | `src/Core/Entities` | #745 Add missing selectors: renames Objective-C selector labels; the C++ has no selectors and no by-name or callObjC row names one (generators --check unchanged) | not-applicable | oo-we7mm |
| ad5288b4a | 2026-09-20 | `src/Core/Materials` | #745 Add missing selectors: renames Objective-C selector labels; the C++ has no selectors and no by-name or callObjC row names one (generators --check unchanged) | not-applicable | oo-we7mm |
| ad5288b4a | 2026-09-20 | `src/Core/Scripting` | #745 Add missing selectors: renames Objective-C selector labels; the C++ has no selectors and no by-name or callObjC row names one (generators --check unchanged) | not-applicable | oo-we7mm |
| ad5288b4a | 2026-09-20 | `src/SDL` | #745 Add missing selectors: renames Objective-C selector labels; the C++ has no selectors and no by-name or callObjC row names one (generators --check unchanged) | not-applicable | oo-we7mm |
| 54cf49a7c | 2026-09-24 | `src/Core` | #747 Common SDL3 stringToClipboard, Linux mouse control, copy-URL key (test copyUrlKey) | ported | oo-we7mm |
| 54cf49a7c | 2026-09-24 | `src/Core/Entities` | #747 Common SDL3 stringToClipboard, Linux mouse control, copy-URL key (test copyUrlKey) | ported | oo-we7mm |
| 54cf49a7c | 2026-09-24 | `src/SDL` | #747 Common SDL3 stringToClipboard, Linux mouse control, copy-URL key (test copyUrlKey) | ported | oo-we7mm |
| 0a8207ead | 2026-09-24 | `src/Core` | #748 Include fixes for clang-format include sorting: the C++ tree builds after sorting; OOFoundation.h keeps winsock2.h before windows.h apart from the sort | ported | oo-we7mm |
| 0a8207ead | 2026-09-24 | `src/Core/Debug` | #748 Include fixes for clang-format include sorting: the C++ tree builds after sorting; OOFoundation.h keeps winsock2.h before windows.h apart from the sort | ported | oo-we7mm |
| 0a8207ead | 2026-09-24 | `src/Core/Entities` | #748 Include fixes for clang-format include sorting: the C++ tree builds after sorting; OOFoundation.h keeps winsock2.h before windows.h apart from the sort | ported | oo-we7mm |
| 0a8207ead | 2026-09-24 | `src/Core/Materials` | #748 Include fixes for clang-format include sorting: the C++ tree builds after sorting; OOFoundation.h keeps winsock2.h before windows.h apart from the sort | ported | oo-we7mm |
| 0a8207ead | 2026-09-24 | `src/Core/Scripting` | #748 Include fixes for clang-format include sorting: the C++ tree builds after sorting; OOFoundation.h keeps winsock2.h before windows.h apart from the sort | ported | oo-we7mm |
| 0a8207ead | 2026-09-24 | `src/SDL` | #748 Include fixes for clang-format include sorting: the C++ tree builds after sorting; OOFoundation.h keeps winsock2.h before windows.h apart from the sort | ported | oo-we7mm |
| f52cca672 | 2026-09-24 | `src/Core` | #749 clang-format code: the converted tree formatted with upstream .clang-format (WebKit), clang-format 22; generated tables are clang-format off | ported | oo-we7mm |
| f52cca672 | 2026-09-24 | `src/Core/Debug` | #749 clang-format code: the converted tree formatted with upstream .clang-format (WebKit), clang-format 22; generated tables are clang-format off | ported | oo-we7mm |
| f52cca672 | 2026-09-24 | `src/Core/Entities` | #749 clang-format code: the converted tree formatted with upstream .clang-format (WebKit), clang-format 22; generated tables are clang-format off | ported | oo-we7mm |
| f52cca672 | 2026-09-24 | `src/Core/Materials` | #749 clang-format code: the converted tree formatted with upstream .clang-format (WebKit), clang-format 22; generated tables are clang-format off | ported | oo-we7mm |
| f52cca672 | 2026-09-24 | `src/Core/OXPVerifier` | #749 clang-format code: the converted tree formatted with upstream .clang-format (WebKit), clang-format 22; generated tables are clang-format off | ported | oo-we7mm |
| f52cca672 | 2026-09-24 | `src/Core/Scripting` | #749 clang-format code: the converted tree formatted with upstream .clang-format (WebKit), clang-format 22; generated tables are clang-format off | ported | oo-we7mm |
| f52cca672 | 2026-09-24 | `src/SDL` | #749 clang-format code: the converted tree formatted with upstream .clang-format (WebKit), clang-format 22; generated tables are clang-format off | ported | oo-we7mm |
| 574ca848c | 2026-10-10 | `src/Core` | #758 Clang 23 and deployment build fixes: its src change moves OOFoundation.h's Foundation import, which the C++ header no longer has (the script changes came with the merge) | not-applicable | oo-we7mm |
| 9ee8ff22f | 2026-10-25 | `src/Core` | #756 Debug monitor enabled in release build: OO_DEBUG_MONITOR_ENABLED guards the debug-monitor code; deployment builds compile and run with the console | ported | oo-we7mm |
| 9ee8ff22f | 2026-10-25 | `src/Core/Debug` | #756 Debug monitor enabled in release build: OO_DEBUG_MONITOR_ENABLED guards the debug-monitor code; deployment builds compile and run with the console | ported | oo-we7mm |
| 9ee8ff22f | 2026-10-25 | `src/Core/Entities` | #756 Debug monitor enabled in release build: OO_DEBUG_MONITOR_ENABLED guards the debug-monitor code; deployment builds compile and run with the console | ported | oo-we7mm |
| 9ee8ff22f | 2026-10-25 | `src/Core/Materials` | #756 Debug monitor enabled in release build: OO_DEBUG_MONITOR_ENABLED guards the debug-monitor code; deployment builds compile and run with the console | ported | oo-we7mm |
| 9ee8ff22f | 2026-10-25 | `src/Core/Scripting` | #756 Debug monitor enabled in release build: OO_DEBUG_MONITOR_ENABLED guards the debug-monitor code; deployment builds compile and run with the console | ported | oo-we7mm |
| 9ee8ff22f | 2026-10-25 | `src/SDL` | #756 Debug monitor enabled in release build: OO_DEBUG_MONITOR_ENABLED guards the debug-monitor code; deployment builds compile and run with the console | ported | oo-we7mm |
<!-- delta:end -->

Outside the frozen modules the 2026-10-25 sync took upstream as merged: #369
(`oolite-equipment-control.js`, pinned by test_OoliteEquipmentControlScript), #747's key and
descriptions, #751's clang-format job (replicated locally by `tools/check-clang-format.sh`),
#756's scripts and options, #758/#765's GNUstep pins and package lists (unused by the C++ build on
Windows and Linux; the Windows list also gains `icu`, which oofnd needs).
