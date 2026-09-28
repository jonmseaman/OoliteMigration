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

/*	<ClassName 0xnnnnnnnn>{components}, or <ClassName 0xnnnnnnnn> without components: the text the
	former stringWithFormat:@"<%@ %p>{%@}" built (%@ of the class is its name, %p GNUstep's pointer
	text, %@ of the components their description), as an Objective-C string.
*/
id DescriptionWithComponents(id object, id components)
{
	const std::string head = oo::str::format("<%s %s>", oo::DescriptionOf([object class]).c_str(), oo::str::pointerDescription(object).c_str());
	if (components == nil)  return oo::NSStringFrom(head);
	return oo::NSStringFrom(head + "{" + oo::DescriptionOf(components) + "}");
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
	return DescriptionWithComponents(self, [self descriptionComponents]);
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif


- (id) shortDescription
{
	return DescriptionWithComponents(self, [self shortDescriptionComponents]);
}


- (id) shortDescriptionComponents
{
	return nil;
}

@end


// NSObject (OODescriptionComponents) above, for classes rooted on OOObject (ADR-0029).
@implementation OOObject (OODescriptionComponents)

- (id) descriptionComponents
{
	return nil;
}


- (id) description
{
	return DescriptionWithComponents(self, [self descriptionComponents]);
}


- (id) shortDescription
{
	return DescriptionWithComponents(self, [self shortDescriptionComponents]);
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
