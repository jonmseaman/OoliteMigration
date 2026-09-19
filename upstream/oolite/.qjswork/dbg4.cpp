#include "ooscript/JSEngine.hpp"
#include <cstdio>
using namespace ooscript;
int gFin=0;
void Fin(Context cx, Object obj){ gFin++; printf("finalized\n"); }
ClassDef C = { "T", ClassFlag::HasPrivate, nullptr,nullptr,nullptr,nullptr, nullptr, nullptr, nullptr, nullptr, Fin, nullptr,nullptr,nullptr };
int main(){
  Runtime rt = newRuntime(1024*1024);
  Context cx = newContext(rt, 8192);
  Object g = getGlobalObject(cx);
  Object o = newObject(cx, &C, nullptr, nullptr);
  setPrivate(cx, o, (void*)1);
  Value ov = objectValue(o);
  setProperty(cx, g, "o", &ov);
  printf("before destroy\n");
  destroyContext(cx);
  printf("after destroyContext, gFin=%d\n", gFin);
  destroyRuntime(rt);
  printf("after destroyRuntime, gFin=%d\n", gFin);
}
