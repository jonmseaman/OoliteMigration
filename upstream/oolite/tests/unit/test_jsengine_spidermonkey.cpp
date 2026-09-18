/*	test_jsengine_spidermonkey.cpp
	Unit test for the ooscript façade on the SpiderMonkey 1.8.5 backend (seam 1.1, bead oo-e7c).
	Plain C++20 against the façade header and the backend TU, linked to the engine the game
	ships; no GNUstep, no SDL. tools/check-jsengine-facade.sh builds and runs it.

	What is asserted, and why it matters for the retarget that follows:
	  - the façade's number canonicalisation is bit-identical to JS_NewNumberValue's, because a
	    double where the engine would store an int moves a golden dump;
	  - two classes that reuse the same tinyids with different getters stay distinct (Ship and
	    PlayerShip do this), i.e. the trampoline design does not route by receiver class;
	  - natives, constructors, static functions, private data, roots, arrays, strings,
	    exceptions, the error reporter and the operation callback all round-trip.
*/

#include "ooscript/JSEngine.hpp"

#include <cstdio>
#include <cstring>
#include <cmath>
#include <string>

namespace {

int gFailures = 0;

#define CHECK(cond) do { if (!(cond)) { std::printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #cond); ++gFailures; } } while (0)

using namespace ooscript;

struct Point { double x; double y; };
int gFinalized = 0;

// A class with two tinyid properties and a method, in the style of OOJSVector.m.
enum { kP_x = 1, kP_y = 2 };

bool PointGet(Context cx, Object obj, PropertyId id, Value* vp)
{
	if (!isInt32Id(id))  return true;
	auto* p = static_cast<Point*>(getPrivate(cx, obj));
	if (p == nullptr)  return true;
	switch (idToInt32(id))
	{
		case kP_x: return newNumberValue(cx, p->x, vp);
		case kP_y: return newNumberValue(cx, p->y, vp);
	}
	return true;
}

bool PointSet(Context cx, Object obj, PropertyId id, bool /*strict*/, Value* vp)
{
	if (!isInt32Id(id))  return true;
	auto* p = static_cast<Point*>(getPrivate(cx, obj));
	double d = 0;
	if (!valueToNumber(cx, *vp, &d))  return false;
	if (idToInt32(id) == kP_x)  p->x = d;  else  p->y = d;
	return true;
}

void PointFinalize(Context cx, Object obj)
{
	delete static_cast<Point*>(getPrivate(cx, obj));
	++gFinalized;
}

ClassDef sPointClass = { "Point", ClassFlag::HasPrivate, nullptr, nullptr, PointGet, PointSet,
                         nullptr, nullptr, nullptr, nullptr, PointFinalize, nullptr, nullptr, nullptr };

// Same tinyids, different getter: reads back x*100. If trampolines were routed by receiver class
// or by tinyid alone, one of the two classes would answer for the other.
bool ScaledGet(Context cx, Object obj, PropertyId id, Value* vp)
{
	if (!isInt32Id(id))  return true;
	auto* p = static_cast<Point*>(getPrivate(cx, obj));
	return newNumberValue(cx, (idToInt32(id) == kP_x ? p->x : p->y) * 100.0, vp);
}
ClassDef sScaledClass = { "ScaledPoint", ClassFlag::HasPrivate, nullptr, nullptr, ScaledGet, PointSet,
                          nullptr, nullptr, nullptr, nullptr, PointFinalize, nullptr, nullptr, nullptr };

const PropertySpec sPointProps[] =
{
	{ "x", kP_x, PropertyFlag::Shared | PropertyFlag::Enumerate | PropertyFlag::Permanent, nullptr, nullptr },
	{ "y", kP_y, PropertyFlag::Shared | PropertyFlag::Enumerate | PropertyFlag::Permanent, nullptr, nullptr },
	{ nullptr, 0, PropertyFlag::None, nullptr, nullptr }
};

bool PointConstruct(Context cx, CallArgs& args)
{
	double x = 0, y = 0;
	if (args.count() > 0 && !valueToNumber(cx, args[0], &x))  return false;
	if (args.count() > 1 && !valueToNumber(cx, args[1], &y))  return false;
	Object self = newObject(cx, &sPointClass, nullptr, nullptr);
	if (self == nullptr)  return false;
	setPrivate(cx, self, new Point{x, y});
	args.setRval(objectValue(self));
	return true;
}

bool ScaledConstruct(Context cx, CallArgs& args)
{
	double x = 0, y = 0;
	if (args.count() > 0 && !valueToNumber(cx, args[0], &x))  return false;
	if (args.count() > 1 && !valueToNumber(cx, args[1], &y))  return false;
	Object self = newObject(cx, &sScaledClass, nullptr, nullptr);
	setPrivate(cx, self, new Point{x, y});
	args.setRval(objectValue(self));
	return true;
}

bool PointSum(Context cx, CallArgs& args)
{
	Object self = args.thisObject();
	auto* p = static_cast<Point*>(getInstancePrivate(cx, self, &sPointClass, args.argv()));
	if (p == nullptr)  { reportError(cx, "Point.sum: not a Point"); return false; }
	Value v;
	if (!newNumberValue(cx, p->x + p->y, &v))  return false;
	args.setRval(v);
	return true;
}

bool PointMake(Context cx, CallArgs& args)   // static: Point.make(x, y)
{
	return PointConstruct(cx, args);
}

bool Throwing(Context cx, CallArgs& /*args*/)
{
	reportError(cx, "boom from native");
	return false;
}

const FunctionSpec sPointMethods[] =
{
	{ "sum", PointSum, 0, 0 },
	{ nullptr, nullptr, 0, 0 }
};
const FunctionSpec sPointStatics[] =
{
	{ "make", PointMake, 2, 0 },
	{ nullptr, nullptr, 0, 0 }
};

ClassDef sGlobalClass = { "global", ClassFlag::Global, nullptr, nullptr, nullptr, nullptr,
                          nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr, nullptr };

std::string gLastError;
unsigned    gLastLine = 0;
void Reporter(Context, const char* message, const ErrorReport* report)
{
	gLastError = message ? message : "";
	gLastLine  = report ? report->lineno : 0;
}

int gOpCalls = 0;
bool OpCallback(Context) { ++gOpCalls; return true; }

double evalNumber(Context cx, Object global, const char* src, bool* ok)
{
	Value rv = undefinedValue();
	*ok = evaluateScript(cx, global, src, static_cast<unsigned>(std::strlen(src)), "test.js", 1, &rv);
	double d = std::nan("");
	if (*ok)  valueToNumber(cx, rv, &d);
	return d;
}

} // namespace

int main()
{
	Runtime rt = newRuntime(8u * 1024u * 1024u);
	CHECK(rt != nullptr);
	Context cx = newContext(rt, 8192);
	CHECK(cx != nullptr);
	CHECK(getRuntime(cx) == rt);
	{
		Request req(cx);
		CHECK(isInRequest(cx));
		setOptions(cx, ContextOption::VarObjFix | ContextOption::RegExpLimit | ContextOption::AnonFunFix);
		CHECK(setVersion(cx, Version::ECMA5) != Version::Unknown);
		CHECK(getVersion(cx) == Version::ECMA5);
		CHECK(setErrorReporter(cx, Reporter) == nullptr);
		CHECK(setOperationCallback(cx, OpCallback) == nullptr);

		Object global = newGlobalObject(cx, &sGlobalClass);
		CHECK(global != nullptr);
		CHECK(initStandardClasses(cx, global));
		CHECK(getClass(cx, global) == &sGlobalClass);

		// Values: construction, predicates, and the int32 canonicalisation contract.
		CHECK(isUndefined(undefinedValue()) && isNull(nullValue()) && isNullOrUndefined(nullValue()));
		CHECK(isObjectOrNull(nullValue()) && !isObject(nullValue()) && isObject(objectValue(global)));
		CHECK(isInt32(int32Value(7)) && toInt32(int32Value(7)) == 7);
		CHECK(isBoolean(trueValue()) && toBoolean(trueValue()) && !toBoolean(falseValue()) && toBoolean(booleanValue(true)));
		CHECK(isPrimitive(int32Value(1)) && !isPrimitive(objectValue(global)));
		const double samples[] = { 0.0, -0.0, 1.0, -1.0, 3.0, 3.5, 2147483647.0, 2147483648.0, -2147483648.0, -2147483649.0,
		                           1e300, std::nan(""), std::numeric_limits<double>::infinity(), 0.1 };
		for (double d : samples)
		{
			Value a = numberValue(d);
			Value b = undefinedValue();
			CHECK(newNumberValue(cx, d, &b));
			CHECK(a.bits == b.bits);   // the façade's replica must match the engine bit for bit
		}
		CHECK(isInt32(numberValue(3.0)) && isDouble(numberValue(-0.0)) && isDouble(numberValue(3.5)) && isNumber(numberValue(3.5)));
		CHECK(toDouble(numberValue(3.5)) == 3.5);
		Value priv = privateValue(&gFailures);
		CHECK(toPrivate(priv) == &gFailures);

		// Property ids.
		CHECK(isInt32Id(int32Id(5)) && idToInt32(int32Id(5)) == 5 && isVoidId(voidId()) && idsEqual(int32Id(5), int32Id(5)));

		// Script evaluation and conversions.
		bool ok = false;
		CHECK(evalNumber(cx, global, "1 + 2", &ok) == 3.0 && ok);
		Value rv = undefinedValue();
		const char* s = "'abc'";
		CHECK(evaluateScript(cx, global, s, static_cast<unsigned>(std::strlen(s)), "test.js", 1, &rv));
		CHECK(isString(rv) && typeOfValue(cx, rv) == Type::String);
		std::size_t len = 0;
		const Char16* chars = getStringCharsAndLength(cx, toString(rv), &len);
		CHECK(len == 3 && chars != nullptr && chars[0] == u'a' && chars[2] == u'c');
		CHECK(getStringLength(toString(rv)) == 3);
		bool match = false;
		CHECK(stringEqualsAscii(cx, toString(rv), "abc", &match) && match);
		String interned = internString(cx, "abc");
		CHECK(interned != nullptr && stringHasBeenInterned(cx, interned));
		bool b = false;
		CHECK(valueToBoolean(cx, int32Value(0), &b) && !b);
		CHECK(valueToBoolean(cx, rv, &b) && b);
		std::int32_t i = 0;
		CHECK(valueToInt32(cx, numberValue(41.7), &i) && i == 42);   // JS_ValueToInt32 rounds
		CHECK(valueToECMAInt32(cx, numberValue(41.7), &i) && i == 41);
		Value sv = stringValue(newStringCopyZ(cx, "42"));
		double d = 0;
		CHECK(valueToNumber(cx, sv, &d) && d == 42.0);
		CHECK(isString(emptyStringValue(cx)));

		// Classes: init, construct, tinyid getters/setters, methods, statics, private data.
		Object proto = initClass(cx, global, nullptr, &sPointClass, PointConstruct, 2,
		                         sPointProps, sPointMethods, sPointStatics, nullptr);
		CHECK(proto != nullptr);
		CHECK(getClass(cx, proto) == &sPointClass);
		Object sproto = initClass(cx, global, nullptr, &sScaledClass, ScaledConstruct, 2,
		                          sPointProps, nullptr, nullptr, nullptr);
		CHECK(sproto != nullptr);
		CHECK(evalNumber(cx, global, "var p = new Point(3, 4); p.x + p.y + p.sum()", &ok) == 14.0 && ok);
		CHECK(evalNumber(cx, global, "p.x = 10; p.x", &ok) == 10.0 && ok);
		CHECK(evalNumber(cx, global, "Point.make(1, 2).sum()", &ok) == 3.0 && ok);
		CHECK(evalNumber(cx, global, "new ScaledPoint(5, 6).x", &ok) == 500.0 && ok);   // distinct getter, same tinyid
		CHECK(evalNumber(cx, global, "new Point(5, 6).x", &ok) == 5.0 && ok);
		CHECK(evalNumber(cx, global, "(p instanceof Point) ? 1 : 0", &ok) == 1.0 && ok);
		Value pv = undefinedValue();
		CHECK(getProperty(cx, global, "p", &pv) && isObject(pv));
		Object pobj = toObject(pv);
		CHECK(getClass(cx, pobj) == &sPointClass);
		CHECK(instanceOf(cx, pobj, &sPointClass, nullptr));
		CHECK(!instanceOf(cx, pobj, &sScaledClass, nullptr));
		auto* pp = static_cast<Point*>(getPrivate(cx, pobj));
		CHECK(pp != nullptr && pp->x == 10.0 && pp->y == 4.0);
		Value xv = undefinedValue();
		CHECK(getPropertyById(cx, pobj, int32Id(kP_x), &xv) == true);   // int ids reach the getter
		CHECK(getProperty(cx, pobj, "y", &xv) && isInt32(xv) && toInt32(xv) == 4);
		bool found = false;
		CHECK(hasProperty(cx, proto, "sum", &found) && found);

		// Natives resolve through the callee, and the reverse lookup works.
		Function sumFn = valueToFunction(cx, [&]{ Value v; getProperty(cx, proto, "sum", &v); return v; }());
		CHECK(sumFn != nullptr && getFunctionNative(cx, sumFn) == PointSum);
		CHECK(getFunctionNative(cx, valueToFunction(cx, [&]{ Value v; getProperty(cx, global, "Math", &v); Value f; getProperty(cx, toObject(v), "abs", &f); return f; }())) == nullptr);
		Function thrower = defineFunction(cx, global, "thrower", Throwing, 0, PropertyFlag::None);
		CHECK(thrower != nullptr);
		String fid = getFunctionId(thrower);
		CHECK(fid != nullptr && stringEqualsAscii(cx, fid, "thrower", &match) && match);

		// Call a script function from native, with arguments.
		const char* fsrc = "function twice(n) { return n * 2; }";
		CHECK(evaluateScript(cx, global, fsrc, static_cast<unsigned>(std::strlen(fsrc)), "test.js", 1, &rv));
		Value fnv = undefinedValue();
		CHECK(getProperty(cx, global, "twice", &fnv) && objectIsFunction(cx, toObject(fnv)));
		Value arg = int32Value(21);
		Value out = undefinedValue();
		CHECK(callFunctionValue(cx, global, fnv, 1, &arg, &out) && isInt32(out) && toInt32(out) == 42);
		CHECK(callFunctionName(cx, global, "twice", 1, &arg, &out) && toInt32(out) == 42);

		// Exceptions: from script, from a native, and the reporter.
		const char* bad = "throw new Error('kaboom')";
		CHECK(!evaluateScript(cx, global, bad, static_cast<unsigned>(std::strlen(bad)), "test.js", 7, &rv));
		CHECK(isExceptionPending(cx));
		Value exc = undefinedValue();
		CHECK(getPendingException(cx, &exc) && isObject(exc));
		gLastError.clear();
		CHECK(reportPendingException(cx));
		CHECK(gLastError.find("kaboom") != std::string::npos);
		CHECK(!isExceptionPending(cx));
		CHECK(!evalNumber(cx, global, "thrower()", &ok) || !ok);
		CHECK(isExceptionPending(cx));
		clearPendingException(cx);
		CHECK(!isExceptionPending(cx));
		const char* syntax = "var = ;";
		gLastLine = 0;
		CHECK(!evaluateScript(cx, global, syntax, static_cast<unsigned>(std::strlen(syntax)), "bad.js", 12, &rv));
		clearPendingException(cx);
		CHECK(gLastLine == 12);
		setPendingException(cx, int32Value(9));
		CHECK(isExceptionPending(cx) && getPendingException(cx, &exc) && toInt32(exc) == 9);
		ExceptionState* st = saveExceptionState(cx);
		clearPendingException(cx);
		CHECK(!isExceptionPending(cx));
		restoreExceptionState(cx, st);
		CHECK(isExceptionPending(cx));
		clearPendingException(cx);
		gLastError.clear();
		reportWarning(cx, "just a warning");
		CHECK(gLastError.find("just a warning") != std::string::npos);

		// Arrays and elements.
		Value elems[2] = { int32Value(1), int32Value(2) };
		Object arr = newArrayObject(cx, 2, elems);
		CHECK(arr != nullptr && isArrayObject(cx, arr));
		std::uint32_t n = 0;
		CHECK(getArrayLength(cx, arr, &n) && n == 2);
		Value three = int32Value(3);
		CHECK(setElement(cx, arr, 2, &three) && getArrayLength(cx, arr, &n) && n == 3);
		Value got = undefinedValue();
		CHECK(lookupElement(cx, arr, 1, &got) && toInt32(got) == 2);
		CHECK(getElement(cx, arr, 2, &got) && toInt32(got) == 3);
		IdArray* ida = enumerate(cx, arr);
		CHECK(ida != nullptr && ida->length == 3);
		destroyIdArray(cx, ida);

		// Roots survive a GC; unrooted temporaries with finalizers get collected.
		{
			RootedObject keep(cx, newObject(cx, &sPointClass, proto, nullptr), "keep");
			setPrivate(cx, keep.get(), new Point{1, 1});
			CHECK(evaluateScript(cx, global, "p = null", 8, "test.js", 1, &rv));
			const int before = gFinalized;
			gc(cx);
			CHECK(gFinalized > before);                       // the Point we nulled out went away
			CHECK(getPrivate(cx, keep.get()) != nullptr);     // the rooted one did not
			RootedValue keepv(cx, objectValue(keep.get()), "keepv");
			CHECK(isObject(keepv.get()));
		}
		gc(cx);
		CHECK(getGCParameter(rt, GCParam::NumberOfGCs) >= 2);
		CHECK(getGCParameter(rt, GCParam::MaxBytes) == 8u * 1024u * 1024u);

		// Operation callback fires when triggered.
		triggerOperationCallback(cx);
		CHECK(evalNumber(cx, global, "1", &ok) == 1.0 && ok);
		CHECK(gOpCalls >= 1);

		CHECK(std::strcmp(backendName(), "spidermonkey-1.8.5") == 0);
		CHECK(std::strcmp(typeName(Type::Number), "number") == 0);
		CHECK(std::strcmp(versionToString(Version::ECMA5), "ECMAv5") == 0);
	}
	CHECK(!isInRequest(cx));
	destroyContext(cx);
	destroyRuntime(rt);
	shutDown();

	if (gFailures == 0)  std::printf("PASS: ooscript façade on %s\n", "spidermonkey-1.8.5");
	else                 std::printf("%d check(s) failed\n", gFailures);
	return gFailures == 0 ? 0 : 1;
}
