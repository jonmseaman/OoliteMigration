"use strict";
// SECRETCOMMENT must never appear in probe output
this.name = "SecretScriptName";
this.$secretCounter = 42;

this.startUp = function (secretParam) {
	var secretLocal = new Vector3D(1, 2, 3);
	for (undeclaredLoopVar in secretParam) {
		secretLocal.add(/secretRegex/g.test("secret string"));
	}
	player.consoleMessage(`secret template`, 3.5);
};

function helperSecret(a, b) {
	"use strict";
	return a.secretMember + b;
}
