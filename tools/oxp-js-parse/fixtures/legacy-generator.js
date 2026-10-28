"use strict";
this.name = "fx-legacy-generator";
this.counter = function (n) {
  var i = 0;
  while (i < n) yield i++;
};
