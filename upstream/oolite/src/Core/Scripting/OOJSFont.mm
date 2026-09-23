/*

OOJSFont.mm


Copyright (C) 2011-2013 Jens Ayton

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

#import "OOJSFont.h"
#import "OOJavaScriptEngine.h"
#import "HeadUpDisplay.h"

#include "ooscript/JSEngine.hpp"

/*
	Retargeted onto the ooscript façade (JSEngine.hpp) the way OOJSVector.mm does it (bead
	oo-sdz, the sweep exemplar) and OOJSClock.mm does it for a single global object with no
	class of its own: the engine's DefineObject and DefineFunction entry points become
	ooscript::defineObject and ooscript::defineFunction. This file has no class hooks, no
	property table and no argument-marshalling beyond the OOJS_* macros (OOJS_NATIVE_ENTER,
	OOJS_ARGV, OOJS_RETURN_DOUBLE), which expand to the CallArgs accessors of the façade
	native signature. `this` is not used here, so no renaming is required, but the file is still
	compiled as Objective-C++ (ADR-0001) because it now includes JSEngine.hpp.
*/
namespace ooscript { }
using ooscript::Context;
using ooscript::Object;
using ooscript::CallArgs;
using ooscript::PropertyFlag;

namespace {
static bool FontMeasureString(ooscript::Context context, ooscript::CallArgs &oojsArgs);
} // namespace


namespace {
constexpr PropertyFlag kFontObjectFlags = PropertyFlag::Permanent | PropertyFlag::Enumerate | PropertyFlag::ReadOnly;
} // namespace
namespace {
constexpr PropertyFlag kFontMethodFlags = PropertyFlag::Permanent | PropertyFlag::ReadOnly;
} // namespace


// MARK: Public

void InitOOJSFont(ooscript::Context context, ooscript::Object global)
{
	Object fontObject = ooscript::defineObject((context), (global), "defaultFont", nullptr, nullptr, kFontObjectFlags);
	ooscript::defineFunction((context), fontObject, "measureString", FontMeasureString, 1, kFontMethodFlags);
}


// MARK: Methods

namespace {
static bool FontMeasureString(ooscript::Context context, ooscript::CallArgs &oojsArgs)
{
	OOJS_NATIVE_ENTER(context)
	
	if (EXPECT_NOT(oojsArgs.count() < 1) || ooscript::isUndefined(OOJS_ARGV[0]))
	{
		ooscript::Value undefined = ooscript::undefinedValue();
		OOJSReportBadArguments(context, nil, @"defaultFont.measureString", MIN(oojsArgs.count(), 1U), &undefined, nil, @"string");
		return NO;
	}
	
	OOJS_RETURN_DOUBLE(OOStringWidthInEm(OOStringFromJSValue(context, OOJS_ARGV[0])));
	
	OOJS_NATIVE_EXIT
}
} // namespace
