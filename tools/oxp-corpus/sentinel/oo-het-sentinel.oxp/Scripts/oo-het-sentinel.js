"use strict";
/* oo-het load-check sentinel: the witness that makes "no ERROR lines" mean something.

   WHY THIS EXISTS: a per-expansion load check cannot conclude anything from
   "rc=0 and no ERROR lines".  On this shared fleet machine a bare game DIALS
   OUT to the default debug-console port 8563 and can land in a SIBLING
   worker's component-test listener, which runs quit().  The run then ends
   early, at a moment nobody chose, with rc=0 and a clean log.  Observed live
   during this bead:

       [debugTCP.connected]: Connected to debug console "OoliteComponentTests"
       ... 4.7s later ...
       [debugConsole.automation]: Triggering global quitGame bridge...
       [universe.quit]: Quit command received by Universe.

   Two defences, and both are needed.  Config/debugConfig.plist in this OXP
   steers the dial-out to a dead port so nobody can reach in.  This script then
   emits a marker THIS RUN CAUSED and quits deliberately, so the run has a
   defined end that the checker can require.

   WHY THE QUIT IS DEFERRED BY A TIMER, which is the whole subtlety here.
   startUpComplete fires BEFORE Universe logs [startup.complete]; an earlier
   version of this script called quitGame() straight from the handler and the
   resulting logs had no loading-complete line at all - the sentinel was
   destroying the very progress evidence the checker wanted to assert on.  A
   short one-shot Timer lets the startup path finish and log
   [startup.complete], and only then do we sign off.  The checker therefore
   gets BOTH: an independent boot-completed marker from the game, and an
   end-of-run marker that only this run could have produced.

   The marker literal is assembled from two halves at runtime so this source
   file does not itself contain the string the checker greps for: a checker
   that matched its own staged script text would be self-satisfying.  */

this.name        = "oo-het-sentinel";
this.author      = "Oolite migration fleet (bead oo-het)";
this.description = "end-of-run witness for the OXP tier-1 load check";
this.version     = "1.0";

this._signOff = function () {
	var head = "OO-HET-";
	var tail = "SENTINEL-OK";
	log("oo-het.sentinel", head + tail);
	// Quit under OUR control so the run has a defined end. A run ended by
	// anything else never reaches this line.
	quitGame();
};

this.startUpComplete = function () {
	// Deferred on purpose - see the header. 2s is comfortably past the point
	// where Universe logs [startup.complete] on this build (~0.1s after this
	// handler) without adding meaningfully to a ~30s per-expansion check.
	this._timer = new Timer(this, this._signOff, 2.0);
};
