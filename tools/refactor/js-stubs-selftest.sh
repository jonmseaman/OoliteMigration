#!/usr/bin/env bash
# tools/refactor/js-stubs-selftest.sh -- acceptance check for js-stubs.sh.
#
# Runs js-stubs.sh against a copy of the pre-retarget OOJSVector.m fixture
# (tools/refactor/testdata/OOJSVector.pre-retarget.m, restored from git
# history as of the commit before bead oo-sdz's hand retarget) and checks
# that every JS_PropertyStub/JS_ResolveStub/JS_ConvertStub/JS_EnumerateStub/
# JS_InitClass/JS_NewNumberValue/JS_ValueToNumber/JS_ValueToBoolean call
# site the script targets is gone from the result, i.e. the script produces
# the same call-site rewrite oo-sdz did by hand for this pattern family
# (JS_PropertyStub x2, JS_EnumerateStub x1, JS_ResolveStub x1,
# JS_ConvertStub x1, JS_InitClass x1, JS_ValueToNumber x6,
# JS_NewNumberValue x4 -- 16 call sites, plus the one non-call comment
# mention of JS_ValueToNumber which must be left untouched).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURE="$SCRIPT_DIR/testdata/OOJSVector.pre-retarget.m"

if [ ! -f "$FIXTURE" ]; then
    echo "js-stubs-selftest: missing fixture: $FIXTURE" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cp "$FIXTURE" "$WORK/fixture.m"

if command -v cygpath >/dev/null 2>&1; then
    WORKFILE="$(cygpath -m "$WORK/fixture.m")"
else
    WORKFILE="$WORK/fixture.m"
fi

OUT="$(bash "$SCRIPT_DIR/js-stubs.sh" "$WORKFILE" 2>&1)"
echo "$OUT"

[[ "$OUT" == *"stub_tokens=5 init_class=1 numeric_calls=11"* ]] || {
    echo "js-stubs-selftest: unexpected rewrite counts" >&2
    exit 1
}

# No remaining call sites for the targeted functions (the one comment
# mention of JS_ValueToNumber() is expected to survive, since it is not a
# call site).
remaining="$(grep -nE '\b(JS_PropertyStub|JS_ResolveStub|JS_ConvertStub|JS_EnumerateStub|JS_InitClass|JS_NewNumberValue|JS_ValueToNumber|JS_ValueToBoolean)\s*\([^)]' "$WORK/fixture.m" || true)"
if [ -n "$remaining" ]; then
    echo "js-stubs-selftest: leftover call sites:" >&2
    echo "$remaining" >&2
    exit 1
fi

# Spot-check the JS_InitClass rewrite shape matches the exemplar's façade
# form (two statements: ooscript::initClass(...) then OOJSROBJ assignment).
grep -Fq "Object proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), nullptr, &sVectorClass," "$WORK/fixture.m"
grep -Fq "sVectorPrototype = OOJSROBJ(proto);" "$WORK/fixture.m"

# Spot-check a numeric-conversion rewrite matches the exemplar's façade
# call and argument-wrapping shape.
grep -Fq "ooscript::valueToNumber(OOJSFCX(context), OOJSFVAL(arrayX), &x)" "$WORK/fixture.m"
grep -Fq "return ooscript::newNumberValue(OOJSFCX(context), fValue, OOJSFVALP(value));" "$WORK/fixture.m"

# Regression fixture 1: a JS_* stub token appearing only inside a string
# literal (a log message) must be left byte-for-byte unchanged -- not
# rewritten to nullptr. Guards against a bare \bTOKEN\b regex over raw
# text with no string-literal awareness.
STRLIT_FIXTURE="$SCRIPT_DIR/testdata/js-stubs-string-literal.m"
if [ ! -f "$STRLIT_FIXTURE" ]; then
    echo "js-stubs-selftest: missing fixture: $STRLIT_FIXTURE" >&2
    exit 1
fi
cp "$STRLIT_FIXTURE" "$WORK/strlit.m"
if command -v cygpath >/dev/null 2>&1; then
    STRLIT_WORKFILE="$(cygpath -m "$WORK/strlit.m")"
else
    STRLIT_WORKFILE="$WORK/strlit.m"
fi
STRLIT_OUT="$(bash "$SCRIPT_DIR/js-stubs.sh" "$STRLIT_WORKFILE" 2>&1)"
echo "$STRLIT_OUT"
[[ "$STRLIT_OUT" == *"stub_tokens=0 init_class=0 numeric_calls=0"* ]] || {
    echo "js-stubs-selftest: string-literal fixture was rewritten (should be untouched)" >&2
    exit 1
}
diff -u "$STRLIT_FIXTURE" "$WORK/strlit.m" || {
    echo "js-stubs-selftest: string-literal fixture content changed -- JS_* token inside a string literal was corrupted" >&2
    exit 1
}

# Regression fixture 2: a JS_* call-shaped mention inside a comment, with
# real-looking arguments, must be left byte-for-byte unchanged -- not
# rewritten in place. Guards against a plain text.find()-based call
# scanner with no comment awareness (the prior in-repo example of this,
# OOJSVector.pre-retarget.m's JS_ValueToNumber() comment mention, happened
# to have empty parens, which masked the bug by luck; this fixture uses
# real arguments so it cannot be masked the same way).
COMMENT_FIXTURE="$SCRIPT_DIR/testdata/js-stubs-comment-call.m"
if [ ! -f "$COMMENT_FIXTURE" ]; then
    echo "js-stubs-selftest: missing fixture: $COMMENT_FIXTURE" >&2
    exit 1
fi
cp "$COMMENT_FIXTURE" "$WORK/comment.m"
if command -v cygpath >/dev/null 2>&1; then
    COMMENT_WORKFILE="$(cygpath -m "$WORK/comment.m")"
else
    COMMENT_WORKFILE="$WORK/comment.m"
fi
COMMENT_OUT="$(bash "$SCRIPT_DIR/js-stubs.sh" "$COMMENT_WORKFILE" 2>&1)"
echo "$COMMENT_OUT"
[[ "$COMMENT_OUT" == *"stub_tokens=0 init_class=0 numeric_calls=0"* ]] || {
    echo "js-stubs-selftest: comment-call fixture was rewritten (should be untouched)" >&2
    exit 1
}
diff -u "$COMMENT_FIXTURE" "$WORK/comment.m" || {
    echo "js-stubs-selftest: comment-call fixture content changed -- JS_* call mention inside a comment was rewritten" >&2
    exit 1
}
grep -Fq "JS_ValueToNumber(context, val, &x) -- see docs" "$WORK/comment.m" || {
    echo "js-stubs-selftest: comment-call fixture's comment text no longer matches exactly" >&2
    exit 1
}

# Regression fixture 3: JS_InitClass call site using the real inline-
# declaration form `Type *name = JS_InitClass(...)` (as seen in upstream
# OOJSClock.m/OOJSMission.m/OOJSOolite.m), as opposed to the no-
# declaration form covered by the OOJSVector.pre-retarget.m exemplar
# above. Guards against a regex that only captured the trailing
# assignment-target identifier and left the leading `Type *` fragment
# stranded in front of the rewritten statement (producing malformed
# non-compiling C++ like `JSObject *Object proto = ooscript::initClass(...);`).
INLINE_DECL_FIXTURE="$SCRIPT_DIR/testdata/js-stubs-inline-decl-initclass.m"
if [ ! -f "$INLINE_DECL_FIXTURE" ]; then
    echo "js-stubs-selftest: missing fixture: $INLINE_DECL_FIXTURE" >&2
    exit 1
fi
cp "$INLINE_DECL_FIXTURE" "$WORK/inline-decl.m"
if command -v cygpath >/dev/null 2>&1; then
    INLINE_DECL_WORKFILE="$(cygpath -m "$WORK/inline-decl.m")"
else
    INLINE_DECL_WORKFILE="$WORK/inline-decl.m"
fi
INLINE_DECL_OUT="$(bash "$SCRIPT_DIR/js-stubs.sh" "$INLINE_DECL_WORKFILE" 2>&1)"
echo "$INLINE_DECL_OUT"
[[ "$INLINE_DECL_OUT" == *"stub_tokens=0 init_class=1 numeric_calls=0"* ]] || {
    echo "js-stubs-selftest: unexpected rewrite counts for inline-decl fixture" >&2
    exit 1
}
grep -Fq $'\tJSObject *examplePrototype;' "$WORK/inline-decl.m" || {
    echo "js-stubs-selftest: inline-decl fixture's hoisted declaration statement missing/wrong" >&2
    exit 1
}
grep -Fq $'\tObject proto = ooscript::initClass(OOJSFCX(context), OOJSFOBJ(global), nullptr, &sExampleClass, OOJSUnconstructableConstruct, 0, sExampleProperties, sExampleMethods, NULL, NULL);' "$WORK/inline-decl.m" || {
    echo "js-stubs-selftest: inline-decl fixture's facade call statement missing/wrong" >&2
    exit 1
}
grep -Fq $'\texamplePrototype = OOJSROBJ(proto);' "$WORK/inline-decl.m" || {
    echo "js-stubs-selftest: inline-decl fixture's OOJSROBJ assignment statement missing/wrong" >&2
    exit 1
}
# The type declaration must never end up glued onto the rewritten
# statement (the exact corruption this fixture guards against).
if grep -Fq 'JSObject *Object proto' "$WORK/inline-decl.m"; then
    echo "js-stubs-selftest: inline-decl fixture corrupted -- leading type declaration glued onto rewrite" >&2
    exit 1
fi

echo "js-stubs-selftest: OK"
