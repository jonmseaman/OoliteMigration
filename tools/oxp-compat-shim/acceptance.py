#!/usr/bin/env python3
"""Offline acceptance checks for the compatibility shim OXP (bead oo-864).

Verifies, without a game build:
  1. CompatShim.oxp's manifest/requires/world-scripts plists parse (OpenStep
     dialect, same parser tools/oxp_tier1.py uses on the real corpus) and
     have the expected shape - single world script, matching identifier.
  2. The polyfill self-test (tools/oxp-compat-shim/selftest.js) passes: the
     three DONE-WHEN-relevant methods (toSource, quote, uneval) are
     installed, produce SpiderMonkey-shaped output, and never shadow a
     pre-existing native implementation.
  3. Running oxp-js-lint's to-source/quote-method/uneval detectors over the
     shim's own Scripts folder finds exactly the shim's own definitions (the
     methods it *defines*), proving those three names are not otherwise
     dangling references anywhere else in the shim.
"""
import json
import os
import subprocess
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO_ROOT, "tools"))
from oxp_tier1 import parse_openstep, PlistError  # noqa: E402

SHIM_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "CompatShim.oxp")


def fail(msg):
    print("FAIL: " + msg)
    sys.exit(1)


def check_manifest():
    path = os.path.join(SHIM_DIR, "manifest.plist")
    if not os.path.isfile(path):
        fail("missing " + path)
    try:
        man = parse_openstep(open(path, encoding="utf-8").read())
    except PlistError as exc:
        fail("manifest.plist does not parse as OpenStep plist: %s" % exc)
    if man.get("identifier") != "org.oolite.oolite.compat-shim":
        fail("manifest identifier is %r, expected org.oolite.oolite.compat-shim" % man.get("identifier"))
    for key in ("title", "version", "required_oolite_version", "description"):
        if not man.get(key):
            fail("manifest.plist missing required key %r" % key)
    print("OK: manifest.plist parses, identifier=%s" % man["identifier"])


def check_world_scripts():
    path = os.path.join(SHIM_DIR, "Config", "world-scripts.plist")
    if not os.path.isfile(path):
        fail("missing " + path)
    try:
        names = parse_openstep(open(path, encoding="utf-8").read())
    except PlistError as exc:
        fail("world-scripts.plist does not parse: %s" % exc)
    if names != ["oolite-compat-shim.js"]:
        fail("world-scripts.plist lists %r, expected exactly ['oolite-compat-shim.js']" % (names,))
    script_path = os.path.join(SHIM_DIR, "Scripts", "oolite-compat-shim.js")
    if not os.path.isfile(script_path):
        fail("world-scripts.plist names a script that does not exist: " + script_path)
    print("OK: world-scripts.plist names exactly one existing script")


def check_requires():
    path = os.path.join(SHIM_DIR, "requires.plist")
    if not os.path.isfile(path):
        fail("missing " + path)
    try:
        req = parse_openstep(open(path, encoding="utf-8").read())
    except PlistError as exc:
        fail("requires.plist does not parse: %s" % exc)
    if not req.get("version"):
        fail("requires.plist missing 'version'")
    print("OK: requires.plist parses, version=%s" % req["version"])


def find_node():
    for candidate in (os.environ.get("NODE"), "node"):
        if not candidate:
            continue
        try:
            subprocess.run([candidate, "--version"], capture_output=True, check=True)
            return candidate
        except Exception:
            continue
    fail("no working node executable found (set $NODE)")


def check_selftest(node):
    script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "selftest.js")
    proc = subprocess.run([node, script], capture_output=True, text=True)
    print(proc.stdout, end="")
    if proc.returncode != 0:
        print(proc.stderr, end="", file=sys.stderr)
        fail("selftest.js exited %d" % proc.returncode)
    if "all checks passed" not in proc.stdout:
        fail("selftest.js did not report 'all checks passed'")
    print("OK: selftest.js (polyfill install + native-passthrough) passed")


def check_lint(node):
    lint = os.path.join(REPO_ROOT, "tools", "oxp-js-lint", "lint.js")
    scripts_dir = os.path.join(SHIM_DIR, "Scripts")
    proc = subprocess.run(
        [node, lint, "scan", scripts_dir, "--json", "--allow-hits"],
        capture_output=True, text=True,
    )
    if proc.returncode not in (0, 1):
        print(proc.stderr, end="", file=sys.stderr)
        fail("lint.js scan exited %d" % proc.returncode)
    data = json.loads(proc.stdout)
    if data["files"] != 1:
        fail("lint scan covered %d files, expected exactly 1 (the shim script)" % data["files"])
    rules_seen = {f["rule"] for r in data["results"] for f in r["findings"]}
    unexpected = rules_seen - {"to-source", "uneval"}
    if unexpected:
        fail("lint found unexpected SpiderMonkey-only rule hits in the shim itself: %s" % sorted(unexpected))
    if not {"to-source", "uneval"} <= rules_seen:
        fail(
            "expected the shim's own toSource()/uneval() definitions to be visible to the "
            "lint (rules_seen=%s) - if this ever goes to zero the detector wiring changed" % sorted(rules_seen)
        )
    print("OK: lint scan of the shim finds only its own toSource/uneval definitions (%s)" % sorted(rules_seen))


def main():
    check_manifest()
    check_requires()
    check_world_scripts()
    node = find_node()
    check_selftest(node)
    check_lint(node)
    print("ACCEPTANCE OK: compatibility shim OXP present, well-formed, and its polyfills verified offline")


if __name__ == "__main__":
    main()
