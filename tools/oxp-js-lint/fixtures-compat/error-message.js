"use strict";
this.name = "fxc-error-message";
this.safe = function (f) {
  try { f(); }
  catch (problem) {
    if (problem.message === "x is not defined") { return "missing"; }
    if (problem.message.indexOf("has no properties") >= 0) { return "null"; }
  }
  return "ok";
};
