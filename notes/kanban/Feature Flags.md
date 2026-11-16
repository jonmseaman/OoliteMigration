---
status: New
---
# Feature flags: `oo::FeatureConfig` instead of compile-time macros

Use feature flags instead of compile-time macros. They work better with IDEs and clang-tidy, because both branches are compiled and checked.

## Why

The macro review (`notes/2026-11-14 Macro Review.md`) found eleven hard-coded `#define` toggles that switch real behaviour. Flipping one means editing a header. The `#if`-ed branch is never compiled, so clang-tidy and the IDE never see it. This card puts them behind one encapsulated config object. Every default stays at today's value, so upstream behaviour is unchanged.

## Done check (from `oolite-dev`)

```bash
! grep -rnwE '#define (PIRATES_PREFER_PLAYER|ALLOW_CUSTOM_VIEWS_WHILE_PAUSED|SNAPSHOTS_PNG_FORMAT|MASS_DEPENDENT_FUEL_PRICES|OO_CACHE_JS_SCRIPTS|OO_VARIABLE_TORUS_SPEED|OO_RESOLUTION_OPTION|OOTEXTURE_RELOADABLE|OO_GAME_DATA_TO_USER_FOLDER|OO_USE_VBO|USE_NEW_SHADER_SYNTHESIZER)' src
```

Run it on top of `./mk.sh build dev`, `tests/run.sh unit` (including the new `test_FeatureConfig`), `tests/run.sh component` and `tests/run.sh smoke`.

## Library: none, because `oo::Defaults` already is the flag store

- **No std flags library exists.** Abseil Flags, gflags, CLI11 and cxxopts are all command-line parsers.
- **`oo::Defaults` (`src/oofnd/Defaults.hpp`) already covers it.** It parses argv as `-key value` (upstream NSUserDefaults semantics), then reads the prefs plist, then the registration defaults. A flag read through it is overridable on the command line (`-feature-snapshots-png NO`) and persisted in prefs for free.
- **Abseil is rejected.**
  - Its flags are process-global `ABSL_FLAG`s, against `Encapsulate Global State`.
  - Its `--flag=value` syntax clashes with upstream's `-key value`.
  - `absl::ParseCommandLine` wants to own argv, which `oo::Defaults` and `main.cpp`'s `-load` already do.
  - It is a large CMake-first dependency for a meson build.
- **CLI11 and cxxopts are rejected:** they would add a second argv parser for no gain.

## Design

**`src/Core/FeatureConfig.h` / `.cpp` (new): `oo::FeatureConfig`.** A plain value type that is immutable after startup and is not a singleton.

```cpp
namespace oo {

struct FeatureConfig {
  // Runtime; defaults are today's macro values.
  bool massDependentFuelPrices = true;   // MASS_DEPENDENT_FUEL_PRICES
  bool piratesPreferPlayer = true;       // PIRATES_PREFER_PLAYER
  bool customViewsWhilePaused = true;    // ALLOW_CUSTOM_VIEWS_WHILE_PAUSED
  bool variableTorusSpeed = true;        // OO_VARIABLE_TORUS_SPEED
  bool resolutionOption = true;          // OO_RESOLUTION_OPTION
  bool cacheJsScripts = true;            // OO_CACHE_JS_SCRIPTS
  bool snapshotsPng = true;              // SNAPSHOTS_PNG_FORMAT

  static FeatureConfig fromDefaults(const Defaults&);   // missing key → default
  std::vector<std::string> describeNonDefault() const;  // for the log header
  friend bool operator==(const FeatureConfig&, const FeatureConfig&) = default;
};

}  // namespace oo
```

- **One table.** A `constexpr std::array` of `{std::string_view key, bool FeatureConfig::*member}` rows, with kebab-case keys (`"feature-mass-dependent-fuel-prices"`). `fromDefaults`, `describeNonDefault` and any debug-console dump iterate it. Adding a flag means adding one field and one row. No X-macros.
- **Ownership and injection.** `GameController` builds the config once at startup: `oo::FeatureConfig::fromDefaults(oo::Defaults::standard())`. It passes it into `Universe` at construction, and consumers read `UNIVERSE->features()`. Tests build it directly: `oo::FeatureConfig{.piratesPreferPlayer = false}`.
- **Logging.** `OOLogHeader.cpp` logs every non-default flag beside the build-config lines.

**Build-time features go in the platform layer's generated `config.hpp`** (`notes/plans/platform-layer.md`, P6), as `inline constexpr bool`s in `oo::config`. They are tested with `if constexpr` where both branches compile. A flag is build-time if it:
- changes layout or memory use (`OOTEXTURE_RELOADABLE`);
- is needed before `oo::Defaults` exists (`OO_GAME_DATA_TO_USER_FOLDER` picks where the prefs file lives; it already maps onto `PathEnvironment::gameDataToUserFolder` in `src/oofnd/ResourcePaths.hpp:99`);
- or is known to crash or may not compile (`OO_USE_VBO`, `USE_NEW_SHADER_SYNTHESIZER`).

Each gets a `meson.options` boolean.

### Each consumer

| Macro | Today | Becomes | Where it changes |
|---|---|---|---|
| `PIRATES_PREFER_PLAYER` | `true` | runtime (exemplar, first) | `ShipEntity.h:78` (delete), `ShipEntityAI.cpp:1061` |
| `ALLOW_CUSTOM_VIEWS_WHILE_PAUSED` | 1 | runtime | `PlayerEntity.h:77`, `PlayerEntityControls.cpp:1950`, `Universe.cpp:7037` |
| `SNAPSHOTS_PNG_FORMAT` | 1 | runtime | `MyOpenGLView.h:85`, `MyOpenGLView.cpp:1233,1299` |
| `MASS_DEPENDENT_FUEL_PRICES` | 1 | runtime | `Universe.h:219`, `PlayerEntity.cpp:11036,13571`, `ShipEntity.cpp:104,7708`; `kBaseCharge`/`kMassCharge` become unconditional `constexpr` |
| `OO_CACHE_JS_SCRIPTS` | 1 | runtime | `OOJSScript.cpp:25-26` and its 5 blocks; include `OOCacheManager.h` always |
| `OO_VARIABLE_TORUS_SPEED` | 1 | runtime | `PlayerEntity.h:80`, `PlayerEntity.cpp` (4 blocks), `OOEntityCalledByNameTable.h:960,2478` (always register; gate the behaviour). Coordinate with the by-name-table plan, which rewrites that file. |
| `OO_RESOLUTION_OPTION` | 1 | runtime | `PlayerEntity.h:118,213` (members always compiled), `PlayerEntityControls.cpp:153,3744`, `PlayerEntity.cpp:9179` |
| `OOTEXTURE_RELOADABLE` | 1 | meson `texture_reloadable` | `OOConcreteTexture.cpp`, `OODebugMonitor.cpp:529-561` |
| `OO_GAME_DATA_TO_USER_FOLDER` | 0 | meson `game_data_to_user_folder` | `OOFoundation.h:177`, `ResourcePaths.hpp:113`, `main.cpp:138` |
| `OO_USE_VBO` | 0 | meson `use_vbo` | `OOOpenGLExtensionPointers.h:81`, `OOOpenGLExtensionManager.*` |
| `USE_NEW_SHADER_SYNTHESIZER` | 0 | meson `new_shader_synthesizer` | `OOMaterialConvenienceCreators.cpp:28-29` and its 4 blocks |

## Steps

1. Run `/speckit-specify` for `specs/015-feature-config/`, and branch with `git town append` in `oolite-dev`.
2. Add `FeatureConfig.h/.cpp`, the table, `fromDefaults()`, the injection into `Universe` and the log-header lines. Convert `PIRATES_PREFER_PLAYER`. Add `tests/unit/core/test_FeatureConfig.cpp`, covering:
   - the defaults equal today's macros;
   - each key overrides its field;
   - a missing key gives the default;
   - junk values are coerced the way `oo::Defaults::boolForKey` coerces them.
3. Convert the other six runtime flags, one commit each, in table order.
4. Convert the four build-time flags. Do platform-layer P6 (`config.hpp`) first. If it hasn't landed, create `config.hpp` exactly as P6 specifies.
5. Add a docs section listing each flag with its key or meson option and its default.

## Decisions

- **No new dependency.** `oo::Defaults` already gives argv and prefs overrides with upstream syntax.
- **Defaults equal today's macro values**, so behaviour and tests are unchanged.
- **Naming.** New code is `oo::FeatureConfig` in `FeatureConfig.h`, with no `OO` prefix. The prefs keys are `feature-*`.
- **No singleton.** The config is owned by `GameController` and injected into `Universe`.

## Test-change ledger

None expected. Only a new test is added.

## Out of scope (follow-ups)

- `OO_USE_FBO`, `OO_MULTITEXTURE` and `OO_TEXTURE_CUBE_MAP` are GPU capabilities, not features. They belong in runtime checks in `OOOpenGLExtensionManager`.
- The scattered `DUMP_*` / `DEBUG_*` / `PROFILE*` / `SCRIBBLE` debug aids could become one meson `debug_dumps` option.
- Dead flags: `OOLITE_SDL_MAC` (set in `src/meson/darwin/meson.build`, never tested), `OO_EXCLUDE_DEBUG_SUPPORT` (never referenced), and the four `#warning`-only guards in `OOLogHeader.cpp`. Delete them in a cleanup.
