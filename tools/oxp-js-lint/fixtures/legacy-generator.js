"use strict";
// FIXTURE: legacy (JS1.7) generator: a plain function whose body uses yield,
// iterated with for-in (SpiderMonkey only; bead oo-1gc.16).
// MUST be flagged by rule: legacy-generator
this.shipSpawned = function () {
    var subs = this.ship.subEntities;
    subs.each = function () { for (var i = 0; i < this.length; i++) yield this[i]; };
    for (var sub in subs.each()) {
        sub.script.owner = this.ship;
    }
};
