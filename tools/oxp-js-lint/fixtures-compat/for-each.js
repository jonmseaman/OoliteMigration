"use strict";
this.name = "fxc-for-each";
this.total = function (list) {
  var sum = 0;
  for each (var n in list) { sum += n; }
  return sum;
};
