local addonName, addon = ...

local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

local TableRemove, strsplit, type, tonumber, GetSpellInfo = table.remove, strsplit, type, tonumber, GetSpellInfo

-- *** Utility functions ***
local bit64 = LibStub("LibBit64")
local professionIndices = {
	Profession1 = 1,
	Profession2 = 2,
	Cooking = 3,
	Fishing = 4,
	Archeology = 5,	-- retail & cata
	FirstAid = 6,		-- cata
}

local function _GetProfessionRankByIndex(character, professionIndex)
	local attrib = character.Ranks[professionIndex]
	
	local rank = attrib and bit64:GetBits(attrib, 0, 16) or 0
	local maxRank = attrib and bit64:RightShift(attrib, 16) or 0

	return rank, maxRank
end

local function _GetProfessionRank(character, professionName)
	local index = character.Indices[professionName]
	if index then
		return _GetProfessionRankByIndex(character, index)
	end
end

local function _GetCraftCooldownInfo(profession, index)
	-- exit if the table does not exist
	if not profession.Cooldowns then return end
		
	local cooldown = profession.Cooldowns[index]
	local name, resetsIn, expiresAt = strsplit("|", cooldown)
	
	resetsIn = tonumber(resetsIn)
	expiresAt = tonumber(expiresAt)	
	local expiresIn = expiresAt - time()
	
	return name, expiresIn, resetsIn, expiresAt
end

DataStore:OnAddonLoaded(addonName, function() 
	DataStore:RegisterTables({
		addon = addon,
		characterTables = {
			["DataStore_Crafts_Characters"] = {
				GetProfession = function(character, name)
					local index = character.Indices[name]		-- Get the profession index
					return character.Professions[index]
				end,
				GetProfessionByIndex = function(character, index)
					return character.Professions[index]
				end,
				GetProfessions = function(character) return character.Professions	end,
				IsProfessionKnown = function(character, professionName)
					if (character.Professions[1] and character.Professions[1].Name == professionName) or
						(character.Professions[2] and character.Professions[2].Name == professionName) then 
						return true 
					end
				end,
				GetProfessionLink = function(character, index) 
					local profession = character.Professions[index]
					if not profession then return end
					
					local guid = DataStore:GetCharacterGUID(character)
					local link = profession.FullLink
					local arg1 = bit64:RightShift(link, 16)
					local arg2 = bit64:GetBits(link, 0, 16)
					
					return format("|cffffd000|Htrade:%s:%d:%d|h[%s]|h|r", guid, arg1, arg2, profession.Name)
				end,
				
				GetProfession1Name = function(character)
					local profession = character.Professions[1]
					return profession and profession.Name or ""
				end,
				GetProfession2Name = function(character)
					local profession = character.Professions[2]
					return profession and profession.Name or ""
				end,

				-- Profession ranks
				GetProfessionRank = _GetProfessionRank,
				GetProfessionRankByIndex = function(character, index) return _GetProfessionRankByIndex(character, index) end,
				GetProfession1Rank = function(character) return _GetProfessionRankByIndex(character, 1) end,
				GetProfession2Rank = function(character) return _GetProfessionRankByIndex(character, 2) end,
				GetCookingRank = function(character) return _GetProfessionRankByIndex(character, 3) end,
				GetFishingRank = function(character) return _GetProfessionRankByIndex(character, 4) end,
				GetFirstAidRank = (not isRetail) and function(character) return _GetProfessionRankByIndex(character, 5) end,
				GetArchaeologyRank = isRetail and function(character) return _GetProfessionRankByIndex(character, 5) end,
			},
		}
	})
	
	DataStore:RegisterMethod(addon, "GetProfessionIndices", function() return professionIndices end)
	DataStore:RegisterMethod(addon, "GetCraftCooldownInfo", _GetCraftCooldownInfo)
	DataStore:RegisterMethod(addon, "GetNumActiveCooldowns", function(profession)
		return profession.Cooldowns and #profession.Cooldowns or 0
	end)
	DataStore:RegisterMethod(addon, "ClearExpiredCooldowns", function(profession)
		-- exit if the table does not exist
		if not profession.Cooldowns then return end
		
		-- from last to first, to avoid messing up indexes when removing entries
		for i = #profession.Cooldowns, 1, -1 do
			local _, expiresIn = _GetCraftCooldownInfo(profession, i)
			if expiresIn <= 0 then		-- already expired ? remove it
				TableRemove(profession.Cooldowns, i)
			end
		end

		-- after clearing, delete the table if there are none left
		if #profession.Cooldowns == 0 then
			profession.Cooldowns = nil
		end
	end)
	DataStore:RegisterMethod(addon, "GetCraftResultItem", function(recipeID)
		-- local itemData = resultItemsDB[recipeID]
		-- if itemData then
			-- maxMade (bits 0-7), itemID (bits 8+)
			-- return bit64:GetBits(itemData, 0, 8), bit64:RightShift(itemData, 8)
		-- end
		
		local schematic = C_TradeSkillUI.GetRecipeSchematic(recipeID, false)
		return schematic.outputItemID, schematic.quantityMax
	end)
end)
