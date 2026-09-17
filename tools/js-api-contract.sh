#!/usr/bin/env bash
# Assert the committed JS API snapshot still describes the API the contract claims.
#
# Separate from tools/js-api-check.sh on purpose: that script checks the file is well-formed,
# canonical and deterministic; this one pins the specific numbers and classes this bead landed, so
# an accidental truncation or a silently emptied class fails loudly rather than passing a
# structural check. Offline, no game build needed, runnable from the repository root.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/.." && pwd)"
snapshot="$repo/oxp-contract/js-api-1.92.json"

python3 - "$(cygpath -m "$snapshot" 2>/dev/null || printf '%s' "$snapshot")" <<'PY'
import json
import sys

# Measured against upstream/oolite 1.93 by tools/js-api-snapshot.sh. See oxp-contract/README.md
# for why these are not the "61" the originating story guessed at.
EXPECTED = {
    "global_count": 121,
    "ecmascript_global_count": 51,
    "oolite_global_count": 70,
    "oolite_global_count_without_debug_console": 66,
    "class_count": 32,
}

# Classes that must carry a non-empty method list, with the minimum this build actually has. A
# floor rather than an equality: adding a method to Ship is a normal engine change and should not
# fail this check, losing every method is a regression and must.
MIN_METHODS = {
    "Ship": 81, "PlayerShip": 28, "Player": 16, "System": 27, "Station": 21,
    "Vector3D": 20, "Quaternion": 15, "Entity": 3,
}

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    doc = json.load(handle)

summary, globals_map = doc["summary"], doc["globals"]
problems = []

for key, want in EXPECTED.items():
    got = summary.get(key)
    if got != want:
        problems.append(f"summary.{key} is {got}, expected {want}")

for name, floor in MIN_METHODS.items():
    entry = globals_map.get(name)
    if entry is None:
        problems.append(f"class {name} is missing from the snapshot")
        continue
    methods = [m for m, e in entry.get("prototype_members", {}).items()
               if e.get("kind") == "method"]
    if len(methods) < floor:
        problems.append(f"{name}.prototype has {len(methods)} methods, expected at least {floor}")

if problems:
    for problem in problems:
        print(f"[!] {problem}")
    print("[!] regenerate with tools/js-api-snapshot.sh and review the diff before updating "
          "these expectations")
    sys.exit(1)

print(f"[+] {path}: {summary['global_count']} globals, {summary['class_count']} native classes, "
      f"method floors met for {len(MIN_METHODS)} classes")
PY
