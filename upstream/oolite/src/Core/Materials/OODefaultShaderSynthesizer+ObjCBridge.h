/*

OODefaultShaderSynthesizer+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056, beads oo-bm1q and oo-bhxc): the Objective-C OODefaultShaderSynthesizer, a
facade over the C++ cxx::OODefaultShaderSynthesizer (OODefaultShaderSynthesizer.h). The class was
private to OODefaultShaderSynthesizer.mm; slice 1 (oo-bm1q) made it C++ with this facade for its
shader stages, and slice 2 (oo-bhxc) made the stages members, so nothing sends the facade but its
test (test_OODefaultShaderSynthesizer's facade contract). Its interface is the public part of the
one the .mm declared, copied exactly (same selectors, same types); each method forwards to its C++
member. Imported as the last line of OODefaultShaderSynthesizer.h; do not import it directly.
Never add to this file. Deleted by its deletion bead (oo-9ht.134).

Copyright © 2011-2013 Jens Ayton

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

*/

#ifndef OODEFAULTSHADERSYNTHESIZER_OBJCBRIDGE_H
#define OODEFAULTSHADERSYNTHESIZER_OBJCBRIDGE_H

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"


@interface OODefaultShaderSynthesizer: OOObject
{
@private
	oo::Ref<cxx::OODefaultShaderSynthesizer>	_cxxSynthesizer;
}

- (id) initWithMaterialConfiguration:(const oo::PList &)configuration
						 materialKey:(const std::optional<std::string> &)materialKey
						  entityName:(const std::optional<std::string> &)name;

- (BOOL) run;

- (std::string) vertexShader;
- (std::string) fragmentShader;
- (oo::PList) textureSpecifications;		// an array
- (oo::PList) uniformSpecifications;		// a dictionary

- (std::optional<std::string>) materialKey;
- (std::optional<std::string>) entityName;

@end


namespace oo {

// The synthesizer's Objective-C facade: its live one, else a new one; autoreleased. nil for null.
OODefaultShaderSynthesizer *ToObjC(cxx::OODefaultShaderSynthesizer *synthesizer);
inline OODefaultShaderSynthesizer *ToObjC(const Ref<cxx::OODefaultShaderSynthesizer> &synthesizer)  { return ToObjC(synthesizer.get()); }
// The C++ synthesizer behind a facade, borrowed (the facade retains it); null for nil.
cxx::OODefaultShaderSynthesizer *ToCxx(OODefaultShaderSynthesizer *synthesizer);

}	// namespace oo

#endif	// OODEFAULTSHADERSYNTHESIZER_OBJCBRIDGE_H
