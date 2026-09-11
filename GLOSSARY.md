# Glossary

Terms used across the roadmap, phase docs, and execution model. Agents: read this once.

| Term | Meaning |
|---|---|
| **Adjudicator** | Frontier-model role that examines a *failed* check and proposes whether the diff is legitimate. Proposes only; never decides. |
| **ADR** | Architecture decision record, `docs/decisions/NNNN-*.md`. Append-only. |
| **Bead** | Gas City's unit of tracked work. One bead ≈ one L3 story. Closed only by the wrapper. |
| **C1–C6** | The six expansion-compatibility contracts (plist dialect, JS API, JS language level, legacy scripting, resource resolution, string expansion). [architecture §5](docs/architecture.md). |
| **Converter** | Agent role that translates one unit in its own worktree branch. Never pushes to main. |
| **Deny-list** | CI grep that fails on reintroduced `libgnustep-base` or `JS_*` symbols. |
| **Exemplar** | An already-landed path a story points at: "do it the way `<path>` does it". Sizing check 7. |
| **Fleet** | The set of memoryless agents consuming L3 stories under Gas City. |
| **Freeze policy** | Once Phase 3 starts on a module, upstream changes to it are ported by hand, tracked in `docs/UPSTREAM_DELTA.md`. |
| **G1–G9** | The PyAutoGUI GUI smoke tests. [phases/0-gui-tier.md](docs/phases/0-gui-tier.md). |
| **Golden** | A committed canonical state dump (sorted JSON) plus frame hashes for one scenario. Byte-compared. |
| **Golden harness** | The containerised runner that launches the real game headless, drives it over the debug-console TCP channel, and emits the dump. |
| **Harness steward** | Standing role that owns the safety net's integrity: flake rate, drift. May fix harness code; may never re-bless. |
| **I0–I4** | Infra-track items: machines, base images, forge/runners, fleet, metrics. [docs/infra/](docs/infra/). |
| **L0–L3** | Grain levels: phase / plan item / component / story. The fleet consumes L3. |
| **Mayor / Polecat / Refinery / Witness / Deacon / Dogs / Crew** | Gastown-pack role names for orchestrator / converter / merge queue / per-rig watchdog / cross-rig watchdog / helpers / human. |
| **Merge queue, batch-and-bisect** | Tier C runs once over a batch of Tier-B-green PRs; on failure, bisects to the culprit. Gas City's Refinery. |
| **`oofnd`** | The in-tree C++20 Foundation replacement (String, PList, Ref, FileSystem, Defaults, Logging). |
| **`oo::Ref<T>` / `WeakRef<T>`** | Intrusive refcounting mirroring ObjC retain/release. Not `shared_ptr`. [ADR-0003](docs/decisions/0003-intrusive-refcount.md). |
| **OXP / OXZ** | Oolite expansion pack, unpacked directory / zipped. Data + JS + assets; never native code. |
| **R1–R5** | The five ranked risks: SpiderMonkey, GNUstep Foundation, manual refcounting, legacy OpenGL, no tests + fast upstream. |
| **Re-bless** | Replacing a golden after an intentional behaviour change. The one human-only gate. |
| **Reporter** | Read-only scheduled role that reports the I4 metrics. Zero write authority. |
| **Reviewer** | Advisory agent role. Comments only; never a gate. |
| **Seam** | A design decision that must exist before a sweep can start. Fails sizing checks 5 and 7. Human + frontier work. |
| **Seven-check sizing rule** | The test a story must pass to be fleet-ready. [execution-model §8.2](docs/execution-model.md). |
| **Story** | An L3 work unit: ≤ 1,500 lines read, ≤ 400 written, ≤ 8 files, command-shaped acceptance, no new interfaces, 2–3 sentences, names an exemplar. |
| **Sweep** | A set of replication stories generated from an inventory command against one seam's exemplar. |
| **TCC** | macOS privacy grants (Accessibility, Screen Recording). Per-app, interactive, cannot be scripted. Why the macOS GUI tier needs a self-hosted runner. |
| **Tier A / B / C** | In-loop (< 30 s, offline, compiler-only) / per-PR (< 10 min, one platform) / per-merge-batch (all platforms, sanitizers, everything). |
| **Tier 1 / 2 / 3 corpus** | ~30 / ~150 / all expansions, run per-commit / nightly / weekly. Distinct from Tier A/B/C. |
| **Verification vs. adjudication** | Verification (did behaviour change?) is decided by goldens, sanitizers, deny-lists. Adjudication (is a failed check legitimate?) is proposed by a model and decided by Jon. |
| **WSL2** | Windows Subsystem for Linux. Hosts Gas City, the agents, and the Linux build/golden/sanitizer leg on the single Windows machine until Phase 5. [ADR-0010](docs/decisions/0010-single-windows-machine.md). |
| **Wrapper** | The external process that runs a story's acceptance commands and is the only thing allowed to mark a bead done. |
