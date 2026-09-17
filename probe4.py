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
        v = con.evaluate(expr, timeout=timeout); print(label, "=>", repr(v)[:300]); return v
    except Exception as e:
        print(label, "FAILED", str(e)[:200]); return None
try:
    con.start(ready_timeout=240)
    S._wait_until_rendering(con, 2.0)
    t("g names", "Object.getOwnPropertyNames((function(){return this;})()).length")
    t("g is global?", "(function(){return this;})() === this")
    # install members helper referencing nothing global
    MEM = 'this.__mem = function (obj) { var out = {}; if (obj === null || obj === undefined) { return out; } var names; try { names = Object.getOwnPropertyNames(obj); } catch (e) { return out; } for (var i = 0; i < names.length; i++) { var n = names[i], d = null, e = {}; try { d = Object.getOwnPropertyDescriptor(obj, n); } catch (err) { d = null; } if (!d) { e.kind = "opaque"; out[n] = e; continue; } e.enumerable = !!d.enumerable; e.configurable = !!d.configurable; if (d.get || d.set) { e.kind = "accessor"; e.readable = !!d.get; e.writable = !!d.set; } else if (typeof d.value === "function") { e.kind = "method"; e.arity = d.value.length | 0; e.writable = !!d.writable; } else { e.kind = "property"; e.type = (d.value === null) ? "null" : typeof d.value; e.writable = !!d.writable; } out[n] = e; } return out; };'
    con.perform(MEM)
    time.sleep(0.8)
    t("mem", "typeof __mem")
    # per-name: describe one global fully as JSON, measure length
    DESC = 'this.__desc = function (name) { var g = (function(){return this;})(); var v; try { v = g[name]; } catch (e) { return JSON.stringify({type:"unreadable"}); } var t = (v === null) ? "null" : typeof v; var entry = { type: t }; if (t === "function") { entry.arity = v.length | 0; entry.statics = __mem(v); var proto = null; try { proto = v.prototype; } catch (e) {} entry.is_class = !!proto; if (proto) { entry.prototype_members = __mem(proto); } } else if (t === "object") { entry.class_name = Object.prototype.toString.call(v).replace("[object ","").replace("]",""); entry.own_members = __mem(v); var pr=null; try { pr = Object.getPrototypeOf(v); } catch(e){} if (pr) { entry.prototype_members = __mem(pr); } } return JSON.stringify(entry); };'
    con.perform(DESC)
    time.sleep(0.8)
    t("desc", "typeof __desc")
    names = t('names', '(function(){var g=(function(){return this;})(); return Object.getOwnPropertyNames(g).sort().join(",");})()', 40)
    names = names.split(",")
    print("N=", len(names))
    total = 0
    for n in names:
        L = con.evaluate('(__cur = __desc(%s)).length' % json.dumps(n), timeout=45)
        total += int(float(L))
        print("  %-24s %s" % (n, L))
    print("TOTAL BYTES", total)
finally:
    con.close()
    shutil.rmtree(cfg, ignore_errors=True)
    shutil.rmtree(out, ignore_errors=True)
