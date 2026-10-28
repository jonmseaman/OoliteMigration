"use strict";
this.name = "fxc-removed-api";
this.startUp = function () {
  this.$state = { fuel: 7 };
  this.$state.watch("fuel", function (id, oldValue, newValue) { return newValue; });
  var it = Iterator(this.$state);
  try { it.next(); } catch (e) { if (e === StopIteration) { log(this.name, "done"); } }
  var stamp = new Date().toLocaleFormat("%Y");
  if (/(\d+)/.exec("42")) { log(this.name, RegExp.$1); }
  function inner() { return inner.caller; }
  try { missing(); } catch (err) { log(this.name, err.lineNumber); }
};
