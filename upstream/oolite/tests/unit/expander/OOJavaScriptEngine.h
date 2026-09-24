// Stub for tests/unit/expander (bead oo-3rb.61): only what src/Core/OOStringExpander.mm uses.
#import "OOCocoa.h"
namespace ooscript { struct Context { void *p; }; }
ooscript::Context OOJSAcquireContext(void);
void OOJSRelinquishContext(ooscript::Context context);
void OOJSReportWarningWithArguments(ooscript::Context context, NSString *format, va_list args);
