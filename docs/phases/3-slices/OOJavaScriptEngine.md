# Slice plan: OOJavaScriptEngine

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-ox23). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/OOJavaScriptEngine.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Scripting/OOJavaScriptEngine.mm` (2,567 lines) + header (767 lines). The
  engine singleton `OOJavaScriptEngine` (with its `OOMonitorSupport` categories), the `OOJSValue`
  and `OONull` classes, JS-conversion categories on `OOObject` and `OONativeVector`, and ~80
  file-scope helpers: error/warning reporting, stack dumps, value description, the object
  wrapper, entity predicates and the JS → `oo::PList` converters.
- **Shape:** the header is long (the whole `OOJSxxx` helper API is declared there) and every slice
  reads it together with a ~330-line preamble, so each slice may own only ~390 lines. That makes
  four slices. Every helper that sends an Objective-C message goes to a slice; the rest (about
  half of them: `jsid` / string conversion, `oo::PList` builders, the subclass and converter
  registries) have no Objective-C and stay verbatim
  ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9).
- **Order:** after the scripting-bindings pattern seam (oo-ppc, `OOJSVector`). Slice 1 first: it
  converts the engine class shell and lifecycle; slices 2-4 then attach members to it or are
  free functions, and are independent of one another.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | engine shell and lifecycle: `sharedEngine`, `init`, context create / destroy, `reset`, `dealloc`, standard class lookup, monitor support | ~315 | ~1,415 |
| 2 | engine accessors, GC roots, `callJSFunction`, debugger flags; `ReportJSError` and the error / warning reporting functions; jsid cache init | ~355 | ~1,455 |
| 3 | `OOJSDumpStack`, `DescribeValue`, string-literal cache; `OOObject` / `OONativeVector` JS conversion, `OONull`, native-object → JS value | ~350 | ~1,450 |
| 4 | `OOJSValue`; the object wrapper (finalize, `toString`); entity predicates; class-checked native-object getters and converters | ~280 | ~1,380 |
| verbatim | helpers with no Objective-C | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Scripting/OOJavaScriptEngine.mm
header: upstream/oolite/src/Core/Scripting/OOJavaScriptEngine.h

slice 1: engine class shell, lifecycle and monitor support
  +[OOJavaScriptEngine sharedEngine]
  -[OOJavaScriptEngine runMissionCallback]
  -[OOJavaScriptEngine init]
  -[OOJavaScriptEngine createMainThreadContext]
  -[OOJavaScriptEngine destroyMainThreadContext]
  -[OOJavaScriptEngine reset]
  -[OOJavaScriptEngine dealloc]
  -[OOJavaScriptEngine lookUpStandardClassPointers]
  -[OOJavaScriptEngine registerStandardObjectConverters]
  @OOJavaScriptEngine(OOMonitorSupport*)

slice 2: engine accessors and debugger flags; error and warning reporting
  @OOJavaScriptEngine
  ReportJSError()
  OOJSInitJSIDCachePRIVATE()
  cxx_OOJSReportErrorForCaller()
  cxx_OOJSReportErrorWithArguments()
  cxx_OOJSReportWarningForCaller()
  cxx_OOJSReportWarningWithArguments()
  cxx_OOJSReportBadArguments()
  OOJSReportWrappedException()

slice 3: stack dumps, value description, OOObject / OONativeVector / OONull JS conversion
  OOJSDumpStack()
  DescribeValue()
  OOJSStrLiteralCachePRIVATE()
  @OOObject(OOJavaScriptConversion)
  @OONativeVector(OOJavaScriptConversion)
  @OONull
  IsOOObjectRooted()
  OOJSValueFromNativeObject()

slice 4: OOJSValue, the object wrapper, entity predicates and native-object converters
  @OOJSValue
  OOJSObjectWrapperFinalize()
  OOJSObjectWrapperToString()
  JSFunctionPredicate()
  JSEntityIs*Predicate()
  OOJSNativeObjectOfClassFrom*()
  OOJSBasicPrivateObjectConverter()
  PListFromJSArray()

verbatim: plain C/C++ helpers, no Objective-C (checked)
  *
```
