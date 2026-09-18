"use strict";
/*
 * The sandboxed classifier payload (bead oo-l7u).
 *
 * This file is the ONLY code that talks to the model. It is executed by
 * sandbox.js as a child `node --permission ...` process whose filesystem
 * permissions cover exactly one scratch directory and whose environment has
 * been scrubbed to a whitelist. It therefore has:
 *   - no repo mount   (no --allow-fs-read/write for the repo)
 *   - no secrets      (scrubbed env; no read permission for ~/.ssh, ~/.gitconfig, .git/config)
 *   - network ONLY if sandbox.js was asked for it, and only because the model
 *     server is a loopback process.
 *
 * It reads tasks.jsonl from the scratch dir and writes verdicts.jsonl there.
 * Nothing else is reachable; sandbox-probe.js proves that with negative tests.
 *
 * THE MODEL SEAM: OXP_CLASSIFIER_MODE selects the classifier.
 *   model    - POST to OXP_MODEL_URL (an OpenAI-compatible /v1/chat/completions
 *              endpoint) using model OXP_MODEL_NAME. This is the real path.
 *   constant - always answer "false-positive". This is the VACUITY MUTANT and
 *              exists so the scorer can be proven to reject a classifier that
 *              has learned nothing. It is never reported as a model result.
 */
const fs = require("fs");
const path = require("path");
const http = require("http");

const SCRATCH = process.env.OXP_SCRATCH;
if (!SCRATCH) { console.error("OXP_SCRATCH not set"); process.exit(2); }
const MODE = process.env.OXP_CLASSIFIER_MODE || "model";

const SYSTEM =
  "You are a JavaScript dialect auditor. You are shown one line of JavaScript from an Oolite " +
  "expansion, with a little surrounding context, and the name of a Mozilla-only (SpiderMonkey-only) " +
  "construct that a naive regex matched on that line. Decide whether the construct is REALLY present " +
  "as executable syntax, or whether the regex only matched text inside a comment or a string literal. " +
  "Reference: an expression closure is `function (x) x * x` with NO braces; `function (x) // comment` " +
  "followed by a `{` body is an ordinary function. E4X attribute access is `node.@attr` in code; " +
  "`@param` in a JSDoc comment is not E4X. " +
  "Answer with exactly one word: MOZILLA if the construct is real executable syntax, " +
  "or FALSEPOSITIVE if the match is comment or string text.";

function prompt(t) {
  const ctx = (t.context || []).map((c) => `${c.n === t.line ? ">>" : "  "}${c.n}| ${c.text}`).join("\n");
  return `Construct matched: ${t.construct}\nLine ${t.line}.\n\n${ctx || ">> " + t.snippet}\n\nOne word:`;
}

function callModel(body) {
  const url = new URL(process.env.OXP_MODEL_URL);
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = http.request({
      hostname: url.hostname, port: url.port, path: url.pathname, method: "POST",
      headers: { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(data) },
      timeout: 180000,
    }, (res) => {
      let buf = "";
      res.setEncoding("utf8");
      res.on("data", (d) => (buf += d));
      res.on("end", () => {
        try { resolve(JSON.parse(buf)); } catch (e) { reject(new Error("bad JSON from model: " + buf.slice(0, 200))); }
      });
    });
    req.on("error", reject);
    req.on("timeout", () => req.destroy(new Error("model timeout")));
    req.end(data);
  });
}

function parseAnswer(text) {
  const up = String(text || "").toUpperCase();
  // the answer may be preceded by <think>...</think> on reasoning models; take the LAST decisive token
  const hits = up.match(/FALSE\s*-?\s*POSITIVE|FALSEPOSITIVE|MOZILLA/g);
  if (!hits || !hits.length) return null;
  const last = hits[hits.length - 1];
  return last.startsWith("MOZ") ? "mozilla" : "false-positive";
}

async function main() {
  const tasks = fs.readFileSync(path.join(SCRATCH, "tasks.jsonl"), "utf8")
    .split("\n").filter(Boolean).map((l) => JSON.parse(l));
  const out = [];
  for (const t of tasks) {
    let verdict = null, raw = "";
    if (MODE === "constant") {
      verdict = "false-positive"; raw = "[constant stub: always false-positive]";
    } else if (MODE === "model") {
      const r = await callModel({
        model: process.env.OXP_MODEL_NAME,
        messages: [{ role: "system", content: SYSTEM }, { role: "user", content: prompt(t) }],
        temperature: 0, max_tokens: Number(process.env.OXP_MAX_TOKENS || 2048),
      });
      raw = (((r.choices || [])[0] || {}).message || {}).content || "";
      verdict = parseAnswer(raw);
    } else {
      throw new Error("unknown OXP_CLASSIFIER_MODE: " + MODE);
    }
    out.push({ id: t.id, verdict, mode: MODE, raw: String(raw).slice(-300) });
  }
  fs.writeFileSync(path.join(SCRATCH, "verdicts.jsonl"), out.map((r) => JSON.stringify(r)).join("\n") + "\n");
  console.log(JSON.stringify({ classified: out.length, mode: MODE, unparsed: out.filter((r) => !r.verdict).length }));
}
main().catch((e) => { console.error("classifier failed: " + e.message); process.exit(1); });
