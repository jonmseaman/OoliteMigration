"use strict";
/*
 * ESLint flat config for the Mozilla-only-JS scan (bead oo-ctq).
 *
 * This file is the SINGLE SOURCE OF TRUTH for which rules are enabled. Both
 * consumers read it:
 *
 *   - `eslint --config tools/oxp-js-lint/eslint.config.js` (when ESLint is
 *     installed), via the plugin in plugin.js;
 *   - `node tools/oxp-js-lint/lint.js` (always; no node_modules, no network),
 *     which reads MOZILLA_ONLY_RULES below and runs exactly those detectors.
 *
 * So deleting a rule here disables it in both paths - which is what the
 * acceptance gate mutates to prove it can fail.
 */

const plugin = require("./plugin");

/** rule name -> ESLint severity. "off" disables the detector everywhere. */
const MOZILLA_ONLY_RULES = {
  "catch-if": "error",
  "e4x": "error",
  "quote-method": "error",
  "to-source": "error",
  "uneval": "error",
  "let-block": "error",
  "legacy-accessor": "error",
  "expression-closure": "error",
  "legacy-generator": "error",
};

/** The names that are actually enabled (severity not "off"/0). */
function enabledRules() {
  return Object.keys(MOZILLA_ONLY_RULES).filter((name) => {
    const sev = MOZILLA_ONLY_RULES[name];
    return sev !== "off" && sev !== 0;
  });
}

const namespaced = {};
for (const [name, sev] of Object.entries(MOZILLA_ONLY_RULES)) {
  namespaced["mozilla-only/" + name] = sev;
}

/** The flat-config array ESLint consumes. */
const config = [
  {
    files: ["**/*.js"],
    languageOptions: {
      ecmaVersion: 2015,
      sourceType: "script",
    },
    plugins: { "mozilla-only": plugin },
    rules: namespaced,
  },
];

module.exports = config;
module.exports.MOZILLA_ONLY_RULES = MOZILLA_ONLY_RULES;
module.exports.enabledRules = enabledRules;
