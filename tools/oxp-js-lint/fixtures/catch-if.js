"use strict";
// FIXTURE: conditional catch clause (SpiderMonkey "catch (e if cond)").
// MUST be flagged by rule: catch-if
this.startUp = function () {
    try {
        player.ship.awardEquipment("EQ_FUEL_SCOOPS");
    } catch (e if e instanceof TypeError) {
        log("fixture", "type error: " + e);
    } catch (e) {
        log("fixture", "other: " + e);
    }
};
