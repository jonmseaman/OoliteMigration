"use strict";
/*
 * Detectors for Mozilla-only (SpiderMonkey-only) JavaScript.
 *
 * WHY THESE ARE TEXT DETECTORS AND NOT AST RULES
 * ----------------------------------------------
 * Four of the eight constructs this bead must flag - conditional catch
 * clauses, E4X, let blocks and expression closures - are *syntax* that no
 * standards-conforming JavaScript parser accepts. espree (ESLint's parser),
 * acorn, and every other ES2015+ parser raise a SyntaxError on them, and an
 * ESLint rule only ever runs on a file that parsed. An AST rule for `catch (e
 * if cond)` can therefore never fire: it is unreachable by construction.
 *
 * So every rule here works on the source text *after masking* - comments,
 * string literals, template literals and regular-expression literals are
 * replaced by spaces of the same length (newlines preserved, so line/column
 * numbers are exact). Masking is what keeps the detectors honest: it is why
 * the clean fixture, which deliberately mentions every banned construct
 * inside strings, comments and a regex, produces zero hits.
 *
 * The same rule objects are exported as an ESLint plugin (plugin.js) so a real
 * `eslint` run and the standalone runner (lint.js) share one implementation.
 */

/* ------------------------------------------------------------------ */
/* masking                                                             */
/* ------------------------------------------------------------------ */

const REGEX_PRECEDERS = new Set([
  "return", "typeof", "instanceof", "in", "of", "delete", "void", "throw",
  "new", "do", "else", "yield", "case",
]);

/**
 * Replace the body of every comment, string, template literal and regex
 * literal with spaces. Newlines are preserved so that offsets, lines and
 * columns in the masked text match the original exactly.
 */
function mask(src) {
  const out = src.split("");
  const n = src.length;
  let i = 0;
  // last significant (non-space, non-comment) character seen, used to decide
  // whether a '/' starts a regex or is a division operator
  let prev = "";
  let prevWord = "";

  const blank = (from, to) => {
    for (let k = from; k < to && k < n; k++) {
      if (out[k] !== "\n" && out[k] !== "\r") out[k] = " ";
    }
  };

  while (i < n) {
    const c = src[i];
    const d = src[i + 1];

    if (c === "/" && d === "/") {
      let j = i;
      while (j < n && src[j] !== "\n") j++;
      blank(i, j);
      i = j;
      continue;
    }
    if (c === "/" && d === "*") {
      let j = i + 2;
      while (j < n && !(src[j] === "*" && src[j + 1] === "/")) j++;
      j = Math.min(n, j + 2);
      blank(i, j);
      i = j;
      continue;
    }
    if (c === '"' || c === "'") {
      let j = i + 1;
      while (j < n) {
        if (src[j] === "\\") { j += 2; continue; }
        if (src[j] === c || src[j] === "\n") break;
        j++;
      }
      j = Math.min(n, j + 1);
      blank(i, j);
      prev = "x"; prevWord = "";
      i = j;
      continue;
    }
    if (c === "`") {
      // Template literals are masked whole, expression holes included. That is
      // conservative: it can hide a construct used inside ${...}. Recorded in
      // README.md as a known limit rather than papered over.
      let j = i + 1;
      let depth = 0;
      while (j < n) {
        if (src[j] === "\\") { j += 2; continue; }
        if (src[j] === "$" && src[j + 1] === "{") { depth++; j += 2; continue; }
        if (src[j] === "}" && depth > 0) { depth--; j++; continue; }
        if (src[j] === "`" && depth === 0) break;
        j++;
      }
      j = Math.min(n, j + 1);
      blank(i, j);
      prev = "x"; prevWord = "";
      i = j;
      continue;
    }
    if (c === "/") {
      const regexOk =
        prev === "" ||
        "(,=:[!&|?{};+-*%~^<>".includes(prev) ||
        REGEX_PRECEDERS.has(prevWord);
      if (regexOk) {
        let j = i + 1;
        let inClass = false;
        let closed = false;
        while (j < n && src[j] !== "\n") {
          if (src[j] === "\\") { j += 2; continue; }
          if (src[j] === "[") inClass = true;
          else if (src[j] === "]") inClass = false;
          else if (src[j] === "/" && !inClass) { closed = true; break; }
          j++;
        }
        if (closed) {
          j++;
          while (j < n && /[a-z]/.test(src[j])) j++; // flags
          blank(i, j);
          prev = "x"; prevWord = "";
          i = j;
          continue;
        }
      }
      prev = c; prevWord = "";
      i++;
      continue;
    }

    if (/\s/.test(c)) { i++; continue; }

    if (/[A-Za-z_$]/.test(c)) {
      let j = i;
      while (j < n && /[\w$]/.test(src[j])) j++;
      prevWord = src.slice(i, j);
      prev = src[j - 1];
      i = j;
      continue;
    }

    prev = c;
    prevWord = "";
    i++;
  }
  return out.join("");
}

/* ------------------------------------------------------------------ */
/* helpers                                                             */
/* ------------------------------------------------------------------ */

function lineStarts(src) {
  const starts = [0];
  for (let i = 0; i < src.length; i++) if (src[i] === "\n") starts.push(i + 1);
  return starts;
}

function posOf(starts, index) {
  let lo = 0, hi = starts.length - 1;
  while (lo < hi) {
    const mid = (lo + hi + 1) >> 1;
    if (starts[mid] <= index) lo = mid; else hi = mid - 1;
  }
  return { line: lo + 1, column: index - starts[lo] + 1 };
}

/** Index just past the ')' matching the '(' at `open`, or -1. */
function matchParen(text, open) {
  let depth = 0;
  for (let i = open; i < text.length; i++) {
    if (text[i] === "(") depth++;
    else if (text[i] === ")") {
      depth--;
      if (depth === 0) return i + 1;
    }
  }
  return -1;
}

function nextNonSpace(text, i) {
  while (i < text.length && /\s/.test(text[i])) i++;
  return i;
}

/** Build a detector from a global regex over the masked text. */
function byRegex(re) {
  return (masked) => {
    const hits = [];
    const rx = new RegExp(re.source, re.flags.includes("g") ? re.flags : re.flags + "g");
    let m;
    while ((m = rx.exec(masked)) !== null) {
      hits.push({ index: m.index, length: m[0].length });
      if (m[0].length === 0) rx.lastIndex++;
    }
    return hits;
  };
}

/* ------------------------------------------------------------------ */
/* the detectors (the eight of bead oo-ctq, then legacy-generator)    */
/* ------------------------------------------------------------------ */

const DETECTORS = {
  "catch-if": {
    description: "conditional catch clause: catch (e if cond) {} (JS1.5, SpiderMonkey only)",
    message: "conditional catch clause (catch ... if): SpiderMonkey-only, removed in Firefox 59",
    detect(masked) {
      const hits = [];
      const rx = /(?<![.\w$])catch\s*\(/g;
      let m;
      while ((m = rx.exec(masked)) !== null) {
        const open = masked.indexOf("(", m.index);
        const end = matchParen(masked, open);
        if (end < 0) continue;
        const inner = masked.slice(open + 1, end - 1);
        if (/(?<![.\w$])if(?![\w$])/.test(inner)) {
          hits.push({ index: m.index, length: end - m.index });
        }
        rx.lastIndex = open + 1;
      }
      return hits;
    },
  },

  e4x: {
    description: "E4X / ECMA-357: XML literals, the .. descendant operator, the .@ attribute operator",
    message: "E4X syntax (ECMA-357): removed from SpiderMonkey in Firefox 21, never implemented elsewhere",
    detect(masked) {
      const hits = [];
      // descendant operator:  doc..name
      hits.push(...byRegex(/[A-Za-z_$][\w$]*\s*\.\.\s*[A-Za-z_$@*]/)(masked));
      // attribute operator:  doc.@identifier
      hits.push(...byRegex(/\.\s*@\s*[A-Za-z_$*]/)(masked));
      // XML literal in expression position:  x = <tag>, return <tag>, (<tag>
      hits.push(...byRegex(/(?:[=(,:[]|(?<![.\w$])(?:return|new|typeof|yield)(?![\w$]))\s*<\s*[A-Za-z_/?!]/)(masked));
      return hits.sort((a, b) => a.index - b.index);
    },
  },

  "quote-method": {
    description: "String.prototype.quote(), a SpiderMonkey-only method",
    message: ".quote(): SpiderMonkey-only String method, removed in Firefox 37",
    detect: byRegex(/\.\s*quote\s*\(/),
  },

  "to-source": {
    description: "Object.prototype.toSource() / uneval-style source reflection",
    message: "toSource(): SpiderMonkey-only, removed in Firefox 74",
    detect: byRegex(/(?<![\w$])toSource\s*\(/),
  },

  uneval: {
    description: "the global uneval(), SpiderMonkey only",
    message: "uneval(): SpiderMonkey-only global, removed in Firefox 74",
    detect: byRegex(/(?<![.\w$])uneval\s*\(/),
  },

  "let-block": {
    description: "let block / let expression: let (x = 1) { ... } (JS1.7, SpiderMonkey only)",
    message: "let block/expression: SpiderMonkey-only JS1.7 syntax, removed in Firefox 44",
    detect: byRegex(/(?<![.\w$])let\s*\(/),
  },

  "legacy-accessor": {
    description: "__defineGetter__ / __defineSetter__ / __lookupGetter__ / __lookupSetter__",
    message: "legacy accessor (__define*__/__lookup*__): deprecated Mozilla extension; use Object.defineProperty",
    detect: byRegex(/__(?:define|lookup)(?:Getter|Setter)__/),
  },

  "expression-closure": {
    description: "expression closures: function (x) x * x (JS1.8, SpiderMonkey only)",
    message: "expression closure (function body is an expression, not a block): SpiderMonkey-only, removed in Firefox 60",
    detect(masked) {
      const hits = [];
      const rx = /(?<![.\w$])function(?![\w$])/g;
      let m;
      while ((m = rx.exec(masked)) !== null) {
        let i = nextNonSpace(masked, m.index + 8);
        if (masked[i] === "*") i = nextNonSpace(masked, i + 1); // generator
        if (/[A-Za-z_$]/.test(masked[i] || "")) {            // optional name
          while (i < masked.length && /[\w$]/.test(masked[i])) i++;
          i = nextNonSpace(masked, i);
        }
        if (masked[i] !== "(") continue;
        const end = matchParen(masked, i);
        if (end < 0) continue;
        const body = nextNonSpace(masked, end);
        if (masked[body] !== "{") {
          hits.push({ index: m.index, length: Math.min(body + 1, masked.length) - m.index });
        }
      }
      return hits;
    },
  },

  // Bead oo-1gc.16: three authors' ship scripts do
  //   subs.each = function () { for (...) yield this[i]; }  for (let s in subs.each()) ...
  // SpiderMonkey 1.8.5 (Oolite ran it at JSVERSION_ECMA_5 = 185, above the 1.7 that enables `yield`)
  // made any function containing `yield` a generator, and for-in over one iterated its values. No
  // other engine has either; QuickJS-ng fails the whole file with "SyntaxError: expecting ';'".
  "legacy-generator": {
    description: "legacy generator: a function (not function*) whose body uses yield (JS1.7, SpiderMonkey only)",
    message: "yield in a function not declared function*: SpiderMonkey-only JS1.7 legacy generator, removed in Firefox 58",
    detect(masked) {
      const hits = [];
      const frames = [];   // one per open '{': null for a plain block, else { gen } for a function body
      const rx = /[{}]|(?<![.\w$])yield(?![\w$])/g;
      let m;
      while ((m = rx.exec(masked)) !== null) {
        if (m[0] === "{") { frames.push(functionBodyAt(masked, m.index)); continue; }
        if (m[0] === "}") { frames.pop(); continue; }
        if (masked[nextNonSpace(masked, m.index + 5)] === ":") continue;   // { yield: 1 } is a key
        let fn = null;
        for (let k = frames.length - 1; k >= 0 && !fn; k--) fn = frames[k];
        if (fn && !fn.gen) hits.push({ index: m.index, length: 5 });
      }
      return hits;
    },
  },
};

/** Index of the last non-space character before `i`, or -1. */
function prevNonSpace(text, i) {
  while (i >= 0 && /\s/.test(text[i])) i--;
  return i;
}

/**
 * Classify the '{' at `brace`: null for a block/object literal, or { gen } when it opens a function
 * body -- `function [*] [name] (...) {`, a method `[*] name (...) {`, or an arrow `=> {`.
 */
function functionBodyAt(text, brace) {
  let j = prevNonSpace(text, brace - 1);
  if (j >= 1 && text[j] === ">" && text[j - 1] === "=") return { gen: false };
  if (text[j] !== ")") return null;
  let depth = 0;
  for (; j >= 0; j--) {
    if (text[j] === ")") depth++;
    else if (text[j] === "(" && --depth === 0) break;
  }
  let k = prevNonSpace(text, j - 1);
  if (k >= 0 && text[k] === "*") return { gen: true };                  // function* (
  let w = k;
  while (w >= 0 && /[\w$]/.test(text[w])) w--;
  const word = text.slice(w + 1, k + 1);
  if (!word) return null;
  if (/^(?:if|for|while|switch|catch|with)$/.test(word)) return null;
  if (word === "function") return { gen: false };
  k = prevNonSpace(text, w);
  return { gen: k >= 0 && text[k] === "*" };                           // function* name ( / *method (
}

const RULE_NAMES = Object.keys(DETECTORS);

/**
 * Scan one source text with the named rules.
 * @param {string} src   raw file text
 * @param {string[]} enabled  rule names to run
 * @returns {{rule:string,line:number,column:number,message:string,snippet:string}[]}
 */
function scanText(src, enabled = RULE_NAMES) {
  const masked = mask(src);
  const starts = lineStarts(src);
  const findings = [];
  for (const name of enabled) {
    const rule = DETECTORS[name];
    if (!rule) throw new Error("unknown rule: " + name);
    for (const hit of rule.detect(masked)) {
      const { line, column } = posOf(starts, hit.index);
      const lineEnd = src.indexOf("\n", hit.index);
      const raw = src.slice(starts[line - 1], lineEnd < 0 ? src.length : lineEnd);
      findings.push({
        rule: name,
        line,
        column,
        message: rule.message,
        snippet: raw.trim().slice(0, 160),
      });
    }
  }
  findings.sort((a, b) => a.line - b.line || a.column - b.column || a.rule.localeCompare(b.rule));
  return findings;
}

module.exports = { DETECTORS, RULE_NAMES, mask, scanText };
