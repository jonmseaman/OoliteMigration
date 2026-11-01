# Contract: PR description (`series/pr/NNN-slug.md`)

The first line is the PR title. Sections in this order; `check` fails if one is missing. **(gen)** marks
sections that `describe` rewrites; the others are written by hand and kept.

```markdown
# <title>

**Series:** step N of M · base `<parent branch>` · next `<next branch or "—">` **(gen)**

## What this changes
<2–6 sentences, plain language, about the code>

## Why
<the reason this step exists and why it comes here in the order>

## Behaviour changes
<"None." or a list, each with the test that pins it>

## How to review
<where to start; for mechanical steps, the command and "rerun it on the base and compare">

## Verified **(gen)**
<table: check → result, compilers, platform, date, commit>

## Temporary code **(gen, omitted if none)**
<shims added here and the step that removes them, or removed here and where they were added>
```

Rules: no bead ids, ADR numbers or `docs/` paths of OoliteMigration (FR-017). Platforms not verified
(macOS, and Linux unless built) are named as not verified, never claimed to work.
