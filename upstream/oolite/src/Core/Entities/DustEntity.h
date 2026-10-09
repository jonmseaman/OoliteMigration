/*

DustEntity.h

Entity representing a number of dust particles.

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

#import "Entity.h"
#import "OOOpenGLExtensionManager.h"
#import "OOTexture.h"
#import "OOGraphicsResetManager.h"

#include "oofnd/StdLib.hpp"
#include "oofnd/objc/OOObjCRef.h"

#if OO_SHADERS
#import "OOShaderProgram.h"
#import "OOShaderUniform.h"
#endif

#define DUST_SCALE			2000
#define DUST_N_PARTICLES	600

/*	C++ only since bead oo-9ht.77 deleted its Objective-C facade (proposed ADR-0056 amendment
	oo-0mxi): the universe makes it with oo::makeRef<DustEntity>() and init(), hands it to
	Objective-C with oo::NewEntityFacade, and finds it with dynamic_cast. It is its own graphics
	reset client (cxx::OOGraphicsResetClient), and the dust shader's uniforms are bound, by
	selector, to a file-local Objective-C object in DustEntity.mm that forwards to it.
*/
class DustEntity : public cxx::Entity, public cxx::OOGraphicsResetClient
{
public:
	DustEntity() = default;
	~DustEntity() override;

	/*	-init's body after [super init] (the constructor ran Entity's), run once right after
		construction: it registers this with the graphics reset manager.
	*/
	void init();

	void setDustColor(cxx::OOColor *color);
	cxx::OOColor *dustColor();

	bool canCollide() override;
	void updateCameraRelativePosition() override;
	void update(OOTimeDelta delta_t) override;

#if OO_SHADERS
	OOShaderProgram *getShader();
	Vector offsetPlayerPosition();	// bound to the dust shader by selector, through the binding object
#endif
	Vector warpVector();			// bound to the dust shader by selector, through the binding object

	void drawImmediate(bool immediate, bool translucent) override;

	// cxx::OOGraphicsResetClient.
	void resetGraphicsState() override;

#ifndef NDEBUG
	std::optional<std::string> descriptionForObjDump() override;
#endif

private:
#if OO_SHADERS
	void checkShaderMode();
#endif

	oo::Ref<cxx::OOColor>	dust_color;
	Vector				vertices[DUST_N_PARTICLES * 2] = {};
	GLushort			indices[DUST_N_PARTICLES * 2] = {};
	GLfloat				color_fv[4] = {};
	oo::ObjCRef<::OOTexture *>	texture;
	bool				hasPointSprites = {};
	bool				drawDust = {};
	
#if OO_SHADERS
	GLfloat				warpinessAttr[DUST_N_PARTICLES * 2] = {};
	oo::Ref<OOShaderProgram>	shader;
	std::vector<oo::Ref<OOShaderUniform>>	uniforms;
	oo::ObjCRef<id>		shaderBinding;	// what the uniforms are bound to (DustEntity.mm)
	uint8_t				shaderMode = {};
#endif
};
