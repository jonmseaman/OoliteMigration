"use strict";
this.name = "fx-catch-if";
this.startUp = function () {
  try { missing(); }
  catch (e if e instanceof ReferenceError) { log(this.name, "ref"); }
};
