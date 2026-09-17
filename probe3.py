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
def t(label, expr, timeout=25):
    try:
        v = con.evaluate(expr, timeout=timeout)
        print(label, "=>", repr(v)[:400]); return v
    except Exception as e:
        print(label, "FAILED", str(e)[:250]); return None

MEMBERS = """
this.__mem = function (obj) {
  var out = {};
  if (obj === null || obj === undefined) { return out; }
  var names;
  try { names = Object.getOwnPropertyNames(obj); } catch (e) { return out; }
  for (var i = 0; i < names.length; i++) {
    var n = names[i], d = null, e = {};
    try { d = Object.getOwnPropertyDescriptor(obj, n); } catch (err) { d = null; }
    if (!d) { e.kind = "opaque"; out[n] = e; continue; }
    e.enumerable = !!d.enumerable;
    e.configurable = !!d.configurable;
    if (d.get || d.set) { e.kind = "accessor"; e.readable = !!d.get; e.writable = !!d.set; }
    else if (typeof d.value === "function") { e.kind = "method"; e.arity = d.value.length | 0; e.writable = !!d.writable; }
    else { e.kind = "property"; e.type = (d.value === null) ? "null" : typeof d.value; e.writable = !!d.writable; }
    out[n] = e;
  }
  return out;
};
"""
try:
    con.start(ready_timeout=240)
    S._wait_until_rendering(con, 2.0)
    con.perform(" ".join(MEMBERS.split()))
    time.sleep(0.8)
    t("mem installed", "typeof __mem")
    t("mem Ship.prototype size", "Object.keys(__mem(Ship.prototype)).length")
    t("json of Ship.prototype len", "JSON.stringify(__mem(Ship.prototype)).length")
    t("json of Player.prototype len", "JSON.stringify(__mem(Player.prototype)).length")
    t("names count", "Object.getOwnPropertyNames(this).length")
    # loop over all globals, per-name member count -- find the one that hangs
    con.perform('this.__log = ""; this.__step = function(){ var ns = Object.getOwnPropertyNames(this).sort(); var acc=[]; for (var i=0;i<ns.length;i++){ var n=ns[i]; if(n.indexOf("__")===0) continue; var v; try{v=this[n];}catch(e){acc.push(n+":UNREADABLE");continue;} var c=0; try{ c=Object.keys(__mem(v)).length; }catch(e){ acc.push(n+":ERR"); continue;} var pc=-1; try{ if(v&&v.prototype){pc=Object.keys(__mem(v.prototype)).length;} }catch(e){pc=-2;} acc.push(n+":"+c+"/"+pc); } __log=acc.join(" "); return acc.length; };')
    time.sleep(0.8)
    t("step installed", "typeof __step")
    t("step run", "__step()", 120)
    n = t("log len", "__log.length", 60)
    if n:
        n = int(float(n))
        parts = []
        for off in range(0, n, 1500):
            parts.append(con.evaluate("__log.substr(%d,1500)" % off, timeout=30))
        print("LOG:", "".join(parts))
finally:
    con.close()
    shutil.rmtree(cfg, ignore_errors=True)
    shutil.rmtree(out, ignore_errors=True)
