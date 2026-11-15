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

## Windows only code

```cpp

#if OOLITE_WINDOWS
typedef SOCKET OOSocket;
typedef int OOSocketLength;
...
```

Ideally would not have windows-only code like this.
I'd rather have this moved to a library where there is one implementation per platform.


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

## Heavy macro use

There are a ton of macros. Some are debug only, some are windows only.
I'm not a huge fan of macros. I'd like to go through and see if these should be replaced in some cases.


