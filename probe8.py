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
def t(label, expr, timeout=20):
    try:
        v = con.evaluate(expr, timeout=timeout); print("  %-42s => %s" % (label, repr(v)[:180]), flush=True); return v
    except Exception as e:
        print("  %-42s !! %s" % (label, str(e)[:140]), flush=True); return None
try:
    con.start(ready_timeout=240)
    S._wait_until_rendering(con, 2.0)
    for prop in ["allowsDocking", "isQueued", "dockingQueueLength", "constructor"]:
        t("desc Dock.%s exists" % prop,
          "typeof Object.getOwnPropertyDescriptor(Dock.prototype, '%s')" % prop)
    print("--- alternatives ---", flush=True)
    t("lookupGetter allowsDocking", "typeof Dock.prototype.__lookupGetter__('allowsDocking')")
    t("lookupSetter allowsDocking", "typeof Dock.prototype.__lookupSetter__('allowsDocking')")
    t("lookupGetter Ship.name", "typeof Ship.prototype.__lookupGetter__('name')")
    t("lookupGetter Ship.setAI", "typeof Ship.prototype.__lookupGetter__('setAI')")
    t("desc Ship.setAI kind", "(function(){var d=Object.getOwnPropertyDescriptor(Ship.prototype,'setAI'); return (d.get?'g':'')+(d.set?'s':'')+typeof d.value;})()")
    t("desc Ship.name kind", "(function(){var d=Object.getOwnPropertyDescriptor(Ship.prototype,'name'); return (d.get?'g':'')+(d.set?'s':'')+typeof d.value;})()")
    print("--- propertyIsEnumerable / hasOwn route ---", flush=True)
    t("Dock proto typeof method", "typeof Dock.prototype.isQueued")
finally:
    con.close()
    shutil.rmtree(cfg, ignore_errors=True)
    shutil.rmtree(out, ignore_errors=True)
