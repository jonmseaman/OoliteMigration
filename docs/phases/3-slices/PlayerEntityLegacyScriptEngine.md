# Slice plan: PlayerEntityLegacyScriptEngine

Pre-split for [Phase 3](../3-cpp-conversion.md) (bead oo-hqj4). Checked by
`python3 tools/check-slice-plan.py docs/phases/3-slices/PlayerEntityLegacyScriptEngine.md`, which
recounts the file every time, so the numbers below are only a snapshot.

- **File:** `Core/Entities/PlayerEntityLegacyScriptEngine.mm` (3,039 lines) + header (280 lines).
  One category, `PlayerEntity (Scripting)`: the legacy plist script interpreter (conditions,
  actions, mission variables), ~50 `*_number` / `*_string` / `*_bool` query methods and ~60
  action methods that plist scripts call by name (ADR-0043 item 21), the mission screen, and the
  scene / equipment-script helpers. About twenty small file-scope helpers sit inside the
  `@implementation`.
- **Shape:** the file is already ordered by feature, so it is cut in four at feature boundaries.
  Slice 2 takes the category by `@block` (every method not named elsewhere); slices 1, 3 and 4
  name their methods. The helpers without Objective-C are named in the verbatim group (a name
  beats a `@block`) and stay verbatim ([ADR-0012](../../decisions/0012-c-stays-c.md), CLAUDE.md
  rule 9); `MissionTextForKey()`, `PerformActionStatment()` and `TestScriptConditions()` send
  messages and go with the interpreter in slice 1. Faithful port of the legacy scripting
  (open decision 6).
- **Order:** after the `ooentity` pattern seam (oo-bj8) and once the `PlayerEntity` class shell is
  C++ (frontier, oo-a70). The slices only define `PlayerEntity` members declared in the header,
  so they are independent; slice 1 first is the natural order, since the others' called-by-name
  actions run through its interpreter.

| Slice | Content | Own lines | Reads (header + preamble + own) |
|---|---|---:|---:|
| 1 | interpreter: `checkScript`, run actions, test conditions, `scriptTestCondition:`; mission and local variables; missions list; mission descriptions and instructions | ~700 | ~1,135 |
| 2 | query methods (`*_number`, `*_string`, `*_bool`); messages; awards, equipment, planet info, cargo, fuel; ship AIs; `addShips*` | ~725 | ~1,160 |
| 3 | `spawnShip:`; mission-variable arithmetic (`set:`, `increment:`, …); mission text, choices, destinations, title / image / background; fuel leak, nova, station launch / blow-up, `sendAllShipsAway` | ~610 | ~1,045 |
| 4 | `addPlanet:` / `addMoon:`, debug, sounds, the mission screen and callback, scenes, equipment scripts, target helpers, galactic hyperspace behaviour | ~680 | ~1,115 |
| verbatim | helpers with no Objective-C | — | not read |

```slice-plan
source: upstream/oolite/src/Core/Entities/PlayerEntityLegacyScriptEngine.mm
header: upstream/oolite/src/Core/Entities/PlayerEntityLegacyScriptEngine.h

slice 1: interpreter, mission variables, missions list and descriptions
  MissionTextForKey()
  PerformActionStatment()
  TestScriptConditions()
  -[PlayerEntity setScriptTarget:]
  -[PlayerEntity scriptTarget]
  -[PlayerEntity worldScriptsRequiringTickle]
  -[PlayerEntity checkScript]
  -[PlayerEntity cxx_runScriptActions:withContextName:forTarget:]
  -[PlayerEntity cxx_runUnsanitizedScriptActions:allowingAIMethods:withContextName:forTarget:]
  -[PlayerEntity cxx_scriptTestConditions:]
  -[PlayerEntity scriptTestCondition:]
  -[PlayerEntity expandScriptRightHandSide:]
  -[PlayerEntity cxx_missionVariables]
  -[PlayerEntity cxx_missionVariableForKey:]
  -[PlayerEntity cxx_setMissionVariable:forKey:]
  -[PlayerEntity localVariablesForMission:]
  -[PlayerEntity localVariableForKey:andMission:]
  -[PlayerEntity setLocalVariable:forKey:andMission:]
  -[PlayerEntity cxx_missionsList]
  -[PlayerEntity replaceVariablesInString:]
  -[PlayerEntity setMissionDescription:]
  -[PlayerEntity setMissionDescription:forMission:]
  -[PlayerEntity cxx_setMissionInstructions:forMission:]
  -[PlayerEntity cxx_setMissionInstructionsList:forMission:]
  -[PlayerEntity clearMissionDescription]
  -[PlayerEntity clearMissionDescriptionForMission:]

slice 2: query methods, messages, awards, cargo and ship adding
  @PlayerEntity(Scripting)

slice 3: variable arithmetic, mission text and choices, system events
  -[PlayerEntity spawnShip:]
  -[PlayerEntity set:]
  -[PlayerEntity reset:]
  -[PlayerEntity increment:]
  -[PlayerEntity decrement:]
  -[PlayerEntity add:]
  -[PlayerEntity subtract:]
  -[PlayerEntity checkForShips:]
  -[PlayerEntity resetScriptTimer]
  -[PlayerEntity addMissionText:]
  -[PlayerEntity addLiteralMissionText:]
  -[PlayerEntity setMissionChoiceByTextEntry:]
  -[PlayerEntity setMissionChoices:]
  -[PlayerEntity cxx_setMissionChoicesDictionary:]
  -[PlayerEntity resetMissionChoice]
  -[PlayerEntity clearMissionScreen]
  -[PlayerEntity addMissionDestination:]
  -[PlayerEntity removeMissionDestination:]
  -[PlayerEntity showShipModel:]
  -[PlayerEntity setMissionMusic:]
  -[PlayerEntity cxx_missionTitle]
  -[PlayerEntity cxx_setMissionTitle:]
  -[PlayerEntity setMissionImage:]
  -[PlayerEntity setMissionBackground:]
  -[PlayerEntity setFuelLeak:]
  -[PlayerEntity fuelLeakRate_number]
  -[PlayerEntity setSunNovaIn:]
  -[PlayerEntity launchFromStation]
  -[PlayerEntity blowUpStation]
  -[PlayerEntity sendAllShipsAway]

slice 4: planets, the mission screen, scenes, equipment scripts, galactic hyperspace
  -[PlayerEntity addPlanet:]
  -[PlayerEntity addMoon:]
  -[PlayerEntity debugOn]
  -[PlayerEntity debugOff]
  -[PlayerEntity debugMessage:]
  -[PlayerEntity playSound:]
  -[PlayerEntity doMissionCallback]
  -[PlayerEntity clearMissionScreenID]
  -[PlayerEntity cxx_setMissionScreenID:]
  -[PlayerEntity cxx_missionScreenID]
  -[PlayerEntity endMissionScreenAndNoteOpportunity]
  -[PlayerEntity setGuiToMissionScreen]
  -[PlayerEntity refreshMissionScreenTextEntry]
  -[PlayerEntity setGuiToMissionScreenWithCallback:]
  -[PlayerEntity cxx_setBackgroundFromDescriptionsKey:]
  -[PlayerEntity addScene:atOffset:]
  -[PlayerEntity processSceneDictionary:atOffset:]
  -[PlayerEntity processSceneString:atOffset:]
  -[PlayerEntity cxx_addEqScriptForKey:]
  -[PlayerEntity cxx_removeEqScriptForKey:]
  -[PlayerEntity cxx_eqScriptIndexForKey:]
  -[PlayerEntity targetNearestHostile]
  -[PlayerEntity targetNearestIncomingMissile]
  -[PlayerEntity setGalacticHyperspaceBehaviourTo:]
  -[PlayerEntity setGalacticHyperspaceFixedCoordsTo:]

verbatim: plain C/C++ helpers, no Objective-C (checked)
  CurrentScriptNameOr()
  CurrentScriptDescription()
  ElementAt()
  IsWhitespaceNotNewline()
  StringAtIndex()
  IsNoneValue()
  TokenArray()
  JoinedFrom()
  TrimWhitespace()
  ConditionString()
  QueryDoubleValue()
  PerformScriptActions()
  PerformConditionalStatment()
  RecursiveRemapStatus()
  cxx_OOComparisonTypeToString()
  *
```
