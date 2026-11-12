"""T045: generate specs/009-modern-cpp-std/external-values.md. Builds and runs a C++ program, with
the game's compile flags, that prints the value the program uses for every enumerator whose name or
number leaves the program (research R8's visibility table)."""
import json, os, re, shlex, subprocess, sys

ROOT = '/Users/jonms/OoliteMigration/oolite-dev'
OUT = '/Users/jonms/OoliteMigration/.agent-tmp/extvals'
SPEC = '/Users/jonms/OoliteMigration/specs/009-modern-cpp-std/external-values.md'

def strip_comments(t):
    t = re.sub(r'/\*.*?\*/', '', t, flags=re.S)
    return re.sub(r'//[^\n]*', '', t)

def enum_body(header, start_regex):
    text = open(os.path.join(ROOT, header)).read()
    m = re.search(start_regex, text, re.M | re.S)
    if not m:
        sys.exit(f'{header}: no {start_regex}')
    i = text.index('{', m.start())
    depth, j = 0, i
    while True:
        if text[j] == '{': depth += 1
        elif text[j] == '}':
            depth -= 1
            if depth == 0: break
        j += 1
    return text[i + 1:j]

def enumerators(body):
    """Items in order: ('pp', directive line) for #if/#ifdef/#else/#elif/#endif, ('name', n)."""
    items = []
    for raw in strip_comments(body).split('\n'):
        line = raw.strip()
        if not line:
            continue
        if line.startswith('#'):
            if re.match(r'#\s*(if|ifdef|ifndef|else|elif|endif)\b', line):
                items.append(('pp', line))
            continue
        for part in line.split(','):
            m = re.match(r'\s*([A-Za-z_]\w*)', part)
            if m: items.append(('name', m.group(1)))
    return items

# (enum, header, start regex, external form, where visible, pin task)
NAMED = [
    ('OORouteType', 'src/Core/OOTypes.h', r'typedef enum \{[^}]*\}\s*OORouteType\s*;', 'name and number', 'JS (`OOJSSystemInfo.cpp:1002`), saved game `chart_ana_mode`', 'T059'),
    ('OOCargoType', 'src/Core/OOTypes.h', r'typedef enum \{[^}]*\}\s*OOCargoType\s*;', 'name', 'shipdata `cargo_type` (`ShipEntity.cpp:1393`)', 'T059'),
    ('OOEnergyUnitType', 'src/Core/OOTypes.h', r'typedef enum \{[^}]*\}\s*OOEnergyUnitType\s*;', 'name and number', 'log; legacy saved game `energy_unit` (`PlayerEntity.cpp:1760`)', 'T059'),
    ('OODockingClearanceStatus', 'src/Core/OOTypes.h', r'typedef enum \{[^}]*\}\s*OODockingClearanceStatus\s*;', 'name', 'JS (`OOJSPlayer.cpp:350`)', 'T059'),
    ('OOGraphicsDetail', 'src/Core/OOTypes.h', r'typedef enum \{[^}]*\}\s*OOGraphicsDetail\s*;', 'name and number', 'debug console (`Universe.cpp:4948`), preferences `detailLevel`, description key `gameoptions-detaillevel-[n]`', 'T059'),
    ('OOWeaponFacing', 'src/Core/OOTypes.h', r'typedef enum \{[^}]*\}\s*OOWeaponFacing\s*;', 'number (bits)', 'shipdata `weapon_facings`, JS `weaponFacings`', 'T053'),
    ('OOShaderSetting', 'src/Core/OOOpenGL.h', r'typedef enum \{[^}]*\}\s*OOShaderSetting\s*;', 'name', 'GPU configuration (`OOOpenGLExtensionManager.cpp:335`)', 'T059'),
    ('OOHDRToneMapper', 'src/SDL/MyOpenGLView.h', r'typedef enum \{[^}]*\}\s*OOHDRToneMapper\s*;', 'name and number', 'preferences, JS (`OOJSOolite.cpp:207-296`)', 'T059'),
    ('OOSDRToneMapper', 'src/SDL/MyOpenGLView.h', r'typedef enum \{[^}]*\}\s*OOSDRToneMapper\s*;', 'name and number', 'preferences, JS (`OOJSOolite.cpp:207-296`)', 'T059'),
    ('WORMHOLE_SCANINFO', 'src/Core/Entities/WormholeEntity.h', r'typedef enum \{[^}]*\}\s*WORMHOLE_SCANINFO\s*;', 'name', 'JS, via `WormholeEntity.cpp:854-866`', 'T059'),
    ('OOAlertCondition', 'src/Core/Entities/ShipEntity.h', r'typedef enum \{[^}]*\}\s*OOAlertCondition\s*;', 'number', 'shaders (`EntityShaderBindings.cpp:661`), JS `alertCondition`', 'T057'),
    ('OOStationAlertLevel', 'src/Core/Entities/StationEntity.h', r'typedef enum \{[^}]*\}\s*OOStationAlertLevel\s*;', 'number', 'JS (`OOJSStation.cpp:278`)', 'T057'),
    ('OOSpeechSettings', 'src/Core/Entities/PlayerEntity.h', r'typedef enum \{[^}]*\}\s*OOSpeechSettings\s*;', 'number', 'saved game `speech_on`', 'T057'),
    ('OOFuelScoopStatus', 'src/Core/Entities/PlayerEntity.h', r'typedef enum \{[^}]*\}\s*OOFuelScoopStatus\s*;', 'number', 'shaders (`EntityShaderBindings.cpp:624`)', 'T057'),
    ('OOMissileStatus', 'src/Core/Entities/PlayerEntity.h', r'typedef enum \{[^}]*\}\s*OOMissileStatus\s*;', 'number', 'shaders (`EntityShaderBindings.cpp:611`)', 'T057'),
    ('OOPlayerFleeingStatus', 'src/Core/Entities/PlayerEntity.h', r'typedef enum \{[^}]*\}\s*OOPlayerFleeingStatus\s*;', 'number', 'JS', 'T057'),
    ('OOMarketFilterMode', 'src/Core/Entities/PlayerEntity.h', r'typedef enum \{[^}]*\}\s*OOMarketFilterMode\s*;', 'number', 'description key `oolite-market-filter-[n]`', 'T057'),
    ('OOMarketSorterMode', 'src/Core/Entities/PlayerEntity.h', r'typedef enum \{[^}]*\}\s*OOMarketSorterMode\s*;', 'number', 'description key `oolite-market-sorter-[n]`', 'T057'),
]
ANON = [
    ('ALERT_FLAG_* (OOAlertFlags)', 'src/Core/Entities/PlayerEntity.h', r'^enum\s*\{\s*\n\s*ALERT_FLAG_', 'number (bits)', 'JS alert flags (`OOJSPlayer.cpp:273-293`)', 'T052'),
    ('AXIS_* (joystick)', 'src/Core/OOJoystickManager.h', r'^enum\s*\{\s*\n\s*AXIS_', 'number', 'preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED`', 'T067'),
    ('BUTTON_* (joystick)', 'src/Core/OOJoystickManager.h', r'^enum\s*\{\s*\n\s*BUTTON_', 'number', 'preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED`', 'T067'),
    ('OO_POSTFX_* (post-processing)', 'src/Core/Universe.h', r'^enum\s*\{\s*\n\s*OO_POSTFX_', 'number', 'JS `oolite.postFX` (`OOJSOolite.cpp:199`)', 'T068'),
]
# The .tbl enums: (table, enum, header, macro form, where, pin)
TABLES = [
    ('OOEntityStatus.tbl', 'OOEntityStatus', 'ENTRY', 'JS `status`, shipdata, AI', 'T060'),
    ('OOScanClass.tbl', 'OOScanClass', 'ENTRY', 'JS `scanClass`, shipdata `scan_class`', 'T060'),
    ('OOShipDamageType.tbl', 'OOShipDamageType', 'DIFF_STRING_ENTRY', 'JS damage types', 'T060'),
    ('OOBehaviour.tbl', 'OOBehaviour', 'ENTRY', 'JS, saved game (`ShipEntity.cpp:6726`)', 'T061'),
    ('OOGalacticHyperspaceBehaviour.tbl', 'OOGalacticHyperspaceBehaviour', 'GALACTIC_HYPERSPACE_ENTRY', 'planetinfo / JS galactic hyperspace behaviour', 'T061'),
    ('OOLegalStatusReason.tbl', 'OOLegalStatusReason', 'DIFF_STRING_ENTRY', 'JS legal-status change reasons', 'T061'),
    ('OOCompassMode.tbl', 'OOCompassMode', 'ENTRY', 'JS `compassMode`, shaders (`EntityShaderBindings.cpp:637`)', 'T062'),
    ('OOViewID.tbl', 'OOViewID', 'ENTRY', 'JS `viewDirection`', 'T062'),
    ('OOLongRangeChartMode.tbl', 'OOLongRangeChartMode', 'ENTRY', 'saved game `chart_colour_mode`', 'T063'),
    ('OOGUIScreenID.tbl', 'OOGUIScreenID', 'ENTRY', 'JS `guiScreen`', 'T063'),
]

lines = ['#include <cstdio>',
         '#include "OOEntityEnums.h"', '#include "OOTypes.h"', '#include "OOOpenGL.h"',
         '#include "MyOpenGLView.h"', '#include "Entities/WormholeEntity.h"',
         '#include "Entities/ShipEntity.h"', '#include "Entities/StationEntity.h"',
         '#include "Entities/PlayerEntity.h"', '#include "OOJoystickManager.h"', '#include "Universe.h"',
         'int main() {']
meta = []
for enum, header, rx, form, where, pin in NAMED + ANON:
    items = enumerators(enum_body(header, rx))
    meta.append((enum, form, where, pin, None, None))
    for kind, v in items:
        if kind == 'pp':
            lines.append(v)
        else:
            lines.append(f'  std::printf("V\\t{enum}\\t{v}\\t%lld\\t{v}\\n", (long long){v});')
for tbl, enum, macro, where, pin in TABLES:
    meta.append((enum, 'name and number', where, pin, None, tbl))
    if macro == 'ENTRY':
        lines.append(f'#define ENTRY(label, value) std::printf("V\\t{enum}\\t%s\\t%lld\\t%s\\n", #label, (long long)label, #label);')
    elif macro == 'DIFF_STRING_ENTRY':
        lines.append(f'#define DIFF_STRING_ENTRY(label, string) std::printf("V\\t{enum}\\t%s\\t%lld\\t%s\\n", #label, (long long)label, string);')
    else:
        lines.append(f'#define GALACTIC_HYPERSPACE_ENTRY(label, value) std::printf("V\\t{enum}\\t%s\\t%lld\\t%s\\n", "GALACTIC_HYPERSPACE_" #label, (long long)GALACTIC_HYPERSPACE_##label, #label);')
    lines.append(f'#include "Tables/{tbl}"')
    lines.append(f'#undef {macro}')
lines += ['  return 0;', '}']
os.makedirs(OUT, exist_ok=True)
src = os.path.join(OUT, 'extvals.cpp')
open(src, 'w').write('\n'.join(lines) + '\n')

db = json.load(open(os.path.join(ROOT, 'compile_commands.json')))
e = next(x for x in db if x['file'].endswith('src/Core/Universe.cpp'))
args = e.get('arguments') or shlex.split(e['command'])
cc, skip = [], False
for a in args:
    if skip: skip = False; continue
    if a in ('-o', '-MF', '-MQ', '-MT'): skip = True; continue
    if a in ('-MD', '-c') or a.endswith('Universe.cpp') or a.startswith('-flto'): continue
    cc.append(a)
if os.path.basename(cc[0]) == 'ccache': cc = cc[1:]
exe = os.path.join(OUT, 'extvals')
r = subprocess.run(cc + [src, '-o', exe], cwd=e['directory'], capture_output=True, text=True)
if r.returncode:
    print(r.stderr[-3000:]); sys.exit(1)
rows = [l.split('\t') for l in subprocess.run([exe], capture_output=True, text=True).stdout.splitlines() if l.startswith('V\t')]

out = ['# External names and values: spec 009', '',
       'Every enum name and number that leaves the program (research R8), with the value the program',
       'uses today, printed by a program compiled with the game\'s flags from these headers and tables',
       '(`external-values-gen.py` in this directory, 2026-11-12, `oolite-dev` after T044). A `.tbl` value column is',
       'not used: where it disagrees with the program (`OOViewID`, `OOLongRangeChartMode`,',
       '`OOGUIScreenID`), the program\'s value is the one recorded. The pin is the `static_assert` (and,',
       'for names, the `OOEnumName` switch) that the converting task adds beside the enum.', '',
       '| enum | enumerator | value | external form | where visible | pin |', '|---|---|---|---|---|---|']
by_enum = {}
for _, enum, name, value, ext in rows:
    by_enum.setdefault(enum, []).append((name, value, ext))
count = 0
for enum, form, where, pin, _, _ in meta:
    for name, value, ext in by_enum.get(enum, []):
        shown = f'`{ext}`' if 'name' in form else '—'
        out.append(f'| `{enum}` | `{name}` | {value} | {shown}{" and " + value if form == "name and number" else ""} | {where} | `static_assert` ({pin}) |')
        count += 1
out += ['', 'Also external, kept as they are and pinned by their own tasks: the `console.DEBUG_*` names and',
        'values of `OODebugFlags` (T046), the texture option bits in the `%X` shader cache key',
        '(`OODefaultShaderSynthesizer.cpp:353`, T056) and the debug TCP protocol numbers',
        '(`OODebugTCPConsoleProtocol.h`, T068, shared with the external console).']
open(SPEC, 'w').write('\n'.join(out) + '\n')
print(count, 'rows;', len(by_enum), 'enums')
