/*	test_MyOpenGLView.mm
	Unit tests for MyOpenGLView (src/SDL/MyOpenGLView.h), the game's SDL window and OpenGL view:
	bead oo-6rb6, slice 1 of the Phase 3 slice plan docs/phases/3-slices/MyOpenGLView.md (the class
	shell, the window and OpenGL lifecycle, the splash screen), in the house style of the OOColor
	exemplar (proposed ADR-0056, amendments oo-o89, oo-3bgz and oo-2g51).

	The view is made as the game makes it, with +alloc/-init, in a scratch home (no user defaults,
	so the splash screen is on and -init opens no window) with OpenAL on its null backend. The tests
	pin, through the Objective-C API, what the slice's units answer without a window: the state
	-init leaves (no game controller, the window caption, the size the view starts at, the input
	state, a matrix manager), the display it would open on and that display's native size, and the
	projection -updateGLSize: sets up, read back from a hidden OpenGL context
	(oo_gl_test_context.hpp). Opening the game's window (-createWindowWithSize:, -initSplashScreen,
	-endSplashScreen, -initialiseGLWithSize:, -updateScreen) would show a real window on the desktop,
	which a unit test must not do (CLAUDE.md, tools/gui-lock); the goldens launch the game, which runs
	all of them. The expectations were written against the unconverted class and run on it first.
	The view's -dealloc quits SDL, so one view serves every test and the last one releases it.
	Bead oo-72cz (slice 2) adds the accessors, the display-mode list and the saved window,
	full-screen and HDR settings, again without a window.

	MyOpenGLView.mm reaches the game controller, the universe and the player, so the test links
	every game object but main's (tests/unit/core/meson.build entry ['*'], ADR-0056 amendment
	oo-44gg) and defines gDebugFlags.
	Run: bash tools/check-core-tests.sh test_MyOpenGLView
*/

#import "MyOpenGLView.h"
#import "OOOpenGLMatrixManager.h"
#import "OOFullScreenController.h"

#include "oofnd/Defaults.hpp"
#include "oofnd/PList.hpp"
#include "oo_gl_test_context.hpp"
#include "oo_test.hpp"

#include <cmath>
#include <cstdlib>
#include <filesystem>
#include <process.h>
#include <string>


// main.mm defines the debug flags, and the test has its own main.
#ifndef NDEBUG
uint32_t gDebugFlags = 0;
#endif


namespace {

MyOpenGLView *sView = nil;


// A scratch home (no user defaults) and the null OpenAL backend, then the view, made once.
MyOpenGLView *View()
{
	if (sView != nil)  return sView;
	namespace stdfs = std::filesystem;
	OO_CHECK(::_putenv_s("ALSOFT_DRIVERS", "null") == 0);
	const stdfs::path root = stdfs::temp_directory_path() / ("oo-test-myopenglview-" + std::to_string(static_cast<unsigned long>(::_getpid())));
	stdfs::remove_all(root);
	stdfs::create_directories(root);
	OO_CHECK(::_putenv_s("HOMEPATH", root.string().c_str()) == 0);
	stdfs::current_path(root);
	sView = [[MyOpenGLView alloc] init];
	return sView;
}


bool Near(double a, double b)
{
	return std::fabs(a - b) < 1e-3;
}

}	// namespace


OO_TEST(initWithoutAWindow)
{
	@autoreleasepool
	{
		MyOpenGLView *view = View();
		OO_CHECK(view != nil);
		if (view == nil)  return;
		OO_CHECK([view gameController] == nil);
		OO_CHECK(![view inFullScreenMode]);
		// No defaults: the window size the game starts windowed at.
		OO_CHECK([view viewSize].width == WINDOW_SIZE_DEFAULT_WIDTH && [view viewSize].height == WINDOW_SIZE_DEFAULT_HEIGHT);
		OO_CHECK([view virtualJoystickPosition].x == 0.0 && [view virtualJoystickPosition].y == 0.0);
		OO_CHECK([view allowingStringInput] == gvStringInputNo);
		OO_CHECK(![view isAlphabetKeyDown]);
		OO_CHECK_EQ([view mouseWheelDelta], 0.0f);
		OO_CHECK([view getOpenGLMatrixManager] != nil);
		OO_CHECK([view getOpenGLMatrixManager] == [view getOpenGLMatrixManager]);
		OO_CHECK(![view hdrOutput]);	// set when the window is made
		OO_CHECK(![view msaa]);
		OO_CHECK(![view getScreenSizeArray].empty());	// the display's modes, the native one first
	}
}


OO_TEST(windowCaption)
{
	@autoreleasepool
	{
		MyOpenGLView *view = View();
		const std::optional<std::string> caption = [view getWindowCaption];
		OO_CHECK(caption.has_value());
		OO_CHECK(caption.has_value() && caption->rfind("Oolite v", 0) == 0);
		OO_CHECK(caption.has_value() && caption->find(" by ") != std::string::npos);
		OO_CHECK(caption == [view getWindowCaption]);
	}
}


OO_TEST(displayAndNativeSize)
{
	@autoreleasepool
	{
		MyOpenGLView *view = View();
		// No window yet: the first display.
		OO_CHECK([view getDisplayId] != 0);
		const oo::PList native = [view getNativeSize];
		OO_CHECK(native.isDict());
		OO_CHECK(native.get<int>(std::string(kOODisplayWidth), -1) > 0);
		OO_CHECK(native.get<int>(std::string(kOODisplayHeight), -1) > 0);
		OO_CHECK(native.get<int>(std::string(kOODisplayRefreshRate), -1) == 0);
		OO_CHECK_EQ(native.count(), 3u);
		// The mode list starts with it.
		const std::vector<oo::PList> modes = [view getScreenSizeArray];
		OO_CHECK(!modes.empty() && modes[0].get<int>(std::string(kOODisplayWidth), -1) == native.get<int>(std::string(kOODisplayWidth), -2));
	}
}


OO_TEST(updateGLSizeSetsTheProjection)
{
	@autoreleasepool
	{
		MyOpenGLView *view = View();
		OO_CHECK(OOTestGLContext());

		// 4:3 or narrower: the depth and x offset are fixed, y follows the aspect.
		[view updateGLSize:NSMakeSize(800, 600)];
		OO_CHECK([view viewSize].width == 800 && [view viewSize].height == 600);
		OO_CHECK([view backingViewSize].width == 800);
		OO_CHECK(Near([view display_z], 640.0));
		OO_CHECK(Near([view x_offset], 320.0));
		OO_CHECK(Near([view y_offset], 240.0));
		GLint viewport[4] = { -1, -1, -1, -1 };
		glGetIntegerv(GL_VIEWPORT, viewport);
		OO_CHECK(viewport[0] == 0 && viewport[1] == 0 && viewport[2] == 800 && viewport[3] == 600);

		[view updateGLSize:NSMakeSize(640, 960)];
		OO_CHECK(Near([view display_z], 640.0));
		OO_CHECK(Near([view x_offset], 320.0));
		OO_CHECK(Near([view y_offset], 480.0));

		// Wider than 4:3: the depth and x offset follow the aspect, y is fixed.
		[view updateGLSize:NSMakeSize(1600, 900)];
		OO_CHECK(Near([view display_z], 480.0 * 1600.0 / 900.0));
		OO_CHECK(Near([view x_offset], 240.0 * 1600.0 / 900.0));
		OO_CHECK(Near([view y_offset], 240.0));
		glGetIntegerv(GL_VIEWPORT, viewport);
		OO_CHECK(viewport[2] == 1600 && viewport[3] == 900);
	}
}


// --- bead oo-72cz: slice 2 (accessors, display modes, settings, display / HDR, FOV and MSAA) ---
// No window: none of these open one (full-screen mode is only switched off again, and the screen
// size is set while windowed). Settings the setters save go to the scratch home's defaults.

OO_TEST(slice2AccessorsAndViewSettings)
{
	@autoreleasepool
	{
		MyOpenGLView *view = View();

		// The game controller is not retained: any object round-trips.
		NSObject *controller = [[NSObject alloc] init];
		[view setGameController:(GameController *)controller];
		OO_CHECK([view gameController] == (GameController *)controller);
		[view setGameController:nil];
		OO_CHECK([view gameController] == nil);
		[controller release];

		// FOV: stored as tan(half the angle); in degrees or as that fraction.
		[view setFov:60.0f fromFraction:NO];
		OO_CHECK(Near([view fov:YES], std::tan(30.0 * M_PI / 180.0)));
		OO_CHECK(Near([view fov:NO], 60.0));
		[view setFov:0.5f fromFraction:YES];
		OO_CHECK(Near([view fov:YES], 0.5));
		OO_CHECK(Near([view fov:NO], 2.0 * std::atan(0.5) * 180.0 / M_PI));

		[view setMsaa:YES];
		OO_CHECK([view msaa]);
		[view setMsaa:NO];
		OO_CHECK(![view msaa]);

		// SDR tone mapper: clamped to the enum's range.
		[view setSDRToneMapper:(OOSDRToneMapper)99];
		OO_CHECK([view sdrToneMapper] == OOSDR_TONEMAPPER_REINHARD);
		[view setSDRToneMapper:(OOSDRToneMapper)-7];
		OO_CHECK([view sdrToneMapper] == OOSDR_TONEMAPPER_NONE);
		[view setSDRToneMapper:OOSDR_TONEMAPPER_AgX];
		OO_CHECK([view sdrToneMapper] == OOSDR_TONEMAPPER_AgX);

		// Colour saturation: adjusted, clamped to [0, MAX_COLOR_SATURATION]. No window: it starts at 0.
		OO_CHECK_EQ([view colorSaturation], 0.0f);
		[view adjustColorSaturation:0.25f];
		OO_CHECK(Near([view colorSaturation], 0.25));
		[view adjustColorSaturation:10.0f];
		OO_CHECK(Near([view colorSaturation], MAX_COLOR_SATURATION));
		[view adjustColorSaturation:-10.0f];
		OO_CHECK_EQ([view colorSaturation], 0.0f);

		OO_CHECK(![view hdrOutput]);
		(void)[view isOutputDisplayHDREnabled];	// the display's; not pinned
		[view grabMouseInsideGameWindow:NO];

		// +pollShiftKey reads the keyboard: nobody holds shift during a test run.
		OO_CHECK(![MyOpenGLView pollShiftKey]);
		OO_CHECK([view getOpenGLMatrixManager] != nil);

#if OOLITE_WINDOWS
		// No window: -isRunningOnPrimaryDisplayDevice answers NO, and -atDesktopResolution is unset.
		OO_CHECK(![view isRunningOnPrimaryDisplayDevice]);
		OO_CHECK(![view atDesktopResolution]);
		unsigned width = 7, height = 9;
		[view getDisplayDimensions:&width height:&height];	// no window, no display: unchanged
		OO_CHECK(width == 7 && height == 9);
		(void)[view isDarkModeOn];	// the user's theme; not pinned

		// HDR settings: clamped and saved to the defaults.
		[view setHDRMaxBrightness:10.0f];
		OO_CHECK(Near([view hdrMaxBrightness], MIN_HDR_MAXBRIGHTNESS));
		[view setHDRMaxBrightness:5000.0f];
		OO_CHECK(Near([view hdrMaxBrightness], MAX_HDR_MAXBRIGHTNESS));
		[view setHDRMaxBrightness:600.0f];
		OO_CHECK(Near([view hdrMaxBrightness], 600.0));
		OO_CHECK(Near(oo::Defaults::standard().floatForKey("hdr-max-brightness"), 600.0));
		[view setHDRPaperWhiteBrightness:1.0f];
		OO_CHECK(Near([view hdrPaperWhiteBrightness], MIN_HDR_PAPERWHITE));
		[view setHDRPaperWhiteBrightness:1000.0f];
		OO_CHECK(Near([view hdrPaperWhiteBrightness], MAX_HDR_PAPERWHITE));
		[view setHDRPaperWhiteBrightness:150.0f];
		OO_CHECK(Near([view hdrPaperWhiteBrightness], 150.0));
		OO_CHECK(Near(oo::Defaults::standard().floatForKey("hdr-paperwhite-brightness"), 150.0));
		[view setHDRToneMapper:(OOHDRToneMapper)42];
		OO_CHECK([view hdrToneMapper] == OOHDR_TONEMAPPER_REINHARD);
		[view setHDRToneMapper:(OOHDRToneMapper)-3];
		OO_CHECK([view hdrToneMapper] == OOHDR_TONEMAPPER_NONE);
		[view setHDRToneMapper:OOHDR_TONEMAPPER_DICE];
		OO_CHECK([view hdrToneMapper] == OOHDR_TONEMAPPER_DICE);
#endif
	}
}


OO_TEST(slice2DisplayModesAndSavedSettings)
{
	@autoreleasepool
	{
		MyOpenGLView *view = View();
		const std::vector<oo::PList> modes = [view getScreenSizeArray];
		OO_CHECK(!modes.empty());
		if (modes.empty())  return;
		const int nativeWidth = modes[0].get<int>(std::string(kOODisplayWidth), -1);
		const int nativeHeight = modes[0].get<int>(std::string(kOODisplayHeight), -1);

		// Mode 0 is the native mode, refresh 0.
		OO_CHECK([view modeAsSize:0].width == nativeWidth && [view modeAsSize:0].height == nativeHeight);
		OO_CHECK_EQ([view indexOfDisplayModeForWidth:nativeWidth Height:nativeHeight Refresh:0], 0);
		OO_CHECK_EQ([view indexOfDisplayModeForWidth:7 Height:5 Refresh:3], 0);	// none: the native mode
		const int last = static_cast<int>(modes.size()) - 1;
		const oo::PList &lastMode = modes[last];
		const int lastIndex = [view indexOfDisplayModeForWidth:lastMode.get<int>(std::string(kOODisplayWidth))
															Height:lastMode.get<int>(std::string(kOODisplayHeight))
														   Refresh:lastMode.get<int>(std::string(kOODisplayRefreshRate))];
		OO_CHECK(lastIndex >= 0 && lastIndex <= last);

		// Repopulating the list gives the same list.
		[view populateFullScreenModelist];
		OO_CHECK_EQ([view getScreenSizeArray].size(), modes.size());

		// Windowed: choosing a mode only records it.
		OO_CHECK(![view inFullScreenMode]);
		[view setScreenSize:last];
		OO_CHECK([view currentScreenMode] == lastMode);
		OO_CHECK([view currentScreenSize].width == lastMode.get<int>(std::string(kOODisplayWidth)));
		[view setDisplayMode:0 fullScreen:NO];
		OO_CHECK(![view inFullScreenMode]);
		OO_CHECK([view currentScreenMode] == modes[0]);
		OO_CHECK([view currentScreenSize].width == nativeWidth && [view currentScreenSize].height == nativeHeight);

		// Full-screen mode is saved to the defaults; switching it on without a window is not tried.
		[view setFullScreenMode:NO];
		OO_CHECK(![view inFullScreenMode]);
		OO_CHECK(oo::Defaults::standard().object("fullscreen").isBool() && !oo::Defaults::standard().boolForKey("fullscreen"));

		// The windowed size round-trips through the defaults.
		[view saveWindowSize:NSMakeSize(1000, 700)];
		OO_CHECK_EQ(oo::Defaults::standard().integerForKey("window_width"), 1000);
		OO_CHECK([view loadWindowSize].width == 1000 && [view loadWindowSize].height == 700);

		// Full-screen settings: windowed (saved above), the saved mode's index (none saved: 0).
		OO_CHECK_EQ([view loadFullscreenSettings], 0);
		OO_CHECK(![view inFullScreenMode]);
		oo::Defaults::standard().setInteger("display_width", nativeWidth);
		oo::Defaults::standard().setInteger("display_height", nativeHeight);
		oo::Defaults::standard().setInteger("display_refresh", 0);
		OO_CHECK_EQ([view loadFullscreenSettings], 0);
		OO_CHECK([view currentScreenMode] == modes[0]);
	}
}


// After the conversion: the C++ view behind the facade the game made.
OO_TEST(facadeContract)
{
	@autoreleasepool
	{
		MyOpenGLView *view = View();
		cxx::MyOpenGLView *cxxView = oo::ToCxx(view);
		OO_CHECK(cxxView != nullptr);
		OO_CHECK(oo::ToObjC(cxxView) == view);
		OO_CHECK(oo::ToObjC(static_cast<cxx::MyOpenGLView *>(nullptr)) == nil);
		OO_CHECK(oo::ToCxx(static_cast<MyOpenGLView *>(nil)) == nullptr);
		OO_CHECK(cxxView->getWindowCaption() == [view getWindowCaption]);
		OO_CHECK(cxxView->getDisplayId() == [view getDisplayId]);
		cxxView->updateGLSize(NSMakeSize(1024, 768));
		OO_CHECK([view viewSize].width == 1024 && cxxView->viewSize.height == 768);
		OO_CHECK(Near(cxxView->display_z, 640.0));
		// The matrix manager is C++; the facade's getter answers its facade.
		OO_CHECK(oo::ToCxx([view getOpenGLMatrixManager]) == cxxView->matrixManager.get());
	}
}


// Last: -dealloc quits SDL.
OO_TEST(zzDeallocReleasesTheView)
{
	@autoreleasepool
	{
		MyOpenGLView *view = View();
		[view release];
		sView = nil;
	}
}


OO_TEST_MAIN()
