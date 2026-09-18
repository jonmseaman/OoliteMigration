"use strict";
// FIXTURE: Object.prototype.toSource(), SpiderMonkey only.
// MUST be flagged by rule: to-source
this.startUp = function () {
    var state = { fuel: player.ship.fuel, mass: 3 };
    log("fixture", state.toSource());
};
