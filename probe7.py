import os, sys, tempfile, shutil, time, json
MAIN = r"C:/Users/jon/OoliteMigration"
REPO = MAIN + "/.worktrees/oo-qjc"
sys.path.insert(0, REPO + "/upstream/oolite/tests/component")
sys.path.insert(0, REPO + "/tools")
from console import DebugConsole
import js_api_snapshot as S

app = MAIN + "/upstream/oolite/build/meson_test/oolite.app"
S._ensure_software_gl(app)
cfg = S._console_config_dir("127.0.0.1", 8563)
out = tempfile.mkdtemp()
os.environ["OO_ADDITIONALADDONSDIRS"] = cfg
con = DebugConsole(app, 8563, seed=1, output_dir=out)
BAD = ["Dock", "ExhaustPlume", "Flasher", "Station", "VisualEffect", "Waypoint", "Wormhole"]
def t(label, expr, timeout=30):
    try:
        v = con.evaluate(expr, timeout=timeout); print("   %-46s => %s" % (label, repr(v)[:200]), flush=True); return v
    except Exception as e:
        print("   %-46s !! %s" % (label, str(e)[:160]), flush=True); return None
try:
    con.start(ready_timeout=240)
    S._wait_until_rendering(con, 2.0)
    for n in BAD:
        print(n, flush=True)
        t("typeof", "typeof %s" % n)
        t("has prototype", "!!%s.prototype" % n)
        t("own names count", "Object.getOwnPropertyNames(%s).length" % n)
        t("own names", "Object.getOwnPropertyNames(%s).sort().join(',')" % n)
        t("proto names count", "Object.getOwnPropertyNames(%s.prototype).length" % n)
        t("proto names", "Object.getOwnPropertyNames(%s.prototype).sort().join(',')" % n, 45)
finally:
    con.close()
    shutil.rmtree(cfg, ignore_errors=True)
    shutil.rmtree(out, ignore_errors=True)
