"use strict";
// mentions: for each (x in y), catch (e if c), let (x = 1) {}, function (x) x * x, <tag/>
this.name = "fx-clean";
this.note = "for each (var x in y) and catch (e if cond) inside a string";
this.pattern = /for each \(/;
this.startUp = function () {
  var list = [3, 1, 2];
  list.sort(function (a, b) { return a - b; });
  for (var i = 0; i < list.length; i++) { log(this.name, list[i]); }
};
