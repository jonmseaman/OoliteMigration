"use strict";
// FIXTURE: legacy __defineGetter__ / __defineSetter__ / __lookupGetter__.
// MUST be flagged by rule: legacy-accessor
this.startUp = function () {
    var o = {};
    o.__defineGetter__("fuel", function () { return 7; });
    o.__defineSetter__("fuel", function (v) { this._f = v; });
    return o.__lookupGetter__("fuel");
};
