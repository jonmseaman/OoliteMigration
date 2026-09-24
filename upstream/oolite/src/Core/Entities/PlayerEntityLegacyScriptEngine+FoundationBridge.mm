/*

PlayerEntityLegacyScriptEngine+FoundationBridge.mm

TRANSITIONAL: see PlayerEntityLegacyScriptEngine+FoundationBridge.h. Each method forwards to its
cxx_ counterpart and converts the result exactly as the old method produced it (nil for nil).

*/

#import "PlayerEntityLegacyScriptEngine.h"	// declares the bridge category at its end
#import "OOFoundationBridge.h"


@implementation PlayerEntity (ScriptingFoundationBridge)

- (void) runScriptActions:(NSArray *)sanitizedActions withContextName:(NSString *)contextName forTarget:(ShipEntity *)target
{
	[self cxx_runScriptActions:oo::PListFrom(sanitizedActions) withContextName:oo::OptionalString(contextName) forTarget:target];
}


- (void) runUnsanitizedScriptActions:(NSArray *)unsanitizedActions allowingAIMethods:(BOOL)allowAIMethods withContextName:(NSString *)contextName forTarget:(ShipEntity *)target
{
	[self cxx_runUnsanitizedScriptActions:oo::PListFrom(unsanitizedActions) allowingAIMethods:allowAIMethods withContextName:oo::OptionalString(contextName) forTarget:target];
}


- (BOOL) scriptTestConditions:(NSArray *)array
{
	return [self cxx_scriptTestConditions:oo::PListFrom(array)];
}


- (NSDictionary *) missionVariables
{
	return mission_variables;
}


- (NSString *)missionVariableForKey:(NSString *)key
{
	if (key == nil)  return nil;
	return oo::ObjectFromPList([self cxx_missionVariableForKey:oo::StdString(key)]);
}


- (void)setMissionVariable:(NSString *)value forKey:(NSString *)key
{
	if (key == nil)  return;
	[self cxx_setMissionVariable:oo::PListFrom(value) forKey:oo::StdString(key)];
}


- (NSArray *) missionsList
{
	return oo::ObjectFromPList([self cxx_missionsList]);
}


- (void) setMissionInstructions:(NSString *)text forMission:(NSString *)key
{
	[self cxx_setMissionInstructions:oo::StdString(text) forMission:oo::OptionalString(key)];
}


- (void) setMissionInstructionsList:(NSArray *)list forMission:(NSString *)key
{
	[self cxx_setMissionInstructionsList:oo::PListFrom(list) forMission:oo::OptionalString(key)];
}


- (NSString *)missionTitle
{
	return oo::NSStringOrNil([self cxx_missionTitle]);
}


- (void) setMissionTitle:(NSString *)value
{
	[self cxx_setMissionTitle:oo::OptionalString(value)];
}

@end


NSString *OOComparisonTypeToString(OOComparisonType type)
{
	return oo::NSStringFrom(cxx_OOComparisonTypeToString(type));
}
