# Phase 2: selector-family flip plan (bead oo-virp)

Proposed ADR-0043 item 21 keeps a selector that more than one class or protocol declares (a *family*), or that the game sends by name, typed `id` in the sweep bead of each member. Each family must then change to C++ types in ONE bead that edits every declaration and caller, before oo-qps removes gnustep-base and the bridges. This note is the plan; the beads it lists are filed as children of oo-3rb, labelled `sweep:selector-family`, each depending on its members' sweep beads and blocking oo-qps.

## How the families were found

`tools/check-selector-types.py`'s own parser (`scan`, `dynamic_selectors`) over `upstream/oolite/src` on phase-2 at the time of filing: every selector declared by two or more `@interface` / `@implementation` / `@protocol` containers (a class, its categories and its .mm count once) where some declaration has a Foundation value type (NSString, NSArray, NSDictionary, NSSet, NSNumber, NSData, NSMutable*, NSEnumerator, NSError, NSURL) or carries the sweep's `// shared selector` / `// called by name` marker. 108 families. Call-site files are a grep for the selector's first keyword in a message send, so a bead's file list is an estimate to check at pickup.

## Beads

| Bead | Family | Selectors | Files | After |
|---|---|---|---|---|
| oo-3rb.258 | PlayerEntity/ShipEntity equipment selectors | `-addEquipmentItem:inContext:` `-addEquipmentItem:withValidation:inContext:` `-canAddEquipment:inContext:` `-removeEquipmentItem:` `-setWeaponMount:toWeapon:` | 4 | oo-3rb.242, oo-3rb.257 |
| oo-3rb.259 | PlayerEntity/ShipEntity manifest and comms selectors | `-cargoListForScripting` `-contractListForScripting` `-missilesList` `-parcelListForScripting` `-passengerListForScripting` `-receiveCommsMessage:from:` `-setBounty:withReasonAsString:` | 3 | oo-3rb.242, oo-3rb.257 |
| oo-3rb.260 | beacon selectors | `-beaconCode` `-beaconLabel` `-setBeaconCode:` `-setBeaconLabel:` | 4 | oo-2qdy, oo-3rb.242 |
| oo-3rb.261 | subentity and flasher selectors | `-subEntities` `-subEntitiesForScript` `-subEntityEnumerator` `-flasherEnumerator` `-setUpOneFlasher:` `-setUpOneSubentity:` | 8 | oo-3rb.242, oo-8aic |
| oo-3rb.262 | DockEntity/StationEntity launch-queue and docking selectors | `-countOfShipsInLaunchQueueWithPrimaryRole:` `-dockingInstructionsForShip:` | 4 | oo-3rb.175, oo-e7ab, oo-u7fq |
| oo-3rb.263 | debug monitor, debugger and JS-engine-monitor protocol selectors | `-connectDebugMonitor:errorMessage:` `-debugMonitor:jsConsoleOutput:colorKey:emphasisRange:` `-debugMonitor:noteChangedConfigrationValue:forKey:` `-debugMonitor:noteConfiguration:` `-disconnectDebugMonitor:message:` `-disconnectDebugger:message:` `-jsEngine:context:error:stackSkip:showingLocation:withMessage:` `-jsEngine:context:logMessage:ofClass:` `-performJSConsoleCommand:` `-setConfigurationValue:forKey:` `-sourceCodeForFile:line:` `-configurationValueForKey:` | 7 | oo-3rb.135, oo-3rb.149, oo-3rb.203, oo-hnqb, oo-prwr, oo-rbqc |
| oo-3rb.264 | OOCache/OOPriorityQueue GraphViz selectors | `-generateGraphViz` `-writeGraphVizToPath:` `-writeGraphVizToURL:` | 2 | oo-ndqg |
| oo-3rb.265 | OOProbabilitySet property-list selectors | `-initWithPropertyListRepresentation:` `-propertyListRepresentation` | 3 | oo-gkib |
| oo-3rb.266 | OOScript -scriptDescription | `-scriptDescription` | 4 | members swept |
| oo-3rb.267 | -displayName (OOScript, ShipEntity) | `-displayName` | 8 | oo-3rb.242 |
| oo-3rb.268 | -runCallback: (JS GUI key, interface and populator definitions) | `-runCallback:` | 6 | exempt (below) |
| oo-3rb.269 | planet texture generator and planet entity selectors | `+planetTextureWithInfo:seed:` `-initWithPlanetInfo:seed:` `-setUpPlanetFromTexture:` `-textureFileName` | 9 (split) | members swept |
| oo-3rb.270 | texture and generator -cacheKey | `-cacheKey` | 11 (split) | oo-7xnb, oo-japz |
| oo-3rb.271 | debug-only -allTextures | `-allTextures` | 17 (split) | oo-2qdy, oo-3kai, oo-3rb.106, oo-3rb.130, oo-5d4v |
| oo-3rb.272 | commodity selectors | `-getRandomCommodity` `-goods` `-massUnitForGood:` | 9 (split) | oo-19d2, oo-3rb.155, oo-3rb.231 |
| oo-3rb.273 | display-mode selectors | `-displayModes` `-findDisplayModeForWidth:Height:Refresh:` | 7 | oo-2bn9, oo-3rb.91, oo-drw6, oo-m6ej |
| oo-3rb.274 | OXP verifier stage dependency selectors | `-dependents` `+nameForReverseDependencyForVerifier:` | 11 (split) | oo-v1zb |
| oo-3rb.275 | OOPListSchemaVerifier delegate callbacks | `-verifier:withPropertyList:named:failedForProperty:withError:expectedType:` `-verifier:withPropertyList:named:testProperty:atPath:againstType:error:` | 2 | oo-3rb.142, oo-v1zb, oo-vvxy |
| oo-3rb.276 | -message: (AI, OOCheckShipDataPListVerifierStage) | `-message:` | 8 | oo-v1zb |
| oo-3rb.277 | -collisionDescription (CollisionRegion, Universe) | `-collisionDescription` | 4 | oo-3rb.231 |
| oo-3rb.278 | -descriptionForObjDump | `-descriptionForObjDump` | 6 | oo-2qdy, oo-3rb.242 |
| oo-3rb.279 | -identFromShip: (ShipEntity, WormholeEntity) | `-identFromShip:` | 5 | oo-3rb.242, oo-ys2e |
| oo-3rb.280 | -hasRole: (OORoleSet, ShipEntity) | `-hasRole:` | 4 | oo-3rb.242 |
| oo-3rb.281 | -takeEnergyDamage:from:becauseOf:weaponIdentifier: | `-takeEnergyDamage:from:becauseOf:weaponIdentifier:` | 6 | oo-2qdy, oo-3rb.175, oo-3rb.242, oo-3rb.257, oo-e7ab, oo-u7fq |
| oo-3rb.282 | -setUpShipFromDictionary: | `-setUpShipFromDictionary:` | 5 | oo-3rb.175, oo-3rb.242, oo-3rb.257, oo-e7ab, oo-u7fq |
| oo-3rb.283 | -initWithKey:definition: | `-initWithKey:definition:` | 10 (split) | oo-3rb.175, oo-3rb.242, oo-e7ab, oo-u7fq |
| oo-3rb.284 | -scriptInfo | `-scriptInfo` | 6 | oo-3rb.159, oo-3rb.242, oo-fvnu |
| oo-3rb.285 | -nameOfJoystick: | `-nameOfJoystick:` | 4 | members swept |
| oo-3rb.286 | -initWithCustomSoundKey: | `-initWithCustomSoundKey:` | 3 | oo-3rb.231 |
| oo-3rb.287 | -pendingMessages (AI, OOPreservedAIStateMachine) | `-pendingMessages` | 2 | members swept |
| oo-3rb.288 | JS description glue: -oo_jsClassName, -oo_jsDescription, -oo_jsDescriptionWithClassName: | `-oo_jsClassName` `-oo_jsDescription` `-oo_jsDescriptionWithClassName:` | 29 (split) | oo-3rb.203, oo-8aic, oo-ld2b, oo-rbqc |
| oo-3rb.289 | Foundation-shared -name / -setName: / -initWithName: | `-name` `-setName:` `-initWithName:` | 67 (split) | oo-3rb.159, oo-3rb.242, oo-3rb.257, oo-5l4w, oo-fvnu, oo-japz, oo-ld2b, oo-v1zb |
| oo-3rb.290 | Foundation-shared -title / -setTitle: (GuiDisplayGen, OOJSInterfaceDefinition) | `-title` `-setTitle:` | 4 | oo-ol63 |
| oo-3rb.291 | Foundation-shared -version / -state / -function / -dependencies | `-version` `-state` `-function` `-dependencies` | 16 (split) | members swept |
| oo-3rb.292 | Foundation-shared initializers -initWithDictionary: / -initWithPath: / -initWithContentsOfFile: | `-initWithDictionary:` `-initWithPath:` `-initWithContentsOfFile:` | 23 (split) | oo-3rb.213, oo-uccu |
| oo-3rb.293 | Foundation-shared -allObjects / -objectEnumerator (probability set, priority queue) | `-allObjects` `-objectEnumerator` | 19 (split) | oo-21kc, oo-5l4w, oo-gkib, oo-ig84, oo-ndqg |

A bead marked *(split)* is over the 8-file story rule; its description says how to split it at pickup. Families that Foundation also declares (`-name`, `-title`, `-version`, ...) cannot give the selector itself C++ types while gnustep-base is linked, because an `id` receiver may be a Foundation object: those beads add `cxx_` twins per member, move the callers whose receiver has the member's static type, and leave the `id` selector to retire with oo-qps.

## Not planned as flips

- -runCallback: stays `id` (oo-3rb.268, orchestrator decision): the family is heterogeneous. The JS GUI-key and interface definitions take a string key, but OOJSPopulatorDefinition takes an HPVector location, so no single C++ type fits the family and a flip of the string members alone is a collision for tools/check-selector-types.py --check. `id` is not a Foundation type, so oo-qps is unaffected; Phase 3 converts the classes. Renaming the populator selector was rejected (a new interface).

- **Called by name (stay id while dispatched by name: legacy-script/AI dispatcher, ADR-0043 item 21)**: `-commsMessage:`, `-commsMessageByUnpiloted:`, `-interpretAIMessage:`, `-playSound:`, `-setLegalStatus:`, `-setMissionMusic:`, `-spawnShip:`
- **Root-class description selectors (with the %@/description retirement, oo-qpb follow-up)**: `-description`, `-descriptionComponents`, `-shortDescription`, `-shortDescriptionComponents`
- **Categories on Foundation classes only (retire with gnustep-base, oo-qps)**: `-oo_arrayForKey:defaultValue:`, `-oo_dataForKey:defaultValue:`, `-oo_dictionaryForKey:defaultValue:`, `-oo_doubleForKey:`, `-oo_setForKey:`, `-oo_setForKey:defaultValue:`, `-oo_stringForKey:defaultValue:`
- **Foundation-class categories plus OO twins (retire with oo-qps; the OO twins go with OODeepCopy / the plist writer)**: `-oldSchoolPListFormatWithIndentation:errorDescription:`, `-ooDeepCopyWithSharedObjects:`

## Acceptance of each family bead

`python3 tools/check-selector-types.py --check`; a grep that no declaration of the family's selectors still names a bare `id` or a Foundation value type (for a Foundation-shared family: that each member header declares the `cxx_` twin); `tools/build-windows.sh test`; `bash tools/guardrails.sh`. Goldens (2 blessed verified) as for every sweep bead.
