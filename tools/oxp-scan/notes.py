#!/usr/bin/env python3
"""tools/oxp-scan/notes.py -- per-expansion notes from the expansion compatibility scan.

    python3 tools/oxp-scan/notes.py           # write the notes
    python3 tools/oxp-scan/notes.py --check   # exit 1 if the committed notes are stale

Merges, for every one of the 818 expansions in tools/oxp-corpus/manifest.json:
  - layer 1, tools/oxp-js-parse/parse-report.json  (does the game's QuickJS-ng compile it?)
  - layer 2, tools/oxp-js-lint/compat-report.json  (code that parses but behaves differently)
  - the nine Mozilla-only rules, tools/oxp-js-lint/corpus-report.json
  - identity and dependencies from tools/oxp-corpus/tier3.json
  - reviewed diagnoses from tools/oxp-scan/diagnoses.json
and writes:
  - tools/oxp-scan/expansion-notes.json   all 818, machine-readable
  - docs/expansions/README.md             the index
  - docs/expansions/<identifier>.md       one page per expansion with a finding

Nothing here opens an expansion: the inputs are the committed reports, which carry positions, rule
ids, fixed-vocabulary names and engine messages, never source text (CLAUDE.md rule 6).
Output is deterministic (no timestamps), so --check can prove the committed notes match the reports.
"""

import json
import re
import sys
import urllib.parse
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MANIFEST = REPO / "tools" / "oxp-corpus" / "manifest.json"
TIER3 = REPO / "tools" / "oxp-corpus" / "tier3.json"
PARSE = REPO / "tools" / "oxp-js-parse" / "parse-report.json"
COMPAT = REPO / "tools" / "oxp-js-lint" / "compat-report.json"
LINT = REPO / "tools" / "oxp-js-lint" / "corpus-report.json"
DIAGNOSES = REPO / "tools" / "oxp-scan" / "diagnoses.json"
NOTES_JSON = REPO / "tools" / "oxp-scan" / "expansion-notes.json"
DOCS = REPO / "docs" / "expansions"
GUIDE = "../EXPANSION_MIGRATION.md"

# rule -> (one-line fix, used on the expansion pages). The guide section is #rule-<id>.
RULES = {
    "syntax-other": "No rule names this compile error. See the engine message and the diagnosis.",
    "catch-if": "Rewrite `catch (e if cond)` as `catch (e) { if (cond) {...} else { throw e; } }`.",
    "e4x": "Replace E4X XML literals and operators with plain objects.",
    "let-block": "Replace `let (x = 1) {...}` with `{ let x = 1; ... }`.",
    "expression-closure": "Give the function a block body: `function (x) { return x * x; }`.",
    "legacy-generator": "Iterate the list directly, or declare `function*` and iterate with `for...of`.",
    "for-each": "Replace `for each (var x in o)` with `for (var k in o) { var x = o[k]; }`.",
    "legacy-accessor": "Still works on QuickJS-ng; `Object.defineProperty` is the standard form.",
    "removed-api": "Remove the SpiderMonkey-only API use; the guide gives the replacement for each name.",
    "polyfill-approx": "Works through the game's polyfill; use `JSON.stringify` where the exact text matters.",
    "readonly-native-write": "Delete the write: the property is read-only, so it never took effect on either engine.",
    "strict-only": "Name the function instead of `arguments.callee`; write octal as `0o755`; drop duplicate parameters.",
    "fn-tostring": "Do not depend on a function's source text.",
    "error-message": "Test the error's type (`instanceof`, `e.name`), not its message wording.",
    "global-enum": "Expect the standard ES2023 globals when listing the global object.",
}

LINT_SEVERITY = {  # the nine Mozilla-only rules; to-source/uneval/quote are reported by compat
    "catch-if": "BREAKS", "e4x": "BREAKS", "let-block": "BREAKS", "expression-closure": "BREAKS",
    "legacy-generator": "BREAKS", "legacy-accessor": "INFO",
}

STATUS_ORDER = ["breaks", "broken-on-every-engine", "changed", "info", "clean", "data-only", "not-scanned"]
STATUS_TEXT = {
    "breaks": "a script fails on QuickJS-ng that worked on SpiderMonkey",
    "broken-on-every-engine": "a script fails to compile on any engine (a defect that predates the migration)",
    "changed": "runs, but with a different result from SpiderMonkey",
    "info": "worth a look; no change to what players see",
    "clean": "no finding",
    "data-only": "no JavaScript",
    "not-scanned": "not in the cache",
}
SEV_ORDER = {"BREAKS": 0, "CHANGED": 1, "INFO": 2}


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def file_stem(url):
    name = urllib.parse.unquote(url.rsplit("/", 1)[-1])
    return re.sub(r"\.(oxz|zip)$", "", name, flags=re.I)


def slug(identifier):
    return re.sub(r"[^A-Za-z0-9._-]+", "_", identifier).strip("_") or "expansion"


def md(text):
    return str(text).replace("|", "\\|")


def build():
    manifest = load(MANIFEST)["entries"]
    tier3 = {e["url"]: e for e in load(TIER3)["entries"]}
    parse = {e["url"]: e for e in load(PARSE)["expansions"]}
    compat = {e["url"]: e for e in load(COMPAT)["expansions"]}
    lint = {e["url"]: e for e in load(LINT)["expansions"]}
    diagnoses = load(DIAGNOSES)["diagnoses"]
    for d in diagnoses:
        if d["url"] not in manifest:
            sys.exit(f"diagnoses.json names a url that is not in the manifest: {d['url']}")

    def diagnosis_for(url, f):
        for d in diagnoses:
            if d["url"] == url and d["file"] == f["file"] and d["rule"] == f["rule"] \
                    and d.get("line") in (None, f["line"]):
                return {"class": d["class"], "note": d["note"]}
        return None

    notes = []
    for url in sorted(manifest, key=lambda u: (tier3.get(u, {}).get("identifier") or file_stem(u)).lower()):
        entry = manifest[url]
        t = tier3.get(url)
        p = parse.get(url, {})
        c = compat.get(url, {})
        lt = lint.get(url, {})
        findings = []
        parse_lines = set()
        for f in p.get("failures", []):
            parse_lines.add((f["file"], f["line"]))
            findings.append({"layer": "parse", "rule": f["rule"],
                             "severity": "BREAKS" if f["mode"] == "plain" else "INFO",
                             "file": f["file"], "line": f["line"], "column": f["column"],
                             "engine_message": f["message"]})
        for f in lt.get("findings", []):
            sev = LINT_SEVERITY.get(f["rule"])
            if sev is None or (f["file"], f["line"]) in parse_lines:
                continue
            findings.append({"layer": "lint", "rule": f["rule"], "severity": sev,
                             "file": f["file"], "line": f["line"], "column": f["column"]})
        for f in c.get("findings", []):
            findings.append({"layer": "compat", "rule": f["rule"], "severity": f["severity"],
                             "what": f.get("what"), "file": f["file"], "line": f["line"], "column": f["column"]})
        for f in findings:
            d = diagnosis_for(url, f)
            if d:
                f["diagnosis"] = d
        findings.sort(key=lambda f: (f["file"], f["line"], f["column"], f["rule"]))

        counted = [f for f in findings if f.get("diagnosis", {}).get("class") != "own-field"]
        if p.get("status", "ok") != "ok" or c.get("status", "ok") != "ok":
            status = "not-scanned"
        elif any(f["severity"] == "BREAKS" and f.get("diagnosis", {}).get("class") != "content-defect" for f in counted):
            status = "breaks"
        elif any(f.get("diagnosis", {}).get("class") == "content-defect" for f in counted):
            status = "broken-on-every-engine"
        elif any(f["severity"] == "CHANGED" for f in counted):
            status = "changed"
        elif counted:
            status = "info"
        elif findings:
            status = "clean"   # only diagnosed own-field hits
        else:
            status = "clean" if p.get("js_files", 0) else "data-only"

        notes.append({
            "identifier": t["identifier"] if t else file_stem(url),
            "title": t.get("title") if t else None,
            "version": t.get("version") if t else None,
            "category": t.get("category") if t else None,
            "in_tier_lists": bool(t),
            "url": url,
            "sha256": entry.get("sha256"),
            "js_files": p.get("js_files", 0),
            "requires": t.get("requires", []) if t else [],
            "dependents": t.get("indegree", 0) if t else 0,
            "status": status,
            "findings": findings,
        })
    return notes


def page(n):
    lines = [f"# {md(n['identifier'])}", ""]
    lines.append(f"**Status: {n['status']}**: {STATUS_TEXT[n['status']]}.")
    lines += ["", "| | |", "|---|---|"]
    for k, v in (("Title", n["title"]), ("Version", n["version"]), ("Category", n["category"]),
                 ("Download", n["url"]), ("sha256", f"`{n['sha256']}`"),
                 (".js files", n["js_files"]), ("Required by", f"{n['dependents']} catalogued expansion(s)"),
                 ("Requires", ", ".join(n["requires"]) or "nothing")):
        if v is not None:
            lines.append(f"| {k} | {md(v)} |")
    lines += ["", "## Findings", "",
              "| File:line:col | Layer | Rule | Severity | Detail |", "|---|---|---|---|---|"]
    for f in n["findings"]:
        detail = f.get("what") or f.get("engine_message") or ""
        if f.get("diagnosis"):
            detail = (detail + ". " if detail else "") + f"**{f['diagnosis']['class']}**"
        lines.append(f"| `{md(f['file'])}:{f['line']}:{f['column']}` | {f['layer']} | "
                     f"[`{f['rule']}`]({GUIDE}#rule-{f['rule']}) | {f['severity']} | {md(detail)} |")
    diagnosed = {}
    for f in n["findings"]:
        if f.get("diagnosis"):
            diagnosed.setdefault((f["file"], f["diagnosis"]["class"], f["diagnosis"]["note"]), 0)
            diagnosed[(f["file"], f["diagnosis"]["class"], f["diagnosis"]["note"])] += 1
    if diagnosed:
        lines += ["", "## Diagnosis", ""]
        for (file, cls, note), _ in sorted(diagnosed.items()):
            lines.append(f"- `{md(file)}` ({cls}): {note}")
    lines += ["", "## What to change", ""]
    for rule in sorted({f["rule"] for f in n["findings"]}):
        files = sorted({f["file"] for f in n["findings"] if f["rule"] == rule})
        own = all(f.get("diagnosis", {}).get("class") == "own-field" for f in n["findings"] if f["rule"] == rule)
        box = "[x]" if own else "[ ]"
        text = "nothing to change; the diagnosis shows it is the expansion's own field." if own else RULES.get(rule, "")
        lines.append(f"- {box} [`{rule}`]({GUIDE}#rule-{rule}) in {', '.join('`' + md(x) + '`' for x in files)}: "
                     f"{text}")
    lines += ["- [ ] Load the updated expansion in the game and check `Latest.log` for errors.",
              "- [ ] Bump the version in `manifest.plist`.",
              "", "Generated by `tools/oxp-scan/notes.py` from the layer 1 and 2 reports "
              "([scan report](scan-report.md)). Do not edit by hand.", ""]
    return "\n".join(lines)


def index(notes, slugs):
    counts = Counter(n["status"] for n in notes)
    sev = Counter()
    by_rule = Counter()
    for n in notes:
        for f in n["findings"]:
            sev[f["severity"]] += 1
            by_rule[(f["layer"], f["rule"], f["severity"])] += 1
    lines = ["# Expansion notes: QuickJS-ng compatibility, layers 1 and 2", "",
             f"Every catalogued expansion ({len(notes)}) was checked by the scan of "
             f"the [compatibility scan](scan-report.md):",
             "",
             "- **layer 1**: parsed by the game's own QuickJS-ng;",
             "- **layer 2**: checked by the compat rules and the nine Mozilla-only rules.",
             "",
             "How to fix each finding is in the [migration guide](../EXPANSION_MIGRATION.md). How the scan "
             "was run is in the [scan report](scan-report.md). The machine-readable "
             "notes are in [`tools/oxp-scan/expansion-notes.json`](../../tools/oxp-scan/expansion-notes.json).",
             "", "| Status | Meaning | Expansions |", "|---|---|---:|"]
    for s in STATUS_ORDER:
        lines.append(f"| {s} | {STATUS_TEXT[s]} | {counts.get(s, 0)} |")
    lines += ["", "## Expansions with findings", "",
              "| Expansion | Version | Status | BREAKS | CHANGED | INFO | Required by |",
              "|---|---|---|---:|---:|---:|---:|"]
    flagged = [n for n in notes if n["findings"]]
    flagged.sort(key=lambda n: (STATUS_ORDER.index(n["status"]), -n["dependents"], n["identifier"].lower()))
    for n in flagged:
        c = Counter(f["severity"] for f in n["findings"])
        lines.append(f"| [{md(n['identifier'])}]({slugs[n['url']]}.md) | {md(n['version'] or '')} | {n['status']} | "
                     f"{c.get('BREAKS', 0)} | {c.get('CHANGED', 0)} | {c.get('INFO', 0)} | {n['dependents']} |")
    lines += ["", "## Findings by rule", "", "| Layer | Rule | Severity | Findings |", "|---|---|---|---:|"]
    for (layer, rule, s), k in sorted(by_rule.items()):
        lines.append(f"| {layer} | [`{rule}`]({GUIDE}#rule-{rule}) | {s} | {k} |")
    lines += ["", "## All expansions", "", "<details><summary>All "
              f"{len(notes)} expansions</summary>", "",
              "| Expansion | Version | .js files | Status |", "|---|---|---:|---|"]
    for n in notes:
        name = f"[{md(n['identifier'])}]({slugs[n['url']]}.md)" if n["findings"] else md(n["identifier"])
        lines.append(f"| {name} | {md(n['version'] or '')} | {n['js_files']} | {n['status']} |")
    lines += ["", "</details>", "", "Generated by `tools/oxp-scan/notes.py`. Do not edit by hand.", ""]
    return "\n".join(lines)


def render():
    notes = build()
    slugs, used = {}, set()
    for n in notes:
        s = slug(n["identifier"])
        if s.lower() in used or s.lower() == "readme":
            s = f"{s}-{(n['sha256'] or '')[:8]}"
        used.add(s.lower())
        slugs[n["url"]] = s
    out = {NOTES_JSON: json.dumps({"generated_by": "tools/oxp-scan/notes.py", "expansions": notes},
                                  indent=1, ensure_ascii=False) + "\n",
           DOCS / "README.md": index(notes, slugs)}
    for n in notes:
        if n["findings"]:
            out[DOCS / f"{slugs[n['url']]}.md"] = page(n)
    return notes, out


def main(argv):
    check = "--check" in argv
    notes, out = render()
    if len(notes) != len(load(MANIFEST)["entries"]):
        sys.exit("notes do not cover every manifest entry")
    stale_pages = [p for p in DOCS.glob("*.md") if p not in out and p.name != "scan-report.md"] if DOCS.is_dir() else []
    if check:
        bad = [str(p.relative_to(REPO)) for p, text in out.items()
               if not p.is_file() or p.read_text(encoding="utf-8").replace("\r\n", "\n") != text]
        bad += [str(p.relative_to(REPO)) + " (not generated)" for p in stale_pages]
        if bad:
            print("notes are stale; run python3 tools/oxp-scan/notes.py:\n  " + "\n  ".join(bad))
            return 1
        print(f"notes up to date: {len(notes)} expansions, {len(out) - 2} pages")
        return 0
    DOCS.mkdir(parents=True, exist_ok=True)
    for p in stale_pages:
        p.unlink()
    for p, text in out.items():
        p.write_text(text, encoding="utf-8", newline="\n")
    c = Counter(n["status"] for n in notes)
    print(f"wrote {len(notes)} notes, {len(out) - 2} pages: " +
          ", ".join(f"{s} {c[s]}" for s in STATUS_ORDER if c.get(s)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
