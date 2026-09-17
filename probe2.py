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
body = S.ENUMERATE_JS.strip()
fn = body[:-2]
def t(label, expr, timeout=30):
    try:
        print(label, "=>", repr(con.evaluate(expr, timeout=timeout))[:300])
    except Exception as e:
        print(label, "FAILED", str(e)[:250])
try:
    con.start(ready_timeout=240)
    S._wait_until_rendering(con, 2.0)
    con.perform("var xsimple = 5;")
    time.sleep(0.5)
    t("var persists", "typeof xsimple")
    con.perform("this.ysimple = 7;")
    time.sleep(0.5)
    t("this. persists", "typeof ysimple")
    # length probe: build a big string via perform
    big = "this.zbig = '" + ("a"*5000) + "';"
    con.perform(big)
    time.sleep(0.5)
    t("5000-char perform", "typeof zbig === 'string' ? zbig.length : 'nope'")
    # try assigning fn without var
    con.perform("this.__ooapiRun = " + fn + ";")
    time.sleep(1.0)
    t("fn assigned", "typeof __ooapiRun")
    # try single-line version of fn
    oneline = " ".join(fn.split())
    print("oneline len", len(oneline))
    con.perform("this.__oo2 = " + oneline + ";")
    time.sleep(1.0)
    t("oneline fn", "typeof __oo2")
    t("run oneline", "(__ooapi = __oo2()).length", 120)
finally:
    con.close()
    shutil.rmtree(cfg, ignore_errors=True)
    shutil.rmtree(out, ignore_errors=True)
