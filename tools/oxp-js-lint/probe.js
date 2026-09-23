"use strict";
/*
 * tools/oxp-js-lint/probe.js - REDACTING probe of one line of an expansion script
 * (bead oo-1gc.13; shared by oo-1gc.14..16).
 *
 * CLAUDE.md rule 6 forbids an agent from reading expansion content. Triaging a
 * JavaScript error logged at "<script>.js:<line>" still needs the *shape* of the
 * code at that line. This probe is the same trust model as lint.js: code reads
 * the file, the agent reads only a constrained, redacted rendering of it.
 *
 * What it prints, and nothing else:
 *   - JS keywords and punctuators, verbatim;
 *   - identifiers that are in a FIXED allowlist (ECMAScript globals and
 *     keywords, the names in oxp-contract/js-api-1.93.json, `this`), verbatim;
 *   - every other identifier as a stable placeholder ID1, ID2, ... numbered in
 *     file order, so the same name is the same placeholder everywhere;
 *   - string / template / number / regex literals as STR / TPL / NUM / RE,
 *     except a string whose whole value is itself an allowlisted name (or one
 *     of the script-object property names Oolite defines, SCRIPT_PROPS), which
 *     prints as STR"value" -- e.g. the key in `this["name"]`;
 *   - any other character as `?`; comments are dropped.
 * Plus boolean/count facts computed by code: whether the file (or a function)
 * starts with the "use strict" directive, and per placeholder whether it is
 * declared (var/let/const/function/parameter/catch) anywhere in the file, and
 * how often it is used bare, as a member (`.ID`), as an object key, or as
 * `this.ID = ...`.
 *
 *   node tools/oxp-js-lint/probe.js corpus <identifier> <member-suffix> <line> [--context N]
 *   node tools/oxp-js-lint/probe.js file <path.js> <line> [--context N]
 *
 * `corpus` resolves the identifier through tools/oxp-corpus/tier3.json and the
 * byte cache (as lint.js corpus does), picks the .js member whose path ends
 * with <member-suffix>, and never touches the network. `file` exists for the
 * self-test on the synthetic fixture tools/oxp-js-lint/fixtures/probe/*.js.
 * Also `--parse`: report where V8 (node) fails to parse the file, as a line
 * and column only (the engine's message text is never printed).
 */

const fs = require("fs");
const path = require("path");
const vm = require("vm");

const HERE = __dirname;
const REPO_ROOT = path.resolve(HERE, "..", "..");

/* ------------------------------------------------------------------ */
/* allowlist                                                           */
/* ------------------------------------------------------------------ */

const KEYWORDS = [
  "break", "case", "catch", "class", "const", "continue", "debugger", "default",
  "delete", "do", "else", "export", "extends", "finally", "for", "function", "if",
  "import", "in", "instanceof", "new", "return", "super", "switch", "this", "throw",
  "try", "typeof", "var", "void", "while", "with", "yield", "let", "static",
  "enum", "await", "implements", "package", "protected", "interface", "private",
  "public", "null", "true", "false", "undefined", "NaN", "Infinity", "of", "get",
  "set", "async", "arguments", "eval",
  // SpiderMonkey-only words worth seeing
  "each", "__defineGetter__", "__defineSetter__", "__lookupGetter__",
  "__lookupSetter__", "__proto__", "__iterator__", "__noSuchMethod__",
  "toSource", "uneval", "quote", "watch", "unwatch",
];

const ES_GLOBALS = [
  "Object", "Function", "Array", "String", "Number", "Boolean", "Symbol", "Math",
  "Date", "RegExp", "Error", "TypeError", "RangeError", "ReferenceError",
  "SyntaxError", "EvalError", "URIError", "JSON", "Map", "Set", "WeakMap",
  "WeakSet", "Promise", "Proxy", "Reflect", "globalThis", "parseInt",
  "parseFloat", "isNaN", "isFinite", "encodeURI", "decodeURI",
  "encodeURIComponent", "decodeURIComponent", "escape", "unescape",
  "prototype", "constructor", "length", "call", "apply", "bind", "push", "pop",
  "shift", "unshift", "splice", "slice", "concat", "join", "indexOf",
  "lastIndexOf", "forEach", "map", "filter", "reduce", "some", "every", "sort",
  "keys", "hasOwnProperty", "toString", "valueOf", "floor", "ceil", "round",
  "random", "min", "max", "abs", "sqrt", "pow", "substring", "substr",
  "charAt", "split", "replace", "match", "test", "exec", "toLowerCase",
  "toUpperCase", "trim", "defineProperty", "getOwnPropertyNames", "create",
  "freeze", "name", "message", "Iterator", "StopIteration", "XML",
];

function contractNames() {
  const p = path.join(REPO_ROOT, "oxp-contract", "js-api-1.93.json");
  const names = new Set();
  if (!fs.existsSync(p)) return names;
  const d = JSON.parse(fs.readFileSync(p, "utf8"));
  const walk = (o) => {
    if (!o || typeof o !== "object") return;
    for (const [k, v] of Object.entries(o)) {
      if (["globals", "statics", "prototype_members", "own_members"].includes(k) && v && typeof v === "object") {
        for (const n of Object.keys(v)) names.add(n);
      }
      walk(v);
    }
  };
  walk(d);
  return names;
}

// Properties Oolite itself puts on a script object (OOJSScript.mm), and the directive.
const SCRIPT_PROPS = [
  "oolite_manifest_identifier", "name", "version", "author", "description",
  "copyright", "license", "licence", "use strict",
];

const ALLOW = new Set([...KEYWORDS, ...ES_GLOBALS, ...contractNames()]);
const ALLOW_STR = new Set([...ALLOW, ...SCRIPT_PROPS]);
const KEYWORD_SET = new Set(KEYWORDS);

/* ------------------------------------------------------------------ */
/* tokenizer                                                           */
/* ------------------------------------------------------------------ */

const PUNCT = [
  ">>>=", "...", "===", "!==", "**=", "<<=", ">>=", ">>>", "&&=", "||=", "??=",
  "=>", "==", "!=", "<=", ">=", "&&", "||", "??", "?.", "++", "--", "+=", "-=",
  "*=", "/=", "%=", "&=", "|=", "^=", "<<", ">>", "**", "::", "..", ".@",
  "{", "}", "(", ")", "[", "]", ";", ",", "<", ">", "+", "-", "*", "/", "%",
  "&", "|", "^", "!", "~", "?", ":", "=", ".", "@", "#",
];

const REGEX_PRECEDERS = new Set([
  "return", "typeof", "instanceof", "in", "of", "delete", "void", "throw",
  "new", "do", "else", "yield", "case",
]);

const ID_START = /[A-Za-z_$\u0080-￿]/;
const ID_PART = /[A-Za-z0-9_$\u0080-￿]/;

/** tokens: {t: kind, v: raw value, line} kinds: id, num, str, tpl, re, p, other */
function tokenize(src) {
  const toks = [];
  const n = src.length;
  let i = 0;
  let line = 1;
  const last = () => toks[toks.length - 1];
  const regexAllowed = () => {
    const l = last();
    if (!l) return true;
    if (l.t === "p") return !(l.v === ")" || l.v === "]" || l.v === "}" || l.v === "++" || l.v === "--");
    if (l.t === "id") return REGEX_PRECEDERS.has(l.v);
    return false;
  };
  while (i < n) {
    const c = src[i];
    const d = src[i + 1];
    if (c === "\n") { line++; i++; continue; }
    if (c === " " || c === "\t" || c === "\r" || c === "\f" || c === "\v" || c === "﻿" || c === " ") { i++; continue; }
    if (c === "/" && d === "/") { while (i < n && src[i] !== "\n") i++; continue; }
    if (c === "/" && d === "*") {
      let j = i + 2;
      while (j < n && !(src[j] === "*" && src[j + 1] === "/")) { if (src[j] === "\n") line++; j++; }
      i = Math.min(n, j + 2);
      continue;
    }
    if (c === '"' || c === "'") {
      let j = i + 1;
      while (j < n) {
        if (src[j] === "\\") { if (src[j + 1] === "\n") line++; j += 2; continue; }
        if (src[j] === c || src[j] === "\n") break;
        j++;
      }
      toks.push({ t: "str", v: src.slice(i + 1, j), line });
      i = Math.min(n, j + 1);
      continue;
    }
    if (c === "`") {
      const startLine = line;
      let j = i + 1;
      while (j < n && src[j] !== "`") { if (src[j] === "\\") j++; else if (src[j] === "\n") line++; j++; }
      toks.push({ t: "tpl", v: "", line: startLine });
      i = Math.min(n, j + 1);
      continue;
    }
    if (c === "/" && regexAllowed()) {
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
        while (j < n && ID_PART.test(src[j])) j++;
        toks.push({ t: "re", v: "", line });
        i = j;
        continue;
      }
    }
    if (/[0-9]/.test(c) || (c === "." && /[0-9]/.test(d || ""))) {
      let j = i + 1;
      while (j < n && /[0-9A-Za-z_.]/.test(src[j])) {
        if ((src[j] === "e" || src[j] === "E") && (src[j + 1] === "+" || src[j + 1] === "-")) j++;
        j++;
      }
      toks.push({ t: "num", v: "", line });
      i = j;
      continue;
    }
    if (ID_START.test(c) || c === "\\") {
      let j = i + 1;
      while (j < n && (ID_PART.test(src[j]) || src[j] === "\\")) j++;
      toks.push({ t: "id", v: src.slice(i, j), line });
      i = j;
      continue;
    }
    let matched = null;
    for (const p of PUNCT) {
      if (src.startsWith(p, i)) { matched = p; break; }
    }
    if (matched) {
      // `..` and `.@` are E4X only; outside `a..b` treat as two dots
      toks.push({ t: "p", v: matched, line });
      i += matched.length;
      continue;
    }
    toks.push({ t: "other", v: "?", line });
    i++;
  }
  return toks;
}

/* ------------------------------------------------------------------ */
/* facts                                                               */
/* ------------------------------------------------------------------ */

function isDirective(toks, k) {
  const t = toks[k];
  if (t.t !== "str" || t.v !== "use strict") return false;
  const prev = toks[k - 1];
  const next = toks[k + 1];
  const prevOk = !prev || (prev.t === "p" && (prev.v === "{" || prev.v === ";")) || (prev.t === "str");
  const nextOk = !next || (next.t === "p" && (next.v === ";" || next.v === "}")) || next.line > t.line;
  return prevOk && nextOk;
}

function analyse(src) {
  const toks = tokenize(src);
  const ph = new Map();
  const place = (name) => {
    if (ALLOW.has(name)) return name;
    if (!ph.has(name)) ph.set(name, "ID" + (ph.size + 1));
    return ph.get(name);
  };
  for (const t of toks) if (t.t === "id") place(t.v);

  const facts = new Map(); // name -> counters
  const fact = (name) => {
    if (!facts.has(name)) facts.set(name, { var: 0, let: 0, const: 0, function: 0, param: 0, catch: 0, bare: 0, member: 0, key: 0, thisAssign: 0 });
    return facts.get(name);
  };

  // declarations
  for (let k = 0; k < toks.length; k++) {
    const t = toks[k];
    if (t.t !== "id") continue;
    const prev = toks[k - 1];
    const next = toks[k + 1];
    if (!KEYWORD_SET.has(t.v) || t.v === "each" || t.v === "get" || t.v === "set" || t.v === "of") {
      const f = fact(t.v);
      if (prev && prev.t === "p" && (prev.v === "." || prev.v === "?.")) {
        f.member++;
        const pp = toks[k - 2];
        if (pp && pp.t === "id" && pp.v === "this" && next && next.t === "p" && next.v === "=") f.thisAssign++;
      } else if (next && next.t === "p" && next.v === ":" && prev && prev.t === "p" && (prev.v === "{" || prev.v === ",")) {
        f.key++;
      } else {
        f.bare++;
      }
    }
    if (t.v === "var" || t.v === "let" || t.v === "const") {
      // walk the declarator list at depth 0 of this statement
      let depth = 0;
      let expectName = true;
      for (let j = k + 1; j < toks.length; j++) {
        const u = toks[j];
        if (u.t === "p" && (u.v === "(" || u.v === "[" || u.v === "{")) { depth++; expectName = false; continue; }
        if (u.t === "p" && (u.v === ")" || u.v === "]" || u.v === "}")) { if (depth === 0) break; depth--; continue; }
        if (depth === 0 && u.t === "p" && u.v === ";") break;
        if (depth === 0 && u.t === "id" && (u.v === "in" || u.v === "of")) break;
        if (depth === 0 && u.t === "p" && u.v === ",") { expectName = true; continue; }
        if (expectName && u.t === "id") { fact(u.v)[t.v]++; expectName = false; continue; }
        expectName = false;
      }
    }
    if (t.v === "function") {
      let j = k + 1;
      if (toks[j] && toks[j].t === "id") { fact(toks[j].v).function++; j++; }
      if (toks[j] && toks[j].t === "p" && toks[j].v === "(") {
        let depth = 0;
        let expectName = true;
        for (j = j + 1; j < toks.length; j++) {
          const u = toks[j];
          if (u.t === "p" && u.v === ")" && depth === 0) break;
          if (u.t === "p" && (u.v === "(" || u.v === "[" || u.v === "{")) depth++;
          else if (u.t === "p" && (u.v === ")" || u.v === "]" || u.v === "}")) depth--;
          else if (depth === 0 && u.t === "p" && u.v === ",") { expectName = true; continue; }
          else if (depth === 0 && expectName && u.t === "id") fact(u.v).param++;
          expectName = false;
        }
      }
    }
    if (t.v === "catch" && toks[k + 1] && toks[k + 1].v === "(" && toks[k + 2] && toks[k + 2].t === "id") {
      fact(toks[k + 2].v).catch++;
    }
  }

  // "use strict" directives
  const directives = [];
  for (let k = 0; k < toks.length; k++) {
    if (isDirective(toks, k)) directives.push({ line: toks[k].line, top: k === 0 || toks.slice(0, k).every((u) => u.t === "str" || (u.t === "p" && u.v === ";")) });
  }
  return { toks, ph, facts, directives };
}

function render(t, ph) {
  switch (t.t) {
    case "id": return ALLOW.has(t.v) ? t.v : ph.get(t.v);
    case "str": return ALLOW_STR.has(t.v) ? `STR"${t.v}"` : "STR";
    case "tpl": return "TPL";
    case "num": return "NUM";
    case "re": return "RE";
    case "p": return t.v;
    default: return "?";
  }
}

/** V8's parse position for the file, or null if it parses. Message text is never returned. */
function parseCheck(src) {
  try {
    new vm.Script("(function(){\n" + src + "\n})", { filename: "probe" });
    return null;
  } catch (e) {
    const m = /probe:(\d+)/.exec(String(e.stack || ""));
    const lines = String(e.stack || "").split("\n");
    let col = null;
    const caret = lines.find((l) => /^\s*\^+\s*$/.test(l));
    if (caret) col = caret.indexOf("^") + 1;
    return { kind: e && e.constructor ? e.constructor.name : "Error", line: m ? Number(m[1]) - 1 : null, column: col };
  }
}

function report(src, line, ctx, label, doParse) {
  const { toks, ph, facts, directives } = analyse(src);
  const out = [];
  out.push(`probe: ${label}`);
  out.push(`lines: ${src.split("\n").length}`);
  const top = directives.some((d) => d.top);
  out.push(`use-strict at top of file: ${top ? "yes" : "no"}`);
  const fnDirs = directives.filter((d) => !d.top).map((d) => d.line);
  out.push(`use-strict function directives at lines: ${fnDirs.length ? fnDirs.join(",") : "none"}`);
  if (doParse) {
    const p = parseCheck(src);
    out.push(`v8 parse: ${p ? `${p.kind} at line ${p.line} column ${p.column}` : "ok"}`);
  }
  const lo = Math.max(1, line - ctx);
  const hi = line + ctx;
  const shown = new Set();
  for (let L = lo; L <= hi; L++) {
    const row = toks.filter((t) => t.line === L);
    for (const t of row) if (t.t === "id" && !ALLOW.has(t.v)) shown.add(t.v);
    out.push(`${L === line ? ">" : " "}${String(L).padStart(5)}: ${row.map((t) => render(t, ph)).join(" ")}`);
  }
  const names = [...shown].sort((a, b) => Number(ph.get(a).slice(2)) - Number(ph.get(b).slice(2)));
  for (const n of names) {
    const f = facts.get(n) || {};
    const decl = ["var", "let", "const", "function", "param", "catch"].filter((k) => f[k]).map((k) => `${k}x${f[k]}`);
    out.push(`  ${ph.get(n)}: declared=${decl.length ? decl.join("+") : "no"} bare=${f.bare || 0} member=${f.member || 0} key=${f.key || 0} this-assign=${f.thisAssign || 0}`);
  }
  return out.join("\n") + "\n";
}

/* ------------------------------------------------------------------ */
/* corpus resolution (same cache and zip reader as lint.js)            */
/* ------------------------------------------------------------------ */

function defaultCacheDir() {
  if (process.env.OXP_CACHE_DIR) return process.env.OXP_CACHE_DIR;
  const la = process.env.LOCALAPPDATA;
  if (la) return path.join(la, "OoliteMigration", "oxp-cache");
  return path.join(process.env.HOME || ".", ".cache", "oolite-migration", "oxp-cache");
}

function loadCorpusMember(identifier, suffix) {
  const { zipEntries, readMember, blobPath } = require("./lint");
  const tier3 = JSON.parse(fs.readFileSync(path.join(REPO_ROOT, "tools", "oxp-corpus", "tier3.json"), "utf8"));
  const entry = tier3.entries.find((e) => e.identifier === identifier);
  if (!entry) throw new Error("identifier not in tier3.json");
  const buf = fs.readFileSync(blobPath(defaultCacheDir(), entry.url));
  const members = zipEntries(buf).filter((e) => e.name.toLowerCase().endsWith(".js") && (e.name === suffix || e.name.endsWith("/" + suffix)));
  if (members.length !== 1) throw new Error(`${members.length} .js members match the suffix (need exactly 1)`);
  const bytes = readMember(buf, members[0]);
  const text = bytes.toString("utf8");
  return text.includes("�") ? bytes.toString("latin1") : text;
}

function main(argv) {
  let ctx = 3;
  let doParse = false;
  const args = [];
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === "--context") ctx = parseInt(argv[++i], 10);
    else if (argv[i] === "--parse") doParse = true;
    else args.push(argv[i]);
  }
  if (args[0] === "file" && args.length === 3) {
    const src = fs.readFileSync(args[1], "utf8");
    process.stdout.write(report(src, parseInt(args[2], 10), ctx, path.basename(args[1]), doParse));
    return 0;
  }
  if (args[0] === "corpus" && args.length === 4) {
    const src = loadCorpusMember(args[1], args[2]);
    process.stdout.write(report(src, parseInt(args[3], 10), ctx, `${args[1]} ${args[2]}`, doParse));
    return 0;
  }
  process.stdout.write("usage: node probe.js corpus <identifier> <member-suffix> <line> [--context N] [--parse]\n" +
                       "       node probe.js file <path.js> <line> [--context N] [--parse]\n");
  return 2;
}

if (require.main === module) {
  try {
    process.exitCode = main(process.argv.slice(2));
  } catch (e) {
    // the message is ours (never file content)
    process.stderr.write("probe: " + String(e && e.message ? e.message : e) + "\n");
    process.exitCode = 2;
  }
}

module.exports = { tokenize, analyse, report };
