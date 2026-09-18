"use strict";
// FIXTURE: the global uneval(), SpiderMonkey only.
// MUST be flagged by rule: uneval
this.startUp = function () {
    var state = { fuel: 7 };
    log("fixture", uneval(state));
};
