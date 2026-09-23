/*

PlayerEntityContracts.m

Oolite
Copyright (C) 2004-2013 Giles C Williams and contributors

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
MA 02110-1301, USA.

*/

#import "PlayerEntity.h"
#import "PlayerEntityLegacyScriptEngine.h"
#import "PlayerEntityContracts.h"
#import "PlayerEntityControls.h"
#import "ProxyPlayerEntity.h"
#import "HeadUpDisplay.h"

#import "ShipEntityAI.h"
#import "Universe.h"
#import "AI.h"
#import "OOColor.h"
#import "OOCharacter.h"
#import "StationEntity.h"
#import "GuiDisplayGen.h"
#import "OOStringExpander.h"
#import "OOStringParsing.h"
#import "OOPListView.h"
#import "OOConstToString.h"
#import "MyOpenGLView.h"
#import "NSStringOOExtensions.h"
#import "OOShipRegistry.h"
#import "OOEquipmentType.h"
#import "OOTexture.h"
#import "OOJavaScriptEngine.h"
#import "OOFoundationBridge.h"
#include "oofnd/PList.hpp"
#include "oofnd/String.hpp"
#include "oofnd/objc/OOObjCRef.h"


static unsigned RepForRisk(unsigned risk);


namespace
{

// -oo_intForKey: on the reputation dictionary.
int ReputationValue(const oo::PList::Dict &reputation, const std::string &key)
{
	const auto it = reputation.find(key);
	return it != reputation.end() ? oo::PListGet<int>::from(&it->second, 0) : 0;
}


// -oo_stringForKey: where the old code could read nil: a string, or a number's -stringValue;
// nullopt when the key is absent or holds anything else.
std::optional<std::string> OptionalStringForKey(const oo::PList &dict, std::string_view key)
{
	const oo::PList *value = dict.find(key);
	if (value == nullptr || !(value->isString() || value->isNumber()))  return std::nullopt;
	return dict.get<std::string>(key);
}


// %@ of a string that may be nil, in a runtime format.
oo::str::FormatArg TextArg(const std::optional<std::string> &string)
{
	return string ? oo::str::FormatArg(*string) : oo::str::FormatArg::null();
}


// -oo_doubleForKey: on a record dictionary (0 when absent).
double DoubleForKey(const oo::PList::Dict &dict, const std::string &key)
{
	const auto it = dict.find(key);
	return it != dict.end() ? oo::PListGet<double>::from(&it->second, 0.0) : 0.0;
}


// -oo_setInteger:forKey: / +numberWithInt: (both a signed integer).
void SetReputationValue(oo::PList::Dict &reputation, const std::string &key, int value)
{
	reputation[key] = oo::PList::signedInteger(value);
}

}	// namespace

@interface PlayerEntity (ContractsPrivate)

- (OOCreditsQuantity) tradeInValue;
- (NSArray*) contractsListFromArray:(NSArray *) contracts_array forCargo:(BOOL) forCargo forParcels:(BOOL)forParcels;

@end


@implementation PlayerEntity (Contracts)

- (std::optional<std::string>) cxx_processEscapePods // removes pods from cargo bay and treats categories of characters carried
{
	unsigned		i;
	BOOL added_entry = NO; // to prevent empty lines for slaves and the rare empty report.
	std::string		result;
	std::vector<oo::ObjCRef<OOCharacter *>>	rescuees;
	OOGovernmentID	government = [[[UNIVERSE currentSystemData] objectForKey:KEY_GOVERNMENT] intValue];
	if ([UNIVERSE inInterstellarSpace])  government = 1;	// equivalent to Feudal. I'm assuming any station in interstellar space is military. -- Ahruman 2008-05-29

	// step through the cargo removing crew from any escape pods
	// No enumerator because we're mutating the array -- Ahruman
	for (i = 0; i < [cargo count]; i++)
	{
		ShipEntity	*cargoItem = [cargo objectAtIndex:i];

		if ([cargoItem crew] != nil)
		{
			// Has crew -> is escape pod.
			for (OOCharacter *member in [cargoItem crew])  rescuees.push_back(oo::ObjCRef<OOCharacter *>(member));
			[cargoItem setCrew:nil];
			[cargo removeObjectAtIndex:i];
			i--;
		}
	}

	// step through the rescuees awarding insurance or bounty or adding to slaves
	for (i = 0; i < rescuees.size(); i++)
	{
		OOCharacter *rescuee = rescuees[i].get();

		if ([rescuee script])
		{
			[rescuee doScriptEvent:OOJSID("unloadCharacter")];
		}
		else if ([rescuee legacyScript])
		{
			[self runUnsanitizedScriptActions:[rescuee legacyScript]
							allowingAIMethods:YES
							  withContextName:oo::NSStringFrom(oo::str::format("<character \"%s\" script>", oo::DescriptionOf([rescuee name]).c_str()))
									forTarget:nil];
		}
		else if ([rescuee insuranceCredits] && [rescuee legalStatus])
		{
			float reward = (5.0 + government) * [rescuee legalStatus];
			float insurance = 10 * [rescuee insuranceCredits];
			if (government > (Ranrot() & 7) || reward >= insurance)
			{
				// claim bounty for capture, ignore insurance
				result += oo::str::formatRuntime(oo::StdString(DESC(@"capture-reward-for-@@-@-credits-@-alt")),
				 { oo::DescriptionOf([rescuee name]), oo::DescriptionOf([rescuee shortDescription]), oo::DescriptionOf(OOStringFromDeciCredits(reward, YES, NO)),
				 oo::DescriptionOf(OOStringFromDeciCredits(insurance, YES, NO)) });
				[self doScriptEvent:OOJSID("playerRescuedEscapePod") withArguments:oo::ObjectFromPList(oo::PList(oo::PList::Array{ oo::PList::unsignedInteger(static_cast<NSUInteger>(reward)), oo::PList("bounty"), oo::PListObject([rescuee infoForScripting]) }))];
			}
			else
			{
				// claim insurance reward with reduction of bounty
				result += oo::str::formatRuntime(oo::StdString(DESC(@"rescue-reward-for-@@-@-credits-@-alt")),
				 { oo::DescriptionOf([rescuee name]), oo::DescriptionOf([rescuee shortDescription]), oo::DescriptionOf(OOStringFromDeciCredits(insurance - reward, YES, NO)),
				 oo::DescriptionOf(OOStringFromDeciCredits(reward, YES, NO)) });
				reward = insurance - reward;
				[self doScriptEvent:OOJSID("playerRescuedEscapePod") withArguments:oo::ObjectFromPList(oo::PList(oo::PList::Array{ oo::PList::unsignedInteger(static_cast<NSUInteger>(reward)), oo::PList("insurance"), oo::PListObject([rescuee infoForScripting]) }))];
			}
			credits += reward;
			added_entry = YES;
		}
		else if ([rescuee insuranceCredits])
		{
			// claim insurance reward
			result += oo::str::formatRuntime(oo::StdString(DESC(@"rescue-reward-for-@@-@-credits")),
				{ oo::DescriptionOf([rescuee name]), oo::DescriptionOf([rescuee shortDescription]), oo::DescriptionOf(OOStringFromDeciCredits([rescuee insuranceCredits] * 10, YES, NO)) });
			credits += 10 * [rescuee insuranceCredits];
			[self doScriptEvent:OOJSID("playerRescuedEscapePod") withArguments:oo::ObjectFromPList(oo::PList(oo::PList::Array{ oo::PList::unsignedInteger(static_cast<NSUInteger>(10 * [rescuee insuranceCredits])), oo::PList("insurance"), oo::PListObject([rescuee infoForScripting]) }))];

			added_entry = YES;
		}
		else if ([rescuee legalStatus])
		{
			// claim bounty for capture
			float reward = (5.0 + government) * [rescuee legalStatus];
			result += oo::str::formatRuntime(oo::StdString(DESC(@"capture-reward-for-@@-@-credits")),
				{ oo::DescriptionOf([rescuee name]), oo::DescriptionOf([rescuee shortDescription]), oo::DescriptionOf(OOStringFromDeciCredits(reward, YES, NO)) });
			credits += reward;
			[self doScriptEvent:OOJSID("playerRescuedEscapePod") withArguments:oo::ObjectFromPList(oo::PList(oo::PList::Array{ oo::PList::unsignedInteger(static_cast<NSUInteger>(reward)), oo::PList("bounty"), oo::PListObject([rescuee infoForScripting]) }))];
			added_entry = YES;
		}
		else
		{
			// sell as slave - increase no. of slaves in manifest
			[shipCommodityData cxx_addQuantity:1 forGood:"slaves"];
			[self doScriptEvent:OOJSID("playerRescuedEscapePod") withArguments:oo::ObjectFromPList(oo::PList(oo::PList::Array{ oo::PList::unsignedInteger(0), oo::PList("slave"), oo::PListObject([rescuee infoForScripting]) }))];

		}
		if ((i < rescuees.size() - 1) && added_entry)
			result += "\n";
		added_entry = NO;
	}

	[self calculateCurrentCargo];

	return result;	// never nil (the old method returned an empty string when nothing was reported)
}


- (std::optional<std::string>) cxx_checkPassengerContracts	// returns messages from any passengers whose status have changed
{
	if ([self dockedStation] != [UNIVERSE station])	// only drop off passengers or fulfil contracts at main station
		return std::nullopt;
	
	// check escape pods...
	// TODO
	
	std::string			result;	// each report line ends in "\n" (-appendFormatLine:)
	unsigned			i;
	
	// check passenger contracts
	for (i = 0; i < passengers.size(); i++)
	{
		const oo::PList passenger_info = passengers[i];	// a copy: the entry may be removed below (it was retained)
		const std::optional<std::string> passenger_name = OptionalStringForKey(passenger_info, oo::StdString(PASSENGER_KEY_NAME));
		int dest = passenger_info.get<int>(oo::StdString(CONTRACT_KEY_DESTINATION));
		// the system name can change via script
		const std::optional<std::string> passenger_dest_name = oo::OptionalString([UNIVERSE getSystemName: dest]);
		int dest_eta = passenger_info.get<double>(oo::StdString(CONTRACT_KEY_ARRIVAL_TIME)) - ship_clock;
		
		if (system_id == dest)
		{
			// we've arrived in system!
			if (dest_eta > 0)
			{
				// and in good time
				long long fee = passenger_info.get<long long>(oo::StdString(CONTRACT_KEY_FEE));
				while ((randf() < 0.75)&&(dest_eta > 3600))	// delivered with more than an hour to spare and a decent customer?
				{
					fee *= 110;	// tip + 10%
					fee /= 100;
					dest_eta *= 0.5;
				}
				credits += 10 * fee;
				
				result += oo::str::formatRuntime(oo::StdString(DESC(@"passenger-delivered-okay-@-@-@")), { TextArg(passenger_name), oo::DescriptionOf(OOIntCredits(fee)), TextArg(passenger_dest_name) }) + "\n";
				if (passenger_info.get<unsigned int>(oo::StdString(CONTRACT_KEY_RISK), 0) > 0)
				{
					[self addRoleToPlayer:@"trader-courier+"];
				}

				[self increasePassengerReputation:RepForRisk(passenger_info.get<unsigned int>(oo::StdString(CONTRACT_KEY_RISK), 0))];
				passengers.erase(passengers.begin() + i--);
				[self doScriptEvent:OOJSID("playerCompletedContract") withArguments:oo::ObjectFromPList(oo::PList(oo::PList::Array{ oo::PList("passenger"), oo::PList("success"), oo::PList::unsignedInteger(static_cast<NSUInteger>(10*fee)), passenger_info }))];
			}
			else
			{
				// but we're late!
				long long fee = passenger_info.get<long long>(oo::StdString(CONTRACT_KEY_FEE)) / 2;	// halve fare
				while (randf() < 0.5)	// maybe halve fare a few times!
					fee /= 2;
				credits += 10 * fee;
				
				result += oo::str::formatRuntime(oo::StdString(DESC(@"passenger-delivered-late-@-@-@")), { TextArg(passenger_name), oo::DescriptionOf(OOIntCredits(fee)), TextArg(passenger_dest_name) }) + "\n";
				if (passenger_info.get<unsigned int>(oo::StdString(CONTRACT_KEY_RISK), 0) > 0)
				{
					[self addRoleToPlayer:@"trader-courier+"];
				}

				passengers.erase(passengers.begin() + i--);
				[self doScriptEvent:OOJSID("playerCompletedContract") withArguments:oo::ObjectFromPList(oo::PList(oo::PList::Array{ oo::PList("passenger"), oo::PList("late"), oo::PList::unsignedInteger(static_cast<NSUInteger>(10*fee)), passenger_info }))];

			}
		}
		else
		{
			if (dest_eta < 0)
			{
				// we've run out of time!
				result += oo::str::formatRuntime(oo::StdString(DESC(@"passenger-failed-@")), { TextArg(passenger_name) }) + "\n";
				
				[self decreasePassengerReputation:RepForRisk(passenger_info.get<unsigned int>(oo::StdString(CONTRACT_KEY_RISK), 0))];
				passengers.erase(passengers.begin() + i--);
				[self doScriptEvent:OOJSID("playerCompletedContract") withArguments:oo::ObjectFromPList(oo::PList(oo::PList::Array{ oo::PList("passenger"), oo::PList("failed"), oo::PList::unsignedInteger(static_cast<NSUInteger>(0)), passenger_info }))];
			}
		}
	}

	// check parcel contracts
	for (i = 0; i < [parcels count]; i++)
	{
		NSDictionary* parcel_info = [oo::PListView(parcels).at<NSDictionary *>(i) retain];
		NSString* parcel_name = oo::PListView(parcel_info).get<NSString *>(PASSENGER_KEY_NAME);
		int dest = oo::PListView(parcel_info).get<int>(CONTRACT_KEY_DESTINATION);
		int dest_eta = oo::PListView(parcel_info).get<double>(CONTRACT_KEY_ARRIVAL_TIME) - ship_clock;
		
		if (system_id == dest)
		{
			// we've arrived in system!
			if (dest_eta > 0)
			{
				// and in good time
				long long fee = oo::PListView(parcel_info).get<long long>(CONTRACT_KEY_FEE);
				while ((randf() < 0.75)&&(dest_eta > 86400))	// delivered with more than a day to spare and a decent customer?
				{
					// lower tips than passengers
					fee *= 110;	// tip + 10%
					fee /= 100;
					dest_eta *= 0.5;
				}
				credits += 10 * fee;
				
				result += oo::str::formatRuntime(oo::StdString(DESC(@"parcel-delivered-okay-@-@")), { oo::DescriptionOf(parcel_name), oo::DescriptionOf(OOIntCredits(fee)) }) + "\n";
				
				[self increaseParcelReputation:RepForRisk(oo::PListView(parcel_info).get<unsigned int>(CONTRACT_KEY_RISK, 0))];

				[parcels removeObjectAtIndex:i--];
				if (oo::PListView(parcel_info).get<unsigned int>(CONTRACT_KEY_RISK, 0) > 0)
				{
					[self addRoleToPlayer:@"trader-courier+"];
				}
				[self doScriptEvent:OOJSID("playerCompletedContract") withArguments:[NSArray arrayWithObjects:@"parcel",@"success",[NSNumber numberWithUnsignedInteger:10*fee],parcel_info,nil]];

			}
			else
			{
				// but we're late!
				long long fee = oo::PListView(parcel_info).get<long long>(CONTRACT_KEY_FEE) / 2;	// halve fare
				while (randf() < 0.5)	// maybe halve fare a few times!
					fee /= 2;
				credits += 10 * fee;
				
				result += oo::str::formatRuntime(oo::StdString(DESC(@"parcel-delivered-late-@-@")), { oo::DescriptionOf(parcel_name), oo::DescriptionOf(OOIntCredits(fee)) }) + "\n";
				if (oo::PListView(parcel_info).get<unsigned int>(CONTRACT_KEY_RISK, 0) > 0)
				{
					[self addRoleToPlayer:@"trader-courier+"];
				}
				[parcels removeObjectAtIndex:i--];
				[self doScriptEvent:OOJSID("playerCompletedContract") withArguments:[NSArray arrayWithObjects:@"parcel",@"late",[NSNumber numberWithUnsignedInteger:10*fee],parcel_info,nil]];
			}
		}
		else
		{
			if (dest_eta < 0)
			{
				// we've run out of time!
				result += oo::str::formatRuntime(oo::StdString(DESC(@"parcel-failed-@")), { oo::DescriptionOf(parcel_name) }) + "\n";
				
				[self decreaseParcelReputation:RepForRisk(oo::PListView(parcel_info).get<unsigned int>(CONTRACT_KEY_RISK, 0))];
				[parcels removeObjectAtIndex:i--];
				[self doScriptEvent:OOJSID("playerCompletedContract") withArguments:[NSArray arrayWithObjects:@"parcel",@"failed",[NSNumber numberWithUnsignedInteger:0],parcel_info,nil]];
			}
		}
		[parcel_info release];
	}

	
	// check cargo contracts
	for (i = 0; i < [contracts count]; i++)
	{
		NSDictionary* contract_info = [oo::PListView(contracts).at<NSDictionary *>(i) retain];
		NSString* contract_cargo_desc = oo::PListView(contract_info).get<NSString *>(CARGO_KEY_DESCRIPTION);
		int dest = oo::PListView(contract_info).get<int>(CONTRACT_KEY_DESTINATION);
		int dest_eta = oo::PListView(contract_info).get<double>(CONTRACT_KEY_ARRIVAL_TIME) - ship_clock;
		
		if (system_id == dest)
		{
			// no longer needed
			// int premium = 10 * oo::PListView(contract_info).get<float>(CONTRACT_KEY_PREMIUM);
			int fee = 10 * oo::PListView(contract_info).get<float>(CONTRACT_KEY_FEE);
			
			OOCommodityType contract_cargo_type = oo::PListView(contract_info).get<NSString *>(CARGO_KEY_TYPE);
			int contract_amount = oo::PListView(contract_info).get<int>(CARGO_KEY_AMOUNT);
			
			int quantity_on_hand =  [shipCommodityData quantityForGood:contract_cargo_type];

			// we've arrived in system!
			if (dest_eta > 0)
			{
				// and in good time
				if (quantity_on_hand >= contract_amount)
				{
					// with the goods too!
					
					// remove the goods...
					[shipCommodityData removeQuantity:contract_amount forGood:contract_cargo_type];

					// pay the premium and fee
					// credits += fee + premium;
					// not any more: all contracts initially awarded by JS, so fee
					// is now all that needs to be paid - CIM

					if ([shipCommodityData exportLegalityForGood:contract_cargo_type] > 0)
					{
						[self addRoleToPlayer:@"trader-smuggler"];
					}
					else
					{
						[self addRoleToPlayer:@"trader"];
					}
					
					credits += fee;
					result += oo::str::formatRuntime(oo::StdString(DESC(@"cargo-delivered-okay-@-@")), { oo::DescriptionOf(contract_cargo_desc), oo::DescriptionOf(OOCredits(fee)) }) + "\n";
					
					[contracts removeObjectAtIndex:i--];
					// repute++
					// +10 as cargo contracts don't have risk modifiers
					[self increaseContractReputation:10];
					[self doScriptEvent:OOJSID("playerCompletedContract") withArguments:[NSArray arrayWithObjects:@"cargo",@"success",[NSNumber numberWithUnsignedInteger:fee],contract_info,nil]];

				}
				else
				{
					// see if the amount of goods delivered is acceptable
					
					float percent_delivered = 100.0 * (float)quantity_on_hand/(float)contract_amount;
					float acceptable_ratio = 100.0 - 10.0 * system_id / 256.0; // down to 90%
					
					if (percent_delivered >= acceptable_ratio)
					{
						// remove the goods...
						[shipCommodityData setQuantity:0 forGood:contract_cargo_type];

						// pay the fee
						int shortfall = 100 - percent_delivered;
						int payment = percent_delivered * (fee) / 100.0;
						credits += payment;
						
						if ([shipCommodityData exportLegalityForGood:contract_cargo_type] > 0)
						{
							[self addRoleToPlayer:@"trader-smuggler"];
						}
						else
						{
							[self addRoleToPlayer:@"trader"];
						}

						result += oo::str::formatRuntime(oo::StdString(DESC(@"cargo-delivered-short-@-@-d")), { oo::DescriptionOf(contract_cargo_desc), oo::DescriptionOf(OOCredits(payment)), shortfall }) + "\n";
						
						[contracts removeObjectAtIndex:i--];
						// repute unchanged
						[self doScriptEvent:OOJSID("playerCompletedContract") withArguments:[NSArray arrayWithObjects:@"cargo",@"short",[NSNumber numberWithUnsignedInteger:payment],contract_info,nil]];

					}
					else
					{
						result += oo::str::formatRuntime(oo::StdString(DESC(@"cargo-refused-short-%@")), { oo::DescriptionOf(contract_cargo_desc) }) + "\n";
						// The player has still time to buy the missing goods elsewhere and fulfil the contract.
					}
				}
			}
			else
			{
				// but we're late!
				result += oo::str::formatRuntime(oo::StdString(DESC(@"cargo-delivered-late-@")), { oo::DescriptionOf(contract_cargo_desc) }) + "\n";

				[contracts removeObjectAtIndex:i--];
				// repute--
				[self decreaseContractReputation:10];
				[self doScriptEvent:OOJSID("playerCompletedContract") withArguments:[NSArray arrayWithObjects:@"cargo",@"late",[NSNumber numberWithUnsignedInteger:0],contract_info,nil]];
			}
		}
		else
		{
			if (dest_eta < 0)
			{
				// we've run out of time!
				result += oo::str::formatRuntime(oo::StdString(DESC(@"cargo-failed-@")), { oo::DescriptionOf(contract_cargo_desc) }) + "\n";
				
				[contracts removeObjectAtIndex:i--];
				// repute--
				[self decreaseContractReputation:10];
				[self doScriptEvent:OOJSID("playerCompletedContract") withArguments:[NSArray arrayWithObjects:@"cargo",@"failed",[NSNumber numberWithUnsignedInteger:0],contract_info,nil]];
			}
		}
		[contract_info release];
	}
	
	// check passenger_record for expired contracts (only deletes: the key order does not matter)
	std::vector<std::string> names;
	for (const auto &record : passenger_record)  names.push_back(record.first);
	for (i = 0; i < names.size(); i++)
	{
		double dest_eta = DoubleForKey(passenger_record, names[i]) - ship_clock;
		if (dest_eta < 0)
		{
			// check they're not STILL on board
			BOOL on_board = NO;
			unsigned j;
			for (j = 0; j < passengers.size(); j++)
			{
				const oo::PList *passenger_name = passengers[j].find(oo::StdString(PASSENGER_KEY_NAME));	// -isEqual: to the record's key
				if (passenger_name != nullptr && passenger_name->isString() && *passenger_name->getIf<std::string>() == names[i])
					on_board = YES;
			}
			if (!on_board)
			{
				passenger_record.erase(names[i]);
			}
		}
	}
	
	// check contract_record for expired contracts
	NSArray* ids = [contract_record allKeys];
	for (i = 0; i < [ids count]; i++)
	{
		double dest_eta = [(NSNumber*)[contract_record objectForKey:[ids objectAtIndex:i]] doubleValue] - ship_clock;
		if (dest_eta < 0)
		{
			[contract_record removeObjectForKey:[ids objectAtIndex:i]];
		}
	}

	// check parcel_record for expired deliveries
	ids = [parcel_record allKeys];
	for (i = 0; i < [ids count]; i++)
	{
		double dest_eta = [(NSNumber*)[parcel_record objectForKey:[ids objectAtIndex:i]] doubleValue] - ship_clock;
		if (dest_eta < 0)
		{
			[parcel_record removeObjectForKey:[ids objectAtIndex:i]];
		}
	}

	
	if (result.empty())
	{
		return std::nullopt;	// nil: nothing to report
	}
	else
	{
		// Should have a trailing \n
		result.pop_back();
	}

	return result;
}


- (OOCargoQuantity) contractedVolumeForGood:(OOCommodityType) good
{
	OOCargoQuantity total = 0;
	for (unsigned i = 0; i < [contracts count]; i++)
	{
		NSDictionary* contract_info = oo::PListView(contracts).at<NSDictionary *>(i);
		OOCommodityType contract_cargo_type = oo::PListView(contract_info).get<NSString *>(CARGO_KEY_TYPE);
		if ([good isEqualToString:contract_cargo_type])
		{
			total += oo::PListView(contract_info).get<NSUInteger>(CARGO_KEY_AMOUNT);
		}
	}
	return total;
}


- (void) cxx_addMessageToReport:(const std::string &) report
{
	if (!report.empty())
	{
		if (dockingReport.empty())
			dockingReport += report;
		else
			dockingReport += "\n\n" + report;	// @"\n\n%@"
	}
}


- (oo::PList) reputation
{
	return oo::PList(reputation);
}


- (int) passengerReputation
{
	int good = ReputationValue(reputation, oo::StdString(PASSAGE_GOOD_KEY));
	int bad = ReputationValue(reputation, oo::StdString(PASSAGE_BAD_KEY));
	int unknown = ReputationValue(reputation, oo::StdString(PASSAGE_UNKNOWN_KEY));

	if (unknown > 0)
		unknown = MAX_CONTRACT_REP - (((2*unknown)+(market_rnd % unknown))/3);
	else
		unknown = MAX_CONTRACT_REP;
	
	return (good + unknown - 3 * bad) / 2;	// return a number from -MAX_CONTRACT_REP to +MAX_CONTRACT_REP
}


- (void) increasePassengerReputation:(unsigned)amount
{
	int good = ReputationValue(reputation, oo::StdString(PASSAGE_GOOD_KEY));
	int bad = ReputationValue(reputation, oo::StdString(PASSAGE_BAD_KEY));
	int unknown = ReputationValue(reputation, oo::StdString(PASSAGE_UNKNOWN_KEY));
	
	for (unsigned i=0;i<amount;i++)
	{
	if (bad > 0)
	{
		// shift a bean from bad to unknown
		bad--;
		if (unknown < MAX_CONTRACT_REP)
			unknown++;
	}
	else
	{
		// shift a bean from unknown to good
		if (unknown > 0)
			unknown--;
		if (good < MAX_CONTRACT_REP)
			good++;
	}
	}
	SetReputationValue(reputation, oo::StdString(PASSAGE_GOOD_KEY), good);
	SetReputationValue(reputation, oo::StdString(PASSAGE_BAD_KEY), bad);
	SetReputationValue(reputation, oo::StdString(PASSAGE_UNKNOWN_KEY), unknown);
}


- (void) decreasePassengerReputation:(unsigned)amount
{
	int good = ReputationValue(reputation, oo::StdString(PASSAGE_GOOD_KEY));
	int bad = ReputationValue(reputation, oo::StdString(PASSAGE_BAD_KEY));
	int unknown = ReputationValue(reputation, oo::StdString(PASSAGE_UNKNOWN_KEY));
	
for (unsigned i=0;i<amount;i++)
	{
	if (good > 0)
	{
		// shift a bean from good to bad
		good--;
		if (bad < MAX_CONTRACT_REP)
			bad++;
	}
	else
	{
		// shift a bean from unknown to bad
		if (unknown > 0)
			unknown--;
		if (bad < MAX_CONTRACT_REP)
			bad++;
	}
	}
	SetReputationValue(reputation, oo::StdString(PASSAGE_GOOD_KEY), good);
	SetReputationValue(reputation, oo::StdString(PASSAGE_BAD_KEY), bad);
	SetReputationValue(reputation, oo::StdString(PASSAGE_UNKNOWN_KEY), unknown);
}


- (int) parcelReputation
{
	int good = ReputationValue(reputation, oo::StdString(PARCEL_GOOD_KEY));
	int bad = ReputationValue(reputation, oo::StdString(PARCEL_BAD_KEY));
	int unknown = ReputationValue(reputation, oo::StdString(PARCEL_UNKNOWN_KEY));
	
	if (unknown > 0)
		unknown = MAX_CONTRACT_REP - (((2*unknown)+(market_rnd % unknown))/3);
	else
		unknown = MAX_CONTRACT_REP;
	
	return (good + unknown - 3 * bad) / 2;	// return a number from -MAX_CONTRACT_REP to +MAX_CONTRACT_REP
}


- (void) increaseParcelReputation:(unsigned)amount
{
	int good = ReputationValue(reputation, oo::StdString(PARCEL_GOOD_KEY));
	int bad = ReputationValue(reputation, oo::StdString(PARCEL_BAD_KEY));
	int unknown = ReputationValue(reputation, oo::StdString(PARCEL_UNKNOWN_KEY));

		for (unsigned i=0;i<amount;i++)
	{
	if (bad > 0)
	{
		// shift a bean from bad to unknown
		bad--;
		if (unknown < MAX_CONTRACT_REP)
			unknown++;
	}
	else
	{
		// shift a bean from unknown to good
		if (unknown > 0)
			unknown--;
		if (good < MAX_CONTRACT_REP)
			good++;
	}
	}
	SetReputationValue(reputation, oo::StdString(PARCEL_GOOD_KEY), good);
	SetReputationValue(reputation, oo::StdString(PARCEL_BAD_KEY), bad);
	SetReputationValue(reputation, oo::StdString(PARCEL_UNKNOWN_KEY), unknown);
}


- (void) decreaseParcelReputation:(unsigned)amount
{
	int good = ReputationValue(reputation, oo::StdString(PARCEL_GOOD_KEY));
	int bad = ReputationValue(reputation, oo::StdString(PARCEL_BAD_KEY));
	int unknown = ReputationValue(reputation, oo::StdString(PARCEL_UNKNOWN_KEY));
	
	for (unsigned i=0;i<amount;i++)
	{
	if (good > 0)
	{
		// shift a bean from good to bad
		good--;
		if (bad < MAX_CONTRACT_REP)
			bad++;
	}
	else
	{
		// shift a bean from unknown to bad
		if (unknown > 0)
			unknown--;
		if (bad < MAX_CONTRACT_REP)
			bad++;
	}
	}
	SetReputationValue(reputation, oo::StdString(PARCEL_GOOD_KEY), good);
	SetReputationValue(reputation, oo::StdString(PARCEL_BAD_KEY), bad);
	SetReputationValue(reputation, oo::StdString(PARCEL_UNKNOWN_KEY), unknown);
}


- (int) contractReputation
{
	int good = ReputationValue(reputation, oo::StdString(CONTRACTS_GOOD_KEY));
	int bad = ReputationValue(reputation, oo::StdString(CONTRACTS_BAD_KEY));
	int unknown = ReputationValue(reputation, oo::StdString(CONTRACTS_UNKNOWN_KEY));
	
	if (unknown > 0)
		unknown = MAX_CONTRACT_REP - (((2*unknown)+(market_rnd % unknown))/3);
	else
		unknown = MAX_CONTRACT_REP;
	
	return (good + unknown - 3 * bad) / 2;	// return a number from -MAX_CONTRACT_REP to +MAX_CONTRACT_REP
}


- (void) increaseContractReputation:(unsigned)amount
{
	int good = ReputationValue(reputation, oo::StdString(CONTRACTS_GOOD_KEY));
	int bad = ReputationValue(reputation, oo::StdString(CONTRACTS_BAD_KEY));
	int unknown = ReputationValue(reputation, oo::StdString(CONTRACTS_UNKNOWN_KEY));
	
	for (unsigned i=0;i<amount;i++)
	{
	if (bad > 0)
	{
		// shift a bean from bad to unknown
		bad--;
		if (unknown < MAX_CONTRACT_REP)
			unknown++;
	}
	else
	{
		// shift a bean from unknown to good
		if (unknown > 0)
			unknown--;
		if (good < MAX_CONTRACT_REP)
			good++;
	}
	}
	SetReputationValue(reputation, oo::StdString(CONTRACTS_GOOD_KEY), good);
	SetReputationValue(reputation, oo::StdString(CONTRACTS_BAD_KEY), bad);
	SetReputationValue(reputation, oo::StdString(CONTRACTS_UNKNOWN_KEY), unknown);
}


- (void) decreaseContractReputation:(unsigned)amount
{
	int good = ReputationValue(reputation, oo::StdString(CONTRACTS_GOOD_KEY));
	int bad = ReputationValue(reputation, oo::StdString(CONTRACTS_BAD_KEY));
	int unknown = ReputationValue(reputation, oo::StdString(CONTRACTS_UNKNOWN_KEY));
	
	for (unsigned i=0;i<amount;i++)
	{
	if (good > 0)
	{
		// shift a bean from good to bad
		good--;
		if (bad < MAX_CONTRACT_REP)
			bad++;
	}
	else
	{
		// shift a bean from unknown to bad
		if (unknown > 0)
			unknown--;
		if (bad < MAX_CONTRACT_REP)
			bad++;
	}
	}
	SetReputationValue(reputation, oo::StdString(CONTRACTS_GOOD_KEY), good);
	SetReputationValue(reputation, oo::StdString(CONTRACTS_BAD_KEY), bad);
	SetReputationValue(reputation, oo::StdString(CONTRACTS_UNKNOWN_KEY), unknown);
}


- (void) erodeReputation
{
	int c_good = ReputationValue(reputation, oo::StdString(CONTRACTS_GOOD_KEY));
	int c_bad = ReputationValue(reputation, oo::StdString(CONTRACTS_BAD_KEY));
	int c_unknown = ReputationValue(reputation, oo::StdString(CONTRACTS_UNKNOWN_KEY));
	int p_good = ReputationValue(reputation, oo::StdString(PASSAGE_GOOD_KEY));
	int p_bad = ReputationValue(reputation, oo::StdString(PASSAGE_BAD_KEY));
	int p_unknown = ReputationValue(reputation, oo::StdString(PASSAGE_UNKNOWN_KEY));
	int pl_good = ReputationValue(reputation, oo::StdString(PARCEL_GOOD_KEY));
	int pl_bad = ReputationValue(reputation, oo::StdString(PARCEL_BAD_KEY));
	int pl_unknown = ReputationValue(reputation, oo::StdString(PARCEL_UNKNOWN_KEY));
	
	if (c_unknown < MAX_CONTRACT_REP)
	{
		if (c_bad > 0)
			c_bad--;
		else
		{
			if (c_good > 0)
				c_good--;
		}
		c_unknown++;
	}
	
	if (p_unknown < MAX_CONTRACT_REP)
	{
		if (p_bad > 0)
			p_bad--;
		else
		{
			if (p_good > 0)
				p_good--;
		}
		p_unknown++;
	}

	if (pl_unknown < MAX_CONTRACT_REP)
	{
		if (pl_bad > 0)
			pl_bad--;
		else
		{
			if (pl_good > 0)
				pl_good--;
		}
		pl_unknown++;
	}
	
	SetReputationValue(reputation, oo::StdString(CONTRACTS_GOOD_KEY), c_good);
	SetReputationValue(reputation, oo::StdString(CONTRACTS_BAD_KEY), c_bad);
	SetReputationValue(reputation, oo::StdString(CONTRACTS_UNKNOWN_KEY), c_unknown);
	SetReputationValue(reputation, oo::StdString(PASSAGE_GOOD_KEY), p_good);
	SetReputationValue(reputation, oo::StdString(PASSAGE_BAD_KEY), p_bad);
	SetReputationValue(reputation, oo::StdString(PASSAGE_UNKNOWN_KEY), p_unknown);
	SetReputationValue(reputation, oo::StdString(PARCEL_GOOD_KEY), pl_good);
	SetReputationValue(reputation, oo::StdString(PARCEL_BAD_KEY), pl_bad);
	SetReputationValue(reputation, oo::StdString(PARCEL_UNKNOWN_KEY), pl_unknown);
	
}


/* Update reputation levels in case of change in MAX_CONTRACT_REP */
- (void) normaliseReputation
{
	int c_good = ReputationValue(reputation, oo::StdString(CONTRACTS_GOOD_KEY));
	int c_bad = ReputationValue(reputation, oo::StdString(CONTRACTS_BAD_KEY));
	int c_unknown = ReputationValue(reputation, oo::StdString(CONTRACTS_UNKNOWN_KEY));
	int p_good = ReputationValue(reputation, oo::StdString(PASSAGE_GOOD_KEY));
	int p_bad = ReputationValue(reputation, oo::StdString(PASSAGE_BAD_KEY));
	int p_unknown = ReputationValue(reputation, oo::StdString(PASSAGE_UNKNOWN_KEY));
	int pl_good = ReputationValue(reputation, oo::StdString(PARCEL_GOOD_KEY));
	int pl_bad = ReputationValue(reputation, oo::StdString(PARCEL_BAD_KEY));
	int pl_unknown = ReputationValue(reputation, oo::StdString(PARCEL_UNKNOWN_KEY));

	int c = c_good + c_bad + c_unknown;
	if (c == 0)
	{
		c_unknown = MAX_CONTRACT_REP;
	}
	else if (c != MAX_CONTRACT_REP)
	{
		c_good = c_good * MAX_CONTRACT_REP / c;
		c_bad = c_bad * MAX_CONTRACT_REP / c;
		c_unknown = MAX_CONTRACT_REP - c_good - c_bad;
	}

	int p = p_good + p_bad + p_unknown;
	if (p == 0)
	{
		p_unknown = MAX_CONTRACT_REP;
	}
	else if (p != MAX_CONTRACT_REP)
	{
		p_good = p_good * MAX_CONTRACT_REP / p;
		p_bad = p_bad * MAX_CONTRACT_REP / p;
		p_unknown = MAX_CONTRACT_REP - p_good - p_bad;
	}
	
	int pl = pl_good + pl_bad + pl_unknown;
	if (pl == 0)
	{
		pl_unknown = MAX_CONTRACT_REP;
	}
	else if (pl != MAX_CONTRACT_REP)
	{
		pl_good = pl_good * MAX_CONTRACT_REP / pl;
		pl_bad = pl_bad * MAX_CONTRACT_REP / pl;
		pl_unknown = MAX_CONTRACT_REP - pl_good - pl_bad;
	}

	SetReputationValue(reputation, oo::StdString(CONTRACTS_GOOD_KEY), c_good);
	SetReputationValue(reputation, oo::StdString(CONTRACTS_BAD_KEY), c_bad);
	SetReputationValue(reputation, oo::StdString(CONTRACTS_UNKNOWN_KEY), c_unknown);
	SetReputationValue(reputation, oo::StdString(PASSAGE_GOOD_KEY), p_good);
	SetReputationValue(reputation, oo::StdString(PASSAGE_BAD_KEY), p_bad);
	SetReputationValue(reputation, oo::StdString(PASSAGE_UNKNOWN_KEY), p_unknown);
	SetReputationValue(reputation, oo::StdString(PARCEL_GOOD_KEY), pl_good);
	SetReputationValue(reputation, oo::StdString(PARCEL_BAD_KEY), pl_bad);
	SetReputationValue(reputation, oo::StdString(PARCEL_UNKNOWN_KEY), pl_unknown);
	
}


- (BOOL) cxx_addPassenger:(const std::string &)Name start:(unsigned)start destination:(unsigned)Destination eta:(double)eta fee:(double)fee advance:(double)advance risk:(unsigned)risk
{
	// the NSNumber kinds the old dictionary held: +numberWithInt:, +numberWithDouble:, +numberWithUnsignedInt:
	const oo::PList passenger_info(oo::PList::Dict{
		{ oo::StdString(PASSENGER_KEY_NAME),								oo::PList(Name) },
		{ oo::StdString(CONTRACT_KEY_START),				oo::PList::signedInteger(static_cast<int>(start)) },
		{ oo::StdString(CONTRACT_KEY_DESTINATION),			oo::PList::signedInteger(static_cast<int>(Destination)) },
		{ oo::StdString(CONTRACT_KEY_DEPARTURE_TIME),		oo::PList([PLAYER clockTime]) },
		{ oo::StdString(CONTRACT_KEY_ARRIVAL_TIME),			oo::PList(eta) },
		{ oo::StdString(CONTRACT_KEY_FEE),					oo::PList(fee) },
		{ oo::StdString(CONTRACT_KEY_PREMIUM),				oo::PList(advance) },
		{ oo::StdString(CONTRACT_KEY_RISK),					oo::PList::unsignedInteger(risk) },
	});

	// extra checks, just in case.
	if (passengers.size() >= max_passengers || passenger_record.find(Name) != passenger_record.end()) return NO;

	if (risk > 1)
	{
		[self addRoleToPlayer:@"trader-courier+"];
	}

	passengers.push_back(passenger_info);
	passenger_record[Name] = oo::PList(eta);	// +numberWithDouble:

	[self doScriptEvent:OOJSID("playerEnteredContract") withArguments:oo::ObjectFromPList(oo::PList(oo::PList::Array{ oo::PList("passenger"), passenger_info }))];

	return YES;
}


- (BOOL) cxx_removePassenger:(const std::string &)Name	// removes the first passenger that answers to Name, returns NO if none found
{
	// extra check, just in case.
	if (passengers.empty()) return NO;

	unsigned			i;

	for (i = 0; i < passengers.size(); i++)
	{
		const std::optional<std::string> this_name = OptionalStringForKey(passengers[i], oo::StdString(PASSENGER_KEY_NAME));

		if (this_name == Name)
		{
			passengers.erase(passengers.begin() + i);
			passenger_record.erase(Name);
			return YES;
		}
	}

	return NO;
}


- (BOOL) addParcel:(NSString*)Name start:(unsigned)start destination:(unsigned)Destination eta:(double)eta fee:(double)fee premium:(double)premium risk:(unsigned)risk
{
	NSDictionary* parcel_info = [NSDictionary dictionaryWithObjectsAndKeys:
		Name,											PASSENGER_KEY_NAME,
		[NSNumber numberWithInt:start],					CONTRACT_KEY_START,
		[NSNumber numberWithInt:Destination],			CONTRACT_KEY_DESTINATION,
		[NSNumber numberWithDouble:[PLAYER clockTime]],	CONTRACT_KEY_DEPARTURE_TIME,
		[NSNumber numberWithDouble:eta],				CONTRACT_KEY_ARRIVAL_TIME,
		[NSNumber numberWithDouble:fee],				CONTRACT_KEY_FEE,
		[NSNumber numberWithDouble:premium],			CONTRACT_KEY_PREMIUM,
		[NSNumber numberWithUnsignedInt:risk],			CONTRACT_KEY_RISK,
		NULL];
	
	// extra checks, just in case.
	// FIXME: do we absolutely need this check? can we live
	// with parcels of senders who happen to have the same
	// name? - Nikos 20160527
	//if ([parcel_record objectForKey:Name] != nil) return NO;

	if (risk > 1)
	{
		[self addRoleToPlayer:@"trader-courier+"];
	}
		
	[parcels addObject:parcel_info];
	[parcel_record setObject:[NSNumber numberWithDouble:eta] forKey:Name];

	[self doScriptEvent:OOJSID("playerEnteredContract") withArguments:[NSArray arrayWithObjects:@"parcel",parcel_info,nil]];

	return YES;
}


- (BOOL) removeParcel:(NSString*)Name	// removes the first parcel that answers to Name, returns NO if none found
{	
	// extra check, just in case.
	if ([parcels count] == 0) return NO;
	
	unsigned			i;
	
	for (i = 0; i < [parcels count]; i++)
	{
		NSString		*this_name = oo::PListView(oo::PListView(parcels).at<NSDictionary *>(i)).get<NSString *>(PASSENGER_KEY_NAME);
		
		if ([Name isEqualToString:this_name])
		{
			[parcels removeObjectAtIndex:i];
			[parcel_record removeObjectForKey:Name];
			return YES;
		}
	}
	
	return NO;
}


- (BOOL) awardContract:(unsigned)qty commodity:(OOCommodityType)type start:(unsigned)start
					 destination:(unsigned)Destination eta:(double)eta fee:(double)fee premium:(double)premium
{

	unsigned		sr1 = Ranrot()&0x111111;
	int				sr2 = Ranrot()&0x111111;

	NSString		*cargo_ID =[NSString stringWithFormat:@"%06x-%06x", sr1, sr2];
	
	if (![[UNIVERSE commodities] goodDefined:type])  return NO;
	if (qty < 1)  return NO;
	
	// avoid duplicate cargo_IDs
	while ([contract_record objectForKey:cargo_ID] != nil)
	{
		sr2++;
		cargo_ID =[NSString stringWithFormat:@"%06x-%06x", sr1, sr2];
	}

	NSDictionary* cargo_info = [NSDictionary dictionaryWithObjectsAndKeys:
		cargo_ID,										CARGO_KEY_ID,
		type,											CARGO_KEY_TYPE,
		[NSNumber numberWithInt:qty],					CARGO_KEY_AMOUNT,
		[UNIVERSE describeCommodity:type amount:qty],	CARGO_KEY_DESCRIPTION,
		[NSNumber numberWithInt:start],					CONTRACT_KEY_START,
		[NSNumber numberWithInt:Destination],			CONTRACT_KEY_DESTINATION,
		[NSNumber numberWithDouble:[PLAYER clockTime]],	CONTRACT_KEY_DEPARTURE_TIME,
		[NSNumber numberWithDouble:eta],				CONTRACT_KEY_ARRIVAL_TIME,
		[NSNumber numberWithDouble:fee],				CONTRACT_KEY_FEE,
		[NSNumber numberWithDouble:premium],						CONTRACT_KEY_PREMIUM,
		NULL];
	
	// check available space
	
	OOCargoQuantity		cargoSpaceRequired = qty;
	OOMassUnit			contractCargoUnits	= [shipCommodityData massUnitForGood:type];
	
	if (contractCargoUnits == UNITS_KILOGRAMS)  cargoSpaceRequired /= 1000;
	if (contractCargoUnits == UNITS_GRAMS)  cargoSpaceRequired /= 1000000;
	
	if (cargoSpaceRequired > [self availableCargoSpace]) return NO;

	[shipCommodityData addQuantity:qty forGood:type];

	current_cargo = [self cargoQuantityOnBoard];

	if ([shipCommodityData exportLegalityForGood:type] > 0)
	{
		[self addRoleToPlayer:@"trader-smuggler"];
		[roleWeightFlags setObject:[NSNumber numberWithInt:1] forKey:@"bought-illegal"];
	}
	else
	{
		[self addRoleToPlayer:@"trader"];
		[roleWeightFlags setObject:[NSNumber numberWithInt:1] forKey:@"bought-legal"];
	}

	[contracts addObject:cargo_info];
	[contract_record setObject:[NSNumber numberWithDouble:eta] forKey:cargo_ID];

	[self doScriptEvent:OOJSID("playerEnteredContract") withArguments:[NSArray arrayWithObjects:@"cargo",cargo_info,nil]];

	return YES;
}


- (BOOL) removeContract:(OOCommodityType)type destination:(unsigned)dest	// removes the first match found, returns NO if none found
{
	if ([contracts count] == 0 || dest > 255)  return NO;

	if (![[UNIVERSE commodities] goodDefined:type])  return NO;
	
	unsigned			i;
	
	for (i = 0; i < [contracts count]; i++)
	{
		NSDictionary		*contractInfo = oo::PListView(contracts).at<NSDictionary *>(i);
		unsigned 			cargoDest = oo::PListView(contractInfo).get<int>(CONTRACT_KEY_DESTINATION);
		OOCommodityType		cargoType = oo::PListView(contractInfo).get<NSString *>(CARGO_KEY_TYPE);
		
		if ([cargoType isEqualToString:type] && cargoDest == dest)
		{
			[contract_record removeObjectForKey:oo::PListView(contractInfo).get<NSString *>(CARGO_KEY_ID)];
			[contracts removeObjectAtIndex:i];
			return YES;
		}
	}
	
	return NO;
}




- (NSArray*) passengerList
{
	return [self contractsListFromArray:oo::ObjectFromPList(oo::PList(passengers)) forCargo:NO forParcels:NO];	// the helper is chunk 5's
}


- (NSArray*) parcelList
{
	return [self contractsListFromArray:parcels forCargo:NO forParcels:YES];
}


- (NSArray*) contractList
{
	return [self contractsListFromArray:contracts forCargo:YES forParcels:NO];
}


- (NSArray*) contractsListFromArray:(NSArray *) contracts_array forCargo:(BOOL) forCargo forParcels:(BOOL)forParcels
{
	// check  contracts
	NSMutableArray	*result = [NSMutableArray arrayWithCapacity:5];
	NSString		*formatString = (forCargo||forParcels) ? @"oolite-manifest-item-delivery" : @"oolite-manifest-person-travelling";
	unsigned i;
	for (i = 0; i < [contracts_array count]; i++)
	{
		NSDictionary* contract_info = (NSDictionary *)[contracts_array objectAtIndex:i];
		NSString* label = oo::PListView(contract_info).get<NSString *>(forCargo ? CARGO_KEY_DESCRIPTION : PASSENGER_KEY_NAME);
		// the system name can change via script. The following PASSENGER_KEYs are identical to the corresponding CONTRACT_KEYs
		NSString* destination = [UNIVERSE getSystemName: oo::PListView(contract_info).get<int>(CONTRACT_KEY_DESTINATION)];
		int dest_eta = oo::PListView(contract_info).get<double>(CONTRACT_KEY_ARRIVAL_TIME) - ship_clock;
		NSString *deadline = [UNIVERSE shortTimeDescription:dest_eta];

		OOCreditsQuantity fee = oo::PListView(contract_info).get<int>(CONTRACT_KEY_FEE);
		NSString *feeDesc = OOIntCredits(fee);

		[result addObject:OOExpandKey(formatString, label, destination, deadline, feeDesc)];

	}
	
	return result;
}


// only use within setGuiToManifestScreen
#define SET_MANIFEST_ROW(obj,color,row) ([self setManifestScreenRow:obj inColor:color forRow:row ofRows:max_rows andOffset:page_offset inMultipage:multi_page])

- (void) setGuiToManifestScreen
{
	OOGUIScreenID	oldScreen = gui_screen;
	
	GuiDisplayGen	*gui = [UNIVERSE gui];
	gui_screen = GUI_SCREEN_MANIFEST;
	BOOL			guiChanged = (oldScreen != gui_screen);
	if (guiChanged)
	{
		[gui setStatusPage:0]; // need to do this earlier than the rest
	}
	
	// GUI stuff
	{
		NSInteger current, max;
		OOColor *subheadColor = [gui colorFromSetting:kGuiManifestSubheadColor defaultValue:[OOColor greenColor]];
		OOColor *entryColor = [gui colorFromSetting:kGuiManifestEntryColor defaultValue:nil];
		OOColor *scrollColor = [gui colorFromSetting:kGuiManifestScrollColor defaultValue:[OOColor greenColor]];
		OOColor *noScrollColor = [gui colorFromSetting:kGuiManifestNoScrollColor defaultValue:[OOColor darkGrayColor]];

		NSArray*	cargoManifest = [self cargoList];
		NSArray*	missionsManifest = [self missionsList];
		
		NSUInteger	i = 0;
		NSUInteger	max_rows = 20;
		NSUInteger	manifestCount = [cargoManifest count];
		NSUInteger	cargoRowCount = (manifestCount + 1)/2;
		OOGUIRow	cargoRow = 2;
		OOGUIRow	missionsRow = 2;
		
		OOGUIRow	nextPageRow = MANIFEST_SCREEN_ROW_NEXT;
		// show extra lines if no HUD is displayed.
		if ([[self hud] isHidden] || [[self hud] allowBigGui])
		{
			max_rows += 7;
			nextPageRow += 7;
		}

		NSUInteger mmRows = 0;
		id mmEntry = nil;
		foreach (mmEntry, missionsManifest)
		{
			if ([mmEntry isKindOfClass:[NSString class]])
			{
				++mmRows;
			}
			else if ([mmEntry isKindOfClass:[NSArray class]])
			{
				mmRows += [(NSArray *)mmEntry count];
			}
		}
		
		NSInteger page_offset = 0;
		BOOL multi_page = NO;
//		NSUInteger total_rows = cargoRowCount + MAX(1U,[passengerManifest count]) + MAX(1U,[contractManifest count]) + mmRows + MAX(1U,[parcelManifest count]) + 5;
		NSUInteger total_rows = cargoRowCount + mmRows + 5;
		if (total_rows > max_rows)
		{
			max_rows -= 2;
			page_offset = ([gui statusPage]-1) * max_rows;
			if (page_offset < 0 || (NSUInteger)page_offset >= total_rows)
			{
				[gui setStatusPage:0];
				page_offset = 0;
			}
			multi_page = YES;
		}


		OOGUITabSettings tab_stops;
		tab_stops[0] = 0;
		tab_stops[1] = 256;
		[gui overrideTabs:tab_stops from:kGuiManifestTabs length:3];
		[gui setTabStops:tab_stops];
		
		// Cargo Manifest
		current_cargo = [self cargoQuantityOnBoard];

		[gui clearAndKeepBackground:!guiChanged];
		[gui setTitle:DESC(@"manifest-title")];
		
		current = current_cargo;
		max = [self maxAvailableCargoSpace];
		NSString *cargoString = OOExpandKey(@"oolite-manifest-cargo", current, max);
		current = [[self passengerList] count];
		max = max_passengers;
		NSString *cabinString = OOExpandKey(@"oolite-manifest-cabins", current, max);
		NSArray *manifestHeader = [NSArray arrayWithObjects:cargoString,cabinString,nil];

		SET_MANIFEST_ROW( manifestHeader , entryColor, cargoRow - 1);
		
		if (manifestCount > 0)
		{
			for (i = 0; i < cargoRowCount; i++)
			{
				NSMutableArray*		row_info = [NSMutableArray arrayWithCapacity:3];
				// i is always smaller than manifest_count, no need to test.
				[row_info addObject:[cargoManifest objectAtIndex:i]];
				if (i + cargoRowCount < manifestCount)
				{
					[row_info addObject:[cargoManifest objectAtIndex:i + cargoRowCount]];
				}
				else
				{
					[row_info addObject:@""];
				}
				SET_MANIFEST_ROW( (NSArray *)row_info, subheadColor, cargoRow + i);
			}
		}
		else
		{
			SET_MANIFEST_ROW( (DESC(@"manifest-none")), subheadColor, cargoRow);
			cargoRowCount=1;
		}
		
		missionsRow = cargoRow + cargoRowCount + 1;
		
		// Missions Manifest
		manifestCount = [missionsManifest count];
		
		if (manifestCount > 0)
		{
			if ([[missionsManifest objectAtIndex:0] isKindOfClass:[NSString class]])
			{
				// then there's at least one without its own heading
				// to go under the generic 'missions' heading
				SET_MANIFEST_ROW( (DESC(@"manifest-missions")) , entryColor, missionsRow - 1);
			}
			else
			{
				missionsRow--;
			}
			
			NSUInteger mmRow = 0;
			for (i = 0; i < manifestCount; i++)
			{
				NSString *mmItem = nil;
				mmEntry = [missionsManifest objectAtIndex:i];
				if ([mmEntry isKindOfClass:[NSString class]])
				{
					mmItem = [NSString stringWithFormat:@"\t%@",(NSString *)mmEntry];
					SET_MANIFEST_ROW( (mmItem) , subheadColor, missionsRow + mmRow);
					++mmRow;
				}
				else if ([mmEntry isKindOfClass:[NSArray class]])
				{
					BOOL isHeading = YES;
					foreach (mmItem, mmEntry)
					{
						if (isHeading)
						{
							SET_MANIFEST_ROW( ((NSString *)mmItem) , entryColor , missionsRow + mmRow);
						}
						else
						{
							mmItem = [NSString stringWithFormat:@"\t%@",(NSString *)mmItem];
							SET_MANIFEST_ROW( ((NSString *)mmItem) , subheadColor , missionsRow + mmRow);
						}
						isHeading = NO;
						++mmRow;
					}
				}
			}
		}
		
		if (multi_page)
		{
			OOGUIRow r_start = MANIFEST_SCREEN_ROW_BACK;
			OOGUIRow r_end = nextPageRow;
			if (page_offset > 0)
			{
				[gui setColor:scrollColor forRow:MANIFEST_SCREEN_ROW_BACK];
				[gui setKey:GUI_KEY_OK forRow:MANIFEST_SCREEN_ROW_BACK];
			}
			else
			{
				[gui setColor:noScrollColor forRow:MANIFEST_SCREEN_ROW_BACK];
				r_start = nextPageRow;
			}
			[gui setArray:[NSArray arrayWithObjects:DESC(@"gui-back"), @" <-- ",nil] forRow:MANIFEST_SCREEN_ROW_BACK];

			if (total_rows > max_rows + page_offset)
			{
				[gui setColor:scrollColor forRow:nextPageRow];
				[gui setKey:GUI_KEY_OK forRow:nextPageRow];
			}
			else
			{
				[gui setColor:noScrollColor forRow:nextPageRow];
				r_end = MANIFEST_SCREEN_ROW_BACK;
			}
			[gui setArray:[NSArray arrayWithObjects:DESC(@"gui-more"), @" --> ",nil] forRow:nextPageRow];

			[gui setSelectableRange:NSMakeRange(r_start,r_end+1-r_start)];
			[gui setSelectedRow:r_start];

		}

		[gui setShowTextCursor:NO];
	}
	/* ends */
	
	if (lastTextKey)
	{
		[lastTextKey release];
		lastTextKey = nil;
	}
	
	[self setShowDemoShips:NO];
	[UNIVERSE enterGUIViewModeWithMouseInteraction:NO];
	
	if (guiChanged)
	{
		[gui setForegroundTextureKey:[self status] == STATUS_DOCKED ? @"docked_overlay" : @"overlay"];
		[gui setBackgroundTextureKey:@"manifest"];
		[self noteGUIDidChangeFrom:oldScreen to:gui_screen];
	}
}


- (void) setManifestScreenRow:(id)object inColor:(OOColor*)color forRow:(OOGUIRow)row ofRows:(OOGUIRow)max_rows andOffset:(OOGUIRow)offset inMultipage:(BOOL)multi
{
	OOGUIRow disp_row = row - offset;
	if (disp_row < 1 || disp_row > max_rows) return;
	if (multi) disp_row++;
	GuiDisplayGen	*gui = [UNIVERSE gui];
	if ([object isKindOfClass:[NSString class]])
	{
		[gui setText:(NSString*)object forRow:disp_row];
	}
	else if ([object isKindOfClass:[NSArray class]])
	{
		[gui setArray:(NSArray*)object forRow:disp_row];
	}
	[gui setColor:color forRow:disp_row];
}


- (void) setGuiToDockingReportScreen
{
	GuiDisplayGen	*gui = [UNIVERSE gui];
	
	OOGUIScreenID	oldScreen = gui_screen;
	gui_screen = GUI_SCREEN_REPORT;
	BOOL			guiChanged = (oldScreen != gui_screen);	
	
	OOGUIRow		i, text_row = 1;
	
	dockingReport = oo::str::trimWhitespaceAndNewlines(dockingReport);
	
	// GUI stuff
	{
		[gui clearAndKeepBackground:!guiChanged];
		[gui setTitle:OOExpandKey(@"arrival-report-title")];
		
		for (i=1;i<=18;i++) {
			[gui setColor:[gui cxx_colorFromSetting:std::string(cxx_kGuiDockingReportColor) defaultValue:nil] forRow:21];
		}
		
		// dockingReport might be a multi-line message
		
		while ((!dockingReport.empty())&&(text_row < 18))
		{
			if (dockingReport.find('\n') != std::string::npos)
			{
				while ((dockingReport.find('\n') != std::string::npos)&&(text_row < 18))
				{
					const std::size_t line_break = dockingReport.find('\n');
					const std::string line = dockingReport.substr(0, line_break);
					dockingReport.erase(0, line_break + 1);
					text_row = [gui cxx_addLongText:line startingAtRow:text_row align:GUI_ALIGN_LEFT];
				}
				dockingReport = oo::str::trimWhitespaceAndNewlines(dockingReport);
			}
			else
			{
				text_row = [gui cxx_addLongText:dockingReport startingAtRow:text_row align:GUI_ALIGN_LEFT];
				dockingReport.clear();
			}
		}

		[gui cxx_setText:oo::str::formatRuntime(oo::StdString(DESC_PLURAL(@"contracts-cash-@-load-d-of-d-passengers-d-of-d-berths", max_passengers)), { oo::DescriptionOf(OOCredits(credits)), current_cargo, [self maxAvailableCargoSpace], passengers.size(), max_passengers })  forRow: GUI_ROW_MARKET_CASH];
		[gui setColor:[gui cxx_colorFromSetting:std::string(cxx_kGuiDockingSummaryColor) defaultValue:nil] forRow:GUI_ROW_MARKET_CASH];

		[gui cxx_setText:oo::OptionalString(DESC(@"press-space-commander")) forRow:21 align:GUI_ALIGN_CENTER];
		[gui setColor:[gui cxx_colorFromSetting:std::string(cxx_kGuiDockingContinueColor) defaultValue:nil] forRow:21];
		[gui setShowTextCursor:NO];
	}
	/* ends */
	
	if (lastTextKey)
	{
		[lastTextKey release];
		lastTextKey = nil;
	}
	
	[self setShowDemoShips:NO];
	[UNIVERSE enterGUIViewModeWithMouseInteraction:NO];
	
	if (guiChanged)
	{
		[gui cxx_setForegroundTextureKey:std::string("docked_overlay")];	// has to be docked!

		oo::PList bgDescriptor = oo::PListFrom([UNIVERSE screenTextureDescriptorForKey:@"report"]);
		if (bgDescriptor.isNull()) bgDescriptor = oo::PListFrom([UNIVERSE screenTextureDescriptorForKey:@"status_docked"]);
		if (bgDescriptor.isNull()) bgDescriptor = oo::PListFrom([UNIVERSE screenTextureDescriptorForKey:@"status"]);
		[gui cxx_setBackgroundTextureDescriptor:bgDescriptor];
		[self noteGUIDidChangeFrom:oldScreen to:gui_screen];
	}
}

// ---------------------------------------------------------------------- 

static NSMutableDictionary *currentShipyard = nil;


- (OOCreditsQuantity) priceForShipKey:(NSString *)key
{
	NSDictionary *shipInfo = oo::PListView(currentShipyard).get<NSDictionary *>(key);
	return oo::PListView(shipInfo).get<unsigned long long>(SHIPYARD_KEY_PRICE);
}


- (void) setGuiToShipyardScreen:(NSUInteger)skip
{
	OOGUIScreenID	oldScreen = gui_screen;
	
	GuiDisplayGen	*gui = [UNIVERSE gui];
	gui_screen = GUI_SCREEN_SHIPYARD;
	BOOL			guiChanged = (oldScreen != gui_screen);	
	
	unsigned		i;
	
	// set up initial market if there is none
	OOTechLevelID stationTechLevel;
	StationEntity *station = [self dockedStation];
	
	if (station != nil)
	{
		stationTechLevel = [station equivalentTechLevel];
	}
	else
	{
		station  = [UNIVERSE station];
		stationTechLevel = NSNotFound;
	}
	if ([station localShipyard] == nil)
	{
		[station generateShipyard:stationTechLevel];
	}
		
	NSMutableArray *shipyard = [station localShipyard];
		
	[currentShipyard release];
	currentShipyard = [[NSMutableDictionary alloc] initWithCapacity:[shipyard count]];

	for (i = 0; i < [shipyard count]; i++)
	{
		[currentShipyard setObject:[shipyard objectAtIndex:i]
							forKey:oo::PListView(oo::PListView(shipyard).at<NSDictionary *>(i)).get<NSString *>(SHIPYARD_KEY_ID)];
	}
	
	NSUInteger shipCount = [shipyard count];

	//error check
	if (skip >= shipCount)  skip = shipCount - 1;
	if (skip < 2)  skip = 0;
	
	// GUI stuff
	{
		[gui clearAndKeepBackground:!guiChanged];
		NSString *system = [UNIVERSE getSystemName:system_id];
		[gui setTitle:OOExpandKey(@"shipyard-title", system)];
		
		OOGUITabSettings tab_stops;
		tab_stops[0] = 0;
		tab_stops[1] = -258;
		tab_stops[2] = 270;
		tab_stops[3] = 370;
		tab_stops[4] = 450;
		[gui overrideTabs:tab_stops from:kGuiShipyardTabs length:5];
		[gui setTabStops:tab_stops];
		
		int rowCount = MAX_ROWS_SHIPS_FOR_SALE;
		int startRow = GUI_ROW_SHIPYARD_START;
		NSInteger previous = 0;
		
		if (shipCount <= MAX_ROWS_SHIPS_FOR_SALE)
			skip = 0;
		else
		{
			if (skip > 0)
			{
				rowCount -= 1;
				startRow += 1;
				previous = skip - MAX_ROWS_SHIPS_FOR_SALE + 2;
				if (previous < 2)
					previous = 0;
			}
			if (skip + rowCount < shipCount)
				rowCount -= 1;
		}
		
		if (shipCount > 0)
		{
			[gui setColor:[gui colorFromSetting:kGuiShipyardHeadingColor defaultValue:[OOColor greenColor]] forRow:GUI_ROW_SHIPYARD_LABELS];
			[gui setArray:[NSArray arrayWithObjects:DESC(@"shipyard-shiptype"), DESC(@"shipyard-price-label"),
					DESC(@"shipyard-cargo-label"), DESC(@"shipyard-speed-label"), nil] forRow:GUI_ROW_SHIPYARD_LABELS];

			if (skip > 0)
			{
				[gui setColor:[gui colorFromSetting:kGuiShipyardScrollColor defaultValue:[OOColor greenColor]] forRow:GUI_ROW_SHIPYARD_START];
				[gui setArray:[NSArray arrayWithObjects:DESC(@"gui-back"), @" <-- ", nil] forRow:GUI_ROW_SHIPYARD_START];
				[gui setKey:[NSString stringWithFormat:@"More:%zd", previous] forRow:GUI_ROW_SHIPYARD_START];
			}
			for (i = 0; i < (shipCount - skip) && (int)i < rowCount; i++)
			{
				NSDictionary* ship_info = oo::PListView(shipyard).at<NSDictionary *>(i + skip);
				OOCreditsQuantity ship_price = oo::PListView(ship_info).get<unsigned long long>(SHIPYARD_KEY_PRICE);
				[gui setColor:[gui colorFromSetting:kGuiShipyardEntryColor defaultValue:nil] forRow:startRow + i];
				[gui setArray:[NSArray arrayWithObjects:
						[NSString stringWithFormat:@" %@ ",oo::PListView(oo::PListView(ship_info).get<NSDictionary *>(SHIPYARD_KEY_SHIP)).get<NSString *>(@"display_name", oo::PListView(oo::PListView(ship_info).get<NSDictionary *>(SHIPYARD_KEY_SHIP)).get<NSString *>(KEY_NAME))],
						OOIntCredits(ship_price),
						nil]
					forRow:startRow + i];
				[gui setKey:(NSString*)[ship_info objectForKey:SHIPYARD_KEY_ID] forRow:startRow + i];
			}
			if (i < shipCount - skip)
			{
				[gui setColor:[gui colorFromSetting:kGuiShipyardScrollColor defaultValue:[OOColor greenColor]] forRow:startRow + i];
				[gui setArray:[NSArray arrayWithObjects:DESC(@"gui-more"), @" --> ", nil] forRow:startRow + i];
				[gui setKey:[NSString stringWithFormat:@"More:%zu", rowCount + skip] forRow:startRow + i];
				i++;
			}

			[gui setSelectableRange:NSMakeRange( GUI_ROW_SHIPYARD_START, i + startRow - GUI_ROW_SHIPYARD_START)];
			// ensure that at least one row is selected at all times
			if(shipCount == 1)  [gui setFirstSelectableRow];
			[self showShipyardInfoForSelection];
		}
		else
		{
			[gui setText:DESC(@"shipyard-no-ships-available-for-purchase") forRow:GUI_ROW_NO_SHIPS align:GUI_ALIGN_CENTER];
			[gui setColor:[gui colorFromSetting:kGuiShipyardNoshipColor defaultValue:[OOColor greenColor]] forRow:GUI_ROW_NO_SHIPS];
			
			[gui setNoSelectedRow];
		}
		
		[self showTradeInInformationFooter];
		
		[gui setShowTextCursor:NO];
	}
	
	// the following are necessary...

	[self setShowDemoShips:(shipCount > 0)];
	[UNIVERSE enterGUIViewModeWithMouseInteraction:YES];
	
	if (guiChanged)
	{
		[gui setForegroundTextureKey:@"docked_overlay"];
		[gui setBackgroundTextureKey:@"shipyard"];
	}
}


- (void) showShipyardInfoForSelection
{
	NSUInteger		i;
	GuiDisplayGen	*gui = [UNIVERSE gui];
	OOGUIRow		sel_row = [gui selectedRow];
	
	if (sel_row <= 0)  return;
	
	NSMutableArray *row_info = [NSMutableArray arrayWithArray:(NSArray*)[gui objectForRow:GUI_ROW_SHIPYARD_LABELS]];
	while ([row_info count] < 4)
	{
		[row_info addObject:@""];
	}
	
	NSString *key = [gui keyForRow:sel_row];
	
	NSDictionary *info = oo::PListView(currentShipyard).get<NSDictionary *>(key);

	// clean up the display ready for the newly-selected ship (if there is one)
	[row_info replaceObjectAtIndex:2 withObject:@""];
	[row_info replaceObjectAtIndex:3 withObject:@""];
	for (i = GUI_ROW_SHIPYARD_INFO_START; i < GUI_ROW_MARKET_CASH - 1; i++)
	{
		[gui setText:@"" forRow:i];
		[gui setColor:[gui colorFromSetting:kGuiShipyardDescriptionColor defaultValue:[OOColor greenColor]] forRow:i];
	}
	[UNIVERSE removeDemoShips];

	if (info)
	{
		// the key is a particular ship - show the details
		NSString *salesPitch = oo::PListView(info).get<NSString *>(KEY_SHORT_DESCRIPTION);
		NSDictionary *shipDict = oo::PListView(info).get<NSDictionary *>(SHIPYARD_KEY_SHIP);
		
		int cargoRating = oo::PListView(shipDict).get<int>(@"max_cargo");
		int cargo_extra;
		cargo_extra = oo::PListView(shipDict).get<int>(@"extra_cargo", 15);
		float speedRating = 0.001 * oo::PListView(shipDict).get<int>(@"max_flight_speed");
		
		NSArray *shipExtras = oo::PListView(info).get<NSArray *>(KEY_EQUIPMENT_EXTRAS);
		for (i = 0; i < [shipExtras count]; i++)
		{
			if ([oo::PListView(shipExtras).at<NSString *>(i) isEqualToString:@"EQ_CARGO_BAY"])
			{
				cargoRating += cargo_extra;
			}
			else if ([oo::PListView(shipExtras).at<NSString *>(i) isEqualToString:@"EQ_PASSENGER_BERTH"])
			{
				cargoRating -= PASSENGER_BERTH_SPACE;
			}
		}
		
		[row_info replaceObjectAtIndex:2 withObject:OOExpandKey(@"shipyard-cargo-value", cargoRating)];
		[row_info replaceObjectAtIndex:3 withObject:OOExpandKey(@"shipyard-speed-value", speedRating)];
		
		// Show footer first. It'll be overwritten by the sales_pitch if that text is longer than usual.
		[self showTradeInInformationFooter];
		i = [gui addLongText:salesPitch startingAtRow:GUI_ROW_SHIPYARD_INFO_START align:GUI_ALIGN_LEFT];
		if (i - 1 >= GUI_ROW_MARKET_CASH - 1)
		{
			[gui setColor:[gui colorFromSetting:kGuiShipyardDescriptionColor defaultValue:[OOColor greenColor]] forRow:i - 1];
			[gui setColor:[gui colorFromSetting:kGuiShipyardDescriptionColor defaultValue:[OOColor greenColor]] forRow:GUI_ROW_MARKET_CASH - 1];
		}
		
		// now display the ship
		[self showShipyardModel:oo::PListView(info).get<NSString *>(SHIPYARD_KEY_SHIPDATA_KEY)
					   shipData:shipDict
					personality:oo::PListView(info).get<unsigned short>(SHIPYARD_KEY_PERSONALITY)];
	}
	else
	{
		// the key is a particular model of ship which we must expand...
		// build an array from the entries for that model in the currentShipyard TODO
		// 
	}

	[gui setArray:[NSArray arrayWithArray:row_info] forRow:GUI_ROW_SHIPYARD_LABELS];
}


- (void) showTradeInInformationFooter
{
	GuiDisplayGen *gui = [UNIVERSE gui];
	OOCreditsQuantity tradeIn = [self tradeInValue];
	OOCreditsQuantity total = tradeIn + credits;
	NSString *shipType = [self displayName];
	
	[gui setColor:[gui colorFromSetting:kGuiShipyardTradeinColor defaultValue:nil] forRow:GUI_ROW_MARKET_CASH - 1];
	[gui setColor:[gui colorFromSetting:kGuiShipyardTradeinColor defaultValue:nil] forRow:GUI_ROW_MARKET_CASH];
	[gui setText:OOExpandKey(@"shipyard-trade-in-value", shipType, tradeIn) forRow: GUI_ROW_MARKET_CASH - 1];
	[gui setText:OOExpandKey(@"shipyard-total-available-with-trade-in", shipType, total, credits, tradeIn) forRow: GUI_ROW_MARKET_CASH];
}


- (void) showShipyardModel:(NSString *)shipKey shipData:(NSDictionary *)shipData personality:(uint16_t)personality
{
	if (shipKey == nil || [self dockedStation] == nil)  return;
	[self showShipModelWithKey:shipKey shipData:shipData personality:personality factorX:1.2 factorY:0.8 factorZ:6.4 inContext:@"shipyard"];
}


- (NSInteger) missingSubEntitiesAdjustment
{
	// each missing subentity depreciates the ship by 5%, up to a maximum of 35% depreciation.
	NSUInteger percent = 5 * ([self maxShipSubEntities] - [[[self shipSubEntityEnumerator] allObjects] count]);
	return (percent > 35 ? 35 : percent);
}


- (OOCreditsQuantity) tradeInValue
{
	// returns down to ship_trade_in_factor% of the full credit value of your ship
	
	/*	FIXME: the trade-in value can be more than the sale value, and
		ship_trade_in_factor starts at 100%, so it can be profitable to sit
		and buy the same ship over and over again. This bug predates Oolite
		1.65.
		Partial fix: make effective trade-in value 75% * ship_trade_in_factor%
		of the "raw" trade-in value. This still allows profitability! A better
		solution would be to unify the price calculation for trade-in and
		for-sale ships.
		-- Ahruman 20070707, fix applied 20070708
	*/
	unsigned long long value = [UNIVERSE tradeInValueForCommanderDictionary:[self commanderDataDictionary]];
	value -= value * 0.006 * [self missingSubEntitiesAdjustment];	// TODO: 0.006 might need rethinking.
	value = cunningFee(((value * 75 * ship_trade_in_factor) + 5000) / 10000, 0.005);	// Multiply by two percentages, divide by 100*100. The +5000 is to get normal rounding.
	return value * 10;
}


- (BOOL) buySelectedShip
{
	GuiDisplayGen	*gui = [UNIVERSE gui];
	OOGUIRow		selectedRow = [gui selectedRow];
	
	if (selectedRow <= 0)  return NO;
	
	NSString *key = [gui keyForRow:selectedRow];

	if ([key hasPrefix:@"More:"])
	{
		NSInteger fromShip = oo::PListView([key componentsSeparatedByString:@":"]).at<NSInteger>(1);
		if (fromShip < 0)  fromShip = 0;
		
		[self setGuiToShipyardScreen:fromShip];
		if ([[UNIVERSE gui] selectedRow] < 0)
		{
			[[UNIVERSE gui] setSelectedRow:GUI_ROW_SHIPYARD_START];
		}
		if (fromShip == 0)
		{
			[[UNIVERSE gui] setSelectedRow:GUI_ROW_SHIPYARD_START + MAX_ROWS_SHIPS_FOR_SALE - 1];
		}
		// next bit or the first ship on the list gets wrongly previewed
		// clean up the display
		NSMutableArray *row_info = [NSMutableArray arrayWithArray:(NSArray*)[gui objectForRow:GUI_ROW_SHIPYARD_LABELS]];
		while ([row_info count] < 4)
		{
			[row_info addObject:@""];
		}
		[row_info replaceObjectAtIndex:2 withObject:@""];
		[row_info replaceObjectAtIndex:3 withObject:@""];
		NSUInteger		i;
		for (i = GUI_ROW_SHIPYARD_INFO_START; i < GUI_ROW_MARKET_CASH - 1; i++)
		{
			[gui setText:@"" forRow:i];
			[gui setColor:[gui colorFromSetting:kGuiShipyardDescriptionColor defaultValue:[OOColor greenColor]] forRow:i];
		}
		[gui setArray:[NSArray arrayWithArray:row_info] forRow:GUI_ROW_SHIPYARD_LABELS];
		[UNIVERSE removeDemoShips];
		return YES;
	}

	// first check you can afford it!
	NSDictionary *shipInfo = oo::PListView(currentShipyard).get<NSDictionary *>(key);
	OOCreditsQuantity price = oo::PListView(shipInfo).get<unsigned long long>(SHIPYARD_KEY_PRICE);
	OOCreditsQuantity tradeIn = [self tradeInValue];

	if (credits + tradeIn < price * 10)
		return NO;	// you can't afford it!
	
	// from this point, the player is committed to buying - raise a pre-buy script event
	[self doScriptEvent:OOJSID("playerWillBuyNewShip") 
		withArguments:[NSArray arrayWithObjects:oo::PListView(shipInfo).get<NSString *>(SHIPYARD_KEY_SHIPDATA_KEY), 
			[[[self dockedStation] localShipyard] objectAtIndex:selectedRow - GUI_ROW_SHIPYARD_START], 
			[NSNumber numberWithUnsignedLongLong:price], 
			[NSNumber numberWithUnsignedLongLong:(tradeIn / 10)], nil]];

	// sell all the commodities carried
	NSString *good = nil;
	foreach (good, [shipCommodityData goods])
	{
		[self trySellingCommodity:good all:YES];
	}
	// We tried to sell everything. If there are still items present in our inventory, it
	// means that the market got saturated (quantity in station > 127 t) before we could sell
	// it all. Everything that could not be sold will be lost. -- Nikos 20083012

	// pay over the mazoolah
	credits -= 10 * price - tradeIn;
	
	NSDictionary *shipDict = oo::PListView(shipInfo).get<NSDictionary *>(SHIPYARD_KEY_SHIP);
	[self newShipCommonSetup:oo::PListView(shipInfo).get<NSString *>(SHIPYARD_KEY_SHIPDATA_KEY) yardInfo:shipInfo baseInfo:shipDict];

	// this ship has a clean record
	legalStatus = 0;

	NSArray *extras = oo::PListView(shipInfo).get<NSArray *>(KEY_EQUIPMENT_EXTRAS);
	for (NSUInteger i = 0; i < [extras count]; i++)
	{
		NSString *eq_key = oo::PListView(extras).at<NSString *>(i);
		if ([eq_key isEqualToString:@"EQ_PASSENGER_BERTH"])
		{
			max_passengers++;
			max_cargo -= PASSENGER_BERTH_SPACE;
		}
		else
		{
			[self addEquipmentItem:eq_key withValidation:YES inContext:@"newShip"]; 
		}
	}

	// add bought ship to shipyard_record
	[shipyard_record setObject:[self shipDataKey] forKey:[shipInfo objectForKey:SHIPYARD_KEY_ID]];
	
	// remove the ship from the localShipyard
	[[[self dockedStation] localShipyard] removeObjectAtIndex:selectedRow - GUI_ROW_SHIPYARD_START];
	
	// perform the transformation
	NSDictionary* cmdr_dict = [self commanderDataDictionary];	// gather up all the info
	if (![self setCommanderDataFromDictionary:cmdr_dict])  return NO;

	[self setStatus:STATUS_DOCKED];
	[self setEntityPersonalityInt:oo::PListView(shipInfo).get<unsigned short>(SHIPYARD_KEY_PERSONALITY)];
	
	// adjust the clock forward by an hour
	ship_clock_adjust += 3600.0;
	
	// finally we can get full hock if we sell it back
	ship_trade_in_factor = 100;
	
	if ([UNIVERSE autoSave])  [UNIVERSE setAutoSaveNow:YES];
	
	return YES;
}

- (BOOL) replaceShipWithNamedShip:(NSString *)shipKey
{

	NSDictionary *ship_info = [[OOShipRegistry sharedRegistry] shipyardInfoForKey:shipKey];
	
	NSDictionary *ship_base_dict = [[OOShipRegistry sharedRegistry] shipInfoForKey:shipKey];

	if (ship_info == nil || ship_base_dict == nil) {
		return NO;
	}

	// from this point, the player is committed to replacing - raise a pre-replace script event
	[self doScriptEvent:OOJSID("playerWillReplaceShip") withArgument:shipKey];

	[self newShipCommonSetup:shipKey yardInfo:ship_info baseInfo:ship_base_dict];

	// perform the transformation
	NSDictionary* cmdr_dict = [self commanderDataDictionary];	// gather up all the info
	if (![self setCommanderDataFromDictionary:cmdr_dict])  return NO;

	// refill from ship_info
	NSArray* extras = [NSMutableArray arrayWithArray:oo::PListView(oo::PListView(ship_info).get<NSDictionary *>(KEY_STANDARD_EQUIPMENT)).get<NSArray *>(KEY_EQUIPMENT_EXTRAS)];
	for (unsigned i = 0; i < [extras count]; i++)
	{
		NSString* eq_key = oo::PListView(extras).at<NSString *>(i);
		if ([eq_key isEqualToString:@"EQ_PASSENGER_BERTH"])
		{
			max_passengers++;
			max_cargo -= PASSENGER_BERTH_SPACE;
		}
		else
		{
			[self addEquipmentItem:eq_key withValidation:YES inContext:@"newShip"]; 
		}
	}

	[self setEntityPersonalityInt:oo::PListView(ship_info).get<unsigned short>(SHIPYARD_KEY_PERSONALITY)];
	
	return YES;
}

- (void) newShipCommonSetup:(NSString *)shipKey yardInfo:(NSDictionary *)ship_info baseInfo:(NSDictionary *)ship_base_dict 
{
	// Zero out our manifest.
	[shipCommodityData removeAllGoods];
	current_cargo = 0;
	
	// drop all passengers
	passengers.clear();
	passenger_record.clear(); 
		
	// parcels stay the same; easy to transfer between ships
	// contracts stay the same, so if you default - tough!
	// okay we need to switch the model used, lots of the stats, and add all the extras
	
	[self clearSubEntities];

	[self setShipDataKey:shipKey];

	NSDictionary *shipDict = ship_base_dict;


	// get a full tank for free
	[self setFuel:[self fuelCapacity]];
	
	// get forward_weapon aft_weapon port_weapon starboard_weapon from ship_info
	int base_facings = oo::PListView(shipDict).get<unsigned int>(KEY_WEAPON_FACINGS, 15);
	int available_facings = oo::PListView(ship_info).get<unsigned int>(KEY_WEAPON_FACINGS, base_facings);

	// not retained - weapon types are references to the objects in OOEquipmentType's cache
	if (available_facings & WEAPON_FACING_AFT)
		aft_weapon_type = OOWeaponTypeFromEquipmentIdentifierSloppy(oo::PListView(shipDict).get<NSString *>(@"aft_weapon_type"));
	else
		aft_weapon_type = OOWeaponTypeFromEquipmentIdentifierSloppy(@"EQ_WEAPON_NONE");

	if (available_facings & WEAPON_FACING_PORT)
		port_weapon_type = OOWeaponTypeFromEquipmentIdentifierSloppy(oo::PListView(shipDict).get<NSString *>(@"port_weapon_type"));
	else
		port_weapon_type = OOWeaponTypeFromEquipmentIdentifierSloppy(@"EQ_WEAPON_NONE");

	if (available_facings & WEAPON_FACING_STARBOARD)
		starboard_weapon_type = OOWeaponTypeFromEquipmentIdentifierSloppy(oo::PListView(shipDict).get<NSString *>(@"starboard_weapon_type"));
	else
		starboard_weapon_type = OOWeaponTypeFromEquipmentIdentifierSloppy(@"EQ_WEAPON_NONE");

	if (available_facings & WEAPON_FACING_FORWARD)
		forward_weapon_type = OOWeaponTypeFromEquipmentIdentifierSloppy(oo::PListView(shipDict).get<NSString *>(@"forward_weapon_type"));
	else
		forward_weapon_type = OOWeaponTypeFromEquipmentIdentifierSloppy(@"EQ_WEAPON_NONE");
	
	// new ships start with weapons online
	weapons_online = 1;

	// get basic max_cargo
	max_cargo = [UNIVERSE maxCargoForShip:[self shipDataKey]];

	// ensure all missiles are tidied up and start at pylon 0
	[self tidyMissilePylons];

	// get missiles from ship_info
	missiles = oo::PListView(shipDict).get<unsigned int>(@"missiles");
	
	// reset max_passengers
	max_passengers = 0;
	
	// reset and refill extra_equipment then set flags from it
	
	// keep track of portable equipment..

	NSMutableSet	*portable_equipment = [NSMutableSet set];
	NSEnumerator	*eqEnum = nil;
	NSString		*eq_desc = nil;
	OOEquipmentType	*item = nil;
	
	for (eqEnum = [self equipmentEnumerator]; (eq_desc = [eqEnum nextObject]);)
	{
		item = [OOEquipmentType equipmentTypeWithIdentifier:eq_desc];
		if ([item isPortableBetweenShips])  [portable_equipment addObject:eq_desc];
	}
	
	// remove ALL
	[self removeAllEquipment];
	
	// restore  portable equipment
	for (eqEnum = [portable_equipment objectEnumerator]; (eq_desc = [eqEnum nextObject]); )
	{
		[self addEquipmentItem:eq_desc withValidation:NO inContext:@"portable"];
	}


	// set up subentities from scratch; new ship could carry more or fewer than the old one
	[self setUpSubEntities];

	// clear old ship names
	[self setShipClassName:oo::PListView(shipDict).get<NSString *>(@"name")];
	[self setShipUniqueName:@""];

	// new ship, so lose some memory of actions
	// new ship, so lose some memory of player actions
	if (ship_kills >= 6400)
	{
		[self clearRolesFromPlayer:0.1];
	}
	else if (ship_kills >= 2560)
	{
		[self clearRolesFromPlayer:0.25];
	}
	else
	{
		[self clearRolesFromPlayer:0.5];
	}	

}

@end

static unsigned RepForRisk(unsigned risk)
{
	switch (risk)
	{
	case 0:
		return 1;
	case 1:
		return 2;
	case 2:
	default:
		return 4;
	}
}
