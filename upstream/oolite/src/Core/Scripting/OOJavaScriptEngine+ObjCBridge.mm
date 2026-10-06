/*

OOJavaScriptEngine+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, bead oo-10qz): the Objective-C OOJavaScriptEngine facade's own
methods (see OOJavaScriptEngine+ObjCBridge.h). Slice 1's selectors forward to their C++ members in
one line each; slice 2's are still Objective-C methods of the facade in OOJavaScriptEngine.mm, so
the facade's crossing and lifetime methods are a category here (amendment oo-10qz of ADR-0056).
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

// The engine's internal monitor sends (OOJavaScriptEngine.mm's ReportJSError(), slice 2, and
// OOJSGlobalSendMonitorLogMessage() in OOJSGlobal+ObjCBridge.mm, amendment oo-6ia4 item 6), which
// declare the category themselves.
@interface OOJavaScriptEngine (OOMonitorSupportInternal)

- (void)sendMonitorError:(ooscript::ErrorReport *)errorReport
			 withMessage:(const std::string &)message
			   inContext:(ooscript::Context)context;

// nullopt is meaningful to the monitor (Log() with a null message; no class for Log()).
- (void)sendMonitorLogMessage:(const std::optional<std::string> &)message
			 withMessageClass:(const std::optional<std::string> &)messageClass
					inContext:(ooscript::Context)context;

@end

#endif


@implementation OOJavaScriptEngine (OOJavaScriptEngineShell)

// Inside an @implementation of the class for the private ivar.
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


- (void) runMissionCallback								{ _cxxEngine->runMissionCallback(); }
- (BOOL) reset											{ return _cxxEngine->reset(); }

@end


#if OOJSENGINE_MONITOR_SUPPORT

@implementation OOJavaScriptEngine (OOMonitorSupport)

- (void) setMonitor:(id<OOJavaScriptEngineMonitor>)monitor	{ _cxxEngine->setMonitor(monitor); }

@end


@implementation OOJavaScriptEngine (OOMonitorSupportInternal)

- (void) sendMonitorError:(ooscript::ErrorReport *)errorReport withMessage:(const std::string &)message inContext:(ooscript::Context)context
{
	_cxxEngine->sendMonitorError(errorReport, message, context);
}


- (void) sendMonitorLogMessage:(const std::optional<std::string> &)message withMessageClass:(const std::optional<std::string> &)messageClass inContext:(ooscript::Context)context
{
	_cxxEngine->sendMonitorLogMessage(message, messageClass, context);
}

@end

#endif
