"""Verification of one step (research R5, R9, R11).

A step is checked out in a shared worktree and rebuilt incrementally (`./mk.sh build test`), then
its suites run. The matrix depends on the step's era, read from its tree:

    objc-spidermonkey  Objective-C sources under src/ and SpiderMonkey linked (upstream's base)
    objc-quickjs       Objective-C sources, SpiderMonkey gone
    cxx                no Objective-C under src/

GCC is attempted from the C++ era on, and required wherever the parent built with GCC: no step may
break a compiler its parent builds with. Objective-C eras build in the isolated MSYS2 under
.agent-tmp/msys2-objc (upstream's packages); the C++ era in the developer's MSYS2, where develop
builds. Clang and GCC use separate worktrees, so each keeps its own incremental build directory.
"""
import datetime
import os
import re
import subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AGENT_TMP = os.path.join(ROOT, ".agent-tmp")
WORKTREES = {"clang": os.path.join(AGENT_TMP, "series-verify"), "gcc": os.path.join(AGENT_TMP, "series-verify-gcc")}
LOG_DIR = os.path.join(AGENT_TMP, "series-verify-logs")
SHELLS = {
    "objc": os.environ.get("OO_SERIES_MSYS_OBJC", os.path.join(AGENT_TMP, "msys2-objc")),
    "cxx": os.environ.get("OO_SERIES_MSYS_CXX", "C:/Users/jon/scoop/apps/msys2/current"),
}
CHECKS = ("build_clang", "warnings_clang", "build_gcc", "unit", "smoke", "component")

SPIDERMONKEY_RE = re.compile(r"\bwin_js_suffix\b|\bjs_static\b|dependency\('nspr'\)|js32ECMAv5|mozjs")
DARWIN_MESON = "src/meson/darwin/"
OBJC_RE = re.compile(r"^src/.*\.(m|mm)$")
# a compiler, driver or linker diagnostic: "path:line:col: warning:", "clang++: warning:", "ld.lld: warning:"
WARNING_RE = re.compile(r"^(?:\S.*?:\d+(?::\d+)?|[\w.+-]*ld[\w.+-]*|(?:clang|gcc|g)(?:\+\+)?(?:\.exe)?|cc1\w*): warning: ",
                        re.M)
FEATURES = "tests/component/features/"
COMPONENT_SUPPORT = ("tests/component/steps/", "tests/component/conftest.py", "tests/component/support/")


def _git(repo, *args, ok=(0,)):
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, encoding="utf-8")
    if r.returncode not in ok:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()[-400:]}")
    return r.stdout


def era(repo, tree):
    files = _git(repo, "ls-tree", "-r", "--name-only", tree).splitlines()
    objc = any(OBJC_RE.match(p) for p in files)
    if not objc:
        return "cxx"
    # the era is the Windows build's: macOS's meson file keeps SpiderMonkey until macOS is converted
    meson = [p for p in files if p.endswith("meson.build") and not p.startswith(DARWIN_MESON)]
    for p in meson:
        if SPIDERMONKEY_RE.search(_git(repo, "cat-file", "-p", f"{tree}:{p}")):
            return "objc-spidermonkey"
    return "objc-quickjs"


def _passed(record, check):
    return str(((record or {}).get("checks") or {}).get(check, "")).startswith("pass")


def gcc_required(parent_record):
    return _passed(parent_record, "build_gcc")


def gcc_attempted(step_era, parent_record):
    return step_era == "cxx" or gcc_required(parent_record)


def _warnings(log):
    return set(m.group(0) + log[m.end():log.find("\n", m.end())] for m in WARNING_RE.finditer(log))


def warning_count(log):
    return len(_warnings(log))


_LOCATION_RE = re.compile(r"^(?:\.\./)*(?:[A-Za-z]:)?[^:]*?(?=[^/:]*/|[^/:]*:)")


def warning_keys(log):
    """The build's warnings without line and column numbers or the build directory's prefix, so the
    same warning matches across steps that move it (seriesb: a step is judged by the warnings its
    parent does not have)."""
    out = set()
    for w in _warnings(log):
        loc, sep, rest = w.partition(": warning: ")
        loc = re.sub(r":\d+(?::\d+)?$", "", loc.strip())
        loc = re.sub(r"^(?:\.\./)+", "", loc.replace("\\", "/"))
        loc = re.sub(r"^.*?/(?=(?:src|subprojects|tests|deps)/)", "", loc)
        out.add(f"{loc}: warning: {rest.strip()}" if sep else w.strip())
    return out


def warnings_verdict_relative(log, n, listed, inherited):
    """warnings_verdict, counting only warnings the parent's build does not have (`inherited`)."""
    keys = warning_keys(log)
    found = _warnings(log)
    known = {w for w in found if _is_listed(w, n, listed)}
    known_keys = warning_keys("\n".join(known))
    new = keys - set(inherited) - known_keys
    note = f"{len(keys & set(inherited))} inherited from the parent"
    if known:
        note += f", {len(known)} listed in {os.path.basename(TEST_WARNINGS)}"
    if not new:
        return f"pass: 0 new warnings ({note})" if keys else "pass: 0 warnings"
    return f"fail: {len(new)} new warnings ({note}): " + "; ".join(sorted(new)[:3])


# Warnings the history's own test files raise under the series' newer compiler. The series never
# edits a test and never silences a warning, so these are listed, per step range, instead of fixed;
# every other warning fails the step. Only files under tests/ can be listed.
TEST_WARNINGS = os.path.join(ROOT, "specs", "001-split-migration-prs", "series", "test-warnings.md")
_ROW_RE = re.compile(r"^\|\s*(\d+)(?:\s*[–-]\s*(\d+))?\s*\|\s*`(tests/[^`]+)`\s*\|\s*`([^`]+)`\s*\|", re.M)


def listed_test_warnings(path=None):
    """[(first step, last step, test file, warning text)] from the table in `path` (default: the profile's)."""
    path = path or TEST_WARNINGS
    if not os.path.exists(path):
        return []
    return [(int(lo), int(hi or lo), f, w) for lo, hi, f, w in _ROW_RE.findall(_read(path))]


def _is_listed(warning, n, listed):
    path = re.sub(r"^(?:\.\./)+", "", warning.split(":", 1)[0])
    return path.startswith("tests/") and any(
        lo <= n <= hi and path == f and text in warning for lo, hi, f, text in listed)


def warnings_verdict(log, n, listed):
    found = _warnings(log)
    known = {w for w in found if _is_listed(w, n, listed)}
    other = len(found) - len(known)
    note = f"{len(known)} listed in {os.path.basename(TEST_WARNINGS)}"
    if other == 0:
        return f"pass: 0 warnings outside the history's tests ({note})" if known else "pass: 0 warnings"
    return f"fail: {other} warnings" + (f" (and {note})" if known else "")


def touched_scenarios(repo, parent_tree, tree):
    """Stems of the component scenarios the step changes; all of them if it changes shared step code."""
    names = _git(repo, "diff", "--name-only", "--no-renames", parent_tree, tree, "--", "tests/component").splitlines()
    present = sorted(os.path.basename(p)[:-len(".feature")]
                     for p in _git(repo, "ls-tree", "-r", "--name-only", tree, "--", FEATURES).splitlines()
                     if p.endswith(".feature"))
    if any(p.startswith(COMPONENT_SUPPORT) for p in names):
        return present
    changed = {os.path.basename(p)[:-len(".feature")] for p in names if p.startswith(FEATURES) and p.endswith(".feature")}
    return [s for s in present if s in changed]


def plan(step_era, parent_record, has_unit, has_smoke, scenarios):
    """[(check, 'run' | 'n/a: reason')] in CHECKS order."""
    out = [("build_clang", "run"), ("warnings_clang", "run")]
    if gcc_attempted(step_era, parent_record):
        out.append(("build_gcc", "run"))
    else:
        out.append(("build_gcc", "n/a: Objective-C with the GNUstep runtime builds with Clang only (upstream too)"))
    out.append(("unit", "run" if has_unit else "n/a: the tree has no unit suites"))
    out.append(("smoke", "run" if has_smoke else "n/a: the tree has no launch snapshot"))
    out.append(("component", "run" if scenarios else "n/a: no component scenario touched"))
    return out


# --- construction integrity (research R11) ----------------------------------------------------------

SUPPRESSION_RE = re.compile(r"-Wno-|#\s*pragma\s.*diagnostic")
LEGACY_DEP_RE = {"gnustep-base": re.compile(r"['\"](?:lib)?gnustep-base['\"]"),
                 "nspr": re.compile(r"dependency\(\s*['\"]nspr['\"]"),
                 "spidermonkey": re.compile(r"\bwin_js_suffix\b|\bjs_static\b|mozjs|js32ECMAv5")}
# jidicula/clang-format-action's default include-regex, over check-path 'src' (upstream's build-all.yaml)
FORMAT_INCLUDE_RE = re.compile(r"^.*\.((((c|C)(c|pp|xx|\+\+)?$)|((h|H)h?(pp|xx|\+\+)?$))|(ino|pde|proto|cu))$")


def _blob(repo, tree, path):
    r = subprocess.run(["git", "-C", repo, "rev-parse", "-q", "--verify", f"{tree}:{path}"],
                       capture_output=True, text=True)
    return r.stdout.strip() if r.returncode == 0 else None


def _text(repo, tree, path):
    r = subprocess.run(["git", "-C", repo, "cat-file", "-p", f"{tree}:{path}"], capture_output=True)
    return r.stdout.decode("utf-8", "replace") if r.returncode == 0 else ""


def _clean_merge(repo, base, ours, theirs, path):
    """The text of a conflict-free `git merge-file` of the path's three versions, or None."""
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        files = []
        for name, t in (("ours", ours), ("base", base), ("theirs", theirs)):
            f = os.path.join(tmp, name)
            r = subprocess.run(["git", "-C", repo, "cat-file", "-p", f"{t}:{path}"], capture_output=True)
            with open(f, "wb") as out:
                out.write(r.stdout if r.returncode == 0 else b"")
            files.append(f)
        r = subprocess.run(["git", "merge-file", "-p", *files], capture_output=True)
        return r.stdout if r.returncode == 0 else None


def check_tests_untouched(repo, tree, source, ours, resolution_paths, base=None):
    """(a) every tests/ file is the source snapshot's, upstream's (`ours`, the merge's other side), or
    the conflict-free merge of the two, and no stored resolution is a test file."""
    bad = [p for p in resolution_paths if p.startswith("tests/")]
    for p in _git(repo, "diff", "--name-only", "--no-renames", source, tree, "--", "tests/").splitlines():
        if _blob(repo, tree, p) == _blob(repo, ours, p):
            continue
        merged = _clean_merge(repo, base, ours, source, p) if base else None
        if merged is None or merged != subprocess.run(["git", "-C", repo, "cat-file", "-p", f"{tree}:{p}"],
                                                      capture_output=True).stdout:
            bad.append(p)
    return "pass" if not bad else "fail: " + ", ".join(sorted(set(bad))[:8])


def _added_lines(repo, parent_tree, tree):
    """{path: [added line]} from parent_tree to tree."""
    out, path = {}, None
    diff = subprocess.run(["git", "-C", repo, "diff", "-U0", "--no-renames", "--no-color", parent_tree, tree],
                          capture_output=True).stdout.decode("utf-8", "replace")
    for line in diff.splitlines():
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else None
        elif line.startswith("+") and path:
            out.setdefault(path, []).append(line[1:])
    return out


def check_no_new_suppressions(repo, parent_tree, tree, source):
    """(b) no added -Wno-* or #pragma diagnostic line that the source snapshot lacks."""
    bad = []
    for path, lines in _added_lines(repo, parent_tree, tree).items():
        for l in (l for l in lines if SUPPRESSION_RE.search(l)):
            # anywhere in the source snapshot: upstream renames move lines between files (#737)
            found = subprocess.run(["git", "-C", repo, "grep", "-q", "-F", "-e", l.strip(), source],
                                   capture_output=True).returncode == 0
            if not found:
                bad.append(f"{path}: {l.strip()[:60]}")
    return "pass" if not bad else "fail: " + "; ".join(bad[:5])


def _meson_code(repo, tree):
    """The build files' code, comments stripped (macOS's file excluded, as for the era)."""
    files = [p for p in _git(repo, "ls-tree", "-r", "--name-only", tree).splitlines()
             if p.endswith("meson.build") and not p.startswith(DARWIN_MESON)]
    return "\n".join(line.split("#", 1)[0] for p in files for line in _text(repo, tree, p).splitlines())


def check_no_new_legacy(repo, parent_tree, tree):
    """(d) no SpiderMonkey or gnustep-base dependency that the parent lacks: per pattern, the number of
    uses in the build files' code may not grow. Mentions in comments and docs are not dependencies."""
    def count(t):
        text = _meson_code(repo, t)
        return {k: len(r.findall(text)) for k, r in LEGACY_DEP_RE.items()}
    before, after = count(parent_tree), count(tree)
    grown = [f"{k} {before[k]}->{after[k]}" for k in LEGACY_DEP_RE if after[k] > before[k]]
    return "pass" if not grown else "fail: " + ", ".join(grown)


def check_clang_format(repo, tree, formatted_tree):
    """(c) upstream's CI format check: src/ files matching the action's regex are clang-format fixed points.
    `formatted_tree` is normalise.normalise_tree(repo, tree, tree)."""
    diff = [p for p in _git(repo, "diff", "--name-only", "--no-renames", tree, formatted_tree, "--", "src/").splitlines()
            if FORMAT_INCLUDE_RE.match(p)]
    return "pass" if not diff else f"fail: {len(diff)} files not formatted: " + ", ".join(diff[:5])


# --- running ---------------------------------------------------------------------------------------

def _shell(step_era):
    return SHELLS["cxx" if step_era == "cxx" else "objc"]


def ensure_worktree(repo, path, commit):
    if not os.path.isdir(path):
        _git(repo, "worktree", "add", "-q", "--detach", path, commit)
    else:
        _git(path, "checkout", "-q", "--detach", "--force", commit)
        # untracked and ignored leftovers too (a subproject extracted under an older wrap or patch),
        # but never the build directory or the downloaded subproject archives
        _git(path, "clean", "-q", "-d", "-f", "-f", "-x", "-e", "build/", "-e", "subprojects/packagecache/")
    return path


def _msys_path(p):
    p = os.path.abspath(p).replace("\\", "/")
    return f"/{p[0].lower()}{p[2:]}" if re.match(r"^[A-Za-z]:", p) else p


def run_script(step_era, body, log):
    """Run `body` in a UCRT64 login shell of the era's MSYS2, appending output to `log`. Returns the exit code."""
    os.makedirs(os.path.dirname(log), exist_ok=True)
    script = log[:-4] + ".sh"
    with open(script, "w", encoding="utf-8", newline="\n") as f:
        f.write("#!/bin/bash\nset -o pipefail\n" + body + "\n")
    bash = os.path.join(_shell(step_era), "usr", "bin", "bash.exe")
    env = dict(os.environ, MSYSTEM="UCRT64", CHERE_INVOKING="1")
    with open(log, "ab") as out:
        return subprocess.run([bash, "-l", _msys_path(script)], stdout=out, stderr=subprocess.STDOUT, env=env).returncode


def _read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def run_build(step_era, worktree, compiler, clean, log):
    native = " --native-file=gcc.ini" if compiler == "gcc" else ""
    body = f"cd '{_msys_path(worktree)}' || exit 2\n"
    if clean:
        body += "rm -rf build/meson_test\n"
    # keep going past failed objects, so one run reports every error and warning of the step
    body += f"./mk.sh{native} --compile-flags=--ninja-args=-k0 build test"
    rc = run_script(step_era, body, log)
    return rc, warning_count(_read(log))


def run_unit(step_era, worktree, suites, log):
    body = f"cd '{_msys_path(worktree)}' || exit 2\nrc=0\n"
    for s in suites:
        body += f"meson test -C build/meson_test --suite {s} --print-errorlogs || rc=1\n"
    return run_script(step_era, body + "exit $rc", log)


def run_smoke(step_era, worktree, log):
    return run_script(step_era, f"cd '{_msys_path(worktree)}' || exit 2\n./mk.sh test test", log)


def run_component(step_era, worktree, scenarios, log):
    venv = _msys_path(os.path.join(AGENT_TMP, "series-verify-venv"))
    body = (f"cd '{_msys_path(worktree)}' || exit 2\n"
            f"[ -x {venv}/bin/python ] || python3 -m venv {venv} || exit 2\n"
            f"{venv}/bin/python -m pip install -q --disable-pip-version-check -r tests/component/requirements.txt || exit 2\n"
            f"{venv}/bin/python -m pytest tests/component -x -q -k '{' or '.join(scenarios)}'")
    return run_script(step_era, body, log)


def unit_suites(repo, tree):
    files = set(_git(repo, "ls-tree", "-r", "--name-only", tree, "--", "tests/unit").splitlines())
    suites = [s for s in ("oofnd", "core") if f"tests/unit/{s}/meson.build" in files]
    if suites and "tests/check_headers_standalone.py" in _git(repo, "ls-tree", "--name-only", tree, "--", "tests/"):
        suites.append("headers")
    return suites


def verify_step(repo, step, parent_tree, parent_record, clean=False, integrity=None, inherited=None,
                listed_n=None):
    """Run the step's matrix; returns its verification record. With `inherited` (seriesb), warnings
    are counted against the parent's; `listed_n` is the step number test-warnings.md is keyed by."""
    branch = step["branch"]
    commit = _git(repo, "rev-parse", f"refs/heads/{branch}").strip()
    tree = _git(repo, "rev-parse", f"{commit}^{{tree}}").strip()
    step_era = era(repo, tree)
    suites = unit_suites(repo, tree)
    has_smoke = "tests/launch_snapshot.py" in _git(repo, "ls-tree", "--name-only", tree, "--", "tests/")
    scenarios = touched_scenarios(repo, parent_tree, tree) if parent_tree else []
    checks = dict(plan(step_era, parent_record, bool(suites), has_smoke, scenarios))
    stamp = f"{step['n']:03d}"
    log = lambda what: os.path.join(LOG_DIR, f"{stamp}-{what}.log")
    for what in ("build_clang", "build_gcc", "unit", "smoke", "component"):
        if os.path.exists(log(what)):
            os.remove(log(what))

    wt = ensure_worktree(repo, WORKTREES["clang"], commit)
    listed = listed_test_warnings()
    ln = listed_n or step["n"]
    verdict = (lambda text: warnings_verdict(text, ln, listed)) if inherited is None else \
        (lambda text: warnings_verdict_relative(text, ln, listed, inherited))
    rc, _ = run_build(step_era, wt, "clang", clean, log("build_clang"))
    checks["build_clang"] = "pass" if rc == 0 else f"fail: exit {rc} (see {os.path.relpath(log('build_clang'), ROOT)})"
    checks["warnings_clang"] = verdict(_read(log("build_clang"))) if rc == 0 \
        else "n/a: the build failed"
    if checks["build_gcc"] == "run":
        gwt = ensure_worktree(repo, WORKTREES["gcc"], commit)
        grc, _ = run_build(step_era, gwt, "gcc", clean, log("build_gcc"))
        gverdict = verdict(_read(log("build_gcc")))
        if grc == 0 and gverdict.startswith("pass"):
            checks["build_gcc"] = gverdict.replace("pass: 0 warnings", "pass", 1) if gverdict != "pass: 0 warnings" else "pass"
        elif grc == 0:
            checks["build_gcc"] = gverdict
        elif gcc_required(parent_record):
            checks["build_gcc"] = f"fail: exit {grc} (the parent builds with GCC)"
        else:
            checks["build_gcc"] = f"n/a: does not build with GCC yet (exit {grc}); the parent does not either"
    built = rc == 0
    for check, runner in (("unit", lambda: run_unit(step_era, wt, suites, log("unit"))),
                          ("smoke", lambda: run_smoke(step_era, wt, log("smoke"))),
                          ("component", lambda: run_component(step_era, wt, scenarios, log("component")))):
        if checks[check] != "run":
            continue
        if not built:
            checks[check] = "fail: not run, the build failed"
            continue
        r = runner()
        checks[check] = "pass" + (f": {', '.join(suites)}" if check == "unit" else
                                  f": {', '.join(scenarios)}" if check == "component" else "") if r == 0 \
            else f"fail: exit {r} (see {os.path.relpath(log(check), ROOT)})"
    if integrity:
        checks.update(integrity)
    record = {"commit": commit, "tree": tree, "era": step_era, "date": datetime.date.today().isoformat(),
              "clean": clean, "checks": checks}
    if inherited is not None and rc == 0:
        record["warning_keys"] = sorted(warning_keys(_read(log("build_clang"))))
    return record


def record_passes(record):
    return bool(record) and all(str(v).startswith(("pass", "n/a")) for v in record.get("checks", {}).values())
