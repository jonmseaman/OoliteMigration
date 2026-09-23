/*

OOPListSchemaVerifier.m


Copyright (C) 2007-2013 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED ìAS ISî, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

#import "OOPListSchemaVerifier.h"
#import <objc/runtime.h>
#import <objc/objc-arc.h>

#if OO_OXP_VERIFIER_ENABLED

#import "OOLoggingExtended.h"
#import "OOPListView.h"
#import "OOMaths.h"
#import "OOFoundationBridge.h"
#include "oofnd/String.hpp"
#include <limits.h>


#define PLIST_VERIFIER_DEBUG_DUMP_ENABLED		1


enum
{
	// Largest allowable number of characters for string included in error message.
	kMaximumLengthForStringInErrorMessage		= 100
};


// Internal error codes.
enum
{
	kStartOfPrivateErrorCodes = kPListErrorLastErrorCode,
	
	kPListErrorFailedAndErrorHasBeenReported
};


#if PLIST_VERIFIER_DEBUG_DUMP_ENABLED
static BOOL				sDebugDump = NO;

#define DebugDumpIndent()		do { if (sDebugDump) OOLogIndent(); } while (0)
#define DebugDumpOutdent()		do { if (sDebugDump) OOLogOutdent(); } while (0)
#define DebugDumpPushIndent()	do { if (sDebugDump) OOLogPushIndent(); } while (0)
#define DebugDumpPopIndent()	do { if (sDebugDump) OOLogPopIndent(); } while (0)
#define DebugDump(...)			do { if (sDebugDump) OOLog(@"verifyOXP.verbose.plistDebugDump", __VA_ARGS__); } while (0)
#else
#define DebugDumpIndent()		do { } while (0)
#define DebugDumpOutdent()		do { } while (0)
#define DebugDumpPushIndent()	do { } while (0)
#define DebugDumpPopIndent()	do { } while (0)
#define DebugDump(...)			do { } while (0)
#endif


const char * const kOOPListSchemaVerifierErrorDomain = "org.aegidian.oolite.OOPListSchemaVerifier.ErrorDomain";

const char * const kPListKeyPathErrorKey = "org.aegidian.oolite.OOPListSchemaVerifier plist key path";
const char * const kSchemaKeyPathErrorKey = "org.aegidian.oolite.OOPListSchemaVerifier schema key path";

const char * const kExpectedClassErrorKey = "org.aegidian.oolite.OOPListSchemaVerifier expected class";
const char * const kExpectedClassNameErrorKey = "org.aegidian.oolite.OOPListSchemaVerifier expected class name";
const char * const kUnknownKeyErrorKey = "org.aegidian.oolite.OOPListSchemaVerifier unknown key";
const char * const kMissingRequiredKeysErrorKey = "org.aegidian.oolite.OOPListSchemaVerifier missing required keys";
const char * const kMissingSubStringErrorKey = "org.aegidian.oolite.OOPListSchemaVerifier missing substring";
const char * const kUnnownFilterErrorKey = "org.aegidian.oolite.OOPListSchemaVerifier unknown filter";
const char * const kErrorsByOptionErrorKey = "org.aegidian.oolite.OOPListSchemaVerifier errors by option";

const char * const kUnknownTypeErrorKey = "org.aegidian.oolite.OOPListSchemaVerifier unknown type";
const char * const kUndefinedMacroErrorKey = "org.aegidian.oolite.OOPListSchemaVerifier undefined macro";


typedef enum
{
	kTypeUnknown,
	kTypeString,
	kTypeArray,
	kTypeDictionary,
	kTypeInteger,
	kTypePositiveInteger,
	kTypeFloat,
	kTypePositiveFloat,
	kTypeOneOf,
	kTypeEnumeration,
	kTypeBoolean,
	kTypeFuzzyBoolean,
	kTypeVector,
	kTypeQuaternion,
	kTypeDelegatedType
} SchemaType;


typedef struct BackLinkChain BackLinkChain;
struct BackLinkChain
{
	BackLinkChain			*link;
	const std::string		*key;		// a dictionary key (the caller keeps it alive), or
	NSUInteger				index;		// an array index when isIndex; neither for the root
	bool					isIndex;
};

namespace {

OOINLINE BackLinkChain BackLink(BackLinkChain *link, const std::string *key)
{
	BackLinkChain result = { link, key, 0, false };
	return result;
}

OOINLINE BackLinkChain BackLinkIndex(BackLinkChain *link, NSUInteger index)
{
	BackLinkChain result = { link, nullptr, index, true };
	return result;
}

OOINLINE BackLinkChain BackLinkRoot(void)
{
	BackLinkChain result = { NULL, nullptr, 0, false };
	return result;
}

} // namespace


static SchemaType StringToSchemaType(NSString *string, NSError **outError);
static NSString *ApplyStringFilter(NSString *string, id filterSpec, BackLinkChain keyPath, NSError **outError);
static BOOL ApplyStringTest(NSString *string, id test, SEL testSelector, NSString *testDescription, BackLinkChain keyPath, NSError **outError);
namespace {

oo::PList KeyPathToArray(BackLinkChain keyPath);
std::string KeyPathToString(BackLinkChain keyPath);

} // namespace

static NSString *StringForErrorReport(NSString *string);
static NSString *ArrayForErrorReport(NSArray *array);
static NSString *SetForErrorReport(NSSet *set);
static NSString *StringOrArrayForErrorReport(id value, NSString *arrayPrefix);

namespace {

// The formats are printf formats (oo::str::vformat); an object's text is %s of oo::DescriptionOf(x).
NSError *Error(OOPListSchemaVerifierErrorCode errorCode, BackLinkChain *keyPath, const char *format, ...);
NSError *ErrorWithProperty(OOPListSchemaVerifierErrorCode errorCode, BackLinkChain *keyPath, const std::string &propKey, const oo::PList &propValue, const char *format, ...);
NSError *ErrorWithDictionary(OOPListSchemaVerifierErrorCode errorCode, BackLinkChain *keyPath, const oo::PList &dict, const char *format, ...);
NSError *ErrorWithDictionaryAndArguments(OOPListSchemaVerifierErrorCode errorCode, BackLinkChain *keyPath, const oo::PList &dict, const char *format, va_list arguments);

NSError *ErrorTypeMismatch(Class expectedClass, const char *expectedClassName, id actualObject, BackLinkChain keyPath);
NSError *ErrorFailureAlreadyReported(void);
BOOL IsFailureAlreadyReportedError(NSError *error);

} // namespace


@interface OOPListSchemaVerifier (OOPrivate)

// Call delegate methods.
- (BOOL)delegateVerifierWithPropertyList:(id)rootPList
								   named:(NSString *)name
							testProperty:(id)subPList
								  atPath:(BackLinkChain)keyPath
							 againstType:(NSString *)typeKey
								   error:(NSError **)outError;

- (BOOL)delegateVerifierWithPropertyList:(id)rootPList
								   named:(NSString *)name
					   failedForProperty:(id)subPList
							   withError:(NSError *)error
							expectedType:(NSDictionary *)localSchema;

- (BOOL)verifyPList:(id)rootPList
			  named:(NSString *)name
		subProperty:(id)subProperty
  againstSchemaType:(id)subSchema
			 atPath:(BackLinkChain)keyPath
		  tentative:(BOOL)tentative
			  error:(NSError **)outError
			   stop:(BOOL *)outStop;

- (NSDictionary *)resolveSchemaType:(id)specifier
							 atPath:(BackLinkChain)keyPath
							  error:(NSError **)outError;

@end


@interface NSString (OOPListSchemaVerifierHelpers)

- (BOOL)ooPListVerifierHasSubString:(NSString *)string;

@end


#define VERIFY_PROTO(T) static NSError *Verify_##T(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
VERIFY_PROTO(String);
VERIFY_PROTO(Array);
VERIFY_PROTO(Dictionary);
VERIFY_PROTO(Integer);
VERIFY_PROTO(PositiveInteger);
VERIFY_PROTO(Float);
VERIFY_PROTO(PositiveFloat);
VERIFY_PROTO(OneOf);
VERIFY_PROTO(Enumeration);
VERIFY_PROTO(Boolean);
VERIFY_PROTO(FuzzyBoolean);
VERIFY_PROTO(Vector);
VERIFY_PROTO(Quaternion);
VERIFY_PROTO(DelegatedType);


@implementation OOPListSchemaVerifier

+ (id)verifierWithSchema:(NSDictionary *)schema
{
	return [[[self alloc] initWithSchema:schema] autorelease];
}


- (id)initWithSchema:(NSDictionary *)schema
{
	self = [super init];
	if (self != nil)
	{
		_schema = [schema retain];
		_definitions = [oo::PListView(_schema).get<NSDictionary *>(@"$definitions") retain];
		sDebugDump = [[NSUserDefaults standardUserDefaults] boolForKey:@"plist-schema-verifier-dump-structure"];
		if (sDebugDump)  OOLogSetDisplayMessagesInClass(@"verifyOXP.verbose.plistDebugDump", YES);
		
		if (_schema == nil)
		{
			[self release];
			self = nil;
		}
	}
	
	return self;
}


- (void)dealloc
{
	[_schema release];
	[_definitions release];
	
	[super dealloc];
}


- (void)setDelegate:(id)delegate
{
	if (_delegate != delegate)
	{
		_delegate = delegate;
		_badDelegateWarning = NO;
	}
}


- (id)delegate
{
	return _delegate;
}


- (BOOL)verifyPropertyList:(id)plist named:(NSString *)name
{
	BOOL						OK;
	BOOL						stop = NO;
	
	OK = [self verifyPList:plist
					 named:name
			   subProperty:plist
		 againstSchemaType:_schema
					atPath:BackLinkRoot()
				 tentative:NO
					 error:NULL
					  stop:&stop];
	
	return OK;
}


+ (std::optional<std::string>)descriptionForKeyPath:(const oo::PList &)keyPath
{
	std::string					result;
	BOOL						first = YES;

	if (const oo::PList::Array *components = keyPath.getIf<oo::PList::Array>())
	{
		for (const oo::PList &component : *components)
		{
			if (component.isNumber())
			{
				result += "[" + oo::plist_get::numberStringValue(component) + "]";	// as %@ printed the number
			}
			else if (const std::string *string = component.getIf<std::string>())
			{
				if (!first)  result += ".";
				result += *string;
			}
			else  return std::nullopt;
			first = NO;
		}
	}

	if (first)
	{
		// Empty path
		return std::string("root");
	}

	return result;
}

@end


@implementation OOPListSchemaVerifier (OOPrivate)

- (BOOL)delegateVerifierWithPropertyList:(id)rootPList
								   named:(NSString *)name
							testProperty:(id)subPList
								  atPath:(BackLinkChain)keyPath
							 againstType:(NSString *)typeKey
								   error:(NSError **)outError
{
	BOOL					result;
	NSError					*error = nil;
	
	if ([_delegate respondsToSelector:@selector(verifier:withPropertyList:named:testProperty:atPath:againstType:error:)])
	{
		@try
		{
			result = [_delegate verifier:self
						withPropertyList:rootPList
								   named:name
							testProperty:subPList
								  atPath:oo::ObjectFromPList(KeyPathToArray(keyPath))
							 againstType:typeKey
								   error:&error];
		}
		@catch (NSException *exception)
		{
			OOLog(@"plistVerifier.delegateException", @"Property list schema verifier: delegate threw exception (%@) in -verifier:withPropertyList:named:testProperty:atPath:againstType: for type \"%@\" at %@ in %@ -- treating as failure.", [exception name], typeKey,oo::NSStringFrom(KeyPathToString(keyPath)), name);
			result = NO;
			error = nil;
		}
		
		if (outError != NULL)
		{
			if (!result || error != nil)
			{
				// Note: Generates an error if delegate returned NO (meaning stop) or if delegate produced an error but did not request a stop.
				*outError = ErrorWithProperty(kPListDelegatedTypeError, &keyPath, oo::StdString(NSUnderlyingErrorKey), oo::PListFrom(error), "Value at %s does not match delegated type \"%s\".", KeyPathToString(keyPath).c_str(), oo::DescriptionOf(typeKey).c_str());
			}
			else *outError = nil;
		}
	}
	else
	{
		if (!_badDelegateWarning)
		{
			OOLog(@"plistVerifier.badDelegate", @"%@", @"Property list schema verifier: delegate does not handle delegated types.");
			_badDelegateWarning = YES;
		}
		result = YES;
	}
	
	return result;
}


- (BOOL)delegateVerifierWithPropertyList:(id)rootPList
								   named:(NSString *)name
					   failedForProperty:(id)subPList
							   withError:(NSError *)error
							expectedType:(NSDictionary *)localSchema
{
	BOOL					result;
	
	if ([_delegate respondsToSelector:@selector(verifier:withPropertyList:named:failedForProperty:withError:expectedType:)])
	{
		@try
		{
			result = [_delegate verifier:self
						withPropertyList:rootPList
								   named:name
					   failedForProperty:subPList
							   withError:error
							expectedType:localSchema];
		}
		@catch (NSException *exception)
		{
			OOLog(@"plistVerifier.delegateException", @"Property list schema verifier: delegate threw exception (%@) in -verifier:withPropertyList:named:failedForProperty:atPath:expectedType: at %@ in %@ -- stopping.", [exception name], [error plistKeyPathDescription], name);
			result = NO;
		}
	}
	else
	{
		OOLog(@"plistVerifier.failed", @"Verification of property list \"%@\" failed at %@: %@", name, [error plistKeyPathDescription], [error localizedFailureReason]);
		result = NO;
	}
	return result;
}


- (BOOL)verifyPList:(id)rootPList
			  named:(NSString *)name
		subProperty:(id)subProperty
  againstSchemaType:(id)subSchema
			 atPath:(BackLinkChain)keyPath
		  tentative:(BOOL)tentative
			  error:(NSError **)outError
			   stop:(BOOL *)outStop
{
	SchemaType				type = kTypeUnknown;
	NSError					*error = nil;
	NSDictionary			*resolvedSpecifier = nil;
	void					*pool = NULL;
	
	assert(outStop != NULL);
	
	pool = objc_autoreleasePoolPush();
	
	DebugDumpPushIndent();
	
	@try
	{
		DebugDumpIndent();
		
		resolvedSpecifier = [self resolveSchemaType:subSchema atPath:keyPath error:&error];
		if (resolvedSpecifier != nil)  type = StringToSchemaType([resolvedSpecifier objectForKey:@"type"], &error);
		
		#define VERIFY_CASE(T) case kType##T: error = Verify_##T(self, subProperty, resolvedSpecifier, rootPList, name, keyPath, tentative, outStop); break;
		
		switch (type)
		{
			VERIFY_CASE(String);
			VERIFY_CASE(Array);
			VERIFY_CASE(Dictionary);
			VERIFY_CASE(Integer);
			VERIFY_CASE(PositiveInteger);
			VERIFY_CASE(Float);
			VERIFY_CASE(PositiveFloat);
			VERIFY_CASE(OneOf);
			VERIFY_CASE(Enumeration);
			VERIFY_CASE(Boolean);
			VERIFY_CASE(FuzzyBoolean);
			VERIFY_CASE(Vector);
			VERIFY_CASE(Quaternion);
			VERIFY_CASE(DelegatedType);
			
			case kTypeUnknown:
				// resolveSchemaType:... or StringToSchemaType() should have provided an error.
				*outStop = YES;
		}
	}
	@catch (NSException *exception)
	{
		error = Error(kPListErrorInternal, (BackLinkChain *)&keyPath, "Uncaught exception %s: %s in plist verifier for \"%s\" at %s.", oo::DescriptionOf([exception name]).c_str(), oo::DescriptionOf([exception reason]).c_str(), oo::DescriptionOf(name).c_str(), KeyPathToString(keyPath).c_str());
	}
	
	DebugDumpPopIndent();
	
	if (error != nil)
	{
		if (!tentative && !IsFailureAlreadyReportedError(error))
		{
			*outStop = ![self delegateVerifierWithPropertyList:rootPList
														 named:name
											 failedForProperty:subProperty
													 withError:error
												  expectedType:subSchema];
		}
		else if (tentative)  *outStop = YES;
	}
	
	if (outError != NULL && error != nil)
	{
		*outError = [error retain];
		objc_autoreleasePoolPop(pool);
		[error autorelease];
	}
	else
	{
		objc_autoreleasePoolPop(pool);
	}
	
	return error == nil;
}


- (NSDictionary *)resolveSchemaType:(id)specifier
							 atPath:(BackLinkChain)keyPath
							  error:(NSError **)outError
{
	id						typeVal = nil;
	NSString				*complaint = nil;
	
	assert(outError != NULL);
	
	if (![specifier isKindOfClass:[NSString class]] && ![specifier isKindOfClass:[NSDictionary class]])  goto BAD_TYPE;
	
	for (;;)
	{
		if ([specifier isKindOfClass:[NSString class]])  specifier = [NSDictionary dictionaryWithObject:specifier forKey:@"type"];
		typeVal = [(NSDictionary *)specifier objectForKey:@"type"];
		
		if ([typeVal isKindOfClass:[NSString class]])
		{
			if ([typeVal hasPrefix:@"$"])
			{
				// Macro reference; look it up in $definitions
				specifier = [_definitions objectForKey:typeVal];
				if (specifier == nil)
				{
					*outError = ErrorWithProperty(kPListErrorSchemaUndefiniedMacroReference, &keyPath, kUndefinedMacroErrorKey, oo::PListFrom(typeVal), "Bad schema: reference to undefined macro \"%s\".", oo::DescriptionOf(StringForErrorReport(typeVal)).c_str());
					return nil;
				}
			}
			else
			{
				// Non-macro string
				return specifier;
			}
		}
		else if ([typeVal isKindOfClass:[NSDictionary class]])
		{
			specifier = typeVal;	
		}
		else
		{
			goto BAD_TYPE;
		}
	}
	
BAD_TYPE:
	// Error: bad type
	if (typeVal == nil)  complaint = @"no type specified";
	else  complaint = @"not string or dictionary";
				
	*outError = Error(kPListErrorSchemaBadTypeSpecifier, &keyPath, "Bad schema: invalid type specifier for path %s (%s).", KeyPathToString(keyPath).c_str(), oo::DescriptionOf(complaint).c_str());
	return nil;
}

@end


static SchemaType StringToSchemaType(NSString *string, NSError **outError)
{
	static NSDictionary			*typeMap = nil;
	SchemaType					result;
	
	if (typeMap == nil)
	{
		typeMap =
			[[NSDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithUnsignedInt:kTypeString],			@"string",
				[NSNumber numberWithUnsignedInt:kTypeArray],			@"array",
				[NSNumber numberWithUnsignedInt:kTypeDictionary],		@"dictionary",
				[NSNumber numberWithUnsignedInt:kTypeInteger],			@"integer",
				[NSNumber numberWithUnsignedInt:kTypePositiveInteger],	@"positiveInteger",
				[NSNumber numberWithUnsignedInt:kTypeFloat],			@"float",
				[NSNumber numberWithUnsignedInt:kTypePositiveFloat],	@"positiveFloat",
				[NSNumber numberWithUnsignedInt:kTypeOneOf],			@"oneOf",
				[NSNumber numberWithUnsignedInt:kTypeEnumeration],		@"enumeration",
				[NSNumber numberWithUnsignedInt:kTypeBoolean],			@"boolean",
				[NSNumber numberWithUnsignedInt:kTypeFuzzyBoolean],		@"fuzzyBoolean",
				[NSNumber numberWithUnsignedInt:kTypeVector],			@"vector",
				[NSNumber numberWithUnsignedInt:kTypeQuaternion],		@"quaternion",
				[NSNumber numberWithUnsignedInt:kTypeDelegatedType],	@"delegatedType",
				nil
			 ] retain];
	}
	
	result = (SchemaType)[[typeMap objectForKey:string] unsignedIntValue];
	if (result == kTypeUnknown && outError != NULL)
	{
		if ([string hasPrefix:@"$"])
		{
			*outError = ErrorWithProperty(kPListErrorSchemaUnknownType, NULL, kUnknownTypeErrorKey, oo::PListFrom(string), "Bad schema: unresolved macro reference \"%s\".", oo::DescriptionOf(string).c_str());
		}
		else
		{
			*outError = ErrorWithProperty(kPListErrorSchemaUnknownType, NULL, kUnknownTypeErrorKey, oo::PListFrom(string), "Bad schema: unknown type \"%s\".", oo::DescriptionOf(string).c_str());
		}
	}
	
	return result;
}


static NSString *ApplyStringFilter(NSString *string, id filterSpec, BackLinkChain keyPath, NSError **outError)
{
	NSEnumerator			*filterEnum = nil;
	id						filter = nil;
	NSRange					range;
	
	assert(outError != NULL);
	
	if (filterSpec == nil)  return string;
	
	if ([filterSpec isKindOfClass:[NSString class]])
	{
		filterSpec = [NSArray arrayWithObject:filterSpec];
	}
	if ([filterSpec isKindOfClass:[NSArray class]])
	{
		for (filterEnum = [filterSpec objectEnumerator]; (filter = [filterEnum nextObject]); )
		{
			if ([filter isKindOfClass:[NSString class]])
			{
				if ([filter isEqual:@"lowerCase"])  string = [string lowercaseString];
				else if ([filter isEqual:@"upperCase"])  string = [string uppercaseString];
				else if ([filter isEqual:@"capitalized"])  string = [string capitalizedString];
				else if ([filter hasPrefix:@"truncFront:"])
				{
					string = [string substringToIndex:[[filter substringFromIndex:11] intValue]];
				}
				else if ([filter hasPrefix:@"truncBack:"])
				{
					string = [string substringToIndex:[[filter substringFromIndex:10] intValue]];
				}
				else if ([filter hasPrefix:@"subStringTo:"])
				{
					range = [string rangeOfString:[filter substringFromIndex:12]];
					if (range.location != NSNotFound)
					{
						string = [string substringToIndex:range.location];
					}
				}
				else if ([filter hasPrefix:@"subStringFrom:"])
				{
					range = [string rangeOfString:[filter substringFromIndex:14]];
					if (range.location != NSNotFound)
					{
						string = [string substringFromIndex:range.location + range.length];
					}
				}
				else if ([filter hasPrefix:@"subStringToInclusive:"])
				{
					range = [string rangeOfString:[filter substringFromIndex:21]];
					if (range.location != NSNotFound)
					{
						string = [string substringToIndex:range.location + range.length];
					}
				}
				else if ([filter hasPrefix:@"subStringFromInclusive:"])
				{
					range = [string rangeOfString:[filter substringFromIndex:23]];
					if (range.location != NSNotFound)
					{
						string = [string substringFromIndex:range.location];
					}
				}
				else
				{
					*outError = ErrorWithProperty(kPListErrorSchemaUnknownFilter, &keyPath, kUnnownFilterErrorKey, oo::PListFrom(filter), "Bad schema: unknown string filter specifier \"%s\".", oo::DescriptionOf(filter).c_str());
				}
			}
			else
			{
				*outError = Error(kPListErrorSchemaUnknownFilter, &keyPath, "Bad schema: filter specifier is not a string.");
			}
		}
	}
	else
	{
		*outError = Error(kPListErrorSchemaUnknownFilter, &keyPath, "Bad schema: \"filter\" must be a string or an array.");
	}
	
	return string;
}


static BOOL ApplyStringTest(NSString *string, id test, SEL testSelector, NSString *testDescription, BackLinkChain keyPath, NSError **outError)
{
	BOOL					(*testIMP)(id, SEL, NSString *);
	NSEnumerator			*testEnum = nil;
	id						subTest = nil;
	
	assert(outError != NULL);
	
	if (test == nil)  return YES;
	
	testIMP = (BOOL(*)(id, SEL, NSString *))[string methodForSelector:testSelector];
	if (testIMP == NULL)
	{
		*outError = Error(kPListErrorInternal, &keyPath, "OOPListSchemaVerifier internal error: NSString does not respond to test selector %s.", oo::DescriptionOf(NSStringFromSelector(testSelector)).c_str());
		return NO;
	}
	
	if ([test isKindOfClass:[NSString class]])
	{
		test = [NSArray arrayWithObject:test];
	}
	
	if ([test isKindOfClass:[NSArray class]])
	{
		for (testEnum = [test objectEnumerator]; (subTest = [testEnum nextObject]); )
		{
			if ([subTest isKindOfClass:[NSString class]])
			{
				if (testIMP(string, testSelector, subTest))  return YES;
			}
			else
			{
				*outError = Error(kPListErrorSchemaBadComparator, &keyPath, "Bad schema: required %s is not a string.", oo::DescriptionOf(testDescription).c_str());
				return NO;
			}
		}
	}
	else
	{
		*outError = Error(kPListErrorSchemaBadComparator, &keyPath, "Bad schema: %s requirement specification is not a string or array.", oo::DescriptionOf(testDescription).c_str());
	}
	return NO;
}


namespace {

oo::PList KeyPathToArray(BackLinkChain keyPath)
{
	oo::PList::Array		result;
	BackLinkChain			*curr = NULL;

	for (curr = &keyPath; curr != NULL; curr = curr->link)
	{
		// Keys as strings, indices as signed integers (+numberWithInteger:).
		if (curr->key != nullptr)  result.insert(result.begin(), oo::PList(*curr->key));
		else if (curr->isIndex)  result.insert(result.begin(), oo::PList(static_cast<std::int64_t>(curr->index)));
	}

	return oo::PList(std::move(result));
}


std::string KeyPathToString(BackLinkChain keyPath)
{
	return [OOPListSchemaVerifier descriptionForKeyPath:KeyPathToArray(keyPath)].value_or("(null)");	// %@ of nil
}

} // namespace


static NSString *StringForErrorReport(NSString *string)
{
	id						result = nil;
	
	if (kMaximumLengthForStringInErrorMessage < [string length])
	{
		string = [string substringToIndex:kMaximumLengthForStringInErrorMessage];
	}
	result = [NSMutableString stringWithString:string];
	[result replaceOccurrencesOfString:@"\t" withString:@"    " options:0 range:NSMakeRange(0, [string length])];
	[result replaceOccurrencesOfString:@"\r\n" withString:@" \\ " options:0 range:NSMakeRange(0, [string length])];
	[result replaceOccurrencesOfString:@"\n" withString:@" \\ " options:0 range:NSMakeRange(0, [string length])];
	[result replaceOccurrencesOfString:@"\r" withString:@" \\ " options:0 range:NSMakeRange(0, [string length])];
	
	if (kMaximumLengthForStringInErrorMessage < [result length])
	{
		result = [result substringToIndex:kMaximumLengthForStringInErrorMessage - 3];
		result = [result stringByAppendingString:@"..."];
	}
	
	return result;
}


static NSString *ArrayForErrorReport(NSArray *array)
{
	NSString				*result = nil;
	NSString				*string = nil;
	NSUInteger				i, count;
	
	count = [array count];
	if (count == 0)  return @"( )";
	
	@autoreleasepool
	{
		result = [NSString stringWithFormat:@"(%@", [array objectAtIndex:0]];
		
		for (i = 1; i != count; ++i)
		{
			string = [result stringByAppendingFormat:@", %@", [array objectAtIndex:i]];
			if (kMaximumLengthForStringInErrorMessage < [string length])
			{
				result = [result stringByAppendingString:@", ..."];
				break;
			}
			result = string;
		}
		
		result = [result stringByAppendingString:@")"];
		
		[result retain];
	}
	return [result autorelease];
}


static NSString *SetForErrorReport(NSSet *set)
{
	return ArrayForErrorReport([[set allObjects] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]);
}


static NSString *StringOrArrayForErrorReport(id value, NSString *arrayPrefix)
{
	if ([value isKindOfClass:[NSString class]])
	{
		return [NSString stringWithFormat:@"\"%@\"", StringForErrorReport(value)];
	}
	
	if (arrayPrefix == nil)  arrayPrefix = @"";
	if ([value isKindOfClass:[NSArray class]])
	{
		return [arrayPrefix stringByAppendingString:ArrayForErrorReport(value)];
	}
	if ([value isKindOfClass:[NSSet class]])
	{
		return [arrayPrefix stringByAppendingString:SetForErrorReport(value)];
	}
	if (value == nil)  return @"(null)";
	return @"<?>";
}


// Specific type verifiers

#define REQUIRE_TYPE(CLASSNAME, NAMESTRING)	 do { \
		if (![value isKindOfClass:[CLASSNAME class]]) \
		{ \
			return ErrorTypeMismatch([CLASSNAME class], NAMESTRING, value, keyPath); \
		} \
	} while (0)

static NSError *Verify_String(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	NSString			*filteredString = nil;
	id					testValue = nil;
	NSUInteger			length;
	NSUInteger			lengthConstraint;
	NSError				*error = nil;
	
	REQUIRE_TYPE(NSString, "string");
	
	DebugDump(@"* string: \"%@\"", StringForErrorReport(value));
	
	// Apply filters
	filteredString = ApplyStringFilter(value, [params objectForKey:@"filter"], keyPath, &error);
	if (filteredString == nil)  return error;
	
	// Apply substring requirements
	testValue = [params objectForKey:@"requiredPrefix"];
	if (testValue != nil)
	{
		if (!ApplyStringTest(filteredString, testValue, @selector(hasPrefix:), @"prefix", keyPath, &error))
		{
			if (error == nil)  error = ErrorWithProperty(kPListErrorStringPrefixMissing, &keyPath, kMissingSubStringErrorKey, oo::PListFrom(testValue), "String \"%s\" does not have required %s %s.", oo::DescriptionOf(StringForErrorReport(value)).c_str(), "prefix", oo::DescriptionOf(StringOrArrayForErrorReport(testValue, @"in ")).c_str());
			return error;
		}
	}
	
	testValue = [params objectForKey:@"requiredSuffix"];
	if (testValue != nil)
	{
		if (!ApplyStringTest(filteredString, testValue, @selector(hasSuffix:), @"suffix", keyPath, &error))
		{
			if (error == nil)  error = ErrorWithProperty(kPListErrorStringSuffixMissing, &keyPath, kMissingSubStringErrorKey, oo::PListFrom(testValue), "String \"%s\" does not have required %s %s.", oo::DescriptionOf(StringForErrorReport(value)).c_str(), "suffix", oo::DescriptionOf(StringOrArrayForErrorReport(testValue, @"in ")).c_str());
			return error;
		}
	}
	
	testValue = [params objectForKey:@"requiredSubString"];
	if (testValue != nil)
	{
		if (!ApplyStringTest(filteredString, testValue, @selector(ooPListVerifierHasSubString:), @"substring", keyPath, &error))
		{
			if (error == nil)  error = ErrorWithProperty(kPListErrorStringSubstringMissing, &keyPath, kMissingSubStringErrorKey, oo::PListFrom(testValue), "String \"%s\" does not have required %s %s.", oo::DescriptionOf(StringForErrorReport(value)).c_str(), "substring", oo::DescriptionOf(StringOrArrayForErrorReport(testValue, @"in ")).c_str());
			return error;
		}
	}
	
	// Apply length bounds.
	length = [filteredString length];
	lengthConstraint = oo::PListView(params).get<NSUInteger>(@"minLength");
	if (length < lengthConstraint)
	{
		return  Error(kPListErrorMinimumConstraintNotMet, &keyPath, "String \"%s\" is too short (%u bytes, minimum is %u).", oo::DescriptionOf(StringForErrorReport(filteredString)).c_str(), length, lengthConstraint);
	}
	
	lengthConstraint = oo::PListView(params).get<NSUInteger>(@"maxLength", NSUIntegerMax);
	if (lengthConstraint < length)
	{
		return  Error(kPListErrorMaximumConstraintNotMet, &keyPath, "String \"%s\" is too long (%u bytes, maximum is %u).", oo::DescriptionOf(StringForErrorReport(filteredString)).c_str(), length, lengthConstraint);
	}
	
	// All tests passed.
	return nil;
}


static NSError *Verify_Array(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	id						valueType = nil;
	BOOL					OK = YES, stop = NO;
	NSUInteger				i, count;
	id						subProperty = nil;
	NSUInteger				constraint;
	
	REQUIRE_TYPE(NSArray, "array");
	
	DebugDump(@"%@", @"* array");
	
	// Apply count bounds.
	count = [value count];
	constraint = oo::PListView(params).get<NSUInteger>(@"minCount", 0);
	if (count < constraint)
	{
		return  Error(kPListErrorMinimumConstraintNotMet, &keyPath, "Array has too few members (%u, minimum is %u).", count, constraint);
	}
	
	constraint = oo::PListView(params).get<NSUInteger>(@"maxCount", NSUIntegerMax);
	if (constraint < count)
	{
		return  Error(kPListErrorMaximumConstraintNotMet, &keyPath, "Array has too many members (%u, maximum is %u).", count, constraint);
	}
	
	// Test member objects.
	valueType = [params objectForKey:@"valueType"];
	if (valueType != nil)
	{
		for (i = 0; i != count; ++i)
		{
			subProperty = [value objectAtIndex:i];
			
			if (![verifier verifyPList:rootPList
								 named:name
						   subProperty:subProperty
					 againstSchemaType:valueType
								atPath:BackLinkIndex(&keyPath, i)
							 tentative:tentative
								 error:NULL
								  stop:&stop])
			{
				OK = NO;
			}
			
			if ((stop && !tentative) || (tentative && !OK))  break;
		}
	}
	
	*outStop = stop && !tentative;
	
	if (!OK)  return ErrorFailureAlreadyReported();
	else  return nil;
}


static NSError *Verify_Dictionary(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	NSDictionary			*schema = nil;
	id						valueType = nil,
							typeSpec = nil;
	NSEnumerator			*keyEnum = nil;
	NSString				*key = nil;
	id						subProperty = nil;
	BOOL					OK = YES, stop = NO, prematureExit = NO;
	BOOL					allowOthers;
	NSMutableSet			*requiredKeys = nil;
	NSArray					*requiredKeyList = nil;
	NSUInteger				count, constraint;
	
	REQUIRE_TYPE(NSDictionary, "dictionary");
	
	DebugDump(@"%@", @"* dictionary");
	
	// Apply count bounds.
	count = [value count];
	constraint = oo::PListView(params).get<NSUInteger>(@"minCount", 0);
	if (count < constraint)
	{
		return  Error(kPListErrorMinimumConstraintNotMet, &keyPath, "Dictionary has too few pairs (%u, minimum is %u).", count, constraint);
	}
	constraint = oo::PListView(params).get<NSUInteger>(@"maxCount", NSUIntegerMax);
	if (constraint < count)
	{
		return  Error(kPListErrorMaximumConstraintNotMet, &keyPath, "Dictionary has too manu pairs (%u, maximum is %u).", count, constraint);
	}
	
	// Get schema.
	schema = oo::PListView(params).get<NSDictionary *>(@"schema");
	valueType = [params objectForKey:@"valueType"];
	allowOthers = oo::PListView(params).get<BOOL>(@"allowOthers", YES);
	requiredKeyList = oo::PListView(params).get<NSArray *>(@"requiredKeys");
	
	// If these conditions are met, all members must pass:
	if (schema == nil && valueType == nil && requiredKeyList == nil && allowOthers)  return nil;
	
	if (requiredKeyList != nil)
	{
		requiredKeys = [NSMutableSet setWithArray:requiredKeyList];
	}
	
	DebugDumpIndent();
	
	// Test member objects.
	for (keyEnum = [value keyEnumerator]; (key = [keyEnum nextObject]) && !stop; )
	{
		subProperty = [(NSDictionary *)value objectForKey:key];
		const std::string keyString = oo::StdString(key);	// kept alive for the key path below
		typeSpec = [schema objectForKey:key];
		if (typeSpec == nil)  typeSpec = valueType;
		
		DebugDump(@"- \"%@\"", key);
		DebugDumpIndent();
		
		if (typeSpec != nil)
		{
			if (![verifier verifyPList:rootPList
								 named:name
						   subProperty:subProperty
					 againstSchemaType:typeSpec
								atPath:BackLink(&keyPath, &keyString)
							 tentative:tentative
								 error:NULL
								  stop:&stop])
			{
				OK = NO;
			}
		}
		else if (!allowOthers && ![requiredKeys containsObject:key] && [schema objectForKey:key] == nil)
		{
			// Report error now rather than returning it, since there may be several unknown keys.
			if (!tentative)
			{
				NSError *error = ErrorWithProperty(kPListErrorDictionaryUnknownKey, &keyPath, kUnknownKeyErrorKey, oo::PListFrom(key), "Unpermitted key \"%s\" in dictionary.", oo::DescriptionOf(StringForErrorReport(key)).c_str());
				stop = ![verifier delegateVerifierWithPropertyList:rootPList
															 named:name
												 failedForProperty:value
														 withError:error
													  expectedType:params];
			}
			OK = NO;
		}
		
		DebugDumpOutdent();
		
		[requiredKeys removeObject:key];
		
		if ((stop && !tentative) || (tentative && !OK))
		{
			prematureExit = YES;
			break;
		}
	}
	
	DebugDumpOutdent();
	
	// Check that all required keys were present.
	if (!prematureExit && [requiredKeys count] != 0)
	{
		return ErrorWithProperty(kPListErrorDictionaryMissingRequiredKeys, &keyPath, kMissingRequiredKeysErrorKey, oo::PListFrom(requiredKeys), "Required keys %s missing from dictionary.", oo::DescriptionOf(SetForErrorReport(requiredKeys)).c_str());
	}
	
	*outStop = stop && !tentative;
	
	if (!OK)  return ErrorFailureAlreadyReported();
	else  return nil;
}


static NSError *Verify_Integer(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	long long				numericValue;
	long long				constraint;
	
	numericValue = OOLongLongFromObject(value, 0);
	
	DebugDump(@"* integer: %lli", numericValue);
	
	// Check basic parseability. If there's inequality here, the default value is being returned.
	if (numericValue != OOLongLongFromObject(value, 1))
	{
		return ErrorTypeMismatch([NSNumber class], "integer", value, keyPath);
	}
	
	// Check constraints.
	constraint = oo::PListView(params).get<long long>(@"minimum", LLONG_MIN);
	if (numericValue < constraint)
	{
		return  Error(kPListErrorMinimumConstraintNotMet, &keyPath, "Number is too small (%lli, minimum is %lli).", numericValue, constraint);
	}
	
	constraint = oo::PListView(params).get<long long>(@"maximum", LLONG_MAX);
	if (constraint < numericValue)
	{
		return  Error(kPListErrorMaximumConstraintNotMet, &keyPath, "Number is too large (%lli, maximum is %lli).", numericValue, constraint);
	}
	
	return nil;
}


static NSError *Verify_PositiveInteger(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	unsigned long long		numericValue;
	unsigned long long		constraint;
	
	numericValue = OOUnsignedLongLongFromObject(value, 0);
	
	DebugDump(@"* positive integer: %llu", numericValue);
	
	// Check basic parseability. If there's inequality here, the default value is being returned.
	if (numericValue != OOUnsignedLongLongFromObject(value, 1))
	{
		return ErrorTypeMismatch([NSNumber class], "positive integer", value, keyPath);
	}
	
	// Check constraints.
	constraint = oo::PListView(params).get<unsigned long long>(@"minimum", 0);
	if (numericValue < constraint)
	{
		return  Error(kPListErrorMinimumConstraintNotMet, &keyPath, "Number is too small (%zu, minimum is %zu).", numericValue, constraint);
	}
	
	constraint = oo::PListView(params).get<unsigned long long>(@"maximum", ULLONG_MAX);
	if (constraint < numericValue)
	{
		return  Error(kPListErrorMaximumConstraintNotMet, &keyPath, "Number is too large (%zu, maximum is %zu).", numericValue, constraint);
	}
	
	return nil;
}


static NSError *Verify_Float(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	double					numericValue;
	double					constraint;
	
	numericValue = OODoubleFromObject(value, 0);
	
	DebugDump(@"* float: %g", numericValue);
	
	// Check basic parseability. If there's inequality here, the default value is being returned.
	if (numericValue != OODoubleFromObject(value, 1))
	{
		return ErrorTypeMismatch([NSNumber class], "number", value, keyPath);
	}
	
	// Check constraints.
	constraint = oo::PListView(params).get<double>(@"minimum", -INFINITY);
	if (numericValue < constraint)
	{
		return  Error(kPListErrorMinimumConstraintNotMet, &keyPath, "Number is too small (%g, minimum is %g).", numericValue, constraint);
	}
	
	constraint = oo::PListView(params).get<double>(@"maximum", INFINITY);
	if (constraint < numericValue)
	{
		return  Error(kPListErrorMaximumConstraintNotMet, &keyPath, "Number is too large (%g, maximum is %g).", numericValue, constraint);
	}
	
	return nil;
}


static NSError *Verify_PositiveFloat(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	double					numericValue;
	double					constraint;
	
	numericValue = OODoubleFromObject(value, 0);
	
	DebugDump(@"* positive float: %g", numericValue);
	
	// Check basic parseability. If there's inequality here, the default value is being returned.
	if (numericValue != OODoubleFromObject(value, 1))
	{
		return ErrorTypeMismatch([NSNumber class], "positive number", value, keyPath);
	}
	
	if (numericValue < 0)
	{
		return Error(kPListErrorNumberIsNegative, &keyPath, "Expected non-negative number, found %g.", numericValue);
	}
	
	// Check constraints.
	constraint = oo::PListView(params).get<double>(@"minimum", 0);
	if (numericValue < constraint)
	{
		return  Error(kPListErrorMinimumConstraintNotMet, &keyPath, "Number is too small (%g, minimum is %g).", numericValue, constraint);
	}
	
	constraint = oo::PListView(params).get<double>(@"maximum", INFINITY);
	if (constraint < numericValue)
	{
		return  Error(kPListErrorMaximumConstraintNotMet, &keyPath, "Number is too large (%g, maximum is %g).", numericValue, constraint);
	}
	
	return nil;
}


static NSError *Verify_OneOf(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	NSArray					*options = nil;
	BOOL					OK = NO, stop = NO;
	id						option = nil;
	NSError					*error;
	NSMutableDictionary		*errors = nil;
	
	DebugDump(@"%@", @"* oneOf");
	
	options = oo::PListView(params).get<NSArray *>(@"options");
	if (options == nil)
	{
		*outStop = YES;
		return Error(kPListErrorSchemaNoOneOfOptions, &keyPath, "Bad schema: no options specified for oneOf type.");
	}
	
	errors = [[NSMutableDictionary alloc] initWithCapacity:[options count]];
	
	foreach (option, options)
	{
		if ([verifier verifyPList:rootPList
							named:name
					  subProperty:value
				againstSchemaType:option
						   atPath:keyPath
						tentative:YES
							error:&error
							 stop:&stop])
		{
			DebugDump(@"%@", @"> Match.");
			OK = YES;
			break;
		}
		[errors setObject:error forKey:option];
	}
	
	if (!OK)
	{
		DebugDump(@"%@", @"! No match.");
		return ErrorWithProperty(kPListErrorOneOfNoMatch, &keyPath, kErrorsByOptionErrorKey, oo::PListObject([errors autorelease]), "No matching type rule could be found.");
	}
	
	// Ignore stop in tentatives.
	[errors release];
	return nil;
}


static NSError *Verify_Enumeration(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	NSArray					*values = nil;
	NSString				*filteredString = nil;
	NSError					*error = nil;
	
	DebugDump(@"%@", @"* enumeration");
	
	REQUIRE_TYPE(NSString, "string");
	
	values = oo::PListView(params).get<NSArray *>(@"values");
	DebugDump(@"  - \"%@\" in %@", StringForErrorReport(value), ArrayForErrorReport(values));
	
	if (values == nil)
	{
		*outStop = YES;
		return Error(kPListErrorSchemaNoEnumerationValues, &keyPath, "Bad schema: no options specified for oneOf type.");
	}
	
	filteredString = ApplyStringFilter(value, [params objectForKey:@"filter"], keyPath, &error);
	if (filteredString == nil)  return error;
	
	if ([values containsObject:filteredString])  return nil;
	
	return Error(kPListErrorEnumerationBadValue, &keyPath, "Value \"%s\" not recognized, should be one of %s.", oo::DescriptionOf(StringForErrorReport(value)).c_str(), oo::DescriptionOf(ArrayForErrorReport(values)).c_str());
}


static NSError *Verify_Boolean(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	DebugDump(@"* boolean: %@", value);
	
	// Check basic parseability. If there's inequality here, the default value is being returned.
	if (OOBooleanFromObject(value, 0) == OOBooleanFromObject(value, 1))  return nil;
	else  return ErrorTypeMismatch([NSNumber class], "boolean", value, keyPath);
}


static NSError *Verify_FuzzyBoolean(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	DebugDump(@"* fuzzy boolean: %@", value);
	
	// Check basic parseability. If there's inequality here, the default value is being returned.
	if (OODoubleFromObject(value, 0) == OODoubleFromObject(value, 1))  return nil;
	else if (OOBooleanFromObject(value, 0) == OOBooleanFromObject(value, 1))  return nil;
	else  return ErrorTypeMismatch([NSNumber class], "fuzzy boolean", value, keyPath);
}


static NSError *Verify_Vector(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	DebugDump(@"* vector: %@", value);
	
	// Check basic parseability. If there's inequality here, the default value is being returned.
	if (vector_equal(OOVectorFromObject(value, kZeroVector), OOVectorFromObject(value, kBasisXVector)))  return nil;
	else  return ErrorTypeMismatch(Nil, "vector", value, keyPath);
}


static NSError *Verify_Quaternion(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	DebugDump(@"* quaternion: %@", value);
	
	// Check basic parseability. If there's inequality here, the default value is being returned.
	if (quaternion_equal(OOQuaternionFromObject(value, kZeroQuaternion), OOQuaternionFromObject(value, kIdentityQuaternion)))  return nil;
	else  return ErrorTypeMismatch(Nil, "quaternion", value, keyPath);
}


static NSError *Verify_DelegatedType(OOPListSchemaVerifier *verifier, id value, NSDictionary *params, id rootPList, NSString *name, BackLinkChain keyPath, BOOL tentative, BOOL *outStop)
{
	id						baseType = nil;
	NSString				*key = nil;
	BOOL					stop = NO;
	NSError					*error = nil;
	
	DebugDump(@"* delegated type: %@", [params objectForKey:@"key"]);
	
	baseType = [params objectForKey:@"baseType"];
	if (baseType != nil)
	{
		if (![verifier verifyPList:rootPList
							 named:name
					   subProperty:value
				 againstSchemaType:baseType
							atPath:keyPath
						 tentative:tentative
							 error:NULL
							  stop:&stop])
		{
			*outStop = stop;
			return nil;
		}
	}
	
	key = [params objectForKey:@"key"];
	*outStop = ![verifier delegateVerifierWithPropertyList:rootPList
													 named:name
											  testProperty:value
													atPath:keyPath
											   againstType:key
													 error:&error];
	return error;
}


@implementation NSString (OOPListSchemaVerifierHelpers)

- (BOOL)ooPListVerifierHasSubString:(NSString *)string
{
	return [self rangeOfString:string].location != NSNotFound;
}

@end


@implementation NSError (OOPListSchemaVerifierConveniences)

- (NSArray *)plistKeyPath
{
	return oo::PListView([self userInfo]).get<NSArray *>(oo::NSStringFrom(kPListKeyPathErrorKey));
}


- (NSString *)plistKeyPathDescription
{
	return oo::NSStringOrNil([OOPListSchemaVerifier descriptionForKeyPath:oo::PListFrom([self plistKeyPath])]);
}


- (NSSet *)missingRequiredKeys
{
	return oo::PListView([self userInfo]).get<NSSet *>(oo::NSStringFrom(kMissingRequiredKeysErrorKey));
}


- (Class)expectedClass
{
	return [[self userInfo] objectForKey:oo::NSStringFrom(kExpectedClassErrorKey)];
}


- (NSString *)expectedClassName
{
	NSString *result = [[self userInfo] objectForKey:oo::NSStringFrom(kExpectedClassNameErrorKey)];
	if (result == nil)  result = [[self expectedClass] description];
	return result;
}

@end


namespace {

NSError *Error(OOPListSchemaVerifierErrorCode errorCode, BackLinkChain *keyPath, const char *format, ...)
{
	NSError				*result = nil;
	va_list				args;

	va_start(args, format);
	result = ErrorWithDictionaryAndArguments(errorCode, keyPath, oo::PList(), format, args);
	va_end(args);

	return result;
}


NSError *ErrorWithProperty(OOPListSchemaVerifierErrorCode errorCode, BackLinkChain *keyPath, const std::string &propKey, const oo::PList &propValue, const char *format, ...)
{
	NSError				*result = nil;
	va_list				args;
	oo::PList			dict;

	if (propValue)
	{
		dict = oo::PList(oo::PList::Dict{ { propKey, propValue } });
	}
	va_start(args, format);
	result = ErrorWithDictionaryAndArguments(errorCode, keyPath, dict, format, args);
	va_end(args);

	return result;
}


NSError *ErrorWithDictionary(OOPListSchemaVerifierErrorCode errorCode, BackLinkChain *keyPath, const oo::PList &dict, const char *format, ...)
{
	NSError				*result = nil;
	va_list				args;

	va_start(args, format);
	result = ErrorWithDictionaryAndArguments(errorCode, keyPath, dict, format, args);
	va_end(args);

	return result;
}


NSError *ErrorWithDictionaryAndArguments(OOPListSchemaVerifierErrorCode errorCode, BackLinkChain *keyPath, const oo::PList &dict, const char *format, va_list arguments)
{
	oo::PList::Dict		userInfo;

	if (const oo::PList::Dict *entries = dict.getIf<oo::PList::Dict>())  userInfo = *entries;
	userInfo[oo::StdString(NSLocalizedFailureReasonErrorKey)] = oo::PList(oo::str::vformat(format, arguments));
	if (keyPath != NULL)
	{
		userInfo[kPListKeyPathErrorKey] = KeyPathToArray(*keyPath);
	}

	return [NSError errorWithDomain:oo::NSStringFrom(kOOPListSchemaVerifierErrorDomain) code:errorCode userInfo:oo::ObjectFromPList(oo::PList(std::move(userInfo)))];
}


NSError *ErrorTypeMismatch(Class expectedClass, const char *expectedClassName, id actualObject, BackLinkChain keyPath)
{
	oo::PList::Dict		dict;
	std::string			className;

	const std::string expectedName = (expectedClassName != NULL) ? std::string(expectedClassName) : oo::StdString([expectedClass description]);

	dict[kExpectedClassNameErrorKey] = oo::PList(expectedName);
	if (expectedClass != Nil)  dict[kExpectedClassErrorKey] = oo::PListObject(expectedClass);	// omitted for Nil, as the nil-terminated list did

	if (actualObject == nil)  className = "nothing";
	else if (oo::IsNSString(actualObject))  className = "string";
	else if (oo::IsNSNumber(actualObject))  className = "number";
	else if (oo::IsNSArray(actualObject))  className = "array";
	else if (oo::IsNSDictionary(actualObject))  className = "dictionary";
	else if (oo::IsNSData(actualObject))  className = "data";
	else if ([actualObject isKindOfClass:[NSDate class]])  className = "date";
	else  className = oo::StdString([[actualObject class] description]);

	return ErrorWithDictionary(kPListErrorTypeMismatch, &keyPath, oo::PList(std::move(dict)), "Expected %s, found %s.", expectedName.c_str(), className.c_str());
}


NSError *ErrorFailureAlreadyReported(void)
{
	return [NSError errorWithDomain:oo::NSStringFrom(kOOPListSchemaVerifierErrorDomain) code:kPListErrorFailedAndErrorHasBeenReported userInfo:nil];
}


BOOL IsFailureAlreadyReportedError(NSError *error)
{
	return oo::StdString([error domain]) == kOOPListSchemaVerifierErrorDomain && [error code] == kPListErrorFailedAndErrorHasBeenReported;
}

} // namespace

#endif	// OO_OXP_VERIFIER_ENABLED
