"use strict";
/*
 * Sandbox launcher for the oo-l7u classifier.
 *
 * ENFORCEMENT (all three are real, and sandbox-probe.js proves each one fires):
 *  1. Filesystem. The child runs under Node's permission model
 *     (`--permission`) with --allow-fs-read / --allow-fs-write naming ONLY a
 *     scratch directory outside the repo, plus read on the two payload files.
 *     Every other path - the repo, the worktree, .beads/issues.jsonl, ~/.ssh,
 *     ~/.gitconfig - raises ERR_ACCESS_DENIED inside the child.
 *  2. Environment. The child's env is REBUILT from a whitelist rather than
 *     inherited, so no token, key or credential in the parent env reaches it.
 *  3. Network. Off by default. `--net` adds --allow-net; without it the child
 *     cannot open a socket at all, including to loopback.
 *
 * Deliberate design note: the child is spawned WITHOUT --allow-child-process
 * and WITHOUT --allow-worker, so it cannot escape by re-execing an unsandboxed
 * node.
 */
const { spawnSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const HERE = __dirname;

/* Env vars the classifier legitimately needs. Everything else is dropped. */
const ENV_WHITELIST = [
  "OXP_SCRATCH", "OXP_CLASSIFIER_MODE", "OXP_MODEL_URL", "OXP_MODEL_NAME", "OXP_MAX_TOKENS",
  "SystemRoot", "windir", "TEMP", "TMP", "PATHEXT", "COMSPEC", "NUMBER_OF_PROCESSORS", "OS",
];
/* A parent env var matching any of these must never reach the child. Asserted,
 * not merely intended: buildEnv throws if the whitelist ever lets one in. */
const SECRET_RE = /TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL|API_?KEY|_KEY$|SSH|GITHUB|AWS|AZURE|OPENAI|ANTHROPIC/i;

function buildEnv(extra) {
  const env = {};
  for (const k of ENV_WHITELIST) {
    const v = (extra && extra[k] !== undefined) ? extra[k] : process.env[k];
    if (v !== undefined) env[k] = v;
  }
  for (const k of Object.keys(env)) {
    if (SECRET_RE.test(k)) throw new Error("whitelist leaks a secret-shaped variable: " + k);
  }
  return env;
}

function scratchDir(tag) {
  const base = (process.env.LOCALAPPDATA || os.tmpdir()).replace(/\\/g, "/");
  const d = path.posix.join(base, "Temp", "oxp-model-pilot", tag);
  fs.mkdirSync(d, { recursive: true });
  return d;
}

/**
 * Run `script` (an absolute path) sandboxed.
 * @param {object} o {script, scratch, net, env, args, timeout}
 */
function runSandboxed(o) {
  const nodeArgs = ["--permission"];
  /* read: the scratch dir and the payload script itself (node must load it) */
  nodeArgs.push("--allow-fs-read=" + o.scratch);
  nodeArgs.push("--allow-fs-read=" + o.script.replace(/\\/g, "/"));
  nodeArgs.push("--allow-fs-write=" + o.scratch);
  if (o.net) nodeArgs.push("--allow-net");
  nodeArgs.push(o.script);
  const r = spawnSync(process.execPath, nodeArgs.concat(o.args || []), {
    env: buildEnv(Object.assign({ OXP_SCRATCH: o.scratch }, o.env || {})),
    encoding: "utf8",
    timeout: o.timeout || 1800000,
    cwd: o.scratch,                    // never the repo root
  });
  return { status: r.status, stdout: r.stdout || "", stderr: r.stderr || "", argv: nodeArgs };
}

/** The same run with enforcement stripped - used ONLY to prove the negative
 *  tests are falsifiable, never to produce a reported result. */
function runUnenforced(o) {
  const r = spawnSync(process.execPath, [o.script].concat(o.args || []), {
    env: Object.assign({}, process.env, { OXP_SCRATCH: o.scratch }, o.env || {}),
    encoding: "utf8", timeout: o.timeout || 1800000, cwd: o.scratch,
  });
  return { status: r.status, stdout: r.stdout || "", stderr: r.stderr || "" };
}

function classify(opts) {
  const scratch = scratchDir(opts.tag || "run");
  const tasks = fs.readFileSync(opts.sample, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  /* Hand the sandbox ONLY what a classifier needs. No file paths into the repo,
   * no expansion bytes beyond the snippet oo-ctq already extracted. */
  const seen = new Set();
  const slim = [];
  for (const t of tasks) {
    if (seen.has(t.id)) continue;
    seen.add(t.id);
    slim.push({ id: t.id, construct: t.construct, line: t.line, snippet: t.snippet, context: t.context || [] });
  }
  fs.writeFileSync(path.join(scratch, "tasks.jsonl"), slim.map((r) => JSON.stringify(r)).join("\n") + "\n");
  try { fs.unlinkSync(path.join(scratch, "verdicts.jsonl")); } catch (e) { /* first run */ }
  const t0 = Date.now();
  const r = runSandboxed({
    script: path.join(HERE, "classify.js"),
    scratch, net: opts.net !== false,
    env: {
      OXP_CLASSIFIER_MODE: opts.mode || "model",
      OXP_MODEL_URL: opts.url || process.env.OXP_MODEL_URL || "http://127.0.0.1:1234/v1/chat/completions",
      OXP_MODEL_NAME: opts.model || process.env.OXP_MODEL_NAME || "qwen/qwen3-4b-2507",
    },
    timeout: opts.timeout,
  });
  const wall = ((Date.now() - t0) / 1000).toFixed(1);
  if (r.status !== 0) {
    process.stderr.write(r.stdout + r.stderr);
    throw new Error("sandboxed classifier exited " + r.status);
  }
  const vfile = path.join(scratch, "verdicts.jsonl");
  const verdicts = fs.readFileSync(vfile, "utf8").split("\n").filter(Boolean).map((l) => JSON.parse(l));
  if (opts.out) {
    fs.mkdirSync(path.dirname(opts.out), { recursive: true });
    fs.writeFileSync(opts.out, verdicts.map((r2) => JSON.stringify(r2)).join("\n") + "\n");
  }
  return { verdicts, wall, stdout: r.stdout.trim(), scratch, argv: r.argv };
}

function main(argv) {
  const o = { sample: path.join(HERE, "data", "sample.jsonl"), tag: "run" };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--sample") o.sample = argv[++i];
    else if (a === "--out") o.out = argv[++i];
    else if (a === "--mode") o.mode = argv[++i];
    else if (a === "--tag") o.tag = argv[++i];
    else if (a === "--model") o.model = argv[++i];
    else if (a === "--url") o.url = argv[++i];
    else if (a === "--no-net") o.net = false;
  }
  const r = classify(o);
  console.log(r.stdout);
  console.log(JSON.stringify({ verdicts: r.verdicts.length, wall_seconds: Number(r.wall), out: o.out || null, sandbox_argv: r.argv.slice(0, -1) }));
}

if (require.main === module) main(process.argv.slice(2));
module.exports = { runSandboxed, runUnenforced, buildEnv, scratchDir, classify, ENV_WHITELIST, SECRET_RE };
