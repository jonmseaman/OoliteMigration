## OOFoundation.h?
oolite-dev/src/Core/OOFoundation.h

Is this still needed? This file should be reviewed. Some it is obsolete I think.


## Macros for profiling?

Are these needed, or would a normally profiler run work instead?
Why were these created?

```cpp
void DockEntity::initDockDefaults() {
  OOJS_PROFILE_ENTER

  allow_docking = YES;
  disallowed_docking_collides = NO;
  allow_launching = YES;
  virtual_dock = NO;

  OOJS_PROFILE_EXIT_VOID
}
```

## If C++?

Are these still needed

`OODebugTCPConsoleProtocol.h`

```cpp
#if defined(__cplusplus)

```

`OOJSEngineNativeWrappers.h`

```cpp
#ifdef __cplusplus
#ifndef OOJS_EXTERN_C
#define OOJS_EXTERN_C extern "C"
#endif
#else
#ifndef OOJS_EXTERN_C
#define OOJS_EXTERN_C
#endif
#endif
```

I guess these exist because some code is stil compiled as C instead of C++.
That is what I told Claude to do, but it is now dirtying up the code base.


## Windows only code

```cpp

#if OOLITE_WINDOWS
typedef SOCKET OOSocket;
typedef int OOSocketLength;
...
```

Ideally would not have windows-only code like this.
I'd rather have this moved to a library where there is one implementation per platform.


## Ugly enum code:

```cpp
typedef enum {
  GUI_ALIGN_LEFT,
  GUI_ALIGN_RIGHT,
  GUI_ALIGN_CENTER
} OOGUIAlignment;

typedef enum {
  GUI_BACKGROUND_SPECIAL_NONE,
  GUI_BACKGROUND_SPECIAL_CUSTOM,
  GUI_BACKGROUND_SPECIAL_CUSTOM_ANA_SHORTEST,
  GUI_BACKGROUND_SPECIAL_CUSTOM_ANA_QUICKEST,
  GUI_BACKGROUND_SPECIAL_SHORT,
  GUI_BACKGROUND_SPECIAL_SHORT_ANA_SHORTEST,
  GUI_BACKGROUND_SPECIAL_SHORT_ANA_QUICKEST,
  GUI_BACKGROUND_SPECIAL_LONG,
  GUI_BACKGROUND_SPECIAL_LONG_ANA_SHORTEST,
  GUI_BACKGROUND_SPECIAL_LONG_ANA_QUICKEST
} OOGUIBackgroundSpecial;
```


## Macros instead of constants

```cpp
#define GUI_MAX_ROWS 64
#define GUI_MAX_COLUMNS 40
#define MAIN_GUI_PIXEL_HEIGHT 480
#define MAIN_GUI_PIXEL_WIDTH 480
#define MAIN_GUI_ROW_HEIGHT 16
#define MAIN_GUI_ROW_WIDTH 16
#define MAIN_GUI_PIXEL_ROW_START 40
```
## AI-driven behavior analysis before and after
Compare the Objective-C code and the C++ code for behavior discrepancies.
This should also be driven through playtests etc.


## Component tests organization

- `tests/unit` --> Unit tests should normally go alongside the files they test.
- `tests/component`
	- feature folder files should be moved up one with step definitions in subfolders or a different folder alongside.


## GnuStep macros

Many instances of macros with GNUSTEP in it. Are these obsolete and can they be deleted?
```cpp
#elif (OOLITE_GNUSTEP && defined(OO_DEBUG_MONITOR_ENABLED))  
#include "OODebugMonitor.h"  
#endif
```

`ShellScripts/Linux/build_gnustep.sh` --> Should this file even exist?

## Better autoformat

There are functions that don't have spaces between them.

Stuff like this:
```cpp
int func1() {
}
int func2() {
}
```

Readability prefers spaces between functions. There should be readability rules generated and such.

Example potential style guide:
https://google.github.io/styleguide/cppguide.html
Cons: I don't like the license boilerplate at the beginning.

## Heavy macro use

There are a ton of macros. Some are debug only, some are windows only.
I'm not a huge fan of macros. I'd like to go through and see if these should be replaced in some cases.


