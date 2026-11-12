# External names and values: spec 009

Every enum name and number that leaves the program (research R8), with the value the program
uses today, printed by a program compiled with the game's flags from these headers and tables
(`external-values-gen.py` in this directory, 2026-11-12, `oolite-dev` after T044). A `.tbl` value column is
not used: where it disagrees with the program (`OOViewID`, `OOLongRangeChartMode`,
`OOGUIScreenID`), the program's value is the one recorded. The pin is the `static_assert` (and,
for names, the `OOEnumName` switch) that the converting task adds beside the enum.

| enum | enumerator | value | external form | where visible | pin |
|---|---|---|---|---|---|
| `OORouteType` | `OPTIMIZED_BY_NONE` | 0 | `OPTIMIZED_BY_NONE` and 0 | JS (`OOJSSystemInfo.cpp:1002`), saved game `chart_ana_mode` | `static_assert` (T059) |
| `OORouteType` | `OPTIMIZED_BY_JUMPS` | 1 | `OPTIMIZED_BY_JUMPS` and 1 | JS (`OOJSSystemInfo.cpp:1002`), saved game `chart_ana_mode` | `static_assert` (T059) |
| `OORouteType` | `OPTIMIZED_BY_TIME` | 2 | `OPTIMIZED_BY_TIME` and 2 | JS (`OOJSSystemInfo.cpp:1002`), saved game `chart_ana_mode` | `static_assert` (T059) |
| `OOCargoType` | `CARGO_NOT_CARGO` | -1 | `CARGO_NOT_CARGO` | shipdata `cargo_type` (`ShipEntity.cpp:1393`) | `static_assert` (T059) |
| `OOCargoType` | `CARGO_SLAVES` | 3 | `CARGO_SLAVES` | shipdata `cargo_type` (`ShipEntity.cpp:1393`) | `static_assert` (T059) |
| `OOCargoType` | `CARGO_ALLOY` | 9 | `CARGO_ALLOY` | shipdata `cargo_type` (`ShipEntity.cpp:1393`) | `static_assert` (T059) |
| `OOCargoType` | `CARGO_MINERALS` | 12 | `CARGO_MINERALS` | shipdata `cargo_type` (`ShipEntity.cpp:1393`) | `static_assert` (T059) |
| `OOCargoType` | `CARGO_THARGOID` | 16 | `CARGO_THARGOID` | shipdata `cargo_type` (`ShipEntity.cpp:1393`) | `static_assert` (T059) |
| `OOCargoType` | `CARGO_RANDOM` | 100 | `CARGO_RANDOM` | shipdata `cargo_type` (`ShipEntity.cpp:1393`) | `static_assert` (T059) |
| `OOCargoType` | `CARGO_SCRIPTED_ITEM` | 200 | `CARGO_SCRIPTED_ITEM` | shipdata `cargo_type` (`ShipEntity.cpp:1393`) | `static_assert` (T059) |
| `OOCargoType` | `CARGO_CHARACTER` | 300 | `CARGO_CHARACTER` | shipdata `cargo_type` (`ShipEntity.cpp:1393`) | `static_assert` (T059) |
| `OOEnergyUnitType` | `ENERGY_UNIT_NONE` | 0 | `ENERGY_UNIT_NONE` and 0 | log; legacy saved game `energy_unit` (`PlayerEntity.cpp:1760`) | `static_assert` (T059) |
| `OOEnergyUnitType` | `ENERGY_UNIT_NORMAL_DAMAGED` | 1 | `ENERGY_UNIT_NORMAL_DAMAGED` and 1 | log; legacy saved game `energy_unit` (`PlayerEntity.cpp:1760`) | `static_assert` (T059) |
| `OOEnergyUnitType` | `ENERGY_UNIT_NAVAL_DAMAGED` | 2 | `ENERGY_UNIT_NAVAL_DAMAGED` and 2 | log; legacy saved game `energy_unit` (`PlayerEntity.cpp:1760`) | `static_assert` (T059) |
| `OOEnergyUnitType` | `OLD_ENERGY_UNIT_NORMAL` | 15 | `OLD_ENERGY_UNIT_NORMAL` and 15 | log; legacy saved game `energy_unit` (`PlayerEntity.cpp:1760`) | `static_assert` (T059) |
| `OOEnergyUnitType` | `OLD_ENERGY_UNIT_NAVAL` | 20 | `OLD_ENERGY_UNIT_NAVAL` and 20 | log; legacy saved game `energy_unit` (`PlayerEntity.cpp:1760`) | `static_assert` (T059) |
| `OOEnergyUnitType` | `ENERGY_UNIT_NORMAL` | 8 | `ENERGY_UNIT_NORMAL` and 8 | log; legacy saved game `energy_unit` (`PlayerEntity.cpp:1760`) | `static_assert` (T059) |
| `OOEnergyUnitType` | `ENERGY_UNIT_NAVAL` | 16 | `ENERGY_UNIT_NAVAL` and 16 | log; legacy saved game `energy_unit` (`PlayerEntity.cpp:1760`) | `static_assert` (T059) |
| `OODockingClearanceStatus` | `DOCKING_CLEARANCE_STATUS_NONE` | 0 | `DOCKING_CLEARANCE_STATUS_NONE` | JS (`OOJSPlayer.cpp:350`) | `static_assert` (T059) |
| `OODockingClearanceStatus` | `DOCKING_CLEARANCE_STATUS_NOT_REQUIRED` | 1 | `DOCKING_CLEARANCE_STATUS_NOT_REQUIRED` | JS (`OOJSPlayer.cpp:350`) | `static_assert` (T059) |
| `OODockingClearanceStatus` | `DOCKING_CLEARANCE_STATUS_REQUESTED` | 2 | `DOCKING_CLEARANCE_STATUS_REQUESTED` | JS (`OOJSPlayer.cpp:350`) | `static_assert` (T059) |
| `OODockingClearanceStatus` | `DOCKING_CLEARANCE_STATUS_GRANTED` | 3 | `DOCKING_CLEARANCE_STATUS_GRANTED` | JS (`OOJSPlayer.cpp:350`) | `static_assert` (T059) |
| `OODockingClearanceStatus` | `DOCKING_CLEARANCE_STATUS_TIMING_OUT` | 4 | `DOCKING_CLEARANCE_STATUS_TIMING_OUT` | JS (`OOJSPlayer.cpp:350`) | `static_assert` (T059) |
| `OOGraphicsDetail` | `DETAIL_LEVEL_MINIMUM` | 0 | `DETAIL_LEVEL_MINIMUM` and 0 | debug console (`Universe.cpp:4948`), preferences `detailLevel`, description key `gameoptions-detaillevel-[n]` | `static_assert` (T059) |
| `OOGraphicsDetail` | `DETAIL_LEVEL_NORMAL` | 1 | `DETAIL_LEVEL_NORMAL` and 1 | debug console (`Universe.cpp:4948`), preferences `detailLevel`, description key `gameoptions-detaillevel-[n]` | `static_assert` (T059) |
| `OOGraphicsDetail` | `DETAIL_LEVEL_SHADERS` | 2 | `DETAIL_LEVEL_SHADERS` and 2 | debug console (`Universe.cpp:4948`), preferences `detailLevel`, description key `gameoptions-detaillevel-[n]` | `static_assert` (T059) |
| `OOGraphicsDetail` | `DETAIL_LEVEL_EXTRAS` | 3 | `DETAIL_LEVEL_EXTRAS` and 3 | debug console (`Universe.cpp:4948`), preferences `detailLevel`, description key `gameoptions-detaillevel-[n]` | `static_assert` (T059) |
| `OOGraphicsDetail` | `DETAIL_LEVEL_MAXIMUM` | 3 | `DETAIL_LEVEL_MAXIMUM` and 3 | debug console (`Universe.cpp:4948`), preferences `detailLevel`, description key `gameoptions-detaillevel-[n]` | `static_assert` (T059) |
| `OOWeaponFacing` | `WEAPON_FACING_FORWARD` | 1 | — | shipdata `weapon_facings`, JS `weaponFacings` | `static_assert` (T053) |
| `OOWeaponFacing` | `WEAPON_FACING_AFT` | 2 | — | shipdata `weapon_facings`, JS `weaponFacings` | `static_assert` (T053) |
| `OOWeaponFacing` | `WEAPON_FACING_PORT` | 4 | — | shipdata `weapon_facings`, JS `weaponFacings` | `static_assert` (T053) |
| `OOWeaponFacing` | `WEAPON_FACING_STARBOARD` | 8 | — | shipdata `weapon_facings`, JS `weaponFacings` | `static_assert` (T053) |
| `OOWeaponFacing` | `WEAPON_FACING_NONE` | 0 | — | shipdata `weapon_facings`, JS `weaponFacings` | `static_assert` (T053) |
| `OOShaderSetting` | `SHADERS_NOT_SUPPORTED` | 0 | `SHADERS_NOT_SUPPORTED` | GPU configuration (`OOOpenGLExtensionManager.cpp:335`) | `static_assert` (T059) |
| `OOShaderSetting` | `SHADERS_OFF` | 1 | `SHADERS_OFF` | GPU configuration (`OOOpenGLExtensionManager.cpp:335`) | `static_assert` (T059) |
| `OOShaderSetting` | `SHADERS_SIMPLE` | 2 | `SHADERS_SIMPLE` | GPU configuration (`OOOpenGLExtensionManager.cpp:335`) | `static_assert` (T059) |
| `OOShaderSetting` | `SHADERS_FULL` | 3 | `SHADERS_FULL` | GPU configuration (`OOOpenGLExtensionManager.cpp:335`) | `static_assert` (T059) |
| `OOHDRToneMapper` | `OOHDR_TONEMAPPER_NONE` | -1 | `OOHDR_TONEMAPPER_NONE` and -1 | preferences, JS (`OOJSOolite.cpp:207-296`) | `static_assert` (T059) |
| `OOHDRToneMapper` | `OOHDR_TONEMAPPER_ACES_APPROX` | 0 | `OOHDR_TONEMAPPER_ACES_APPROX` and 0 | preferences, JS (`OOJSOolite.cpp:207-296`) | `static_assert` (T059) |
| `OOHDRToneMapper` | `OOHDR_TONEMAPPER_DICE` | 1 | `OOHDR_TONEMAPPER_DICE` and 1 | preferences, JS (`OOJSOolite.cpp:207-296`) | `static_assert` (T059) |
| `OOHDRToneMapper` | `OOHDR_TONEMAPPER_UCHIMURA` | 2 | `OOHDR_TONEMAPPER_UCHIMURA` and 2 | preferences, JS (`OOJSOolite.cpp:207-296`) | `static_assert` (T059) |
| `OOHDRToneMapper` | `OOHDR_TONEMAPPER_REINHARD` | 3 | `OOHDR_TONEMAPPER_REINHARD` and 3 | preferences, JS (`OOJSOolite.cpp:207-296`) | `static_assert` (T059) |
| `OOSDRToneMapper` | `OOSDR_TONEMAPPER_NONE` | -1 | `OOSDR_TONEMAPPER_NONE` and -1 | preferences, JS (`OOJSOolite.cpp:207-296`) | `static_assert` (T059) |
| `OOSDRToneMapper` | `OOSDR_TONEMAPPER_ACES` | 0 | `OOSDR_TONEMAPPER_ACES` and 0 | preferences, JS (`OOJSOolite.cpp:207-296`) | `static_assert` (T059) |
| `OOSDRToneMapper` | `OOSDR_TONEMAPPER_AgX` | 1 | `OOSDR_TONEMAPPER_AgX` and 1 | preferences, JS (`OOJSOolite.cpp:207-296`) | `static_assert` (T059) |
| `OOSDRToneMapper` | `OOSDR_TONEMAPPER_HEJLDAWSON` | 2 | `OOSDR_TONEMAPPER_HEJLDAWSON` and 2 | preferences, JS (`OOJSOolite.cpp:207-296`) | `static_assert` (T059) |
| `OOSDRToneMapper` | `OOSDR_TONEMAPPER_UC2` | 3 | `OOSDR_TONEMAPPER_UC2` and 3 | preferences, JS (`OOJSOolite.cpp:207-296`) | `static_assert` (T059) |
| `OOSDRToneMapper` | `OOSDR_TONEMAPPER_UCHIMURA` | 4 | `OOSDR_TONEMAPPER_UCHIMURA` and 4 | preferences, JS (`OOJSOolite.cpp:207-296`) | `static_assert` (T059) |
| `OOSDRToneMapper` | `OOSDR_TONEMAPPER_REINHARD` | 5 | `OOSDR_TONEMAPPER_REINHARD` and 5 | preferences, JS (`OOJSOolite.cpp:207-296`) | `static_assert` (T059) |
| `WORMHOLE_SCANINFO` | `WH_SCANINFO_NONE` | 0 | `WH_SCANINFO_NONE` | JS, via `WormholeEntity.cpp:854-866` | `static_assert` (T059) |
| `WORMHOLE_SCANINFO` | `WH_SCANINFO_SCANNED` | 1 | `WH_SCANINFO_SCANNED` | JS, via `WormholeEntity.cpp:854-866` | `static_assert` (T059) |
| `WORMHOLE_SCANINFO` | `WH_SCANINFO_COLLAPSE_TIME` | 2 | `WH_SCANINFO_COLLAPSE_TIME` | JS, via `WormholeEntity.cpp:854-866` | `static_assert` (T059) |
| `WORMHOLE_SCANINFO` | `WH_SCANINFO_ARRIVAL_TIME` | 3 | `WH_SCANINFO_ARRIVAL_TIME` | JS, via `WormholeEntity.cpp:854-866` | `static_assert` (T059) |
| `WORMHOLE_SCANINFO` | `WH_SCANINFO_DESTINATION` | 4 | `WH_SCANINFO_DESTINATION` | JS, via `WormholeEntity.cpp:854-866` | `static_assert` (T059) |
| `WORMHOLE_SCANINFO` | `WH_SCANINFO_SHIP` | 5 | `WH_SCANINFO_SHIP` | JS, via `WormholeEntity.cpp:854-866` | `static_assert` (T059) |
| `OOAlertCondition` | `ALERT_CONDITION_DOCKED` | 0 | — | shaders (`EntityShaderBindings.cpp:661`), JS `alertCondition` | `static_assert` (T057) |
| `OOAlertCondition` | `ALERT_CONDITION_GREEN` | 1 | — | shaders (`EntityShaderBindings.cpp:661`), JS `alertCondition` | `static_assert` (T057) |
| `OOAlertCondition` | `ALERT_CONDITION_YELLOW` | 2 | — | shaders (`EntityShaderBindings.cpp:661`), JS `alertCondition` | `static_assert` (T057) |
| `OOAlertCondition` | `ALERT_CONDITION_RED` | 3 | — | shaders (`EntityShaderBindings.cpp:661`), JS `alertCondition` | `static_assert` (T057) |
| `OOStationAlertLevel` | `STATION_ALERT_LEVEL_GREEN` | 1 | — | JS (`OOJSStation.cpp:278`) | `static_assert` (T057) |
| `OOStationAlertLevel` | `STATION_ALERT_LEVEL_YELLOW` | 2 | — | JS (`OOJSStation.cpp:278`) | `static_assert` (T057) |
| `OOStationAlertLevel` | `STATION_ALERT_LEVEL_RED` | 3 | — | JS (`OOJSStation.cpp:278`) | `static_assert` (T057) |
| `OOSpeechSettings` | `OOSPEECHSETTINGS_OFF` | 0 | — | saved game `speech_on` | `static_assert` (T057) |
| `OOSpeechSettings` | `OOSPEECHSETTINGS_COMMS` | 1 | — | saved game `speech_on` | `static_assert` (T057) |
| `OOSpeechSettings` | `OOSPEECHSETTINGS_ALL` | 2 | — | saved game `speech_on` | `static_assert` (T057) |
| `OOFuelScoopStatus` | `SCOOP_STATUS_NOT_INSTALLED` | 0 | — | shaders (`EntityShaderBindings.cpp:624`) | `static_assert` (T057) |
| `OOFuelScoopStatus` | `SCOOP_STATUS_FULL_HOLD` | 1 | — | shaders (`EntityShaderBindings.cpp:624`) | `static_assert` (T057) |
| `OOFuelScoopStatus` | `SCOOP_STATUS_OKAY` | 2 | — | shaders (`EntityShaderBindings.cpp:624`) | `static_assert` (T057) |
| `OOFuelScoopStatus` | `SCOOP_STATUS_ACTIVE` | 3 | — | shaders (`EntityShaderBindings.cpp:624`) | `static_assert` (T057) |
| `OOMissileStatus` | `MISSILE_STATUS_SAFE` | 0 | — | shaders (`EntityShaderBindings.cpp:611`) | `static_assert` (T057) |
| `OOMissileStatus` | `MISSILE_STATUS_ARMED` | 1 | — | shaders (`EntityShaderBindings.cpp:611`) | `static_assert` (T057) |
| `OOMissileStatus` | `MISSILE_STATUS_TARGET_LOCKED` | 2 | — | shaders (`EntityShaderBindings.cpp:611`) | `static_assert` (T057) |
| `OOPlayerFleeingStatus` | `PLAYER_FLEEING_UNLIKELY` | -1 | — | JS | `static_assert` (T057) |
| `OOPlayerFleeingStatus` | `PLAYER_FLEEING_NONE` | 0 | — | JS | `static_assert` (T057) |
| `OOPlayerFleeingStatus` | `PLAYER_FLEEING_MAYBE` | 1 | — | JS | `static_assert` (T057) |
| `OOPlayerFleeingStatus` | `PLAYER_FLEEING_CARGO` | 2 | — | JS | `static_assert` (T057) |
| `OOPlayerFleeingStatus` | `PLAYER_FLEEING_LIKELY` | 3 | — | JS | `static_assert` (T057) |
| `OOMarketFilterMode` | `MARKET_FILTER_MODE_OFF` | 0 | — | description key `oolite-market-filter-[n]` | `static_assert` (T057) |
| `OOMarketFilterMode` | `MARKET_FILTER_MODE_TRADE` | 1 | — | description key `oolite-market-filter-[n]` | `static_assert` (T057) |
| `OOMarketFilterMode` | `MARKET_FILTER_MODE_HOLD` | 2 | — | description key `oolite-market-filter-[n]` | `static_assert` (T057) |
| `OOMarketFilterMode` | `MARKET_FILTER_MODE_STOCK` | 3 | — | description key `oolite-market-filter-[n]` | `static_assert` (T057) |
| `OOMarketFilterMode` | `MARKET_FILTER_MODE_LEGAL` | 4 | — | description key `oolite-market-filter-[n]` | `static_assert` (T057) |
| `OOMarketFilterMode` | `MARKET_FILTER_MODE_RESTRICTED` | 5 | — | description key `oolite-market-filter-[n]` | `static_assert` (T057) |
| `OOMarketFilterMode` | `MARKET_FILTER_MODE_MAX` | 5 | — | description key `oolite-market-filter-[n]` | `static_assert` (T057) |
| `OOMarketSorterMode` | `MARKET_SORTER_MODE_OFF` | 0 | — | description key `oolite-market-sorter-[n]` | `static_assert` (T057) |
| `OOMarketSorterMode` | `MARKET_SORTER_MODE_ALPHA` | 1 | — | description key `oolite-market-sorter-[n]` | `static_assert` (T057) |
| `OOMarketSorterMode` | `MARKET_SORTER_MODE_PRICE` | 2 | — | description key `oolite-market-sorter-[n]` | `static_assert` (T057) |
| `OOMarketSorterMode` | `MARKET_SORTER_MODE_STOCK` | 3 | — | description key `oolite-market-sorter-[n]` | `static_assert` (T057) |
| `OOMarketSorterMode` | `MARKET_SORTER_MODE_HOLD` | 4 | — | description key `oolite-market-sorter-[n]` | `static_assert` (T057) |
| `OOMarketSorterMode` | `MARKET_SORTER_MODE_UNIT` | 5 | — | description key `oolite-market-sorter-[n]` | `static_assert` (T057) |
| `OOMarketSorterMode` | `MARKET_SORTER_MODE_MAX` | 5 | — | description key `oolite-market-sorter-[n]` | `static_assert` (T057) |
| `ALERT_FLAG_* (OOAlertFlags)` | `ALERT_FLAG_DOCKED` | 16 | — | JS alert flags (`OOJSPlayer.cpp:273-293`) | `static_assert` (T052) |
| `ALERT_FLAG_* (OOAlertFlags)` | `ALERT_FLAG_MASS_LOCK` | 32 | — | JS alert flags (`OOJSPlayer.cpp:273-293`) | `static_assert` (T052) |
| `ALERT_FLAG_* (OOAlertFlags)` | `ALERT_FLAG_YELLOW_LIMIT` | 63 | — | JS alert flags (`OOJSPlayer.cpp:273-293`) | `static_assert` (T052) |
| `ALERT_FLAG_* (OOAlertFlags)` | `ALERT_FLAG_TEMP` | 64 | — | JS alert flags (`OOJSPlayer.cpp:273-293`) | `static_assert` (T052) |
| `ALERT_FLAG_* (OOAlertFlags)` | `ALERT_FLAG_ALT` | 128 | — | JS alert flags (`OOJSPlayer.cpp:273-293`) | `static_assert` (T052) |
| `ALERT_FLAG_* (OOAlertFlags)` | `ALERT_FLAG_ENERGY` | 256 | — | JS alert flags (`OOJSPlayer.cpp:273-293`) | `static_assert` (T052) |
| `ALERT_FLAG_* (OOAlertFlags)` | `ALERT_FLAG_HOSTILES` | 512 | — | JS alert flags (`OOJSPlayer.cpp:273-293`) | `static_assert` (T052) |
| `AXIS_* (joystick)` | `AXIS_ROLL` | 0 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `AXIS_* (joystick)` | `AXIS_PITCH` | 1 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `AXIS_* (joystick)` | `AXIS_YAW` | 2 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `AXIS_* (joystick)` | `AXIS_PRECISION` | 3 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `AXIS_* (joystick)` | `AXIS_THRUST` | 4 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `AXIS_* (joystick)` | `AXIS_VIEWX` | 5 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `AXIS_* (joystick)` | `AXIS_VIEWY` | 6 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `AXIS_* (joystick)` | `AXIS_end` | 7 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_INCTHRUST` | 0 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_DECTHRUST` | 1 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_SCANNERZOOM` | 2 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_SCANNERUNZOOM` | 3 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_JETTISON` | 4 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_COMPASSMODE` | 5 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_COMMSLOG` | 6 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_DOCKCPU` | 7 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_DOCKCPUFAST` | 8 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_FUELINJECT` | 9 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_HYPERSPEED` | 10 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_HYPERDRIVE` | 11 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_GALACTICDRIVE` | 12 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_FIRE` | 13 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_ARMMISSILE` | 14 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_LAUNCHMISSILE` | 15 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_PRIMEEQUIPMENT` | 16 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_ACTIVATEEQUIPMENT` | 17 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_UNARM` | 18 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_TARGETINCOMINGMISSILE` | 19 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_CYCLEMISSILE` | 20 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_ENERGYBOMB` | 21 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_WEAPONSONLINETOGGLE` | 22 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_ID` | 23 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_ECM` | 24 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_ESCAPE` | 25 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_CLOAK` | 26 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_PRECISION` | 27 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_VIEWFORWARD` | 28 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_VIEWAFT` | 29 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_VIEWPORT` | 30 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_VIEWSTARBOARD` | 31 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_SNAPSHOT` | 32 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_PREVTARGET` | 33 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_NEXTTARGET` | 34 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_MODEEQUIPMENT` | 35 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_DOCKINGCLEARANCE` | 36 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_COMPASSMODE_PREV` | 37 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_PRIMEEQUIPMENT_PREV` | 38 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_ROTATECARGO` | 39 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_MFDSELECTNEXT` | 40 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_MFDSELECTPREV` | 41 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_MFDCYCLENEXT` | 42 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_MFDCYCLEPREV` | 43 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_EXTVIEWCYCLE` | 44 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_DOCKINGMUSIC` | 45 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_PAUSE` | 46 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_TOGGLEHUD` | 47 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_GUILEFT` | 48 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_GUIRIGHT` | 49 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_GUIUP` | 50 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_GUIDOWN` | 51 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_GUIPAGEUP` | 52 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_GUIPAGEDOWN` | 53 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_GUISELECT` | 54 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `BUTTON_* (joystick)` | `BUTTON_end` | 55 | — | preference keys (`ENUMKEY`); ordinals shift with `OO_FOV_INFLIGHT_CONTROL_ENABLED` | `static_assert` (T067) |
| `OO_POSTFX_* (post-processing)` | `OO_POSTFX_NONE` | 0 | — | JS `oolite.postFX` (`OOJSOolite.cpp:199`) | `static_assert` (T068) |
| `OO_POSTFX_* (post-processing)` | `OO_POSTFX_COLORBLINDNESS_PROTAN` | 1 | — | JS `oolite.postFX` (`OOJSOolite.cpp:199`) | `static_assert` (T068) |
| `OO_POSTFX_* (post-processing)` | `OO_POSTFX_COLORBLINDNESS_DEUTER` | 2 | — | JS `oolite.postFX` (`OOJSOolite.cpp:199`) | `static_assert` (T068) |
| `OO_POSTFX_* (post-processing)` | `OO_POSTFX_COLORBLINDNESS_TRITAN` | 3 | — | JS `oolite.postFX` (`OOJSOolite.cpp:199`) | `static_assert` (T068) |
| `OO_POSTFX_* (post-processing)` | `OO_POSTFX_CLOAK` | 4 | — | JS `oolite.postFX` (`OOJSOolite.cpp:199`) | `static_assert` (T068) |
| `OO_POSTFX_* (post-processing)` | `OO_POSTFX_GRAYSCALE` | 5 | — | JS `oolite.postFX` (`OOJSOolite.cpp:199`) | `static_assert` (T068) |
| `OO_POSTFX_* (post-processing)` | `OO_POSTFX_OLDMOVIE` | 6 | — | JS `oolite.postFX` (`OOJSOolite.cpp:199`) | `static_assert` (T068) |
| `OO_POSTFX_* (post-processing)` | `OO_POSTFX_CRT` | 7 | — | JS `oolite.postFX` (`OOJSOolite.cpp:199`) | `static_assert` (T068) |
| `OO_POSTFX_* (post-processing)` | `OO_POSTFX_CRTBADSIGNAL` | 8 | — | JS `oolite.postFX` (`OOJSOolite.cpp:199`) | `static_assert` (T068) |
| `OO_POSTFX_* (post-processing)` | `OO_POSTFX_ENDOFLIST` | 9 | — | JS `oolite.postFX` (`OOJSOolite.cpp:199`) | `static_assert` (T068) |
| `OOEntityStatus` | `STATUS_START_GAME` | -10 | `STATUS_START_GAME` and -10 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_RESTART_GAME` | -2 | `STATUS_RESTART_GAME` and -2 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_DEAD` | -1 | `STATUS_DEAD` and -1 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_INACTIVE` | 0 | `STATUS_INACTIVE` and 0 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_TEST` | 1 | `STATUS_TEST` and 1 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_COCKPIT_DISPLAY` | 2 | `STATUS_COCKPIT_DISPLAY` and 2 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_ACTIVE` | 5 | `STATUS_ACTIVE` and 5 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_EFFECT` | 10 | `STATUS_EFFECT` and 10 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_IN_FLIGHT` | 100 | `STATUS_IN_FLIGHT` and 100 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_DOCKED` | 200 | `STATUS_DOCKED` and 200 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_AUTOPILOT_ENGAGED` | 300 | `STATUS_AUTOPILOT_ENGAGED` and 300 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_DOCKING` | 401 | `STATUS_DOCKING` and 401 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_LAUNCHING` | 402 | `STATUS_LAUNCHING` and 402 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_WITCHSPACE_COUNTDOWN` | 410 | `STATUS_WITCHSPACE_COUNTDOWN` and 410 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_ENTERING_WITCHSPACE` | 411 | `STATUS_ENTERING_WITCHSPACE` and 411 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_EXITING_WITCHSPACE` | 412 | `STATUS_EXITING_WITCHSPACE` and 412 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_ESCAPE_SEQUENCE` | 500 | `STATUS_ESCAPE_SEQUENCE` and 500 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_IN_HOLD` | 600 | `STATUS_IN_HOLD` and 600 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_BEING_SCOOPED` | 700 | `STATUS_BEING_SCOOPED` and 700 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOEntityStatus` | `STATUS_HANDLING_ERROR` | 999 | `STATUS_HANDLING_ERROR` and 999 | JS `status`, shipdata, AI | `static_assert` (T060) |
| `OOScanClass` | `CLASS_NOT_SET` | -1 | `CLASS_NOT_SET` and -1 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_NO_DRAW` | 0 | `CLASS_NO_DRAW` and 0 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_NEUTRAL` | 1 | `CLASS_NEUTRAL` and 1 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_STATION` | 3 | `CLASS_STATION` and 3 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_TARGET` | 4 | `CLASS_TARGET` and 4 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_CARGO` | 5 | `CLASS_CARGO` and 5 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_MISSILE` | 6 | `CLASS_MISSILE` and 6 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_ROCK` | 7 | `CLASS_ROCK` and 7 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_MINE` | 8 | `CLASS_MINE` and 8 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_THARGOID` | 9 | `CLASS_THARGOID` and 9 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_BUOY` | 10 | `CLASS_BUOY` and 10 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_VISUAL_EFFECT` | 11 | `CLASS_VISUAL_EFFECT` and 11 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_WORMHOLE` | 444 | `CLASS_WORMHOLE` and 444 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_PLAYER` | 100 | `CLASS_PLAYER` and 100 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_POLICE` | 999 | `CLASS_POLICE` and 999 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOScanClass` | `CLASS_MILITARY` | 333 | `CLASS_MILITARY` and 333 | JS `scanClass`, shipdata `scan_class` | `static_assert` (T060) |
| `OOShipDamageType` | `kOODamageTypeScrape` | 0 | `scrape damage` and 0 | JS damage types | `static_assert` (T060) |
| `OOShipDamageType` | `kOODamageTypeHeat` | 1 | `heat damage` and 1 | JS damage types | `static_assert` (T060) |
| `OOShipDamageType` | `kOODamageTypeEnergy` | 2 | `energy damage` and 2 | JS damage types | `static_assert` (T060) |
| `OOShipDamageType` | `kOODamageTypeCascadeWeapon` | 3 | `cascade weapon` and 3 | JS damage types | `static_assert` (T060) |
| `OOShipDamageType` | `kOODamageTypeHitAPlanet` | 4 | `hit a planet` and 4 | JS damage types | `static_assert` (T060) |
| `OOShipDamageType` | `kOODamageTypeHitASun` | 5 | `hit a sun` and 5 | JS damage types | `static_assert` (T060) |
| `OOShipDamageType` | `kOODamageTypeRemoved` | 6 | `removed` and 6 | JS damage types | `static_assert` (T060) |
| `OOBehaviour` | `BEHAVIOUR_IDLE` | 0 | `BEHAVIOUR_IDLE` and 0 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_TRACK_TARGET` | 1 | `BEHAVIOUR_TRACK_TARGET` and 1 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_TUMBLE` | 4 | `BEHAVIOUR_TUMBLE` and 4 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_STOP_STILL` | 5 | `BEHAVIOUR_STOP_STILL` and 5 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_STATION_KEEPING` | 10 | `BEHAVIOUR_STATION_KEEPING` and 10 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ATTACK_TARGET` | 101 | `BEHAVIOUR_ATTACK_TARGET` and 101 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ATTACK_FLY_TO_TARGET` | 102 | `BEHAVIOUR_ATTACK_FLY_TO_TARGET` and 102 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ATTACK_FLY_FROM_TARGET` | 103 | `BEHAVIOUR_ATTACK_FLY_FROM_TARGET` and 103 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_RUNNING_DEFENSE` | 104 | `BEHAVIOUR_RUNNING_DEFENSE` and 104 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_FLEE_TARGET` | 105 | `BEHAVIOUR_FLEE_TARGET` and 105 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ATTACK_FLY_TO_TARGET_SIX` | 106 | `BEHAVIOUR_ATTACK_FLY_TO_TARGET_SIX` and 106 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ATTACK_MINING_TARGET` | 107 | `BEHAVIOUR_ATTACK_MINING_TARGET` and 107 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_EVASIVE_ACTION` | 108 | `BEHAVIOUR_EVASIVE_ACTION` and 108 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_FLEE_EVASIVE_ACTION` | 109 | `BEHAVIOUR_FLEE_EVASIVE_ACTION` and 109 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ATTACK_BREAK_OFF_TARGET` | 110 | `BEHAVIOUR_ATTACK_BREAK_OFF_TARGET` and 110 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ATTACK_SLOW_DOGFIGHT` | 111 | `BEHAVIOUR_ATTACK_SLOW_DOGFIGHT` and 111 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ATTACK_FLY_TO_TARGET_TWELVE` | 112 | `BEHAVIOUR_ATTACK_FLY_TO_TARGET_TWELVE` and 112 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ATTACK_SNIPER` | 113 | `BEHAVIOUR_ATTACK_SNIPER` and 113 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ATTACK_BROADSIDE` | 115 | `BEHAVIOUR_ATTACK_BROADSIDE` and 115 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ATTACK_BROADSIDE_LEFT` | 116 | `BEHAVIOUR_ATTACK_BROADSIDE_LEFT` and 116 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ATTACK_BROADSIDE_RIGHT` | 117 | `BEHAVIOUR_ATTACK_BROADSIDE_RIGHT` and 117 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_CLOSE_TO_BROADSIDE_RANGE` | 118 | `BEHAVIOUR_CLOSE_TO_BROADSIDE_RANGE` and 118 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_CLOSE_WITH_TARGET` | 125 | `BEHAVIOUR_CLOSE_WITH_TARGET` and 125 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_AVOID_COLLISION` | 130 | `BEHAVIOUR_AVOID_COLLISION` and 130 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_TRACK_AS_TURRET` | 150 | `BEHAVIOUR_TRACK_AS_TURRET` and 150 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_FLY_RANGE_FROM_DESTINATION` | 200 | `BEHAVIOUR_FLY_RANGE_FROM_DESTINATION` and 200 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_FLY_TO_DESTINATION` | 201 | `BEHAVIOUR_FLY_TO_DESTINATION` and 201 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_FLY_FROM_DESTINATION` | 202 | `BEHAVIOUR_FLY_FROM_DESTINATION` and 202 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_FACE_DESTINATION` | 203 | `BEHAVIOUR_FACE_DESTINATION` and 203 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_FLY_THRU_NAVPOINTS` | 210 | `BEHAVIOUR_FLY_THRU_NAVPOINTS` and 210 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_LAND_ON_PLANET` | 250 | `BEHAVIOUR_LAND_ON_PLANET` and 250 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_COLLECT_TARGET` | 300 | `BEHAVIOUR_COLLECT_TARGET` and 300 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_INTERCEPT_TARGET` | 350 | `BEHAVIOUR_INTERCEPT_TARGET` and 350 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_FORMATION_FORM_UP` | 501 | `BEHAVIOUR_FORMATION_FORM_UP` and 501 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_FORMATION_BREAK` | 502 | `BEHAVIOUR_FORMATION_BREAK` and 502 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_ENERGY_BOMB_COUNTDOWN` | 601 | `BEHAVIOUR_ENERGY_BOMB_COUNTDOWN` and 601 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_TRACTORED` | 701 | `BEHAVIOUR_TRACTORED` and 701 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_SCRIPTED_AI` | 801 | `BEHAVIOUR_SCRIPTED_AI` and 801 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOBehaviour` | `BEHAVIOUR_SCRIPTED_ATTACK_AI` | 811 | `BEHAVIOUR_SCRIPTED_ATTACK_AI` and 811 | JS, saved game (`ShipEntity.cpp:6726`) | `static_assert` (T061) |
| `OOGalacticHyperspaceBehaviour` | `GALACTIC_HYPERSPACE_BEHAVIOUR_STANDARD` | 0 | `BEHAVIOUR_STANDARD` and 0 | planetinfo / JS galactic hyperspace behaviour | `static_assert` (T061) |
| `OOGalacticHyperspaceBehaviour` | `GALACTIC_HYPERSPACE_BEHAVIOUR_ALL_SYSTEMS_REACHABLE` | 1 | `BEHAVIOUR_ALL_SYSTEMS_REACHABLE` and 1 | planetinfo / JS galactic hyperspace behaviour | `static_assert` (T061) |
| `OOGalacticHyperspaceBehaviour` | `GALACTIC_HYPERSPACE_BEHAVIOUR_FIXED_COORDINATES` | 2 | `BEHAVIOUR_FIXED_COORDINATES` and 2 | planetinfo / JS galactic hyperspace behaviour | `static_assert` (T061) |
| `OOGalacticHyperspaceBehaviour` | `GALACTIC_HYPERSPACE_BEHAVIOUR_UNKNOWN` | -1 | `BEHAVIOUR_UNKNOWN` and -1 | planetinfo / JS galactic hyperspace behaviour | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonUnknown` | 0 | `unknown` and 0 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonSetup` | 1 | `setup actions` and 1 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonByScript` | 2 | `scripted` and 2 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonAttackedPolice` | 3 | `attacked police` and 3 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonAttackedMainStation` | 4 | `attacked main station` and 4 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonAttackedInnocent` | 5 | `attacked innocent` and 5 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonSeenByPolice` | 6 | `seen by police` and 6 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonDistressCall` | 7 | `distress call` and 7 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonIllegalExports` | 8 | `illegal exports` and 8 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonIllegalImports` | 9 | `illegal imports` and 9 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonAssistingOffender` | 10 | `assisting offenders` and 10 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonNewGalaxy` | 11 | `new galaxy` and 11 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonNewSystem` | 12 | `new system` and 12 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonPaidFine` | 13 | `paid fine` and 13 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonEscapePod` | 14 | `escape pod` and 14 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonAssistingPolice` | 15 | `assisting police` and 15 | JS legal-status change reasons | `static_assert` (T061) |
| `OOLegalStatusReason` | `kOOLegalStatusReasonPoliceAreClean` | 16 | `police are clean` and 16 | JS legal-status change reasons | `static_assert` (T061) |
| `OOCompassMode` | `COMPASS_MODE_INACTIVE` | -1 | `COMPASS_MODE_INACTIVE` and -1 | JS `compassMode`, shaders (`EntityShaderBindings.cpp:637`) | `static_assert` (T062) |
| `OOCompassMode` | `COMPASS_MODE_BASIC` | 0 | `COMPASS_MODE_BASIC` and 0 | JS `compassMode`, shaders (`EntityShaderBindings.cpp:637`) | `static_assert` (T062) |
| `OOCompassMode` | `COMPASS_MODE_PLANET` | 1 | `COMPASS_MODE_PLANET` and 1 | JS `compassMode`, shaders (`EntityShaderBindings.cpp:637`) | `static_assert` (T062) |
| `OOCompassMode` | `COMPASS_MODE_STATION` | 3 | `COMPASS_MODE_STATION` and 3 | JS `compassMode`, shaders (`EntityShaderBindings.cpp:637`) | `static_assert` (T062) |
| `OOCompassMode` | `COMPASS_MODE_SUN` | 4 | `COMPASS_MODE_SUN` and 4 | JS `compassMode`, shaders (`EntityShaderBindings.cpp:637`) | `static_assert` (T062) |
| `OOCompassMode` | `COMPASS_MODE_TARGET` | 5 | `COMPASS_MODE_TARGET` and 5 | JS `compassMode`, shaders (`EntityShaderBindings.cpp:637`) | `static_assert` (T062) |
| `OOCompassMode` | `COMPASS_MODE_BEACONS` | 6 | `COMPASS_MODE_BEACONS` and 6 | JS `compassMode`, shaders (`EntityShaderBindings.cpp:637`) | `static_assert` (T062) |
| `OOViewID` | `VIEW_FORWARD` | 0 | `VIEW_FORWARD` and 0 | JS `viewDirection` | `static_assert` (T062) |
| `OOViewID` | `VIEW_AFT` | 1 | `VIEW_AFT` and 1 | JS `viewDirection` | `static_assert` (T062) |
| `OOViewID` | `VIEW_PORT` | 2 | `VIEW_PORT` and 2 | JS `viewDirection` | `static_assert` (T062) |
| `OOViewID` | `VIEW_STARBOARD` | 3 | `VIEW_STARBOARD` and 3 | JS `viewDirection` | `static_assert` (T062) |
| `OOViewID` | `VIEW_CUSTOM` | 4 | `VIEW_CUSTOM` and 4 | JS `viewDirection` | `static_assert` (T062) |
| `OOViewID` | `VIEW_NONE` | 5 | `VIEW_NONE` and 5 | JS `viewDirection` | `static_assert` (T062) |
| `OOViewID` | `VIEW_GUI_DISPLAY` | 6 | `VIEW_GUI_DISPLAY` and 6 | JS `viewDirection` | `static_assert` (T062) |
| `OOViewID` | `VIEW_BREAK_PATTERN` | 7 | `VIEW_BREAK_PATTERN` and 7 | JS `viewDirection` | `static_assert` (T062) |
| `OOLongRangeChartMode` | `OOLRC_MODE_UNKNOWN` | 0 | `OOLRC_MODE_UNKNOWN` and 0 | saved game `chart_colour_mode` | `static_assert` (T063) |
| `OOLongRangeChartMode` | `OOLRC_MODE_SUNCOLOR` | 1 | `OOLRC_MODE_SUNCOLOR` and 1 | saved game `chart_colour_mode` | `static_assert` (T063) |
| `OOLongRangeChartMode` | `OOLRC_MODE_ECONOMY` | 2 | `OOLRC_MODE_ECONOMY` and 2 | saved game `chart_colour_mode` | `static_assert` (T063) |
| `OOLongRangeChartMode` | `OOLRC_MODE_GOVERNMENT` | 3 | `OOLRC_MODE_GOVERNMENT` and 3 | saved game `chart_colour_mode` | `static_assert` (T063) |
| `OOLongRangeChartMode` | `OOLRC_MODE_TECHLEVEL` | 4 | `OOLRC_MODE_TECHLEVEL` and 4 | saved game `chart_colour_mode` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_MAIN` | 0 | `GUI_SCREEN_MAIN` and 0 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_INTRO1` | 1 | `GUI_SCREEN_INTRO1` and 1 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_SHIPLIBRARY` | 2 | `GUI_SCREEN_SHIPLIBRARY` and 2 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_KEYBOARD` | 3 | `GUI_SCREEN_KEYBOARD` and 3 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_NEWGAME` | 4 | `GUI_SCREEN_NEWGAME` and 4 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_OXZMANAGER` | 5 | `GUI_SCREEN_OXZMANAGER` and 5 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_STATUS` | 6 | `GUI_SCREEN_STATUS` and 6 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_MANIFEST` | 7 | `GUI_SCREEN_MANIFEST` and 7 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_EQUIP_SHIP` | 8 | `GUI_SCREEN_EQUIP_SHIP` and 8 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_SHIPYARD` | 9 | `GUI_SCREEN_SHIPYARD` and 9 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_LONG_RANGE_CHART` | 10 | `GUI_SCREEN_LONG_RANGE_CHART` and 10 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_SHORT_RANGE_CHART` | 11 | `GUI_SCREEN_SHORT_RANGE_CHART` and 11 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_SYSTEM_DATA` | 12 | `GUI_SCREEN_SYSTEM_DATA` and 12 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_MARKET` | 13 | `GUI_SCREEN_MARKET` and 13 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_MARKETINFO` | 14 | `GUI_SCREEN_MARKETINFO` and 14 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_OPTIONS` | 15 | `GUI_SCREEN_OPTIONS` and 15 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_GAMEOPTIONS` | 16 | `GUI_SCREEN_GAMEOPTIONS` and 16 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_LOAD` | 17 | `GUI_SCREEN_LOAD` and 17 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_SAVE` | 18 | `GUI_SCREEN_SAVE` and 18 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_SAVE_OVERWRITE` | 19 | `GUI_SCREEN_SAVE_OVERWRITE` and 19 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_STICKMAPPER` | 20 | `GUI_SCREEN_STICKMAPPER` and 20 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_STICKPROFILE` | 21 | `GUI_SCREEN_STICKPROFILE` and 21 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_MISSION` | 22 | `GUI_SCREEN_MISSION` and 22 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_REPORT` | 23 | `GUI_SCREEN_REPORT` and 23 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_INTERFACES` | 24 | `GUI_SCREEN_INTERFACES` and 24 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_KEYBOARD_CONFIRMCLEAR` | 25 | `GUI_SCREEN_KEYBOARD_CONFIRMCLEAR` and 25 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_KEYBOARD_CONFIG` | 26 | `GUI_SCREEN_KEYBOARD_CONFIG` and 26 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_KEYBOARD_ENTRY` | 27 | `GUI_SCREEN_KEYBOARD_ENTRY` and 27 | JS `guiScreen` | `static_assert` (T063) |
| `OOGUIScreenID` | `GUI_SCREEN_KEYBOARD_LAYOUT` | 28 | `GUI_SCREEN_KEYBOARD_LAYOUT` and 28 | JS `guiScreen` | `static_assert` (T063) |

Also external, kept as they are and pinned by their own tasks: the `console.DEBUG_*` names and
values of `OODebugFlags` (T046), the texture option bits in the `%X` shader cache key
(`OODefaultShaderSynthesizer.cpp:353`, T056) and the debug TCP protocol numbers
(`OODebugTCPConsoleProtocol.h`, T068, shared with the external console).
