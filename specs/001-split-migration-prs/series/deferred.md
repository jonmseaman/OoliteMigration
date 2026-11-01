# Upstream changes deferred within the series

Upstream changes the history's code at a step could not take yet, with the step that carries
them. Each must be present by the last step (`develop` has them); the check for that is the final
tree equalling `develop` (FR-002).

| From step | Upstream change | Why deferred | Present again from |
|---:|---|---|---|
| 7 | #766 macOS: `builtInPath` returns the app bundle's resource path under `OOLITE_MAC_COCOA_UI` | the history replaced the path code with `oo::ResourcePaths`; macOS is not converted (Phase 5) | 023 (`ac193cfe7` ports #766's macOS paths, dormant behind `OOLITE_MAC_OS_X`) |
| 3 | #742 moved `decode{Axis,Button,Hat}Event` into `OOSDLJoystickManager` (an Objective-C GCC warning) | the migration keeps them in `OOJoystickManager`, as `develop` does; steps 3–6 carry both copies, and step 7 takes the history's SDL manager whole | n/a: `develop` keeps the history's design |
| 8 | #766 debug console: a plain socket on macOS | the history's plain-socket client covers it on every platform | 8 (covered) |
| 1–18 | #756 debug monitor in deployment builds: `#ifndef NDEBUG` → `#ifdef OO_DEBUG_MONITOR_ENABLED` | conflicting hunks take upstream's guard; code the history wrote on the pre-#756 base keeps `NDEBUG` (only the history knows which of its guards are monitor code). `test`-flavour builds define both, so they behave the same; deployment builds may lack monitor pieces | 19 (the history's own port of #756) |
| 11 | #766 macOS: `GameController` Cocoa-UI arms (`OOLITE_MAC_COCOA_UI`) | the history moved the Mac methods into a `GameController (MacOSX)` category; macOS is not converted | 023 |
| 11 | `PlanetEntity` (#745 names, #756 guards, `#pragma once`) | the history deleted this compiled-out old-planet code | n/a: deleted |
| 12 | #774 (Linux/X11 blank window): the splash window is replaced by a new game window sharing its GL context | the history's C++ `MyOpenGLView` keeps the old splash window | 023 (`f80c74210` ports #774) |
| 12 | #766 macOS: screenshot from the front buffer / GL drawable | macOS is not converted | 023 |
| 12–18 | Upstream's OXZ-manager copy-URL key (`n_key_oxzmanager_copyurl`, `-setOXPURL:`, `-processCopyUrlKey`) | **Done (T023).** Ported to C++ in step 12 (`setOXPURL(const std::optional<std::string>&)`, `processCopyUrlKey()`, `std::optional<std::string> _currentOXPURL`, a facade forwarder until step 15), its calls moved to C++ with the rest of the file in step 16, in the form of the history's own port (step 19). Step 16's resolution now keeps upstream's `setOXPURL` on the info page instead of the old immediate copy | 12 |
| 2–16 | Clang 23 warnings in files step 2 first compiles as Objective-C++ (`-Wvla-cxx-extension`, `-Wunused-but-set-global`, `-Wimplicit-const-int-float-conversion`) | **Fixed in step 2**, in the forms the history reaches later: `std::vector` buffers (history: steps 7, 9), `static_cast<double>(NSNotFound)` (step 16), the unused JS prototype and manifest objects removed (steps 4, 19). Not silenced | 2 |
