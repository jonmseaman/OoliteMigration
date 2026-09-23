#!/usr/bin/env python3
"""
tools/refactor/js-types.py — Phase 1 seam 1.2b (the second clang-refactor-style script, after
js-stubs.sh): moves Oolite's remaining SpiderMonkey vocabulary onto the ooscript façade
(src/Core/Scripting/ooscript/JSEngine.hpp) so that no game file needs the engine's header.

    python3 tools/refactor/js-types.py [--check] <file>...

It is a token-level rewrite, not a parser. Every rule below is a 1:1 spelling change whose
target has the same meaning under the SpiderMonkey backend (JSEngine.hpp's contract: Value,
PropertyId and the handle types are byte copies of the engine's own), so the goldens must not
move. What the rules cannot express (engine-only debugger calls, a class table that needs a
new slot, a native whose body uses `vp` in an unusual way) is left for the compiler to point
at and a human or agent to finish: the script never guesses.

--check prints what would change and exits 1 if anything would.
"""
import re
import sys
from pathlib import Path

F = 'ooscript::'

# --- 1. Engine calls with a 1:1 façade function (README.md "Retarget map") -------------------
CALLS = {
    'NewNumberValue': 'newNumberValue', 'ValueToNumber': 'valueToNumber',
    'ValueToBoolean': 'valueToBoolean', 'ValueToObject': 'valueToObject',
    'ValueToInt32': 'valueToInt32', 'ValueToECMAInt32': 'valueToECMAInt32',
    'ValueToECMAUint32': 'valueToECMAUint32', 'ValueToString': 'valueToString',
    'ValueToFunction': 'valueToFunction', 'ValueToId': 'valueToId', 'IdToValue': 'idToValue',
    'TypeOfValue': 'typeOfValue', 'GetTypeName': 'typeName', 'IsConstructing': 'isConstructing',
    'NewObject': 'newObject', 'InitStandardClasses': 'initStandardClasses',
    'ClearScope': 'clearScope', 'InitClass': 'initClass', 'DefineObject': 'defineObject',
    'GetConstructor': 'getConstructor', 'GetPrototype': 'getPrototype', 'GetParent': 'getParent',
    'GetGlobalObject': 'getGlobalObject', 'GetGlobalForObject': 'getGlobalForObject',
    'GetClass': 'getClass', 'InstanceOf': 'instanceOf', 'SetPrivate': 'setPrivate',
    'GetPrivate': 'getPrivate', 'GetInstancePrivate': 'getInstancePrivate',
    'ObjectIsFunction': 'objectIsFunction', 'GetProperty': 'getProperty',
    'SetProperty': 'setProperty', 'GetPropertyById': 'getPropertyById',
    'SetPropertyById': 'setPropertyById', 'DefinePropertyById': 'definePropertyById',
    'LookupProperty': 'lookupProperty', 'LookupPropertyById': 'lookupPropertyById',
    'HasProperty': 'hasProperty', 'DeleteProperty': 'deleteProperty',
    'GetMethodById': 'getMethodById', 'DefineProperty': 'defineProperty',
    'DefineProperties': 'defineProperties', 'DefineFunction': 'defineFunction',
    'DefineFunctions': 'defineFunctions', 'SetElement': 'setElement', 'GetElement': 'getElement',
    'LookupElement': 'lookupElement', 'NewArrayObject': 'newArrayObject',
    'IsArrayObject': 'isArrayObject', 'GetArrayLength': 'getArrayLength',
    'SetArrayLength': 'setArrayLength', 'Enumerate': 'enumerate',
    'DestroyIdArray': 'destroyIdArray', 'GetFunctionId': 'getFunctionId',
    'GetFunctionObject': 'getFunctionObject', 'GetFunctionNative': 'getFunctionNative',
    'CallFunctionValue': 'callFunctionValue', 'CallFunctionName': 'callFunctionName',
    'EvaluateScript': 'evaluateScript', 'EvaluateUCScript': 'evaluateUCScript',
    'CompileUCScript': 'compileUCScript', 'NewScriptObject': 'newScriptObject',
    'ExecuteScript': 'executeScript', 'DestroyScript': 'destroyScript',
    'InternString': 'internString', 'InternUCStringN': 'internUCStringN',
    'NewStringCopyZ': 'newStringCopyZ', 'NewStringCopyN': 'newStringCopyN',
    'NewUCStringCopyN': 'newUCStringCopyN',
    'NewUCRegExpObjectNoStatics': 'newUCRegExpObjectNoStatics',
    'GetEmptyStringValue': 'emptyStringValue', 'GetStringLength': 'getStringLength',
    'GetStringCharsAndLength': 'getStringCharsAndLength',
    'GetInternedStringChars': 'getInternedStringChars', 'StringEqualsAscii': 'stringEqualsAscii',
    'StringHasBeenInterned': 'stringHasBeenInterned', 'SetCStringsAreUTF8': 'setCStringsAreUTF8',
    'SetGCZeal': 'setGCZeal', 'IsExceptionPending': 'isExceptionPending',
    'GetPendingException': 'getPendingException', 'SetPendingException': 'setPendingException',
    'ClearPendingException': 'clearPendingException',
    'ReportPendingException': 'reportPendingException', 'ReportOutOfMemory': 'reportOutOfMemory',
    'SetErrorReporter': 'setErrorReporter', 'SaveExceptionState': 'saveExceptionState',
    'RestoreExceptionState': 'restoreExceptionState', 'DropExceptionState': 'dropExceptionState',
    'AddNamedObjectRoot': 'addNamedObjectRoot', 'AddNamedValueRoot': 'addNamedValueRoot',
    'AddNamedStringRoot': 'addNamedStringRoot', 'RemoveObjectRoot': 'removeObjectRoot',
    'RemoveValueRoot': 'removeValueRoot', 'RemoveStringRoot': 'removeStringRoot',
    'NewRuntime': 'newRuntime', 'DestroyRuntime': 'destroyRuntime', 'ShutDown': 'shutDown',
    'NewContext': 'newContext', 'DestroyContext': 'destroyContext', 'GetRuntime': 'getRuntime',
    'GetContextPrivate': 'getContextPrivate', 'SetContextPrivate': 'setContextPrivate',
    'BeginRequest': 'beginRequest', 'EndRequest': 'endRequest', 'IsInRequest': 'isInRequest',
    'SetOptions': 'setOptions', 'GetOptions': 'getOptions', 'SetVersion': 'setVersion',
    'GetVersion': 'getVersion', 'VersionToString': 'versionToString',
    'GetGCParameter': 'getGCParameter', 'SetGCParameter': 'setGCParameter', 'GC': 'gc',
    'MaybeGC': 'maybeGC', 'SetOperationCallback': 'setOperationCallback',
    'TriggerOperationCallback': 'triggerOperationCallback',
    'TriggerAllOperationCallbacks': 'triggerAllOperationCallbacks',
}
STUBS = ['PropertyStub', 'StrictPropertyStub', 'EnumerateStub', 'ResolveStub', 'ConvertStub',
         'FinalizeStub']

# --- 2. Value / id macros -------------------------------------------------------------------
VALUE_FUNCS = {
    'JSVAL_IS_VOID': 'isUndefined', 'JSVAL_IS_NULL': 'isNull', 'JSVAL_IS_OBJECT': 'isObjectOrNull',
    'JSVAL_IS_STRING': 'isString', 'JSVAL_IS_INT': 'isInt32', 'JSVAL_IS_DOUBLE': 'isDouble',
    'JSVAL_IS_NUMBER': 'isNumber', 'JSVAL_IS_BOOLEAN': 'isBoolean',
    'JSVAL_IS_PRIMITIVE': 'isPrimitive', 'JSVAL_TO_OBJECT': 'toObject',
    'JSVAL_TO_STRING': 'toString', 'JSVAL_TO_INT': 'toInt32', 'JSVAL_TO_DOUBLE': 'toDouble',
    'JSVAL_TO_BOOLEAN': 'toBoolean', 'JSVAL_TO_PRIVATE': 'toPrivate',
    'OBJECT_TO_JSVAL': 'objectValue', 'STRING_TO_JSVAL': 'stringValue',
    'INT_TO_JSVAL': 'int32Value', 'BOOLEAN_TO_JSVAL': 'booleanValue',
    'PRIVATE_TO_JSVAL': 'privateValue', 'DOUBLE_TO_JSVAL': 'numberValue',
    'JSID_IS_STRING': 'isStringId', 'JSID_TO_STRING': 'idToString', 'JSID_IS_INT': 'isInt32Id',
    'JSID_TO_INT': 'idToInt32', 'JSID_IS_VOID': 'isVoidId', 'INT_TO_JSID': 'int32Id',
}
VALUE_CONSTS = {
    'JSVAL_VOID': 'undefinedValue()', 'JSVAL_NULL': 'nullValue()', 'JSVAL_TRUE': 'trueValue()',
    'JSVAL_FALSE': 'falseValue()', 'JSID_VOID': 'voidId()',
}
FLAG_CONSTS = {
    'JSPROP_ENUMERATE': 'PropertyFlag::Enumerate', 'JSPROP_READONLY': 'PropertyFlag::ReadOnly',
    'JSPROP_PERMANENT': 'PropertyFlag::Permanent', 'JSPROP_SHARED': 'PropertyFlag::Shared',
    'JSCLASS_HAS_PRIVATE': 'ClassFlag::HasPrivate',
    'JSCLASS_NEW_ENUMERATE': 'ClassFlag::NewEnumerate',
    'JSCLASS_GLOBAL_FLAGS': 'ClassFlag::Global',
    'JSTYPE_VOID': 'Type::Void', 'JSTYPE_OBJECT': 'Type::Object', 'JSTYPE_FUNCTION': 'Type::Function',
    'JSTYPE_STRING': 'Type::String', 'JSTYPE_NUMBER': 'Type::Number',
    'JSTYPE_BOOLEAN': 'Type::Boolean', 'JSTYPE_NULL': 'Type::Null', 'JSTYPE_XML': 'Type::XML',
    'JSENUMERATE_INIT': 'EnumerateOp::Init', 'JSENUMERATE_INIT_ALL': 'EnumerateOp::InitAll',
    'JSENUMERATE_NEXT': 'EnumerateOp::Next', 'JSENUMERATE_DESTROY': 'EnumerateOp::Destroy',
    'JSGC_BYTES': 'GCParam::Bytes', 'JSGC_MAX_BYTES': 'GCParam::MaxBytes',
    'JSGC_MAX_MALLOC_BYTES': 'GCParam::MaxMallocBytes', 'JSGC_NUMBER': 'GCParam::NumberOfGCs',
}

# --- 3. Types -------------------------------------------------------------------------------
# Pointer handles: `JSObject *x` -> `ooscript::Object x` (the handle is already a pointer).
HANDLE_TYPES = {'JSContext': 'Context', 'JSObject': 'Object', 'JSString': 'String',
                'JSFunction': 'Function', 'JSRuntime': 'Runtime', 'JSScript': 'Script'}
PLAIN_TYPES = {'jsval': F + 'Value', 'jsid': F + 'PropertyId', 'JSBool': 'bool',
               'uintN': 'unsigned', 'intN': 'int', 'jsdouble': 'double', 'jschar': F + 'Char16',
               'jsuint': 'uint32_t', 'jsint': 'int32_t', 'JSClass': F + 'ClassDef',
               'JSPropertySpec': F + 'PropertySpec', 'JSFunctionSpec': F + 'FunctionSpec',
               'JSType': F + 'Type', 'JSIdArray': F + 'IdArray', 'JSErrorReport': F + 'ErrorReport',
               'JSErrorReporter': F + 'ErrorReporter', 'JSExceptionState': F + 'ExceptionState'}
BOOL_CONSTS = {'JS_TRUE': 'true', 'JS_FALSE': 'false'}

# Casts the retarget sweep used between the two vocabularies; after this script both sides are
# the same type and the casts are identities.
SHIM_CASTS = ['OOJSFCX', 'OOJSRCX', 'OOJSFOBJ', 'OOJSROBJ', 'OOJSRVAL', 'OOJSFVALP', 'OOJSFVAL',
              'OOJSRJSID', 'OOJSFJSID', 'OOJSFSTR', 'OOJSRSTR']


def sub_word(pattern, repl, text):
    return re.sub(r'\b' + pattern + r'\b', repl, text)


def _body_end(rest):
    """Index just past the brace-balanced body that `rest` starts with (after whitespace), or None."""
    mb = re.match(r'\s*\{', rest)
    if not mb:
        return None
    depth, i = 0, mb.end() - 1
    while i < len(rest):
        c = rest[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return None


SM_NATIVE = re.compile(r'\bJSBool(\s+)(\w+)\s*\(\s*JSContext\s*\*\s*(\w+)\s*,\s*uintN\s+argc\s*,\s*jsval\s*\*\s*vp\s*\)')
FACADE_NATIVE = re.compile(r'\bbool(\s+)(\w+)\s*\(\s*(?:ooscript::)?Context\s+(\w+)\s*,\s*(?:ooscript::)?CallArgs\s*&\s*oojsArgs\s*\)')
SHIM_LINES = [
    re.compile(r'\n[ \t]*JSContext\s*\*\s*context\s*=\s*OOJSRCX\(cx\);[ \t]*(?=\n)'),
    re.compile(r'\n[ \t]*uintN\s+argc\s*=\s*oojsArgs\.count\(\);[ \t]*(?=\n)'),
    re.compile(r'\n[ \t]*jsval\s*\*\s*vp\s*=\s*OOJSRVAL\(oojsArgs\.rawVp\(\)\);[ \t]*(?=\n)'),
]


def rewrite_natives(text):
    """Every native becomes `bool Name(ooscript::Context context, ooscript::CallArgs &oojsArgs)`:
    engine-signature natives (JSContext *, uintN argc, jsval *vp) and the retarget sweep's
    façade-signature ones with their three-line shim alike. Inside the body `argc` and `vp`
    become the CallArgs accessors, so no local mirrors the engine's calling convention."""
    out, pos = [], 0
    while True:
        found = [m for m in (SM_NATIVE.search(text, pos), FACADE_NATIVE.search(text, pos)) if m]
        if not found:
            break
        m = min(found, key=lambda x: x.start())
        out.append(text[pos:m.start()])
        name, cxname = m.group(2), m.group(3)
        rest = text[m.end():]
        end = _body_end(rest)
        body = rest[:end] if end else ''
        renamed = m.re is FACADE_NATIVE and SHIM_LINES[0].search(body) is not None
        if renamed:
            cxname = 'context'
        out.append(f'bool{m.group(1)}{name}({F}Context {cxname}, {F}CallArgs &oojsArgs)')
        if end:
            for sl in SHIM_LINES:
                body = sl.sub('', body, count=1)
            if renamed:
                body = sub_word('cx', 'context', body)   # the shim's `context` and the parameter are now one
            body = sub_word('argc', 'oojsArgs.count()', body)
            body = sub_word('vp', 'oojsArgs.rawVp()', body)
            out.append(body)
            pos = m.end() + end
        else:
            pos = m.end()
    out.append(text[pos:])
    return ''.join(out)


def remove_shims(text):
    # Shim cast helper definitions become dead: drop `namespace {\nstatic inline ... OOJSxxx(...) {...}\n} // namespace`
    text = re.sub(r'namespace \{\n(?:static )?inline [^\n]*\b(?:' + '|'.join(SHIM_CASTS) + r')\s*\([^\n]*\n\} // namespace\n', '', text)
    for c in SHIM_CASTS:
        text = re.sub(r'\b' + c + r'\s*\(', '(', text)
    return text


def fix_declarators(text, tname, new):
    # `JSObject *a, *b, *c` -> `ooscript::Object a, b, c` (one declaration's declarator list).
    pat = re.compile(r'\b' + tname + r'(\s*)\*(\s*\w+(?:\s*=\s*[^,;()]+)?)((?:\s*,\s*\*\s*\w+(?:\s*=\s*[^,;()]+)?)+)(\s*;)')
    def repl(m):
        rest = re.sub(r',\s*\*\s*', ', ', m.group(3))
        return new + ' ' + m.group(2).strip() + rest + m.group(4)
    return pat.sub(repl, text)


def transform(text):
    orig = text
    text = rewrite_natives(text)
    text = remove_shims(text)
    # includes
    text = re.sub(r'#\s*(?:include|import)\s*<js(?:api|dbgapi|friendapi|pubtd)\.h>\s*\n', '', text)
    text = re.sub(r'#\s*(?:include|import)\s*"js(?:api|dbgapi|friendapi|pubtd)\.h"\s*\n', '', text)
    # calls
    for k, v in CALLS.items():
        text = sub_word('JS_' + k, F + v, text)
    for s in STUBS:
        text = sub_word('JS_' + s, 'nullptr', text)
    for k, v in BOOL_CONSTS.items():
        text = sub_word(k, v, text)
    # value / id macros
    for k, v in VALUE_FUNCS.items():
        text = sub_word(k, F + v, text)
    for k, v in VALUE_CONSTS.items():
        text = sub_word(k, F + v, text)
    for k, v in FLAG_CONSTS.items():
        text = sub_word(k, F + v, text)
    # types
    for t, h in HANDLE_TYPES.items():
        text = fix_declarators(text, t, F + h)
        text = re.sub(r'\b(?:const\s+)?' + t + r'\s*\*', F + h + ' ', text)
    for t, v in PLAIN_TYPES.items():
        text = sub_word(t, v, text)
    text = re.sub(r'ooscript::(\w+) ([,)])', r'ooscript::\1\2', text)   # "Object )" -> "Object)"
    text = text.replace('ooscript::ooscript::', 'ooscript::')
    return text, text != orig


LF, CRLF = chr(10), chr(13) + chr(10)   # a file's line endings are kept as they were


def main(argv):
    check = '--check' in argv
    files = [a for a in argv[1:] if a != '--check']
    changed = 0
    for f in files:
        p = Path(f)
        raw = p.read_bytes().decode('utf-8', errors='surrogateescape')
        crlf = CRLF in raw
        src = raw.replace(CRLF, LF)
        new, did = transform(src)
        if crlf:
            new = new.replace(LF, CRLF)
        if did:
            changed += 1
            print(f'js-types: {"would rewrite" if check else "rewrote"} {f}')
            if not check:
                p.write_bytes(new.encode('utf-8', errors='surrogateescape'))
    return 1 if (check and changed) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
