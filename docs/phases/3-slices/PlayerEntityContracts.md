# Slice plan: PlayerEntityContracts

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-68lj). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/PlayerEntityContracts.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Entities/PlayerEntityContracts.mm` (2,108 lines) + header (124 lines). One
  `PlayerEntity (Contracts)` category holding three unrelated feature groups: passenger / parcel /
  cargo contracts, commander reputation plus the manifest and docking-report screens, and the
  shipyard (screen, trade-in, purchase).
- **Shape:** every method becomes a `PlayerEntity` member defined in
  `PlayerEntityContracts.cpp`. The reputation arithmetic has no Objective-C syntax left but still
  is a set of methods, so it is converted, not kept verbatim. The file-scope helpers
  (`ReputationValue`, `TextArg`, `RepForRisk`, the shipyard row helpers without message sends)
  stay verbatim ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md rule 9);
  `ShipyardLabelsRow()` sends messages, so it moves with the shipyard slice.
- **Order:** after the `ooentity` pattern seam (oo-bj8) and once the `PlayerEntity` class
  shell is C++ (frontier, oo-a70, which converts the category files through these slices). Slices only define members declared in
  the header or the preamble, so they are independent of each other.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | contracts: escape pods, passenger checks, add/remove passenger/parcel/contract, contract lists | ~720 | ~930 |
| 2 | reputation, manifest screen, docking report | ~655 | ~865 |
| 3 | shipyard: screen, info, trade-in, `buySelectedShip`, new-ship setup | ~570 | ~780 |
| verbatim | reputation dictionary / string helpers, `RepForRisk` | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Entities/PlayerEntityContracts.mm
header: upstream/oolite/src/Core/Entities/PlayerEntityContracts.h

slice 1: passenger, parcel and cargo contracts
  -[PlayerEntity cxx_processEscapePods]
  -[PlayerEntity cxx_checkPassengerContracts]
  -[PlayerEntity cxx_contractedVolumeForGood:]
  -[PlayerEntity cxx_addMessageToReport:]
  -[PlayerEntity cxx_addPassenger:*]
  -[PlayerEntity cxx_removePassenger:]
  -[PlayerEntity cxx_addParcel:*]
  -[PlayerEntity cxx_removeParcel:]
  -[PlayerEntity cxx_awardContract:*]
  -[PlayerEntity cxx_removeContract:destination:]
  -[PlayerEntity cxx_passengerList]
  -[PlayerEntity cxx_parcelList]
  -[PlayerEntity cxx_contractList]
  -[PlayerEntity cxx_contractsListFromEntries:*]

slice 2: reputation, manifest screen and docking report
  -[PlayerEntity reputation]
  -[PlayerEntity *Reputation]
  -[PlayerEntity *Reputation:]
  -[PlayerEntity setGuiToManifestScreen]
  -[PlayerEntity setManifestScreenRow:*]
  -[PlayerEntity setGuiToDockingReportScreen]

slice 3: shipyard screen, trade-in and ship purchase
  ShipyardLabelsRow()
  -[PlayerEntity cxx_priceForShipKey:]
  -[PlayerEntity setGuiToShipyardScreen:]
  -[PlayerEntity showShipyardInfoForSelection]
  -[PlayerEntity showTradeInInformationFooter]
  -[PlayerEntity cxx_showShipyardModel:*]
  -[PlayerEntity missingSubEntitiesAdjustment]
  -[PlayerEntity tradeInValue]
  -[PlayerEntity buySelectedShip]
  -[PlayerEntity cxx_replaceShipWithNamedShip:]
  -[PlayerEntity newShipCommonSetup:*]

verbatim: plain C/C++ helpers, no Objective-C (checked)
  *
```
