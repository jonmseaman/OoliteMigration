/*
 * tools/oxp-js-parse/engine-probe.c -- which SpiderMonkey-era APIs does the game's QuickJS-ng have?
 *
 * Evaluates each case in a bare QuickJS-ng context (no Oolite globals, no oolite-global-prefix.js
 * polyfills) and prints the result. Built by build.sh beside oxp-js-parse.exe. Results are recorded
 * in docs/expansions/scan-report.md; they are the ground truth for the removed-api and
 * legacy-accessor entries in docs/EXPANSION_MIGRATION.md.
 */
#include <stdio.h>
#include <string.h>
#include "quickjs.h"
static const char* cases[] = {
 "typeof Object.prototype.watch", "typeof Object.prototype.unwatch",
 "typeof Iterator", "(function(){try{Iterator({a:1});return 'call ok'}catch(e){return e.name+': '+e.message}})()",
 "typeof StopIteration",
 "(/(a)(b)/.exec('ab'), typeof RegExp.$1 + ' ' + RegExp.$1 + ' lastMatch=' + RegExp.lastMatch)",
 "typeof Date.prototype.toLocaleFormat",
 "String((function(a,b){}).arity)",
 "(function(){ function g(){ return typeof g.caller } return g() })()",
 "(function(){ 'use strict'; try { return typeof (function(){}).caller } catch(e) { return e.name } })()",
 "(function(){ var e = new Error('x'); return String(e.fileName) + ' ' + String(e.lineNumber) })()",
 "String(({a:1,b:2}).__count__)", "String(({}).__parent__)",
 "typeof Object.prototype.__defineGetter__", "typeof Object.prototype.__lookupGetter__",
 "(function(){ var o={__noSuchMethod__:function(){return 'nsm'}}; try { return o.missing() } catch(e) { return e.name } })()",
 "(function(){ var o={__iterator__:function(){}}; var n=0; for (var k in o) n++; return 'keys='+n })()",
 "typeof Array.forEach", "typeof String.replace",
 "typeof Object.prototype.toSource", "typeof uneval", "typeof String.prototype.quote",
 "(function sq(a){ return a*2 }).toString()",
 "(function(){ return typeof arguments.callee })()",
 "(function(){ 'use strict'; try { return typeof arguments.callee } catch(e) { return e.name } })()",
 "(function(){ try { null.x } catch(e) { return e.message } })()",
 "(function(){ try { undefinedName } catch(e) { return e.message } })()",
 "(function(){ var s='abc'; s.x = 1; return 'sloppy primitive write ok' })()",
 "Object.getOwnPropertyNames(globalThis).filter(function(n){return ['Map','Set','Promise','globalThis','Symbol','Proxy','Reflect','WeakMap','BigInt','Iterator'].indexOf(n)>=0}).sort().join(',')",
 NULL };
int main(void){ JSRuntime*rt=JS_NewRuntime(); JSContext*ctx=JS_NewContext(rt);
 for(int i=0;cases[i];i++){ JSValue v=JS_Eval(ctx,cases[i],strlen(cases[i]),"p.js",0);
  if(JS_IsException(v)){ JSValue e=JS_GetException(ctx); const char*s=JS_ToCString(ctx,e); printf("%-60.60s => THROWS %s\n",cases[i],s); JS_FreeCString(ctx,s); JS_FreeValue(ctx,e);}
  else { const char*s=JS_ToCString(ctx,v); printf("%-60.60s => %s\n",cases[i],s?s:"?"); JS_FreeCString(ctx,s);} JS_FreeValue(ctx,v);} return 0; }
