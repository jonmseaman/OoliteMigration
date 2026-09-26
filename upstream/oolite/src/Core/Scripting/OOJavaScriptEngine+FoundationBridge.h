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

OOJS_EXTERN_C NSString *OOJSDescribeValue(ooscript::Context context, ooscript::Value value, BOOL abbreviateObjects);	// -> cxx_OOJSDescribeValue


// Error and warning reporters with NSString formats (bead oo-3rb.200) -> the cxx_ reporters, which
// take printf formats; the bridge formats %@ with GNUstep and hands over the finished text.
OOJS_EXTERN_C void OOJSReportError(ooscript::Context context, NSString *format, ...);
OOJS_EXTERN_C void OOJSReportErrorWithArguments(ooscript::Context context, NSString *format, va_list args);
OOJS_EXTERN_C void OOJSReportErrorForCaller(ooscript::Context context, NSString *scriptClass, NSString *function, NSString *format, ...);

OOJS_EXTERN_C void OOJSReportWarning(ooscript::Context context, NSString *format, ...);
OOJS_EXTERN_C void OOJSReportWarningWithArguments(ooscript::Context context, NSString *format, va_list args);
OOJS_EXTERN_C void OOJSReportWarningForCaller(ooscript::Context context, NSString *scriptClass, NSString *function, NSString *format, ...);

OOJS_EXTERN_C void OOJSReportBadArguments(ooscript::Context context, NSString *scriptClass, NSString *function, unsigned argc, ooscript::Value *argv, NSString *message, NSString *expectedArgsDescription);

OOJS_EXTERN_C BOOL OOJSArgumentListGetNumber(ooscript::Context context, NSString *scriptClass, NSString *function, unsigned argc, ooscript::Value *argv, double *outNumber, unsigned *outConsumed);


// Retiring category on a Foundation class (ADR-0043 Amendment 1 item 7; bead oo-3rb.199). The
// three helpers forward to cxx_OOJSStringWithJavaScriptParameters,
// cxx_OOJSConcatenationOfStringsFromJavaScriptValues and cxx_OOJSEscapedForJavaScriptLiteral.
@interface NSString (OOJavaScriptExtensions)

// For diagnostic messages; produces things like @"(42, true, "a string", an object description)".
+ (NSString *) stringWithJavaScriptParameters:(ooscript::Value *)params count:(unsigned)count inContext:(ooscript::Context)context;

// Concatenate sequence of arbitrary JS objects into string.
+ (NSString *) concatenationOfStringsFromJavaScriptValues:(ooscript::Value *)values count:(size_t)count separator:(NSString *)separator inContext:(ooscript::Context)context;

// Add escape codes for string so that it's a valid JavaScript literal (if you put "" or '' around it).
- (NSString *) escapedForJavaScriptLiteral;

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

// The converter for plain JS Objects (bead oo-3rb.202: moved verbatim, orchestrator decision on
// the chunk's STOP). It builds the NSDictionary that OOJSNativeObjectFromJSValue() hands to code
// that still expects Foundation objects, keeping an integer-like property id as an NSNumber key.
// cxx_OOJSDictionaryFromJSObject in OOJavaScriptEngine.h is the oo::PList form; the C++ converter
// and the integer-key question are bead oo-vp0y's.
OOJS_EXTERN_C NSDictionary *OOJSDictionaryFromJSObject(ooscript::Context context, ooscript::Object object);

// Registers OOJSDictionaryFromJSObject as the converter for objectClass (the engine's plain
// Object class); -[OOJavaScriptEngine registerStandardObjectConverters] calls it.
void OOJSRegisterFoundationObjectConverter(ooscript::ClassDef *objectClass);

// Notifications sent when JavaScript engine is reset, for NSNotificationCenter observers (bead
// oo-3rb.203). kOOJavaScriptEngineWillResetNotificationName / ...DidResetNotificationName in
// OOJavaScriptEngine.h are the oo::NotificationCenter names.
extern NSString * const kOOJavaScriptEngineWillResetNotification;
extern NSString * const kOOJavaScriptEngineDidResetNotification;

#endif	// OOJAVASCRIPTENGINE_FOUNDATIONBRIDGE_H
