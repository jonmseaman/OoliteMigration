"use strict";
// FIXTURE: String.prototype.quote(), a SpiderMonkey-only method.
// MUST be flagged by rule: quote-method
this.startUp = function () {
    var label = player.ship.displayName;
    return label.quote();
};
