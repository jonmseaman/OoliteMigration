import re, sys, pathlib

root = pathlib.Path(__file__).resolve().parents[2]
doc = root / "docs" / "EXPANSION_MIGRATION.md"
rules_js = root / "tools" / "oxp-js-lint" / "rules.js"
deny_list = root / "tools" / "deny-list.txt"

if not doc.is_file():
    sys.exit("docs/EXPANSION_MIGRATION.md missing")

text = doc.read_text(encoding="utf-8")

if len(text.splitlines()) < 100:
    sys.exit("doc too short to be a real guide")

if not rules_js.is_file():
    sys.exit("tools/oxp-js-lint/rules.js (lint rule source) missing")
if not deny_list.is_file():
    sys.exit("tools/deny-list.txt (C/C++ deny-list) missing")

rules_src = rules_js.read_text(encoding="utf-8")

RULES = [
    "catch-if", "e4x", "quote-method", "to-source", "uneval",
    "let-block", "legacy-accessor", "expression-closure",
]

# Each rule must actually be a detector implemented in rules.js (catches a
# doc that names a rule which does not exist).
for r in RULES:
    if f'"{r}"' not in rules_src and f"{r}:" not in rules_src:
        sys.exit(f"rule {r} not found in tools/oxp-js-lint/rules.js")

sections = re.split(r"\n#### ", text)
by_rule = {}
for sec in sections[1:]:
    for r in RULES:
        if sec.startswith("`" + r + "`"):
            by_rule[r] = sec.split("\n#### ")[0]

missing = [r for r in RULES if r not in by_rule]
if missing:
    sys.exit(f"doc is missing a section for rule(s): {missing}")

for r, sec in by_rule.items():
    has_replacement = ("**Replacement:**" in sec) or ("**Removed/deprecated:**" in sec)
    has_lint_ref = "**Lint rule:**" in sec and "rules.js" in sec
    if not has_replacement:
        sys.exit(f"rule {r}: missing a replacement entry")
    if not has_lint_ref:
        sys.exit(f"rule {r}: missing a lint-rule reference")

print(f"OK: {len(by_rule)}/8 constructs each link a replacement and a lint rule")
