#if OOLITE_WINDOWS
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
extern "C" HRESULT WINAPI DwmSetWindowAttribute(HWND hwnd, DWORD dwAttribute, LPCVOID pvAttribute, DWORD cbAttribute);

#define USE_UNDOCUMENTED_DARKMODE_API 1

#if USE_UNDOCUMENTED_DARKMODE_API
#ifndef LOAD_LIBRARY_SEARCH_SYSTEM32
#define LOAD_LIBRARY_SEARCH_SYSTEM32 0x00000800
#endif
typedef DWORD(WINAPI* pfnSetPreferredAppMode)(DWORD appMode);
enum PreferredAppMode {
    Default,
    AllowDark,
    ForceDark,
    ForceLight,
    Max
};
#endif
#endif // OOLITE_WINDOWS
