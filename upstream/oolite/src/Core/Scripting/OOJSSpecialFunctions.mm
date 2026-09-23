/*

OOJSSpecialFunctions.m


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

#import "OOJSSpecialFunctions.h"


static bool SpecialJSWarning(ooscript::Context context, ooscript::CallArgs &oojsArgs);
#ifndef NDEBUG
static bool SpecialMarkConsoleEntryPoint(ooscript::Context context, ooscript::CallArgs &oojsArgs);
#endif


static ooscript::FunctionSpec sSpecialFunctionsMethods[] =
{
	// JS name					Function						min args
	{ "jsWarning",				SpecialJSWarning,				1 },
#ifndef NDEBUG
	{ "markConsoleEntryPoint",	SpecialMarkConsoleEntryPoint,	0 },
#endif
	{ 0 }
};


void InitOOJSSpecialFunctions(ooscript::Context context, ooscript::Object global)
{
}


OOJSValue *JSSpecialFunctionsObjectWrapper(ooscript::Context context)
{
	/*
		Special object is created on the fly so it can be GCed (the debug
		console script keeps a reference to its copy, but the prefix script
		doesn't) and so we don't need to clean up a root on JS engine reset.
		-- Ahruman 2011-03-30
	*/
	
	ooscript::Object special = NULL;
	OOJSAddGCObjectRoot(context, &special, "OOJSSpecialFunctions");
	
	special = ooscript::newObject(context, NULL, NULL, NULL);
	ooscript::defineFunctions(context, special, sSpecialFunctionsMethods);
	ooscript::freezeObject(context, special);
	
	OOJSValue *result = [OOJSValue valueWithJSObject:special inContext:context];
	
	ooscript::removeObjectRoot(context, &special);
	
	return result;
}


static bool SpecialJSWarning(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_PROFILE_ENTER	// These functions are exception-safe
	
	if (EXPECT_NOT(oojsArgs.count() < 1))
	{
		OOJSReportBadArguments(context, @"special", @"jsWarning", oojsArgs.count(), OOJS_ARGV, nil, @"string");
		return NO;
	}
	
	OOJSSetWarningOrErrorStackSkip(1);
	OOJSReportWarning(context, @"%@", OOStringFromJSValue(context, OOJS_ARGV[0]));
	OOJSSetWarningOrErrorStackSkip(0);
	
	OOJS_RETURN_VOID;
	
	OOJS_PROFILE_EXIT
}


#ifndef NDEBUG
static bool SpecialMarkConsoleEntryPoint(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	// First stack frame will be in eval() in console.script.evaluate(), unless someone is playing silly buggers.
	
	ooscript::StackFrame frame = NULL;
	if (ooscript::frameIterator(context, &frame) != NULL)
	{
		OOJSMarkConsoleEvalLocation(context, frame);
	}
	
	OOJS_RETURN_VOID;
}
#endif
