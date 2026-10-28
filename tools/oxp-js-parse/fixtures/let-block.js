"use strict";
this.name = "fx-let-block";
this.startUp = function () {
  let (x = 1, y = 2) { log(this.name, x + y); }
};
