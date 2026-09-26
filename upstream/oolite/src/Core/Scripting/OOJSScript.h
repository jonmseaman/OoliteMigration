/*

OOJSScript.h

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


#import "OOScript.h"
#import "OOJavaScriptEngine.h"

// The script property that holds the identifier of the manifest the script was loaded under.
inline constexpr char kLocalManifestProperty[] = "oolite_manifest_identifier";

@interface OOJSScript: OOScript <OOWeakReferenceSupport>
{
@private
	ooscript::Object _jsSelf;
	
	std::optional<std::string>	name;
	std::optional<std::string>	description;
	std::optional<std::string>	version;
	std::optional<std::string>	filePath;
	
	OOWeakReference		*weakSelf;
}

// path nullopt is nil (the script is then named after its address); properties may hold live objects.
+ (id) scriptWithPath:(const std::optional<std::string> &)path properties:(const oo::PList &)properties;

- (id) initWithPath:(const std::optional<std::string> &)path properties:(const oo::PList &)properties;

+ (OOJSScript *) currentlyRunningScript;
+ (std::vector<oo::ObjCRef<OOJSScript *>>) scriptStack;

/*	External manipulation of acrtive script stack. Used, for instance, by
	timers. Failing to balance these will crash!
	Passing a nil script is valid for cases where JS is used which is not
	attached to a specific script.
*/
+ (void) pushScript:(OOJSScript *)script;
+ (void) popScript:(OOJSScript *)script;

/*	Call a method.
	Requires a request on context.
	outResult may be NULL.
*/
- (BOOL) callMethod:(ooscript::PropertyId)methodID
		  inContext:(ooscript::Context)context
	  withArguments:(ooscript::Value *)argv count:(int)argc
			 result:(ooscript::Value *)outResult;

- (id) propertyWithID:(ooscript::PropertyId)propID inContext:(ooscript::Context)context;
// Set a property which can be modified or deleted by the script.
- (BOOL) setProperty:(id)value withID:(ooscript::PropertyId)propID inContext:(ooscript::Context)context;
// Set a special property which cannot be modified or deleted by the script.
- (BOOL) defineProperty:(id)value withID:(ooscript::PropertyId)propID inContext:(ooscript::Context)context;

- (id) propertyNamed:(const std::string &)name;
- (BOOL) setProperty:(id)value named:(const std::string &)name;
- (BOOL) defineProperty:(id)value named:(const std::string &)name;

@end


@interface OOScript (JavaScriptEvents)

// For simplicity, calling methods on non-JS scripts works but does nothing.
- (BOOL) callMethod:(ooscript::PropertyId)methodID
		  inContext:(ooscript::Context)context
	  withArguments:(ooscript::Value *)argv count:(int)argc
			 result:(ooscript::Value *)outResult;

@end


OOJS_EXTERN_C void InitOOJSScript(ooscript::Context context, ooscript::Object global);

