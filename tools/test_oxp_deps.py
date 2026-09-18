#!/usr/bin/env python3
"""Offline proofs for the dependency-closure machinery (bead oo-kcrw).

EVERY TEST HERE RUNS WITHOUT LAUNCHING THE GAME.  That is deliberate and it is
the justification for the acceptance split: a full 36-group tier run costs
~500-900 s on this contended host and would fail on a neighbour's load rather
than on this bead's code, so the LOGIC (index, closure, cycles, unsatisfiable
requirements, attribution, verdict routing) is pinned here with fixtures and
exactly ONE stored line really loads a small set.

The fixtures are SYNTHETIC on purpose for the graph tests - a hand-built graph
can contain a cycle, a missing node and a diamond at once, which the real corpus
may not - and REAL (a captured log shape) for the judging tests.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import oxp_deps as od  # noqa: E402
import oxp_load_check as lc  # noqa: E402


def rec(ident, requires=(), optional=(), title=None):
    return {"identifier": ident, "title": title or ident, "version": "1.0",
            "url": "https://example.invalid/%s.oxz" % ident, "size": 1, "sha256": "x",
            "requires": list(requires), "optional": list(optional)}


# ------------------------------------------------------------------ closure


def test_closure_is_transitive_not_just_direct():
    """A dependency's own dependency must be staged too, or the group still
    fails for exactly the reason the bead exists to fix."""
    idx = {r["identifier"]: r for r in [
        rec("A", ["B"]), rec("B", ["C"]), rec("C")]}
    order, missing = od.closure(idx, "A")
    assert order == ["A", "B", "C"], order
    assert missing == []


def test_closure_terminates_on_a_two_cycle():
    """A<->B. A recursive walk would recurse forever; this must return."""
    idx = {r["identifier"]: r for r in [rec("A", ["B"]), rec("B", ["A"])]}
    order, missing = od.closure(idx, "A")
    assert order == ["A", "B"], order
    assert order.count("A") == 1 and order.count("B") == 1
    assert missing == []


def test_closure_terminates_on_a_three_cycle():
    idx = {r["identifier"]: r for r in [
        rec("A", ["B"]), rec("B", ["C"]), rec("C", ["A"])]}
    order, _ = od.closure(idx, "A")
    assert sorted(order) == ["A", "B", "C"], order


def test_closure_tolerates_a_self_edge():
    """A manifest naming itself is a manifest bug, not a reason to hang."""
    idx = {"A": rec("A", ["A", "B"]), "B": rec("B")}
    order, _ = od.closure(idx, "A")
    assert order == ["A", "B"], order


def test_closure_visits_a_diamond_once():
    """A->B,C and both ->D: D is staged once, not twice (a duplicate stage would
    be a filename collision in the AddOns dir)."""
    idx = {r["identifier"]: r for r in [
        rec("A", ["B", "C"]), rec("B", ["D"]), rec("C", ["D"]), rec("D")]}
    order, _ = od.closure(idx, "A")
    assert order.count("D") == 1
    assert sorted(order) == ["A", "B", "C", "D"]


def test_a_requirement_absent_from_the_corpus_is_missing_not_a_load_failure():
    """The distinction that keeps the report honest: 'we do not have it' is not
    'it failed to load'. The runner must not even launch the game for this."""
    idx = {"A": rec("A", ["B", "GONE"]), "B": rec("B")}
    order, missing = od.closure(idx, "A")
    assert order == ["A", "B"], order
    assert missing == ["GONE"], missing


def test_a_root_not_in_the_corpus_yields_no_members():
    order, missing = od.closure({}, "NOPE")
    assert order == []
    assert missing == ["NOPE"]


def test_companions_participate_in_the_walk_and_are_transitive():
    """A curated companion is followed like a declared requirement, INCLUDING
    its own requires_oxps - otherwise pairing XenonUI with a resource pack that
    itself has requirements would silently under-stage."""
    idx = {"A": rec("A"), "P": rec("P", ["Q"]), "Q": rec("Q")}
    comp = {"A": {"requires": ["P"], "reason": "r"}}
    order, missing = od.closure(idx, "A", comp)
    assert order == ["A", "P", "Q"], order
    assert missing == []


def test_the_companion_pair_is_a_real_cycle_and_still_terminates():
    """XenonUI's real shape: the pack declares requires_oxps=[XenonUI] while the
    companion table adds XenonUI->pack. That is a genuine 2-cycle in the
    augmented graph and is the corpus's own live cycle test."""
    idx = {"XenonUI": rec("XenonUI"), "Pack": rec("Pack", ["XenonUI"])}
    comp = {"XenonUI": {"requires": ["Pack"], "reason": "r"}}
    order, _ = od.closure(idx, "XenonUI", comp)
    assert order == ["XenonUI", "Pack"], order


# --------------------------------------------------- the companions table


def test_the_committed_companion_table_states_a_reason_and_evidence():
    """A companion entry without a written reason is indistinguishable from
    silencing an error, which this bead is explicitly forbidden to do."""
    comp = od.load_companions()
    assert comp, "the companions table is empty - XenonUI's decision is not recorded"
    for ident, e in comp.items():
        assert e.get("requires"), "%s names no companion" % ident
        assert len(e.get("reason", "")) > 80, (
            "%s has no substantive written reason; a companion pairing with no "
            "argument is a silenced error" % ident)
        assert e.get("evidence"), "%s cites no evidence line" % ident


def test_xenonui_is_paired_rather_than_excluded_and_the_pack_exists():
    comp = od.load_companions()
    e = comp["oolite.oxp.z.phkb.XenonUI"]
    assert e["requires"] == ["oolite.oxp.z.phkb.XenonUIResources"]
    assert "No Xenon UI Resource packs installed" in e["evidence"]


# --------------------------------------------------------------- the index


def test_the_index_maps_identifiers_to_cached_blobs_that_exist():
    """requires_oxps names IDENTIFIERS and the cache is content-addressed, so
    without this mapping no closure can be staged at all."""
    idx = od.build_index()
    assert len(idx) > 700, "index has only %d identifiers" % len(idx)
    have = [i for i in idx if idx[i]["requires"]]
    assert have, "no expansion in the corpus declares requires_oxps - the index is wrong"
    probe = "oolite.oxp.Svengali.GNN"
    assert probe in idx
    assert idx[probe]["requires"] == ["oolite.oxp.Svengali.Library"], idx[probe]["requires"]
    assert od.blob_for(idx, probe).exists(), "the indexed blob is not in the cache"


def test_every_tier1_group_resolves_and_the_known_seven_gain_dependencies():
    """The seven oo-het measured as NOTLOADED must now be multi-member groups;
    if any is still a 1-member group the grouping did nothing for it."""
    groups = {g["name"]: g for g in od.tier1_groups()}
    assert len(groups) == 36, len(groups)
    expected = {
        "oolite.oxp.Svengali.GNN": 2,
        "oolite.oxp.Thargoid.Planetfall": 7,
        "oolite.oxp.Norby.Carriers": 3,
        "oolite.oxp.Svengali.OXPConfig": 2,
        "oolite.oxp.Griff.Cobra_MkIII": 3,
        "oolite.oxp.Norby.Separated_Lasers": 2,
        "oolite.oxp.z.phkb.XenonUI": 2,   # via the companion table
    }
    for name, n in expected.items():
        assert len(groups[name]["members"]) == n, (
            "%s resolved to %d member(s), expected %d - the closure walk did not "
            "stage its dependencies"
            % (name, len(groups[name]["members"]), n))
        assert groups[name]["members"][0]["role"] == "primary"


# ---------------------------------------------------------- attribution


def test_an_error_from_a_dependency_is_attributed_to_the_dependency():
    owners = [
        {"label": "PRIMARY", "tokens": ["PRIMARY.oxz", "PRIMARY", "Primary Thing"]},
        {"label": "DEP", "tokens": ["DEP.oxz", "DEP", "Dep Thing"]},
    ]
    line = ("03:35:59.439 [plist.parse.failed]: Failed to parse "
            "x/AddOns/DEP.oxz/Config/shipdata.plist as a property list.")
    got = od.attribute_errors([line], owners)
    assert got["DEP"] == [line]
    assert got["PRIMARY"] == [], "a dependency's error was blamed on the primary"


def test_the_longest_matching_token_wins_over_a_prefix():
    """'Xenon UI' is a prefix of 'Xenon UI Resources Pack A'. First-match-wins
    would credit every pack error to XenonUI - the exact mis-attribution this
    bead must not introduce."""
    owners = [
        {"label": "XenonUI", "tokens": ["Xenon UI"]},
        {"label": "PackA", "tokens": ["Xenon UI Resources Pack A"]},
    ]
    line = "03:00:00.000 [x.error]: Xenon UI Resources Pack A did something bad"
    got = od.attribute_errors([line], owners)
    assert got["PackA"] == [line]
    assert got["XenonUI"] == []


def test_an_unowned_error_is_reported_not_folded_into_the_primary():
    owners = [{"label": "PRIMARY", "tokens": ["PRIMARY.oxz"]}]
    line = "03:00:00.000 [general.error]: something nobody staged went wrong"
    got = od.attribute_errors([line], owners)
    assert got[od.UNATTRIBUTED] == [line]
    assert got["PRIMARY"] == []


# ------------------------------------------------------- group verdicts


GOOD_HEAD = """Opening log for Oolite version 1.91 (x86-64) under Windows.

03:00:00.000 [process.args]: oolite.exe --no-splash
03:00:01.000 [searchPaths.dumpAll]: Resource paths:
    C:/w/AddOns
    C:/w/AddOns/PRIMARY.oxz
    C:/w/AddOns/DEP.oxz
    C:/w/AddOns/oo-het-sentinel.oxp
03:00:02.000 [shipData.load.begin]: Loading ship data.
03:00:03.000 [startup.complete]: ========== Loading complete. ==========
03:00:04.000 [oo-het.sentinel]: OO-HET-""" + "SENTINEL-OK\n"


def _pad(text):
    """Bring a fixture above MIN_LOG_LINES without adding anything judgeable."""
    return text + "".join("03:00:05.%03d [general]: filler\n" % i
                          for i in range(lc.MIN_LOG_LINES + 5))


MEMBERS = [
    {"identifier": "PRIMARY", "staged_as": "PRIMARY.oxz", "title": "Primary Thing",
     "role": "primary"},
    {"identifier": "DEP", "staged_as": "DEP.oxz", "title": "Dep Thing",
     "role": "dependency"},
]


def test_group_pass_when_primary_and_dependency_both_load_cleanly():
    v, d, errs, per = lc.judge_group(_pad(GOOD_HEAD), MEMBERS, "fixture")
    assert v == lc.Verdict.PASS, (v, d)
    assert per["PRIMARY"]["loaded"] and per["DEP"]["loaded"]


def test_group_notloaded_when_the_primary_is_absent_and_says_deps_were_staged():
    text = _pad(GOOD_HEAD.replace("    C:/w/AddOns/PRIMARY.oxz\n", ""))
    v, d, errs, per = lc.judge_group(text, MEMBERS, "fixture")
    assert v == lc.Verdict.NOTLOADED, (v, d)
    assert "DEP.oxz" in d, "the message does not say the dependency WAS staged"
    assert "did NOT load" in d


def test_group_depnotloaded_names_the_dependency_not_the_primary():
    text = _pad(GOOD_HEAD.replace("    C:/w/AddOns/DEP.oxz\n", ""))
    v, d, errs, per = lc.judge_group(text, MEMBERS, "fixture")
    assert v == lc.Verdict.DEPNOTLOADED, (v, d)
    assert "DEP.oxz" in d
    assert per["PRIMARY"]["loaded"] is True


def test_group_deperrors_blames_the_dependency_and_exonerates_the_primary():
    """THE ATTRIBUTION TEST THE BEAD ASKS FOR. A loads fine, B emits the error;
    the verdict must name B and must NOT say 'PRIMARY FAILED'."""
    bad = ("03:00:06.000 [plist.parse.failed]: Failed to parse "
           "C:/w/AddOns/DEP.oxz/Config/shipdata.plist as a property list.\n")
    v, d, errs, per = lc.judge_group(_pad(GOOD_HEAD + bad), MEMBERS, "fixture")
    assert v == lc.Verdict.DEPERRORS, (v, d)
    assert "DEP" in d
    assert "PRIMARY.oxz FAILED" not in d, "a dependency's error was reported as the primary's"
    assert per["DEP"]["errors"] == [bad.rstrip("\n")]
    assert per["PRIMARY"]["errors"] == []


def test_group_errors_still_blames_the_primary_for_its_own_error():
    bad = ("03:00:06.000 [plist.parse.failed]: Failed to parse "
           "C:/w/AddOns/PRIMARY.oxz/Config/shipdata.plist as a property list.\n")
    v, d, errs, per = lc.judge_group(_pad(GOOD_HEAD + bad), MEMBERS, "fixture")
    assert v == lc.Verdict.ERRORS, (v, d)
    assert "PRIMARY.oxz FAILED" in d


def test_a_group_verdict_is_never_green_for_a_failure():
    """The whole point: no failure mode introduced here may be treated as PASS."""
    for v in (lc.Verdict.UNSATISFIABLE, lc.Verdict.DEPNOTLOADED,
              lc.Verdict.DEPERRORS, lc.Verdict.NOTLOADED, lc.Verdict.ERRORS):
        assert v != lc.Verdict.PASS


# ------------------------------------- the legacy no-manifest fixture class
#
# Five in-tree test-oxps ship no manifest.plist and each emits EXACTLY 2 error
# lines, all of them the same standards complaint. That is a fixture property,
# not five defects, and reporting it as ERRORS sends readers hunting a bug that
# does not exist. It gets a non-fatal state - and these tests exist so that
# state cannot widen into a silencer.

NOMANIF = ("03:00:06.000 [oxp-standards.error]: OXP "
           "C:/w/AddOns/PRIMARY.oxz has no manifest.plist\n")


def test_no_manifest_only_is_its_own_state_and_still_prints_the_lines():
    v, d, errs, per = lc.judge_group(_pad(GOOD_HEAD + NOMANIF + NOMANIF),
                                     MEMBERS, "fixture")
    assert v == lc.Verdict.NOMANIFEST, (v, d)
    assert len(errs) == 2, "the lines were suppressed instead of re-labelled"
    assert "no manifest.plist" in d and "NOT a content defect" in d


def test_one_extra_error_of_any_kind_makes_it_ERRORS_again():
    """The narrowing that stops this becoming a blanket exemption."""
    other = ("03:00:07.000 [plist.parse.failed]: Failed to parse "
             "C:/w/AddOns/PRIMARY.oxz/Config/shipdata.plist as a property list.\n")
    v, d, errs, per = lc.judge_group(_pad(GOOD_HEAD + NOMANIF + other),
                                     MEMBERS, "fixture")
    assert v == lc.Verdict.ERRORS, (v, d)
    assert len(errs) == 2, "the manifest line was dropped from the ERRORS report"


def test_an_UNOWNED_missing_manifest_is_not_absorbed():
    """The complaint must NAME a staged member. A manifest error nobody claims
    is still an unattributed finding, not a free pass."""
    stranger = ("03:00:06.000 [oxp-standards.error]: OXP "
                "C:/w/AddOns/SomethingElse.oxp has no manifest.plist\n")
    v, d, errs, per = lc.judge_group(_pad(GOOD_HEAD + stranger), MEMBERS, "fixture")
    assert v == lc.Verdict.ERRORS, (v, d)
    assert "NO staged expansion claims" in d


def test_no_manifest_cannot_rescue_an_expansion_that_never_loaded():
    """P5 comes first: a rejected expansion is NOTLOADED and never reaches the
    non-fatal branch, so this state can never mask a non-load."""
    text = _pad(GOOD_HEAD.replace("    C:/w/AddOns/PRIMARY.oxz\n", "") + NOMANIF)
    v, d, errs, per = lc.judge_group(text, MEMBERS, "fixture")
    assert v == lc.Verdict.NOTLOADED, (v, d)


def test_the_no_manifest_pattern_is_anchored_and_does_not_match_prose():
    assert lc.NOMANIFEST_RE.search("OXP x.oxp has no manifest.plist")
    assert not lc.NOMANIFEST_RE.search(
        "OXP x.oxp has no manifest.plist and also failed to parse shipdata")
    assert not lc.NOMANIFEST_RE.search("some other standards error")


def test_the_run_level_guards_still_apply_to_a_group():
    """P2-P4b are NOT weakened by grouping: the real dead-launch corpse must be
    rejected when judged as a group exactly as it is judged solo. The corpse
    contains ZERO lines matching ERROR, so only a positive-progress guard can
    reject it - which is the property grouping must not lose."""
    corpse = (HERE / "oxp-corpus" / "fixtures" / "dead-initgl-Latest.log")
    text = corpse.read_text(encoding="utf-8", errors="replace")
    assert not any(lc.is_error_line(l) for l in text.splitlines()), (
        "the corpse fixture now contains error lines; it no longer proves the "
        "guard rejects a SILENT dead launch")
    v, d, errs, per = lc.judge_group(text, MEMBERS, str(corpse))
    assert v != lc.Verdict.PASS, "the group judge PASSED a dead launch"
    assert v in (lc.Verdict.LOG, lc.Verdict.NOSHIPDATA, lc.Verdict.STARTUP,
                 lc.Verdict.NOSENTINEL), (v, d)


def test_unsatisfiable_does_not_launch_the_game():
    """A group with a missing requirement must be decided WITHOUT a launch: the
    app dir here does not exist, so any launch attempt would show up as LAUNCH."""
    g = {"name": "X", "primary": "X", "missing": ["GONE"],
         "members": [{"identifier": "X", "staged_as": "X.oxz", "path": "/nope",
                      "title": "X", "role": "primary"}]}
    r = lc.run_group(Path("C:/no-such-app-dir-oo-kcrw"), g, Path("."), 5.0)
    assert r["verdict"] == lc.Verdict.UNSATISFIABLE, r
    assert r["wall_s"] == 0.0, "a launch was attempted for an unsatisfiable group"
    assert "GONE" in r["detail"] and "NOT a load failure" in r["detail"]


if __name__ == "__main__":
    sys.exit(pytest.main([__file__, "-q"]))
