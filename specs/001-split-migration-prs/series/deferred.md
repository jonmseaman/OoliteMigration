# Upstream changes deferred within the series

Upstream changes the history's code at a step could not take yet, with the step that carries
them. Each must be present by the last step (`develop` has them); the check for that is the final
tree equalling `develop` (FR-002).

| From step | Upstream change | Why deferred | Present again from |
|---:|---|---|---|
| 7 | #766 macOS: `builtInPath` returns the app bundle's resource path under `OOLITE_MAC_COCOA_UI` | the history replaced the path code with `oo::ResourcePaths`; macOS is not converted (Phase 5) | 023 (`ac193cfe7` ports #766's macOS paths, dormant behind `OOLITE_MAC_OS_X`) |
