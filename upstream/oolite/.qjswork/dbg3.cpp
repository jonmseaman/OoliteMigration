#include "ooscript/JSEngine.hpp"
#include <cstdio>
#include <cstring>
using namespace ooscript;
namespace ooscript { void registerResolvableProperty(Context cx, ClassDef* def, const char* name, std::int32_t tinyid); }
int gEnum=0, gResolve=0;
bool Resolve(Context cx, Object obj, PropertyId id){ gResolve++; printf("resolve int=%d\n", isInt32Id(id)?idToInt32(id):-1); return true; }
bool Enumerate(Context cx, Object obj){ gEnum++; printf("enum called\n"); return true; }
void Fin(Context cx, Object obj){}
ClassDef C = { "T", ClassFlag::HasPrivate, nullptr,nullptr,nullptr,nullptr, Enumerate, nullptr, Resolve, nullptr, Fin, nullptr,nullptr,nullptr };
int main(){
  Runtime rt = newRuntime(1024*1024);
  Context cx = newContext(rt, 8192);
  Object g = getGlobalObject(cx);
  Object o = newObject(cx, &C, nullptr, nullptr);
  registerResolvableProperty(cx, &C, "x", 1);
  registerResolvableProperty(cx, &C, "y", 2);
  Value ov = objectValue(o);
  setProperty(cx, g, "o", &ov);
  Value rv = undefinedValue();
  const char* src = "var n=0; for (var k in o) { n++; } n";
  bool ok = evaluateScript(cx, g, src, strlen(src), "t.js", 1, &rv);
  printf("ok=%d isInt=%d val=%d\n", ok, isInt32(rv), isInt32(rv)?toInt32(rv):-1);
  destroyContext(cx); destroyRuntime(rt);
}
