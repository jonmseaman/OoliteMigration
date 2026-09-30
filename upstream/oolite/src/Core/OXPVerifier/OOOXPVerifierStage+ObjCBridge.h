/*

OOOXPVerifierStage+ObjCBridge.h

TRANSITIONAL (proposed ADR-0056 Amendment 1, bead oo-cwz): the Objective-C OOOXPVerifierStage, a
facade over the C++ cxx::OOOXPVerifierStage (OOOXPVerifierStage.h), for the Objective-C verifier
and for the stages not converted yet. Its interface is the one OOOXPVerifierStage.h declared
before the conversion, copied exactly (same selectors, same types), so they compile and behave
unchanged; OOOXPVerifierStageInternal.h still declares its OOInternal category. Imported as the
last line of OOOXPVerifierStage.h; do not import it directly.

A class with subclasses has two kinds of facade, one class:

	the stage is                         its facade is                      virtual calls on the
	                                                                          C++ side reach
	-----------------------------------  ---------------------------------  ---------------------
	an Objective-C subclass              the subclass instance itself; its  the subclass's
	  (unconverted, [[X alloc] init])    -init made its C++ part, an        methods (-cxx_name,
	                                     adapter that forwards the virtual  -run, ...), as
	                                     members to it                      overriding did
	a C++ subclass (converted)           made by oo::ToObjC, one live one   the C++ overrides
	                                     per stage (oo::ObjCPeers)

An Objective-C subclass's [super cxx_name] (and -cxx_dependencies, -dependents, -shouldRun,
-run) reaches the C++ base class's own member, not the virtual one, so it does what the base did.

	a caller that is                       holds / passes                      crosses with
	-------------------------------------  ----------------------------------  -----------------
	still Objective-C (the verifier,       OOOXPVerifierStage * (this facade)  nothing
	  unconverted stages)
	converted (C++)                        oo::Ref<cxx::OOOXPVerifierStage>
	  handing a stage to Objective-C                                           oo::ToObjC(stage)
	  taking one from Objective-C                                              oo::ToCxx(objcStage)

oo::ToObjC(oo::ToCxx(s)) == s for both kinds. Never add to this file; converted code does not
message the facade. Deleted by its deletion bead once the verifier and every stage are C++.


Copyright (C) 2007-2013 Jens Ayton

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

#ifndef OOOXPVERIFIERSTAGE_OBJCBRIDGE_H
#define OOOXPVERIFIERSTAGE_OBJCBRIDGE_H

#if OO_OXP_VERIFIER_ENABLED

#include "oofnd/objc/OOObjCRef.h"


@interface OOOXPVerifierStage: OOObject
{
@private
	oo::Ref<cxx::OOOXPVerifierStage>	_cxxStage;
}

- (OOOXPVerifier *)verifier;
- (BOOL)completed;

// Subclass responsibilities:

- (std::optional<std::string>)cxx_name;	// nullopt: none (bead oo-3rb.289.1)
- (std::optional<std::vector<std::string>>)cxx_dependencies;	// nullopt: none (nil); override this (bead oo-3rb.291.3)
- (std::optional<std::vector<std::string>>)dependents;	// stage names; nullopt: none (nil)
- (BOOL)shouldRun;
- (void)run;

@end


namespace oo {

// The stage's Objective-C object: an Objective-C stage itself, else a C++ stage's live facade (or
// a new one); autoreleased. nil for null.
OOOXPVerifierStage *ToObjC(cxx::OOOXPVerifierStage *stage);
inline OOOXPVerifierStage *ToObjC(const Ref<cxx::OOOXPVerifierStage> &stage)  { return ToObjC(stage.get()); }

// The C++ stage behind an Objective-C one, borrowed (the Objective-C object retains it); null for nil.
cxx::OOOXPVerifierStage *ToCxx(OOOXPVerifierStage *stage);

}	// namespace oo

#endif	// OO_OXP_VERIFIER_ENABLED

#endif	// OOOXPVERIFIERSTAGE_OBJCBRIDGE_H
