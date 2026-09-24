/*

OOConstToString+FoundationBridge.mm

TRANSITIONAL: see OOConstToString+FoundationBridge.h. Each function forwards to its cxx_
counterpart and converts at the boundary (oo::StdString in: nil arrives as "", which matches no
name, so the same default results; oo::NSStringFrom out).

*/

#import "OOConstToString.h"	// declares the bridge functions at its end
#import "OOFoundationBridge.h"



NSString *JSTypeToString(int /* ooscript::Type */ type)
{
	return oo::NSStringFrom(cxx_JSTypeToString(type));
}


NSString *CargoTypeToString(OOCargoType cargo)
{
	return oo::NSStringFrom(cxx_CargoTypeToString(cargo));
}


OOCargoType StringToCargoType(NSString *string)
{
	return cxx_StringToCargoType(oo::StdString(string));
}


NSString *EnergyUnitTypeToString(OOEnergyUnitType unit)
{
	return oo::NSStringFrom(cxx_EnergyUnitTypeToString(unit));
}


OOEnergyUnitType StringToEnergyUnitType(NSString *string)
{
	return cxx_StringToEnergyUnitType(oo::StdString(string));
}


NSString *RouteTypeToString(OORouteType routeType)
{
	return oo::NSStringFrom(cxx_RouteTypeToString(routeType));
}


OORouteType StringToRouteType(NSString *string)
{
	return cxx_StringToRouteType(oo::StdString(string));
}


NSString *DockingClearanceStatusToString(OODockingClearanceStatus dockingClearanceStatus)
{
	return oo::NSStringFrom(cxx_DockingClearanceStatusToString(dockingClearanceStatus));
}


NSString *OOStringFromGraphicsDetail(OOGraphicsDetail detail)
{
	return oo::NSStringFrom(cxx_OOStringFromGraphicsDetail(detail));
}


OOGraphicsDetail OOGraphicsDetailFromString(NSString *string)
{
	return cxx_OOGraphicsDetailFromString(oo::StdString(string));
}


NSString *OOStringFromHDRToneMapper(OOHDRToneMapper toneMapper)
{
	return oo::NSStringFrom(cxx_OOStringFromHDRToneMapper(toneMapper));
}


OOHDRToneMapper OOHDRToneMapperFromString( NSString *string)
{
	return cxx_OOHDRToneMapperFromString(oo::StdString(string));
}


NSString *OOStringFromSDRToneMapper(OOSDRToneMapper toneMapper)
{
	return oo::NSStringFrom(cxx_OOStringFromSDRToneMapper(toneMapper));
}


OOSDRToneMapper OOSDRToneMapperFromString( NSString *string)
{
	return cxx_OOSDRToneMapperFromString(oo::StdString(string));
}
