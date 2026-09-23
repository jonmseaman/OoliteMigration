/*

OODebugMonitor.m


Oolite debug support

Copyright (C) 2007-2013 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

#ifndef NDEBUG


#import "OODebugMonitor.h"
#import "OOPListView.h"
#import "OOLoggingExtended.h"
#import "ResourceManager.h"
#import "NSStringOOExtensions.h"

#import "OOJSConsole.h"
#import "OOJSScript.h"
#import "OOFoundationBridge.h"
#import "OOJSEngineTimeManagement.h"
#import "OOJSSpecialFunctions.h"

#import "NSObjectOOExtensions.h"
#import "OOTexture.h"
#import "OOFoundationBridge.h"
#include "oofnd/String.hpp"
#include "oofnd/PListGet.hpp"
#import "OOConcreteTexture.h"
#import "OODrawable.h"


static OODebugMonitor *sSingleton = nil;


@interface OODebugMonitor (Private) <OOJavaScriptEngineMonitor>

- (void) setUpDebugConsoleScript;
- (void) javaScriptEngineWillReset:(NSNotification *)notification;

- (void)disconnectDebuggerWithMessage:(const std::optional<std::string> &)message;	// nullopt: no message (the TCP client sends a bare close)

- (oo::PList)mergedConfiguration;

/*	Convert a configuration dictionary to a standard form. In particular,
	convert all colour specifiers to RGBA arrays with values in [0, 1], and
	converts "show-console" values to booleans.
*/
- (oo::PList)normalizeConfigDictionary:(const oo::PList &)dictionary;	// always a Dict (empty for null)
- (oo::PList)normalizeConfigValue:(const oo::PList &)value forKey:(const std::string &)key;	// null: dropped

- (NSArray *)loadSourceFile:(NSString *)filePath;

@end


@implementation OODebugMonitor
#if OOLITE_GNUSTEP
namespace {
	id							NSApplicationWillTerminateNotification = @"ApplicationWillTerminate";	// file-private (no other file names it)
} // namespace
#endif

- (id)init
{
	NSUserDefaults				*defaults = nil;

	self = [super init];
	if (self != nil)
	{
		_configFromOXPs = [self normalizeConfigDictionary:oo::PListFrom([ResourceManager dictionaryFromFilesNamed:@"debugConfig.plist"
																										   inFolder:@"Config"
																										   andMerge:YES])];

		defaults = [NSUserDefaults standardUserDefaults];
		_configOverrides = [self normalizeConfigDictionary:oo::PListFrom([defaults dictionaryForKey:@"debug-settings-override"])];
		
		_TCPIgnoresDroppedPackets = NO;
		
		OOJavaScriptEngine *jsEng = [OOJavaScriptEngine sharedEngine];
#if OOJSENGINE_MONITOR_SUPPORT
		[jsEng setMonitor:self];
#endif
		
		[self setUpDebugConsoleScript];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationWillTerminate:)
													 name:NSApplicationWillTerminateNotification
												   object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(javaScriptEngineWillReset:)
													 name:kOOJavaScriptEngineWillResetNotification
												   object:jsEng];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(setUpDebugConsoleScript)
													 name:kOOJavaScriptEngineDidResetNotification
												   object:jsEng];
	}
	
	return self;
}


- (void)dealloc
{
	[self disconnectDebuggerWithMessage:"Debug controller object destroyed while debugging in progress."];

	
	[_fgColors release];
	[_bgColors release];
	[_sourceFiles release];
	
	if (_jsSelf != NULL)
	{
		[[OOJavaScriptEngine sharedEngine] removeGCObjectRoot:&_jsSelf];
	}
	
	[super dealloc];
}


+ (OODebugMonitor *) sharedDebugMonitor
{
	// NOTE: assumes single-threaded access. The debug monitor is not, on the whole, thread safe.
	if (sSingleton == nil)
	{
		sSingleton = [[self alloc] init];
	}
	
	return sSingleton;
}


- (BOOL)setDebugger:(id<OODebuggerInterface>)newDebugger
{
	id							error = nil;	// the shared -connectDebugMonitor:errorMessage:'s string

	if (newDebugger != _debugger)
	{
		// Disconnect existing debugger, if any.
		if (newDebugger != nil)
		{
			[self disconnectDebuggerWithMessage:"New debugger set."];
		}
		else
		{
			[self disconnectDebuggerWithMessage:"Debugger disconnected programatically."];
		}
		
		// If a new debugger was specified, try to connect it.
		if (newDebugger != nil)
		{
			@try
			{
				if ([newDebugger connectDebugMonitor:self errorMessage:&error])
				{
					[newDebugger debugMonitor:self
							noteConfiguration:oo::ObjectFromPList([self mergedConfiguration])];
					_debugger = [newDebugger retain];
				}
				else
				{
					OOLog(@"debugMonitor.setDebugger.failed", @"Could not connect to debugger %@, because an error occurred: %@", newDebugger, error);
				}
			}
			@catch (NSException *exception)
			{
				OOLog(@"debugMonitor.setDebugger.failed", @"Could not connect to debugger %@, because an exception occurred: %@ -- %@", newDebugger, [exception name], [exception reason]);
			}
		}
	}
	
	return _debugger == newDebugger;
}


- (oneway void)performJSConsoleCommand:(in id)command	// shared selector (proposed ADR-0043)
{
	ooscript::Context context = OOJSAcquireContext();
	ooscript::Value commandVal = OOJSValueFromNativeObject(context, command);
	OOJSStartTimeLimiterWithTimeLimit(kOOJSLongTimeLimit);
	[_script callMethod:OOJSID("consolePerformJSCommand") inContext:context withArguments:&commandVal count:1 result:NULL];
	OOJSStopTimeLimiter();
	OOJSRelinquishContext(context);
}


- (void)appendJSConsoleLine:(id)string
				   colorKey:(NSString *)colorKey
			  emphasisRange:(NSRange)emphasisRange
{
	if (string == nil)  return;
	OOJSPauseTimeLimiter();
	@try
	{
		[_debugger debugMonitor:self
				jsConsoleOutput:string
					   colorKey:colorKey
				  emphasisRange:emphasisRange];
	}
	@catch (NSException *exception)
	{
		OOLog(@"debugMonitor.debuggerConnection.exception", @"Exception while attempting to send JavaScript console text to debugger: %@ -- %@", [exception name], [exception reason]);
	}
	OOJSResumeTimeLimiter();
}


- (void)appendJSConsoleLine:(id)string
				   colorKey:(NSString *)colorKey
{
	[self appendJSConsoleLine:string
					 colorKey:colorKey
				emphasisRange:NSMakeRange(0, 0)];
}


- (void)clearJSConsole
{
	OOJSPauseTimeLimiter();
	@try
	{
		[_debugger debugMonitorClearConsole:self];
	}
	@catch (NSException *exception)
	{
		OOLog(@"debugMonitor.debuggerConnection.exception", @"Exception while attempting to clear JavaScript console: %@ -- %@", [exception name], [exception reason]);
	}
	OOJSResumeTimeLimiter();
}


- (void)showJSConsole
{
	OOJSPauseTimeLimiter();
	@try
	{
		[_debugger debugMonitorShowConsole:self];
	}
	@catch (NSException *exception)
	{
		OOLog(@"debugMonitor.debuggerConnection.exception", @"Exception while attempting to show JavaScript console: %@ -- %@", [exception name], [exception reason]);
	}
	OOJSResumeTimeLimiter();
}


- (id)configurationValueForKey:(in id)key	// shared selector (proposed ADR-0043)
{
	return [self configurationValueForKey:oo::StdString(key) class:Nil defaultValue:nil];
}


- (id)configurationValueForKey:(const std::string &)key class:(Class)klass defaultValue:(id)value
{
	id							result = nil;

	if (klass == Nil)  klass = [NSObject class];

	// The stored objects: an Object node gives back the same object, any other node an equal one.
	const oo::PList *overrideValue = _configOverrides.find(key);
	result = (overrideValue != nullptr) ? oo::ObjectFromPList(*overrideValue) : nil;
	if (![result isKindOfClass:klass] && result != [OONull null])
	{
		const oo::PList *oxpValue = _configFromOXPs.find(key);
		result = (oxpValue != nullptr) ? oo::ObjectFromPList(*oxpValue) : nil;
	}
	if (![result isKindOfClass:klass] && result != [OONull null])  result = [[value retain] autorelease];
	if (result == [OONull null])  result = nil;

	return result;
}


- (long long)configurationIntValueForKey:(const std::string &)key defaultValue:(long long)value
{
	long long					result;
	id							object = nil;

	object = [self configurationValueForKey:key class:Nil defaultValue:nil];
	if ([object respondsToSelector:@selector(longLongValue)])  result = [object longLongValue];
	else if ([object respondsToSelector:@selector(intValue)])  result = [object intValue];
	else  result = value;
	
	return result;
}


- (void)setConfigurationValue:(in id)value forKey:(in id)key	// shared selector (proposed ADR-0043)
{
	if (key == nil)  return;

	const std::string keyString = oo::StdString(key);
	const oo::PList normalized = [self normalizeConfigValue:oo::PListFrom(value) forKey:keyString];

	if (!_configOverrides.isDict())  _configOverrides = oo::PList(oo::PList::Dict());
	oo::PList::Dict &overrides = *_configOverrides.getIf<oo::PList::Dict>();
	if (!normalized)
	{
		overrides.erase(keyString);
	}
	else
	{
		overrides[keyString] = normalized;
	}

	// Send changed value to debugger
	if (!normalized)
	{
		// Setting a nil value removes an override, and may reveal an underlying OXP-defined value
		value = [self configurationValueForKey:keyString class:Nil defaultValue:nil];
	}
	else
	{
		value = oo::ObjectFromPList(normalized);
	}
	@try
	{
		[_debugger debugMonitor:self
   noteChangedConfigrationValue:value
						 forKey:key];
	}
	@catch (NSException *exception)
	{
		OOLog(@"debugMonitor.debuggerConnection.exception", @"Exception while attempting to send configuration update to debugger: %@ -- %@", [exception name], [exception reason]);
	}
}


- (std::vector<std::string>)configurationKeys
{
	std::set<std::string>		keys;

	for (const oo::PList *config : { &_configFromOXPs, &_configOverrides })
	{
		if (const oo::PList::Dict *entries = config->getIf<oo::PList::Dict>())
		{
			for (const auto &entry : *entries)  keys.insert(entry.first);
		}
	}

	std::vector<std::string> result(keys.begin(), keys.end());
	std::stable_sort(result.begin(), result.end(), [](const std::string &a, const std::string &b) { return oo::str::caseInsensitiveCompare(a, b) < 0; });
	return result;
}


- (BOOL) debuggerConnected
{
	return _debugger != nil;
}


- (void) writeMemStat:(const std::string &)line
{
	OOLog(@"debug.memStats", @"%@", oo::NSStringFrom(line));
	[self appendJSConsoleLine:oo::NSStringFrom(line) colorKey:@"command-result"];
}


namespace {

std::string SizeString(size_t size)
{
	enum
	{
		kThreshold = 2	// 2 KiB, 2 MiB etc.
	};

	unsigned magnitude = 0;
	
	if (size < kThreshold << 10)
	{
		return oo::str::format("%zu bytes", size);
	}
	const char *suffix;
	if (size < kThreshold << 20)
	{
		magnitude = 1;
		suffix = "KiB";
	}
	else if (size < ((size_t)kThreshold << 30))
	{
		magnitude = 2;
		suffix = "MiB";
	}
	else
	{
		magnitude = 3;
		suffix = "GiB";
	}

	float unit = 1 << (magnitude * 10);
	float sizef = (float)size / unit;
	sizef = round(sizef * 100.0f) / 100.f;

	return oo::str::format("%.2f %s", sizef, suffix);
}


// Sets of objects by identity (the mutable sets of textures and entities compared by identity).
struct EntityDumpState
{
	std::set<oo::ObjCRef<id>>	entityTextures;
	std::set<oo::ObjCRef<id>>	visibleEntityTextures;
	std::set<oo::ObjCRef<id>>	seenEntities;
	unsigned					seenCount = 0;
	size_t						totalEntityObjSize = 0;
	size_t						totalDrawableSize = 0;
};

} // namespace


- (void) dumpEntity:(id)entity withState:(EntityDumpState *)state parentVisible:(BOOL)parentVisible
{
	if (entity == nil || state->seenEntities.count(oo::ObjCRef<id>(entity)) != 0)  return;
	state->seenEntities.insert(oo::ObjCRef<id>(entity));

	state->seenCount++;

	size_t entitySize = [entity oo_objectSize];
	size_t drawableSize = 0;
	if ([entity isKindOfClass:[OOEntityWithDrawable class]])
	{
		OODrawable *drawable = [entity drawable];
		drawableSize = [drawable totalSize];
	}

	BOOL visible = parentVisible && [entity isVisible];

	// -allTextures is a shared selector (id): read the set it returns with for-in.
	for (id texture in [entity allTextures])
	{
		state->entityTextures.insert(oo::ObjCRef<id>(texture));
		if (visible)  state->visibleEntityTextures.insert(oo::ObjCRef<id>(texture));
	}

	std::string extra;
	if (visible)
	{
		extra += ", visible";
	}

	if (drawableSize != 0)
	{
		extra += ", drawable: " + SizeString(drawableSize);
	}

	[self writeMemStat:oo::str::format("%s: %s%s", oo::DescriptionOf([entity shortDescription]).c_str(), SizeString(entitySize).c_str(), extra.c_str())];

	state->totalEntityObjSize += entitySize;
	state->totalDrawableSize += drawableSize;

	OOLogIndent();
	if ([entity isShip])
	{
		for (id subentity in [entity subEntityEnumerator])
		{
			[self dumpEntity:subentity withState:state parentVisible:visible];
		}

		if ([entity isPlayer])
		{
			NSUInteger i, count = [entity dialMaxMissiles];
			for (i = 0; i < count; i++)
			{
				id subentity = [entity missileForPylon:i];
				if (subentity != nil)  [self dumpEntity:subentity withState:state parentVisible:NO];
			}
		}
	}
	if ([entity isPlanet])
	{
#if NEW_PLANETS
		// FIXME: dump atmosphere texture.
#else
		PlanetEntity *atmosphere = [entity atmosphere];
		if (atmosphere != nil)
		{
			[self dumpEntity:atmosphere withState:state parentVisible:visible];
		}
#endif
	}
	if ([entity isWormhole])
	{
		for (id shipInfo in [entity shipsInTransit])
		{
			ShipEntity *ship = [shipInfo objectForKey:@"ship"];
			[self dumpEntity:ship withState:state parentVisible:NO];
		}
	}
	OOLogOutdent();
}


- (void) dumpMemoryStatistics
{
	OOLog(@"debug.memStats", @"%@", @"Memory statistics:");
	OOLogIndent();

	//	Get texture retain counts before the entity dumper starts messing with them.
	const std::vector<oo::ObjCRef<OOTexture *>> allTextures = [OOTexture cxx_allTextures];
	std::map<OOTexture *, NSUInteger> textureRefCounts;

	for (const oo::ObjCRef<OOTexture *> &tex : allTextures)
	{
		// We subtract one because allTextures retains the textures.
		textureRefCounts[tex.get()] = [tex.get() retainCount] - 1;
	}

	size_t totalSize = 0;

	[self writeMemStat:"Entitites:"];
	OOLogIndent();

	EntityDumpState entityDumpState;

	for (id entity in [UNIVERSE entityList])
	{
		[self dumpEntity:entity withState:&entityDumpState parentVisible:YES];
	}
	for (id entity in [PLAYER scannedWormholes])
	{
		[self dumpEntity:entity withState:&entityDumpState parentVisible:YES];
	}

	OOLogOutdent();
	[self writeMemStat:oo::str::format("Total entity size (excluding %u entities not accounted for): %s (%s entity objects, %s drawables)",
	 gLiveEntityCount - entityDumpState.seenCount,
	 SizeString(entityDumpState.totalEntityObjSize + entityDumpState.totalDrawableSize).c_str(),
	 SizeString(entityDumpState.totalEntityObjSize).c_str(),
	 SizeString(entityDumpState.totalDrawableSize).c_str())];
	totalSize += entityDumpState.totalEntityObjSize + entityDumpState.totalDrawableSize;

	/*	Sort textures so that textures in the "recent cache" come first by age,
		followed by others.
	*/
	std::vector<oo::ObjCRef<OOTexture *>> textures = [OOTexture cxx_cachedTexturesByAge];

	for (const oo::ObjCRef<OOTexture *> &tex : allTextures)
	{
		if (std::find(textures.begin(), textures.end(), tex) == textures.end())
		{
			textures.push_back(tex);
		}
	}

	size_t totalTextureObjSize = 0;
	size_t totalTextureDataSize = 0;
	size_t visibleTextureDataSize = 0;

	[self writeMemStat:"Textures:"];
	OOLogIndent();

	for (const oo::ObjCRef<OOTexture *> &texRef : textures)
	{
		OOTexture *tex = texRef.get();
		size_t objSize = [tex oo_objectSize];
		size_t dataSize = [tex dataSize];

#if OOTEXTURE_RELOADABLE
		const char *byteCountSuffix = "";
#else
		const char *byteCountSuffix = " (* 2)";
#endif

		const char *usage = "";
		if (entityDumpState.visibleEntityTextures.count(oo::ObjCRef<id>(tex)) != 0)
		{
			visibleTextureDataSize += dataSize;	// NOT doubled if !OOTEXTURE_RELOADABLE, because we're interested in what the GPU sees.
			usage = ", visible";
		}
		else if (entityDumpState.entityTextures.count(oo::ObjCRef<id>(tex)) != 0)
		{
			usage = ", active";
		}

		const auto counted = textureRefCounts.find(tex);
		unsigned refCount = (counted != textureRefCounts.end()) ? (unsigned)counted->second : 0;

		[self writeMemStat:oo::str::format("%s: [%u refs%s] %s%s",
		 oo::DescriptionOf([tex name]).c_str(),
		 refCount,
		 usage,
		 SizeString(objSize + dataSize).c_str(),
		 byteCountSuffix)];

		totalTextureDataSize += dataSize;
		totalTextureObjSize += objSize;
	}
	totalSize += totalTextureObjSize + totalTextureDataSize;

	OOLogOutdent();

#if !OOTEXTURE_RELOADABLE
	totalTextureDataSize *= 2;
#endif
	[self writeMemStat:oo::str::format("Total texture size: %s (%s object overhead, %s data, %s visible texture data)",
	 SizeString(totalTextureObjSize + totalTextureDataSize).c_str(),
	 SizeString(totalTextureObjSize).c_str(),
	 SizeString(totalTextureDataSize).c_str(),
	 SizeString(visibleTextureDataSize).c_str())];

	totalSize += [self dumpJSMemoryStatistics];

	[self writeMemStat:oo::str::format("Total: %s", SizeString(totalSize).c_str())];

	OOLogOutdent();
}


- (size_t) dumpJSMemoryStatistics
{
	ooscript::Context context = OOJSAcquireContext();

	ooscript::Runtime runtime = ooscript::getRuntime(context);
	size_t jsSize = ooscript::getGCParameter(runtime, ooscript::GCParam::Bytes);
	size_t jsMax = ooscript::getGCParameter(runtime, ooscript::GCParam::MaxBytes);
	uint32_t jsGCCount = ooscript::getGCParameter(runtime, ooscript::GCParam::NumberOfGCs);

	OOJSRelinquishContext(context);

	[self writeMemStat:oo::str::format("JavaScript heap: %s (limit %s, %u collections to date)", SizeString(jsSize).c_str(), SizeString(jsMax).c_str(), jsGCCount)];
	return jsSize;
}


- (void) setTCPIgnoresDroppedPackets:(BOOL)flag
{
	if (_TCPIgnoresDroppedPackets != flag)
	{
		OOLog(@"debugMonitor.TCPSettings", @"The TCP console will %@ TCP packets.",
				(flag ? @"try to stay connected, ignoring dropped" : @"disconnect if an error affects"));
	}
	_TCPIgnoresDroppedPackets = flag;
}


- (BOOL) TCPIgnoresDroppedPackets
{
	return _TCPIgnoresDroppedPackets;
}


- (void) setUsingPlugInController:(BOOL)flag
{
	_usingPlugInController = flag;
}


- (BOOL) usingPlugInController
{
	return _usingPlugInController;
}


- (id)sourceCodeForFile:(in id)filePath line:(in unsigned)line	// shared selector (proposed ADR-0043)
{
	id							linesForFile = nil;
	
	linesForFile = [_sourceFiles objectForKey:filePath];
	
	if (linesForFile == nil)
	{
		linesForFile = [self loadSourceFile:filePath];
		if (linesForFile == nil)  linesForFile = [NSArray arrayWithObject:[NSString stringWithFormat:@"<Can't load file %@>", filePath]];
		
		if (_sourceFiles == nil)  _sourceFiles = [[NSMutableDictionary alloc] init];
		[_sourceFiles setObject:linesForFile forKey:filePath];
	}
	
	if ([linesForFile count] < line || line == 0)  return @"<line out of range!>";
	
	return [linesForFile objectAtIndex:line - 1];
}


- (void)disconnectDebugger:(in id<OODebuggerInterface>)debugger
				   message:(in id)message	// shared selector (proposed ADR-0043)
{
	if (debugger == nil)  return;

	if (debugger == _debugger)
	{
		[self disconnectDebuggerWithMessage:oo::OptionalString(message)];
	}
	else
	{
		OOLog(@"debugMonitor.disconnect.ignored", @"Attempt to disconnect debugger %@, which is not current debugger; ignoring.", debugger);
	}
}


#if OOLITE_GNUSTEP
- (void) applicationWillTerminate
{
	[[NSNotificationCenter defaultCenter] postNotificationName:NSApplicationWillTerminateNotification object:nil];
}
#endif


- (void)applicationWillTerminate:(NSNotification *)notification
{
	if (_configOverrides)
	{
		[[NSUserDefaults standardUserDefaults] setObject:oo::ObjectFromPList(_configOverrides) forKey:@"debug-settings-override"];
	}

	[self disconnectDebuggerWithMessage:"Oolite is terminating."];
}


@end


@implementation OODebugMonitor (Private)

- (void) setUpDebugConsoleScript
{
	ooscript::Context context = OOJSAcquireContext();
	/*	The path to the console script is saved in this here static variable
		so that we can reload it when resetting into strict mode.
		-- Ahruman 2011-02-06
	*/
	static std::optional<std::string> path;

	if (!path)
	{
		path = [ResourceManager cxx_pathForFileNamed:"oolite-debug-console.js" inFolder:std::string("Scripts")];
	}
	if (path)
	{
		// Live objects as Object nodes; a nil special-functions wrapper leaves "special" out, as the nil-terminated list did.
		oo::PList::Dict jsProps;
		jsProps["console"] = oo::PListObject(self);
		id special = JSSpecialFunctionsObjectWrapper(context);
		if (special != nil)  jsProps["special"] = oo::PListObject(special);
		_script = [[OOJSScript scriptWithPath:path properties:oo::PList(std::move(jsProps))] retain];
	}
	
	// If no script, just make console visible globally as debugConsole.
	if (_script == nil)
	{
		ooscript::Object global = [[OOJavaScriptEngine sharedEngine] globalObject];
		ooscript::defineProperty(context, global, "debugConsole", [self oo_jsValueInContext:context], NULL, NULL, ooscript::PropertyFlag::Enumerate);
	}
	
	OOJSRelinquishContext(context);
}


- (void) javaScriptEngineWillReset:(NSNotification *)notification
{
	DESTROY(_script);
	_jsSelf = NULL;
	
	OOJSConsoleDestroy();
}


- (void)disconnectDebuggerWithMessage:(const std::optional<std::string> &)message
{
	@try
	{
		[_debugger disconnectDebugMonitor:self message:oo::NSStringOrNil(message)];
	}
	@catch (NSException *exception)
	{
		OOLog(@"debugMonitor.debuggerConnection.exception", @"Exception while attempting to disconnect debugger: %@ -- %@", [exception name], [exception reason]);
	}
	
	id debugger = _debugger;
	_debugger = nil;
	[debugger release];
}


- (oo::PList)mergedConfiguration
{
	oo::PList::Dict				result;

	if (const oo::PList::Dict *entries = _configFromOXPs.getIf<oo::PList::Dict>())  result = *entries;
	if (const oo::PList::Dict *entries = _configOverrides.getIf<oo::PList::Dict>())
	{
		for (const auto &[key, value] : *entries)  result[key] = value;
	}

	return oo::PList(std::move(result));
}


- (NSArray *)loadSourceFile:(NSString *)filePath
{
	NSString					*contents = nil;
	NSArray						*lines = nil;
	
	if (filePath == nil)  return nil;
	
	contents = [NSString stringWithContentsOfUnicodeFile:filePath];
	if (contents == nil)  return nil;
	
	/*	Extract lines from file.
FIXME: this works with CRLF and LF, but not CR.
		*/
	lines = [contents componentsSeparatedByString:@"\n"];
	return lines;
}


- (oo::PList)normalizeConfigDictionary:(const oo::PList &)dictionary
{
	oo::PList::Dict			result;

	// Order-free: builds another map.
	if (const oo::PList::Dict *entries = dictionary.getIf<oo::PList::Dict>())
	{
		for (const auto &[key, value] : *entries)
		{
			oo::PList normalized = [self normalizeConfigValue:value forKey:key];
			if (normalized)  result[key] = std::move(normalized);
		}
	}

	return oo::PList(std::move(result));
}


- (oo::PList)normalizeConfigValue:(const oo::PList &)value forKey:(const std::string &)key
{
	OOColor					*color = nil;
	BOOL					boolValue;

	if (value)
	{
		if (oo::str::hasSuffix(key, "-color") || oo::str::hasSuffix(key, "-colour"))
		{
			// OOColor reads the same object; the normalized array holds +numberWithFloat: values.
			color = [OOColor colorWithDescription:oo::ObjectFromPList(value)];
			if (color == nil)  return oo::PList();
			oo::PList::Array components;
			for (float component : [color cxx_normalizedArray])  components.push_back(oo::PList::singleReal(component));
			return oo::PList(std::move(components));
		}
		else if (oo::str::hasPrefix(key, "show-console"))
		{
			boolValue = OOBooleanFromObject(oo::ObjectFromPList(value), NO);
			return oo::PList(static_cast<bool>(boolValue));
		}
	}

	return value;
}


- (oneway void)jsEngine:(in byref OOJavaScriptEngine *)engine
				context:(in ooscript::Context)context
				  error:(in ooscript::ErrorReport *)errorReport
			  stackSkip:(in unsigned)stackSkip
		showingLocation:(in BOOL)showLocation
			withMessage:(in NSString *)message
{
	NSString					*colorKey = nil;
	NSString					*prefix = nil;
	NSString					*filePath = nil;
	NSString					*sourceLine = nil;
	NSString					*scriptLine = nil;
	NSMutableString				*formattedMessage = nil;
	NSRange						emphasisRange;
	NSString					*showKey = nil;
	
	if (_debugger == nil)  return;
	
	if (errorReport->flags & static_cast<unsigned>(ooscript::ReportFlag::Warning))
	{
		colorKey = @"warning";
		prefix = @"Warning";
	}
	else if (errorReport->flags & static_cast<unsigned>(ooscript::ReportFlag::Exception))
	{
		colorKey = @"exception";
		prefix = @"Exception";
	}
	else
	{
		colorKey = @"error";
		prefix = @"Error";
	}
	
	if (errorReport->flags & static_cast<unsigned>(ooscript::ReportFlag::Strict))
	{
		prefix = [prefix stringByAppendingString:@" (strict mode)"];
	}
	
	// Prefix and subsequent colon should be bold:
	emphasisRange = NSMakeRange(0, [prefix length] + 1);
	
	formattedMessage = [NSMutableString stringWithFormat:@"%@: %@", prefix, message];
	
	// Note that the "active script" isn't necessarily the one causing the
	// error, since one script can call another's methods.
	
	// avoid windows DEP exceptions!
	OOJSScript *thisScript = [[OOJSScript currentlyRunningScript] weakRetain];
	scriptLine = [[thisScript weakRefUnderlyingObject] displayName];
	[thisScript release];
	
	if (scriptLine != nil)
	{
		[formattedMessage appendFormat:@"\n    Active script: %@", scriptLine];
	}
	
	if (showLocation && stackSkip == 0)
	{
		// Append file name and line
		if (errorReport->filename != NULL)  filePath = [NSString stringWithUTF8String:errorReport->filename];
		if ([filePath length] != 0)
		{
			[formattedMessage appendFormat:@"\n    %@, line %u", [filePath lastPathComponent], errorReport->lineno];
			
			// Append source code
			sourceLine = [self sourceCodeForFile:filePath line:errorReport->lineno];
			if (sourceLine != nil)
			{
				[formattedMessage appendFormat:@":\n    %@", sourceLine];
			}
		}
	}
	
	[self appendJSConsoleLine:formattedMessage
					 colorKey:colorKey
				emphasisRange:emphasisRange];
	
	if (errorReport->flags & static_cast<unsigned>(ooscript::ReportFlag::Warning))  showKey = @"show-console-on-warning";
	else  showKey = @"show-console-on-error";	// if not a warning, it's a proper error.
	if (OOBooleanFromObject([self configurationValueForKey:showKey], NO))
	{
		[self showJSConsole];
	}
}


- (oneway void)jsEngine:(in byref OOJavaScriptEngine *)engine
				context:(in ooscript::Context)context
			 logMessage:(in NSString *)message
				ofClass:(in NSString *)messageClass
{
	[self appendJSConsoleLine:message colorKey:@"log"];
	if (OOBooleanFromObject([self configurationValueForKey:@"show-console-on-log"], NO))
	{
		[self showJSConsole];
	}
}


- (ooscript::Value)oo_jsValueInContext:(ooscript::Context)context
{
	if (_jsSelf == NULL)
	{
		_jsSelf = DebugMonitorToJSConsole(context, self);
		if (_jsSelf != NULL)
		{
			if (!OOJSAddGCObjectRoot(context, &_jsSelf, "debug console"))
			{
				_jsSelf = NULL;
			}
		}
	}
	
	if (_jsSelf != NULL)  return ooscript::objectValue(_jsSelf);
	else  return ooscript::nullValue();
}

@end


@implementation OODebugMonitor (Singleton)

/*	Canonical singleton boilerplate.
See Cocoa Fundamentals Guide: Creating a Singleton Instance.
See also +sharedDebugMonitor above.

NOTE: assumes single-threaded access.
*/

+ (id)allocWithZone:(OOZone *)inZone
{
	if (sSingleton == nil)
	{
		sSingleton = [super allocWithZone:inZone];
		return sSingleton;
	}
	return nil;
}


- (id)copyWithZone:(OOZone *)inZone
{
	return self;
}


- (id)retain
{
	return self;
}


- (NSUInteger)retainCount
{
	return UINT_MAX;
}


- (void)release
{}


- (id)autorelease
{
	return self;
}

@end

#endif /* NDEBUG */
