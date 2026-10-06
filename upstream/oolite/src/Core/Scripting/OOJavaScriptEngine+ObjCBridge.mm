/*

OOJavaScriptEngine+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, beads oo-10qz, oo-903c and oo-elta): the Objective-C OOJavaScriptEngine
facade (see OOJavaScriptEngine+ObjCBridge.h). Every method forwards to its C++ member in one line.
Then the OONull facade, the categories on OOObject and OONativeVector that forward to the free
functions holding their bodies (amendment oo-ppc item 3), and the one-line bridges of OOJavaScriptEngine.mm's free functions (amendment oo-9ht.139).
Deleted with OOJavaScriptEngine+ObjCBridge.h.

JavaScript support for Oolite
Copyright (C) 2007-2013 David Taylor and Jens Ayton.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

*/

#import "OOJavaScriptEngine.h"
#import "ResourceManager.h"
#import "OOScript.h"
#import "OOWeakReference.h"
#import "OOVector.h"
#include "oofnd/objc/OOException.h"

#include "oofnd/objc/OOObjCPeer.h"


namespace {

// Never destroyed: a facade may be released while the process exits.
oo::ObjCPeers &Peers()
{
	static oo::ObjCPeers *peers = new oo::ObjCPeers;
	return *peers;
}

}	// namespace


@interface OOJavaScriptEngine (OOObjCBridgePrivate)

- (id) initWithCxxEngine:(cxx::OOJavaScriptEngine *)engine;

@end


#if OOJSENGINE_MONITOR_SUPPORT

// The engine's internal monitor send of OOJSGlobalSendMonitorLogMessage() in OOJSGlobal+ObjCBridge.mm
// (amendment oo-6ia4 item 6), which declares the category itself.
@interface OOJavaScriptEngine (OOMonitorSupportInternal)

// nullopt is meaningful to the monitor (Log() with a null message; no class for Log()).
- (void)sendMonitorLogMessage:(const std::optional<std::string> &)message
			 withMessageClass:(const std::optional<std::string> &)messageClass
					inContext:(ooscript::Context)context;

@end

#endif


@implementation OOJavaScriptEngine

// Inside the @implementation for the private ivar.
OOJavaScriptEngine *oo::ToObjC(cxx::OOJavaScriptEngine *engine)
{
	return Peers().peerFor(engine, [engine] { return [[OOJavaScriptEngine alloc] initWithCxxEngine:engine]; });
}


cxx::OOJavaScriptEngine *oo::ToCxx(OOJavaScriptEngine *engine)
{
	if (engine == nil)  return nullptr;
	return engine->_cxxEngine.get();
}


- (id) initWithCxxEngine:(cxx::OOJavaScriptEngine *)engine
{
	self = [super init];
	if (self != nil)  _cxxEngine = oo::Ref<cxx::OOJavaScriptEngine>(engine);
	return self;
}


- (void) dealloc
{
	Peers().forget(_cxxEngine.get());
	[super dealloc];
}


+ (OOJavaScriptEngine *) sharedEngine
{
	// One facade for the life of the process, as there was one object (amendment oo-r7m0, item 5).
	static OOJavaScriptEngine *facade = nil;
	if (facade == nil)  facade = [oo::ToObjC(cxx::OOJavaScriptEngine::sharedEngine()) retain];
	return facade;
}


- (ooscript::Object) globalObject						{ return _cxxEngine->globalObject(); }
- (void) runMissionCallback								{ _cxxEngine->runMissionCallback(); }
- (BOOL) reset											{ return _cxxEngine->reset(); }

- (BOOL) callJSFunction:(ooscript::Value)function forObject:(ooscript::Object)jsThis argc:(unsigned)argc argv:(ooscript::Value *)argv result:(ooscript::Value *)outResult
{
	return _cxxEngine->callJSFunction(function, jsThis, argc, argv, outResult);
}

- (void) removeGCObjectRoot:(ooscript::Object *)rootPtr	{ _cxxEngine->removeGCObjectRoot(rootPtr); }
- (void) removeGCValueRoot:(ooscript::Value *)rootPtr	{ _cxxEngine->removeGCValueRoot(rootPtr); }
- (void) garbageCollectionOpportunity:(BOOL)force		{ _cxxEngine->garbageCollectionOpportunity(force); }
- (BOOL) showErrorLocations								{ return _cxxEngine->showErrorLocations(); }
- (void) setShowErrorLocations:(BOOL)value				{ _cxxEngine->setShowErrorLocations(value); }
- (ooscript::ClassDef *) objectClass					{ return _cxxEngine->objectClass(); }
- (ooscript::ClassDef *) stringClass					{ return _cxxEngine->stringClass(); }
- (ooscript::ClassDef *) arrayClass						{ return _cxxEngine->arrayClass(); }
- (ooscript::ClassDef *) numberClass					{ return _cxxEngine->numberClass(); }
- (ooscript::ClassDef *) booleanClass					{ return _cxxEngine->booleanClass(); }

#ifndef NDEBUG
- (BOOL) dumpStackForErrors								{ return _cxxEngine->dumpStackForErrors(); }
- (void) setDumpStackForErrors:(BOOL)value				{ _cxxEngine->setDumpStackForErrors(value); }
- (BOOL) dumpStackForWarnings							{ return _cxxEngine->dumpStackForWarnings(); }
- (void) setDumpStackForWarnings:(BOOL)value			{ _cxxEngine->setDumpStackForWarnings(value); }
- (void) enableDebuggerStatement						{ _cxxEngine->enableDebuggerStatement(); }
#endif

@end


#if OOJSENGINE_MONITOR_SUPPORT

@implementation OOJavaScriptEngine (OOMonitorSupport)

- (void) setMonitor:(id<OOJavaScriptEngineMonitor>)monitor	{ _cxxEngine->setMonitor(monitor); }

@end


@implementation OOJavaScriptEngine (OOMonitorSupportInternal)

- (void) sendMonitorLogMessage:(const std::optional<std::string> &)message withMessageClass:(const std::optional<std::string> &)messageClass inContext:(ooscript::Context)context
{
	_cxxEngine->sendMonitorLogMessage(message, messageClass, context);
}

@end

#endif


@interface OONull (OOObjCBridgePrivate)

- (id) initWithCxxNull:(cxx::OONull *)null;

@end


@implementation OONull

// Inside the @implementation for the private ivar.
OONull *oo::ToObjC(cxx::OONull *null)
{
	// One facade for the one null, for the life of the process: collections and callers compare it
	// by identity (amendments oo-r7m0 item 5 and oo-kq7 item 2), so no peer table.
	static OONull *facade = nil;
	if (null == nullptr)  return nil;
	if (facade == nil)  facade = [[OONull alloc] initWithCxxNull:null];
	return facade;
}


cxx::OONull *oo::ToCxx(OONull *null)
{
	if (null == nil)  return nullptr;
	return null->_cxxNull.get();
}


- (id) initWithCxxNull:(cxx::OONull *)null
{
	self = [super init];
	if (self != nil)  _cxxNull = oo::Ref<cxx::OONull>(null);
	return self;
}


+ (OONull *) null										{ return oo::ToObjC(cxx::OONull::null()); }
- (id) copyWithZone:(OOZone *)zone						{ return [self retain]; }
- (std::optional<std::string>) cxx_description			{ return _cxxNull->description(); }
- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context	{ return _cxxNull->jsValueInContext(context); }

@end


// The root class's JS glue (amendment oo-ppc item 3): the bodies are in OOJavaScriptEngine.mm.
@implementation OOObject (OOJavaScriptConversion)

- (ooscript::Value) oo_jsValueInContext:(ooscript::Context)context	{ return OOObjectJSValueInContext(context); }
- (std::optional<std::string>) cxx_oo_jsClassName		{ return OOObjectJSClassName(); }
- (std::optional<std::string>) cxx_oo_jsDescription		{ return OOObjectJSDescription(self); }
- (std::optional<std::string>) cxx_oo_jsDescriptionWithClassName:(const std::optional<std::string> &)className	{ return OOObjectJSDescriptionWithClassName(self, className); }
- (void) oo_clearJSSelf:(ooscript::Object)selfVal		{ OOObjectClearJSSelf(selfVal); }

@end


@implementation OONativeVector (OOJavaScriptConversion)

- (ooscript::Value)oo_jsValueInContext:(ooscript::Context)context	{ return OONativeVectorJSValueInContext(oo::ToCxx(self), context); }

@end


oo::PList OOJavaScriptEngineDictionaryFromFilesNamed(const std::string &fileName, const std::optional<std::string> &folderName, bool mergeFiles)
{
	return [ResourceManager cxx_dictionaryFromFilesNamed:fileName inFolder:folderName andMerge:mergeFiles];
}


id OOJavaScriptEngineWeakRefUnderlyingObject(id object)
{
	return [object weakRefUnderlyingObject];
}


std::optional<std::string> OOJavaScriptEngineDisplayName(id script)
{
	return [script displayName];
}


Class OOJavaScriptEngineClass(id object)
{
	return [object class];
}


ooscript::Value OOJavaScriptEngineJSValueInContext(id object, ooscript::Context context)
{
	return [object oo_jsValueInContext:context];
}


std::optional<std::string> OOJavaScriptEngineJSClassName(id object)
{
	return [object cxx_oo_jsClassName];
}


std::optional<std::string> OOJavaScriptEngineJSDescriptionWithClassName(id object, const std::optional<std::string> &className)
{
	return [object cxx_oo_jsDescriptionWithClassName:className];
}


std::optional<std::string> OOJavaScriptEngineDescriptionComponents(id object)
{
	return [object cxx_descriptionComponents];
}


Class OOJavaScriptEngineOOObjectClass()
{
	return [OOObject class];
}


bool OOJavaScriptEngineCaughtOOException(std::string &name, std::string &reason)
{
	try
	{
		throw;
	}
	catch (id exception)
	{
		if (![exception isKindOfClass:[OOException class]])  return false;
		name = [(OOException *)exception name];
		reason = [(OOException *)exception reason];
		return true;
	}
	catch (...)
	{
		return false;	// not an Objective-C exception: not what @catch (OOException *) caught
	}
}
