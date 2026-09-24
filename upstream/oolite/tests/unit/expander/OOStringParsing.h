// Stub for tests/unit/expander (bead oo-3rb.61): only what src/Core/OOStringExpander.mm uses.
#import "OOCocoa.h"
#import "OOTypes.h"
NSString *OOHarnessCredits(OOCreditsQuantity tenths, BOOL decimal);
static inline NSString *OOCredits(OOCreditsQuantity tenthsOfCredits) { return OOHarnessCredits(tenthsOfCredits, YES); }
static inline NSString *OOIntCredits(OOCreditsQuantity integerCredits) { return OOHarnessCredits(integerCredits * 10, NO); }
