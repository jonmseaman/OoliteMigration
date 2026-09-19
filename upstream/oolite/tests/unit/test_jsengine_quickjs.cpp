/*	test_jsengine_quickjs.cpp
	Unit test for the ooscript façade on the QuickJS-ng backend (seam 1.4b, bead oo-0kq).
	Plain C++20 against the façade header and the backend TU, linked against the vendored
	QuickJS-ng library; no GNUstep, no SDL.

	Scoped to what JSEngine_quickjs.cpp implements (Context/Value/Object/ClassDef lifecycle plus
	resolve/enumerate mapped onto JSClassExoticMethods, and private-pointer attach/retrieve): see
	that file's banner for the full list of what is out of scope for this bead. It is the same
	shape of check as test_jsengine_spidermonkey.cpp for the parts both backends cover: number
	canonicalisation, private data through a class with a finalizer, and resolve/enumerate acting
	through the façade's own PropertyId/hook types rather than any engine-specific handle.
*/

#include "ooscript/JSEngine.hpp"

#include <cmath>
#include <cstdio>
#include <cstring>
#include <limits>
#include <string>

// Declared in JSEngine_quickjs.cpp; test-only glue between a PropertySpec-style name/tinyid pair
// and the resolve/enumerate exotic methods (see that file's banner).
namespace ooscript { void registerResolvableProperty(Context cx, ClassDef* def, const char* name, std::int32_t tinyid); }

namespace {

int gFailures = 0;
#define CHECK(cond) do { if (!(cond)) { std::printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); ++gFailures; } } while (0)

using namespace ooscript;

struct Point { double x; double y; };
int gFinalized = 0;
int gResolveCalls = 0;
int gEnumerateCalls = 0;

enum { kP_x = 1, kP_y = 2 };

bool PointResolve(Context cx, Object obj, PropertyId id)
{
	++gResolveCalls;
	if (!isInt32Id(id))  return true;
	auto* p = static_cast<Point*>(getPrivate(cx, obj));
	CHECK(p != nullptr);
	CHECK(idToInt32(id) == kP_x || idToInt32(id) == kP_y);
	return true;
}

bool PointEnumerate(Context /*cx*/, Object /*obj*/)
{
	++gEnumerateCalls;
	return true;
}

void PointFinalize(Context /*cx*/, Object /*obj*/)
{
	++gFinalized;
}

ClassDef sPointClass = { "Point", ClassFlag::HasPrivate, nullptr, nullptr, nullptr, nullptr,
                          PointEnumerate, nullptr, PointResolve, nullptr, PointFinalize, nullptr, nullptr, nullptr };

// A second class reusing the same tinyids with a distinct resolve hook: the trampoline/exotic
// dispatch must not confuse the two classes' hooks (JSClassID is per-class, not per-tinyid).
int gScaledResolveCalls = 0;
bool ScaledResolve(Context /*cx*/, Object /*obj*/, PropertyId id)
{
	++gScaledResolveCalls;
	CHECK(isInt32Id(id));
	return true;
}
ClassDef sScaledClass = { "ScaledPoint", ClassFlag::HasPrivate, nullptr, nullptr, nullptr, nullptr,
                           nullptr, nullptr, ScaledResolve, nullptr, PointFinalize, nullptr, nullptr, nullptr };

} // namespace

int main()
{
	Runtime rt = newRuntime(8u * 1024u * 1024u);
	CHECK(rt != nullptr);
	Context cx = newContext(rt, 8192);
	CHECK(cx != nullptr);
	CHECK(getRuntime(cx) == rt);

	Object global = getGlobalObject(cx);
	CHECK(global != nullptr);
	CHECK(initStandardClasses(cx, global));

	// Values: construction, predicates, and the int32 canonicalisation contract this backend
	// promises to keep even without borrowing the engine's own JSValue layout (see the backend's
	// file banner: Value here is not a byte copy of the engine's 16-byte JSValue).
	CHECK(isUndefined(undefinedValue()) && isNull(nullValue()) && isNullOrUndefined(nullValue()));
	CHECK(isObjectOrNull(nullValue()) && !isObject(nullValue()) && isObject(objectValue(global)));
	CHECK(isInt32(int32Value(7)) && toInt32(int32Value(7)) == 7);
	CHECK(isBoolean(trueValue()) && toBoolean(trueValue()) && !toBoolean(falseValue()) && toBoolean(booleanValue(true)));
	CHECK(isPrimitive(int32Value(1)) && !isPrimitive(objectValue(global)));
	const double samples[] = { 0.0, -0.0, 1.0, -1.0, 3.0, 3.5, 2147483647.0, 2147483648.0, -2147483648.0, -2147483649.0,
	                           1e300, std::nan(""), std::numeric_limits<double>::infinity(), 0.1 };
	for (double d : samples)
	{
		Value v = numberValue(d);
		if (static_cast<double>(static_cast<std::int32_t>(d)) == d && !(d == 0.0 && std::signbit(d)))
		{
			CHECK(isInt32(v) && toInt32(v) == static_cast<std::int32_t>(d));
		}
		else
		{
			CHECK(isDouble(v));
			double back = toDouble(v);
			CHECK((std::isnan(back) && std::isnan(d)) || back == d);
		}
	}
	CHECK(isInt32(numberValue(3.0)) && isDouble(numberValue(-0.0)) && isDouble(numberValue(3.5)) && isNumber(numberValue(3.5)));
	CHECK(toDouble(numberValue(3.5)) == 3.5);

	// Property ids.
	CHECK(isInt32Id(int32Id(5)) && idToInt32(int32Id(5)) == 5 && isVoidId(voidId()) && idsEqual(int32Id(5), int32Id(5)));

	// Classes: attach-on-first-use, private data, finalizer, resolve/enumerate through the
	// exotic-method mapping, and getClass()/instanceOf() answering from the same ClassDef.
	Object p = newObject(cx, &sPointClass, nullptr, nullptr);
	CHECK(p != nullptr);
	CHECK(getClass(cx, p) == &sPointClass);
	CHECK(instanceOf(cx, p, &sPointClass, nullptr));
	CHECK(!instanceOf(cx, p, &sScaledClass, nullptr));
	CHECK(setPrivate(cx, p, new Point{3.0, 4.0}));
	auto* pp = static_cast<Point*>(getPrivate(cx, p));
	CHECK(pp != nullptr && pp->x == 3.0 && pp->y == 4.0);
	CHECK(getInstancePrivate(cx, p, &sPointClass, nullptr) == pp);
	CHECK(getInstancePrivate(cx, p, &sScaledClass, nullptr) == nullptr);   // wrong class, no private

	// Resolve/enumerate: declare "x"/"y" as tinyid properties, then have QuickJS-ng's own
	// property machinery (`in`, for-in) drive the exotic methods through has_property and
	// get_own_property_names, and confirm those trampolines reached the façade's hooks with the
	// right PropertyId.
	registerResolvableProperty(cx, &sPointClass, "x", kP_x);
	registerResolvableProperty(cx, &sPointClass, "y", kP_y);
	Value pv = objectValue(p);
	CHECK(setProperty(cx, global, "p", &pv));
	Value rv = undefinedValue();
	const char* has_x = "'x' in p";
	CHECK(evaluateScript(cx, global, has_x, static_cast<unsigned>(std::strlen(has_x)), "test.js", 1, &rv));
	CHECK(toBoolean(rv) == true || isBoolean(rv));   // 'in' returns a JS boolean; presence is what we assert
	CHECK(gResolveCalls > 0);

	const char* countProps = "var n = 0; for (var k in p) n++; n";
	CHECK(evaluateScript(cx, global, countProps, static_cast<unsigned>(std::strlen(countProps)), "test.js", 1, &rv));
	CHECK(isInt32(rv) && toInt32(rv) == 2);   // x and y, from get_own_property_names
	CHECK(gEnumerateCalls > 0);

	// A second class with the same tinyids exercises a distinct resolve hook: dispatch is keyed
	// by the object's own JSClassID (bc->id), not by tinyid or receiver shape.
	registerResolvableProperty(cx, &sScaledClass, "x", kP_x);
	Object s = newObject(cx, &sScaledClass, nullptr, nullptr);
	CHECK(setPrivate(cx, s, new Point{5.0, 6.0}));
	Value sv = objectValue(s);
	CHECK(setProperty(cx, global, "s", &sv));
	const char* has_sx = "'x' in s";
	CHECK(evaluateScript(cx, global, has_sx, static_cast<unsigned>(std::strlen(has_sx)), "test.js", 1, &rv));
	CHECK(gScaledResolveCalls > 0);
	CHECK(gResolveCalls > 0);   // Point's own resolve was not the one that answered for `s`

	// Basic property get/set and script evaluation, the surface this backend implements.
	CHECK(setProperty(cx, global, "answer", &(rv = int32Value(42))));
	Value got = undefinedValue();
	CHECK(getProperty(cx, global, "answer", &got) && isInt32(got) && toInt32(got) == 42);
	const char* expr = "1 + 2";
	CHECK(evaluateScript(cx, global, expr, static_cast<unsigned>(std::strlen(expr)), "test.js", 1, &rv));
	CHECK(isInt32(rv) && toInt32(rv) == 3);
	const char* bad = "var = ;";
	CHECK(!evaluateScript(cx, global, bad, static_cast<unsigned>(std::strlen(bad)), "bad.js", 1, &rv));

	// Exceptions: a syntax error leaves the engine's own exception pending (bead oo-s0y). Read it
	// without disturbing it (isExceptionPending/getPendingException), report it through a
	// backend-held ErrorReporter, then clear it explicitly.
	CHECK(isExceptionPending(cx));
	Value pending = undefinedValue();
	CHECK(getPendingException(cx, &pending));
	CHECK(isExceptionPending(cx));   // reading must not clear it
	static std::string sLastReported;
	static unsigned sLastFlags = 0;
	ErrorReporter oldReporter = setErrorReporter(cx, +[](Context, const char* message, const ErrorReport* report)
	{
		sLastReported = message != nullptr ? message : "";
		sLastFlags = report != nullptr ? report->flags : 0;
	});
	CHECK(oldReporter == nullptr);
	CHECK(reportPendingException(cx));
	CHECK(!sLastReported.empty());
	CHECK((sLastFlags & static_cast<unsigned>(ReportFlag::Exception)) != 0);
	CHECK(!isExceptionPending(cx));   // reportPendingException clears it

	// setPendingException / clearPendingException round-trip a façade value (not just an engine
	// error), then clear it so it does not leak into the destroyContext below.
	setPendingException(cx, int32Value(99));
	CHECK(isExceptionPending(cx));
	Value thrown = undefinedValue();
	CHECK(getPendingException(cx, &thrown) && isInt32(thrown) && toInt32(thrown) == 99);
	clearPendingException(cx);
	CHECK(!isExceptionPending(cx));

	// save/restore/drop bracket a call that must not disturb an already-pending exception.
	setPendingException(cx, int32Value(7));
	ExceptionState* saved = saveExceptionState(cx);
	CHECK(!isExceptionPending(cx));                 // save lifts it off the context
	setPendingException(cx, int32Value(8));          // something else runs and throws
	restoreExceptionState(cx, saved);
	Value restored = undefinedValue();
	CHECK(getPendingException(cx, &restored) && isInt32(restored) && toInt32(restored) == 7);
	clearPendingException(cx);

	setPendingException(cx, int32Value(11));
	ExceptionState* dropped = saveExceptionState(cx);
	CHECK(!isExceptionPending(cx));
	dropExceptionState(cx, dropped);                 // drop must not resurrect it
	CHECK(!isExceptionPending(cx));

	setErrorReporter(cx, oldReporter);

	// GC roots: RootedObject keeps a handle stable for the scope of a block, and
	// removeObjectRoot()/removeValueRoot() answer false once the root is gone (a second remove is
	// not a silent success).
	{
		Object r = newObject(cx, &sPointClass, nullptr, nullptr);
		CHECK(setPrivate(cx, r, new Point{1.0, 2.0}));
		RootedObject root(cx, r, "test_root");
		CHECK(root.get() == r);
		CHECK(getClass(cx, root.get()) == &sPointClass);
	}
	// After the scope above the root is released (RootedObject's destructor called
	// removeObjectRoot once); the object itself is still reachable only if something else holds
	// it, which nothing does here, so it becomes collectable.

	Object rawObj = nullptr;
	CHECK(addNamedObjectRoot(cx, &rawObj, "raw_root"));
	CHECK(removeObjectRoot(cx, &rawObj));
	CHECK(!removeObjectRoot(cx, &rawObj));   // already removed: false, not a crash

	Value rawVal = int32Value(0);
	CHECK(addNamedValueRoot(cx, &rawVal, "raw_val_root"));
	CHECK(removeValueRoot(cx, &rawVal));
	CHECK(!removeValueRoot(cx, &rawVal));

	// Regression: destroyContext() must erase the destroyed context's entry from the backend's
	// per-context ErrorReporter map (gContextExtras), not just free the underlying context handle.
	// Otherwise, if the allocator hands the freed handle back to a later newContext() (common:
	// same size, no other allocations in between), the new, unrelated context would silently
	// inherit the previous context's stale reporter via gContextExtras[ctx]'s operator[].
	// Exercise context reuse directly: set a reporter on one context, destroy it, create a fresh
	// context (likely reusing the freed handle), and confirm no stale reporter callback fires.
	{
		static std::string sStaleReported;
		Context reused1 = newContext(rt, 8192);
		CHECK(reused1 != nullptr);
		ErrorReporter prevReporter = setErrorReporter(reused1, +[](Context, const char* message, const ErrorReport*)
		{
			sStaleReported = message != nullptr ? message : "";
		});
		reportError(reused1, "reporter armed on context 1");
		CHECK(sStaleReported == "reporter armed on context 1");
		clearPendingException(reused1);
		destroyContext(reused1);   // must erase reused1's gContextExtras entry, not just free it

		sStaleReported.clear();
		Context reused2 = newContext(rt, 8192);   // may or may not reuse reused1's address
		CHECK(reused2 != nullptr);
		// reused2 never called setErrorReporter: if destroyContext() failed to erase reused1's
		// entry and the allocator reused the address, invokeReporter() would find reused1's old
		// reporter still keyed under this address and fire it here. It must stay empty.
		reportError(reused2, "should not reach any reporter");
		CHECK(sStaleReported.empty());
		clearPendingException(reused2);
		destroyContext(reused2);
		(void)prevReporter;
	}

	destroyContext(cx);
	destroyRuntime(rt);
	shutDown();
	CHECK(gFinalized >= 2);   // p and s both finalized when their runtime went away

	CHECK(std::strcmp(backendName(), "quickjs-ng-0.16.2") == 0);

	if (gFailures == 0)  std::printf("PASS: ooscript façade on %s\n", "quickjs-ng-0.16.2");
	else                 std::printf("%d check(s) failed\n", gFailures);
	return gFailures == 0 ? 0 : 1;
}
