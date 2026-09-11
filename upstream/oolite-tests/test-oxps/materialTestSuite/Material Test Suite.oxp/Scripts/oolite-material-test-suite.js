/*

oolite-material-test-suite.js

Test suite for Oolite's material model.


Oolite
Copyright © 2004-2014 Giles C Williams and contributors

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


"use strict";


this.name			= "oolite-material-test-suite";
this.version		= "1.3";
this.author			= "Jens Ayton";
this.copyright		= "© 2010-2014 the Oolite team.";


this.startUp = function()
{
	delete this.startUp;
	try
	{
		var console = debugConsole;
	}
	catch (e)
	{
		log("materialTest.error.consoleRequired", "The material test suite requires the debug console to be active.");
		return;
	}
	
	
	this.shadyTestCount = 17;
	this.nonShadyTestCount = 7;
	this.haveShaders = (debugConsole.maximumDetailLevel != "DETAIL_LEVEL_MINIMUM");
	
	this.runMaterialTestSuite = function ()
	{
		if (!player.ship.docked)
		{
			debugConsole.consoleMessage("command-error", "You must be docked to run the material test suite.");
			return;
		}
		
		// Show instruction/confirmation screen.
		var substitutions = { shady_count: this.shadyTestCount, non_shady_count: this.nonShadyTestCount };
		substitutions.count_string = expandMissionText("oolite_material_test_count_" + (this.haveShaders ? "shaders" : "no_shaders"), substitutions);
		var introText = expandMissionText("oolite_material_test_confirmation", substitutions);
		
		if (!mission.runScreen({ titleKey: "oolite_material_test_title", message: introText, choicesKey: "oolite_material_test_confirmation_choices" }, this.startTest, this))
		{
			log("materialTest.error.missionScreenFailed", "The material test suite failed to run a mission screen.");
			return;
		}
	}
	
	// Run on startup.
	this.missionScreenOpportunity = function ()
	{
		delete this.missionScreenOpportunity;
		this.runMaterialTestSuite();
	}
	
	// User-callable initiation function, if debug console is installed.
	var scriptName = this.name;
	if (debugConsole.script !== undefined)
	{
		debugConsole.script.runMaterialTestSuite = function ()
		{
			worldScripts[scriptName].runMaterialTestSuite();
		}
	}
	
	
	// Confirmation screen result callback.
	this.startTest = function (resonse)
	{
		if (resonse != "A_CONTINUE")  return;
		
		this.originalDetailLevel = debugConsole.detailLevel;
		this.originalDebugFlags = debugConsole.debugFlags;
		this.passID = 1;
		this.nextTestIndex = 1;
		this.originalHUD = player.ship.hud;
		
		this.shipWillLaunchFromStation = function ()
		{
			log("materialTest.cancelled", "Material test suite cancelled by exiting station.");
			this.performCleanUp();
		}
		
		this.maxPassID = (this.haveShaders ? 2 : 1);
		
		debugConsole.writeLogMarker();
		var startString = "Starting material test suite " + this.version +
		                  " under Oolite " + oolite.versionString +
		                  " and " + debugConsole.platformDescription +
		                  " with OpenGL renderer \"" + debugConsole.glRendererString +
		                  "\", vendor \"" + debugConsole.glVendorString +
						  "\"; shaders are " + this.haveShaders ? "supported" : "not supported";
		if (this.haveShaders)
		{
			startString += ", texture image unit count is " + debugConsole.glFragmentShaderTextureUnitCount;
		}
		startString += ".";
		
		log("materialTest.start", startString);
		
		player.ship.hud = "oolite_material_test_suite_blank_hud.plist";
		this.runNextTest();
	}
	
	
	this.performCleanUp = function ()
	{
		debugConsole.detailLevel = this.originalDetailLevel;
		debugConsole.debugFlags = this.originalDebugFlags;
		player.ship.hud = this.originalHUD;
		
		delete this.passID;
		delete this.maxPassID;
		delete this.nextTestIndex;
		delete this.originalDetailLevel;
		delete this.originalDisplayFPS;
		delete this.originalDebugFlags;
		delete this.shipWillLaunchFromStation;
		delete this.originalHUD;
	}
	
	
	this.settingsByPass =
	[
		{},
		{
			passName: "fixed-function",
			detailLevel: "DETAIL_LEVEL_MINIMUM",
			maxIndex: this.nonShadyTestCount,
			rolePrefix: "oolite_non_shader_test_suite_"
		},
		{
			passName: "shaders",
			detailLevel: "DETAIL_LEVEL_SHADERS",
			maxIndex: this.shadyTestCount,
			rolePrefix: "oolite_shader_test_suite_"
		}
	];
	
	this.runNextTest = function ()
	{
		var testIndex = this.nextTestIndex++;
		
		if (testIndex > this.settingsByPass[this.passID].maxIndex)
		{
			if (this.passID < this.maxPassID)
			{
				// Switch to next pass.
				this.passID++;
				this.nextTestIndex = 2;
				testIndex = 1;
			}
			else
			{
				// All passes have run, we're done.
				this.performCleanUp();
				
				var substitutions =
				{
					gl_vendor_string: debugConsole.glVendorString,
					gl_renderer_string: debugConsole.glRendererString,
					gl_tex_image_unit_count: debugConsole.glFragmentShaderTextureUnitCount
				};
				var message = expandMissionText("oolite_material_test_completion_" + (this.haveShaders ? "shaders" : "no_shaders"), substitutions);
				
				log("materialTest.complete", "Material test suite complete.");
				debugConsole.writeLogMarker();
				mission.runScreen({ titleKey: "oolite_material_test_title", message: message }, function () {});
				return;
			}
		}
		
		var passData = this.settingsByPass[this.passID];
		
		// Create a dummy ship to extract its script_info.
		var modelName = passData.rolePrefix + testIndex;
		var ship = system.addShips(modelName, 1, system.sun.position, 10000)[0];
		var testDesc = ship.scriptInfo["oolite_material_test_suite_label"];
		ship.remove();
		
		// Ensure environment is what we need - each time in case user tries to be clever.
		debugConsole.detailLevel = passData.detailLevel;
		debugConsole.debugFlags |= debugConsole.DEBUG_NO_SHADER_FALLBACK | debugConsole.DEBUG_SHADER_VALIDATION;
		
		// Actually run the test.
		var testLabel = passData.passName + ":" + testIndex;
		log("materialTest.runTest", "Running test " + testLabel + " (" + testDesc + ").");
		
		var config =
		{
			model: modelName,
			title: "",
			message: "\n\n" + testLabel + "\n" + testDesc,
			background: { name: "oolite_material_test_suite_backdrop.png", width: 640, height: 480 },
			overlay: null
		};
		if (!mission.runScreen(config, this.runNextTest, this))
		{
			log("materialTest.error.missionScreenFailed", "The material test suite failed to run a mission screen.");
			this.performCleanUp();
			return;
		}
	}
	
	
	log("materialTest.loaded", "Material test suite is installed.");
};
