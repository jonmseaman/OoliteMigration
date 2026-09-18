"use strict";
// FIXTURE: E4X (ECMA-357) XML literals, descendant and attribute operators.
// MUST be flagged by rule: e4x
this.startUp = function () {
    var doc = <manifest><name>Fixture</name></manifest>;
    var names = doc..name;
    var id = doc.@identifier;
    return String(names) + String(id);
};
