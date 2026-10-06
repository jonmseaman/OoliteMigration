/*

MyOpenGLView+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, bead oo-6rb6): the Objective-C MyOpenGLView facade. Every method of
slice 1 forwards to cxx::MyOpenGLView in one line; the categories of slices 2-3 and of the input
handling are in MyOpenGLView.mm and MyOpenGLView+Input.mm. See MyOpenGLView+ObjCBridge.h.

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

#import "MyOpenGLView.h"

#include "oofnd/objc/OOObjCPeer.h"


namespace {

// Never destroyed: a facade may be released while the process exits.
oo::ObjCPeers &Peers()
{
	static oo::ObjCPeers *peers = new oo::ObjCPeers;
	return *peers;
}

}	// namespace


@interface MyOpenGLView (OOObjCBridgePrivate)

- (id) initWithCxxView:(cxx::MyOpenGLView *)view;

@end


@implementation MyOpenGLView

// Inside the @implementation for the private ivar.
MyOpenGLView *oo::ToObjC(cxx::MyOpenGLView *view)
{
	return Peers().peerFor(view, [view] { return [[MyOpenGLView alloc] initWithCxxView:view]; });
}


cxx::MyOpenGLView *oo::ToCxx(MyOpenGLView *view)
{
	if (view == nil)  return nullptr;
	return view->_cxxView.get();
}


- (id) initWithCxxView:(cxx::MyOpenGLView *)view
{
	self = [super init];
	if (self != nil)  _cxxView = oo::Ref<cxx::MyOpenGLView>(view);
	return self;
}


// The C++ view is made empty and this facade becomes its peer before -init's body runs (init()),
// because that body sends the facade's display-mode and input methods (amendment oo-3bgz item 3).
- (id) init
{
	self = [super init];
	if (self == nil)  return nil;

	_cxxView = oo::makeRef<cxx::MyOpenGLView>();
	@autoreleasepool
	{
		Peers().peerFor(_cxxView.get(), [self] { return [self retain]; });
	}
	if (!_cxxView->init())
	{
		[self release];
		return nil;
	}
	return self;
}


- (void) dealloc
{
	Peers().forget(_cxxView.get());
	[super dealloc];
}


- (std::optional<std::string>) getWindowCaption
{
	return _cxxView->getWindowCaption();
}


- (void) createWindowWithSize: (NSSize) size
{
	_cxxView->createWindowWithSize(size);
}


- (void) initSplashScreen
{
	_cxxView->initSplashScreen();
}


- (void) endSplashScreen
{
	_cxxView->endSplashScreen();
}


- (void) initialiseGLWithSize:(NSSize) v_size
{
	_cxxView->initialiseGLWithSize(v_size);
}


- (void) updateGLSize:(NSSize) size
{
	_cxxView->updateGLSize(size);
}


- (void) updateScreen
{
	_cxxView->updateScreen();
}


- (SDL_DisplayID) getDisplayId
{
	return _cxxView->getDisplayId();
}


- (oo::PList) getNativeSize
{
	return _cxxView->getNativeSize();
}

@end
