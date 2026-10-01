/*

OOTextureLoader+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, amendments oo-whzh, oo-bj8 and oo-zl36): the Objective-C
OOTextureLoader, a facade over the C++ cxx::OOTextureLoader (OOTextureLoader.h), for its callers
(the textures, the emission map generator, the OXP verifier), for the work manager, which holds a
loader as an Objective-C task, and for the loaders not converted yet (OOPNGTextureLoader,
OOPixMapTextureLoader, OOTextureGenerator and the generators under it). Its interface is the one
OOTextureLoader.h declared before the conversion, copied exactly but for its ivars: the subclasses
read the root's state through _cxxLoader. Imported as the last line of OOTextureLoader.h; do not
import it directly.

It is a hierarchy root's facade, as OOTexture+ObjCBridge.h is: an Objective-C subclass instance
is its own facade and its C++ part is an adapter whose virtual members message it; a C++ loader's
facade is made by oo::ToObjC (one live one per loader, oo::ObjCPeers).

oo::ToObjC(oo::ToCxx(l)) == l for both kinds. Never add to this file; converted code does not
message the facade. Deleted by its deletion bead once every caller and every loader is C++.


Copyright (C) 2007-2014 Jens Ayton

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

#ifndef OOTEXTURELOADER_OBJCBRIDGE_H
#define OOTEXTURELOADER_OBJCBRIDGE_H


@interface OOTextureLoader: OOObject <OOAsyncWorkTask>
{
@protected
	// The C++ loader: an Objective-C subclass's adapter, or a C++ loader. The subclasses read the
	// root's state through it (_cxxLoader->_data), as they read the ivars (amendment oo-bj8 item 2).
	oo::Ref<cxx::OOTextureLoader>	_cxxLoader;
}

+ (id)cxx_loaderWithPath:(const std::optional<std::string> &)path options:(uint32_t)options;

/*	Convenience method to load images not destined for normal texture use.
	Specifier is a string or a dictionary as with textures. ExtraOptions is
	ored into the option flags interpreted from the specifier. Folder is the
	directory to look in, typically Textures or Images. Options in the
	specifier which are applied at the OOTexture level will be ignored.
*/
+ (id)cxx_loaderWithTextureSpecifier:(const oo::PList &)specifier extraOptions:(uint32_t)extraOptions folder:(const std::optional<std::string> &)folder;

- (BOOL)isReady;

/*	Return value indicates success. This may only be called once (subsequent
	attempts will return failure), and only on the main thread.
*/
- (BOOL) getResult:(OOPixMap *)result
			format:(OOTextureDataFormat *)outFormat
	 originalWidth:(uint32_t *)outWidth
	originalHeight:(uint32_t *)outHeight;

/*	Hopefully-unique string for texture loader; analagous, but not identical,
	to corresponding texture cacheKey.
*/
- (std::optional<std::string>) cxx_cacheKey;



/*** Subclass interface; do not use on pain of pain. Unless you're subclassing. ***/

// Subclasses shouldn't do much on init, because of the whole asynchronous thing.
- (id)cxx_initWithPath:(const std::optional<std::string> &)path options:(uint32_t)options OO_RETURNS_RETAINED;

- (std::optional<std::string>)cxx_path;

/*	Load data, setting up _data, _format, _width, and _height; also _rowBytes
	if it's not _width * OOTextureComponentsForFormat(_format), and
	_originalWidth/_originalHeight if _width and _height for some reason aren't
	the original pixel dimensions.
	
	Thread-safety concerns: this will be called in a worker thread, and there
	may be several worker threads. The caller takes responsibility for
	autorelease pools and exception safety.
	
	Superclass will handle scaling and mip-map generation. Data must be
	allocated with malloc() family.
*/
- (void)loadTexture;

@end


@interface OOTextureLoader (OOObjCBridge)

/*	For the facades of converted subclasses: the facade made by alloc and an initialiser of the
	subclass adopts its new C++ loader and is that loader's peer (the one oo::ToObjC answers).
*/
- (id) initWithNewCxxLoader:(const oo::Ref<cxx::OOTextureLoader> &)loader;

@end


namespace oo {

// The loader's Objective-C object: an Objective-C loader itself, else a C++ loader's live facade
// (or a new one); autoreleased. nil for null.
OOTextureLoader *ToObjC(cxx::OOTextureLoader *loader);
inline OOTextureLoader *ToObjC(const Ref<cxx::OOTextureLoader> &loader)  { return ToObjC(loader.get()); }

// The C++ loader behind an Objective-C one, borrowed (the Objective-C object retains it); null for nil.
cxx::OOTextureLoader *ToCxx(OOTextureLoader *loader);

}	// namespace oo

#endif	// OOTEXTURELOADER_OBJCBRIDGE_H
