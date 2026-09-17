import os, sys, tempfile, shutil, time, json
MAIN = r"C:/Users/jon/OoliteMigration"
REPO = MAIN + "/.worktrees/oo-qjc"
sys.path.insert(0, REPO + "/upstream/oolite/tests/component")
sys.path.insert(0, REPO + "/tools")
from console import DebugConsole
import js_api_snapshot as S

DUMP = r"""
this.__ooMem = function (obj, gname, bucket) {
  var acc = [];
  if (obj === null || obj === undefined) { return ""; }
  var names;
  try { names = Object.getOwnPropertyNames(obj); } catch (e) { return ""; }
  names.sort();
  for (var i = 0; i < names.length; i++) {
    var n = names[i], d = null;
    try { d = Object.getOwnPropertyDescriptor(obj, n); } catch (err) { d = null; }
    var kind = "opaque", arity = "", type = "", flags = "";
    if (d) {
      flags = (d.enumerable ? "e" : "-") + (d.configurable ? "c" : "-");
      if (d.get || d.set) { kind = "accessor"; flags += (d.get ? "r" : "-") + (d.set ? "w" : "-"); }
      else if (typeof d.value === "function") { kind = "method"; arity = String(d.value.length | 0); flags += "r" + (d.writable ? "w" : "-"); }
      else { kind = "property"; type = (d.value === null) ? "null" : typeof d.value; flags += "r" + (d.writable ? "w" : "-"); }
    }
    acc.push("M|" + gname + "|" + bucket + "|" + n + "|" + kind + "|" + arity + "|" + type + "|" + flags);
  }
  return acc.join(";");
};
this.__ooOne = function (name) {
  var g = (function () { return this; })();
  var acc = [], v, t;
  try { v = g[name]; } catch (e) { return "G|" + name + "|unreadable|||"; }
  t = (v === null) ? "null" : typeof v;
  var cls = "";
  try { cls = Object.prototype.toString.call(v).replace("[object ", "").replace("]", ""); } catch (e) { cls = ""; }
  if (t === "function") {
    var proto = null;
    try { proto = v.prototype; } catch (e) { proto = null; }
    acc.push("G|" + name + "|function|" + (v.length | 0) + "|" + (proto ? "class" : "plain") + "|" + cls);
    acc.push(__ooMem(v, name, "static"));
    if (proto) { acc.push(__ooMem(proto, name, "proto")); }
  } else if (t === "object") {
    acc.push("G|" + name + "|object|||" + cls);
    acc.push(__ooMem(v, name, "own"));
    var pr = null;
    try { pr = Object.getPrototypeOf(v); } catch (e) { pr = null; }
    if (pr) { acc.push(__ooMem(pr, name, "proto")); }
  } else {
    acc.push("G|" + name + "|" + t + "|||" + cls);
  }
  return acc.join(";");
};
"""

app = MAIN + "/upstream/oolite/build/meson_test/oolite.app"
S._ensure_software_gl(app)
cfg = S._console_config_dir("127.0.0.1", 8563)
out = tempfile.mkdtemp()
os.environ["OO_ADDITIONALADDONSDIRS"] = cfg
con = DebugConsole(app, 8563, seed=1, output_dir=out)
try:
    con.start(ready_timeout=240)
    S._wait_until_rendering(con, 2.0)
    con.perform(" ".join(DUMP.split()))
    time.sleep(1.0)
    print("installed", con.evaluate("typeof __ooOne"), flush=True)
    names = con.evaluate('(function(){var g=(function(){return this;})(); return Object.getOwnPropertyNames(g).sort().join(",");})()', timeout=40).split(",")
    names = [n for n in names if not n.startswith("__oo")]
    print("N", len(names), flush=True)
    chunks = []
    for n in names:
        try:
            L = int(float(con.evaluate('(__ooCur = __ooOne(%s)).length' % json.dumps(n), timeout=45)))
        except Exception as e:
            print("  !!", n, str(e)[:160], flush=True)
            continue
        parts = []
        for off in range(0, L, 3000):
            parts.append(con.evaluate("__ooCur.substr(%d,3000)" % off, timeout=45))
        s = "".join(parts)
        assert len(s) == L, (n, len(s), L)
        chunks.append(s)
        print("  ok %-22s %d" % (n, L), flush=True)
    open(REPO + "/probe_dump.txt", "w", encoding="utf-8", newline="\n").write("\n".join(chunks))
    print("DONE", len(chunks), "globals")
finally:
    con.close()
    shutil.rmtree(cfg, ignore_errors=True)
    shutil.rmtree(out, ignore_errors=True)
