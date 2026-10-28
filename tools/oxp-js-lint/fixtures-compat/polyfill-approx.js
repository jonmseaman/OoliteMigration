"use strict";
this.name = "fxc-polyfill-approx";
this.startUp = function () {
  var cache = { a: 1 };
  log(this.name, cache.toSource());
  log(this.name, uneval(cache));
  log(this.name, "x".quote());
  Array.forEach([1, 2], function (n) { log("fxc", n); });
};
