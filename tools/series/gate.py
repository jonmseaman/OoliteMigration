"""Gate G1: a seriesb parent must build and pass its own tests here before a step is built on it
(spec FR-003a, research R6).

The checks are the parent's own Windows CI job, read from its tree: every `./mk.sh` line in the job
whose name or runner says windows, once per value of its `js_engine` matrix. Then `./mk.sh build
test`, the build type the steps are verified with. Warnings are counted but do not fail the gate
(upstream's CI does not fail on them). The parent itself is never changed: a failure is flagged,
and Jon chooses a fix parent or a hold (plan.md Notes).
"""
import datetime
import os
import re
import subprocess

from tools.series import verify

WORKFLOW = ".github/workflows/test_builds.yaml"
DEFAULT = ["./mk.sh build deployment", "./mk.sh test deployment"]
MK_RE = re.compile(r"(\./mk\.sh\b[^;\n]*?)(?:;\s*then)?\s*$")
MATRIX_RE = re.compile(r"^\s*js_engine:\s*\[([^\]]*)\]", re.M)


def _jobs(text):
    """{job name: its lines} for the top-level jobs of a workflow (two-space indented keys)."""
    jobs, cur = {}, None
    in_jobs = False
    for line in text.splitlines():
        if line.startswith("jobs:"):
            in_jobs = True
            continue
        if not in_jobs:
            continue
        m = re.match(r"^  ([A-Za-z0-9_-]+):\s*$", line)
        if m:
            cur = m.group(1)
            jobs[cur] = []
        elif cur and (line.startswith("   ") or not line.strip()):
            jobs[cur].append(line)
        elif line.strip() and not line.startswith(" "):
            in_jobs, cur = False, None
    return jobs


def variants(workflow_text):
    """[(label, [commands])] for the Windows job: one per js_engine matrix value, else one 'default'."""
    if not workflow_text:
        return [("default", list(DEFAULT))]
    for name, lines in _jobs(workflow_text).items():
        body = "\n".join(lines)
        if "windows" not in name.lower() and not re.search(r"runs-on:\s*windows", body):
            continue
        commands = []
        for line in lines:
            m = MK_RE.search(line.strip().removeprefix("if ").strip())
            if m and line.strip().startswith(("./mk.sh", "if ./mk.sh")):
                commands.append(m.group(1).strip())
        if not commands:
            continue
        mm = MATRIX_RE.search(body)
        if mm and any("matrix.js_engine" in c for c in commands):
            engines = [e.strip().strip("'\"") for e in mm.group(1).split(",") if e.strip()]
            return [(e, [c.replace("${{ matrix.js_engine }}", e) for c in commands]) for e in engines]
        return [("default", commands)]
    return [("default", list(DEFAULT))]


def run(repo, parent, worktree, log_dir, runner=None):
    """Run the gate for `parent` (a manifest entry); updates and returns it."""
    runner = runner or verify.run_script
    branch = parent["branch"]
    commit = verify._git(repo, "rev-parse", f"refs/heads/{branch}").strip()
    tree = verify._git(repo, "rev-parse", f"{commit}^{{tree}}").strip()
    era = verify.era(repo, tree)
    r = subprocess.run(["git", "-C", repo, "cat-file", "-p", f"{commit}:{WORKFLOW}"], capture_output=True, text=True,
                       encoding="utf-8")
    plan = variants(r.stdout if r.returncode == 0 else None)
    wt = verify.ensure_worktree(repo, worktree, commit)
    stem = branch.split("/", 1)[1].split("-", 1)[0]  # 000a
    checks, commands, warnings = {}, [], {}
    cd = f"cd '{verify._msys_path(wt)}' || exit 2\n"
    for label, cmds in plan:
        # a clean deployment build per variant: a meson option changes only at setup
        log = os.path.join(log_dir, f"gate-{stem}-{label}.log")
        if os.path.exists(log):
            os.remove(log)
        runner(era, wt, cd + "rm -rf build/meson_deployment", log)
        for c in cmds:
            kind = "build" if " build " in f" {c} " else "test" if " test " in f" {c} " else "run"
            key = f"{kind}_{label}"
            commands.append(c)
            if checks.get(f"build_{label}", "pass") != "pass" and kind == "test":
                checks[key] = "fail: not run, the build failed"
                continue
            rc = runner(era, wt, cd + c, log)
            checks[key] = "pass" if rc == 0 else f"fail: exit {rc} (see {os.path.relpath(log, verify.ROOT)})"
            if kind == "build":
                warnings[label] = verify.warning_count(verify._read(log)) if os.path.exists(log) else 0
    log = os.path.join(log_dir, f"gate-{stem}-build_test.log")
    if os.path.exists(log):
        os.remove(log)
    commands.append("./mk.sh build test")
    rc = runner(era, wt, cd + "./mk.sh build test", log)
    checks["build_test"] = "pass" if rc == 0 else f"fail: exit {rc} (see {os.path.relpath(log, verify.ROOT)})"
    warnings["test"] = verify.warning_count(verify._read(log)) if os.path.exists(log) else 0
    parent["verification"] = {"commit": commit, "tree": tree, "era": era, "date": datetime.date.today().isoformat(),
                              "commands": commands, "warnings": warnings, "checks": checks}
    failing = sorted(k for k, v in checks.items() if not v.startswith("pass"))
    if parent.get("gate") == "waived":
        return parent  # Jon's decision stands (plan.md Notes)
    if failing:
        parent["gate"] = "flagged"
        parent["flag"] = "; ".join(f"{k}: {checks[k]}" for k in failing)
    else:
        parent["gate"] = "pass"
        parent.pop("flag", None)
    return parent
