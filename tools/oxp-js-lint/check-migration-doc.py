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
    "legacy-generator",   # bead oo-1gc.16
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

# ADR-0069 layer 2: the compat set gets the same treatment, pointing at compat-rules.js.
compat_js = root / "tools" / "oxp-js-lint" / "compat-rules.js"
if not compat_js.is_file():
    sys.exit("tools/oxp-js-lint/compat-rules.js (compat rule source) missing")
compat_src = compat_js.read_text(encoding="utf-8")
COMPAT_RULES = [
    "for-each", "removed-api", "polyfill-approx", "readonly-native-write",
    "strict-only", "fn-tostring", "error-message", "global-enum",
]
implemented = re.findall(r'^  "?([a-z0-9-]+)"?: \{$', compat_src, flags=re.M)
if sorted(implemented) != sorted(COMPAT_RULES):
    sys.exit(f"compat-rules.js implements {sorted(implemented)}, this check expects {sorted(COMPAT_RULES)}")
for r in COMPAT_RULES:
    sec = next((s for s in sections[1:] if s.startswith("`" + r + "`")), None)
    if sec is None:
        sys.exit(f"doc is missing a section for compat rule {r}")
    if "**Replacement" not in sec:
        sys.exit(f"compat rule {r}: missing a replacement entry")
    if not ("**Lint rule:**" in sec and "compat-rules.js" in sec):
        sys.exit(f"compat rule {r}: missing a reference to compat-rules.js")

# Every rule id, and syntax-other (the parse layer's unexplained failure), has the anchor the
# per-expansion notes link to; and every rule the notes use resolves.
anchors = set(re.findall(r'<a id="rule-([a-z0-9-]+)"></a>', text))
missing_anchor = [r for r in RULES + COMPAT_RULES + ["syntax-other"] if r not in anchors]
if missing_anchor:
    sys.exit(f"doc is missing #rule- anchors for: {missing_anchor}")
notes_file = root / "tools" / "oxp-scan" / "expansion-notes.json"
if notes_file.is_file():
    import json
    used = {f["rule"] for e in json.loads(notes_file.read_text(encoding="utf-8"))["expansions"] for f in e["findings"]}
    dangling = sorted(used - anchors)
    if dangling:
        sys.exit(f"expansion notes link rules with no section in the guide: {dangling}")

print(f"OK: {len(by_rule)}/{len(RULES)} constructs each link a replacement and a lint rule")
print(f"OK: {len(COMPAT_RULES)} compat rules each link a replacement and compat-rules.js; "
      f"{len(anchors)} #rule- anchors cover every rule the notes use")
