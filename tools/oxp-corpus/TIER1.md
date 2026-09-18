# OXP corpus Tier 1 (bead oo-het)

Tier 1 is the per-commit expansion smoke set: ~30 catalogue expansions plus the
6 test-oxps from `upstream/oolite-tests/test-oxps`, each loaded on a headless
build with an assertion that it really loaded and produced no error lines.

    tools/corpus.sh list          # the committed set (offline)
    tools/corpus.sh regen         # regenerate tier1.json from the corpus
    tools/corpus.sh check-list    # assert the committed list is not stale
    tools/corpus.sh selftest      # offline proof the vacuity guards discriminate
    tools/corpus.sh tier1         # load every Tier 1 expansion (~10 min)
    tools/corpus.sh tier1 --limit 3          # cheap smoke subset
    tools/corpus.sh tier1 --only NAME        # one expansion

---

## 1. How Tier 1 was chosen, and why it is a proxy

**The corpus contains no popularity signal.** That is measured, not assumed.
Every one of the 818 cached expansions has a top-level `manifest.plist`; across
all 818 the complete key set is:

> identifier, version, title, required_oolite_version, category, author,
> license/licence, description, information_url, download_url, file_size, tags,
> requires_oxps/requires_oxp, optional_oxps, conflict_oxps, upload_date,
> maximum_version, maximum_oolite_version

No download count, no rating, no install count, no rank. The upstream catalogue
(`upstream/oolite-expansion-catalog/expansionUrls.txt`) is a bare URL list with
no metadata at all. So **"most-installed" cannot be read off the data we have**,
and a list of 30 famous names recalled from memory would be an assertion rather
than a selection.

### The proxy: dependency in-degree

Rank by the number of *other* corpus expansions that name this expansion's
identifier in `requires_oxps` (hard) or `optional_oxps` (soft).

The argument is mechanical: if K expansions hard-require X, then every user who
installs any of those K has X installed too. In-degree is therefore a **strict
lower bound on install breadth** relative to the rest of the corpus. It is
computed from bytes we have, it is reproducible from the committed manifest plus
the content-addressed cache, and every edge traces back to a named
`manifest.plist` inside a sha256-pinned OXZ.

### Known biases, stated rather than hidden

- **Over-weights libraries, under-weights leaf content.** A hugely popular
  standalone ship pack that nothing depends on scores 0.
- **Sparse graph.** Only 177 of 818 manifests declare any dependency, so the
  tail of the ranking is all ties at 0.
- **Self-reported.** An undeclared dependency contributes no edge.

Because of the first two, the rule has a second band:

- **Band A — dependency hubs:** every expansion with in-degree >= 1, descending.
- **Band B — category breadth:** fill the remainder over the in-degree-0 tail,
  round-robin across the corpus's own `category` field, preferring the most
  `tags` then the smallest byte size. Once the hub band is exhausted, the most
  useful property for a per-commit gate is *coverage of different loader code
  paths* at low cost — a 40 kB OXP that exercises the same path as an 80 MB one
  is the better choice for a gate that runs on every commit.

Ties break on `(-score, identifier)`, so the output is stable across machines.
On the current corpus Band A alone supplies all 30 (in-degree 26 down to 3), so
Band B is currently empty — it exists for when the corpus changes.

The 6 test-oxps are appended unconditionally; they are named by the bead and are
source directories, not catalogue OXZs. They are discovered from the tree.

---

## 2. Why "no ERROR lines" needs proof before it means anything

`grep -c ERROR == 0` passes trivially when the game never launched, never loaded
the expansion, or never wrote the log. All three happen routinely here.

**The committed proof is a real artifact**:
`tools/oxp-corpus/fixtures/dead-initgl-Latest.log` — an actual launch on this
machine with `/ucrt64/bin` on PATH. It writes its version banner, records its own
command line at `[process.args]`, negotiates an 8-bpcc GL buffer, prints the
V-Sync warning, then dies at exit 87 (`ERROR_INVALID_PARAMETER`), 1476 bytes, 19
lines, having loaded nothing. **It contains zero lines matching ERROR.** A naive
check calls it green.

Note what that rules out: the banner, the CPU line, the build-options line and
`[process.args]` are all present in the corpse, so none of them can serve as
evidence of loading.

### The five positive assertions

Nothing is concluded from the absence of errors until all five hold:

| | assertion | why it cannot be faked |
|---|---|---|
| P1 | **LAUNCH** — the process ran and wrote a log | a death before any log is reported as LAUNCH, never PASS |
| P2 | **LOG** — banner present, >= 40 lines, in this run's *private* `OO_LOGSDIR` | bound sits above the 19-line corpse; private dir means it cannot be a stale file |
| P3 | **SHIPDATA** — `[shipData.load.begin]` | first line from the data layer; absent from the corpse |
| P4 | **STARTUP** — `[startup.complete]` | Universe saying it finished booting; absent from the corpse |
| P4b | **SENTINEL** — `[oo-het.sentinel]: OO-HET-SENTINEL-OK` | this run saying it finished *on its own terms* — see below |
| P5 | **LOADED** — the staged filename inside the `[searchPaths.dumpAll]` block | only reachable via `checkPotentialPath` (ResourceManager.m:613-668), i.e. after the manifest was read and validated |

> On log channels: `shipData.load.begin = yes` is the **shipped default** in
> `Resources/Config/logcontrol.plist:360`, and `_default = yes` (line 26) means
> otherwise-undefined classes are emitted too — which is why the sentinel's
> custom `oo-het.sentinel` channel appears with no configuration at all. Nothing
> in this bead edits logcontrol.plist. A run that lacks `[shipData.load.begin]`
> is missing it because the game died before the data layer, not because the
> channel is off.

P5 is the load-bearing one. A file merely sitting in the AddOns directory does
**not** appear in that block — verified: an OXZ whose manifest cannot be read
logs `[oxp.noManifest]` and is absent.

---

## 3. The sentinel, and the sibling-hijack hazard

**Measured during this bead:** a bare game dials out to the default debug-console
port 8563 and lands in a *sibling worker's* component-test listener. That
harness runs `quit()`. Observed:

    [debugTCP.connected]: Connected to debug console "OoliteComponentTests"
    ... 4.7s later ...
    [debugConsole.automation]: Triggering global quitGame bridge...
    [universe.quit]: Quit command received by Universe.

The run ended after 4.7s, at a moment nobody chose, with **rc=0 and a clean
log**. So `rc=0` plus "no ERROR lines" is *not* evidence that a run completed.

`tools/oxp-corpus/sentinel/oo-het-sentinel.oxp` fixes this twice over:

1. Its `Config/debugConfig.plist` steers the dial-out to a dead port, so no
   stranger's listener can reach in. (Oolite *dials out* to the port named in
   that plist — `OODebugSupport.m:67-95` — so a private port is made real by
   writing the plist, not by listening elsewhere.)
2. Its world script logs a marker only this run could cause, then quits
   deliberately. A run ended by anything else never emits it.

**The quit is deferred behind a 2s one-shot Timer**, and that detail matters:
`startUpComplete` fires *before* Universe logs `[startup.complete]`. An earlier
version quit straight from the handler and the resulting logs had no
loading-complete line at all — the sentinel was destroying the very progress
evidence the checker wanted. Deferring keeps both markers, which prove different
things: P4 is the game saying it booted, P4b is this run saying it finished.

> **Reusable for other fleet beads.** Several beads launch the game and none can
> currently prove their run was not cut short by a stranger. The technique —
> a tiny self-installed OXP that (a) redirects the console dial-out to a dead
> port and (b) logs a run-owned marker before quitting — costs one directory and
> gives self-attribution with no console socket, no port allocation and no
> synthetic input.

---

## 4. "ERROR line" is not a literal grep

The deliberately-broken fixture (`tools/oxp-corpus/broken`) produces:

    [plist.parse.failed]: Failed to parse .../Config/shipdata.plist as a property list.
    [script.javaScript.exception.notDefined]: ***** JavaScript exception
        (oo-het-broken 1.0): ReferenceError: ooHetThisMethodDoesNotExist is not defined

**Neither contains the word ERROR.** A literal grep passes an expansion whose
ship data does not parse and whose script throws. So an error line is identified
three ways, each read off the product's source:

- `OOLOG_ERROR_PREFIX` — `OOLogERR` renders `***** ERROR: ` (OOLogging.h:109)
- the `*****` attention prefix (OOLogging.h:109-113, OOLogging.m:488-503)
- the log **channel**: `.error` / `.failed` / `.exception` families, which
  `logcontrol.plist` routes error classes through

One family is excluded, narrowly: `debugTCP.*`. Those "failed to connect to
debug console" lines are caused by *this harness* pointing the dial-out at a
dead port on purpose. Counting our own deliberate refusal would make every check
red for a reason unrelated to any expansion. The exclusion is one channel prefix
and `corpus.sh selftest` asserts it cannot widen.

---

## 5. The launch shape (reusable)

Exit 87 is the **bare-launch baseline** on this host, not a DLL bug — distinct
from `0xC0000135`/`STATUS_DLL_NOT_FOUND`, which comes from `/ucrt64/bin` missing
from PATH and writes no log at all. What makes a headless launch work:

    PATH=/ucrt64/bin:$PATH                 # transitive Mesa deps, in no import table
    LIBGL_ALWAYS_SOFTWARE=1
    GALLIUM_DRIVER=llvmpipe
    SDL_AUDIODRIVER=dummy
    ALSOFT_DRIVERS=null
    OO_LOGSDIR=<private>                   # per-run log dir
    OO_ADDITIONALADDONSDIRS=<private>      # per-run AddOns root
    oolite.exe --no-splash -load Resources/Scenarios/oolite-standard.oolite-save

With the sentinel staged alongside, the process **exits on its own** with rc=0
in roughly 13-20 s warm. No console socket, no port, no debugConfig from the
caller, no synthetic input.

### One trap worth knowing

The per-run working directory must contain **no `.oxz` path component**.
`-oo_oxzFileExistsAtPath:` (NSFileManagerOOExtensions.m:251-266) splits a path at
the *first* component whose extension is `oxz` and treats everything before it as
a zip archive. A working directory named `foo.oxz/AddOns/...` makes the game try
to open that *directory* as a zip, and every expansion under it silently fails to
load. This cost one run of this checker its manifest reads and its search-path
entry before it was diagnosed.

### A second trap: CRLF from python.exe into `while read`

`corpus.sh` resolves the tier1 set with a Python helper and pipes tab-separated
lines into a bash `while read` loop. **python.exe on Windows writes CRLF**, so
the last field of every line arrives with a trailing carriage return and the
resulting path names a file that does not exist. The failure mode was nasty: the
*final* line has no trailing newline and therefore no CR, so exactly one entry
staged successfully and a full run reported **"36 checked, 35 failed"** with 35
bogus `MISSING` verdicts — a diagnosis that points at the corpus cache when the
bug is in the harness.

Two fixes, both kept:

- strip the CR explicitly (`path="${path%$'\r'}"`)
- distinguish the three staging states in the output, because "the expansion is
  missing" and "I failed to copy it" demand opposite responses:
  **NOTCACHED** (source absent — fetch it), **STAGEFAIL** (copy failed — fix the
  harness), **staged** (proceed to a real load verdict). Only the third can be
  green, and the run asserts `staged_n == n` before reporting on any of it.

---

## 7. Findings from the first full Tier 1 run (36 expansions, 493 s)

`tools/corpus.sh tier1` currently **exits 1**, and that is the honest result. It
is not loosened to green. Three distinct causes, all correctly attributed
per-expansion:

### (a) Seven catalogue expansions: unmet `requires_oxps` — a composition finding

Verified against the manifests, and the correlation is perfect:

| verdict | expansion | `requires_oxps` |
|---|---|---|
| NOTLOADED | Svengali.GNN | Svengali.Library |
| NOTLOADED | Thargoid.Planetfall | 6 entries incl. PlanetFall2_ResourcesA/B |
| NOTLOADED | Norby.Carriers | Norby.EscortDeck, CaptMurphy.ShipStorageHelper |
| NOTLOADED | Svengali.OXPConfig | Svengali.CCL |
| NOTLOADED | Griff.Cobra_MkIII | Griff_shipset_decals, Griff_alloys_and_wreckage |
| NOTLOADED | Norby.Separated_Lasers | Norby.Multiple_Lasers |
| PASS | Svengali.Library, Norby.CombatMFD, … | *(empty)* |

**Every NOTLOADED has a non-empty `requires_oxps`; every PASS has an empty one.**
The log confirms the mechanism directly:
`[oxp.requirementMissing]: OXP … had unmet requirements and was removed from the
loading list`.

**This is NOT the `0.0.0-fleet` version string.** `required_oolite_version`
ranges 1.79–1.90 across *both* groups — 1.88 passes (Library) and 1.88 fails
(GNN). The discriminating variable is dependencies, not version.

**Consequence for the tier:** loading each expansion *solo* is the wrong shape
for any expansion that declares dependencies. Tier 1 needs **dependency-aware
grouping** — stage an expansion together with its `requires_oxps` closure. The
in-degree criterion makes this worse by construction: ranking *by* dependency
edges selects precisely the expansions most likely to sit in a dependency graph.
This is a real design finding, recorded rather than hidden; the grouping work is
not done here.

### (b) XenonUI: a true positive

    [XenonUI]: ERROR! No Xenon UI Resource packs installed. Xenon UI cannot
    function without one resource pack installed.

It loads fine, then legitimately reports that it needs a companion resource
pack. Same composition class as (a), but surfaced by the OXP's own error rather
than by the engine's requirement check — it declares no `requires_oxps`. Pair it
or exclude it as a documented non-solo-loadable candidate.

### (c) The six test-oxps: no `manifest.plist`

    [oxp-standards.error]: OXP …/PNGTestSuite.oxp has no manifest.plist

Five of the six ship no `manifest.plist` (only Material Test Suite has one). In a
Test Release build with standards enforcement, that is an error. A property of
the fixtures, not of the harness.

### A false-positive that this investigation caught

The first full run reported the five test-oxps as **PASS**. They were not
loading at all. Two compounding bugs:

1. they were staged under their *directory* name (`PNGTestSuite`), with no
   `.oxp` suffix — and Oolite dispatches on the extension, so the game ignored
   them entirely;
2. P5 matched the bare name as a *substring of the whole log*, and the per-run
   work directory is itself named after the expansion, so the name appeared in
   the `searchPaths` block as part of the **AddOns root path** and satisfied the
   check.

Both are fixed: the list now carries the real `.oxp` basename, and P5 parses the
indented path entries of the block and requires an entry to *end with* the staged
filename. Re-judging the five captured logs with the fixed P5 turns all five
from PASS to NOTLOADED — the guard was itself vacuous in exactly the way it was
written to prevent, which is why a positive-evidence assertion needs its own
negative control.

---

## 8. Dependency-aware grouping (bead oo-kcrw)

Section 7 recorded the finding; this section records the fix and its evidence.

### The diagnosis, re-verified from scratch

The inherited claim was *not* taken on trust. One expansion was launched twice
on the same build, differing **only** in whether its declared dependency was
staged beside it:

    === solo: staged ['oolite.oxp.Svengali.GNN'] ; primary=oolite.oxp.Svengali.GNN
        rc=0 wall=10.4s verdict=NOTLOADED
        'oolite.oxp.Svengali.GNN.oxz' is ABSENT from the [searchPaths.dumpAll]
        Resource paths block ... (block listed 5 path(s): Resources, AddOns,
        AddOns, oo-het-sentinel.oxp, Basic-debug.oxp)
        LOG> [oxp.requirementMissing]: OXP oolite.oxp.Svengali.GNN.oxz had unmet
             requirements and was removed from the loading list

    === closure: staged ['oolite.oxp.Svengali.GNN', 'oolite.oxp.Svengali.Library']
        rc=0 wall=14.8s verdict=PASS
        loaded (named in searchPaths.dumpAll), reached shipData.load.begin and
        startup.complete, 91 log lines, 0 ERROR lines

One variable, two verdicts. The dependency explanation holds, and the fix is
composition rather than a weaker predicate.

### The four hazards, and what each cost in design

1. **`requires_oxps` names identifiers; the cache is content-addressed.** The
   byte cache stores blobs under a hash of the URL, with no filename at all, so
   a closure cannot be staged without an **identifier -> blob index** built by
   reading the top-level `manifest.plist` out of every cached OXZ. That index is
   `oxp_deps.build_index()`: 813 identifiers in ~1.2 s, cheap enough to sit in
   an acceptance line.
2. **A requirement may be absent from the corpus.** That is *not* a load
   failure — the expansion never got a chance to load — and reporting it as one
   is a false accusation. `closure()` returns those separately and `run_group()`
   reports `UNSATIS` **without launching the game at all**. On the current
   corpus no Tier 1 group is unsatisfiable, but the path is pinned by a test.
3. **The graph may contain cycles.** The walk is iterative over an explicit
   queue with a `seen` set. Two brakes, and they are *not* redundant: a pop-time
   check (so a diamond stages the shared dependency once, avoiding a filename
   collision) and an append-time check (so `A<->B` never re-queues). Measured
   while building the mutation harness: **removing either brake alone still
   terminates**, so a one-sided mutant would have been a false proof. The
   harness removes both, and then the walk really does hang.
4. **Loading a set changes what a failure means.** Per-expansion attribution is
   this instrument's whole value. Three new verdicts keep it:

   | verdict | meaning | who to investigate |
   |---|---|---|
   | `UNSATIS` | a declared requirement is not in the corpus | the corpus, not the expansion |
   | `DEPNOTLD` | the primary loaded, a staged **dependency** did not | the dependency |
   | `DEPERR` | the primary is clean; the error lines belong to a named dependency | the dependency |

   None of them is green. An error line that **no** staged member claims is
   reported explicitly as unattributed rather than folded into the primary's
   tally — an unowned error is a finding about the engine or the harness and
   hiding it inside a primary's verdict destroys that signal.

   Attribution matches on the longest owning token, not first-match-wins:
   `"Xenon UI"` is a prefix of `"Xenon UI Resources Pack A"`, and first-match
   would credit every pack error to XenonUI — exactly the mis-attribution this
   bead exists to avoid.

### XenonUI: paired, with the reason written down

`[XenonUI]: ERROR! No Xenon UI Resource packs installed. Xenon UI cannot
function without one resource pack installed.` is a **true positive** and is not
silenced. Xenon UI is a UI framework that ships no artwork; it declares no
`requires_oxps`, so no graph walk can discover the need.

It is therefore **paired**, not excluded, through a curated table —
`tools/oxp-corpus/companions.json` — of *undeclared* companion requirements.
Every entry must carry a substantive `reason` and the `evidence` line that
proves the need, and a test asserts both (the mutation harness shows the gate go
red when a reason is reduced to a stub, so the table cannot decay into a
silencer). The chosen partner is `oolite.oxp.z.phkb.XenonUIResources` (Pack A):
the corpus holds 15 interchangeable packs and the lowest-lettered 16:9 pack is a
deterministic, arbitrary-free choice among equals.

The pairing is also the corpus's own **live cycle test**: Pack A's manifest
declares `requires_oxps = [oolite.oxp.z.phkb.XenonUI]`, so XenonUI + Pack A is a
genuine 2-cycle in the companion-augmented graph.

### What the grouping is *not* allowed to do

`NOTLOADED` was **not** made acceptable. If a primary is still absent from
`[searchPaths.dumpAll]` *after* its whole declared closure was staged, the
verdict stays `NOTLOADED` and the message now says so explicitly — naming the
dependencies that *were* staged, so the reader can tell "unmet requirement" from
"the grouping did not work" and knows to look for an **undeclared** requirement.
A red tier with correctly-diagnosed non-loads is the deliverable; a green tier
that lies is not.

---

## 9. The stored acceptance block, and why it is split this way

A full 36-group run really loads 36 sets on a host shared by five agents. Cheap
offline lines therefore pin the **logic**, and exactly **one** line pays for real
evidence that the launch path works end to end:

1. `tools/test_oxp_deps.py` — the closure walk (transitivity, cycles, diamonds,
   self-edges), the identifier index against the real cache, unsatisfiable
   requirements, error attribution and every group verdict, all against
   fixtures with **no game launch**.
2. `corpus.sh selftest` — oo-het's vacuity guards, unchanged and still green.
3. the real exit-87 corpse is still rejected — the guard this bead must not
   weaken, re-asserted after the refactor.
4. `corpus.sh tier1 --only <one multi-member group>` — really launches the game
   with a primary **and** its dependency, with a wall-time floor so a run too
   fast to have launched anything fails.
5. the red proof — the deliberately broken expansion still goes red, naming
   itself and quoting its error line.

---

## 10. The full Tier 1 run after grouping: 30 PASS / 5 NOMANIF / 1 ERRORS

Measured on this host, 36 groups, 50 member-loads, one launch per group:

    tier1: 36 group(s), 7 with dependencies, 50 member-loads total
    --- 36 group(s) checked, 1 failed (ERRORS=1, NOMANIF=5, PASS=30) ---
    RC=1

`NOTLOADED` went from **7 to 0**. All seven expansions oo-het measured as
rejected now load, each named in `[searchPaths.dumpAll]` alongside its closure:

| expansion | closure size | verdict | wall |
|---|---|---|---|
| `oolite.oxp.Svengali.GNN` | 2 | PASS | 14.8 s |
| `oolite.oxp.Thargoid.Planetfall` | 7 | PASS | 16.0 s |
| `oolite.oxp.Svengali.OXPConfig` | 2 | PASS | 14.8 s |
| `oolite.oxp.Griff.Cobra_MkIII` | 3 | PASS | 14.8 s |
| `oolite.oxp.Norby.Separated_Lasers` | 2 | PASS | 14.9 s |
| `oolite.oxp.z.phkb.XenonUI` | 2 (companion) | PASS | 21.0 s |
| `oolite.oxp.Norby.Carriers` | 3 | **ERRORS** — loads, then emits ship-data errors | 14.7 s |

`NOTLOADED` went from 7 to 0 and the failure count from 8 to **1**.
That converts oo-het's correlation into causation: the *only* variable changed is
whether the declared closure was staged, and the verdict flips from a manifest
rejection to a clean load. XenonUI, previously a true-positive `ERRORS`, is now
PASS with Pack A staged — the companion pairing works and the error is gone
because the requirement is *met*, not because anything was silenced.

### The tier is still RED, honestly, for one group

The six failures split into **two different things**, and the instrument now
says which is which — reporting them identically was a defect in the report,
not a reason to loosen anything.

**Class A — five legacy in-tree fixtures with no `manifest.plist`.**
`AI overflow test.oxp`, `JavaScript Interface Tests.oxp`, `PNGTestSuite.oxp`,
`RetroMissions.oxp` and `Fallback test.oxp` each emit **exactly 2** error lines,
all of them:

    [oxp-standards.error]: OXP ...\AddOns\PNGTestSuite.oxp has no manifest.plist

The tell that this is a fixture property rather than five independent defects is
that five unrelated fixtures produce an identical count of exactly 2. They ship
no manifest because they predate the format. They now get their own state,
**`NOMANIF`**, which is **non-fatal** — the only non-`PASS` state that does not
fail the tier.

That is a re-label, not a suppression, and it is narrow by construction:

- the expansion must have **loaded** first (P5), so a rejected expansion is
  `NOTLOADED` and can never reach this branch;
- **every** error line in the run must be this one message — one extra error of
  any kind and it is `ERRORS` again, with the manifest lines still listed;
- the message must **name a staged member**, so a stranger's missing manifest is
  still reported as unattributed;
- the lines are still printed, still in the JSON, still counted.

Each of those four narrowings has its own test, and the mutation harness shows
the gate go red when the "every line matches" condition is widened to "any line
matches". The alternative — leaving them as `ERRORS` — sends every future reader
hunting a bug that does not exist.

**Class B — one genuine finding: `Norby.Carriers`.** The primary and both its
dependencies load cleanly, then ten error lines appear:

    [shipData.load.error]: ***** ERROR: the shipdata.plist entry "cobra1-carrier"
        has unresolved subentity cobramk1-player.
    [oxp-standards.error]: Bad subentity definition found

…repeated for `viper-carrier`, `cobra3-carrier`, `ferdelance-carrier` and
`anaconda-carrier`. These are reported as **unattributed**, not blamed on the
primary, because the messages name a *data key* and never a file, identifier or
title — the log itself does not say which expansion contributed the entry.

**Is this a missing dependency or a real OXP bug?** Investigated, and the answer
is neither of the obvious two. Evidence:

1. **Control run.** The game launched with *only* the sentinel staged — no
   corpus expansion at all — produces **0** such lines. So these errors are
   caused by the staged group, not by the engine or the base data.
2. **The referenced subentities are not missing from the corpus.** Eight of the
   nine (`cobramk1-player`, `adder-player`, `cobra3-player`, `gecko`,
   `sidewinder`, `anaconda-player`, `asp-player`, `ferdelance-player`) are
   **present as top-level entries in the base game's own**
   `Resources/Config/shipdata.plist`, each a `like_ship` of an
   `oolite_template_*` that also exists. Only `viper` is genuinely absent (the
   base data has `oolite_template_viper`, not `viper`).
3. **The engine explains the mechanism.** `OOShipRegistry.m` runs
   `applyLikeShips:` *before* `canonicalizeAndTagSubentities:` (`:327`, `:331`),
   and an entry whose `like_ship` chain cannot be resolved is **removed**
   (`:662-666`) before the subentity pass runs — at which point a reference to
   it reads as "unresolved subentity" (`:940-946`, `:964-967`). The same file
   shows the intended escape hatches: `is_external_dependency` suppresses the
   complaint, and the sibling failure path names the real cause outright —
   `OOStandardsError(@"Likely missing a dependency in a manifest.plist")`.

So this is the **same class as XenonUI**: a composition requirement that
`requires_oxps` does not declare. It differs in that the missing partner cannot
be named from the log alone, and naming it would require opening the OXZ's
`shipdata.plist` — which repo rule 6 forbids. The verdict therefore states the
observation as fact and the mechanism as a ranked candidate list, and **stays
red**. Adding a companions entry here would be a guess, and a guessed pairing is
exactly what the `reason`/`evidence` requirement exists to prevent.

### Cost, and why the full run stays out of the stored gate

Per-group wall time is **~12-24 s (median ~17 s)** against ~13.5 s solo — the
closure adds staging and parsing without adding a launch, since a whole group
loads in *one* game start. The full 36 took **~13 minutes** under four-sibling
contention. `accept.sh` replays the stored block in a fresh checkout, possibly
several times; a 13-minute gate is slow and fails on a neighbour's load rather
than on this bead's code. Hence the split in section 9: the logic is pinned by
fixtures offline in ~2 s, and exactly one stored line really launches the game —
`--only oolite.oxp.Svengali.GNN`, chosen because it is the *minimal* expansion
that loads **only** when its closure is staged, and the line additionally
asserts the run reported a `2-member requires_oxps closure` so it cannot pass
while silently loading solo.


