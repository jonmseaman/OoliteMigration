/*
js-stubs-inline-decl-initclass.m -- regression fixture for bead oo-oio
(review round 3).

Minimal shape modeled on the real inline-declaration JS_InitClass call
sites in upstream/oolite/src/Core/Scripting/OOJSClock.m, OOJSMission.m
and OOJSOolite.m: `Type *name = JS_InitClass(...)`, as opposed to the
no-declaration `sVectorPrototype = JS_InitClass(...)` shape covered by
the OOJSVector.pre-retarget.m exemplar fixture (there, the target is
already declared elsewhere as a file-scope static). rewrite_init_class
must preserve the leading `JSObject *` type declaration by hoisting it
to its own statement ahead of the rewritten facade call, not leave it
stranded in front of the rewrite (which used to produce malformed
non-compiling C++ pairing the leading declaration with the facade call
on the same line).
*/

#import "OOJSExample.h"
#import "OOJavaScriptEngine.h"

static JSClass sExampleClass;
static JSPropertySpec sExampleProperties[];
static JSFunctionSpec sExampleMethods[];

void InitOOJSExample(JSContext *context, JSObject *global)
{
	JSObject *examplePrototype = JS_InitClass(context, global, NULL, &sExampleClass, OOJSUnconstructableConstruct, 0, sExampleProperties, sExampleMethods, NULL, NULL);
	JS_DefineObject(context, global, "example", &sExampleClass, examplePrototype, OOJS_PROP_READONLY);
}
