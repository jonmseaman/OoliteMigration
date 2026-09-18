"""Tests for the read-only fleet reporter (bead oo-l7r0).

Two classes of test, and the second is the point:

POSITIVE: the report contains every daily metric parsed out of docs/infra/4-metrics.md, it
distinguishes a measured zero from an uncomputable metric, and at least one number matches a
value computed by an independent path.

NEGATIVE: the read-only enforcement actually BLOCKS.  Each refusal test has a twin that loads a
copy of tools/fleet_reporter.py with the marked enforcement region stripped and asserts the
action then SUCCEEDS - i.e. the test goes red when the enforcement is removed, so it is proof
rather than decoration.  The strip is done on a temp copy; the real file is never touched.
"""

from __future__ import annotations

import datetime as dt
import importlib.util
import json
import os
import re
import subprocess
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
MODULE_PATH = os.path.join(ROOT, "tools", "fleet_reporter.py")
DOC = os.path.join(ROOT, "docs", "infra", "4-metrics.md")

sys.path.insert(0, os.path.join(ROOT, "tools"))
import fleet_reporter as fr  # noqa: E402


def _load_variant(tmp_path, name, transform):
    """Import a private copy of fleet_reporter.py with `transform` applied to its source."""
    src = open(MODULE_PATH, encoding="utf-8").read()
    mutated = transform(src)
    assert mutated != src, "transform changed nothing; the mutant would be identical to the real module"
    p = tmp_path / f"{name}.py"
    p.write_text(mutated, encoding="utf-8")
    spec = importlib.util.spec_from_file_location(name, str(p))
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def _strip_region(marker):
    def t(src):
        out, n = re.subn(
            rf"# BEGIN-ENFORCEMENT-{marker}.*?# END-ENFORCEMENT-{marker}",
            f"_{marker}_ENFORCED = False  # enforcement stripped by the mutant",
            src,
            flags=re.S,
        )
        assert n == 1, f"expected exactly one ENFORCEMENT-{marker} region, found {n}"
        return out
    return t


@pytest.fixture(scope="module")
def report(tmp_path_factory):
    """One real generation run, reused by the positive tests."""
    out = tmp_path_factory.mktemp("report")
    today = dt.date.today().isoformat()
    path = os.path.join(str(out), f"REPORT-{today}.md")
    g = fr.ReadOnlyGuard(path)
    payload = fr.build_report(ROOT, DOC, g, bd_exe=fr.default_bd(), today=today)
    g.write_text(path, fr.render(payload))
    return path, payload, g


# ----------------------------------------------------------------- positive


def test_every_daily_metric_in_the_doc_is_in_the_report(report):
    path, payload, _ = report
    doc = fr.daily_metrics_from_doc(DOC)
    assert len(doc) >= 8, f"parsed only {len(doc)} daily metrics; the check would be vacuous"
    got = {m["id"] for m in payload["metrics"]}
    missing = [label for slug, label, _ in doc if slug not in got]
    assert not missing, f"metrics defined in the doc but absent from the report: {missing}"
    text = open(path, encoding="utf-8").read()
    for slug, label, _ in doc:
        assert f"### {slug}" in text, f"{label} has no prose section"


def test_the_metric_list_is_derived_not_hardcoded(tmp_path):
    """Add a metric to a COPY of the doc: the check must go red naming it."""
    doc2 = tmp_path / "4-metrics.md"
    src = open(DOC, encoding="utf-8").read()
    src = src.replace(
        "| Tier-1 corpus green | Tier B/C | expansions still work |",
        "| Tier-1 corpus green | Tier B/C | expansions still work |\n"
        "| Invented metric for the derivation test | nowhere | proves the list is parsed |",
    )
    doc2.write_text(src, encoding="utf-8")
    assert len(fr.daily_metrics_from_doc(str(doc2))) == len(fr.daily_metrics_from_doc(DOC)) + 1

    today = dt.date.today().isoformat()
    path = str(tmp_path / f"REPORT-{today}.md")
    g = fr.ReadOnlyGuard(path)
    g.write_text(path, fr.render(fr.build_report(ROOT, DOC, g, bd_exe=fr.default_bd(), today=today)))

    ok, msgs = fr.check_report(path, str(doc2), ROOT, fr.default_bd())
    assert not ok, "the checker passed against a doc containing a metric the report lacks"
    assert any("Invented metric for the derivation test" in m for m in msgs), msgs


def test_zero_and_not_computed_are_distinguishable(report):
    path, payload, _ = report
    text = open(path, encoding="utf-8").read()
    measured, uncomputed = [], []
    for m in payload["metrics"]:
        for k, v in m["values"].items():
            assert ("value" in v) != ("not_computed" in v), f"{m['id']}.{k} is ambiguous"
            (measured if "value" in v else uncomputed).append((m["id"], k, v))
    assert measured, "nothing at all was measured"
    assert uncomputed, (
        "every metric claims a value: either this fleet really has every source wired up, or "
        "the reporter is silently printing 0 for sources it cannot read")
    for mid, k, v in uncomputed:
        assert "NOT COMPUTED" in text
        assert not re.search(rf"`{re.escape(k)}` = 0\b", text), (
            f"{mid}.{k} is not computed yet the prose prints it as 0")
        assert v["not_computed"].strip(), f"{mid}.{k} has an empty reason"


def test_a_real_zero_is_reported_as_zero_not_as_uncomputed(report):
    """Zeros are allowed and must survive: the re-bless queue really has 0 proposed."""
    _, payload, _ = report
    rb = next(m for m in payload["metrics"] if m["id"].startswith("re-bless"))
    assert rb["values"]["proposed"] == {"value": 0}, rb["values"]


def test_reported_numbers_match_independently_computed_ones(report):
    path, payload, _ = report
    ok, msgs = fr.check_report(path, DOC, ROOT, fr.default_bd())
    assert ok, msgs
    crosschecks = [m for m in msgs if "cross-check OK" in m]
    assert len(crosschecks) >= 2, f"only {len(crosschecks)} independent cross-checks ran: {msgs}"


def test_a_faked_number_is_caught_by_the_cross_check(tmp_path, report):
    """Tamper with a reported count: the independent recount must catch it."""
    path, payload, _ = report
    text = open(path, encoding="utf-8").read()
    p = json.loads(re.search(r"```json\n(.*?)\n```", text, re.S).group(1))
    adr = next(m for m in p["metrics"] if m["id"] == "proposed-adrs-awaiting-override")
    adr["values"]["awaiting_override"]["value"] += 7
    tampered = str(tmp_path / os.path.basename(path))
    open(tampered, "w", encoding="utf-8").write(
        re.sub(r"```json\n.*?\n```", "```json\n" + json.dumps(p, indent=2) + "\n```", text, flags=re.S))
    ok, msgs = fr.check_report(tampered, DOC, ROOT, fr.default_bd())
    assert not ok
    assert any("independently counted" in m for m in msgs), msgs


def test_days_since_origin_main_and_fork_migration_are_present(report):
    _, payload, _ = report
    m = next(x for x in payload["metrics"] if x["id"].startswith("days-since-origin-main"))
    for key in ("days_since_origin_main", "days_since_fork_migration", "fork_migration_matched"):
        assert key in m["values"], f"{key} missing"
    v = m["values"]["days_since_origin_main"]
    assert "value" in v and isinstance(v["value"], (int, float)) and v["value"] >= 0


# ----------------------------------------------------------------- negative


def test_writing_outside_the_report_file_is_refused(tmp_path):
    g = fr.ReadOnlyGuard(str(tmp_path / "REPORT-x.md"))
    victim = tmp_path / "victim.txt"
    victim.write_text("original", encoding="utf-8")
    with pytest.raises(fr.Refusal) as e:
        g.write_text(str(victim), "clobbered")
    assert "REFUSED WRITE" in str(e.value)
    assert victim.read_text(encoding="utf-8") == "original", "the refusal did not prevent the write"


def test_the_write_refusal_is_what_prevents_it(tmp_path):
    """RED-TWIN: with the write enforcement stripped, the same call clobbers the file."""
    mod = _load_variant(tmp_path, "fr_nowrite", _strip_region("WRITE"))
    assert mod._WRITE_ENFORCED is False
    g = mod.ReadOnlyGuard(str(tmp_path / "REPORT-x.md"))
    victim = tmp_path / "victim2.txt"
    victim.write_text("original", encoding="utf-8")
    g.write_text(str(victim), "clobbered")
    assert victim.read_text(encoding="utf-8") == "clobbered", (
        "stripping the enforcement did not change the behaviour, so the positive test proves nothing")


MUTATIONS = [
    (["C:/tools/bd/bd.exe", "close", "oo-l7r0"], "bd close"),
    (["bd", "close", "oo-l7r0", "--reason", "done"], "bd close"),
    (["C:/tools/bd/bd.exe", "update", "oo-l7r0", "--status", "closed"], "bd update"),
    (["bd", "update", "oo-l7r0", "--claim"], "--claim"),
    (["git", "commit", "-m", "x"], "git commit"),
    (["git", "-C", ROOT, "commit", "-m", "x"], "git commit"),
    (["git", "push", "origin", "main"], "git push"),
    (["git", "-C", ROOT, "push"], "git push"),
    (["git", "add", "-A"], "git add"),
    (["rm", "-rf", ROOT], "rm"),
]


@pytest.mark.parametrize("argv,needle", MUTATIONS, ids=[m[1].replace(" ", "_") + str(i) for i, m in enumerate(MUTATIONS)])
def test_mutating_commands_are_refused_before_exec(tmp_path, argv, needle):
    g = fr.ReadOnlyGuard(str(tmp_path / "REPORT-x.md"))
    with pytest.raises(fr.Refusal) as e:
        g.run(argv)
    assert "REFUSED COMMAND" in str(e.value)
    assert g.exec_trace == [], "the command was recorded as executed; the refusal came too late"


def test_read_only_commands_are_allowed(tmp_path):
    g = fr.ReadOnlyGuard(str(tmp_path / "REPORT-x.md"))
    assert fr.classify_argv(["git", "-C", ROOT, "log", "-1"]) is None
    assert fr.classify_argv(["C:/tools/bd/bd.exe", "list", "--json"]) is None
    rc, so, _ = g.run(["git", "-C", ROOT, "rev-parse", "HEAD"])
    assert rc == 0 and len(so.strip()) == 40
    assert g.exec_trace, "a permitted command was not recorded in the trace"


def test_the_exec_refusal_is_what_prevents_it(tmp_path):
    """RED-TWIN: with the exec enforcement stripped, `bd close` is no longer refused."""
    mod = _load_variant(tmp_path, "fr_noexec", _strip_region("EXEC"))
    assert mod._EXEC_ENFORCED is False
    g = mod.ReadOnlyGuard(str(tmp_path / "REPORT-x.md"))
    g.run([sys.executable, "-c", "print('bd close would have run here')"])
    assert g.exec_trace, "the stripped mutant still refused; the enforcement is not the reason"
    assert mod.classify_argv(["bd", "close", "oo-l7r0"]) is not None, (
        "classify_argv itself should still classify; only the guard's use of it is stripped")


def test_a_full_run_executes_no_mutating_command_and_writes_one_file(tmp_path):
    out = tmp_path / "out"
    today = dt.date.today().isoformat()
    path = str(out / f"REPORT-{today}.md")
    g = fr.ReadOnlyGuard(path)
    g.write_text(path, fr.render(fr.build_report(ROOT, DOC, g, bd_exe=fr.default_bd(), today=today)))
    assert os.listdir(str(out)) == [f"REPORT-{today}.md"], "the run wrote more than its report file"
    assert g.refusals == []
    assert g.exec_trace, "no subprocess ran at all: the report cannot have read git or bd"
    for argv in g.exec_trace:
        assert fr.classify_argv(argv) is None, f"a mutating command ran: {argv}"


def test_the_repo_is_untouched_by_a_run(tmp_path):
    """The live worktree's git status must be identical before and after a run elsewhere."""
    before = subprocess.run(["git", "-C", ROOT, "status", "--porcelain"],
                            capture_output=True, text=True).stdout
    today = dt.date.today().isoformat()
    path = str(tmp_path / f"REPORT-{today}.md")
    g = fr.ReadOnlyGuard(path)
    g.write_text(path, fr.render(fr.build_report(ROOT, DOC, g, bd_exe=fr.default_bd(), today=today)))
    after = subprocess.run(["git", "-C", ROOT, "status", "--porcelain"],
                           capture_output=True, text=True).stdout
    assert before == after, f"the run changed the worktree:\n{before!r}\n{after!r}"


def test_the_committed_report_exists_and_passes_its_own_check():
    """The definition of done: one report file, every metric present, check green."""
    d = os.path.join(ROOT, "docs", "fleet")
    reports = sorted(f for f in os.listdir(d) if re.fullmatch(r"REPORT-\d{4}-\d{2}-\d{2}\.md", f))
    assert reports, "no docs/fleet/REPORT-<date>.md exists"
    ok, msgs = fr.check_report(os.path.join(d, reports[-1]), DOC, ROOT, fr.default_bd())
    assert ok, msgs
