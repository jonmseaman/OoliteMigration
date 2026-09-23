"use strict";
// FIXTURE: portable ECMAScript 5/2015 only. MUST NOT be flagged by ANY rule.
// It deliberately contains near-misses for every detector so that a scanner
// which flags on naive substrings fails here instead of on the corpus.
this.name = "CleanFixture";

this.startUp = function () {
    // division, not a regular expression
    var ratio = this.total / this.count / 2;

    // a regular expression that contains E4X-looking and Mozilla-looking text
    var re = /a\.\.b|<tag>|\.@attr|let\s*\(/g;

    // strings that name the banned constructs without using them
    var names = ["toSource(", "uneval(", ".quote()", "__defineGetter__", "catch (e if x)"];

    // comments that mention them: let (x = 1) {} and function (x) x * x
    /* block comment: doc..name and doc.@id and o.__defineSetter__("a", f) */

    // ordinary comparisons and shifts, not XML literals
    var cmp = this.total < this.count && this.count > 0;
    var shifted = 1 << 3;

    // spread and rest, not the E4X descendant operator
    var more = [].concat.apply([], [names, ["x"]]);
    var joined = names.join("..");

    // ES5 accessors, the portable replacement for __defineGetter__
    var o = {
        get fuel() { return 7; },
        set fuel(v) { this._f = v; }
    };
    Object.defineProperty(o, "mass", { get: function () { return 3; } });

    // block-bodied functions, including one immediately invoked
    var square = function (x) { return x * x; };
    var iife = (function () { return 1; })();

    // ES2015 generators (function*, a *method), `yield` as a key and a property:
    // only a plain function that yields is the legacy JS1.7 form
    var gen = function* () { for (var i = 0; i < 2; i++) { yield i; } };
    function* named() { if (ratio) { yield 1; } }
    var holder = { *each() { yield 2; }, yield: 3 };
    var viaKey = holder.yield + holder.each().next().value + named().next().value;
    for (var g of gen()) { viaKey += g; }

    // try/catch without a condition
    try {
        square(ratio);
    } catch (e) {
        log(this.name, String(e) + re.source + shifted + cmp + joined + more.length + iife);
    }

    return o;
};
