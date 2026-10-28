"use strict";
/*
 * Compatibility detectors for the expansion scan (ADR-0069, layer 2).
 *
 * rules.js flags the nine Mozilla-only constructs; its rule set is pinned by the oo-ctq acceptance
 * block. This file is a second, separate set: code that QuickJS-ng parses but runs differently from
 * SpiderMonkey 1.8.5, plus `for each`, which rules.js never had. It reuses rules.js's masking
 * (comments, strings, templates and regexes blanked, offsets kept), so a construct mentioned in a
 * string or comment is never flagged.
 *
 * Every hit has a severity, taken from what the game's QuickJS-ng actually does
 * (tools/oxp-js-parse/engine-probe.c; docs/phases/1-expansion-scan-report.md):
 *   BREAKS  - the script fails to compile, or the line throws;
 *   CHANGED - it runs, with a different result (usually a silent undefined);
 *   INFO    - worth a look; breaks only in a mode players do not run by default.
 *
 * Output carries rule, severity, line and column only: never source text (CLAUDE.md rule 6).
 */

const fs = require("fs");
const path = require("path");
const { mask, helpers } = require("./rules");
const { lineStarts, posOf, matchParen, nextNonSpace, byRegex } = helpers;

const NOT_AFTER = "(?<![.\\w$])";   // not a member access and not mid-identifier

/**
 * Hits for `re`, all with one severity. `what` names the construct for the report: a fixed string,
 * or a function of the matched (masked) text that returns a name from a fixed vocabulary (an API or
 * contract name), never free expansion text.
 */
function regexHits(re, severity, what) {
  const find = byRegex(re);
  return (masked) => find(masked).map((h) => ({
    ...h,
    severity,
    what: typeof what === "function" ? what(masked.slice(h.index, h.index + h.length)) : what,
  }));
}

/** The first name of `vocabulary` that occurs in `text` as a whole word, else `fallback`. */
function nameIn(vocabulary, fallback) {
  return (text) => vocabulary.find((v) => {
    const i = text.indexOf(v);
    return i >= 0 && !/[\w$]/.test(text[i - 1] || "") && !/[\w$]/.test(text[i + v.length] || "");
  }) || fallback;
}

/** Names of the file's declared functions: `function f(`, `f = function`, `f: function`. */
function functionNames(masked) {
  const names = new Set();
  for (const m of masked.matchAll(/(?<![.\w$])function\s+([A-Za-z_$][\w$]*)\s*\(/g)) names.add(m[1]);
  for (const m of masked.matchAll(/([A-Za-z_$][\w$]*)\s*[:=]\s*function(?![\w$])/g)) names.add(m[1]);
  return names;
}

/** Names bound by `catch (name)` anywhere in the file. */
function catchNames(masked) {
  const names = new Set();
  for (const m of masked.matchAll(/(?<![.\w$])catch\s*\(\s*([A-Za-z_$][\w$]*)/g)) names.add(m[1]);
  return names;
}

/** The identifier just before the '.' that starts a member hit at `index`. */
function receiverBefore(masked, index) {
  let j = index - 1;
  while (j >= 0 && /\s/.test(masked[j])) j--;
  const end = j + 1;
  while (j >= 0 && /[\w$]/.test(masked[j])) j--;
  return masked.slice(j + 1, end);
}

/** Does the original source start with a "use strict" directive (comments/blank lines allowed)? */
function fileIsStrict(src) {
  const body = src.replace(/^﻿/, "").replace(/^(?:\s+|\/\/[^\n]*\n|\/\*[\s\S]*?\*\/)*/, "");
  return /^(["'])use strict\1/.test(body);
}

/* ------------------------------------------------------------------ */
/* readonly-native-write: the receivers we can name, and their classes */
/* ------------------------------------------------------------------ */

const RECEIVERS = [
  // longest first: "player.ship" must win over "player"
  { re: "player\\s*\\.\\s*ship", classes: ["PlayerShip", "Ship", "Entity"] },
  { re: "this\\s*\\.\\s*ship", classes: ["Ship", "Entity"] },
  { re: "system\\s*\\.\\s*mainStation", classes: ["Station", "Ship", "Entity"] },
  { re: "system\\s*\\.\\s*mainPlanet", classes: ["Planet", "Entity"] },
  { re: "system\\s*\\.\\s*sun", classes: ["Sun", "Entity"] },
  { re: "player", classes: ["Player"] },
  { re: "system", classes: ["System"] },
  { re: "clock", classes: ["Clock"] },
];

let readOnlyCache = null;

/** class name -> Set of property names that are read-only in the 1.93 contract. */
function readOnlyByClass() {
  if (readOnlyCache) return readOnlyCache;
  const file = path.join(__dirname, "..", "..", "oxp-contract", "js-api-1.93.json");
  const api = JSON.parse(fs.readFileSync(file, "utf8"));
  readOnlyCache = new Map();
  for (const [cls, v] of Object.entries(api.globals || {})) {
    const ro = new Set();
    const rw = new Set();
    for (const sect of ["prototype_members", "statics"]) {
      for (const [name, m] of Object.entries(v[sect] || {})) {
        if (!m || m.kind !== "property") continue;
        (m.writable === false ? ro : rw).add(name);
      }
    }
    readOnlyCache.set(cls, { ro, rw });
  }
  return readOnlyCache;
}

/** Is `prop` read-only for an object of this class chain (read-only somewhere, writable nowhere)? */
function isReadOnly(classes, prop) {
  const table = readOnlyByClass();
  let ro = false;
  for (const c of classes) {
    const t = table.get(c);
    if (!t) continue;
    if (t.rw.has(prop)) return false;
    if (t.ro.has(prop)) ro = true;
  }
  return ro;
}

/* ------------------------------------------------------------------ */
/* the detectors                                                       */
/* ------------------------------------------------------------------ */

const COMPAT_DETECTORS = {
  "for-each": {
    description: "for each (x in obj): JS1.6 value iteration, SpiderMonkey only",
    message: "for each (...): SpiderMonkey-only; the script fails to compile on QuickJS-ng",
    detect: regexHits(new RegExp(NOT_AFTER + "for\\s+each\\s*\\("), "BREAKS", "for each"),
  },

  "removed-api": {
    description: "SpiderMonkey-only APIs QuickJS-ng does not have (engine-probe.c)",
    message: "SpiderMonkey-only API, absent on QuickJS-ng: throws, or reads as undefined",
    detect(masked) {
      const throws = [
        /\.\s*(?:un)?watch\s*\(/,                       // Object.prototype.watch/unwatch
        new RegExp(NOT_AFTER + "(?:new\\s+)?Iterator\\s*\\("), // legacy Iterator(obj): TypeError now
        new RegExp(NOT_AFTER + "StopIteration(?![\\w$])"),
        /\.\s*toLocaleFormat\s*\(/,
        /(?<![\w$])__noSuchMethod__(?![\w$])/,
      ];
      const silent = [
        /(?<![\w$])RegExp\s*\.\s*(?:\$[1-9_&+`']|lastMatch|lastParen|leftContext|rightContext|input|multiline)(?![\w$])/,
        /\.\s*(?:arity|caller|fileName|lineNumber|__count__|__parent__)(?![\w$])/,
        /(?<![\w$])__iterator__(?![\w$])/,
      ];
      const api = nameIn(["unwatch", "watch", "Iterator", "StopIteration", "toLocaleFormat", "__noSuchMethod__",
                          "lastMatch", "lastParen", "leftContext", "rightContext", "input", "multiline",
                          "arity", "caller", "fileName", "lineNumber", "__count__", "__parent__", "__iterator__"],
                         "RegExp.$n");
      const hits = [];
      for (const re of throws) hits.push(...regexHits(re, "BREAKS", api)(masked));
      for (const re of silent) hits.push(...regexHits(re, "CHANGED", api)(masked));
      // caller/arity/fileName/lineNumber are also common names for an expansion's own fields
      // ({ caller: x }, opts.lineNumber). Only a read from something known to be a function
      // (a declared function, arguments.callee) or a caught error is CHANGED; the rest is INFO.
      const fns = functionNames(masked);
      fns.add("callee");
      const caught = catchNames(masked);
      for (const h of hits) {
        const owner = h.what === "arity" || h.what === "caller" ? fns
                    : h.what === "fileName" || h.what === "lineNumber" ? caught : null;
        if (owner && !owner.has(receiverBefore(masked, h.index))) h.severity = "INFO";
      }
      return hits;
    },
  },

  "polyfill-approx": {
    description: "toSource/uneval/quote and the Array/String generics: polyfilled by the game (ADR-0023), output differs",
    message: "works through the game's polyfill (ADR-0023), but toSource/uneval/quote output text differs from SpiderMonkey's",
    detect(masked) {
      const hits = [];
      hits.push(...regexHits(/(?<![\w$])toSource\s*\(/, "CHANGED", "toSource")(masked));
      hits.push(...regexHits(new RegExp(NOT_AFTER + "uneval\\s*\\("), "CHANGED", "uneval")(masked));
      hits.push(...regexHits(/\.\s*quote\s*\(\s*\)/, "CHANGED", "quote")(masked));
      // Array.forEach(list, fn), String.replace(s, ...): generics, not the standard statics
      const arrayGenerics = "join|reverse|sort|push|pop|shift|unshift|splice|concat|slice|indexOf|lastIndexOf|forEach|map|filter|every|some|reduce|reduceRight";
      const stringGenerics = "substring|substr|toLowerCase|toUpperCase|charAt|charCodeAt|indexOf|lastIndexOf|localeCompare|match|search|replace|split|concat|slice|trim|trimLeft|trimRight";
      hits.push(...regexHits(new RegExp(NOT_AFTER + "Array\\s*\\.\\s*(?:" + arrayGenerics + ")\\s*\\("), "INFO", "Array generic")(masked));
      hits.push(...regexHits(new RegExp(NOT_AFTER + "String\\s*\\.\\s*(?:" + stringGenerics + ")\\s*\\("), "INFO", "String generic")(masked));
      return hits;
    },
  },

  "readonly-native-write": {
    description: "assignment to a property the 1.93 contract marks read-only, through a known Oolite object",
    message: "assigns a read-only Oolite property: ignored on QuickJS-ng even in strict code (SpiderMonkey threw in strict code)",
    detect(masked) {
      const hits = [];
      const rx = new RegExp(NOT_AFTER + "(" + RECEIVERS.map((r) => r.re).join("|") +
                            ")\\s*\\.\\s*([A-Za-z_$][\\w$]*)\\s*(?:[-+*/%]|<<|>>>?|&|\\||\\^)?=(?!=)", "g");
      let m;
      while ((m = rx.exec(masked)) !== null) {
        const recv = RECEIVERS.find((r) => new RegExp("^" + r.re + "$").test(m[1]));
        if (recv && isReadOnly(recv.classes, m[2])) {
          // receiver from RECEIVERS, property from the contract: both fixed vocabulary
          hits.push({ index: m.index, length: m[0].length, severity: "CHANGED",
                      what: m[1].replace(/\s+/g, "") + "." + m[2] });
        }
      }
      return hits;
    },
  },

  "strict-only": {
    description: "constructs that fail only in strict code: arguments.callee, legacy octal, duplicate parameters, with",
    message: "fails in strict code: a strict file throws or does not compile; a sloppy file breaks only under standards enforcement",
    detect(masked, src) {
      const sev = fileIsStrict(src) ? "BREAKS" : "INFO";
      const hits = [];
      hits.push(...regexHits(/(?<![\w$.])arguments\s*\.\s*callee(?![\w$])/, sev, "arguments.callee")(masked));
      hits.push(...regexHits(/(?<![\w$.])0[0-7]+(?![\w$.89])/, sev, "legacy octal")(masked));
      hits.push(...regexHits(new RegExp(NOT_AFTER + "with\\s*\\("), sev, "with")(masked));
      const fn = new RegExp(NOT_AFTER + "function(?![\\w$])", "g");
      let m;
      while ((m = fn.exec(masked)) !== null) {
        let i = nextNonSpace(masked, m.index + 8);
        if (masked[i] === "*") i = nextNonSpace(masked, i + 1);
        while (i < masked.length && /[\w$]/.test(masked[i])) i++;
        i = nextNonSpace(masked, i);
        if (masked[i] !== "(") continue;
        const end = matchParen(masked, i);
        if (end < 0) continue;
        const params = masked.slice(i + 1, end - 1).split(",").map((p) => p.trim()).filter((p) => /^[A-Za-z_$][\w$]*$/.test(p));
        if (new Set(params).size !== params.length) {
          hits.push({ index: m.index, length: end - m.index, severity: sev, what: "duplicate parameter" });
        }
      }
      return hits;
    },
  },

  "fn-tostring": {
    description: "a function's source text read back: SpiderMonkey decompiled it, QuickJS-ng returns the original",
    message: "reads a function's source text: QuickJS-ng returns the original text, SpiderMonkey 1.8.5 returned decompiled, reformatted source",
    detect(masked) {
      const names = functionNames(masked);
      const hits = [];
      hits.push(...regexHits(/(?<![\w$])Function\s*\.\s*prototype\s*\.\s*toString(?![\w$])/, "CHANGED",
                             "Function.prototype.toString")(masked));
      if (!names.size) return hits;
      const alt = [...names].map((n) => n.replace(/\$/g, "\\$")).join("|");
      // name.toString(), this.$x.name.toString(), String(name)
      hits.push(...regexHits(new RegExp("(?<![\\w$])(?:" + alt + ")\\s*\\.\\s*toString\\s*\\(\\s*\\)"), "CHANGED",
                             "fn.toString()")(masked));
      hits.push(...regexHits(new RegExp(NOT_AFTER + "String\\s*\\(\\s*(?:[\\w$]+\\s*\\.\\s*)*(?:" + alt + ")\\s*\\)"), "CHANGED",
                             "String(fn)")(masked));
      return hits;
    },
  },

  "error-message": {
    description: "a caught error's message compared or searched: wording differs between engines",
    message: "matches on an error's message text: QuickJS-ng's wording differs from SpiderMonkey's",
    detect(masked) {
      const names = catchNames(masked);
      if (!names.size) return [];
      const alt = [...names].map((n) => n.replace(/\$/g, "\\$")).join("|");
      const msg = "(?<![.\\w$])(?:" + alt + ")\\s*\\.\\s*message";
      const hits = [];
      hits.push(...regexHits(new RegExp(msg + "\\s*(?:===?|!==?)"), "CHANGED", "compared")(masked));
      hits.push(...regexHits(new RegExp("(?:===?|!==?)\\s*" + msg.slice(NOT_AFTER.length) + "(?![\\w$])"), "CHANGED", "compared")(masked));
      hits.push(...regexHits(new RegExp(msg + "\\s*\\.\\s*(?:indexOf|search|match|includes|startsWith|endsWith|replace|substr|substring|slice)\\s*\\("), "CHANGED", "searched")(masked));
      hits.push(...regexHits(new RegExp("\\.\\s*test\\s*\\(\\s*" + msg.slice(NOT_AFTER.length) + "\\s*\\)"), "CHANGED", "regex-tested")(masked));
      return hits;
    },
  },

  "global-enum": {
    description: "enumerating the global object: QuickJS-ng has many more standard globals",
    message: "enumerates the global object: QuickJS-ng has BigInt, Map, Promise, Proxy, Reflect, Set, Symbol, WeakMap, globalThis and more",
    detect(masked) {
      const g = "(?:global|globalThis)";
      const hits = [];
      hits.push(...regexHits(new RegExp(NOT_AFTER + "for\\s*\\(\\s*(?:var\\s+|let\\s+|const\\s+)?[A-Za-z_$][\\w$]*\\s+in\\s+" + g + "\\s*\\)"), "INFO", "for-in global")(masked));
      hits.push(...regexHits(new RegExp(NOT_AFTER + "Object\\s*\\.\\s*(?:keys|getOwnPropertyNames)\\s*\\(\\s*" + g + "\\s*\\)"), "INFO",
                             "Object.keys(global)")(masked));
      return hits;
    },
  },
};

const COMPAT_RULE_NAMES = Object.keys(COMPAT_DETECTORS);
const SEVERITY_ORDER = { BREAKS: 0, CHANGED: 1, INFO: 2 };

/**
 * Scan one source text with the compat rules.
 * @returns {{rule:string,severity:string,what:string,line:number,column:number}[]}
 *   `what` names the construct from a fixed vocabulary (API or contract names), never source text.
 */
function scanCompat(src, enabled = COMPAT_RULE_NAMES) {
  const masked = mask(src);
  const starts = lineStarts(src);
  const seen = new Set();
  const findings = [];
  for (const name of enabled) {
    const rule = COMPAT_DETECTORS[name];
    if (!rule) throw new Error("unknown compat rule: " + name);
    for (const hit of rule.detect(masked, src)) {
      const { line, column } = posOf(starts, hit.index);
      const key = name + ":" + hit.index;
      if (seen.has(key)) continue;
      seen.add(key);
      findings.push({ rule: name, severity: hit.severity, what: hit.what, line, column });
    }
  }
  findings.sort((a, b) => a.line - b.line || a.column - b.column || a.rule.localeCompare(b.rule));
  return findings;
}

module.exports = { COMPAT_DETECTORS, COMPAT_RULE_NAMES, SEVERITY_ORDER, scanCompat, fileIsStrict };
