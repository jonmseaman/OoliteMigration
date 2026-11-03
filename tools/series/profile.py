"""The two series this tool builds (specs/002-seriesb-rebase-stack, research R8).

`series`  feature 001: series/NNN steps from the migration's history on upstream 49a5eb9fc.
`seriesb` feature 002: seriesb/NNN steps replaying the series/ steps on upstream #767/#768.

The modules keep module-level names (series.SERIES_DIR, stack.ROOT_BRANCH, manifest.BRANCH_RE, ...),
defaulting to the `series` profile; `activate` rebinds them, and every function reads them at call
time. Without `--series`, the tool behaves exactly as feature 001's.
"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AGENT_TMP = os.path.join(ROOT, ".agent-tmp")
SERIESB_DEFAULT_ROOT = "seriesb/000b-upstream-768-quickjs-only"

PROFILES = {
    "series": {
        "prefix": "series/",
        "dir": os.path.join(ROOT, "specs", "001-split-migration-prs", "series"),
        "root": "series/000-upstream-base",
        "sources": ("history", "hoisted", "develop"),
        "stack_worktree": os.path.join(AGENT_TMP, "series-stack"),
        "resolve_scratch": os.path.join(AGENT_TMP, "series-resolve"),
        "verify_worktrees": {"clang": os.path.join(AGENT_TMP, "series-verify"),
                             "gcc": os.path.join(AGENT_TMP, "series-verify-gcc")},
        "verify_logs": os.path.join(AGENT_TMP, "series-verify-logs"),
    },
    "seriesb": {
        "prefix": "seriesb/",
        "dir": os.path.join(ROOT, "specs", "002-seriesb-rebase-stack", "series"),
        "root": None,  # the last live parent, from the manifest
        "sources": ("replay",),
        "stack_worktree": os.path.join(AGENT_TMP, "seriesb-stack"),
        "resolve_scratch": os.path.join(AGENT_TMP, "seriesb-resolve"),
        "verify_worktrees": {"clang": os.path.join(AGENT_TMP, "seriesb-verify-wt"),
                             "gcc": os.path.join(AGENT_TMP, "seriesb-verify-wt-gcc")},
        "verify_logs": os.path.join(AGENT_TMP, "seriesb-verify-logs"),
    },
}

ACTIVE = "series"


def step_branch_re(prefix):
    return re.compile(rf"^{re.escape(prefix)}(\d{{3}})-[a-z0-9]+(?:-[a-z0-9]+)*$")


def live_parents(m):
    return [p for p in (m or {}).get("parents", []) if p.get("state") != "retired"]


def _load(path):
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def get(name, m=None):
    """The profile `name`, with `root` resolved (for seriesb, from manifest `m`, or the one on disk)."""
    p = dict(PROFILES[name])
    p["manifest"] = os.path.join(p["dir"], "manifest.json")
    p["test_warnings"] = os.path.join(p["dir"], "test-warnings.md")
    p["branch_re"] = step_branch_re(p["prefix"])
    if p["root"] is None:
        if m is None:
            m = _load(p["manifest"])
        live = live_parents(m)
        p["root"] = live[-1]["branch"] if live else SERIESB_DEFAULT_ROOT
    return p


def activate(name, m=None):
    """Rebind the modules' profile names to `name`'s values. Returns the profile."""
    global ACTIVE
    from tools.series import manifest, renumber, series, stack, verify
    p = get(name, m)
    ACTIVE = name
    series.SERIES_DIR = p["dir"]
    series.MANIFEST = p["manifest"]
    series.INVENTORY = os.path.join(p["dir"], "inventory.tsv")
    series.HANDOVER = os.path.join(p["dir"], "HANDOVER.md")
    series.STACK_WORKTREE = p["stack_worktree"]
    series.RESOLVE_SCRATCH = p["resolve_scratch"]
    stack.ROOT_BRANCH = p["root"]
    stack.PREFIX = p["prefix"]
    manifest.ROOT_BRANCH = p["root"]
    manifest.BRANCH_RE = p["branch_re"]
    renumber.BRANCH_RE = re.compile(rf"^{re.escape(p['prefix'])}(\d{{3}})-(.+)$")
    renumber.TMP = p["prefix"] + "renumbering/"
    verify.TEST_WARNINGS = p["test_warnings"]
    verify.WORKTREES = dict(p["verify_worktrees"])
    verify.LOG_DIR = p["verify_logs"]
    return p


def current():
    return ACTIVE
