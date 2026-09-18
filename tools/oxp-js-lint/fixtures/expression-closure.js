"use strict";
// FIXTURE: expression closures (JS1.8, SpiderMonkey only) - a function body
// that is an expression rather than a block.
// MUST be flagged by rule: expression-closure
this.startUp = function () {
    var square = function (x) x * x;
    var pair = function (a, b) a + b;
    return square(4) + pair(1, 2);
};
