import os, sys, tempfile, plistlib, shutil, time, json
REPO = r"C:/Users/jon/OoliteMigration/.worktrees/oo-qjc"
sys.path.insert(0, REPO + "/upstream/oolite/tests/component")
sys.path.insert(0, REPO + "/tools")
from console import DebugConsole, ConsoleError
import js_api_snapshot as S

app = "C:/Users/jon/OoliteMigration" + "/upstream/oolite/build/meson_test/oolite.app"
S._ensure_software_gl(app)
cfg = S._console_config_dir("127.0.0.1", 8563)
out = tempfile.mkdtemp()
os.environ["OO_ADDITIONALADDONSDIRS"] = cfg
con = DebugConsole(app, 8563, seed=1, output_dir=out)
try:
    con.start(ready_timeout=240)
    S._wait_until_rendering(con, 2.0)
    print("ready", con.evaluate("oolite.versionString"))
    for expr in [
        "1+1",
        "Object.getOwnPropertyNames(this).length",
        "(function(){var n=[];for(var k in this){n.push(k);} return n.length;})()",
        '(function(){ return Object.getOwnPropertyNames(this).sort().join(","); })()',
    ]:
        try:
            print(repr(expr), "=>", repr(con.evaluate(expr, timeout=25))[:600])
        except Exception as e:
            print(repr(expr), "FAILED", e.__class__.__name__, str(e)[:200])
    # multiline test
    ml = "(function () {\n  var a = 1;\n  return a + 2;\n})()"
    try:
        print("multiline =>", con.evaluate(ml, timeout=25))
    except Exception as e:
        print("multiline FAILED", str(e)[:200])
finally:
    con.close()
    shutil.rmtree(cfg, ignore_errors=True)
    shutil.rmtree(out, ignore_errors=True)
