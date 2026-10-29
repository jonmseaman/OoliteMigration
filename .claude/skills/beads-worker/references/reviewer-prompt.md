# Phase-end reviewer

Every bead in the phase already went through its own pull request, so this review is not a first
look at unseen code. It answers what those per-bead reviews cannot: **does the phase, taken as a
whole, meet its exit criteria, and did anything drift across the beads?**

Dispatch it as a subagent: a reader who did not write the code catches what the author cannot. It
reads and reports; it changes nothing.

## Prompt

> Review the Oolite migration's phase `<N>` as a whole, before it is proposed from `develop` to
> `master` on the game fork.
>
> The diff is `git -C oolite-dev diff master...develop` (run it from the repo root at
> `<repo root>`). It is large: work from `--stat` first, then read the files that matter rather
> than every hunk. The phase's exit criteria are in `docs/phases/<N>-<name>.md`; read that first,
> because it is what you are judging against. The rules every change had to obey are in
> `CLAUDE.md`.
>
> Report findings only. Do not edit anything, do not open a pull request, do not run `bd`.
>
> Judge, in this order:
>
> 1. **Exit criteria.** Take each box in the phase doc and find the evidence for it in the tree.
>    A criterion with no executable proof is a finding, however plausible it looks.
> 2. **Prohibitions.** Any test weakened, skipped or deleted; any new `-Wno-*`,
>    `#pragma … diagnostic` or unused-attribute; any `libgnustep-base` or `JS_*` symbol
>    reintroduced; any C rewritten that already compiled as C.
> 3. **Drift across beads.** The same helper written three ways, a convention the early beads kept
>    and the late ones abandoned, a facade half-removed, a TODO left where a bead's notes promised
>    a follow-up.
> 4. **Seams left open.** Scaffolding added for one bead that no longer has a reason to exist, and
>    anything that silently depends on a bead that was parked rather than finished.
> 5. **Fidelity.** Behaviour-preserving translation, no redesign smuggled in alongside a
>    conversion, `oo::Ref<T>` rather than `shared_ptr`.
>
> Be specific. A finding without a file and a line is not a finding. For each one give: file, line,
> which of the five it breaks, what is wrong, and what would resolve it.
>
> Finish with a one-paragraph verdict: is this phase ready to propose, and if not, what are the
> blocking findings?

## After the review

File every finding as its own bead, labelled `review-finding`, with the file and line in the body.
Do not open the phase pull request while any is open (`bd list --label review-finding --status
open`). Fix them the ordinary way: each becomes a bead, each gets a branch and a pull request.
