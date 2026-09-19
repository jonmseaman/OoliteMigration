#include "ooscript/JSEngine.hpp"
#include <cstdio>
using namespace ooscript;
int main(){
  Value n = nullValue();
  printf("nullbits=%llx isObjOrNull=%d isObject=%d\n", (unsigned long long)n.bits, isObjectOrNull(n), isObject(n));
}
