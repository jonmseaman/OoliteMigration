/*

OOSDLJoystickManager.m
By Dylan Smith

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

#import "OOSDLJoystickManager.h"
#include "oofnd/Log.hpp"
#include "oofnd/String.hpp"
#import "OOStringBridge.h"

#define kOOLogUnconvertedNSLog @"unclassified.OOSDLJoystickManager"


@implementation OOSDLJoystickManager

- (id) init
{
	int i;

	std::map<std::string, int, std::less<>> idMap;

	// Find and open the sticks. Make sure that we don't fail if more joysticks than MAX_STICKS are detected.
	SDL_JoystickID *joystickIds = SDL_GetJoysticks(&stickCount);
	OO_LOG("joystick.init", "Number of joysticks detected: {}", stickCount);
	if (stickCount > MAX_STICKS)
	{
		stickCount = MAX_STICKS;
		OO_LOG("joystick.init", "Number of joysticks detected exceeds maximum number of joysticks allowed. Setting number of active joysticks to {}.", MAX_STICKS);
	}
	if(stickCount)
	{
		for(i = 0; i < stickCount; i++)
		{
			// it's doubtful MAX_STICKS will ever get exceeded, but
			// we need to be defensive.
			if(i > MAX_STICKS)
				break;

			stick[i]=SDL_OpenJoystick(joystickIds[i]);
			if(stick[i])
			{
				idMap[oo::str::format("%d", joystickIds[i])] = i;
			}
			else
			{
				OO_LOG("joystick.init", "Failed to open joystick #{}", i);
			}
		}
		SDL_SetJoystickEventsEnabled(true);
	}
	SDL_free(joystickIds);
	joystickIdMap = std::move(idMap);
	return [super init];
}


- (void) dealloc
{
	[super dealloc];
}


- (NSInteger) getJoystickIndexFromId: (SDL_JoystickID) joystickId
{
	const auto index = joystickIdMap.find(oo::str::format("%d", joystickId));
	if (index != joystickIdMap.end())
	{
		return index->second;
	}
	return -1;
}


- (JoyAxisEvent) makeJoyAxisEvent: (SDL_JoyAxisEvent*) sdlevt
{
	JoyAxisEvent evt;
	evt.type = sdlevt->type;
	evt.which = [self getJoystickIndexFromId: sdlevt->which];
	evt.axis = sdlevt->axis;
	evt.value = sdlevt->value;
	return evt;
}

- (JoyButtonEvent) makeJoyButtonEvent: (SDL_JoyButtonEvent*) sdlevt
{
	JoyButtonEvent evt;
	evt.type = sdlevt->type;
	evt.which = [self getJoystickIndexFromId: sdlevt->which];
	evt.button = sdlevt->button;
	evt.down = sdlevt->down;
	return evt;
}


- (JoyHatEvent) makeJoyHatEvent: (SDL_JoyHatEvent*) sdlevt
{
	JoyHatEvent evt;
	evt.type = sdlevt->type;
	evt.which = [self getJoystickIndexFromId: sdlevt->which];
	evt.hat = sdlevt->hat;
	evt.value = sdlevt->value;
	return evt;
}


- (BOOL) handleSDLEvent: (SDL_Event *)evt
{
	BOOL rc=NO;
	switch(evt->type)
	{
		case SDL_EVENT_GAMEPAD_AXIS_MOTION:
		case SDL_EVENT_JOYSTICK_AXIS_MOTION:
		{
			JoyAxisEvent joyEvt = [self makeJoyAxisEvent: (SDL_JoyAxisEvent*)evt];
			if (joyEvt.which >= 0)
			{
				[self decodeAxisEvent: &joyEvt];
				rc=YES;
			}
			break;
		}

		case SDL_EVENT_GAMEPAD_BUTTON_DOWN:
		case SDL_EVENT_GAMEPAD_BUTTON_UP:
		case SDL_EVENT_JOYSTICK_BUTTON_DOWN:
		case SDL_EVENT_JOYSTICK_BUTTON_UP:
		{
			JoyButtonEvent joyEvt = [self makeJoyButtonEvent: (SDL_JoyButtonEvent*)evt];
			if (joyEvt.which >= 0)
			{
				[self decodeButtonEvent: &joyEvt];
				rc=YES;
			}
			break;
		}

		case SDL_EVENT_JOYSTICK_HAT_MOTION:
		{
			JoyHatEvent joyEvt = [self makeJoyHatEvent: (SDL_JoyHatEvent*)evt];
			if (joyEvt.which >= 0)
			{
				[self decodeHatEvent: &joyEvt];
				rc=YES;
			}
			break;
		}

		default:
			OO_LOG("handleSDLEvent.unknownEvent", "{}", "JoystickHandler was sent an event it doesn't know");
	}
	return rc;
}


// Overrides

- (NSUInteger) joystickCount
{
	return stickCount;
}


- (id) nameOfJoystick:(NSUInteger)stickNumber	// shared selector (proposed ADR-0043)
{
	if (stickNumber >= stickCount)  return @"(unknown joystick)";
	const char *name = SDL_GetJoystickName(stick[stickNumber]);
	return (name != NULL) ? oo::NSStringFrom(name) : nil;	// no string for a NULL name, as before
}


- (int16_t) getAxisWithStick:(NSUInteger) stickNum axis:(NSUInteger) axisNum 
{
	return SDL_GetJoystickAxis(stick[stickNum], axisNum);
}



@end
