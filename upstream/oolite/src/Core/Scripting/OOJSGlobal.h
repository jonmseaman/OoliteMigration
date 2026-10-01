/*

OOJSGlobal.h

JavaScript global object.


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

#import "OOCocoa.h"
#include "ooscript/JSEngine.hpp"
#ifdef __cplusplus
extern "C" {
#endif

void CreateOOJSGlobal(ooscript::Context context, ooscript::Object *outGlobal);
void SetUpOOJSGlobal(ooscript::Context context, ooscript::Object global);

#ifdef __cplusplus
}
#endif


/*	-[OOJavaScriptEngine sendMonitorLogMessage:withMessageClass:inContext:], which OOJSGlobal.mm
	sends from log(); defined, with the category that declares the selector, in
	OOJSGlobal+ObjCBridge.mm when OOJSENGINE_MONITOR_SUPPORT is on (proposed ADR-0056 amendments
	oo-9ht.66 and oo-6ia4 item 6).
*/
#include "oofnd/StdLib.hpp"
void OOJSGlobalSendMonitorLogMessage(const std::optional<std::string> &message, const std::optional<std::string> &messageClass, ooscript::Context context);
