"use strict";
/*
 * ESLint plugin wrapper around the detectors in rules.js.
 *
 * Each detector runs in Program:exit over the raw source text, not over the
 * AST - see the header of rules.js for why (half these constructs make the
 * file unparseable, so an AST rule could never fire on them).
 */

const { DETECTORS, RULE_NAMES, scanText } = require("./rules");

const rules = {};
for (const name of RULE_NAMES) {
  rules[name] = {
    meta: {
      type: "problem",
      docs: { description: DETECTORS[name].description },
      schema: [],
      messages: { mozillaOnly: "{{detail}}" },
    },
    create(context) {
      return {
        "Program:exit"() {
          const src = context.sourceCode || context.getSourceCode();
          for (const f of scanText(src.getText(), [name])) {
            context.report({
              loc: { line: f.line, column: Math.max(0, f.column - 1) },
              messageId: "mozillaOnly",
              data: { detail: f.message },
            });
          }
        },
      };
    },
  };
}

module.exports = {
  meta: { name: "eslint-plugin-mozilla-only", version: "1.0.0" },
  rules,
};
