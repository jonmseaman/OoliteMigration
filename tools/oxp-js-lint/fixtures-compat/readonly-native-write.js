"use strict";
this.name = "fxc-readonly-native-write";
this.shipLaunchedFromStation = function () {
  player.ship.cargoSpaceAvailable = 20;
  this.ship.isPirate = true;
  system.mainStation.isStation = false;
};
