#!/usr/bin/env node
/*
 * Offline self-test for the compatibility shim OXP (bead oo-864,
 * tools/oxp-compat-shim/CompatShim.oxp/Scripts/oolite-compat-shim.js).
 *
 * The shim script only touches ECMAScript builtins (Object, Array, String
 * prototypes) plus the single Oolite-specific identifier `global`, which
 * happens to alias Node's own `global` -- so it can be loaded and executed
 * verbatim in Node, exactly the way ResourceManager evaluates a world
 * script's top-level body against the engine's real global object. No game
 * binary, no mock JSEngine required.
 *
 * Run: node tools/oxp-compat-shim/selftest.js
 */

"use strict";

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const SCRIPT_PATH = path.join(
	__dirname, "CompatShim.oxp", "Scripts", "oolite-compat-shim.js"
);

let failures = 0;

function check(description, actual, expected)
{
	if (actual === expected)
	{
		console.log("ok - " + description);
	}
	else
	{
		failures++;
		console.log("NOT OK - " + description);
		console.log("  expected: " + JSON.stringify(expected));
		console.log("  actual:   " + JSON.stringify(actual));
	}
}

function loadShimInFreshContext(preinstalled)
{
	// A fresh vm context gives each scenario (clean install vs. an engine
	// that already provides native implementations) its own untouched
	// Object/Array/String prototypes, the same isolation a real per-context
	// JS engine gives each Oolite session.
	const sandbox = { global: undefined, console: console };
	sandbox.global = sandbox; // Oolite's `global` === the JS global object.
	vm.createContext(sandbox);

	if (preinstalled)
	{
		vm.runInContext(
			"Object.defineProperty(Object.prototype, 'toSource', " +
			"{value: function () { return '<native>'; }, configurable: true}); " +
			"Object.defineProperty(String.prototype, 'quote', " +
			"{value: function () { return '<native-quote>'; }, configurable: true}); " +
			"global.uneval = function () { return '<native-uneval>'; };",
			sandbox
		);
	}

	const source = fs.readFileSync(SCRIPT_PATH, "utf8");
	// Mirror how OOJSScript evaluates a world script's top-level body: as a
	// function whose `this` is the private script object. The IIFE at the
	// bottom of the shim then does the actual installation.
	vm.runInContext("(function () {\n" + source + "\n}).call({});", sandbox);
	return sandbox;
}

// --- Scenario 1: nothing pre-installed (the abandoned-expansion case) -----

const clean = loadShimInFreshContext(false);

check(
	"Object.prototype.toSource is installed",
	typeof vm.runInContext("({}).toSource", clean),
	"function"
);
check(
	"plain object toSource()",
	vm.runInContext("({a: 1, b: 'x'}).toSource()", clean),
	'({"a":1, "b":"x"})'
);
check(
	"array toSource() uses [...] form, not ({0:...})",
	vm.runInContext("[1, 2, 3].toSource()", clean),
	"[1, 2, 3]"
);
check(
	"nested object/array toSource()",
	vm.runInContext("({fuel: 3, tags: ['a', 'b']}).toSource()", clean),
	'({"fuel":3, "tags":["a", "b"]})'
);
check(
	"String.prototype.quote installed and escapes",
	vm.runInContext('"He said \\"hi\\"\\n".quote()', clean),
	'"He said \\"hi\\"\\n"'
);
check(
	"global.uneval installed",
	vm.runInContext("uneval(42)", clean),
	"42"
);
check(
	"global.uneval on a string matches quote()",
	vm.runInContext('uneval("x")', clean),
	'"x"'
);

// --- Scenario 2: engine already provides native implementations -----------
// (the SpiderMonkey backend, or any future engine that adds them): the shim
// must be a no-op and never clobber the native behaviour.

const withNative = loadShimInFreshContext(true);

check(
	"does not overwrite a pre-existing native toSource()",
	vm.runInContext("({}).toSource()", withNative),
	"<native>"
);
check(
	"does not overwrite a pre-existing native quote()",
	vm.runInContext('"x".quote()', withNative),
	"<native-quote>"
);
check(
	"does not overwrite a pre-existing native uneval()",
	vm.runInContext("uneval(1)", withNative),
	"<native-uneval>"
);

// --- Scenario 3: circular reference does not hang or throw -----------------

const circular = loadShimInFreshContext(false);
vm.runInContext("var o = {}; o.self = o;", circular);
check(
	"circular object toSource() terminates",
	vm.runInContext("o.toSource()", circular),
	'({"self":<circular>})'
);

if (failures > 0)
{
	console.log(failures + " failure(s)");
	process.exit(1);
}
console.log("all checks passed");
