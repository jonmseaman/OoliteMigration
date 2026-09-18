#!/usr/bin/env python3
"""Write bead oo-jor's acceptance block. One newline-joined string; --acceptance REPLACES."""
import subprocess, sys

PY = 'PY=$(command -v python3 || command -v python || echo /ucrt64/bin/python3)'
APP = 'APP_DIR="${OO_APP_DIR:-C:/Users/jon/OoliteMigration/upstream/oolite/build/meson_test/oolite.app}"'

LINES = [
    # 1. The artefacts exist and the scenario script is importable.
    f'{PY}; for f in tests/golden/launch_dock.py tests/golden/check_launch_dock_evidence.py '
    f'tests/golden/scenarios/001-launch-dock/spec.json '
    f'tests/golden/scenarios/001-launch-dock/README.md '
    f'goldens/windows-x64/001-launch-dock/state.json '
    f'goldens/windows-x64/001-launch-dock/provenance.json; do test -f "$f" || {{ echo "MISSING: $f"; exit 1; }}; done; '
    f'"$PY" -m py_compile tests/golden/launch_dock.py tests/golden/check_launch_dock_evidence.py '
    f'tests/golden/test_launch_dock.py && echo "PASS: scenario 001-launch-dock script, spec, golden and evidence checker are present and importable"',

    # 2. The determinism knobs are PINNED IN THE SPEC and actually consumed by the script.
    f'{PY}; "$PY" -c "'
    f'import json,sys;'
    f's=json.load(open(\'tests/golden/scenarios/001-launch-dock/spec.json\'));'
    f'req=[\'seed\',\'system_id\',\'ticks\',\'tick_seconds\',\'quant_decimals\',\'load_save\',\'pose\'];'
    f'miss=[k for k in req if k not in s];'
    f'sys.exit(\'FAIL: spec.json does not pin %s; without them the scenario is not reproducible\'%miss) if miss else None;'
    f'sys.exit(\'FAIL: spec quant_decimals=%r but the storage policy is 3\'%s[\'quant_decimals\']) if s[\'quant_decimals\']!=3 else None;'
    f'sys.exit(\'FAIL: spec ticks=%r, must be a positive int\'%s[\'ticks\']) if not isinstance(s[\'ticks\'],int) or s[\'ticks\']<1 else None;'
    f'src=open(\'tests/golden/launch_dock.py\',encoding=\'utf-8\').read();'
    f'[sys.exit(\'FAIL: launch_dock.py never reads spec[%r]; the knob is decoration\'%k) for k in (\'seed\',\'system_id\',\'ticks\',\'tick_seconds\') if \'spec[\\"%s\\"]\'%k not in src];'
    f'print(\'PASS: seed=%s system_id=%s ticks=%s tick_seconds=%s quant=3 pinned in spec.json and all four read by launch_dock.py\'%(s[\'seed\'],s[\'system_id\'],s[\'ticks\'],s[\'tick_seconds\']))'
    f'"',

    # 3. The seed reaches the game as OO_RANDOM_SEED, and the port is private (not the shared 8563).
    f'{PY}; "$PY" -c "'
    f'import os,sys;'
    f'sys.path[:0]=[\'upstream/oolite/tests/component\'];'
    f'import console as C;'
    f'src=open(C.__file__,encoding=\'utf-8\').read();'
    f'sys.exit(\'FAIL: console.py does not export OO_RANDOM_SEED; the seed knob cannot reach the game\') if \'OO_RANDOM_SEED\' not in src else None;'
    f'ld=open(\'tests/golden/launch_dock.py\',encoding=\'utf-8\').read();'
    f'sys.exit(\'FAIL: launch_dock.py does not pass seed= to DebugConsole\') if \'seed=seed\' not in ld else None;'
    f'sys.exit(\'FAIL: launch_dock.py does not reserve a private console port; on the shared 8563 a sibling worker\\\'s console can capture and quit the game 4s in, and the run still exits 0 (bead oo-het)\') if \'reserve_port\' not in ld else None;'
    f'sys.exit(\'FAIL: launch_dock.py does not write a debugConfig.plist; the game DIALS OUT to the port named there, so a port that writes no plist can never work (bead oo-gla)\') if \'_write_console_config\' not in ld else None;'
    f'print(\'PASS: seed reaches the game via OO_RANDOM_SEED, and each run reserves its own port and writes the debugConfig.plist the game dials out to\')'
    f'"',

    # 4. The offline falsifiability suite: every guard proven to fire.
    f'{PY}; "$PY" -m pytest tests/golden/test_launch_dock.py -q -p no:cacheprovider',

    # 5. The STORED golden itself carries positive launch+dock evidence.
    f'{PY}; "$PY" tests/golden/check_launch_dock_evidence.py goldens/windows-x64/001-launch-dock/state.json '
    f'--label "stored golden windows-x64/001-launch-dock" || {{ echo "FAIL: the stored golden does not prove the ship launched and docked; a byte-identical comparison against it would be vacuous"; exit 1; }}',

    # 6. The stored golden is on-policy and non-vacuous by golden_diff's own guards.
    f'{PY}; W="${{LOCALAPPDATA:-/tmp}}/Temp/oo_jor_gate.$$"; rm -rf "$W"; mkdir -p "$W"; '
    f'G="goldens/windows-x64/001-launch-dock/state.json"; cp "$G" "$W/copy.json"; '
    f'"$PY" tests/golden/golden_diff.py "$G" "$(cygpath -m "$W/copy.json" 2>/dev/null || echo "$W/copy.json")" '
    f'--label-left "stored golden" --label-right "an untouched copy"; rc=$?; '
    f'test $rc -eq 0 || {{ echo "FAIL: golden_diff refuses or rejects the stored golden (rc=$rc); it is off-policy or collapsed"; rm -rf "$W"; exit 1; }}; '
    f'out=$("$PY" tests/golden/golden_diff.py "$G" "$G" 2>&1); rc2=$?; rm -rf "$W"; '
    f'test $rc2 -eq 2 || {{ echo "FAIL: golden_diff compared the golden with ITSELF and returned $rc2 instead of refusing; zero differences from a self-comparison is not evidence"; exit 1; }}; '
    f'echo "PASS: the stored golden passes golden_diff\'s non-vacuity and quantisation guards, and self-comparison is still REFUSED (rc=2)"',

    # 7. THE ONE REAL LAUNCH LINE: two independent runs, each vs the other and vs the stored golden.
    f'export PATH=/ucrt64/bin:$PATH; {PY}; {APP}; '
    f'test -d "$APP_DIR" || {{ echo "no Oolite build at $APP_DIR; build it first (tools/build-windows.sh test)"; exit 1; }}; '
    f'W="${{LOCALAPPDATA:-/tmp}}/Temp/oo_jor_two.$$"; rm -rf "$W"; mkdir -p "$W"; NW=$(cygpath -m "$W" 2>/dev/null || echo "$W"); '
    f'for i in 1 2; do t0=$(date +%s); "$PY" tests/golden/launch_dock.py --app-dir "$APP_DIR" --no-snapshot '
    f'--out "$NW/run$i.json" --run-root "$NW/runs" >"$W/run$i.log" 2>&1 || {{ echo "FAIL: run $i of the two-run launch/dock proof exited nonzero:"; cat "$W/run$i.log"; rm -rf "$W"; exit 1; }}; '
    f'echo "  run$i wall=$(( $(date +%s) - t0 ))s bytes=$(wc -c < "$W/run$i.json")"; done; '
    f'for i in 1 2; do "$PY" tests/golden/check_launch_dock_evidence.py "$NW/run$i.json" --label "fresh run $i" || {{ echo "FAIL: fresh run $i produced a dump with no launch/dock evidence"; rm -rf "$W"; exit 1; }}; done; '
    f'"$PY" tests/golden/golden_diff.py "$NW/run1.json" "$NW/run2.json" --label-left "fresh run 1" --label-right "fresh run 2" || {{ echo "FAIL: two independent launch/dock runs differ"; rm -rf "$W"; exit 1; }}; '
    f'"$PY" tests/golden/golden_diff.py goldens/windows-x64/001-launch-dock/state.json "$NW/run1.json" --label-left "stored golden" --label-right "fresh run 1" || {{ echo "FAIL: a fresh run disagrees with the STORED golden. This is a FINDING, not a file to rewrite: investigate before re-blessing."; rm -rf "$W"; exit 1; }}; '
    f'rm -rf "$W"; echo "PASS: two independent launch-and-dock runs each carry engine launch/dock evidence, agree with each other, and agree with the stored golden"',
]

block = "\n".join(LINES)
print("LINES: %d" % len(LINES))
r = subprocess.run(["bd", "update", "oo-jor", "--acceptance", block], capture_output=True, text=True)
sys.stdout.write(r.stdout); sys.stderr.write(r.stderr)
sys.exit(r.returncode)
