/*

oolite-compat-shim.js

Compatibility shim (bead oo-864): polyfills the SpiderMonkey-only
Object.prototype.toSource() / Array.prototype.toSource() / String.prototype.quote()
for expansions (OXP/OXZ) whose authors are unreachable and cannot update their
scripts for the QuickJS-ng engine (see docs/EXPANSION_MIGRATION.md, "to-source"
and "quote-method"). Every install is defensive: it never overwrites a native
implementation the engine already provides, so under the legacy SpiderMonkey
backend this shim is a silent no-op.

Installation happens in this script's top-level body, not in startUp(). All
world scripts are loaded (and therefore have their top-level code executed) by
ResourceManager before any world-script event, including startUp, is dispatched
to ANY script (PlayerEntity doWorldScriptEvent: iterates worldScripts only after
loadScripts completes) -- so the polyfills are installed before an abandoned
expansion's own startUp() or any later event handler can call toSource()/quote(),
independent of exactly where in OXP load order this shim happens to sit. This
manifest still asks to be loaded first (Config/world-scripts.plist, single
entry) so a `js-api-snapshot`-style trace shows the shim as the origin of these
methods rather than a coincidence of iteration order.

The polyfill output is intentionally NOT byte-identical to SpiderMonkey's
toSource()/quote() (that would require a full source-reflecting serializer);
it is a best-effort, readable approximation good enough for the debug logging
and cache-key use cases the corpus scan actually found (Library_1.10.5.oxz).
Authors who need exact round-tripping should still migrate to JSON.stringify()
per docs/EXPANSION_MIGRATION.md.

Oolite
Copyright (c) 2004-2013 Giles C Williams and contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

*/

"use strict";

this.name = "oolite-compat-shim";
this.author = "Oolite migration project";
this.copyright = "(c) 2026 the Oolite migration project.";
this.description = "Polyfills toSource()/quote() for abandoned expansions (bead oo-864).";
this.version = "1.0";


(function ()
{
	// quoteString(): produce a double-quoted, backslash-escaped string
	// literal, the piece both toSource() and quote() need.
	function quoteString(s)
	{
		var out = "\"";
		for (var i = 0; i < s.length; i++)
		{
			var c = s.charAt(i);
			var code = s.charCodeAt(i);
			if (c === "\"" || c === "\\")
			{
				out += "\\" + c;
			}
			else if (c === "\n")
			{
				out += "\\n";
			}
			else if (c === "\r")
			{
				out += "\\r";
			}
			else if (c === "\t")
			{
				out += "\\t";
			}
			else if (code < 0x20 || code === 0x7f)
			{
				var hex = code.toString(16);
				while (hex.length < 2)  hex = "0" + hex;
				out += "\\x" + hex;
			}
			else
			{
				out += c;
			}
		}
		return out + "\"";
	}


	// toSourceValue(): best-effort Object.prototype.toSource()/
	// Array.prototype.toSource() replacement. Recurses through plain
	// objects and arrays; anything else falls back to String(value) inside
	// an eval-safe wrapper where practical, matching the common debug-log
	// use case (logging a data object), not full source reflection.
	function toSourceValue(value, seen)
	{
		if (value === null)  return "null";
		if (value === undefined)  return "undefined";

		var t = typeof value;
		if (t === "string")  return quoteString(value);
		if (t === "number" || t === "boolean")  return String(value);
		if (t === "function")
		{
			return value.name ? "(function " + value.name + "() {...})" : "(function () {...})";
		}

		if (t === "object")
		{
			if (seen.indexOf(value) !== -1)  return "<circular>";
			seen = seen.concat([value]);

			if (Array.isArray(value))
			{
				var items = [];
				for (var i = 0; i < value.length; i++)
				{
					items.push(toSourceValue(value[i], seen));
				}
				return "[" + items.join(", ") + "]";
			}

			var parts = [];
			for (var key in value)
			{
				if (!Object.prototype.hasOwnProperty.call(value, key))  continue;
				parts.push(quoteString(key) + ":" + toSourceValue(value[key], seen));
			}
			return "({" + parts.join(", ") + "})";
		}

		// Unrecognised primitive type (e.g. symbol): fall back to String().
		return String(value);
	}


	// Object.prototype.toSource(): SpiderMonkey removed in Firefox 74.
	if (typeof Object.prototype.toSource !== "function")
	{
		Object.defineProperty(Object.prototype, "toSource", {
			value: function toSource()
			{
				return toSourceValue(this, []);
			},
			writable: true,
			configurable: true,
			enumerable: false
		});
	}

	// Array.prototype.toSource(): same removal; own definition so it wins
	// over the generic Object.prototype one and formats as "[...]" per the
	// historical SpiderMonkey behaviour rather than "({0:..., 1:...})".
	if (typeof Array.prototype.toSource !== "function")
	{
		Object.defineProperty(Array.prototype, "toSource", {
			value: function toSource()
			{
				return toSourceValue(this, []);
			},
			writable: true,
			configurable: true,
			enumerable: false
		});
	}

	// String.prototype.quote(): SpiderMonkey-only, removed in Firefox 37.
	if (typeof String.prototype.quote !== "function")
	{
		Object.defineProperty(String.prototype, "quote", {
			value: function quote()
			{
				return quoteString(this.toString());
			},
			writable: true,
			configurable: true,
			enumerable: false
		});
	}

	// uneval(): SpiderMonkey-only global, removed in Firefox 74. Polyfilled
	// alongside toSource()/quote() since it is the same source-reflection
	// family and the same abandoned expansions that call .toSource() are
	// the ones most likely to also call the bare global.
	if (typeof global.uneval !== "function")
	{
		global.uneval = function uneval(value)
		{
			return toSourceValue(value, []);
		};
	}
}).call(this);
