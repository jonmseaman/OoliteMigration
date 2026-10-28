"use strict";
this.name = "fxc-global-enum";
this.startUp = function () {
  var extra = [];
  for (var key in global) { extra.push(key); }
  log(this.name, Object.keys(global).length + extra.length);
};
