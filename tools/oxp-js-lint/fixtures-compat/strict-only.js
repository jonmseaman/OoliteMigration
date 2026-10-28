"use strict";
this.name = "fxc-strict-only";
this.countdown = function (n) {
  if (n > 0) { return arguments.callee(n - 1); }
  return 0;
};
