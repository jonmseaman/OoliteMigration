"use strict";
this.name = "fx-for-each";
this.startUp = function () {
  var total = 0;
  for each (var n in [1, 2, 3]) { total += n; }
  log(this.name, total);
};
