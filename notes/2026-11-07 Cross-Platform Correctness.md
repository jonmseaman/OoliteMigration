# Cross-platform correctness (2026-11-07)

Measured on `seriesb/027-ship-library-keys` (ac60522c9), 2026-11-07. **Waiting for Jon's in-depth
review**; nothing here is scheduled yet. Line numbers are on 027. See also
[2026-11-06 Cross-Platform Checks from a Mac](2026-11-06%20Cross-Platform%20Checks%20from%20a%20Mac.md).

## Cross-platform correctness

1. **macOS keymappings bug**: `PlayerEntityKeyMapper.cpp:147-156` `KeyMappingsFileName()` has no macOS branch, so it returns `""` even though `Resources/Config/keymappings_mac.plist` exists. This is a real user-facing bug.
2. **x86 `cpuid` asm** in `OOCPUInfo.cpp:112-236` is guarded by OS (`OOLITE_WINDOWS || OOLITE_LINUX`), not by architecture. It breaks Linux/aarch64 and Windows-on-ARM. Guard it with `__x86_64__ || _M_X64`, and use `sysctl`/`/proc/cpuinfo` fallbacks.
3. **LP64**: `PListGet.hpp:66-67` integer clamping is "exact only on LLP64" and the `unsigned long` accessor needs revisiting. Fix it so the 5 oofnd tests (`test_foundation_types`, `test_string`, `test_plist_get`, `test_resourcepaths`, `test_defaults`) and the 34 Windows-only core tests can be enabled on Linux and macOS. Use `test_OOShaderUniformMethodType.cpp:93` as the canary (it assumes a 32-bit `long`). Each Windows-only test either runs everywhere or carries a written reason.
4. **Save/prefs/OXZ paths per OS**: verify that the Mac (Application Support) and Linux (`~/.Oolite`, GNUstep `Defaults`) locations match upstream 1.93, so existing players keep their saves and OXZs. Add a unit test per OS in `ResourcePaths`. This interacts with removing the GNUstep runtime config (`run_oolite.sh` `GNUstep.conf`, `OO_GNUSTEPDEFAULTSDIR` in `Defaults.hpp`).
5. **Thread-safety**: the formal race on `OOTextureLoader.cpp:68-86` statics (`sReducedDetail` is written on the main thread and read by the worker-thread load; `sHaveSetUp` is lazily initialised without a lock): make them `std::atomic` / `std::call_once`. Confirm that the `UNIVERSE` reads in `OOPlanetTextureGenerator.cpp:205` and `OOStandaloneAtmosphereGenerator.cpp:131` happen at init time. ARM's weaker memory model makes this more likely to bite on Apple Silicon than on x86.
6. HDR and other Windows-only features (`wglGetProcAddress`, `ChangeDisplaySettingsEx`, EcoQoS, OXZ file unlocking): fine as they are, but document them in `docs/current-state.md` as platform differences.

Suggested order: 1 and 2 first (real user-facing bugs), then 3–5.
