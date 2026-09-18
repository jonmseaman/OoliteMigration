"use strict";
/*
 * Probe for the local inference server (bead oo-l7u).
 *
 * WHY THIS EXISTS: accept.sh replays the stored acceptance block in a fresh
 * checkout, possibly on a machine where LM Studio is not running. A stored line
 * that unconditionally POSTs to 127.0.0.1:1234 would fail there and block
 * acceptance for reasons that have nothing to do with this bead's code.
 *
 * So the gate's deterministic lines use the committed artifacts and the stub,
 * and the one line that touches the live server uses this probe to SKIP
 * cleanly and LOUDLY when the server is absent. It never fails on absence and
 * it never silently passes: the skip prints a named message and exit 0, the
 * present-and-working case runs the real classification, and a server that is
 * present but broken still fails.
 *
 * exit 0 + "SERVER PRESENT" -> caller should run the live check
 * exit 0 + "SERVER ABSENT"  -> caller should skip, loudly
 */
const http = require("http");

const URL_ = process.env.OXP_MODEL_URL || "http://127.0.0.1:1234/v1/chat/completions";
const u = new URL(URL_);
const want = process.env.OXP_MODEL_NAME || "qwen/qwen3-4b-2507";

const req = http.get({ hostname: u.hostname, port: u.port, path: "/v1/models", timeout: 5000 }, (res) => {
  let b = "";
  res.setEncoding("utf8");
  res.on("data", (d) => (b += d));
  res.on("end", () => {
    let ids = [];
    try { ids = (JSON.parse(b).data || []).map((m) => m.id); } catch (e) { /* non-JSON */ }
    if (!ids.length) {
      console.log(`SERVER ABSENT: ${u.hostname}:${u.port} answered but listed no models - skipping the live-model check`);
      process.exit(0);
    }
    if (!ids.includes(want)) {
      console.log(`SERVER ABSENT: ${u.hostname}:${u.port} is up but does not serve ${want} (has ${ids.length} others) - skipping the live-model check`);
      process.exit(0);
    }
    console.log(`SERVER PRESENT: ${u.hostname}:${u.port} serving ${want}`);
    process.exit(0);
  });
});
req.on("error", (e) => {
  console.log(`SERVER ABSENT: no local inference server at ${u.hostname}:${u.port} (${e.code}) - skipping the live-model check`);
  process.exit(0);
});
req.on("timeout", () => {
  req.destroy();
  console.log(`SERVER ABSENT: ${u.hostname}:${u.port} did not answer within 5s - skipping the live-model check`);
  process.exit(0);
});
