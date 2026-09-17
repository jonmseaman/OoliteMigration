"""Assert two simultaneously held run plans cannot collide. Driven by check-isolation.sh."""

import json
import sys

KEYS = ("console_port", "artifact_dir", "staged_app_dir", "config_dir", "run_id")


def main(scenario, plans_path):
    with open(plans_path, encoding="utf-8") as handle:
        plans = json.load(handle)
    if not isinstance(plans, list) or len(plans) != 2:
        raise SystemExit("expected two run plans, got %r" % (plans,))
    for key in KEYS:
        a, b = plans[0][key], plans[1][key]
        if a == b:
            raise SystemExit("two concurrent runs would collide on %s (%r)" % (key, a))
    for plan in plans:
        if plan["scenario"] != scenario:
            raise SystemExit("plan is for %r, not %r" % (plan["scenario"], scenario))
        if not plan["artifact_dir"].startswith(plan["repo_root"]):
            raise SystemExit("artifact dir escapes the repo: %s" % plan["artifact_dir"])
        # An MSYS path handed to the game or to a native python becomes C:/c/... and fails with
        # WinError 3, so a plan must never carry one.
        for key in ("artifact_dir", "staged_app_dir", "source_app_dir"):
            if plan[key].startswith("/c/") or plan[key].startswith("/C/"):
                raise SystemExit("%s is an MSYS path: %s" % (key, plan[key]))
    print("ok: ports %s, distinct artifact directories" % [p["console_port"] for p in plans])


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("usage: check_isolation.py <scenario> <plans.json>")
    main(sys.argv[1], sys.argv[2])
