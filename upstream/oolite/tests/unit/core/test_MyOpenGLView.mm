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

	MyOpenGLView.mm reaches the game controller, the universe and the player, so the test links
	every game object but main's (tests/unit/core/meson.build entry ['*'], ADR-0056 amendment
	oo-44gg) and defines gDebugFlags.
	Run: bash tools/check-core-tests.sh test_MyOpenGLView
*/

#import "MyOpenGLView.h"
#import "OOOpenGLMatrixManager.h"
#import "OOFullScreenController.h"

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
