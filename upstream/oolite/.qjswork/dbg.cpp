#include "ooscript/JSEngine.hpp"
#include <cstdio>
using namespace ooscript;
int main(){
  Runtime rt = newRuntime(1024*1024);
  Context cx = newContext(rt, 8192);
  Object g = getGlobalObject(cx);
  printf("g=%p\n", (void*)g);
  Value v = objectValue(g);
  printf("bits=%llx\n", (unsigned long long)v.bits);
  printf("isObject=%d isNullOrUndef=%d\n", isObject(v), isNullOrUndefined(v));
  destroyContext(cx); destroyRuntime(rt);
}
