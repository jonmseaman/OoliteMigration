/*

ResourceManager+ObjCBridge.mm

TRANSITIONAL (proposed ADR-0056, bead oo-jfno): the Objective-C ResourceManager facade. Every class
method of slice 1 forwards to the static member of cxx::ResourceManager in one line; the category
of slices 2-4 is in ResourceManager.mm. See ResourceManager+ObjCBridge.h.

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

#import "ResourceManager.h"


@implementation ResourceManager

+ (void) reset
{
	cxx::ResourceManager::reset();
}


+ (void) resetManifestKnowledgeForOXZManager
{
	cxx::ResourceManager::resetManifestKnowledgeForOXZManager();
}


+ (std::vector<std::string>) cxx_rootPaths
{
	return cxx::ResourceManager::rootPaths();
}


+ (std::vector<std::string>) cxx_userRootPaths
{
	return cxx::ResourceManager::userRootPaths();
}


+ (std::optional<std::string>) cxx_builtInPath
{
	return cxx::ResourceManager::builtInPath();
}


+ (std::vector<std::string>) cxx_pathsWithAddOns
{
	return cxx::ResourceManager::pathsWithAddOns();
}


+ (std::vector<std::string>) cxx_paths
{
	return cxx::ResourceManager::paths();
}


+ (std::vector<std::string>) cxx_maskUserNameInPathArray:(const std::vector<std::string> &)inputPathArray
{
	return cxx::ResourceManager::maskUserNameInPathArray(inputPathArray);
}


+ (std::optional<std::string>) cxx_maskUserName:(const std::string &)name inPath:(const std::string &)path
{
	return cxx::ResourceManager::maskUserName(name, path);
}


+ (std::optional<std::string>) cxx_useAddOns
{
	return cxx::ResourceManager::useAddOns();
}


+ (std::vector<std::string>) cxx_OXPsWithMessagesFound
{
	return cxx::ResourceManager::OXPsWithMessagesFound();
}


+ (void) cxx_setUseAddOns:(const std::string &)useAddOns
{
	cxx::ResourceManager::setUseAddOns(useAddOns);
}


+ (void) cxx_addExternalPath:(const std::string &)fileName
{
	cxx::ResourceManager::addExternalPath(fileName);
}


+ (oo::PList) cxx_manifestForIdentifier:(const std::string &)identifier
{
	return cxx::ResourceManager::manifestForIdentifier(identifier);
}


+ (std::optional<std::string>) cxx_errors
{
	return cxx::ResourceManager::errors();
}


+ (void) clearCaches
{
	cxx::ResourceManager::clearCaches();
}

@end
