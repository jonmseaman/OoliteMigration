"use strict";
/*
 * Negative tests for the oo-l7u sandbox. A policy nobody has watched BLOCK
 * something is decoration, so every check here runs the SAME operation twice:
 *   ENFORCED   - under sandbox.runSandboxed, and must be refused
 *   UNENFORCED - as a plain node child, and must SUCCEED
 * A check passes only if enforcement refuses AND the stripped run succeeds.
 * That makes each test falsifiable: if the refusal were incidental (a missing
 * file, a typo'd path) the unenforced run would fail too and the test goes red.
 *
 * The probe payload is written to the scratch dir at run time so this file
 * stays readable; it is never placed in the repo.
 *
 * Exit 0 = every axis proven. Exit 1 = some axis is decoration.
 */
const fs = require("fs");
const path = require("path");
const os = require("os");
const { runSandboxed, runUnenforced, scratchDir, buildEnv, SECRET_RE } = require("./sandbox");

const REPO = path.resolve(__dirname, "..", "..");
const scratch = scratchDir("probe");

/* In a worktree, .git is a FILE containing "gitdir: <path>", not a directory -
 * and on this host git writes that path in MSYS form (/c/Users/...), which
 * native node resolves against the drive as C:\c\Users\... and cannot find.
 * Resolve BOTH facts, so the git-internals probe targets something that really
 * exists; otherwise the unenforced control fails for the wrong reason (ENOENT)
 * and the axis reads NOT PROVEN when the sandbox is in fact fine. */
function toNative(p) {
  const m = /^\/([A-Za-z])\/(.*)$/.exec(p);
  return m ? `${m[1].toUpperCase()}:/${m[2]}` : p;
}
function resolveGitDir() {
  const dot = path.join(REPO, ".git");
  const st = fs.statSync(dot);
  if (st.isDirectory()) return dot;
  const m = /gitdir:\s*(.+)/.exec(fs.readFileSync(dot, "utf8"));
  if (!m) throw new Error("cannot resolve gitdir from " + dot);
  const g = toNative(m[1].trim());
  const abs = path.isAbsolute(g) ? g : path.resolve(REPO, g);
  fs.statSync(abs);           // fail loudly here rather than as a bogus NOT PROVEN
  return abs;
}

/* Targets. Each is a real, sensitive path on this machine. */
const TARGETS = {
  repo_write: path.join(REPO, "OO_L7U_SANDBOX_ESCAPE.txt").replace(/\\/g, "/"),
  repo_read: path.join(REPO, "CLAUDE.md").replace(/\\/g, "/"),
  beads_append: path.join(REPO, ".beads", "issues.jsonl").replace(/\\/g, "/"),
  git_config: resolveGitDir().replace(/\\/g, "/"),
  ssh_dir: path.join(os.homedir(), ".ssh").replace(/\\/g, "/"),
  gitconfig: path.join(os.homedir(), ".gitconfig").replace(/\\/g, "/"),
};

const PAYLOAD = `
const fs = require("fs");
const http = require("http");
const what = process.argv[2], target = process.argv[3];
function say(v) { console.log("RESULT " + what + " " + v); }
try {
  if (what === "repo_write")        { fs.writeFileSync(target, "escaped"); say("ALLOWED wrote-" + target); }
  else if (what === "repo_read")    { say("ALLOWED read-" + fs.readFileSync(target, "utf8").length + "-bytes"); }
  else if (what === "beads_append") { fs.appendFileSync(target, ""); say("ALLOWED opened-for-append"); }
  else if (what === "git_config")   { say("ALLOWED listed-" + fs.readdirSync(target).length + "-entries"); }
  else if (what === "ssh_dir")      { say("ALLOWED listed-" + fs.readdirSync(target).length + "-entries"); }
  else if (what === "gitconfig")    { say("ALLOWED read-" + fs.readFileSync(target, "utf8").length + "-bytes"); }
  else if (what === "net")          {
    const req = http.get(target, (r) => { say("ALLOWED status-" + r.statusCode); r.resume(); });
    req.on("error", (e) => say("BLOCKED " + e.code + " " + String(e.message).split("\\n")[0]));
    req.setTimeout(15000, () => { req.destroy(); say("BLOCKED ETIMEDOUT"); });
  }
  else if (what === "child_escape") {
    const cp = require("child_process");
    const r = cp.spawnSync(process.execPath, ["-e", "console.log('child-ran')"], { encoding: "utf8" });
    say("ALLOWED child-" + JSON.stringify((r.stdout || "").trim() || ("status" + r.status)));
  }
  else { say("BLOCKED unknown-probe"); }
} catch (e) { say("BLOCKED " + e.code + " " + String(e.message).split("\\n")[0]); }
`;
const payloadFile = path.join(scratch, "probe-payload.js");
fs.writeFileSync(payloadFile, PAYLOAD);

function verdictOf(out) {
  const m = /RESULT \S+ (ALLOWED|BLOCKED)(.*)/.exec(out);
  return m ? { v: m[1], detail: (m[2] || "").trim() } : { v: "NO-RESULT", detail: out.trim().slice(0, 200) };
}

function axis(name, target, opts) {
  const enf = runSandboxed({
    script: payloadFile, scratch, net: !!(opts && opts.net), args: [name, target], timeout: 60000,
  });
  const unenf = runUnenforced({ script: payloadFile, scratch, args: [name, target], timeout: 60000 });
  const e = verdictOf(enf.stdout + enf.stderr);
  const u = verdictOf(unenf.stdout + unenf.stderr);
  /* The unenforced control for repo_write deliberately creates a file in the
   * shared repo to prove the path really is writable. Remove it IMMEDIATELY:
   * a stray file in the repo root blocks acceptance for every bead in the
   * fleet, so the proof must not outlive the assertion that consumes it. */
  let cleaned = null;
  if (opts && opts.cleanup) {
    try { fs.unlinkSync(opts.cleanup); cleaned = "removed"; }
    catch (err) { cleaned = err.code === "ENOENT" ? "absent" : "FAILED-" + err.code; }
  }
  const ok = e.v === "BLOCKED" && u.v === "ALLOWED" && !String(cleaned).startsWith("FAILED");
  console.log(`\n== ${name} -> ${target}`);
  console.log(`   ENFORCED  : ${e.v} ${e.detail}`);
  console.log(`   UNENFORCED: ${u.v} ${u.detail}`);
  if (cleaned !== null) console.log(`   CLEANUP   : control artifact ${cleaned}`);
  console.log(`   ${ok ? "PROVEN" : "NOT PROVEN"}  (enforcement must block AND stripped run must succeed)`);
  return { name, ok, enforced: e, unenforced: u };
}

const results = [];
results.push(axis("repo_write", TARGETS.repo_write, { cleanup: TARGETS.repo_write }));
results.push(axis("repo_read", TARGETS.repo_read));
results.push(axis("beads_append", TARGETS.beads_append));
results.push(axis("git_config", TARGETS.git_config));
results.push(axis("ssh_dir", TARGETS.ssh_dir));
results.push(axis("gitconfig", TARGETS.gitconfig));
/* Network: proven OFF when --allow-net is withheld. The classifier run itself
 * asks for net (the model is a loopback server), so this proves the switch is
 * real rather than claiming the classifier is offline. */
results.push(axis("net", "http://127.0.0.1:1234/v1/models", { net: false }));
/* Escape by re-exec: --allow-child-process is never passed. */
results.push(axis("child_escape", "-", {}));

/* Env scrubbing: assert on the env actually built, and prove the parent has at
 * least one secret-shaped variable so the check is not vacuous. */
const parentSecrets = Object.keys(process.env).filter((k) => SECRET_RE.test(k));
const childEnv = buildEnv({ OXP_SCRATCH: scratch });
const leaked = Object.keys(childEnv).filter((k) => SECRET_RE.test(k));
console.log(`\n== env_scrub`);
console.log(`   parent env secret-shaped vars: ${parentSecrets.length} (${parentSecrets.slice(0, 6).join(",") || "none"})`);
console.log(`   child  env vars: ${Object.keys(childEnv).length} (${Object.keys(childEnv).join(",")})`);
console.log(`   leaked into child: ${leaked.length ? leaked.join(",") : "none"}`);
const envOk = leaked.length === 0 && parentSecrets.length > 0;
console.log(`   ${envOk ? "PROVEN" : "NOT PROVEN"}  (parent must HAVE secrets and child must have none - else the test is vacuous)`);
results.push({ name: "env_scrub", ok: envOk });

/* Nothing may have been created in the repo, whatever any probe did. */
const escaped = fs.existsSync(TARGETS.repo_write);
console.log(`\n== no_artifact_in_repo: ${escaped ? "FAILED - escape file exists" : "PROVEN - no escape artifact"}`);
results.push({ name: "no_artifact_in_repo", ok: !escaped });

const bad = results.filter((r) => !r.ok);
console.log(`\nSANDBOX PROBE: ${results.length - bad.length}/${results.length} axes proven`);
if (bad.length) {
  console.log("NOT PROVEN: " + bad.map((r) => r.name).join(", "));
  process.exit(1);
}
console.log("SANDBOX OK: every axis refused under enforcement and succeeded with enforcement stripped");
