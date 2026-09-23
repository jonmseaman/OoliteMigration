// tools/refactor/testdata/js-stubs-comment-call.m -- regression fixture
// for js-stubs.sh: a JS_* call-SHAPED mention inside a comment, with real
// looking arguments, must never be rewritten. The bug this guards
// against: a plain text.find()-based call scanner with no comment
// awareness would rewrite the call below in place even though it is
// documentation, not code -- and the one prior in-repo example of this
// (OOJSVector.pre-retarget.m) happened to have empty parens, which
// masked the bug by luck.
//
// See also: JS_ValueToNumber(context, val, &x) -- see docs for the real
// call-site wrapping rules; this line must survive byte-for-byte.

double NotARealCallSite(void)
{
	double x = 0.0;
	return x;
}
