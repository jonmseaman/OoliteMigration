"""tools/js_api_surface_compare.py: what counts as keeping Oolite's JS API surface (bead oo-1gc.6)."""
import json
import subprocess
import sys
from pathlib import Path

SCRIPT = Path(__file__).with_name("js_api_surface_compare.py")


def snapshot(globals_):
    return {"globals": globals_, "oolite_version": "1.93", "schema": 1, "summary": {}}


def run(tmp_path, base, cand):
    (tmp_path / "a.json").write_text(json.dumps(snapshot(base)))
    (tmp_path / "b.json").write_text(json.dumps(snapshot(cand)))
    return subprocess.run([sys.executable, str(SCRIPT), str(tmp_path / "a.json"), str(tmp_path / "b.json")],
                          capture_output=True, text=True)


CLOCK = {"type": "object", "class_name": "Clock", "is_class": False,
         "own_members": {"seconds": {"kind": "property", "writable": False, "enumerable": True}},
         "prototype_members": {"addSeconds": {"kind": "method", "arity": "1", "writable": False}}}


def test_identical_surface_passes(tmp_path):
    assert run(tmp_path, {"clock": CLOCK}, {"clock": CLOCK}).returncode == 0


def test_accessor_is_the_same_kind_as_a_data_property(tmp_path):
    cand = json.loads(json.dumps(CLOCK))
    cand["own_members"]["seconds"] = {"kind": "accessor", "writable": False, "enumerable": True}
    assert run(tmp_path, {"clock": CLOCK}, {"clock": cand}).returncode == 0


def test_lost_read_only_fails(tmp_path):
    cand = json.loads(json.dumps(CLOCK))
    cand["own_members"]["seconds"]["writable"] = True
    r = run(tmp_path, {"clock": CLOCK}, {"clock": cand})
    assert r.returncode == 1 and "writable False -> True" in r.stdout


def test_missing_member_and_arity_fail(tmp_path):
    cand = json.loads(json.dumps(CLOCK))
    del cand["own_members"]["seconds"]
    cand["prototype_members"]["addSeconds"]["arity"] = "2"
    r = run(tmp_path, {"clock": CLOCK}, {"clock": cand})
    assert r.returncode == 1 and "seconds: missing" in r.stdout and "arity 1 -> 2" in r.stdout


def test_class_name_change_fails(tmp_path):
    cand = dict(CLOCK, class_name="Object")
    assert run(tmp_path, {"clock": CLOCK}, {"clock": cand}).returncode == 1


def test_ecmascript_globals_and_additions_do_not_fail(tmp_path):
    base = {"clock": CLOCK, "Array": {"type": "function", "statics": {"forEach": {"kind": "method", "arity": "1"}}}}
    cand = {"clock": CLOCK, "Array": {"type": "function", "statics": {}}, "newThing": {"type": "object"}}
    r = run(tmp_path, base, cand)
    assert r.returncode == 0 and "added newThing" in r.stdout


def test_unreadable_input_is_refused(tmp_path):
    (tmp_path / "a.json").write_text("not json")
    r = subprocess.run([sys.executable, str(SCRIPT), str(tmp_path / "a.json"), str(tmp_path / "a.json")],
                       capture_output=True, text=True)
    assert r.returncode == 2
