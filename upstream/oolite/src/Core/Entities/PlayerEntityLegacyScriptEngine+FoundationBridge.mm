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

@end


NSString *OOComparisonTypeToString(OOComparisonType type)
{
	return oo::NSStringFrom(cxx_OOComparisonTypeToString(type));
}
