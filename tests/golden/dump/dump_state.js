/* oo-gla: canonical world-state dump, installed on debugConsole.
 *
 * debugConsole is a writable JS global the console client already uses as scratch state
 * (upstream/oolite/tests/component/steps/world_steps.py:135, OODebugMonitor.m:761). Installing
 * the dump there makes it a debug-console JS command: "debugConsole.dumpWorldState()" from any
 * console.evaluate() call, same idiom as everything else this tier already does.
 *
 * CANONICAL means two things, both required for byte-identical goldens (decision 11):
 *   1. Every object's keys are sorted (canon() below) - a plain JS/JSON.stringify object walks
 *      keys in creation order, and any of them here that came from an Objective-C NSDictionary
 *      (localMarketForScripting) has creation order that is a hash-iteration artifact, not a
 *      contract. Sorting keys explicitly removes that as a source of divergence.
 *   2. Every array is in a STABLE order chosen by us, not the iteration order of system.allShips
 *      (which walks Universe's sortedEntities - draw order, not identity order, and is exactly
 *      the class of bug docs/fleet/LEARNINGS.md and bead oo-djn are about). Ships are sorted by
 *      shipUniqueName, which the SPAWNING SCRIPT sets deterministically (spawn order, zero-padded
 *      so lexicographic sort == spawn order) - see tests/golden/dump/state_dump.py:_SPAWN_JS.
 *
 * Floats are quantised per decision 11 (docs/decisions/0013-decide-up-front-minimise-human.md
 * item 11: "per-platform blessed goldens AND float quantisation in the dump"). Quantisation is
 * textual, not a second float op: q() rounds through toFixed() to a fixed number of decimal
 * digits and reads the result back as a Number, so the JSON text is the same for any two binary
 * doubles that agree to that many decimal places - which is what absorbs FMA/libm/platform noise
 * without a per-platform golden. See tests/golden/dump/README.md for the epsilon proof.
 */
(function () {
  // QUANTISATION PRECISION (decision 11). 3 decimals = 1 mm on positions, 1 mm/s on
  // velocities. See tests/golden/GOLDEN_STORAGE.md for the measurement this rests on.
  //
  // debugConsole.dumpQuantDecimals is an OVERRIDE, not a second policy: it exists so the
  // storage policy can be measured rather than asserted (dump at 15 decimals, diff two runs,
  // observe the actual spread). The stored goldens are always produced at the default, and
  // tests/golden/golden_diff.py REFUSES to compare anything whose provenance records a
  // coarser value - so nobody can turn a failing golden green by rounding harder.
  var QUANT_DECIMALS = 3;
  if (typeof debugConsole.dumpQuantDecimals === "number") {
    QUANT_DECIMALS = debugConsole.dumpQuantDecimals;
  }

  function q(x) {
    return Number(Number(x).toFixed(QUANT_DECIMALS));
  }

  function vec(v) {
    return [q(v.x), q(v.y), q(v.z)];
  }

  function cmp(a, b) {
    return a < b ? -1 : (a > b ? 1 : 0);
  }

  function canon(o) {
    if (o === null || typeof o !== "object") return o;
    if (Array.isArray(o)) return o.map(canon);
    var keys = Object.keys(o).sort();
    var out = {};
    for (var i = 0; i < keys.length; i++) out[keys[i]] = canon(o[keys[i]]);
    return out;
  }

  function shipRecord(s) {
    return {
      id: s.shipUniqueName || s.name,
      role: s.primaryRole || "",
      position: vec(s.position),
      velocity: vec(s.velocity),
      aiState: s.AIState || "",
      isPlayer: !!s.isPlayer
    };
  }

  var ents = [];
  var ships = system.allShips;
  for (var i = 0; i < ships.length; i++) {
    if (!ships[i].isPlayer) ents.push(shipRecord(ships[i]));
  }
  // Explicit stable sort key, not allShips order - see the module docstring above.
  // MEASURED, not assumed: deleting this line still produces three byte-identical dumps under the
  // repeat-run gate (same spawn sequence on the same build yields the same allShips order every
  // time), but it DOES change the dump versus the sorted baseline. The guard that actually
  // discriminates it is tests/golden/dump/run_order_proof.sh, which spawns the same ships in the
  // opposite order; do not remove this sort on the strength of the three-run diff staying green.
  ents.sort(function (a, b) { return cmp(a.id, b.id); });

  var marketObj = {};
  var station = system.mainStation;
  if (station) {
    var m = station.market;
    var keys = Object.keys(m).sort();
    for (var k = 0; k < keys.length; k++) {
      var key = keys[k];
      var g = m[key];
      marketObj[key] = {
        price: q(g.price),
        quantity: q(g.quantity),
        capacity: ("capacity" in g) ? q(g.capacity) : null
      };
    }
  }

  var cargo = [];
  var manifest = player.ship.manifest.list;
  for (var c = 0; c < manifest.length; c++) {
    cargo.push({
      commodity: manifest[c].commodity,
      quantity: manifest[c].quantity,
      containers: manifest[c].containers
    });
  }
  cargo.sort(function (a, b) { return cmp(a.commodity, b.commodity); });

  var dump = {
    entities: ents,
    market: marketObj,
    player: {
      credits: q(player.credits),
      legalStatus: player.legalStatus,
      score: player.score,
      cargo: cargo,
      ship: {
        position: vec(player.ship.position),
        velocity: vec(player.ship.velocity),
        aiState: player.ship.AIState || "",
        docked: !!player.ship.docked
      }
    }
  };

  return JSON.stringify(canon(dump));
})()
