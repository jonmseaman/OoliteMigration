"use strict";
this.name = "fxc-fn-tostring";
function handler(x) { return x + 1; }
this.$hash = function () {
  return handler.toString().length + String(handler).length;
};
