"""Offline guards for the ship.speed seam itself (bead oo-jou1). No game, no build.

Two things are pinned here that the witness-replay tests cannot pin:

1. THE SEAM IS PRESENT IN THE ENGINE SOURCE. The live evidence is a pair of committed witnesses,
   and a witness is a recording: it stays green if someone reverts the engine change, because the
   JSON does not know the source moved. These tests read OOJSShip (by stem: .m, now .mm, later
   .cpp; spellings are the Phase 1 ooscript façade's) and assert the property is
   declared writable AND that the setter case exists - the two halves that must agree, since
   OOJS_PROP_READWRITE_CB without a `case kShip_speed:` in ShipSetProperty falls through to
   OOJSReportBadPropertySelector and the write fails at runtime with a table that claims it works.

2. THE VALUE POLICY. What a negative, NaN, non-numeric, over-max or player write does is the part
   of a setter's contract that OXPs will depend on and that cannot be changed later. It is
   asserted against the recorded witness AND, for the refusal message, against the source.

NOTE ON READING ENGINE SOURCE: the repo's search tooling silently returns zero matches inside
upstream/oolite/src, so these tests open the file directly. A test that used a repo-wide grep
would report "not found" for a line that is present.
"""

import json
import os
import re
import sys

import pytest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
# Engine sources are named by STEM: the migration renames .m -> .mm -> .cpp (oo-7j3t).
sys.path.insert(0, os.path.join(REPO_ROOT, "upstream", "oolite", "tests"))
from source_paths import resolve_source  # noqa: E402
OOJSSHIP = resolve_source("Core", "Scripting", "OOJSShip")
VALUE_WITNESS = os.path.join(HERE, "fixtures", "value-policy.json")
CONTRACT = os.path.join(REPO_ROOT, "oxp-contract", "js-api-1.93.json")


@pytest.fixture(scope="module")
def source():
    assert os.path.isfile(OOJSSHIP), "engine source missing at %s" % OOJSSHIP
    with open(OOJSSHIP, encoding="utf-8", errors="replace") as handle:
        return handle.read()


@pytest.fixture(scope="module")
def witness():
    with open(VALUE_WITNESS, encoding="utf-8") as handle:
        return json.load(handle)


def case(witness, name):
    for entry in witness["cases"]:
        if entry["case"] == name:
            return entry
    raise AssertionError("no %r case in the witness" % name)


def setter_body(source, strip_comments=True):
    """The `case kShip_speed:` block inside ShipSetProperty, with its comments removed.

    TWO scoping hazards, both found by a surviving mutant rather than by reading:

    1. `case kShip_speed:` appears TWICE in this file, once in ShipGetProperty and once in
       ShipSetProperty, and a naive split on the first occurrence reads the GETTER - which
       contains no setSpeed: and no player guard, so every assertion about the setter fails
       against correct code.

    2. COMMENTS MUST BE STRIPPED before any text search. The setter's own explanatory comment
       names `-setSpeed:`, `fmax(` and `playerReadOnly` while explaining the design, so a search
       over the raw block is satisfied by the PROSE and stays green when the CODE is deleted -
       mutant M3 (remove the [entity setSpeed:] call, keep the comment) survived exactly that way.
       A guard that a comment can satisfy is a guard on documentation, not on behaviour.
    """
    after = source.rsplit("static bool ShipSetProperty", 1)
    assert len(after) == 2, "ShipSetProperty not found"
    assert "{" in after[1][:200], (
        "split landed on the forward declaration at the top of the file rather than the "
        "definition")
    body = after[1].split("case kShip_speed:", 1)
    assert len(body) == 2, "no `case kShip_speed:` inside ShipSetProperty"
    block = body[1].split("break;", 1)[0]
    if strip_comments:
        block = re.sub(r"/\*.*?\*/", " ", block, flags=re.S)
        block = re.sub(r"//[^\n]*", " ", block)
    return block


# --- 1. the seam exists, in both halves ---------------------------------------------------------

def test_speed_is_declared_readwrite(source):
    match = re.search(r'\{\s*"speed",\s*kShip_speed,\s*(OOJS_PROP_\w+)\s*\}', source)
    assert match, "the 'speed' entry is missing from sShipProperties entirely"
    assert match.group(1) == "OOJS_PROP_READWRITE_CB", (
        "ship.speed is declared %s; a script cannot write flightSpeed, so a ship cannot be "
        "brought to a genuine rest - writing ship.velocity only sets the INSTANTANEOUS velocity "
        "(setTotalVelocity:, ShipEntity.h:944) and applyThrust: re-accelerates on the next frame"
        % match.group(1))


def test_the_setter_case_exists(source):
    """The other half. A writable declaration with no setter case fails at runtime, not at build."""
    setter = source.split("static bool ShipSetProperty", 1)
    assert len(setter) == 2, "ShipSetProperty not found"
    body = setter[1]
    assert re.search(r"case kShip_speed:", body), (
        "sShipProperties declares 'speed' writable but ShipSetProperty has no `case kShip_speed:`, "
        "so every write falls through to OOJSReportBadPropertySelector - the table promises a "
        "setter the switch does not implement")


def test_the_setter_actually_writes_flight_speed(source):
    """Pin the CALL, not the case label and not the comment that explains it."""
    body = setter_body(source)
    assert "[entity setSpeed:fValue];" in body, (
        "the kShip_speed setter case does not call -setSpeed: (ShipEntity.m:8575) in CODE, so it "
        "does not touch flightSpeed and the seam is decorative. (Searched with comments stripped: "
        "the block's own comment names -setSpeed: while explaining the design, and a raw text "
        "search would be satisfied by that prose.)")


def test_the_comment_alone_does_not_satisfy_the_call_check(source):
    """Prove the stripping above is load-bearing rather than cosmetic.

    Without it, deleting the call while keeping the comment leaves every assertion green - that
    mutant (M3 in tools/oo-jou1-mutants.sh) survived until the strip was added.
    """
    raw = setter_body(source, strip_comments=False)
    stripped = setter_body(source)
    assert "setSpeed:" in raw and "setSpeed:" in stripped, "sanity: both see the real call"
    mutated = raw.replace("[entity setSpeed:fValue];", "/* write removed */")
    assert "setSpeed:" in mutated, (
        "sanity: the comment in this block must still mention setSpeed: after the call is "
        "removed, otherwise this test is not exercising the hazard it describes")
    mutated_stripped = re.sub(r"//[^\n]*", " ", re.sub(r"/\*.*?\*/", " ", mutated, flags=re.S))
    assert "setSpeed:" not in mutated_stripped, (
        "comment stripping does not remove the prose mention of setSpeed:, so the call check can "
        "still be satisfied by documentation")


def test_the_getter_is_unchanged(source):
    """This bead adds a setter; it must not have altered what reading ship.speed means."""
    assert re.search(r"case kShip_speed:\s*\n\s*return ooscript::newNumberValue\(context, \[entity "
                     r"flightSpeed\], value\);", source), (
        "the ship.speed GETTER no longer reads [entity flightSpeed]; this bead was supposed to "
        "add a setter, not change the meaning of the property")


# --- 2. the value policy ------------------------------------------------------------------------

@pytest.mark.parametrize("name", ["negative", "nan", "non-numeric"])
def test_bad_values_are_refused_and_leave_the_speed_untouched(witness, name):
    entry = case(witness, name)
    assert entry["outcome"] == "refused", (
        "%s was ACCEPTED; a negative or NaN flightSpeed scales v_forward backwards or poisons "
        "position on the next frame" % name)
    assert entry["before"] == entry["after"], (
        "%s was refused with an error but the speed still changed from %r to %r - a setter that "
        "reports failure and writes anyway is worse than one that does neither"
        % (name, entry["before"], entry["after"]))


def test_the_refusal_is_loud_not_a_silent_clamp(source, witness):
    """Refusing names the caller's mistake; clamping to 0 hides it. Pinned on both sides."""
    assert "ship.speed must be a number >= 0." in source
    assert case(witness, "negative")["error"] == "Error: ship.speed must be a number >= 0."
    body = setter_body(source)
    assert "fmax(" not in body, (
        "the kShip_speed setter clamps with fmax() in CODE; this seam refuses out-of-range values "
        "instead of silently rewriting them - see the comment above the case for why")
    assert 'OOJSReportError(context, @"ship.speed must be a number >= 0.")' in body, (
        "the refusal is not raised from the setter's own code; only its comment mentions it")


def test_a_value_above_maxspeed_is_accepted_unchanged(witness):
    """No upper clamp, deliberately: the engine itself exceeds maxFlightSpeed."""
    entry = case(witness, "above-max")
    assert entry["outcome"] == "accepted"
    assert entry["after"] > entry["max"], (
        "the write was clamped to maxSpeed (%r <= %r); the engine sets flightSpeed above "
        "maxFlightSpeed itself for missiles (ShipEntity.m:12381) and injectors, so a clamp here "
        "would make the scripted seam weaker than the engine's own"
        % (entry["after"], entry["max"]))
    assert entry["after"] == pytest.approx(entry["max"] * 3)


def test_zero_is_accepted(witness):
    entry = case(witness, "zero")
    assert entry["outcome"] == "accepted"
    assert entry["after"] == 0


def test_the_player_ship_refuses_the_write(witness, source):
    entry = case(witness, "player")
    assert entry["outcome"] == "refused"
    assert "read-only" in entry["error"]
    body = setter_body(source)
    assert "goto playerReadOnly;" in body, (
        "the kShip_speed setter does not guard [entity isPlayer] in CODE; the player's flightSpeed "
        "is rewritten from the throttle every frame, so the write would silently not stick")


def test_the_recorded_contract_agrees_with_the_source(source):
    """oxp-contract/js-api-1.93.json must record Ship.speed as writable.

    The contract is generated by tools/js-api-snapshot.sh from a RUNNING build - it reflects what
    the interpreter actually exposes, not what the source says - so it is an independent second
    opinion about the seam. If the source says READWRITE and the contract still says
    writable:false, one of them is stale and an OXP author reading the contract is being told the
    property cannot be set.

    Note this is the only artifact in the repo that records the mutability of a Ship property; the
    snapshot enumerates globals, and Ship's per-property table is reached through
    globals -> Ship -> prototype_members.
    """
    with open(CONTRACT, encoding="utf-8") as handle:
        contract = json.load(handle)
    entry = contract["globals"]["Ship"]["prototype_members"]["speed"]
    assert entry["writable"] is True, (
        "the JS API contract records Ship.speed as writable=%r while OOJSShip.m declares it "
        "OOJS_PROP_READWRITE_CB; regenerate with tools/js-api-snapshot.sh" % entry["writable"])
    # and the source half, so this test fails if EITHER side regresses
    assert re.search(r'\{\s*"speed",\s*kShip_speed,\s*OOJS_PROP_READWRITE_CB\s*\}', source)


def test_the_witness_names_the_binary_it_came_from(witness):
    binary = witness["binary"]
    assert binary["exe"].endswith("oolite.exe")
    assert binary["md5"] and binary["size"] > 1_000_000
