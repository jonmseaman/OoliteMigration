"use strict";
/* Red-proof world script: calls a method that does not exist, so the JS engine
   raises and Oolite logs a script error. Paired with a malformed
   Config/shipdata.plist so the fixture exercises BOTH a data-layer parse error
   and a script-layer error. */

this.name        = "oo-het-broken";
this.author      = "Oolite migration fleet (bead oo-het)";
this.description = "deliberately broken expansion for the load check's red proof";
this.version     = "1.0";

this.startUp = function () {
	// No such global. This throws, and the error is logged.
	ooHetThisMethodDoesNotExist(player.ship.thisPropertyDoesNotExist.either);
};
