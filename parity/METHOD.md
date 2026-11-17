# How to run the parity audit

This is the runbook for redoing the Objective-C → C++ behavioural parity audit. It is written for a
**coordinator agent**: follow the steps in order and you will end with a refreshed `parity/` folder
whose findings are tied to one oolite-dev commit. The auditors' instructions are in
[AUDIT-BRIEF.md](AUDIT-BRIEF.md). The extractor, splitter, merger and totals counter are all in
[tools/extract_coverage.py](tools/extract_coverage.py).

Paths are relative to the OoliteMigration root (`C:\Users\jon\OoliteMigration`) unless they say otherwise.

## Run log

| Date | Port commit | Rows | ✅ | ⚠️ | ❌ | ➖ | Notes |
|---|---|---|---|---|---|---|---|
| 2026-10-27 | late-October series tip (commit not recorded) | 7,476 | 6,518 | 263 | 170 | 525 | first audit; 2 high, ~12 med |
| 2026-11-16 | `seriesb/028-upstream-772-tests` @ `bf01f1b49` | 7,461 | 6,395 | 286 | 198 | 582 | full re-audit, 29 auditors, following this runbook; 0 high, 12 med |

Add a row each time you run it.

## 0. Before you start

- **Cost.** A full run is about 25–30 auditor subagents, each reading several thousand lines on each side. Tell the user before you start it, and get a yes.
- **Inputs.** Decide these four and write them down at the top of your working notes:
  - `UPSTREAM` = `upstream/oolite/src`: the unmodified OoliteProject 1.93 sources. Don't edit them.
  - `PORT_REF` = the oolite-dev branch and commit to audit, e.g. `seriesb/028-upstream-772-tests` @ `bf01f1b49`.
  - `RUN` = `.agent-tmp/parity-run` (git-ignored scratch for this run).
  - `PREV` = `.agent-tmp/parity-prev`: a snapshot of the current `parity/*.md`, i.e. the previous run.
- **Never** touch oolite-dev's own checkout (it may be on any branch, with uncommitted work). Audit a separate worktree.

## 1. Check out the port, read-only

```bash
git -C oolite-dev worktree add --detach ../.worktrees/parity-<short-branch> <commit>
PORT=.worktrees/parity-<short-branch>/src
```

## 2. Snapshot the previous run

```bash
mkdir -p .agent-tmp/parity-prev && cp parity/*.md .agent-tmp/parity-prev/
```

The auditors compare against these to mark findings fixed, still open or new.

## 3. Generate the coverage skeletons

```bash
python parity/tools/extract_coverage.py skeleton --upstream upstream/oolite/src --port $PORT --out .agent-tmp/parity-skeletons
```

- The area → file grouping comes from the **Checklist** in `parity/README.md` (`### <title> — [<area>.md](<area>.md)` headings and `- [x] \`Core/X.m\`` rows). If the script reports upstream `.m` files that aren't in any area, add them to the checklist before going on.
- Each upstream `.m` file becomes a `## <Name>` section with an anchor, a `**Status:** todo` line, a coverage table (one row per ObjC method and top-level C function, with its upstream line) and an empty Differences list.
- The extractor is regex-based and finds about 95% of the rows (7,104 vs the 7,476 the first audit ended with). The auditors add the rest by hand.

## 4. Split into auditor assignments

```bash
python parity/tools/extract_coverage.py split --skeletons .agent-tmp/parity-skeletons --out .agent-tmp/parity-run/parts --max-rows 400
```

This packs whole sections into part files `<area>.<NN>.md` of at most about 400 rows, and cuts bigger
sections (ShipEntity, PlayerEntity, Universe) into row ranges marked `<!-- rows a-b of n -->`.
`parts/manifest.json` records the order, which is used by `merge`. 400 rows is about what one subagent can read side by side
without losing track. Go lower if auditors report running out of room.

Plus three **extra assignments** that don't come from the extractor. Each rewrites its own file in
`.agent-tmp/parity-run/extra/` (seed it with a copy of the previous file), using the same verdicts and bullet format:

| File | What it covers | How |
|---|---|---|
| `c-and-tables.md` | C sources and `.tbl` tables that should be byte-identical | `diff --strip-trailing-cr $UPSTREAM/<f> $PORT/<f>` for each `.c` file and table; explain every diff line |
| `headers.md` | `#define`s, enum values, `static const`s and inline functions in paired `.h` files | Write a throwaway script as described in the file's **Method** paragraph: pair the headers, expand X-macro tables, normalise the values and compare. Read every differing body by hand |
| `cpp-only.md` | C++ files with no upstream counterpart, checked against the upstream behaviour they replace, plus the legacy-script and shader-binding dispatch-table completeness checks | One section per file, as before. Also list any *new* C++-only file (`git -C oolite-dev ls-tree` for files with no upstream `.m`/`.c` of the same name) |

Also assign the `## OOMaths` section (the maths headers' inline functions) to the auditor that has `math.01.md`. It isn't an `.m` file, so the extractor skips it.

## 5. Dispatch the auditors

Use one `general-purpose` subagent per part file, run in the background, 5–6 at a time. Give each this prompt, with the placeholders filled in:

```text
You are a parity auditor. Read C:\Users\jon\OoliteMigration\parity\AUDIT-BRIEF.md first and follow it exactly.

Assignment:
- UPSTREAM = C:\Users\jon\OoliteMigration\upstream\oolite\src
- PORT     = C:\Users\jon\OoliteMigration\.worktrees\parity-<short-branch>\src   (oolite-dev <branch> @ <commit>)
- Your part file (fill it in place; the only file you may write): C:\Users\jon\OoliteMigration\.agent-tmp\parity-run\parts\<area>.<NN>.md
- Previous findings for comparison (read-only): C:\Users\jon\OoliteMigration\.agent-tmp\parity-prev\<area>.md (previous run: <prev date>)
- Sections in your part: <comma-separated names>  (<rows> extracted rows)
<any extra instruction, e.g. the OOMaths section, or the row range of a cut section>

Use Read/Grep on both trees. Use Edit to fill the table rows in place: change several rows per Edit, not one at a time.
Do not stop until every row has a verdict and every section has a done Status line. Then give the final reply that the brief describes.
```

While they run, keep a table of part → agent → state. When an agent returns, run:

```bash
grep -c "| |$" .agent-tmp/parity-run/parts/<part>     # rows still without a verdict: must be 0
grep -c "\*\*Status:\*\* todo" .agent-tmp/parity-run/parts/<part>   # must be 0
```

If it isn't finished, continue the same agent (SendMessage) with "finish the rows still without a verdict in <part>". Don't start a fresh one.

## 6. Merge and count

```bash
python parity/tools/extract_coverage.py merge --parts .agent-tmp/parity-run/parts --out parity
cp .agent-tmp/parity-run/extra/*.md parity/
python parity/tools/extract_coverage.py totals
```

`merge` joins the parts (and the cut sections) back into one file per area, and **recomputes every Status
line from the Verdict column**. It prints `NO VERDICT:` for any row whose last cell has no symbol: fix those
by hand before going on. `totals` prints the per-area and overall counts that go in the README and the run log.

If the old area file had text after its sections that isn't in the skeleton (e.g. math.md's `## OOMaths`), check it made it into the new file.

## 7. Coordinator verification

This is what makes the audit trustworthy. Don't skip it.

1. **Every high and medium ❌:** open both sources at the cited lines and confirm. Mark the confirmed ones ✔ in the README.
   Downgrade or delete the rest, and correct their area-file bullet too.
2. **Every `(fixed since …)` claim:** check that the cited fix or test exists at `PORT_REF`.
3. **Spot-check about 10 random ✅ rows** across areas. If more than one is wrong, send that area back for another pass.
4. **Look for gaps:** sections where the row count dropped a lot from the previous run, or areas with suspiciously few findings.

## 8. Rewrite `parity/README.md`

Keep its structure:

- the header: audited commit, date, totals line and method line (link this file);
- **Changes since <previous run>:** the findings fixed (with the fix), still open (new line numbers) and new;
- **Cross-cutting findings:** patterns seen in several files, each linking its instances;
- **Suspected divergences (ranked):** High / Medium / Low, ✔ = verified in step 7;
- **Suggested follow-ups,** or a link to the current fix plan;
- **Checklist:** one row per upstream file, with its port file, line counts, verdict counts and a findings link. Regenerate the counts from `totals`. The skeleton header line of each section has the port path and line counts.

Then add the run's row to the run log above.

## 9. Clean up

```bash
git -C oolite-dev worktree remove ../.worktrees/parity-<short-branch>
```

Keep `.agent-tmp/parity-run` until the user has reviewed the results. Commit `parity/` only when the user says to.

## Conventions

- **Verdicts:** ✅ equivalent · ⚠️ intentional divergence, cited (code comment, ADR, bead, spec) · ❌ suspected behaviour difference · ➖ removed or replaced.
- **Severity:** **high** means the player sees it in normal play, or it corrupts saves or state; **med** means it is user-visible in some configurations or with common OXPs, or crashes on reachable input; **low** covers log text, nil-messaging edge cases, iteration order with no output effect, and unreachable paths.
- **Citations:** `upstream \`Core/X.m:123\` ↔ port \`Core/X.cpp:456\``, with paths relative to each `src/`. Line numbers are only valid for the run's commit, which is why the README header names it.

## How the first audit (2026-10-27) was done

This runbook is a reconstruction of that audit's method, with its gaps fixed.

- **Sources.** Upstream `upstream/oolite/src` against a port worktree `oolite-dev/.claude/worktrees/cpp-objc-code-comparison-e96d6e`. The worktree is gone and its commit wasn't recorded, which is why step 1 now records it.
- **Unit of work.** The 241 upstream `.m` files, grouped into 13 area files. Separate passes covered the C/table files (by `diff`), the C++-only files and a header constants sweep (857 `#define`s, 948 enum values, 173 constants, 105 inlines; 0 ❌).
- **Coverage tables.** A regex extractor pre-filled one row per method or function. Auditors added missed rows and deleted false ones. The script wasn't kept; `tools/extract_coverage.py` replaces it, and its totals mode reproduces the 7,476-row count from the old files exactly.
- **Auditors.** One subagent per area. Big areas were split into part files that were merged by hand. Each followed AUDIT-BRIEF: read both bodies side by side, gave every row a verdict, wrote a Differences bullet with severity and both line numbers, and set a Status line. They were read-only on the code and never committed.
- **Coordinator.** Re-verified every high and most mediums against both sources (the ✔ marks), wrote the cross-cutting patterns, the ranked list, the totals (7,476 rows: 6,518 ✅ · 263 ⚠️ · 170 ❌ · 525 ➖; 2 high, ~12 med) and the follow-ups.
- **Known limits, now addressed here.** The commit wasn't recorded (step 1). The extractor wasn't kept (step 3). The parts were merged by hand and the Status counts were typed by auditors (step 6 recomputes them). There was no previous run to compare with (step 5's `PREV`).
- **Known limits that remain.** Severity is the auditor's call. Unmarked findings weren't re-read by the coordinator. Line numbers go stale with every commit.
