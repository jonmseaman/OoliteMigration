"use strict";
// FIXTURE: let block / let expression (JS1.7, SpiderMonkey only).
// MUST be flagged by rule: let-block
this.startUp = function () {
    var total = 0;
    let (x = 1, y = 2) {
        total = x + y;
    }
    return total;
};
