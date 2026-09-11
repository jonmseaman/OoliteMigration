# Glossary

Terms used across the roadmap, phase docs, and execution model. Agents: read this once.

| Term | Meaning |
|---|---|
| **Adjudicator** | Frontier-model role that examines a *failed* check and proposes whether the diff is legitimate. Proposes only; never decides. |
| **ADR** | Architecture decision record, `docs/decisions/NNNN-*.md`. Append-only. |
| **Bead** | A `bd` (beads) issue. One bead = one L3 story; its body is the story, its notes are the carry-over channel. Closed only by the wrapper. |
| **C1–C6** | The six expansion-compatibility contracts (plist dialect, JS API, JS language level, legacy scripting, resource resolution, string expansion). [architecture §5](docs/architecture.md). |
| **Component tier** | The third test tier: Gherkin scenarios (pytest-bdd) driven over the debug-console channel, asserting named tolerant invariants — "no pirate remains after 900 ticks". Diagnoses what the goldens only detect. [phases/0-component-tier.md](docs/phases/0-component-tier.md), [ADR-0018](docs/decisions/0018-component-test-tier.md). |
| **Converter** | Agent role that translates one unit in its own worktree branch. Never pushes to main. |
| **Deny-list** | Tier B/C grep that fails on reintroduced `libgnustep-base` or `JS_*` symbols. |
| **Exemplar** | An already-landed path a story points at: "do it the way `<path>` does it". Sizing check 7. |
| **Fleet** | The agents consuming `bd ready`: memoryless `claude -p` runs under `tools/fleet/run-story` (frontier tier) and the Hermes `/goal` loop (local tier). Both close beads only through `tools/fleet/accept`. |
| **Freeze policy** | Once Phase 3 starts on a module, upstream changes to it are ported by hand, tracked in `docs/UPSTREAM_DELTA.md`. |
| **G1–G9** | The PyAutoGUI GUI smoke tests. [phases/0-gui-tier.md](docs/phases/0-gui-tier.md). |
| **Golden** | A committed canonical state dump (sorted JSON) plus frame hashes for one scenario. Byte-compared. |
| **Golden harness** | The runner that launches one real game process per scenario (native, Mesa llvmpipe, own port), drives it over the debug-console TCP channel, and emits the dump. |
| **Harness steward** | Standing role that owns the safety net's integrity: flake rate, drift. May fix harness code; may never re-bless. |
| **I0–I5** | Infra-track items: the machine, provisioning, forge (deferred), fleet, metrics, the Hermes runbook. [docs/infra/](docs/infra/). |
| **L0–L3** | Grain levels: phase / plan item / component / story. The fleet consumes L3. |
| **Merge queue, batch-and-bisect** | Tier C runs once over a batch of Tier-B-green bead branches; on failure, bisects to the culprit. `tools/merge-queue`, an in-repo script. |
| **`oofnd`** | The in-tree C++20 Foundation replacement (String, PList, Ref, FileSystem, Defaults, Logging). |
| **`oo::Ref<T>` / `WeakRef<T>`** | Intrusive refcounting mirroring ObjC retain/release. Not `shared_ptr`. [ADR-0003](docs/decisions/0003-intrusive-refcount.md). |
| **OXP / OXZ** | Oolite expansion pack, unpacked directory / zipped. Data + JS + assets; never native code. |
| **R1–R5** | The five ranked risks: SpiderMonkey, GNUstep Foundation, manual refcounting, legacy OpenGL, no tests + fast upstream. |
| **Re-bless** | Replacing a golden after an intentional behaviour change. The one human-only gate; Jon works a weekly queue of Adjudicator proposals. |
| **Reporter** | Read-only scheduled role that reports the I4 metrics. Zero write authority. |
| **Reviewer** | Advisory agent role. Comments only; never a gate. |
| **S1–Sn** | The component-tier Gherkin scenarios. S1 is the seam and exemplar; S2–S8 are its sweep. [phases/0-component-tier.md](docs/phases/0-component-tier.md). |
| **Seam** | A design decision that must exist before a sweep can start. Fails sizing checks 5 and 7. Human + frontier work. |
| **Seven-check sizing rule** | The test a story must pass to be fleet-ready. [execution-model §8.2](docs/execution-model.md). |
| **Story** | An L3 work unit: ≤ 1,500 lines read, ≤ 400 written, ≤ 8 files, command-shaped acceptance, no new interfaces, 2–3 sentences, names an exemplar. |
| **Sweep** | A set of replication stories generated from an inventory command against one seam's exemplar. |
| **TCC** | macOS privacy grants (Accessibility, Screen Recording). Per-app, interactive, cannot be scripted. Why the macOS GUI tier runs on Jon's Mac. |
| **Subtree** | `upstream/oolite` is a `git subtree` of the fork, not a submodule: one repo, one branch per bead, one merge. `git subtree push` mirrors it to the fork's `migration` branch. [ADR-0017](docs/decisions/0017-native-windows-subtree.md). |
| **Tier A / B / C** | In-loop (< 30 s, offline, compiler-only) / per bead branch (< 10 min, headless) / per merge batch (every supported platform, ASan, the GUI tier, everything). |
| **Tier 1 / 2 / 3 corpus** | ~30 / ~150 / all expansions, run per-commit / nightly / weekly. Distinct from Tier A/B/C. |
| **Verification vs. adjudication** | Verification (did behaviour change?) is decided by goldens, sanitizers, deny-lists. Adjudication (is a failed check legitimate?) is proposed by a model and decided by Jon. |
| **WSL2** | Not used. Everything runs natively on Windows until Phase 5. [ADR-0017](docs/decisions/0017-native-windows-subtree.md). |
| **Wrapper** | `tools/fleet/run-story`: claims a bead, runs `claude -p` in a worktree, then calls `accept`. The frontier-tier driver. |
| **Claude Code** | Anthropic's agent CLI. Frontier role: seams, adjudication, giant files, interactive sessions; `claude -p` headless for stories; scheduled tasks for the Reporter. |
| **Hermes Agent** | Open-source agent with persistent memory and many LLM providers. In `/goal` mode it works until `tools/fleet/goal-check <phase>` passes, against the on-prem endpoints. The local tier's driver ([ADR-0015](docs/decisions/0015-hermes-goal-loop.md)). |
| **`accept`** | `tools/fleet/accept <bead>`: runs the story's acceptance commands in a fresh clone of the bead's branch and is the only thing that runs `bd close`. |
| **`goal-check`** | `tools/fleet/goal-check <phase>`: exit 0 iff no open bead carries both `phase:<N>` and `fleet`. The Hermes `/goal` condition. |
