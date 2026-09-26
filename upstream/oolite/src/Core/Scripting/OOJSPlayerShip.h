/*

OOJSPlayerShip.h

JavaScript proxy for the player's ship.
While the player and player's ship are not differentiated in Oolite, such a
separation makes more sense conceptually and design-wise, and we might want to
make it that way in the future. The scripting interface anticipates this by
using two separate objects for the player and player's ship.

The -javaScriptValue of the PlayerEntity is the player's ship.


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
@class PlayerEntity;


#ifdef __cplusplus
extern "C" {
#endif

void InitOOJSPlayerShip(ooscript::Context context, ooscript::Object global);

ooscript::ClassDef *JSPlayerShipClass(void);
ooscript::Object JSPlayerShipPrototype(void);
ooscript::Object JSPlayerShipObject(void);

#ifdef __cplusplus
}
#endif
