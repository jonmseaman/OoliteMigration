# Exceptions list: spec 009

The places a converted pattern may remain (FR-022, data-model.md *Exceptions list*). A row is added
in the same commit as the code it permits.

`check.sh` reads this table: it drops a search hit whose file equals the row's `file` and whose
line contains the row's `match` (a fixed substring of the permitted line, written without the
surrounding backticks), for the row's `category`. A row whose construct a clang-tidy guard flags
is a conflict to record here, never a suppression.

| category | file | match | construct | required by | owner / release | commit |
|---|---|---|---|---|---|---|
| alloc | `src/Core/OODemangle.h` | `&std::free` | `std::free` as the `std::unique_ptr` deleter of the demangled name | `abi::__cxa_demangle` returns `malloc` memory the caller must `free` | the `unique_ptr` in `OODemangle`, released at scope exit | T014 |
| oofnd | `src/oofnd/objc/OOFoundationTypes.h` | `NSInteger/NSUInteger were intptr_t` | a comment naming the old Foundation name | the banner records what the alias became | — | T033 |
| oofnd | `src/oofnd/objc/OOFoundationTypes.h` | `NSTimeInterval and CGFloat were double` | a comment naming the old Foundation name | the banner records what the aliases became | — | T033 |
| oofnd | `src/oofnd/objc/OOFoundationTypes.h` | `NSNotFound is oo::kNotFound` | a comment naming the old Foundation name | the banner records what the constant became | — | T033 |
| oofnd | `src/oofnd/objc/OOFoundationTypes.h` | `Foundation's own NSNotFound` | a comment naming the old Foundation name | the Foundation-collision guard's comment names Foundation's constant | — | T033 |
| oofnd | `src/oofnd/objc/OOFoundationTypes.h` | `Foundation's NSNotFound: the largest` | a comment naming the old Foundation name | oo::kNotFound's comment says what it replaces | — | T033 |
| enum | `src/Core/Entities/PlayerEntity.h` | `inline constexpr int GUI_ROW_` | GUI row numbers as typed constants, not an enumeration | D5: rows are positions added to and compared with GUI rows | — | `b422a5ee8` (T066) |
| enum | `src/Core/OOJoystickProfile.h` | `inline constexpr int STICKPROFILE_TYPE_` | the two stick-profile type numbers as typed constants | D5: upstream's numbers, unused, kept | — | `6329b654f` (T067) |
| enum | `src/SDL/MyOpenGLView.h` | `inline constexpr int gv` | `GameViewKeys` as typed constants | D5: one code space with characters and `OOKeyCode` | — | `e0f441ad4` (T068) |
| enum | `src/Core/Materials/OOPixMap.h` | `inline constexpr OOPixMapFormat kOOPixMap` | the pixel-map formats as typed constants | D5: a format is its component count, used in arithmetic | — | `e0f441ad4` (T068) |
| enum | `src/Core/Debug/OODebugTCPConsoleProtocol.h` | `inline constexpr std::uint32_t kOOTCPProtocolVersion` | the protocol's masks and version as typed constants | D5: bit masks and a packed version number on the wire | — | `e0f441ad4` (T068) |
| enum | `src/Core/Scripting/OOJSEngineCore.h` | `#define OOJS_PROP_` | QuickJS's property flags, kept as its own `#define`s | they are QuickJS's `JS_PROP_*` `uint8_t` flags, passed straight to `JS_CGETSET_MAGIC_DEF2` | — | `10986f049` (T065) |
| enum | `src/Core/OOJoystickManager.h` | `inline constexpr int AXIS_` | the joystick axis functions as typed constants | D5 (revised): one `int` function number for axes and buttons, from plists, in `int8_t` maps | — | `6329b654f` (T067) |
| enum | `src/Core/OOJoystickManager.h` | `inline constexpr int BUTTON_` | the joystick button functions as typed constants | as above | — | `6329b654f` (T067) |
| enum | `src/Core/OOVoxel.h` | `inline constexpr int CUBE_FACE_` | the cube-face bits as typed constants | masks or-ed into a `long` | — | `6329b654f` (T067) |
| enum | `src/Core/OOTypes.h` | `enum` | the `enum` line of upstream's commented-out commodity enum (inside a `/* … */` block, `OOTypes.h:121-146`) | upstream's comment, kept as it is (rule 7); it is not code | — | T067 |
| enum | `src/Core/Materials/OOShaderUniformMethodType.h` | `inline constexpr OOShaderUniformType kOOShaderUniformType` | the uniform type tags as typed constants | stored as `uint8_t`, an index into the template table and the start of `OOJSCall`'s method-type numbers | — | `d5856ec7f` (T068) |
| cstring-types | `src/Core/Entities/OOEntityCalledByName.h` | `const char* name;` | the call-by-name tables' names, `const char*` literals | the tests read the tables as C strings (`std::strcmp(row.result, …)` in `test_OOJSCallEntityMethods.cpp`), so the member type is theirs; a later test-ledger change may convert it | — | T077 |
| cstring-types | `src/Core/Entities/OOEntityCalledByName.h` | `const char* result;` | the by-name rows' result encodings | as above: `std::strcmp(row.result, kOOTypeEncoding<…>)` in the test | — | T077 |
| cstring-types | `src/Core/Entities/OOEntityCalledByName.h` | `const char* encoding;` | the object-name rows' method encodings, null where there is none | null means "no encoding" and the test checks `row.encoding != nullptr` | — | T077 |
| cstring-types | `src/Core/Entities/EntityShaderBindings.cpp` | `const char* name;` | the shader-binding table's names | the table's encodings go to `OOShaderUniformTypeFromEncoding(const char*)` (materials, T079); kept with it | — | T077 |
| cstring-types | `src/Core/Entities/EntityShaderBindings.cpp` | `const char* encoding;` | the shader-binding table's encodings | as above | — | T077 |
| cstring-types | `src/Core/Entities/EntityShaderBindings.cpp` | `const char* property` | the shader binding's property name, null allowed | the binding function's type is the materials area's (`OOShaderUniformMethodType.h`) and a test stand-in (`test_OOShaderMaterial.cpp:318`) has its signature; null answers false | — | T077 |
| cstring-types | `src/Core/Entities/Entity.h` | `const char* property` | the declaration of the binding above | as above | — | T077 |
| cstring-types | `src/Core/Scripting/OOJavaScriptEngine.cpp` | `const char* format` | the printf-style JS error and warning reporters (`cxx_OOJSReportError` and kin) | their formats are printf syntax at some 600 call sites and go through oofnd's printf engine (FR-026); converting them to std::format is a call-site change of its own | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSEngineCore.h` | `const char* format` | the declarations of those reporters | as above | — | T078 |
| cstring-types | `src/Core/Scripting/poc/OOJavaScriptEnginePoc.cpp` | `const char* format` | the proof-of-concept harness's copies of the reporters | as above; the harness mirrors the engine's declarations | — | T078 |
| cstring-types | `src/Core/Scripting/OOJavaScriptEngine.cpp` | `ResetNotificationName =` | the engine-reset notification names | seven tests define these names as `const char* const` stand-ins of the header's declaration | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSEngineCore.h` | `ResetNotificationName;` | the declarations of those names | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSClasses.cpp` | `sClassNames[` | the registered class names, QuickJS `JSClassDef.class_name` pointers | QuickJS keeps and is given them as C strings (`JS_NewCFunction2`); null is "not registered" | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSClasses.cpp` | `OOJSClassName(` | `OOJSClassName`, which answers a registered name or null | as above, and tests check it with `!= nullptr` and `std::strcmp` (`test_OOJSShip.cpp:354`) | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSEngineCore.h` | `OOJSClassName(` | its declaration | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSPrivateObject.cpp` | `= OOJSClassName(` | a local holding its nullable answer | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSScript.cpp` | `= OOJSClassName(` | a local holding its nullable answer | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJavaScriptEngine.cpp` | `= OOJSClassName(` | a local holding its nullable answer | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSEngineDebuggerHelpers.cpp` | `= OOJSClassName(` | a local holding its nullable answer | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSSystemInfo.cpp` | `= JS_ToCString(` | a C string QuickJS returns, freed with `JS_FreeCString` | the QuickJS C interface | — | T078 |
| cstring-types | `src/Core/Scripting/OOJavaScriptEngine.cpp` | `= JS_ToCStringLen(` | a C string QuickJS returns, freed with `JS_FreeCString` | the QuickJS C interface | — | T078 |
| cstring-types | `src/Core/Scripting/poc/OOJavaScriptEnginePoc.cpp` | `= JS_ToCStringLen(` | a C string QuickJS returns | the QuickJS C interface | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSEngineDebuggerHelpers.cpp` | `= JS_ToCStringLen(` | a C string QuickJS returns | the QuickJS C interface | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSEngineDebuggerHelpers.cpp` | `= JS_AtomToCString(` | a C string QuickJS returns | the QuickJS C interface | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSEngineDebuggerHelpers.cpp` | `Dbg(` | the debugger helpers (`JSValueToStrDbg` and kin) and their banner | called from a debugger (`p JSValueToStrDbg(v)`), which prints a C string | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSEngineDebuggerHelpers.cpp` | `DebuggerCString(` | the helpers' C-string pool | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSPropID.h` | `OOJSInternAtomPRIVATE(const char* name)` | the atom interner behind `OOJSID("literal")` | `JS_NewAtom` takes a NUL-terminated name; every caller is the macro, with a literal | — | T078 |
| cstring-types | `src/Core/Scripting/OOJavaScriptEngine.cpp` | `OOJSInternAtomPRIVATE(const char* name)` | its definition | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSMission.cpp` | `const char* key` | the mission parameters' property names | `JS_GetPropertyStr` takes a NUL-terminated name; every caller passes a literal | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSStation.cpp` | `const char* key` | a parameter's property name | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSSystem.cpp` | `const char* key` | a parameter's property name | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSGlobal.cpp` | `const char* key` | a parameter's property name | as above | — | T078 |
| cstring-types | `src/Core/Scripting/poc/OOJSScript.h` | `stringPropertyNamed(const char* name` | the harness's property-name lookup | as above | — | T078 |
| cstring-types | `src/Core/Scripting/poc/OOJSScript.cpp` | `stringPropertyNamed(const char* name` | its definition | as above | — | T078 |
| cstring-types | `src/Core/Scripting/poc/main.cpp` | `const char* argv[]` | the harness's `main` | `main`'s argv | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSFunction.cpp` | `const char** argNames` | a compiled function's argument names | a test stand-in (`test_OORegExpMatcher.cpp:72`) has this signature | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSFunction.h` | `const char** argNames` | its declaration | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSCallEntityMethods.h` | `*name;` | the callObjC table's names | the tests read the table (`std::string bare = row.name`); kept with the encodings below | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSCallEntityMethods.h` | `*encoding;` | the callObjC table's encodings, null for a row that is not Typed | null means "not Typed" | — | T078 |
| cstring-types | `src/Core/Scripting/OOConstToJSString.cpp` | `const char* cString;` | the constant tables' names | `JS_NewAtom` takes them as NUL-terminated names | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSEngineNativeWrappers.h` | `const char* function` | the profiler's frame name | null is a nameless frame, which the profile reports as "(null)" (`test_OOJSEngineTimeManagement.cpp` passes NULL) | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSEngineTimeManagement.cpp` | `const char* function)` | `OOJSProfileEnter` | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSEngineTimeManagement.cpp` | `OOTimeProfileEntry(const char* name)` | a profile entry's nullable name | as above | — | T078 |
| cstring-types | `src/Core/Scripting/OOJSEngineTimeManagement.h` | `OOTimeProfileEntry(const char* name)` | its declaration | as above | — | T078 |
| cstring-types | `src/Core/OOOpenGLCheck.h` | `cxx_OOCheckOpenGLErrors(const char* format` | the printf-style GL error check | its formats are printf syntax at its call sites (FR-026), and two tests define stand-ins with this signature (`test_OOCrosshairs.cpp:43`, `test_OOTrumble.cpp:265`) | — | T079 |
| cstring-types | `src/Core/OOOpenGL.cpp` | `cxx_OOCheckOpenGLErrors(const char* format` | its definition | as above | — | T079 |
| cstring-types | `src/Core/OOOpenGLCheck.h` | `OOGLNoteCurrentFunction(const char*` | the GL call tracker's function name (`__FUNCTION__`) | the tracker compares names by pointer, and a test defines a stand-in with this signature (`test_OOCrosshairs.cpp:45`) | — | T079 |
| cstring-types | `src/Core/OOOpenGLStateManager.cpp` | `OOGLNoteCurrentFunction(const char*` | its definitions | as above | — | T079 |
| cstring-types | `src/Core/OOOpenGL.h` | `const char* function` | `OOSetOpenGLState_` and `OOVerifyOpenGLState_`'s caller names | tests define stand-ins with these signatures (`test_OOCrosshairs.cpp:38-39`) | — | T079 |
| cstring-types | `src/Core/OOOpenGLStateManager.cpp` | `const char* function` | their definitions | as above | — | T079 |
| cstring-types | `src/Core/OOOpenGLStateManager.cpp` | `const char* caller` | the verifier's caller names, from those entry points (declared `NONNULL_FUNC`) | as above | — | T079 |
| cstring-types | `src/Core/OOOpenGLStateManager.cpp` | `const char* nominalCaller` | as above | as above | — | T079 |
| cstring-types | `src/Core/OOOpenGLExtensionManager.cpp` | `reinterpret_cast<const char*>(` | GL's own strings (`glGetString`) | the OpenGL C interface returns `const GLubyte*` | — | T079 |
| cstring-types | `src/Core/OOOpenGL.cpp` | `reinterpret_cast<const char*>(errString)` | `gluErrorString`'s answer | the GLU C interface | — | T079 |
| cstring-types | `src/Core/OOOpenGLMatrixManager.h` | `ooliteStandardMatrixUniforms[]` | the standard matrix uniform names | they go to `glGetUniformLocation`, which takes NUL-terminated names | — | T079 |
| cstring-types | `src/Core/Materials/OOPNGTextureLoader.cpp` | `reinterpret_cast<const char*>(fileData->bytes())` | a byte pointer into the PNG data | byte arithmetic for `memcpy`, not text | — | T079 |
| cstring-types | `src/Core/Materials/OOShaderMaterial.h` | `const char* property` | the entity-binding property name, null allowed | the binding function type (`OOShaderUniformMethodType.h`) and a test stand-in have it; null binds nothing (as T077's rows) | — | T079 |
| cstring-types | `src/Core/Materials/OOShaderMaterial.cpp` | `const char* property` | as above | as above | — | T079 |
| cstring-types | `src/Core/Materials/OOShaderMaterial.cpp` | `const char* propertyName` | the nullable property name handed to the binding | as above | — | T079 |
| cstring-types | `src/Core/Materials/OOShaderUniform.h` | `const char* property` | as above | as above | — | T079 |
| cstring-types | `src/Core/Materials/OOShaderUniform.cpp` | `const char* property` | as above | as above | — | T079 |
| cstring-types | `src/Core/Materials/OOShaderUniformMethodType.h` | `const char* property` | the binding function type | as above | — | T079 |
| cstring-types | `src/Core/Materials/OOShaderUniformMethodType.h` | `OOShaderUniformTypeFromEncoding(const char* typeCode)` | a type encoding, null allowed (answers invalid) | tests pass table encodings that may be null (`test_OOJSCallEntityMethods.cpp:121,178`) | — | T079 |
| cstring-types | `src/Core/Materials/OOShaderUniformMethodType.cpp` | `OOShaderUniformTypeFromEncoding(const char* typeCode)` | its definition | as above | — | T079 |
| cstring-types | `src/Core/Materials/OOShaderUniformMethodType.cpp` | `sTemplates[` | the encodings it compares with, null for an unused slot | as above | — | T079 |
| cstring-types | `src/SDL/main.cpp` | `= SDL_getenv(` | an environment variable, which may be absent | `SDL_getenv` returns the environment's C string or null | — | T080 |
| cstring-types | `src/SDL/MyOpenGLView.cpp` | `SaveEXRSnapshot(const char* outfilename` | the declaration of the EXR snapshot writer | defined beside tinyexr (`OOSaveEXRSnapshot.cpp`, vendored directory), whose `SaveEXR` takes the file name as a C string | — | T080 |
| cstring-types | `src/SDL/MyOpenGLView.cpp` | `= SDL_GetError()` | SDL's error text | the SDL C interface | — | T080 |
| cstring-types | `src/SDL/OOSDLJoystickManager.cpp` | `= SDL_GetJoystickName(` | a joystick's name, null when SDL has none | the SDL C interface | — | T080 |
| cstring-types | `src/Core/Debug/OODebugTCPConsoleClient.cpp` | `static_cast<const char*>(bytes)` | the bytes `send` writes | the sockets C interface (Winsock's `send` takes `const char*`) | — | T080 |
| cstring-types | `src/Core/Debug/OOTCPStreamDecoderAbstractionLayer.cpp` | `const char* string` | the decoder's constant strings, keyed by the literal's address | the abstraction layer interns literals by pointer (its header says literals only) | — | T080 |
| cstring-types | `src/Core/Debug/OOTCPStreamDecoderAbstractionLayer.cpp` | `std::map<const char*,` | the interned strings' table, keyed by address | as above | — | T080 |
| cstring-types | `src/Core/Debug/OOTCPStreamDecoderAbstractionLayer.h` | `const char* string);` | its declaration | as above | — | T080 |
| cstring-types | `src/Core/Debug/OOTCPStreamDecoderAbstractionLayer.cpp` | `reinterpret_cast<const char*>(bytes.bytes())` | a packet's bytes viewed for the property-list parser | bytes, not text: the parser takes a `std::string_view` over them | — | T080 |
| cstring-types | `src/Core/Debug/OOJSConsole.cpp` | `const char* nominalFunction` | the console method name the profiler reports | it is the `%s` argument of the printf-style JS reporters (T078's row) | — | T080 |
| cstring-types | `src/Core/Debug/OOJSConsole.cpp` | `const char* function)` | the console method name in the not-the-monitor report | as above | — | T080 |
| cstring-types | `src/Core/Debug/OOJSConsole.cpp` | `const char* nameString` | a method name or "(null)" for the reporter | as above | — | T080 |
| cstring-types | `src/Core/Debug/OOJSConsole.cpp` | `const char* name;` | the console's callObjC table's names | kept with the encodings below | — | T080 |
| cstring-types | `src/Core/Debug/OOJSConsole.cpp` | `const char* encoding;` | the console's callObjC table's encodings, null for a row that is not Scalar | they go to `OOShaderUniformTypeFromEncoding(const char*)`, which takes null (T079's row) | — | T080 |
