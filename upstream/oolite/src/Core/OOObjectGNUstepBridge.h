/*

OOObjectGNUstepBridge.h

TEMPORARY: oo-qps (libgnustep-base leaves the build) deletes this file and its import in
OOCocoa.h. See OOObjectGNUstepBridge.mm.

*/

#import <Foundation/Foundation.h>
#import "oofnd/objc/OOObject.h"


@interface OOObject (OOGNUstepBridge)

+ (NSString *) description;

// NSObject's own implementations, applied to an OOObject (see OOObjectGNUstepBridge.mm).
+ (NSMethodSignature *) instanceMethodSignatureForSelector:(SEL)selector;
- (NSMethodSignature *) methodSignatureForSelector:(SEL)selector;
- (void) performSelector:(SEL)selector withObject:(id)argument afterDelay:(NSTimeInterval)delay;

@end
