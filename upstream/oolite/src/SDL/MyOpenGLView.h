/*

MyOpenGLView.h

Oolite
Copyright (C) 2004-2013 Giles C Williams and contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

*/

#import "OOCocoa.h"
#import "oofnd/objc/OOObject.h"
#import "OOOpenGL.h"
#import "OOMouseInteractionMode.h"
#import "OOOpenGLMatrixManager.h"
#include "oofnd/Ref.hpp"

#include "oofnd/StdLib.hpp"
#include "oofnd/PList.hpp"


#include <SDL3/SDL_video.h>
#include <string_view>

#define WINDOW_SIZE_DEFAULT_WIDTH	1280
#define WINDOW_SIZE_DEFAULT_HEIGHT	720

#define	MIN_FOV_DEG		30.0f
#define	MAX_FOV_DEG		80.0f
#define MIN_FOV			(tan((MIN_FOV_DEG / 2) * M_PI / 180.0f))
#define MAX_FOV			(tan((MAX_FOV_DEG / 2) * M_PI / 180.0f))

#define MIN_HDR_MAXBRIGHTNESS	400.0
#define MAX_HDR_MAXBRIGHTNESS	1000.0

#define MIN_HDR_PAPERWHITE		80.0f
#define MAX_HDR_PAPERWHITE		280.0f

#define MAX_COLOR_SATURATION	2.0f

#define MOUSEX_MAXIMUM 0.6
#define MOUSEY_MAXIMUM 0.6

#define MAX_CLEAR_DEPTH		10000000000.0
// 10 000 000 km.
#define INTERMEDIATE_CLEAR_DEPTH		25000.0
// 100 m.


#define NUM_KEYS			327
#define MOUSE_DOUBLE_CLICK_INTERVAL	0.40
#define OOMOUSEWHEEL_EVENTS_DELAY_INTERVAL	0.05
#define OOMOUSEWHEEL_DELTA	120 // Same as Windows WHEEL_DELTA

#define SNAPSHOTS_PNG_FORMAT		1
inline constexpr std::string_view SNAPSHOTHDR_EXTENSION_EXR	= ".exr";
inline constexpr std::string_view SNAPSHOTHDR_EXTENSION_HDR	= ".hdr";
#define SNAPSHOTHDR_EXTENSION_DEFAULT	SNAPSHOTHDR_EXTENSION_EXR

@class Entity, GameController, OpenGLSprite;

enum GameViewKeys
{
	gvFunctionKey1 = 256,
	gvFunctionKey2,
	gvFunctionKey3,
	gvFunctionKey4,
	gvFunctionKey5, // 260
	gvFunctionKey6,
	gvFunctionKey7,
	gvFunctionKey8,
	gvFunctionKey9,
	gvFunctionKey10,
	gvFunctionKey11,
	gvArrowKeyRight,
	gvArrowKeyLeft,
	gvArrowKeyDown,
	gvArrowKeyUp, // 270
	gvPauseKey,
	gvPrintScreenKey, // 272
	gvMouseLeftButton = 301,
	gvMouseDoubleClick,
	gvHomeKey,
	gvEndKey,
	gvInsertKey,
	gvDeleteKey,
	gvPageUpKey,
	gvPageDownKey, // 308
	gvBackspaceKey, // 309
	gvNumberKey0 = 48,
	gvNumberKey1,
	gvNumberKey2,
	gvNumberKey3,
	gvNumberKey4,
	gvNumberKey5,
	gvNumberKey6,
	gvNumberKey7,
	gvNumberKey8,
	gvNumberKey9, //57
	gvNumberPadKey0 = 310,
	gvNumberPadKey1,
	gvNumberPadKey2,
	gvNumberPadKey3,
	gvNumberPadKey4,
	gvNumberPadKey5,
	gvNumberPadKey6,
	gvNumberPadKey7,
	gvNumberPadKey8,
	gvNumberPadKey9,
	gvNumberPadKeyDivide, // 320
	gvNumberPadKeyMultiply,
	gvNumberPadKeyMinus,
	gvNumberPadKeyPlus,
	gvNumberPadKeyPeriod,
	gvNumberPadKeyEquals,
	gvNumberPadKeyEnter // 326
};

enum MouseWheelStatus
{
	gvMouseWheelDown = -1,
	gvMouseWheelNeutral,
	gvMouseWheelUp
};

enum StringInput
{
	gvStringInputNo = 0,
	gvStringInputAlpha = 1,
	gvStringInputLoadSave = 2,
	gvStringInputAll = 3
};

enum KeyboardType
{
	gvKeyboardAuto,
	gvKeyboardUS,
	gvKeyboardUK
};

typedef enum
{
	OOHDR_TONEMAPPER_NONE = -1,
	OOHDR_TONEMAPPER_ACES_APPROX = 0,
	OOHDR_TONEMAPPER_DICE,
	OOHDR_TONEMAPPER_UCHIMURA,
	OOHDR_TONEMAPPER_REINHARD
} OOHDRToneMapper;

typedef enum
{
	OOSDR_TONEMAPPER_NONE = -1,
	OOSDR_TONEMAPPER_ACES = 0,
	OOSDR_TONEMAPPER_AgX,
	OOSDR_TONEMAPPER_HEJLDAWSON,
	OOSDR_TONEMAPPER_UC2,
	OOSDR_TONEMAPPER_UCHIMURA,
	OOSDR_TONEMAPPER_REINHARD
} OOSDRToneMapper;

extern int debug;

namespace cxx {

class MyOpenGLView : public oo::RefCounted
{
public:
	MyOpenGLView() = default;	// the object -init fills; see init()
	~MyOpenGLView() override;

	/**
	 * \ingroup cli
	 * Scans the command line for -nosplash, --nosplash, -splash, --splash- -novsync and --novsync arguments.
	 */
	// -init's body, run by the facade's -init once it is the object's peer (ADR-0056 amendment
	// oo-3bgz item 3): it sends the facade's input and display-mode methods. false where -init
	// answered nil (SDL could not start).
	bool init();
	std::optional<std::string> getWindowCaption();
	void createWindowWithSize(NSSize size);
	void initSplashScreen();
	void endSplashScreen();
	void initialiseGLWithSize(NSSize v_size);
	void updateGLSize(NSSize size);
	void updateScreen();
	SDL_DisplayID getDisplayId();
	oo::PList getNativeSize();

	/*	Internal: the view's state. The methods of slices 2 and 3 of docs/phases/3-slices/MyOpenGLView.md
		(accessors, display modes, settings, HDR, snapshots) and the Input category
		(MyOpenGLView+Input.mm), still Objective-C categories of the facade, read and write it through
		oo::ToCxx(self) (ADR-0056 amendment oo-3bgz); it becomes private when they convert.
	*/
	::GameController		*gameController = {};	// not retained
	bool				keys[NUM_KEYS] = {};
	int					scancode2Unicode[NUM_KEYS] = {};
	oo::PList			keyMappings_normal;		// the keyboard's mapping_normal / mapping_shifted (null if none)
	oo::PList			keyMappings_shifted;
	bool				suppressKeys = {};    // DJS
	bool				opt = {}, ctrl = {}, command = {}, shift = {}, lastKeyShifted = {};
	enum StringInput	allowingStringInput = {};
	bool				isAlphabetKeyDown = {};

	int					keycodetrans[255] = {};

	NSPoint				mouseDragStartPoint = {};
	bool				mouseWarped = {};

	NSTimeInterval		timeIntervalAtLastClick = {};
	NSTimeInterval		timeSinceLastMouseWheel = {};
	bool				doubleClick = {};

	std::string			typedString;	// UTF-8; empty, never nil

	NSPoint				virtualJoystickPosition = {};
	float				_mouseVirtualStickSensitivityFactor = {};

	NSSize				viewSize = {};
	GLfloat				display_z = {};
	GLfloat				x_offset = {}, y_offset = {};

	double				squareX = {}, squareY = {};
	NSRect				bounds = {};

	float				_fov = {};
	bool				_msaa = {};

	// Full screen sizes
	std::vector<oo::PList>	screenSizes;	// mode Dicts: Width, Height (integers), RefreshRate (a single real; the native mode's an integer 0)
	int					currentSize = {};	//we need an int!
	bool				fullScreen = {};

	// Windowed mode
	NSSize				currentWindowSize = {};

	bool				showSplashScreen = {};
	SDL_Window			*splashWindow = {};
	SDL_Window			*window = {};
	SDL_GLContext			glContext = {};
	int				bitsPerColorComponent = {};

	bool				vSyncPreference = {};

#if OOLITE_WINDOWS

	bool				saveSize = {};
	bool				atDesktopResolution = {};
	unsigned			keyboardMap = {}; // *** FLAGGED for deletion
	HWND 				windowHandle = {};
	RECT				lastGoodRect = {};
	float				_hdrMaxBrightness = {};
	float				_hdrPaperWhiteBrightness = {};
	int					_hdrToneMapper = {};

#endif

	int					_sdrToneMapper = {};
	float				_colorSaturation = {};

	bool				_hdrOutput = {};

	bool				grabMouseStatus = {};

	NSSize				firstScreen = {};

	oo::Ref<cxx::OOOpenGLMatrixManager>	matrixManager;	// C++ since bead oo-vt0o

	// Mouse mode indicator (for mouse movement model)
	bool				mouseInDeltaMode = {};
	float				_mouseWheelDelta = {};

private:
	void setUpBasicOpenGLStateWithSize();
};

}	// namespace cxx


// Transitional: the Objective-C MyOpenGLView, for the game controller, the universe, the player and
// the many callers of [UNIVERSE gameView], and for the methods of this file's slices 2-3 and the
// Input category, which are not yet converted. Deleted, with namespace cxx above, by the bridge's
// deletion bead.
#import "MyOpenGLView+ObjCBridge.h"

#include <SDL3/SDL_events.h>
#import "MyOpenGLView+Input.h"
