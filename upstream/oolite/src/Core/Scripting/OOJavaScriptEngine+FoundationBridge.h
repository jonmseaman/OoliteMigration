/*

OOJavaScriptEngine+FoundationBridge.h

TRANSITIONAL (proposed ADR-0043, "Transitional bridges"; bead oo-3rb.198, chunk 1 of oo-rbqc).
OOJavaScriptEngine's Foundation-typed API as it was before its sweep, with the same names and
types, forwarding to the cxx_ API in OOJavaScriptEngine.h. It exists so that the engine's callers
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


// Convert a JSString to an NSString.
OOJS_EXTERN_C NSString *OOStringFromJSString(ooscript::Context context, ooscript::String string);	// -> cxx_OOStringFromJSString

/*	Convert an arbitrary JS object to an NSString, calling ooscript::valueToString.
	OOStringFromJSValue() returns nil if value is null or undefined,
	OOStringFromJSValueEvenIfNull() returns "null" or "undefined".
*/
OOJS_EXTERN_C NSString *OOStringFromJSValue(ooscript::Context context, ooscript::Value value);	// -> cxx_OOStringFromJSValue
OOJS_EXTERN_C NSString *OOStringFromJSValueEvenIfNull(ooscript::Context context, ooscript::Value value);	// -> cxx_OOStringFromJSValueEvenIfNull

OOJS_EXTERN_C NSString *OOStringFromJSPropertyIDAndSpec(ooscript::Context context, ooscript::PropertyId propID, ooscript::PropertySpec *propertySpec);	// -> cxx_OOStringFromJSPropertyIDAndSpec

// Convert a ooscript::PropertyId to an NSString.
OOJS_EXTERN_C NSString *OOStringFromJSID(ooscript::PropertyId propID);	// -> cxx_OOStringFromJSID

// Convert an NSString to a ooscript::PropertyId.
OOJS_EXTERN_C ooscript::PropertyId OOJSIDFromString(NSString *string);	// -> cxx_OOJSIDFromString

#endif	// OOJAVASCRIPTENGINE_FOUNDATIONBRIDGE_H
