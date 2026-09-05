# Oolite: Objective-C → Modern C++23 Migration Plan

**Status:** Draft 1 — planning only, no code changes made to `upstream/oolite`
**Date:** 2026-09-05
**Baseline surveyed:** `OoliteProject/oolite` @ `942f5183f` (1.77.1a-3135-g942f5183f, master)
**Author:** Jon Seaman (with Claude)

---

## 1. Executive summary

### Goal

Convert Oolite from Objective-C/GNUstep to Modern C++23, producing a single codebase that
builds natively for:

| Target | Arch | Toolchain | Status today |
|---|---|---|---|
| macOS | arm64 (Apple Silicon) | Apple Clang / LLVM | **Not supported at all** |
| Windows | x86-64 | clang-cl / MinGW-clang | Supported (GNUstep + MinGW) |
| Linux | x86-64 | clang / GCC | Supported (GNUstep) |

…while keeping all **1,591 published expansions** (OXP/OXZ) working unmodified.

### The five things that actually matter

Having measured the tree, the difficulty is *not* evenly distributed. Ranked by risk:

| # | Problem | Why it's hard | Verdict |
|---|---|---|---|
| **R1** | **SpiderMonkey 1.8.5** (Firefox 4.0, March 2011) | No `aarch64` in `configure.in` at all; JIT (nanojit) targets x86/x86-64/ARMv7/PPC/MIPS/SPARC only; autoconf 2.13 build. **3,828 `JS_*` call sites across 102 files.** | **Hard blocker for Apple Silicon.** Must be solved *before* anything else. Independent of the language migration. |
| **R2** | **GNUstep `libs-base` (Foundation)** | The real portability chain, not the ObjC language. ~11k Foundation references; `NSString` alone appears 6,286 times. | Replace with an in-tree C++23 layer. This is the migration's centre of gravity. |
| **R3** | **Manual retain/release** | ~2,100 `retain`/`release`/`autorelease` sites, 92 `NSAutoreleasePool`, no ARC, custom `OOWeakReference` proxy for cycles. | Mirror it exactly with an intrusive `oo::Ref<T>` / `oo::WeakRef<T>`. Do *not* reach for `std::shared_ptr` during translation. |
| **R4** | **OpenGL 2.1 compatibility profile** | 380 `glVertex3f`, 23 `glEnableClientState`, `glMatrixMode`; shaders are GLSL 1.10/1.20 (`gl_FragColor`, no `#version`). | Works on Apple Silicon *today* via macOS's legacy 2.1 profile. Ship on that; modernise to GL 3.3 Core as a separate, later phase. |
| **R5** | **Almost no automated tests + fast-moving upstream** | One Python smoke test (`tests/launch_snapshot.py`). Upstream took ~340 commits in the last 12 months. | Build a characterisation harness **first**. Everything else depends on it. |

### The load-bearing insight

**The Objective-C *runtime* is portable. GNUstep's *Foundation* is what blocks Apple Silicon.**

- Apple's `libobjc` supports arm64 natively; GNUstep's `libobjc2` supports Windows and Linux.
- So `@interface`, message sends, and retain/release can survive on all three platforms *during* the migration.
- What cannot survive is `libgnustep-base`.

This lets us decouple two things that are usually tangled together:

1. **Getting to Apple Silicon** — needs R1 (JS engine) + R2 (Foundation). Achievable in months.
2. **Getting to C++23** — a long, mechanical, file-by-file grind that can proceed afterwards
   without holding the platform goal hostage.

### Recommended strategy: *bridge, then convert* (strangler pattern)

Compile the whole tree as **Objective-C++** so C++ and Objective-C coexist. Introduce a C++23
Foundation replacement (`oofnd`) alongside the existing classes, then convert module by module
from the leaves inward. The build is shippable at every commit; GNUstep's Foundation is deleted
long before the last `@implementation` is.

The rejected alternative — a clean-room C++23 rewrite against the data formats — is faster to a
*nice* architecture and much slower to a *playable* one, with 225k LOC of undocumented gameplay
behaviour and 1,591 expansions as the acceptance criteria. Not worth it here.

### Expansion compatibility: the good news

**No OXP contains native code.** Verified: expansions are plists + JavaScript + `.dat` meshes +
PNG/OGG assets + GLSL. Even the in-tree `DebugOXP` is pure data and JS. The only native plugin
loader is a macOS-only debug path in `OODebugSupport.m:124`.

So expansion compatibility reduces to preserving six *contracts* (§9), not to migrating expansions.
A migration guide for expansion authors is only genuinely needed for the JS engine swap (§9.3) —
and the shipped scripts are already clean ES5 with zero SpiderMonkey-only syntax, which is
encouraging for the third-party corpus.

---

## 2. Where the code stands today (measured, not estimated)

All figures from `upstream/oolite` @ `942f5183f`.

### 2.1 Size

| Category | Files | Lines |
|---|---:|---:|
| Objective-C implementation (`.m`) | 241 | 183,603 |
| Objective-C headers (`.h`) | 265 | 41,214 |
| **Objective-C total** | **506** | **224,817** |
| C / C++ (mostly vendored + generated) | 8 | 59,088 |

Of the 59k C/C++: `OOPlanetData.c` is 48,170 lines of *generated tables*, `miniz.c` (7,853) and
`MiniZip/` (2,378) are vendored. Genuine hand-written C is ~600 lines. So the C/C++ present today
is essentially free — it carries over untouched.

### 2.2 Subsystem inventory

| Subsystem | Files | LOC | Migration character |
|---|---:|---:|---|
| `Core/` (top level) | 223 | 81,062 | Mixed. Contains the leaf utilities (easy) and `Universe.m` (hardest single file). |
| `Core/Entities/` | 84 | 70,599 | The gameplay core. `ShipEntity.m` (14,945) + `PlayerEntity.m` (13,718) dominate. |
| `Core/Scripting/` | 95 | 32,023 | The SpiderMonkey bridge. Already mostly C-shaped; mechanical but voluminous. |
| `Core/Materials/` | 47 | 13,951 | Shader/texture pipeline. Self-contained. |
| `SDL/` | 12 | 16,432 | Platform layer (incl. vendored `stb_image_write.h`). Where macOS support lands. |
| `Core/OXPVerifier/` | 27 | 5,872 | Standalone tool. Good early conversion candidate. |
| `Core/Debug/` | 16 | 4,235 | Debug console server — **keep working, it's the test harness**. |

### 2.3 Objective-C idiom census

| Idiom | Count | Translation |
|---|---:|---|
| `@interface` / `@implementation` | 396 / 353 | → `class` |
| Classes with a superclass | 183 (86 direct `NSObject`) | → single-inheritance hierarchy, mostly 1:1 |
| Categories (total declarations) | 210 | See below |
| — categories on **own** classes | ~155 | → member functions split across `.cpp` files. **Free.** |
| — categories on **Foundation** classes | ~55 | → free functions or `oofnd` methods |
| `@protocol` | 22 | → abstract base classes / concepts |
| `@property` | 5 | (old-style codebase; ivars + explicit accessors) |
| `retain` / `release` / `autorelease` | ~2,116 | → `oo::Ref<T>` |
| `NSAutoreleasePool` | 92 | → scope-based `oo::AutoreleaseScope` shim, then deleted |
| `@try` / `@catch` / `@throw` | 68 / 58 / 9 | → C++ exceptions (nearly 1:1) |
| `isKindOfClass:` | 333 | → `dynamic_cast` / visitor / type tag. **Needs review, not blind translation.** |
| `@selector` | 189 | → mostly `&Class::method` or `std::function` |
| `performSelector:` | 39 | → direct call after analysis |
| `NSSelectorFromString` | 10 | → explicit dispatch table. Requires care. |
| `NSClassFromString` | 4 | → factory registry |
| `objc_*` / `class_*` / `method_*` runtime calls | 17 | Trivially few. **Excellent news.** |
| `@synchronized` | **0** | — |
| KVC (`valueForKey:`) | 7 | → explicit accessors |

**Read:** this is *old-school, static* Objective-C. It uses the language as "C with classes and
refcounting", not as a dynamic metaprogramming substrate. That is the single best structural fact
about this migration — near-zero runtime introspection means almost everything can be resolved at
compile time in C++.

### 2.4 Foundation surface

| Class | Refs | | Class | Refs |
|---|---:|---|---|---:|
| `NSString` | 6,286 | | `NSException` | 88 |
| `NSDictionary` | 1,793 | | `NSFileManager` | 83 |
| `NSArray` | 1,543 | | `NSCharacterSet` | 49 |
| `NSNumber` | 635 | | `NSZone` | 49 |
| `NSMutableDictionary` | 553 | | `NSDate` | 31 |
| `NSMutableArray` | 490 | | `NSBundle` | 23 |
| `NSSet` | 196 | | `NSThread` | 22 |
| `NSEnumerator` | 174 | | `NSScanner` / `NSURL` | 21 / 21 |
| `NSMutableString` | 161 | | `NSURLConnection` | 13 |
| `NSMutableSet` | 159 | | `NSPropertyListSerialization` | 13 |
| `NSUserDefaults` | 145 | | `NSRunLoop` / `NSLock` | 11 / 10 |
| `NSData` | 123 | | `NSMapTable` / `NSNotification` | 9 / 9 |
| `NSValue` | 92 | | `NSTimer` | 6 |

Bounded and unsurprising: strings, collections, property lists, files, defaults. `NSURLConnection`
appears only in the OXZ download manager. This is a *replaceable* surface, not an open-ended one.

### 2.5 The one piece of luck: typed plist accessors

The codebase already funnels every property-list read through a typed, defaulted extractor API
(`OOCollectionExtractors`):

```
oo_stringForKey      559      oo_dictionaryForKey   146
oo_floatForKey       204      oo_unsignedIntForKey   81
oo_boolForKey        198      oo_doubleForKey        50
oo_intForKey         189      oo_vectorForKey        22
oo_arrayForKey       158      …and ~20 more variants
```

~1,800 call sites, all shaped `T oo_<type>ForKey:(NSString*)key defaultValue:(T)dflt`.

In C++23 this collapses to one templated accessor on a `PList` variant:

```cpp
template <class T> T get(std::string_view key, T fallback = {}) const;
```

This is the highest-leverage single conversion in the project: it retires ~1,800 sites with one
well-tested type, and it defines the shape of the whole data layer.

### 2.6 Build, dependencies, platform

Upstream migrated to **Meson** recently (the Apr–May 2026 commit spike). Dependencies:

- `sdl3`, `libpng`, `openal`, `vorbis`/`vorbisfile`, `zlib`, `nspr`, optional `espeak-ng`
- Linux additionally: `gl`, `glu`, `x11`
- **GNUstep**: `libobjc2` + `tools-make` + `libs-base`, built from pinned commits by
  `ShellScripts/Linux/build_gnustep.sh`
- **SpiderMonkey**: a *prebuilt static* `libjs_static.a` downloaded from
  `OoliteProject/mozillajs-linux` release 0.0.1

`src/meson/meson.build` dispatches to `windows/` or `linux/` only — **there is no macOS branch**.
`README.md` states plainly: *"OSX is not supported for v1.92"*. Apple Silicon is greenfield work,
not a regression to fix.

### 2.7 Rendering

Fixed-function and immediate mode throughout, alongside GLSL 1.x shaders:

```
glVertex3f          380      glDrawElements       17
glEnableClientState  23      glDrawArrays         12
glDrawElements       17      glUseProgram          9
glMatrixMode          2      glGenBuffers          6
glBegin/glEnd       5 / 5    glGenVertexArrays     5
```

Shaders use `gl_FragColor` and carry no `#version` directive → GLSL 1.10/1.20 → **OpenGL 2.1
compatibility profile**. 21 files contain immediate-mode drawing, concentrated in HUD, GUI, and
particle/effect entities.

### 2.8 Threading

Minimal and centralised: `OOAsyncWorkManager` + `OOAsyncQueue` (texture loading), 6 `NSOperationQueue`
references, 3 `detachNewThreadSelector`, zero raw `pthread_*`, zero `@synchronized`. Maps cleanly to
`std::jthread` + a task queue. **Low risk.**

### 2.9 Test coverage

- `tests/launch_snapshot.py` — launches the game, drives it over the **debug-console TCP protocol**
  (plist packets on port 8563), captures a screenshot, asserts it exceeds 100 KB.
- `upstream/oolite-tests/test-oxps/` — 6 manual test OXPs (JS interface, materials, shaders, PNG,
  AI overflow, retro missions).
- `upstream/oolite-mac-components/OCUnitTests/` — a dormant Xcode unit-test target, last touched 2020.

That is the entire safety net for 225k LOC. **This is the biggest project risk and Phase 0's whole job.**

The silver lining: the debug-console protocol is a scriptable remote-control channel into a running
game. It is a ready-made foundation for differential testing between the Objective-C and C++ builds.

### 2.10 Upstream velocity

7,975 commits total; ~340 in the last 12 months, spiking Apr–May 2026 (SDL3 + Meson + Flatpak).
Active contributors: AnotherCommander, Kevin Anthoney, Mike, phkb, mcarans, oocube.

**A long-lived rewrite fork will diverge badly.** §10.3 addresses this directly.

---

## 3. Target architecture

### 3.1 Language and toolchain

- **C++23**, `-std=c++23`, exceptions **on** (68 `@try` sites translate directly; the JS bridge
  and plist parser both want them), RTTI **on** initially (333 `isKindOfClass:` sites → `dynamic_cast`),
  revisit both after conversion.
- **Clang ≥ 17 everywhere.** Clang is the only compiler that handles Objective-C++ on all three
  platforms, which the bridge phase requires. GCC support can return in Phase 5 once the last
  `.mm` file is gone.
- **No C++20 modules** for now. Cross-platform module support in Meson + Clang + MSVC is still
  uneven, and this project cannot afford build-system risk on top of everything else. Revisit in
  Phase 6.

### 3.2 C++23 library feature availability

C++23 *language* features are safe across Apple Clang 17+, Clang 17+, and MSVC 19.4x. The *library*
is where the three platforms diverge. Proposed policy:

| Feature | Apple Clang / libc++ | Clang / libstdc++ | MSVC STL | Policy |
|---|---|---|---|---|
| `std::expected` | ✅ (libc++ 17+) | ✅ (13+) | ✅ | **Use freely** — the error-handling backbone |
| `std::span`, `std::string_view` | ✅ | ✅ | ✅ | **Use freely** |
| `std::format` | ✅ (16+) | ✅ (13+) | ✅ | **Use freely** |
| `std::print` / `std::println` | ⚠️ (18+) | ✅ (14+) | ✅ | Wrap behind `oo::log` |
| Deducing `this` | ✅ (17+) | ✅ (18+) | ✅ | Use freely |
| `if consteval`, multidim `[]`, `[[assume]]` | ✅ | ✅ | ✅ | Use freely |
| Ranges + C++23 adaptors | ✅ | ✅ | ⚠️ partial | Prefer C++20 ranges core |
| `std::mdspan` | ⚠️ | ✅ (14+) | ✅ | Avoid until verified |
| `std::flat_map` / `flat_set` | ❌ | ✅ (15+) | ✅ | **Avoid.** Provide `oo::FlatMap` |
| `std::generator` | ❌ | ✅ (14+) | ❌ | **Avoid.** Not worth a polyfill |
| `import std;` | ❌ | ⚠️ | ⚠️ | **Forbidden this cycle** |

Enforce with a CI job that compiles a canary TU on all three toolchains at their pinned minimums.

### 3.3 Proposed source layout

```
src/
  oofnd/          Foundation replacement — String, PList, Ref/WeakRef, FileSystem,
                  Defaults, Logging, Data, Bundle/ResourcePaths
  oomath/         Vector, HPVector, Matrix, Quaternion, Triangle, BoundingBox, Octree
                  (already near-pure C — convert first, use as the pattern-setter)
  oocore/         Universe, ResourceManager, ShipRegistry, Commodities, Equipment,
                  SystemDescriptions, RoleSet, Cache
  ooentity/       Entity hierarchy
  oorender/       Mesh, Drawable, Materials, Shaders, Textures, Sky, Planet, HUD, GUI
  ooaudio/        OpenAL sound + music
  ooscript/       JS engine abstraction + the ~45 JS class bindings + legacy AI/plist scripting
  ooplatform/     SDL3 window/input/joystick, per-OS paths, macOS bundle handling
  oxp/            OXZ/manifest handling, expansion manager, OXP verifier
  main.cpp
```

Dependency direction is strictly downward: `oofnd` and `oomath` depend on nothing in-tree; nothing
depends on `oorender` except `main`. Enforce with a CI include-graph check — this is what keeps the
Universe god-object from re-forming.

### 3.4 `oofnd` — the Foundation replacement

The core design decision. Sketch:

```cpp
namespace oo {

// --- Memory: mirrors ObjC refcounting 1:1 so translation stays reviewable -----
class RefCounted {                       // ~NSObject's refcount contract
public:
    void retain() const noexcept;
    void release() const noexcept;       // deletes at 0
protected:
    virtual ~RefCounted();
private:
    mutable std::atomic<uint32_t> rc_{1};
    mutable WeakControl* weak_ = nullptr;   // replaces OOWeakReference proxy
};

template <class T> class Ref;             // ~ObjC strong reference
template <class T> class WeakRef;         // ~OOWeakReference / weakRetain

// --- Strings: UTF-8 everywhere ------------------------------------------------
// NSString is used as an immutable value type in ~all 6,286 sites.
using String = std::string;               // UTF-8; helpers as free functions
// ObjC's NSString categories (OOExtensions, OOStringParsing, OOStringExpander)
// become free functions in namespace oo::str.

// --- Property lists: the data model ------------------------------------------
class PList {                             // variant: null|bool|int|double|string|data|date|array|dict
public:
    template <class T> T get(std::string_view key, T fallback = {}) const;   // replaces oo_*ForKey:
    template <class T> T at(size_t index, T fallback = {}) const;            // replaces oo_*AtIndex:
    // …
};

std::expected<PList, ParseError> parsePList(std::span<const std::byte>, std::string_view whereFrom);
std::string writeOldStylePList(const PList&);   // OpenStep format — REQUIRED, see §9.1
std::string writeXMLPList(const PList&);

} // namespace oo
```

**Non-negotiable requirement:** `oofnd` must parse *and write* **old-style OpenStep property lists**.
Not optional — the live expansion catalogue at `https://addons.oolite.space/api/1.0/overview` is
served in that format, and so are most OXP config files. GNUstep provides this today; Apple's
Foundation dropped OpenStep *writing* long ago, which is one more reason not to build the migration
on Apple's Foundation.

### 3.5 Memory model: use `oo::Ref`, not `std::shared_ptr`

Deliberate recommendation, worth stating explicitly because it will look wrong to a C++ reviewer:

- **Translation fidelity.** `[x retain]` → `x->retain()` is a reviewable one-line change. Rewriting
  ownership into `shared_ptr`/`unique_ptr` at the same time as changing language turns every diff
  into a design argument.
- **Object identity.** ObjC pointers *are* the identity. Intrusive refcounting preserves that;
  `shared_ptr` introduces a separate control block and makes `shared_from_this` mandatory in the
  many places that pass `self` around.
- **Cycles are already handled.** `OOWeakReference` marks every weak edge in the entity graph
  explicitly. `WeakRef<T>` maps onto it directly; `weak_ptr` would too, but with more churn.
- **Performance.** `ShipEntity` has 186 ivars and there can be thousands of entities. A control
  block per object is real cost.

Then, *after* the class is in C++ and green: demote leaf types (`OOColor`, `Vector`, `Quaternion`,
`OORoleSet`, `OOCommodityMarket`) to value types, and demote exclusively-owned members to
`unique_ptr`. Two passes, each individually reviewable.

---

## 4. Risk register and decisions

### R1 — SpiderMonkey 1.8.5 (blocker)

**Facts.** `Doc/SpidermonkeyChanges.txt` pins a *patched* SpiderMonkey 1.8.5 from the Firefox 4.0
source drop (March 2011), built with `JS_THREADSAFE` and `MOZ_TRACE_JSCALLS`. The source is
vendored at `upstream/spidermonkey-ff4`. `js/src/configure.in` recognises x86, x86-64, ppc, ppc64,
Alpha, s390, hppa, sparc, mips, and `arm*` (ARMv7) — **`aarch64` is not recognised at all**. The
build is autoconf 2.13. The API is the removed-long-ago `jsval` / `JSRuntime` / `JS_BeginRequest`
generation.

**Coupling.** 3,828 `JS_*` call sites across 102 files, but heavily concentrated:
`JS_NewNumberValue` (145), `JS_ValueToNumber` (101), `JS_ValueToBoolean` (63), `JS_PropertyStub` (60),
`JS_ResolveStub`/`JS_ConvertStub`/`JS_EnumerateStub` (32/32/29), `JS_InitClass` (29). Native objects
are attached via `JS_SetPrivate`/`JS_GetPrivate` — a plain pointer, which ports to C++ unchanged.

**Options.**

| Option | Effort | Verdict |
|---|---|---|
| **A. Port SM 1.8.5 to aarch64, interpreter-only** | Medium — add `aarch64` to configure, `--disable-methodjit --disable-tracejit`, fix 15-year-old C++ against Clang 17+, resurrect autoconf 2.13 | Fastest route to *a* macOS build. Keeps an unmaintained, unpatched 2011 engine forever. **Fallback only.** |
| **B. Upgrade to modern SpiderMonkey (mozjs-128 ESR)** | Very high — total API rewrite of 102 files, plus a Rust toolchain and Mozilla's build system as hard deps on all 3 platforms | Poor effort/benefit. **Reject.** |
| **C. Swap to QuickJS-ng** ⭐ | High but bounded — one abstraction layer, then one backend | **Recommended.** Pure C, MIT, ES2023, builds trivially on arm64/x64/Windows/Linux, small embedding API, no Rust, no autoconf. |
| **D. Different engine per platform** | — | **Reject.** Fragments OXP compatibility, which is the one thing we cannot fragment. |

**Decision: C, with A held in reserve.** Concretely:

1. Define `ooscript/JSEngine.hpp` — a thin C++23 façade (`Value`, `Context`, `ClassDef`,
   `Ref`-rooted GC handles) sized to what Oolite actually uses, not to what an engine offers.
2. Port the 3,828 call sites to the façade *with SpiderMonkey still behind it*. This step must
   produce **byte-identical behaviour** — that's what makes it verifiable.
3. Add a QuickJS-ng backend. Run both under the Phase-0 harness and the OXP corpus, differentially.
4. Delete the SpiderMonkey backend once the corpus is green.

Note steps 2 and 3 are pure C — they do not touch Objective-C and can run **fully in parallel**
with the Foundation work by a different person.

**Semantic risk.** SM 1.8.5 is ES5-era with Mozilla extensions (E4X, `for each…in`,
`catch (e if cond)`, `let` blocks, `String.prototype.quote`). QuickJS-ng is ES2023 and supports
none of the Mozilla-only ones. Measured on the 31 shipped scripts in `Resources/Scripts/`:
**zero occurrences** of `for each`, conditional catch, `.quote()`, `__proto__`, `arguments.callee`,
or E4X. The `.eslintrc.json` targets `ecmaVersion: 2015`. In-tree is clean; the 1,591 third-party
expansions are the unknown, which is what §9.3's corpus scan is for.

### R2 — GNUstep Foundation

Handled by `oofnd` (§3.4) across Phases 2–4. No separate decision needed beyond: **do not port to
Apple's Foundation as an interim step.** It creates a second Foundation dialect to reconcile
(different plist behaviour, different `NSUserDefaults` semantics, no OpenStep plist writing) for
code that is going to be deleted anyway.

### R3 — Memory model

Decided in §3.5: intrusive `oo::Ref<T>` / `oo::WeakRef<T>` during migration; value-semantics pass
afterwards.

`NSAutoreleasePool` (92 sites) needs a bridge: an `oo::AutoreleaseScope` that drains a thread-local
deferred-release list, so `-[X autorelease]` → `oo::autorelease(x)` keeps working while both worlds
coexist. It gets deleted in Phase 5 once no returned object relies on deferred release.

### R4 — Renderer / OpenGL on Apple Silicon

**Facts.** GL 2.1 compatibility profile, GLSL 1.10/1.20, immediate mode in 21 files.

macOS still ships a legacy OpenGL 2.1 compatibility context, implemented over Metal, and it works on
Apple Silicon. VAOs are available via `APPLE_vertex_array_object`. **So the existing renderer can run
on Apple Silicon essentially unmodified.** It is deprecated and could be removed in a future macOS,
but it is what makes an early Apple Silicon milestone realistic.

**Decision: ship on legacy GL 2.1 through Phases 1–5. Modernise in Phase 6, separately.**

Phase 6 options, in preference order:
1. **GL 3.3 Core** — one baseline that works on macOS (which supports up to 4.1 Core), Windows, and
   Linux. Requires removing immediate mode (380 `glVertex3f` sites, but concentrated in HUD/GUI/effects
   — a handful of batched-quad helpers would retire most of them) and moving shaders to `#version 330`.
2. **SDL3 GPU API** — Metal/Vulkan/D3D12 behind one abstraction. Strategically the best answer, and
   SDL3 is already a dependency. Much larger job; it means rewriting the material system.
3. **ANGLE (GL ES → Metal/D3D)** — upstream has already experimented with ANGLE on Windows
   (commit `a5dcefa5d`). Worth tracking, but GL ES has no immediate mode either, so it carries
   option 1's cost without option 1's portability.

Do not let this become Phase 1's problem.

### R5 — Testing and upstream divergence

See §5 (harness) and §10.3 (divergence). This is the risk most likely to actually sink the project,
and the least technically interesting — which is exactly why it needs to be scheduled first.

---

## 5. Phase 0 — Baseline and safety net

**No production code changes.** Everything downstream depends on this phase being real.

### 5.1 Reproduce upstream builds in our CI

Linux x86-64 and Windows x86-64, matching `upstream/oolite/.github/workflows/build-all.yaml`.
Pin the GNUstep commits and the `mozillajs-linux` 0.0.1 artefact. Cache aggressively — GNUstep
from source is slow, and every later phase pays this cost on every run.

### 5.2 Characterisation harness ("the golden harness")

Build on `tests/launch_snapshot.py` and `upstream/oolite-debug-console`, which together already
give a scriptable TCP channel into a running game (plist packets, port 8563, `Perform Command`
executes arbitrary JS in the game context).

Required properties:

- **Determinism.** Fixed RNG seed, fixed system, fixed tick count, fixed clock. `legacy_random.c`
  is already a deterministic LCG; audit every other entropy source (`OOAsyncWorkManager` completion
  order, texture-load ordering, `NSDictionary` iteration order — **that last one will bite**, see
  §5.3) and make it reproducible.
- **State dumps.** After N ticks, serialise the world (entity list, positions, velocities,
  orientations, AI states, market prices, player state) to a canonical sorted JSON.
- **Frame hashes.** Perceptual hash of rendered frames at fixed camera positions, with tolerance —
  exact pixel equality across GL drivers is not achievable and chasing it wastes weeks.
- **Scenarios.** Start with ~20: launch/dock, witchspace jump, combat encounter, trade cycle,
  mission trigger, save/load round-trip, each of the 6 `test-oxps`.

**Acceptance for every later phase: the goldens still reproduce.**

### 5.3 Iteration-order determinism (do this before anything else)

GNUstep's `NSDictionary`/`NSSet` enumeration order is unspecified and will differ from any C++
container we choose. If any gameplay path depends on it — populator scripts, role selection,
ship registry, equipment ordering are all prime suspects — behaviour will silently diverge and
goldens will be worthless.

**Action:** instrument `NSDictionary`/`NSSet` enumeration in a debug build to shuffle order, run the
scenarios, and find every place the outcome changes. Fix those to sort explicitly *in the Objective-C
code, upstreamable as bug fixes*, before migrating anything. This is cheap now and extremely
expensive to diagnose in Phase 4.

### 5.4 JS API conformance snapshot

Via the debug console, enumerate all 61 JS globals and, for each of the ~45 native classes, dump
every property and method name, arity, and type. Commit as `oxp-contract/js-api-1.92.json`. Any
later build must reproduce it exactly. This is the machine-checkable form of "expansions still work".

### 5.5 OXP compatibility corpus

From `upstream/oolite-expansion-catalog/expansionUrls.txt` and the live API (1,591 entries), assemble
a tiered corpus:

- **Tier 1 (~30):** the most-installed expansions + all 6 `test-oxps`. Must pass, every commit.
- **Tier 2 (~150):** broad category coverage (ships, missions, HUDs, equipment, OXPs with heavy JS).
  Nightly.
- **Tier 3 (all 1,591):** load-only smoke test — does it parse, register, and reach the main menu
  without errors in `Latest.log`? Weekly.

Also: statically scan all Tier-3 scripts for the Mozilla-only JS constructs in §9.3. That scan is
the single most valuable input to the expansion-author migration guide, and it can run today.

### 5.6 Exit gate

- [ ] Linux + Windows CI green, reproducible
- [ ] ≥20 scenarios producing stable goldens across 10 consecutive runs
- [ ] Iteration-order non-determinism found and fixed
- [ ] JS API snapshot committed
- [ ] Tier 1/2/3 corpus automated
- [ ] Mozilla-only-JS scan report published

---

## 6. Phase 1 — De-Mozilla (JS engine replacement)

Unblocks Apple Silicon. Pure C work; **runs in parallel with Phase 2.**

1. **Define the façade** — `ooscript/JSEngine.hpp`. Design it against the call-site histogram in
   §4/R1, not against QuickJS's API. Roughly: `Value`, `Context`, `Object`, `ClassDef`,
   `PropertySpec`, `FunctionSpec`, rooted handles, exception plumbing.
2. **Retarget all 3,828 call sites onto the façade, SpiderMonkey still underneath.** Mechanical.
   Goldens must not move. Land it in slices — the 5 stub/init patterns and the numeric conversions
   cover ~40% of sites and can be scripted with `clang-refactor` plus review.
3. **Implement the QuickJS-ng backend.** Native objects still attach via a private pointer;
   `JSClass` resolve/enumerate hooks map onto QuickJS's `JSClassExoticMethods`.
4. **Differential-test both backends** against the goldens and Tier 1–3 corpus. Record every
   divergence; each is either a bug or a documented expansion-author change (§9.3).
5. **Delete the SpiderMonkey backend**, delete the `mozillajs-linux` dependency and `nspr`.

**Gate:** goldens reproduce on QuickJS-ng; Tier 1+2 corpus green; Tier 3 regressions triaged and
documented; the tree builds for `aarch64-apple-darwin` as far as the GNUstep dependency permits.

---

## 7. Phase 2 — `oofnd` (Foundation replacement)

Runs in parallel with Phase 1. **This is where GNUstep dies.**

1. **Switch the build to Objective-C++.** Rename `.m` → `.mm`, `-x objective-c++`, `-std=c++23`.
   Expect a few hundred mechanical fixes (`nil` vs `nullptr`, `class`/`new`/`delete`/`template` used
   as identifiers or selector parts, `id` in C++ contexts, `BOOL` conflicts, stricter enum/`void*`
   conversions). Do this as one atomic, reviewable commit — it must change no behaviour.
2. **Build `oofnd` bottom-up**, each piece landed with its own unit tests:
   - `Ref`/`WeakRef`/`RefCounted`/`AutoreleaseScope` (replaces `OOWeakReference`, `OOWeakSet`)
   - `PList` + old-style **and** XML plist parser/writer (replaces `OOPListParsing`,
     `OldSchoolPropertyListWriting`, `NSPropertyListSerialization`)
   - Typed accessors (retires `OOCollectionExtractors` — ~1,800 sites)
   - String utilities (retires the `NSString` categories, `OOStringParsing`, `OOStringExpander`,
     `OOEncodingConverter`)
   - `FileSystem`, `ResourcePaths`, `Data` (retires `NSFileManager`/`NSBundle`/`NSData` usage)
   - `Defaults` (retires `NSUserDefaults` + the two `Override` categories)
   - `Logging` (retires `OOLogging` — already mostly C-shaped)
3. **Migrate usage sites** from Foundation to `oofnd`, still inside Objective-C classes. Order:
   `oomath` → `Core` leaf utilities → `Materials` → `oxp` → `Scripting` → `Entities` → `Universe`.
4. **Delete `libgnustep-base`** from the dependency list. `libobjc2` (runtime only) stays.

**Gate:** goldens reproduce; `libgnustep-base` gone from Linux and Windows builds; only the
Objective-C *runtime* remains.

---

## 8. Phases 3–6

### Phase 3 — Apple Silicon milestone 🎯

With SpiderMonkey and GNUstep-base both gone, the only Objective-C dependency left is the runtime —
which Apple provides natively on arm64.

1. Add a `macos` branch to `src/meson/`; SDL3 for window/input (Cocoa backend), legacy GL 2.1 context.
2. `.app` bundle packaging, `Info.plist`, code-signing/notarisation; Application Support paths for
   saves, OXZ downloads, and the cache.
3. Port the residual `SDL/` platform code; consult `upstream/oolite-mac-components` for the
   historical Cocoa dock-tile, document-type, and importer bits.
4. Add macOS arm64 to CI, running the same goldens.

**Gate: Oolite plays on Apple Silicon, with expansions.** This is the first externally visible win
and the right point to talk to upstream (§10.3).

### Phase 4 — Objective-C → C++23 conversion

The long grind: ~500 files, leaves inward, one module per PR, goldens green at every step.

Suggested order (dependency-driven, and it front-loads the pattern-setting work):

1. `oomath` — `OOVector`, `OOHPVector`, `OOMatrix`, `OOQuaternion`, `OOTriangle`, `Octree`.
   Near-pure C already; converts in days and establishes house style.
2. `Core/OXPVerifier` — 27 files, standalone, has its own test data. The ideal pilot for a *real*
   class hierarchy.
3. Leaf utilities — `OOColor`, `OOCache`, `OORoleSet`, `OOProbabilitySet`, `OOPriorityQueue`,
   `OOCommodities`, `OOEquipmentType`, `OOCharacter`.
4. `Materials` / `oorender` (47 files) — self-contained behind `OODrawable`/`OOMaterial`.
5. `ooaudio` — the `OOAL*` family; already a thin OpenAL wrapper.
6. `ooscript` — the ~45 JS binding classes. Voluminous but repetitive; the façade from Phase 1
   already isolates the engine.
7. `ooentity` — `Entity` → `OOEntityWithDrawable` → `ShipEntity` → `StationEntity`/`PlayerEntity`.
   **`ShipEntity` (14,945 lines, 186 ivars, 565 methods) and `PlayerEntity` (13,718 lines) are the
   hardest artefacts in the project.** Budget real time. The existing category split
   (`PlayerEntityControls`, `PlayerEntityContracts`, `PlayerEntityLoadSave`, …) translates directly
   to member functions defined across multiple `.cpp` files, so the file decomposition survives.
8. `Universe` (11,297 lines, 122 ivars, 302 methods) — last. Everything points at it.

Per-file recipe:

| Objective-C | C++23 |
|---|---|
| `@interface X : Y` + ivar block | `class X : public Y { … }` |
| `@interface X (Private)` in the `.m` | private member functions |
| `@interface X (Feature)` in its own file | member functions defined in `XFeature.cpp` |
| `@interface NSString (OOFoo)` | free functions in `namespace oo::str` |
| `- (T) foo` / `+ (T) foo` | member / `static` member function |
| `[obj msg:a with:b]` | `obj->msg(a, b)` |
| `[[X alloc] init…]` | `oo::make<X>(…)` returning `Ref<X>` |
| `[x retain]` / `[x release]` | `Ref<T>` assignment (usually just deleted) |
| `[x autorelease]` | return `Ref<T>` by value |
| `@protocol P` | abstract base class, or a concept where no dynamic dispatch is needed |
| `id<P>` | `P*` / `Ref<P>` |
| `[x isKindOfClass:[Y class]]` | `dynamic_cast<Y*>(x)` — **but review each: many want a virtual or a type tag** |
| `@try/@catch/@throw` | `try/catch/throw` |
| `NSAutoreleasePool` | scope exit / `Ref` |
| `@selector(foo)` + `performSelector:` | `&X::foo` or `std::function` |
| `NSSelectorFromString(s)` | explicit `unordered_map<string, handler>` — the 10 sites need individual design |
| `nil` / `NO` / `YES` | `nullptr` / `false` / `true` |
| `NSLog` / `OOLog` | `oo::log` (`std::format`-based) |

### Phase 5 — Remove the Objective-C runtime

Delete `AutoreleaseScope`, drop `libobjc2` and `-fobjc-*` flags, rename `.mm` → `.cpp`, restore GCC
to CI. Should be nearly mechanical if Phase 4 was disciplined.

### Phase 6 — Modernise

Only now, with a pure C++23 codebase and a working golden harness, is it safe to make design
changes:

- Renderer → GL 3.3 Core (or SDL3 GPU). See R4.
- Value semantics for leaf types; `unique_ptr` for exclusive ownership; shrink `Ref` usage to the
  entity graph where it belongs.
- Break up `Universe`: separate scene graph, simulation, and presentation.
- `std::expected` error paths replacing out-parameter + `BOOL` returns.
- `std::jthread` + a proper job system for `OOAsyncWorkManager`.
- Revisit C++20 modules.

---

## 9. Expansion (OXP/OXZ) compatibility

### 9.1 The six contracts

Expansions are data, not code. Compatibility is *exactly* the preservation of these six contracts —
and each one is testable:

| # | Contract | Where it lives today | Risk |
|---|---|---|---|
| **C1** | **Property-list dialect** — old-style OpenStep **and** XML, read **and write** | `OOPListParsing.m`, `OldSchoolPropertyListWriting.m`, GNUstep `NSPropertyListSerialization` | **High.** Must be reimplemented in `oofnd`, quirk-for-quirk, incl. the DTD rewriting in `ChangeDTDIfApplicable`. Fuzz against GNUstep. |
| **C2** | **JavaScript API** — 61 globals, ~45 native classes, exact names/arities/semantics | `Core/Scripting/OOJS*.m` | **High.** Locked by the §5.4 conformance snapshot. |
| **C3** | **JS language level** — ES5 + SpiderMonkey extensions | SpiderMonkey 1.8.5 | **Medium.** The only contract we knowingly change. See §9.3. |
| **C4** | **Legacy scripting** — plist scripts and AI state machines | `PlayerEntityLegacyScriptEngine.m` (2,993 lines), `ShipEntityAI.m` (2,943), `AI.m`, `OOLegacyScriptWhitelist.m` | **Medium.** Old, quirky, still used by long-tail OXPs. Do not "clean up" during translation. |
| **C5** | **Resource resolution** — search paths, `manifest.plist`/`requires.plist`, version ranges, conflict/dependency resolution, `.oxz` zip handling, merge/override semantics | `ResourceManager.m` (2,274 lines), `OOOXZManager.m` (2,420) | **Medium.** Subtle ordering rules that OXPs depend on. Pin with tests before touching. |
| **C6** | **String expansion & localisation** — `descriptions.plist`, `[key]` substitution, `%H`/`%I` tokens, random-phrase grammar | `OOStringExpander.m` (1,294 lines), `OOSystemDescriptionManager.m` | **Medium.** Highly quirk-laden; visible to every mission text. |

Add a seventh, informally: file formats (`.dat` meshes, PNG/OGG, GLSL 1.x shaders). These are read
by code that changes but by parsers whose behaviour must not.

### 9.2 The headline

> **Under this plan, expansions require no migration.** C1, C2, C4, C5 and C6 are held constant by
> design and enforced by the corpus. The only behaviour that changes is C3 — the JavaScript
> *language* level — and only for scripts that used Mozilla-only syntax.

### 9.3 What expansion authors *will* need to change (the guide)

Deliverable: `docs/EXPANSION_MIGRATION.md`, published before the first C++-based release. Contents:

**Removed — SpiderMonkey-only syntax (hard errors under QuickJS-ng):**

| Construct | Replacement |
|---|---|
| `for each (var x in obj)` | `for (var k in obj) { var x = obj[k]; }` |
| `catch (e if e instanceof TypeError)` | `catch (e) { if (…) … else throw e; }` |
| E4X (`var x = <foo/>`) | Not supported. Rewrite. |
| `String.prototype.quote()` | `JSON.stringify(s)` |
| `Array.prototype.toSource()`, `uneval()` | `JSON.stringify` |
| Old-style `let` block/expression forms | Standard `let` (block-scoped) |
| Legacy getter/setter syntax (`obj.__defineGetter__`) | `Object.defineProperty` |
| Expression closures (`function(x) x*2`) | `function(x) { return x*2; }` |
| Conditional `const` re-declaration | Standard `const` semantics — **now throws** |

**Newly strict (silent bugs become errors):**

- Duplicate parameter names, octal literals (`0755` → `0o755`), `with` in strict contexts,
  assigning to undeclared variables.
- `arguments.callee` in strict mode.

**Newly available (opt-in, and worth advertising):**

- ES2015–ES2023: `let`/`const`, arrow functions, template literals, classes, destructuring,
  `Map`/`Set`, `Promise`, spread/rest, `async`/`await`, optional chaining, `Array.prototype.at`.

**Tooling shipped with the guide:**

1. `tools/oxp-js-lint` — an ESLint config + runner that flags every construct above across an OXP.
   Run it over all 1,591 catalogue entries during Phase 0 and publish the results, so the community
   knows the blast radius before the release, not after.
2. A compatibility shim OXP that polyfills what can be polyfilled (`toSource`, `quote`), loaded
   first, for the long tail of abandoned expansions.
3. `oolite --verify-oxp` — the existing `OXPVerifier` extended with the JS lint.

**Deprecation policy proposal:** ship one Objective-C release with a *warning-only* lint pass, so
authors get a release cycle of notice before the C++ release changes engines.

---

## 10. Repository, workflow, and upstream

### 10.1 Layout (already set up in this directory)

```
OoliteMigration/
├── MIGRATION_PLAN.md                  ← this document
├── README.md
├── .gitmodules
└── upstream/
    ├── oolite/                        submodule — the main repo (the migration target)
    ├── spidermonkey-ff4/              submodule — the patched SM 1.8.5 source (R1 reference)
    ├── oolite-tests/                  submodule — test OXPs and legacy test projects
    ├── oolite-debug-console/          submodule — TCP debug console (drives the golden harness)
    ├── oolite-mac-components/         submodule — historical macOS Cocoa components (Phase 3 reference)
    └── oolite-expansion-catalog/      submodule — the expansion URL list (corpus source)
```

### 10.2 Remotes

Per the project's convention, `origin` is the fork, `upstream` is the source of truth:

| Repo | `origin` | `upstream` |
|---|---|---|
| `OoliteMigration` (this) | `https://github.com/jonmseaman/OoliteMigration.git` | — |
| `upstream/oolite` | `https://github.com/jonmseaman/oolite.git` | `https://github.com/OoliteProject/oolite.git` |
| all other submodules | `https://github.com/OoliteProject/<repo>.git` (read-only reference) | same |

**Action required before first push:** create `jonmseaman/OoliteMigration` (new, empty) and fork
`OoliteProject/oolite` to `jonmseaman/oolite` on GitHub. Until the fork exists, `.gitmodules`
points at a URL that a fresh `git clone --recursive` cannot reach — the local working copy is
unaffected.

### 10.3 Living with an active upstream

Upstream is not dormant: ~340 commits in the last 12 months, 6+ active contributors. A rewrite fork
that ignores this will be unmergeable within a year.

**Recommended posture:**

1. **Rebase, don't merge.** Keep migration work as a rebasable series on `upstream/master`. Rebase
   at least monthly. The golden harness is what makes each rebase verifiable rather than a leap of
   faith.
2. **Upstream everything that isn't the rewrite.** Determinism fixes (§5.3), test-harness
   improvements, the JS lint tool, plist quirk fixes, build fixes. These are wanted upstream, reduce
   divergence, and build the credibility that Phase 3 will need.
3. **Talk to upstream at Phase 3, not before.** A working Apple Silicon build with expansions
   running is a concrete artefact worth discussing. "We plan to rewrite Oolite in C++" is not.
   Note that upstream explicitly dropped macOS in 1.92 — restoring it is a genuine contribution
   regardless of what happens to the C++ work.
4. **Phase-1 and Phase-2 work is upstreamable on its own merits.** Replacing a 2011 JS engine and
   removing the GNUstep build dependency are things upstream may well want independently of C++23.
   This is the pragmatic hedge: even if the full migration stalls, Phases 0–3 leave Oolite better off.
5. **Freeze policy.** Once Phase 4 starts on a module, stop taking upstream changes to that module;
   port them by hand instead, tracked in `docs/UPSTREAM_DELTA.md`.

### 10.4 Definition of done, per PR

1. Goldens reproduce (or the diff is explained and re-blessed with justification).
2. Tier 1 OXP corpus green.
3. Builds clean on all three platforms at `-Wall -Wextra` with no new warnings.
4. ASan + UBSan clean on Linux (essential — hand-translated refcounting *will* produce use-after-free).
5. No new `libgnustep-base` or `JS_*` symbols reintroduced (CI-enforced deny-list).

---

## 11. Effort and sequencing

Deliberately expressed in engineer-months rather than dates, and honestly uncertain — the ±
column is the point, not the midpoint.

| Phase | Scope | Est. (eng-months) | Parallel? |
|---|---|---:|---|
| **0** | CI, golden harness, determinism fixes, JS API snapshot, OXP corpus | 2–4 | — |
| **1** | JS façade + QuickJS-ng backend, differential validation | 4–7 | ∥ with 2 |
| **2** | ObjC++ switch, `oofnd`, retire GNUstep-base | 6–10 | ∥ with 1 |
| **3** | Apple Silicon build, bundle, signing, CI | 1–2 | after 1+2 |
| **4** | ObjC → C++23, ~500 files | 12–24 | partly ∥ |
| **5** | Remove ObjC runtime | 1–2 | after 4 |
| **6** | Renderer modernisation + C++23 idiom pass | 4–10 | after 5 |
| | **Total** | **30–59** | |

With phases 1 and 2 in parallel, **the Apple Silicon milestone (Phase 3) lands after roughly
9–16 engineer-months** — that's the first externally meaningful result, and it arrives with the
game still written in Objective-C.

**Solo, part-time, this is a multi-year project.** Phases 0–3 are the part with a clear payoff
(macOS support, a maintained JS engine, no GNUstep) and are worth doing whether or not Phase 4
ever completes. Sequencing the plan this way is deliberate: it front-loads the value and makes
every stopping point a reasonable place to stop.

---

## 12. Open decisions

Things this plan does not settle, roughly in the order they need answering:

1. **QuickJS-ng vs. porting SM 1.8.5 to aarch64.** Recommendation is QuickJS-ng (§4/R1), but a
   two-week spike on option A would de-risk the fallback and give an early macOS build to test with.
   **Worth doing first.**
2. **Fork or contribute?** Whether this is a hard fork or an upstream-collaborative effort changes
   the review burden, the timeline, and the freeze policy in §10.3. Decide before Phase 1 lands.
3. **How much C++23 in the translated code?** Recommendation: translate to *conservative* C++ first
   (§8, Phase 4) and modernise in Phase 6. Mixing translation and redesign is the classic way these
   projects die.
4. **`std::string` vs. a custom `oo::String`.** `std::string` is recommended for interop and
   familiarity, but `NSString` is immutable and refcounted; 6,286 sites of copying may be a
   measurable regression. Benchmark in Phase 2 before committing.
5. **Renderer target for Phase 6.** GL 3.3 Core vs. SDL3 GPU. Defer, but don't defer past Phase 5.
6. **Legacy AI and legacy plist scripting** (C4) — port faithfully, or deprecate with a long
   sunset? Faithful porting is recommended; the alternative breaks the long tail of old OXPs, which
   is precisely the compatibility promise this plan is built around.
7. **Windows toolchain.** MinGW-clang (upstream's current path) vs. clang-cl + MSVC STL. The latter
   is better long-term for C++23 library coverage; the former diverges less from upstream today.

---

## Appendix A — Key files by difficulty

| File | Lines | Note |
|---|---:|---|
| `Core/Entities/ShipEntity.m` | 14,945 | 186 ivars, 565 methods. The hardest artefact in the project. |
| `Core/Entities/PlayerEntity.m` | 13,718 | Split across 10 category files; that split survives translation. |
| `Core/Universe.m` | 11,297 | 122 ivars, 302 methods. God object. Convert last. |
| `Core/Entities/PlayerEntityControls.m` | 5,690 | Input handling; heavy platform coupling. |
| `Core/HeadUpDisplay.m` | 4,497 | Dense immediate-mode GL. Also a Phase-6 renderer target. |
| `Core/Scripting/OOJSShip.m` | 4,399 | The largest JS binding surface; C2 contract lives here. |
| `Core/Entities/PlayerEntityLegacyScriptEngine.m` | 2,993 | C4 contract. Port faithfully; resist cleanup. |
| `Core/Entities/ShipEntityAI.m` | 2,943 | C4 contract. Same. |
| `Core/Scripting/OOJavaScriptEngine.m` | 2,543 | Phase 1 epicentre. |
| `Core/OOOXZManager.m` | 2,420 | C5 contract; the only `NSURLConnection` user. |
| `Core/ResourceManager.m` | 2,274 | C5 contract. Search-path and override semantics. |
| `Core/OOCollectionExtractors.m` | 1,564 | Retired wholesale by `oofnd::PList`. Highest leverage. |
| `Core/OOStringExpander.m` | 1,294 | C6 contract. Quirk-dense. |

## Appendix B — Commands used to derive the figures

```bash
cd upstream/oolite/src
find . -name '*.m' | xargs wc -l | tail -1              # 183,603
find . -name '*.h' | xargs wc -l | tail -1              #  41,214
FILES=$(find . -name '*.m' -o -name '*.h')
grep -hoE '@interface[ ]+[A-Za-z_]+[ ]*\(' $FILES | wc -l     # 210 categories
grep -howE 'oo_[a-zA-Z]+ForKey' $FILES | sort | uniq -c        # extractor histogram
grep -hoE 'JS_[A-Za-z]+' $FILES | wc -l                        # 3,828 JS call sites
grep -rl 'jsapi.h\|OOJavaScriptEngine.h' $FILES | wc -l        # 102 files
curl -sL https://addons.oolite.space/api/1.0/overview | grep -c identifier   # 1,591
```
