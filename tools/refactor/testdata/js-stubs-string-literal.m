// tools/refactor/testdata/js-stubs-string-literal.m -- regression fixture
// for js-stubs.sh: a JS_* stub token that appears only INSIDE a string
// literal (e.g. a diagnostic log message) must never be rewritten. The
// bug this guards against: a bare \bTOKEN\b regex with no string-literal
// awareness would turn the message below into
// "Falling back to nullptr behavior", corrupting user-visible text.
#import <Foundation/Foundation.h>

static void LogFallback(void)
{
	OOLog(@"script.warning", @"Falling back to JS_PropertyStub behavior for this class.");
	NSLog(@"resolve hook missing, using JS_ResolveStub as a placeholder");
}
