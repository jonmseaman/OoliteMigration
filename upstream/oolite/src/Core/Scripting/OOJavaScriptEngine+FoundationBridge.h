/*

OOJavaScriptEngine+FoundationBridge.h

TRANSITIONAL (proposed ADR-0043, "Transitional bridges"; bead oo-3rb.198, chunk 1 of oo-rbqc).
OOJavaScriptEngine's Foundation-typed API as it was before its sweep, with the same names and
types, forwarding to the cxx_ API in OOJavaScriptEngine.h. Since oo-vp0y.11 only the JS glue for
Foundation objects and the plain-Object Foundation converter remain: Foundation objects still
reach OOJSValueFromNativeObject() and come back from OOJSNativeObjectFromJSValue(). It exists so that the engine's callers
compile unchanged; each caller moves to the cxx_ API in its own sweep bead. The later chunks of
oo-rbqc (oo-3rb.199 .. oo-3rb.203) move their own groups in here. When `git grep` finds no caller
of anything declared here, the bridge bead deletes this file, OOJavaScriptEngine+FoundationBridge.mm,
its line in Core/Scripting/meson.build and the #import at the end of OOJavaScriptEngine.h. Never
call it from migrated code. oo-qps (the removal of gnustep-base) cannot compile while it exists.

Registry: src/oofnd/README.md, "Transitional bridges".

Copyright (C) 2007-2013 David Taylor and Jens Ayton (OOJavaScriptEngine.h)

*/

// Imported only from the end of OOJavaScriptEngine.h (which declares everything used here); never
// import it directly, and never import OOJavaScriptEngine.h from it (a cycle).
#ifndef OOJAVASCRIPTENGINE_FOUNDATIONBRIDGE_H
#define OOJAVASCRIPTENGINE_FOUNDATIONBRIDGE_H


// Retiring category on a Foundation class (ADR-0043 Amendment 1 item 7; bead oo-3rb.199): the JS
// glue for NSString objects, -oo_jsValueInContext: and -oo_jsClassName (declared on NSObject below).
// Its string helpers went with their last callers (oo-vp0y.11); the cxx_OOJS* functions replace them.
@interface NSString (OOJavaScriptExtensions)

@end



// The JS glue on the Foundation root class (retiring with gnustep-base, ADR-0043 Amendment 1
// item 7; moved verbatim by bead oo-3rb.201). OOObject (OOJavaScript) in OOJavaScriptEngine.h
// documents the methods.
@interface NSObject (OOJavaScript)

/*	-oo_jsValueInContext:
	
	Return the JavaScript value representation of an object. The default
	implementation returns ooscript::undefinedValue().
	
	SAFETY NOTE: if this message is sent to nil, the return value depends on
	the platform and the engine's value representation. If the
	receiver may be nil, use OOJSValueFromNativeObject() instead.
	
	One case where it is safe to use oo_jsValueInContext: is with objects
	retrieved from Foundation collections, as they can never be nil.
	
	Requires a request on context.
*/
- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context;

/*	-oo_jsDescription
	-oo_jsDescriptionWithClassName:
	-oo_jsClassName
	
	See comments for -descriptionComponents in OOCocoa.h.
*/
- (NSString *) oo_jsDescription;
- (NSString *) oo_jsDescriptionWithClassName:(NSString *)className;
- (NSString *) oo_jsClassName;

/*	oo_clearJSSelf:
	This is called by OOJSObjectWrapperFinalize() when a JS object wrapper is
	collected. The default implementation does nothing.
*/
- (void) oo_clearJSSelf:(ooscript::Object)selfVal;

@end

#endif	// OOJAVASCRIPTENGINE_FOUNDATIONBRIDGE_H
