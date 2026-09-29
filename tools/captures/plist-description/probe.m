/*	tools/captures/plist-description/probe.m
	Prints gnustep-base's -description of each case in cases.txt as a C++ table row (bead oo-qps.32,
	ADR-0055 item 1). Run by capture.sh, which links it against gnustep-base; the rows become
	tests/unit/oofnd/plist_description_captured.inc, the expectations of test_plist_description.cpp.
	Needs gnustep-base: after oo-qps.18 unlinks it from the game it must still be installed to rerun.
*/

#import <Foundation/Foundation.h>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>


// An object that is not property-list data, with a fixed -description (a colour, a texture...).
@interface OOCaptureForeign : NSObject
{
	NSString *_text;
}
- (id) initWithText:(NSString *)text;
@end

@implementation OOCaptureForeign

- (id) initWithText:(NSString *)text
{
	if ((self = [super init]))  _text = [text copy];
	return self;
}


- (void) dealloc
{
	[_text release];
	[super dealloc];
}


- (NSString *) description
{
	return _text;
}

@end


static id ValueForCase(NSString *kind, NSString *text)
{
	if ([kind isEqualToString:@"nil"])  return nil;
	if ([kind isEqualToString:@"plist"])
	{
		NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
		NSString *error = nil;
		id plist = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListImmutable format:NULL errorDescription:&error];
		if (plist == nil)
		{
			fprintf(stderr, "probe: cannot parse %s: %s\n", [text UTF8String], [error UTF8String]);
			exit(2);
		}
		return plist;
	}
	if ([kind isEqualToString:@"float"])  return [NSNumber numberWithFloat:strtof([text UTF8String], NULL)];
	if ([kind isEqualToString:@"float-array"])  return [NSArray arrayWithObject:[NSNumber numberWithFloat:strtof([text UTF8String], NULL)]];

	id foreign = [[[OOCaptureForeign alloc] initWithText:text] autorelease];
	if ([kind isEqualToString:@"foreign"])  return foreign;
	if ([kind isEqualToString:@"foreign-array"])  return [NSArray arrayWithObject:foreign];
	if ([kind isEqualToString:@"foreign-dict"])  return [NSDictionary dictionaryWithObject:foreign forKey:@"key"];

	fprintf(stderr, "probe: unknown kind %s\n", [kind UTF8String]);
	exit(2);
}


// <text> as a C string literal: backslash and quote escaped, control bytes as 3-digit octal, the
// rest (UTF-8 included) as is, so the .inc holds no raw control character.
static void PrintCString(const char *text)
{
	putchar('"');
	for (const unsigned char *p = (const unsigned char *)text; *p != 0; p++)
	{
		if (*p == '\\' || *p == '"')  printf("\\%c", *p);
		else if (*p < 0x20 || *p == 0x7F)  printf("\\%03o", *p);
		else  putchar(*p);
	}
	putchar('"');
}


int main(int argc, char **argv)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	if (argc != 2)
	{
		fprintf(stderr, "usage: probe cases.txt\n");
		return 2;
	}
	NSString *cases = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]] encoding:NSUTF8StringEncoding error:NULL];
	if (cases == nil)
	{
		fprintf(stderr, "probe: cannot read %s\n", argv[1]);
		return 2;
	}

	for (NSString *line in [cases componentsSeparatedByString:@"\n"])
	{
		line = [line stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r"]];
		if ([line length] == 0 || [line hasPrefix:@"#"])  continue;
		NSArray *fields = [line componentsSeparatedByString:@"\t"];
		if ([fields count] != 3)
		{
			fprintf(stderr, "probe: not <kind> TAB <name> TAB <text>: %s\n", [line UTF8String]);
			return 2;
		}
		NSString *kind = [fields objectAtIndex:0], *name = [fields objectAtIndex:1], *text = [fields objectAtIndex:2];
		id value = ValueForCase(kind, text);
		NSString *description = value != nil ? [value description] : @"(null)";	// oo::DescriptionOf(id)
		printf("\t{ \"%s\", \"%s\", ", [kind UTF8String], [name UTF8String]);
		PrintCString([text UTF8String]);
		printf(", ");
		PrintCString([description UTF8String]);
		printf(" },\n");
	}

	[pool release];
	return 0;
}
