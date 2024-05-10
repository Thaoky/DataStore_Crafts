--[[	*** DataStore_Crafts ***
Written by : Thaoky, EU-Marécages de Zangar
June 23rd, 2009
--]]
if not DataStore then return end

local addonName, addon = ...
local thisCharacter
local reagentsDB, recipeCategoriesDB

local DataStore, TableConcat, TableInsert, format, gsub, type = DataStore, table.concat, table.insert, format, gsub, type
local GetProfessions, GetProfessionInfo, GetSpellInfo = GetProfessions, GetProfessionInfo, GetSpellInfo
local C_TradeSkillUI = C_TradeSkillUI

-- *** Utility functions ***
local bit64 = LibStub("LibBit64")

local function GetRecipeRank(info)
	local currentRank = 0
	local totalRanks = 1
	local highestRankID = info.recipeID

	-- Go back to the first rank of the recipe
	while info.previousRecipeID do
		info = C_TradeSkillUI.GetRecipeInfo(info.previousRecipeID)
	end

	-- if this happens, the level 1 recipe is not known, so set it as highest rank (even if we came from level 2)
	if not info.learned then
		highestRankID = info.recipeID
	end
	
	-- Loop until the last rank
	while info.nextRecipeID do
		totalRanks = totalRanks + 1
		if info.learned then
			currentRank = currentRank + 1
			highestRankID = info.recipeID
		end
		info = C_TradeSkillUI.GetRecipeInfo(info.nextRecipeID)
	end
	
	-- process the last item
	if info.learned then
		currentRank = currentRank + 1
		highestRankID = info.recipeID
	end
	
	return currentRank, totalRanks, highestRankID
end

local function SetProfessionIndex(name, index)
	-- [1] = prof 1, [2] = prof 2, [3] = cooking, [4] = fishing, [5] = archeo (retail) or first aid (classic)
	thisCharacter.Indices[name] = index
end

local function SetProfessionRank(index, rank, maxRank)
	thisCharacter.Ranks[index] = rank + bit64:LeftShift(maxRank, 16)		-- bits 16+ = max rank
end

-- *** Scanning functions ***

local function ScanProfessionInfo(index, mainIndex)
	-- index may be nil if the profession has not been learned at all
	if not index then return end
	
	local name, texture, rank, maxRank, _, _, _, _, _, _, currentLevelName = GetProfessionInfo(index)
	
	-- Is it archeology ?
	if mainIndex == 5 then
		-- just save the rank for archeology
		SetProfessionRank(mainIndex, rank, maxRank)
	-- else
	end
	
	SetProfessionIndex(name, mainIndex)
	
	-- for all other professions, save some info
	local char = thisCharacter
	char.Professions[mainIndex] = char.Professions[mainIndex] or {}
	
	local profession = char.Professions[mainIndex]
	profession.Name = name
	profession.CurrentLevelName = currentLevelName
	-- end
end

local function ScanProfessionLinks()
	local prof1, prof2, arch, fish, cook = GetProfessions()

	ScanProfessionInfo(prof1, 1)
	ScanProfessionInfo(prof2, 2)
	ScanProfessionInfo(cook, 3)
	ScanProfessionInfo(fish, 4)
	ScanProfessionInfo(arch, 5)
	
	thisCharacter.lastUpdate = time()
	
	DataStore:Broadcast("DATASTORE_PROFESSION_LINKS_UPDATED")
end

local function ScanRecipeCategories(profession, professionIndex)
	-- clear storage
	profession.CategoryInfo = profession.CategoryInfo or {}
	wipe(profession.CategoryInfo)
	profession.Categories = profession.Categories or {}
	wipe(profession.Categories)
	
	local cumulatedRank = 0
	local cumulatedMaxRank = 0
	
	-- loop through this profession's categories
	for _, id in ipairs( { C_TradeSkillUI.GetCategories() } ) do
		local info = C_TradeSkillUI.GetCategoryInfo(id)
		
		cumulatedRank = cumulatedRank + (info.skillLineCurrentLevel or 0)
		cumulatedMaxRank = cumulatedMaxRank + (info.skillLineMaxLevel or 0)
		recipeCategoriesDB[info.categoryID] = info.name
	
		-- Save the ranks of the current category
		local attributes = info.skillLineCurrentLevel			-- bits 0-9 rank
				+ bit64:LeftShift(info.skillLineMaxLevel, 10)	-- bits 10-19 = max rank
				+ bit64:LeftShift(info.categoryID, 20)				-- bits 20 = categoryID
	
		TableInsert(profession.CategoryInfo, attributes)
		
		-- save the names of subcategories
		local subCats = { C_TradeSkillUI.GetSubCategories(info.categoryID) }
		for _, subCatID in pairs(subCats) do
			local subCatInfo = C_TradeSkillUI.GetCategoryInfo(subCatID)
			
			recipeCategoriesDB[subCatInfo.categoryID] = subCatInfo.name
		end
		TableInsert(profession.Categories, subCats)
		
	end
	
	SetProfessionRank(professionIndex, cumulatedRank, cumulatedMaxRank)
end

local function ScanRecipes()
	
	local info = C_TradeSkillUI.GetBaseProfessionInfo()
	local tradeskillName = info.professionName

	if not tradeskillName or tradeskillName == "UNKNOWN" then return end	-- may happen after a patch, or under extreme lag, so do not save anything to the db !

	local char = thisCharacter
	local professionIndex = char.Indices[tradeskillName]
	local profession = char.Professions[professionIndex]
	
	ScanRecipeCategories(profession, professionIndex)
	
	-- Get profession link
	local profLink = C_TradeSkillUI.GetTradeSkillListLink()
	if profLink then	-- sometimes a nil value may be returned, so keep the old one if nil
		-- link format : "|cffffd000|Htrade:Player-1621-0001B345:195126:197|h[Tailoring]|h|r"
		local _, arg1, arg2 = profLink:match("|Htrade:(.-):(.-):(.-)|h")
		arg1 = tonumber(arg1)	-- 195126 in this example
		arg2 = tonumber(arg2)	-- 197 in this example
		
		profession.FullLink = arg2 + bit64:LeftShift(arg1, 16)		-- bits 16+ = arg1
	end
	
	profession.Crafts = profession.Crafts or {}
	local crafts = profession.Crafts
	wipe(crafts)
		
	local recipes = C_TradeSkillUI.GetAllRecipeIDs()
	if not recipes or (#recipes == 0) then return end

	for i, recipeID in pairs(recipes) do
		-- Get recipe info
		local info = C_TradeSkillUI.GetRecipeInfo(recipeID)
		local recipeRank, totalRanks, highestRankID = GetRecipeRank(info)
		
		-- if we are rank 2 out of 3 for a recipe, do not save rank 1 and rank 3
		if recipeID == highestRankID then
		
			-- save the recipe
			crafts[info.categoryID] = crafts[info.categoryID] or {}
			TableInsert(crafts[info.categoryID], 
				info.relativeDifficulty 
				+ bit64:LeftShift((info.learned == true) and 1 or 0, 2) 	-- bit 2 => 1 = learned, 0 = not learned
				+ bit64:LeftShift(recipeRank, 3)		-- bits 3-4 = recipe rank
				+ bit64:LeftShift(totalRanks, 5)		-- bits 5-6 = max rank
				+ bit64:LeftShift(recipeID, 7))		-- bits 7+ = recipeID
		end
		
		-- scan cooldown
		local cooldown = C_TradeSkillUI.GetRecipeCooldown(recipeID)
		if cooldown then
			profession.Cooldowns = profession.Cooldowns or {}
			
			-- ex: "Hexweave Cloth|86220|1533539676" expire at "now + cooldown"
			TableInsert(profession.Cooldowns, format("%s|%d|%d", info.name, cooldown, cooldown + time()))
		end
	end
	
	DataStore:Broadcast("DATASTORE_RECIPES_SCANNED", char, tradeskillName)
end

local function ScanTradeSkills()
	ScanRecipes()
	thisCharacter.lastUpdate = time()
end


-- *** Event Handlers ***

local function OnTradeSkillClose()
	addon:StopListeningTo("TRADE_SKILL_CLOSE")
	addon.isOpen = nil
end

local currentCraftRecipeID

local function OnTradeSkillListUpdate(self)
	if not currentCraftRecipeID then return end
	
	local cooldown = C_TradeSkillUI.GetRecipeCooldown(currentCraftRecipeID)
	if cooldown then
		ScanRecipes()
		DataStore:Broadcast("DATASTORE_PROFESSION_COOLDOWN_UPDATED")
		currentCraftRecipeID = nil
	end
end

local function OnTradeSkillShow()
	if C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild() or C_TradeSkillUI.IsNPCCrafting() then return end
	
	hooksecurefunc(C_TradeSkillUI, "CraftRecipe", function(recipeID)
		currentCraftRecipeID = recipeID
	end)
	
	addon:ListenTo("TRADE_SKILL_CLOSE", OnTradeSkillClose)
	addon.isOpen = true
end

-- this turns
--	"Your skill in %s has increased to %d."
-- into
--	"Your skill in (.+) has increased to (%d+)."
local arg1pattern, arg2pattern
if GetLocale() == "deDE" then		
	-- ERR_SKILL_UP_SI = "Eure Fertigkeit '%1$s' hat sich auf %2$d erhöht.";
	arg1pattern = "'%%1%$s'"
	arg2pattern = "%%2%$d"
else
	arg1pattern = "%%s"
	arg2pattern = "%%d"
end

local skillUpMsg = gsub(ERR_SKILL_UP_SI, arg1pattern, "(.+)")
skillUpMsg = gsub(skillUpMsg, arg2pattern, "(%%d+)")

local function OnChatMsgSkill(self, message)
	if not message then return end

	-- Check it is the right type of message
	local skill = message:match(skillUpMsg)
	if not skill then return end
	
	local info = C_TradeSkillUI.GetChildProfessionInfo()
	-- if we gained a skill point in the currently opened profession pane, rescan
	if skill == info.professionName then	
		ScanTradeSkills()
	end

	ScanProfessionLinks() -- added to update skills upon firing of skillup event 
end


local unlearnMsg = gsub(ERR_SPELL_UNLEARNED_S, arg1pattern, "(.+)")

local function OnChatMsgSystem(self, message)
	if not message then return end

	-- Check it is the right type of message
	local skillLink = message:match(unlearnMsg)
	if not skillLink then return end

	-- Check it is a proper profession
	local skillName = skillLink:match("%[(.+)%]")
	if skillName then
		
		-- Clear the list of recipes
		local char = thisCharacter
		wipe(char.Professions[skillName])
		char.Professions[skillName] = nil
	end
			
	-- this won't help, as GetProfessions does not return the right values right after the profession has been abandoned.
	-- The problem of listing Prof1 & Prof2 with potentially the same value fixes itself after the next logon though.
	-- Until I find more time to work around this issue, we will live with it .. it's not like players are abandoning professions 100x / day :)
	-- ScanProfessionLinks()	
end


-- ** Mixins **

local function GetCategoryName(id)
	return recipeCategoriesDB[id]
end

local function _GetNumRecipeCategories(profession)
	return profession.Categories and #profession.Categories or 0
end

local function _GetRecipeCategoryInfo(profession, index)
	local info = profession.CategoryInfo[index]
	
	local rank = bit64:GetBits(info, 0, 10)
	local maxRank = bit64:GetBits(info, 10, 10)
	local categoryID = bit64:RightShift(info, 20)
	
	return categoryID, GetCategoryName(categoryID), rank, maxRank
end

local function _GetNumRecipeCategorySubItems(profession, index)
	return #profession.Categories[index]
end

local function _GetRecipeSubCategoryInfo(profession, catIndex, subCatIndex)
	local catID = profession.Categories[catIndex][subCatIndex]
	
	-- return real category id, name, and list of recipes
	return catID, GetCategoryName(catID), profession.Crafts[catID]
end

local function _GetRecipeInfo(recipeData)
	local color = bit64:GetBits(recipeData, 0, 2)	-- Bits 0-1 = color
	local isLearned = bit64:TestBit(recipeData, 2) 	-- Bit 2 = isLearned
	local recipeRank = bit64:GetBits(recipeData, 3, 2)		-- bits 3-4 = recipe rank
	local totalRanks = bit64:GetBits(recipeData, 5, 2)		-- bits 5-6 = max rank
	local recipeID = bit64:RightShift(recipeData, 7)		-- bits 7+ = recipeID
	
	-- local minMade = bit64:GetBits(recipeData, 7, 8)		-- bits 7-14 = minMade (8 bits)
	-- local maxMade = bit64:GetBits(recipeData, 15, 8)	-- bits 15-22 = maxMade (8 bits)
	
	return color, recipeID, isLearned, recipeRank, totalRanks, minMade, maxMade
end

-- Iterate through all recipes, and callback a function for each of them
local function _IterateRecipes(profession, mainCategory, subCategory, callback)
	-- mainCategory : category index (or 0 for all)
	-- subCategory : sub-category index (or 0 for all)
	local crafts = profession.Crafts
	
	-- loop through categories
	for catIndex = 1, _GetNumRecipeCategories(profession) do
		-- if there is no filter on main category, or if it is just the one we want to see
		if (mainCategory == 0) or (mainCategory == catIndex) then
			-- loop through subcategories
			for subCatIndex = 1, _GetNumRecipeCategorySubItems(profession, catIndex) do
				-- if there is no filter on sub category, or if it is just the one we want to see
				if (subCategory == 0) or (subCategory == subCatIndex) then
					local subCatID, _, recipes = _GetRecipeSubCategoryInfo(profession, catIndex, subCatIndex)
					
					if type(recipes) == "table" then
						-- loop through recipes
						for i = 1, #recipes do
							local stop = callback(recipes[i])
							
							-- exit if the callback returns true
							if stop then return end
						end
					end
				end
			end
		end
	end
end

local function _GetNumRecipesByColor(profession)
	-- counts the number of orange, yellow, green and grey recipes.
	local counts = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 }
	
	_IterateRecipes(profession, 0, 0, function(recipeData) 
		local color = _GetRecipeInfo(recipeData)
		counts[color] = counts[color] + 1
	end)
	
	return counts[3], counts[2], counts[1], counts[0]		-- orange, yellow, green, grey
end

local function _IsCraftKnown(profession, spellID)
	-- returns true if a given spell ID is known in the profession passed as first argument
	local isKnown
	
	_IterateRecipes(profession, 0, 0, function(recipeData) 
		local _, recipeID, isLearned = _GetRecipeInfo(recipeData)
		if recipeID == spellID and isLearned then
			isKnown = true
			return true	-- stop iteration
		end
	end)

	return isKnown
end

DataStore:OnAddonLoaded(addonName, function() 
	DataStore:RegisterModule({
		addon = addon,
		addonName = addonName,
		rawTables = {
			"DataStore_Crafts_RecipeCategories",	-- [categoryID] = name
		},
		characterTables = {
			["DataStore_Crafts_Characters"] = {},
		}
	})
	
	DataStore:RegisterMethod(addon, "IsCraftKnown", _IsCraftKnown)
	DataStore:RegisterMethod(addon, "GetRecipeInfo", _GetRecipeInfo)
	DataStore:RegisterMethod(addon, "IterateRecipes", _IterateRecipes)
	DataStore:RegisterMethod(addon, "GetNumRecipeCategories", _GetNumRecipeCategories)
	DataStore:RegisterMethod(addon, "GetNumRecipeCategorySubItems", _GetNumRecipeCategorySubItems)
	DataStore:RegisterMethod(addon, "GetNumRecipesByColor", _GetNumRecipesByColor)
	DataStore:RegisterMethod(addon, "GetRecipeCategoryInfo", _GetRecipeCategoryInfo)
	DataStore:RegisterMethod(addon, "GetRecipeSubCategoryInfo", _GetRecipeSubCategoryInfo)
	

	thisCharacter = DataStore:GetCharacterDB("DataStore_Crafts_Characters", true)
	thisCharacter.Ranks = thisCharacter.Ranks or {}
	thisCharacter.Indices = thisCharacter.Indices or {}
	thisCharacter.Professions = thisCharacter.Professions or {}
	recipeCategoriesDB = DataStore_Crafts_RecipeCategories
end)

DataStore:OnPlayerLogin(function()
	addon:ListenTo("PLAYER_ALIVE", ScanProfessionLinks)
	addon:ListenTo("TRADE_SKILL_SHOW", OnTradeSkillShow)
	addon:ListenTo("CHAT_MSG_SKILL", OnChatMsgSkill)
	addon:ListenTo("CHAT_MSG_SYSTEM", OnChatMsgSystem)
	addon:ListenTo("TRADE_SKILL_DATA_SOURCE_CHANGED", ScanTradeSkills)
	addon:ListenTo("TRADE_SKILL_LIST_UPDATE", OnTradeSkillListUpdate)
end)

function addon:IsTradeSkillWindowOpen()
	-- note : maybe there's a function in the WoW API to test this, but I did not find it :(
	return addon.isOpen
end