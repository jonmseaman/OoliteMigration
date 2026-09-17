import os, sys, tempfile, shutil, time, json
MAIN = r"C:/Users/jon/OoliteMigration"
REPO = MAIN + "/.worktrees/oo-qjc"
sys.path.insert(0, REPO + "/upstream/oolite/tests/component")
sys.path.insert(0, REPO + "/tools")
from console import DebugConsole
import js_api_snapshot as S

DUMP = r"""
this.__ooMem = function (obj, gname, bucket, acc) {
  if (obj === null || obj === undefined) { return; }
  var names;
  try { names = Object.getOwnPropertyNames(obj); } catch (e) { return; }
  names.sort();
  for (var i = 0; i < names.length; i++) {
    var n = names[i], d = null;
    try { d = Object.getOwnPropertyDescriptor(obj, n); } catch (err) { d = null; }
    var kind = "opaque", arity = "", type = "", flags = "";
    if (d) {
      flags = (d.enumerable ? "e" : "-") + (d.configurable ? "c" : "-");
      if (d.get || d.set) {
        kind = "accessor"; flags += (d.get ? "r" : "-") + (d.set ? "w" : "-");
      } else if (typeof d.value === "function") {
        kind = "method"; arity = String(d.value.length | 0);
        flags += "r" + (d.writable ? "w" : "-");
      } else {
        kind = "property"; type = (d.value === null) ? "null" : typeof d.value;
        flags += "r" + (d.writable ? "w" : "-");
      }
    }
    acc.push("M|" + gname + "|" + bucket + "|" + n + "|" + kind + "|" + arity + "|" + type + "|" + flags);
  }
};
"""

ALL = r"""
this.__ooDump = function () {
  var g = (function () { return this; })();
  var acc = [], names;
  try { names = Object.getOwnPropertyNames(g); } catch (e) { names = []; }
  names.sort();
  for (var j = 0; j < names.length; j++) {
    var name = names[j];
    if (name.indexOf("__oo") === 0) { continue; }
    var v, t;
    try { v = g[name]; } catch (e) { acc.push("G|" + name + "|unreadable|||"); continue; }
    t = (v === null) ? "null" : typeof v;
    var cls = "";
    try { cls = Object.prototype.toString.call(v).replace("[object ", "").replace("]", ""); } catch (e) { cls = ""; }
    if (t === "function") {
      var proto = null;
      try { proto = v.prototype; } catch (e) { proto = null; }
      acc.push("G|" + name + "|function|" + (v.length | 0) + "|" + (proto ? "class" : "plain") + "|" + cls);
      __ooMem(v, name, "static", acc);
      if (proto) { __ooMem(proto, name, "proto", acc); }
    } else if (t === "object") {
      acc.push("G|" + name + "|object|||" + cls);
      __ooMem(v, name, "own", acc);
      var pr = null;
      try { pr = Object.getPrototypeOf(v); } catch (e) { pr = null; }
      if (pr) { __ooMem(pr, name, "proto", acc); }
    } else {
      acc.push("G|" + name + "|" + t + "|||" + cls);
    }
  }
  return acc.join("\n");
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
    print("version", con.evaluate("oolite.versionString"))
    con.perform(" ".join(DUMP.split()))
    con.perform(" ".join(ALL.split()))
    time.sleep(1.0)
    print("installed", con.evaluate("typeof __ooMem"), con.evaluate("typeof __ooDump"))
    total = int(float(con.evaluate("(__ooText = __ooDump()).length", timeout=180)))
    print("total chars", total)
    parts = []
    for off in range(0, total, 3000):
        parts.append(con.evaluate("__ooText.substr(%d,3000)" % off, timeout=60))
    text = "".join(parts)
    print("reassembled", len(text))
    open(REPO + "/probe_dump.txt", "w", encoding="utf-8", newline="\n").write(text)
    lines = text.split("\n")
    print("lines", len(lines), "globals", sum(1 for l in lines if l.startswith("G|")))
finally:
    con.close()
    shutil.rmtree(cfg, ignore_errors=True)
    shutil.rmtree(out, ignore_errors=True)
