/*	tools/plist-fuzz/gnustep_oracle.mm — the GNUstep side of the oofnd PList differential harness
	(bead oo-g2k, contract C1). NOT part of the game: tools/plist_fuzz.py builds it on demand with
	gnustep-config and links it with the game's own OldSchoolPropertyListWriting.mm, so the
	reference is exactly what the game does today: OOPropertyListFromData (ChangeDTDIfApplicable +
	NSPropertyListSerialization), -oldSchoolPListFormatWithErrorDescription: and GNUstep's XML
	writer.

	    gnustep_oracle <list> <outdir> [parse-only]

	<list> holds "<id>\t<path>" lines. For each, stdout gets (flushed per file, so a crash is
	attributable to the file that caused it):

	    F <id>
	    P OK <format> <dump> | P NIL | P ERR <message> | P EXC <exception name>
	    W1 OK | W1 ERR <message> | W1 SKIP <reason>        (old-style writer; not in parse-only)
	    W2 OK | W2 ERR <message>                            (XML writer; not in parse-only)

	and a successful write leaves <outdir>/<id>.old or <outdir>/<id>.xml. <dump> is the one-line
	canonical form of upstream/oolite/tests/unit/oofnd/plist_dump.hpp (the unit tests pin the same
	text), with a non-string dictionary key written as !<dump of key>. Messages have \ and newlines
	escaped. The harness prints only verdicts derived from this output, never the values.
*/

#import <Foundation/Foundation.h>
#import "OldSchoolPropertyListWriting.h"

#include <inttypes.h>
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>
#include <string>

// ChangeDTDIfApplicable, verbatim from upstream/oolite/src/Core/OOPListParsing.mm (the static
// function the game applies before NSPropertyListSerialization).
static NSData *ChangeDTDIfApplicable(NSData *data)
{
	const uint8_t		*bytes = NULL;
	uint8_t				*newBytes = NULL;
	size_t				length,
						newLength,
						offset = 0,
						newOffset = 0;
	const char			xmlDeclLine[] = "<\?xml version=\"1.0\" encoding=\"UTF-8\"\?>";
	const char			*appleDTDLines[] =
						{
							"<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
							"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">",
							NULL
						};
	const char			gstepDTDLine[] = "<!DOCTYPE plist PUBLIC \"-//GNUstep//DTD plist 0.9//EN\" \"http://www.gnustep.org/plist-0_9.xml\">";
	const char			*srcDTDLine = NULL;
	size_t				srcDTDLineSize = 0;
	unsigned			i;

	length = [data length];
	if (length < sizeof xmlDeclLine) return data;

	bytes = (const uint8_t *)[data bytes];

	if (memcmp(bytes, xmlDeclLine, sizeof xmlDeclLine - 1) != 0) return data;

	offset += sizeof xmlDeclLine - 1;
	while (offset < length && isspace(bytes[offset]))  ++offset;

	for (i = 0; ; i++)
	{
		srcDTDLine = appleDTDLines[i];
		if (srcDTDLine == NULL)  return data;  // No matches

		srcDTDLineSize = strlen(appleDTDLines[i]);

		if (srcDTDLineSize <= length - offset &&
			memcmp(bytes + offset, srcDTDLine, srcDTDLineSize) == 0)
		{
			break;
		}
	}

	offset += srcDTDLineSize;

	newLength = length - offset + sizeof xmlDeclLine + sizeof gstepDTDLine - 1;
	newBytes = (uint8_t *)malloc(newLength);
	if (newBytes == NULL) return data;

	memcpy(newBytes, xmlDeclLine, sizeof xmlDeclLine - 1);
	newOffset = sizeof xmlDeclLine - 1;
	newBytes[newOffset++] = '\n';
	memcpy(newBytes + newOffset, gstepDTDLine, sizeof gstepDTDLine - 1);
	newOffset += sizeof gstepDTDLine - 1;
	memcpy(newBytes + newOffset, bytes + offset, length - offset);

	return [NSData dataWithBytesNoCopy:newBytes length:newLength freeWhenDone:YES];
}

static void DumpString(NSString *s, std::string &out)
{
	out += '"';
	NSUInteger n = [s length];
	for (NSUInteger i = 0; i < n; i++)
	{
		unichar c = [s characterAtIndex:i];
		if (c == '"' || c == '\\') { out += '\\'; out += (char)c; }
		else if (c >= 0x20 && c < 0x7F) out += (char)c;
		else
		{
			char buf[8];
			snprintf(buf, sizeof buf, "\\u%04X", (unsigned)c);
			out += buf;
		}
	}
	out += '"';
}

static BOOL IsBoolean(NSNumber *n)
{
	return n == [NSNumber numberWithBool:YES] || n == [NSNumber numberWithBool:NO];
}

static void Dump(id p, std::string &out)
{
	char buf[64];
	if (p == nil) out += "nil";
	else if ([p isKindOfClass:[NSString class]]) { out += 'S'; DumpString(p, out); }
	else if ([p isKindOfClass:[NSNumber class]])
	{
		const char *t = [p objCType];
		if (IsBoolean(p)) out += [p boolValue] ? "B1" : "B0";
		else if (strcmp(t, @encode(double)) == 0 || strcmp(t, @encode(float)) == 0)
		{
			snprintf(buf, sizeof buf, "R%.17g", [p doubleValue]);
			out += buf;
		}
		else if (strcmp(t, @encode(unsigned long long)) == 0 || strcmp(t, @encode(unsigned long)) == 0
			|| strcmp(t, @encode(unsigned int)) == 0)
		{
			unsigned long long u = [p unsignedLongLongValue];
			if (u > (unsigned long long)INT64_MAX) snprintf(buf, sizeof buf, "U%llu", u);
			else snprintf(buf, sizeof buf, "I%lld", (long long)u);
			out += buf;
		}
		else
		{
			snprintf(buf, sizeof buf, "I%lld", [p longLongValue]);
			out += buf;
		}
	}
	else if ([p isKindOfClass:[NSData class]])
	{
		out += "D<";
		const uint8_t *b = (const uint8_t *)[p bytes];
		NSUInteger n = [p length];
		for (NSUInteger i = 0; i < n; i++) { snprintf(buf, sizeof buf, "%02x", b[i]); out += buf; }
		out += '>';
	}
	else if ([p isKindOfClass:[NSDate class]])
	{
		snprintf(buf, sizeof buf, "T%.3f", [p timeIntervalSinceReferenceDate]);
		out += buf;
	}
	else if ([p isKindOfClass:[NSArray class]])
	{
		out += '[';
		BOOL first = YES;
		for (id e in p)
		{
			if (!first) out += ',';
			first = NO;
			Dump(e, out);
		}
		out += ']';
	}
	else if ([p isKindOfClass:[NSDictionary class]])
	{
		NSMutableArray *strKeys = [NSMutableArray array];
		NSMutableArray *otherKeys = [NSMutableArray array];
		for (id k in p) [([k isKindOfClass:[NSString class]] ? strKeys : otherKeys) addObject:k];
		// UTF-16 code-unit order, as plist_dump.hpp sorts (GNUstep's -compare: is not quite that
		// for non-ASCII keys, and the order is only presentation).
		[strKeys sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
			NSUInteger la = [a length], lb = [b length];
			for (NSUInteger i = 0; i < la && i < lb; i++)
			{
				unichar ca = [a characterAtIndex:i], cb = [b characterAtIndex:i];
				if (ca != cb) return ca < cb ? NSOrderedAscending : NSOrderedDescending;
			}
			return la == lb ? NSOrderedSame : (la < lb ? NSOrderedAscending : NSOrderedDescending);
		}];
		out += '{';
		for (id k in otherKeys)
		{
			out += '!';
			Dump(k, out);
			out += '=';
			Dump([p objectForKey:k], out);
			out += ';';
		}
		for (NSString *k in strKeys)
		{
			DumpString(k, out);
			out += '=';
			Dump([p objectForKey:k], out);
			out += ';';
		}
		out += '}';
	}
	else
	{
		out += "?";
		out += [NSStringFromClass([p class]) UTF8String];
	}
}

static void PrintEscaped(const char *tag, NSString *msg)
{
	std::string s;
	const char *u = [msg UTF8String];
	for (; u != NULL && *u; u++)
	{
		if (*u == '\\') s += "\\\\";
		else if (*u == '\n') s += "\\n";
		else if (*u == '\r') s += "\\r";
		else s += *u;
	}
	printf("%s %s\n", tag, s.c_str());
}

/*	-[NSData oldSchoolPListFormatWithIndentation:] writes past its buffer, leaves bytes
	uninitialised, or loops forever for most lengths (ADR-0027 item 4). Calling it on those would
	crash or hang the oracle, so the harness asks first: YES when every data node's written length
	equals the buffer the original allocates (the only well-defined case).
*/
static BOOL OldStyleDataWellDefined(id p, unsigned indent)
{
	if ([p isKindOfClass:[NSData class]])
	{
		NSUInteger n = [p length];
		NSUInteger dst = 2 * n + n / 8 + 2 + (n / 64 * (1 + indent));
		NSUInteger written = 1;
		for (NSUInteger i = 0; i != n; ++i)
		{
			if (0 != i && 0 == (i & 3))
			{
				if (0 == (i & 31))
				{
					if (indent == 0) return NO;   // while (--j) with j == 0: never ends
					written += 1 + (indent - 1);
				}
				written += 1;
			}
			written += 2;
		}
		return written + 1 == dst;
	}
	if ([p isKindOfClass:[NSArray class]])
	{
		for (id e in p) if (!OldStyleDataWellDefined(e, indent + 1)) return NO;
	}
	else if ([p isKindOfClass:[NSDictionary class]])
	{
		for (id k in p) if (!OldStyleDataWellDefined([p objectForKey:k], indent + 1)) return NO;
	}
	return YES;
}

static BOOL WriteFile(NSString *dir, NSString *name, NSData *data)
{
	return [data writeToFile:[dir stringByAppendingPathComponent:name] atomically:NO];
}

static void ProcessOne(NSString *ident, NSString *path, NSString *outDir, BOOL parseOnly)
{
	printf("F %s\n", [ident UTF8String]);
	fflush(stdout);

	NSData *data = [NSData dataWithContentsOfFile:path];
	id plist = nil;
	@try
	{
		NSString *error = nil;
		NSPropertyListFormat format = (NSPropertyListFormat)0;
		if (data != nil) data = ChangeDTDIfApplicable(data);
		plist = [NSPropertyListSerialization propertyListFromData:data
												 mutabilityOption:NSPropertyListImmutable
														   format:&format
												 errorDescription:&error];
		if (plist != nil)
		{
			std::string d;
			Dump(plist, d);
			printf("P OK %d %s\n", (int)format, d.c_str());
		}
		else if (error != nil) PrintEscaped("P ERR", error);
		else printf("P NIL\n");
	}
	@catch (NSException *e)
	{
		plist = nil;
		printf("P EXC %s\n", [[e name] UTF8String]);
	}
	fflush(stdout);

	if (plist != nil && !parseOnly)
	{
		if (!OldStyleDataWellDefined(plist, 0)) printf("W1 SKIP data-length-undefined\n");
		else
		{
			NSString *err = nil;
			NSData *old = nil;
			@try { old = [plist oldSchoolPListFormatWithErrorDescription:&err]; }
			@catch (NSException *e) { err = [NSString stringWithFormat:@"exception %@", [e name]]; }
			if (old != nil && WriteFile(outDir, [ident stringByAppendingString:@".old"], old)) printf("W1 OK\n");
			else PrintEscaped("W1 ERR", err != nil ? err : @"<nil>");
		}
		fflush(stdout);

		NSString *err = nil;
		NSData *xml = nil;
		@try
		{
			xml = [NSPropertyListSerialization dataFromPropertyList:plist
															 format:NSPropertyListXMLFormat_v1_0
												   errorDescription:&err];
		}
		@catch (NSException *e) { err = [NSString stringWithFormat:@"exception %@", [e name]]; }
		if (xml != nil && WriteFile(outDir, [ident stringByAppendingString:@".xml"], xml)) printf("W2 OK\n");
		else PrintEscaped("W2 ERR", err != nil ? err : @"<nil>");
		fflush(stdout);
	}
}

int main(int argc, char **argv)
{
	if (argc < 3)
	{
		fprintf(stderr, "usage: gnustep_oracle <list> <outdir> [parse-only]\n");
		return 2;
	}
	@autoreleasepool
	{
		BOOL parseOnly = argc > 3 && strcmp(argv[3], "parse-only") == 0;
		// ADR-0027 item 7: GNUstep reads a ...Z date (and a zone beyond 18 hours) in the local
		// zone; the harness pins UTC so the oracle is machine-independent and comparable with oofnd.
		[NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

		NSString *outDir = [NSString stringWithUTF8String:argv[2]];
		NSString *list = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]
												   encoding:NSUTF8StringEncoding error:NULL];
		if (list == nil)
		{
			fprintf(stderr, "cannot read list\n");
			return 2;
		}
		for (NSString *line in [list componentsSeparatedByString:@"\n"])
		{
			NSArray *parts = [line componentsSeparatedByString:@"\t"];
			if ([parts count] != 2) continue;
			@autoreleasepool
			{
				ProcessOne([parts objectAtIndex:0], [parts objectAtIndex:1], outDir, parseOnly);
			}
		}
		printf("END\n");
	}
	return 0;
}
