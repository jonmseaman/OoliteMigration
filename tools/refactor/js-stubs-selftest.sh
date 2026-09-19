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

echo "$OUT" | grep -q "stub_tokens=5 init_class=1 numeric_calls=11" || {
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

echo "js-stubs-selftest: OK"
