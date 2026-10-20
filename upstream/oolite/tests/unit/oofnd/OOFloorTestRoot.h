/*	OOFloorTestRoot.h
	The Objective-C floor tests' own root class: tests/unit/oofnd's test_objc_ref, test_objc_runtime,
	test_objc_assert and test_objc_call_by_name stand their objects on it. It is src/oofnd/objc's
	OOObject (proposed ADR-0029, bead oo-3rb.1), its protocols and its methods, verbatim, taken from
	OOObject.h/.mm as bead oo-4aq6a.8 deleted them from src (no game class is rooted on OOObject), so
	every answer those tests pin is unchanged; OOObjCInstallFloor(), the forwarding hooks and the
	OOConstantString literal class are not here (no test here uses them). Test infrastructure only:
	it goes with these tests, whose subjects (OOObjCRef.h, OORuntime.h, OOAssert, OOCallByName) go
	with libobjc2 (oo-dbz). Include it once per test executable.
*/
#ifndef OO_FLOOR_TEST_ROOT_H
#define OO_FLOOR_TEST_ROOT_H

#include "oofnd/objc/OOObject.h"	// <objc/runtime.h>, OOZone

#include <objc/hooks.h>
#include <objc/objc-arc.h>

#include <cstdio>
#include <cstdlib>

// The root's method signatures (OOObject.mm's, verbatim).
typedef id (*OOObjectMethod0)(id, SEL);
typedef id (*OOObjectMethod1)(id, SEL, id);
typedef id (*OOObjectMethod2)(id, SEL, id, id);

@protocol OOCopying
- (id) copyWithZone:(OOZone *)zone;
@end

@protocol OOMutableCopying
- (id) mutableCopyWithZone:(OOZone *)zone;
@end

/*	Protocol form of the floor (oo-9evb). Protocols that inherited the root protocol
	inherit <OOObject> so id<P> can send -retain / -respondsToSelector: and the
	rest without "method not found in protocol" once gnustep-base is gone.
	No -description here: that is the Logging seam.
*/
@protocol OOObject

- (id) retain;
- (oneway void) release;
- (id) autorelease;
- (uintptr_t) retainCount;

- (id) self;
- (Class) class;
- (Class) superclass;
- (BOOL) isKindOfClass:(Class)aClass;
- (BOOL) isMemberOfClass:(Class)aClass;
- (BOOL) respondsToSelector:(SEL)selector;
- (BOOL) conformsToProtocol:(Protocol *)protocol;
- (BOOL) isProxy;

- (BOOL) isEqual:(id)other;
- (uintptr_t) hash;

- (id) performSelector:(SEL)selector;
- (id) performSelector:(SEL)selector withObject:(id)object;
- (id) performSelector:(SEL)selector withObject:(id)object1 withObject:(id)object2;

@end

__attribute__((objc_root_class))
@interface OOObject <OOObject>
{
@protected
	Class isa;
}

+ (void) initialize;
+ (id) alloc;
+ (id) allocWithZone:(OOZone *)zone;
+ (id) new;

+ (Class) class;
+ (Class) superclass;
+ (BOOL) isSubclassOfClass:(Class)aClass;
+ (BOOL) instancesRespondToSelector:(SEL)selector;
+ (IMP) instanceMethodForSelector:(SEL)selector;
+ (BOOL) conformsToProtocol:(Protocol *)protocol;

// A class object is not refcounted; these make [SomeClass retain] etc. harmless, as on the Foundation root class.
+ (id) retain;
+ (oneway void) release;
+ (id) autorelease;

- (id) init;
- (void) dealloc;

- (id) retain;
- (oneway void) release;
- (id) autorelease;
- (uintptr_t) retainCount;

- (id) self;
- (Class) class;
- (Class) superclass;
- (BOOL) isKindOfClass:(Class)aClass;
- (BOOL) isMemberOfClass:(Class)aClass;
- (BOOL) respondsToSelector:(SEL)selector;
- (IMP) methodForSelector:(SEL)selector;
- (BOOL) conformsToProtocol:(Protocol *)protocol;
- (BOOL) isProxy;

- (BOOL) isEqual:(id)other;
- (uintptr_t) hash;

- (id) performSelector:(SEL)selector;
- (id) performSelector:(SEL)selector withObject:(id)object;
- (id) performSelector:(SEL)selector withObject:(id)object1 withObject:(id)object2;

- (OOZone *) zone;	// always nil: the zone -copy and -mutableCopy pass
- (id) copy;
- (id) mutableCopy;

- (id) forwardingTargetForSelector:(SEL)selector;
- (void) doesNotRecognizeSelector:(SEL)selector;

@end

@implementation OOObject

- (void) _ARCCompliantRetainRelease
{
	// Marker for libobjc2: see the banner.
}

+ (void) initialize
{
}

// As NSObject: +alloc goes through +allocWithZone:, so a subclass overriding +allocWithZone:
// (the game's singletons) is honoured by +alloc and +new too.
+ (id) alloc
{
	return [self allocWithZone:nullptr];
}

+ (id) allocWithZone:(OOZone *)zone
{
	(void)zone;
	return class_createInstance(self, 0);
}

+ (id) new
{
	// Two statements, not [[self alloc] init]: clang lowers that to libobjc2's objc_alloc_init(),
	// which crashes when +allocWithZone: returns nil (measured: a singleton's second +new).
	id instance = [self alloc];
	return [instance init];
}

+ (Class) class
{
	return self;
}

+ (Class) superclass
{
	return class_getSuperclass(self);
}

+ (BOOL) isSubclassOfClass:(Class)aClass
{
	for (Class c = self; c != Nil; c = class_getSuperclass(c))
	{
		if (c == aClass)  return YES;
	}
	return NO;
}

+ (BOOL) instancesRespondToSelector:(SEL)selector
{
	return class_respondsToSelector(self, selector);
}

+ (IMP) instanceMethodForSelector:(SEL)selector
{
	return class_getMethodImplementation(self, selector);
}

+ (BOOL) conformsToProtocol:(Protocol *)protocol
{
	for (Class c = self; c != Nil; c = class_getSuperclass(c))
	{
		if (class_conformsToProtocol(c, protocol))  return YES;
	}
	return NO;
}

+ (id) retain
{
	return self;
}

+ (oneway void) release
{
}

+ (id) autorelease
{
	return self;
}

- (id) init
{
	return self;
}

- (void) dealloc
{
	object_dispose(self);
}

- (id) retain
{
	return objc_retain_fast_np(self);
}

- (oneway void) release
{
	objc_release_fast_np(self);   // sends -dealloc when the count reaches zero
}

- (id) autorelease
{
	return objc_autorelease(self);
}

- (uintptr_t) retainCount
{
	return object_getRetainCount_np(self);
}

- (id) self
{
	return self;
}

- (Class) class
{
	return object_getClass(self);
}

- (Class) superclass
{
	return class_getSuperclass(object_getClass(self));
}

- (BOOL) isKindOfClass:(Class)aClass
{
	for (Class c = object_getClass(self); c != Nil; c = class_getSuperclass(c))
	{
		if (c == aClass)  return YES;
	}
	return NO;
}

- (BOOL) isMemberOfClass:(Class)aClass
{
	return object_getClass(self) == aClass;
}

- (BOOL) respondsToSelector:(SEL)selector
{
	return class_respondsToSelector(object_getClass(self), selector);
}

- (IMP) methodForSelector:(SEL)selector
{
	return class_getMethodImplementation(object_getClass(self), selector);
}

- (BOOL) conformsToProtocol:(Protocol *)protocol
{
	return [object_getClass(self) conformsToProtocol:protocol];
}

- (BOOL) isProxy
{
	return NO;
}

- (BOOL) isEqual:(id)other
{
	return self == other;
}

- (uintptr_t) hash
{
	// gnustep-base's NSObject value (measured: the address shifted right by 4), so a rerooted
	// object lands in the same NSSet/NSDictionary bucket and iteration order does not change.
	const void *address = self;
	return reinterpret_cast<uintptr_t>(address) >> 4;
}

- (id) performSelector:(SEL)selector
{
	IMP imp = class_getMethodImplementation(object_getClass(self), selector);
	return reinterpret_cast<OOObjectMethod0>(imp)(self, selector);
}

- (id) performSelector:(SEL)selector withObject:(id)object
{
	IMP imp = class_getMethodImplementation(object_getClass(self), selector);
	return reinterpret_cast<OOObjectMethod1>(imp)(self, selector, object);
}

- (id) performSelector:(SEL)selector withObject:(id)object1 withObject:(id)object2
{
	IMP imp = class_getMethodImplementation(object_getClass(self), selector);
	return reinterpret_cast<OOObjectMethod2>(imp)(self, selector, object1, object2);
}

- (OOZone *) zone
{
	return nullptr;
}

- (id) copy
{
	return [(id<OOCopying>)self copyWithZone:nullptr];
}

- (id) mutableCopy
{
	return [(id<OOMutableCopying>)self mutableCopyWithZone:nullptr];
}

- (id) forwardingTargetForSelector:(SEL)selector
{
	(void)selector;
	return nil;
}

- (void) doesNotRecognizeSelector:(SEL)selector
{
	std::fprintf(stderr, "oofnd: -[%s %s]: unrecognised selector sent to instance %p\n",
				 class_getName(object_getClass(self)), sel_getName(selector), static_cast<void *>(self));
	std::abort();
}

@end

#endif	// OO_FLOOR_TEST_ROOT_H
