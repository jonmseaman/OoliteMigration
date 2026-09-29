/*

OOCocoa.m

Runtime-like and Cocoa/GNUstep compatibility methods.


Copyright (C) 2008-2013 Jens Ayton

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

#import "OOCocoa.h"
#import "OOFunctionAttributes.h"
#import "OOFoundationBridge.h"

#include "oofnd/String.hpp"


namespace {

/*	TRANSITIONAL (ADR-0055 item 1; oo-qps.43 deletes the legacy family below): the legacy -description
	text, built by OODescription.h's oo::DescriptionWithComponents, as an Objective-C string.
	<components> is "%@" of the legacy components (nil for none).
*/
id LegacyDescriptionWithComponents(id object, id components)
{
	if (components == nil)  return oo::NSStringFrom(oo::DescriptionWithComponents(object, std::nullopt));
	return oo::NSStringFrom(oo::DescriptionWithComponents(object, oo::DescriptionOf(components)));
}


// The same from the C++ family's components.
id LegacyDescriptionWithComponents(id object, const std::optional<std::string> &components)
{
	return oo::NSStringFrom(oo::DescriptionWithComponents(object, components));
}

}	// namespace


@implementation NSObject (OODescriptionComponents)

- (id) descriptionComponents
{
	return nil;
}

#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"
#endif
- (id) description
{
	return LegacyDescriptionWithComponents(self, [self descriptionComponents]);
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif


- (id) shortDescription
{
	return LegacyDescriptionWithComponents(self, [self shortDescriptionComponents]);
}


- (id) shortDescriptionComponents
{
	return nil;
}

@end


// NSObject (OODescriptionComponents) above, for classes rooted on OOObject (ADR-0029). TRANSITIONAL:
// built on OODescription.h's C++ family, whose root defaults forward to a legacy override of
// -descriptionComponents / -shortDescriptionComponents. These build from the components directly,
// never through -cxx_description, so a legacy -description override that calls [super description]
// cannot recurse. oo-qps.43 deletes this category.
@implementation OOObject (OODescriptionComponents)

- (id) descriptionComponents
{
	return nil;
}


- (id) description
{
	return LegacyDescriptionWithComponents(self, [self cxx_descriptionComponents]);
}


- (id) shortDescription
{
	return LegacyDescriptionWithComponents(self, [self cxx_shortDescriptionComponents]);
}


- (id) shortDescriptionComponents
{
	return nil;
}

@end


#ifndef NDEBUG
id OOConsumeReference(id OO_NS_CONSUMED value)
{
	return value;
}
#endif
