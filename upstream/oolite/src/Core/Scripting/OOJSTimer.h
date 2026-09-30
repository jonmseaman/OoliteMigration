/*

OOJSTimer.h

JavaScript timer class.

C++20 since bead oo-kdyh (proposed ADR-0056; amendment oo-ppc for the binding), converted with
its superclass OOScriptTimer. cxx::OOJSTimer has no caller outside OOJSTimer.mm, but the engine
messages the object in a Timer's private slot by selector (-oo_jsValueInContext:,
-cxx_oo_jsClassName) and the timer queue holds it, so it keeps an Objective-C facade,
OOJSTimer+ObjCBridge.h, imported at the end of this header: the facade of the root's peer table,
of this class, with no ivars (ADR-0056 amendment oo-up4b item 3).


Oolite
Copyright (C) 2004-2013 Giles C Williams and contributors

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

#ifndef OOJSTIMER_H
#define OOJSTIMER_H

#import "OOScriptTimer.h"
#include "ooscript/JSEngine.hpp"
#include "oofnd/objc/OOObjCRef.h"

@class OOJSScript;


namespace cxx {

class OOJSTimer : public OOScriptTimer
{
public:
	// [[OOJSTimer alloc] initWithDelay:interval:context:function:this:], for the Timer
	// constructor: null where the initialiser answered nil.
	static oo::Ref<OOJSTimer> timerWithDelay(OOTimeAbsolute delay, OOTimeDelta interval, ooscript::Context context, ooscript::Value function, ooscript::Object jsThis);

	~OOJSTimer() override;

	std::optional<std::string> descriptionComponents() const override;
	std::optional<std::string> oo_jsClassName();

	void timerFired() override;

	ooscript::Value oo_jsValueInContext(ooscript::Context context);

private:
	OOJSTimer() = default;

	bool initWithDelay(OOTimeAbsolute delay, OOTimeDelta interval, ooscript::Context context, ooscript::Value function, ooscript::Object jsThis);
	void deleteJSPointers();

	ooscript::Value				_function = {};
	ooscript::Object _jsThis = {};	// The object that is 'this' in the function call.

	oo::ObjCRef<OOJSScript *>	_owningScript;	// a weak reference (-weakRetain)

	ooscript::Object _jsSelf = {};	// The JS Timer object proxy for this OOJSTimer.
};

}	// namespace cxx


#ifdef __cplusplus
extern "C" {
#endif

void InitOOJSTimer(ooscript::Context context, ooscript::Object global);

#ifdef __cplusplus
}
#endif


// Transitional: the Objective-C OOJSTimer facade. Deleted, with namespace cxx above, by the
// bridge's deletion bead.
#import "OOJSTimer+ObjCBridge.h"

#endif	// OOJSTIMER_H
