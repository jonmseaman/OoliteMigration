# Glossary

Terms used across the roadmap, phase docs, and execution model. Agents: read this once.

| Term | Meaning |
|---|---|
| **Adjudicator** | Frontier-model role that examines a *failed* check and proposes whether the diff is legitimate. Proposes only; never decides. |
| **ADR** | Architecture decision record, `docs/decisions/NNNN-*.md`. Append-only. |
| **Bead** | A `bd` (beads) issue. One bead = one L3 story; its body is the story, its notes are the carry-over channel. Closed only by the wrapper. |
| **C1–C6** | The six expansion-compatibility contracts (plist dialect, JS API, JS language level, legacy scripting, resource resolution, string expansion). [architecture §5](docs/architecture.md). |
| **Component tier** | The third test tier: Gherkin scenarios (pytest-bdd) driven over the debug-console channel, asserting named tolerant invariants — "no pirate remains after 900 ticks". Diagnoses what the goldens only detect. [phases/0-component-tier.md](docs/phases/0-component-tier.md), [ADR-0018](docs/decisions/0018-component-test-tier.md). |
| **Converter** | Agent role that translates one unit on the bead's own branch in `oolite-dev`. Never pushes an integration branch. |
| **Deny-list** | Tier B/C grep that fails on reintroduced `libgnustep-base` or `JS_*` symbols. |
| **Exemplar** | An already-landed path a story points at: "do it the way `<path>` does it". Sizing check 7. |
| **Fleet** | The Claude Code workers consuming `bd ready` through the `beads-worker` skill, one bead per `/loop` iteration. None of them closes a bead: Jon's merge does ([ADR-0014](docs/decisions/0014-claude-code-opencode-beads.md)). |
| **Freeze policy** | Once Phase 3 starts on a module, upstream changes to it are ported by hand, tracked in `docs/UPSTREAM_DELTA.md`. |
| **G1–G9** | The PyAutoGUI GUI smoke tests. [phases/0-gui-tier.md](docs/phases/0-gui-tier.md). |
| **Golden** | A committed canonical state dump (sorted JSON) plus frame hashes for one scenario. Byte-compared. |
| **Golden harness** | The runner that launches one real game process per scenario (native, Mesa llvmpipe, own port), drives it over the debug-console TCP channel, and emits the dump. |
| **Harness steward** | Standing role that owns the safety net's integrity: flake rate, drift. May fix harness code; may never re-bless. |
| **I0–I5** | Infra-track items: the machine, provisioning, forge (deferred), the worker, metrics. Folded into [ROADMAP.md](ROADMAP.md)'s infra track. |
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
| **Submodule layout** | `oolite-dev` (the fork's `develop`, the game being migrated) and `oolite-main` (its `master`) are submodules of `jonmseaman/oolite`; `upstream/*` are OoliteProject's repositories, unmodified. Replaced the subtree layout on 2026-10-27. [ADR-0067](docs/decisions/0067-submodules-replace-subtrees.md). |
| **Tier A / B / C** | In-loop (< 30 s, offline, compiler-only) / per bead branch (< 10 min, headless) / per merge batch (every supported platform, ASan, the GUI tier, everything). |
| **Tier 1 / 2 / 3 corpus** | ~30 / ~150 / all expansions, run per-commit / nightly / weekly. Distinct from Tier A/B/C. |
| **Verification vs. adjudication** | Verification (did behaviour change?) is decided by goldens, sanitizers, deny-lists. Adjudication (is a failed check legitimate?) is proposed by a model and decided by Jon. |
| **Claude Code** | Anthropic's agent CLI. Frontier role: seams, adjudication, giant files, interactive sessions; `claude -p` headless for stories; scheduled tasks for the Reporter. |
| **`land`** | `.claude/skills/beads-worker/scripts/land.sh`: closes every `proposed` bead whose pull request Jon merged. The only path to `bd close`. |
| **`accept`** | `.claude/skills/beads-worker/scripts/accept.sh <bead>`: runs the bead's acceptance commands and, only if they all pass, opens its pull request with `git town propose`. It does not close the bead. |
| **`queue-check`** | `.claude/skills/beads-worker/scripts/queue-check.sh <selector>`: exit 0 iff no bead matching the selector is still actionable. Tells `/loop` when to stop. |
