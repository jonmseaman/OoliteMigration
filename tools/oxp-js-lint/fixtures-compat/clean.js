"use strict";
// near misses, all legal and unchanged on QuickJS-ng:
//   for each (x in y), obj.watch(), Iterator(obj), StopIteration, RegExp.$1, arguments.callee
this.name = "fxc-clean";
this.note = "for each (var x in y); Iterator(o); x.toSource(); uneval(o); e.message === 'boom'";
this.pattern = /for each \(|\.watch\(/;
this.$data = { count: 0, status: "idle", price: 10 };
this.startUp = function () {
  this.$data.count = 3;
  this.$data.status = "busy";
  player.credits = player.credits + 10;
  player.ship.fuel = 7;
  var list = Array.isArray([]) ? Array.from([1, 2]) : [];
  var s = String.fromCharCode(65) + String(list.length);
  var n = 0.5 + 10 + 0x1f + 0;
  try { missing(); } catch (e) { log(this.name, e.message); }
  var keys = Object.keys(this.$data);
  for (var k in this.$data) { n += k.length; }
  log(this.name, s + n + keys.length);
};
