/*
OOBenchStringCopy.mm -- the "B" side of the decision-4 benchmark (bead oo-lvj,
docs/phases/2-string-benchmark.md). NOT part of the game: tools/bench-string-copy.sh copies this
file into src/Core, links it into a throwaway build, and restores the tree.

What it models. The String seam replaces NSString, whose -copy of an immutable string and whose
-retain are both O(1) reference-count bumps, with std::string, whose copy is O(n): a heap
allocation plus a byte copy once the string outgrows the small-string buffer (15 bytes in
libstdc++), and a free when it dies. This file makes the running game PAY that cost, on top of
everything it already does, at every point where it copies or retains an NSString:

    OO_BENCH_STRING_MODE=off    nothing is installed (the control; same binary)
    OO_BENCH_STRING_MODE=copy   every -copyWithZone: on an NSString also builds and destroys a
                                std::string of the same length (value semantics where the ObjC
                                code copies: dictionary keys, `copy` setters, explicit -copy)
    OO_BENCH_STRING_MODE=all    as copy, and every -retain on an NSString too (the pessimistic
                                model: every extra owner of a string becomes a deep copy)

The shadow copy is added, not substituted, so the measurement is an UPPER bound on the cost of
the switch: the real seam also deletes the NSString work it replaces. Game behaviour is untouched
(the goldens are diffed on every benchmark run to prove it).

At process exit, if OO_BENCH_STRING_REPORT names a file, one line is appended to it:
    mode=<m> shadow=<n> heap=<n> bytes=<n> user_ms=<n> kernel_ms=<n>
*/

#import "OOCocoa.h"			// compiled from src/Core, beside it
#include <objc/runtime.h>

#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>
#include <utility>

// GetProcessTimes: OOCocoa.h's Foundation import already brings in <windows.h> on MinGW.

namespace {

enum class Mode { off, copy, all };
Mode gMode = Mode::off;

std::atomic<unsigned long long> gShadow{0}, gHeap{0}, gBytes{0};
volatile char gSink;

constexpr int kSlots = 96;
IMP gOriginal[kSlots];
int gUsed = 0;

void Shadow(id self)
{
	NSUInteger length = [(NSString *)self length];
	std::string copy(length, 'x');		// one std::string copy of this length: allocate + fill ...
	gSink = copy.data()[length / 2];
	gShadow.fetch_add(1, std::memory_order_relaxed);
	if (length > 15)
	{
		gHeap.fetch_add(1, std::memory_order_relaxed);
		gBytes.fetch_add(length, std::memory_order_relaxed);
	}
}										// ... + free

template <int N>
id CopyHook(id self, SEL cmd, NSZone *zone)
{
	Shadow(self);
	return reinterpret_cast<id (*)(id, SEL, NSZone *)>(gOriginal[N])(self, cmd, zone);
}

template <int N>
id RetainHook(id self, SEL cmd)
{
	Shadow(self);
	return reinterpret_cast<id (*)(id, SEL)>(gOriginal[N])(self, cmd);
}

template <int... N>
constexpr auto MakeTable(std::integer_sequence<int, N...>)
{
	struct Table { IMP copy[sizeof...(N)]; IMP retain[sizeof...(N)]; };
	return Table{{reinterpret_cast<IMP>(&CopyHook<N>)...}, {reinterpret_cast<IMP>(&RetainHook<N>)...}};
}
const auto kHooks = MakeTable(std::make_integer_sequence<int, kSlots>());

bool IsStringClass(Class cls, Class stringClass)
{
	for (Class c = cls; c != Nil; c = class_getSuperclass(c))
	{
		if (c == stringClass)  return true;
	}
	return false;
}

// Swizzle <sel> where <cls> itself defines it. Returns false when out of slots.
bool HookOwn(Class cls, SEL sel, bool retain)
{
	unsigned count = 0;
	Method *methods = class_copyMethodList(cls, &count);
	bool ok = true;
	for (unsigned i = 0; i < count; i++)
	{
		if (!sel_isEqual(method_getName(methods[i]), sel))  continue;
		if (gUsed == kSlots) { ok = false; break; }
		int slot = gUsed++;
		gOriginal[slot] = method_getImplementation(methods[i]);
		method_setImplementation(methods[i], retain ? kHooks.retain[slot] : kHooks.copy[slot]);
	}
	free(methods);
	return ok;
}

void Report()
{
	const char *path = getenv("OO_BENCH_STRING_REPORT");
	if (path == nullptr || *path == '\0')  return;
	FILETIME creationTime, exitTime, kernelTime, userTime;
	if (!GetProcessTimes(GetCurrentProcess(), &creationTime, &exitTime, &kernelTime, &userTime))  return;
	unsigned long long kernel = (static_cast<unsigned long long>(kernelTime.dwHighDateTime) << 32) | kernelTime.dwLowDateTime;
	unsigned long long user = (static_cast<unsigned long long>(userTime.dwHighDateTime) << 32) | userTime.dwLowDateTime;
	FILE *f = fopen(path, "a");
	if (f == nullptr)  return;
	const char *mode = gMode == Mode::off ? "off" : gMode == Mode::copy ? "copy" : "all";
	fprintf(f, "mode=%s shadow=%llu heap=%llu bytes=%llu user_ms=%llu kernel_ms=%llu slots=%d\n", mode,
		gShadow.load(), gHeap.load(), gBytes.load(), user / 10000, kernel / 10000, gUsed);
	fclose(f);
}

void Install()
{
	const char *env = getenv("OO_BENCH_STRING_MODE");
	if (env != nullptr && strcmp(env, "copy") == 0)  gMode = Mode::copy;
	else if (env != nullptr && strcmp(env, "all") == 0)  gMode = Mode::all;
	atexit(Report);
	if (gMode == Mode::off)  return;

	Class stringClass = objc_getClass("NSString");
	SEL copySel = sel_registerName("copyWithZone:");
	SEL retainSel = sel_registerName("retain");
	bool addedRetain = false;
	if (gMode == Mode::all)
	{
		// NSString inherits -retain from NSObject: give it its own, forwarding to NSObject's.
		Method inherited = class_getInstanceMethod(class_getSuperclass(stringClass), retainSel);
		int slot = gUsed++;
		gOriginal[slot] = method_getImplementation(inherited);
		addedRetain = class_addMethod(stringClass, retainSel, kHooks.retain[slot], method_getTypeEncoding(inherited));
		if (!addedRetain)  gUsed--;	// NSString already defines it: HookOwn below takes it.
	}

	int n = objc_getClassList(nullptr, 0);
	Class *classes = static_cast<Class *>(calloc(n, sizeof(Class)));
	n = objc_getClassList(classes, n);
	for (int i = 0; i < n; i++)
	{
		if (!IsStringClass(classes[i], stringClass))  continue;
		if (!HookOwn(classes[i], copySel, false))  abort();
		if (gMode == Mode::all && !(addedRetain && classes[i] == stringClass) && !HookOwn(classes[i], retainSel, true))  abort();
	}
	free(classes);
}

}	// namespace


@interface OOBenchStringCopy: NSObject
@end

@implementation OOBenchStringCopy

+ (void) load
{
	Install();
}

@end
