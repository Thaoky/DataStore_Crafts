--[[	*** DataStore_Crafts ***
Written by : Thaoky, EU-Marécages de Zangar
June 23rd, 2009
--]]
if not DataStore then return end

local addonName, addon = ...
local thisCharacter
-- local reagentsDB, resultItemsDB, recipeCategoriesDB

local L = DataStore:GetLocale("DataStore_Crafts")

local TableConcat, TableInsert, TableRemove, format = table.concat, table.insert, table.remove, format
local GetTradeSkillSelectionIndex, GetTradeSkillSubClasses, GetTradeSkillInvSlots, GetSubClassID, GetInvSlotID = GetTradeSkillSelectionIndex, GetTradeSkillSubClasses, GetTradeSkillInvSlots, GetSubClassID, GetInvSlotID
local GetTradeSkillSubClassFilter, GetTradeSkillInvSlotFilter, SetTradeSkillSubClassFilter, SetTradeSkillInvSlotFilter = GetTradeSkillSubClassFilter, GetTradeSkillInvSlotFilter, SetTradeSkillSubClassFilter, SetTradeSkillInvSlotFilter
local UIDropDownMenu_SetSelectedID, UIDropDownMenu_SetText, TradeSkillSubClassDropDown, TradeSkillInvSlotDropDown = UIDropDownMenu_SetSelectedID, UIDropDownMenu_SetText, TradeSkillSubClassDropDown, TradeSkillInvSlotDropDown
local SelectTradeSkill, GetNumTradeSkills, GetTradeSkillInfo, ExpandTradeSkillSubClass, CollapseTradeSkillSubClass = SelectTradeSkill, GetNumTradeSkills, GetTradeSkillInfo, ExpandTradeSkillSubClass, CollapseTradeSkillSubClass
local GetProfessions, GetProfessionInfo, GetSpellInfo, GetNumSkillLines, GetSkillLineInfo, ExpandSkillHeader = GetProfessions, GetProfessionInfo, GetSpellInfo, GetNumSkillLines, GetSkillLineInfo, ExpandSkillHeader
local GetTradeSkillLine, GetTradeSkillCooldown, GetTradeSkillListLink, GetTradeSkillRecipeLink = GetTradeSkillLine, GetTradeSkillCooldown, GetTradeSkillListLink, GetTradeSkillRecipeLink
local GetTradeSkillNumReagents, GetTradeSkillReagentInfo, GetTradeSkillReagentItemLink, GetTradeSkillItemLink = GetTradeSkillNumReagents, GetTradeSkillReagentInfo, GetTradeSkillReagentItemLink, GetTradeSkillItemLink
local GetCraftDisplaySkillLine, GetCraftInfo, GetCraftNumReagents, GetCraftReagentInfo, GetCraftReagentItemLink = GetCraftDisplaySkillLine, GetCraftInfo, GetCraftNumReagents, GetCraftReagentInfo, GetCraftReagentItemLink
local C_TradeSkillUI, C_Timer = C_TradeSkillUI, C_Timer

local isCata = (WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC)


local AddonDB_Defaults = {
	global = {
		Characters = {
			['*'] = {				-- ["Account.Realm.Name"] 
				lastUpdate = nil,
				Professions = {
					['*'] = {
						FullLink = nil,		-- Tradeskill link
						Rank = 0,
						MaxRank = 0,
						Icon = nil,
						Crafts = {},
						Categories = {}, 
						Cooldowns = { ['*'] = nil },		-- list of active cooldowns
					}
				},

			}
		}
	}
}

local SPELL_ID_ARCHAEOLOGY = 78670
local SPELL_ID_COOKING = 2550
local SPELL_ID_FISHING = 7732			-- do not use 7733, it's "Artisan Fishing", not "Fishing"
local SPELL_ID_FIRSTAID = 3273

-- *** Utility functions ***
local bit64 = LibStub("LibBit64")

-- *** Scanning functions ***

local selectedTradeSkillIndex
local subClasses, subClassID
local invSlots, invSlotID

local function GetSubClassID()
	-- The purpose of this function is to get the subClassID in a UI independant way
	-- ie: without relying on UIDropDownMenu_GetSelectedID(TradeSkillSubClassDropDown), which uses a hardcoded frame name.
	
	if GetTradeSkillSubClassFilter(0) then		-- if "All Subclasses" is selected, GetTradeSkillSubClassFilter() will return 1 for all indexes, including 0
		return 1				-- thus return 1 as selected id	(as would be returned by UIDropDownMenu_GetSelectedID(TradeSkillSubClassDropDown))
	end

	local isEnabled
	for i = 1, #subClasses do
	   isEnabled = GetTradeSkillSubClassFilter(i)
	   if isEnabled then
	      return i+1			-- ex: 3rd element of the subClasses array, but 4th in the dropdown due to "All Subclasses", so return i+1
	   end
	end
end

local function GetInvSlotID()
	-- The purpose of this function is to get the invSlotID in a UI independant way	(same as GetSubClassID)
	-- ie: without relying on UIDropDownMenu_GetSelectedID(TradeSkillInvSlotDropDown), which uses a hardcoded frame name.

	if GetTradeSkillInvSlotFilter(0) then		-- if "All Slots" is selected, GetTradeSkillInvSlotFilter() will return 1 for all indexes, including 0
		return 1				-- thus return 1 as selected id	(as would be returned by  UIDropDownMenu_GetSelectedID(TradeSkillInvSlotDropDown))
	end

	local filter
	for i = 1, #invSlots do
	   filter = GetTradeSkillInvSlotFilter(i)
	   if filter then
	      return i+1			-- ex: 3rd element of the invSlots array, but 4th in the dropdown due to "All Slots", so return i+1
	   end
	end
end

local function SaveActiveFilters()
	selectedTradeSkillIndex = GetTradeSkillSelectionIndex()
	
	subClasses = { GetTradeSkillSubClasses() }
	invSlots = { GetTradeSkillInvSlots() }
	subClassID = GetSubClassID()
	invSlotID = GetInvSlotID()
	
	-- Subclasses
	SetTradeSkillSubClassFilter(0, 1, 1)	-- this checks "All subclasses"
	if TradeSkillSubClassDropDown then
		UIDropDownMenu_SetSelectedID(TradeSkillSubClassDropDown, 1)
	end
	
	-- Inventory slots
	SetTradeSkillInvSlotFilter(0, 1, 1)		-- this checks "All slots"
	if TradeSkillInvSlotDropDown then
		UIDropDownMenu_SetSelectedID(TradeSkillInvSlotDropDown, 1)
	end
end

local function RestoreActiveFilters()
	-- Subclasses
	SetTradeSkillSubClassFilter(subClassID-1, 1, 1)	-- this checks the previously checked value
	
	local frame = TradeSkillSubClassDropDown
	if frame then	-- other addons might nil this frame (delayed load, etc..), so secure DDM calls
		local text = (subClassID == 1) and ALL_SUBCLASSES or subClasses[subClassID-1]
		UIDropDownMenu_SetSelectedID(frame, subClassID)
		UIDropDownMenu_SetText(frame, text);
	end
	
	subClassID = nil
	wipe(subClasses)
	subClasses = nil
	
	-- Inventory slots
	invSlotID = invSlotID or 1
	SetTradeSkillInvSlotFilter(invSlotID-1, 1, 1)	-- this checks the previously checked value
	
	frame = TradeSkillInvSlotDropDown
	if frame then
		local text = (invSlotID == 1) and ALL_INVENTORY_SLOTS or invSlots[invSlotID-1]
		UIDropDownMenu_SetSelectedID(frame, invSlotID)
		UIDropDownMenu_SetText(frame, text);
	end
	
	invSlotID = nil
	wipe(invSlots)
	invSlots = nil

	SelectTradeSkill(selectedTradeSkillIndex)
	selectedTradeSkillIndex = nil
end

local headersState = {}

local function SaveHeaders()
	local headerCount = 0		-- use a counter to avoid being bound to header names, which might not be unique.
	
	for i = GetNumTradeSkills(), 1, -1 do		-- 1st pass, expand all categories
		local _, skillType, _, isExpanded  = GetTradeSkillInfo(i)
		 if (skillType == "header") then
			headerCount = headerCount + 1
			if not isExpanded then
				ExpandTradeSkillSubClass(i)
				headersState[headerCount] = true
			end
		end
	end
end

local function RestoreHeaders()
	local headerCount = 0
	for i = GetNumTradeSkills(), 1, -1 do
		local _, skillType  = GetTradeSkillInfo(i)
		if (skillType == "header") then
			headerCount = headerCount + 1
			if headersState[headerCount] then
				CollapseTradeSkillSubClass(i)
			end
		end
	end
	wipe(headersState)
end

local function ScanProfessionLinks()
	local char = thisCharacter
	if not char then return end

	-- reset, in case a profession is dropped
	char.Prof1 = nil
	char.Prof2 = nil
	
	-- 1st pass, expand all categories
	for i = GetNumSkillLines(), 1, -1 do
		local _, isHeader = GetSkillLineInfo(i)
		if isHeader then
			ExpandSkillHeader(i)
		end
	end
	
	local category
	for i = 1, GetNumSkillLines() do
		local profName, isHeader, _, rank, _, _, maxRank = GetSkillLineInfo(i)
		
		if profName == "Secourisme" then
			profName = GetSpellInfo(SPELL_ID_FIRSTAID)
		end
		
		if isHeader then
			category = profName
		else
			if category and profName then
				local field
				
				if category == L["Professions"] then
					field = "isPrimary"
					
					-- if this profession is not known yet as 
					if not char.Prof1 then			-- if there is not "first profession" known yet ..
						char.Prof1 = profName
					else
						char.Prof2 = profName
					end
				end
				
				if category == L["Secondary Skills"] then
					field = "isSecondary"
				end
				
				if field then
					print("prof name : " .. profName)
					local profession = char.Professions[profName]
				
					profession[field] = true
					profession.Rank = rank
					profession.MaxRank = maxRank
					
					-- Always nil classic apparently
					-- should be nil anyway for fishing, mining, etc..
					-- local newLink = select(2, GetSpellLink(skillName))
					-- if newLink then		-- sometimes a nil value may be returned, so keep the old one if nil
						-- char.Professions[skillName].FullLink = newLink
					-- end
				end
			end
		end
	end
	
	char.lastUpdate = time()
end



local SkillTypeToColor = {
	["header"] = 0,
	["optimal"] = 1,		-- orange
	["medium"] = 2,		-- yellow
	["easy"] = 3,			-- green
	["trivial"] = 4,		-- grey
}

local function ScanCooldowns()
	local tradeskillName = GetTradeSkillLine()
	local char = thisCharacter
	local profession = char.Professions[tradeskillName]
	
	wipe(profession.Cooldowns)
	for i = 1, GetNumTradeSkills() do
		local skillName, skillType = GetTradeSkillInfo(i)
		
		if skillType ~= "header" then
			local cooldown = GetTradeSkillCooldown(i)
			if cooldown then
				-- ex: "Hexweave Cloth|86220|1533539676" expire at "now + cooldown"
				TableInsert(profession.Cooldowns, format("%s|%d|%d", skillName, cooldown, cooldown + time()))
				
				DataStore:Broadcast("DATASTORE_PROFESSION_COOLDOWN_UPDATED")
			end
		end
	end
end

local function ScanRecipes()
	local tradeskillName = GetTradeSkillLine()
	
	-- special treatment for frFR, change "Secourisme" into "Premiers soins"
	if tradeskillName == "Secourisme" then
		tradeskillName = GetSpellInfo(SPELL_ID_FIRSTAID)
	end
	
	-- number of known entries in the current skill list including headers and categories
	local numTradeSkills = GetNumTradeSkills()
	local skillName, skillType, _, _, altVerb = GetTradeSkillInfo(1)	-- test the first line
	
	-- This method seems to be stable to not miss skills, or to make incomplete scans. At least in Classic.
	if not tradeskillName or not numTradeSkills
		or	tradeskillName == "UNKNOWN"
		or	numTradeSkills == 0
		or (skillType ~= "header" and skillType ~= "subheader") then
		
		-- if for any reason the frame is not ready, call it again in 1 second
		-- C_Timer.After(0.5, ScanRecipes)
		return
	end

	local char = thisCharacter
	local profession = char.Professions[tradeskillName]
	
	if isCata then
		-- Get profession link
		local profLink = GetTradeSkillListLink()
		if profLink then	-- sometimes a nil value may be returned, so keep the old one if nil
			--addon:Print(format(("%s"), profLink)) -- debug
			profession.FullLink = profLink
		end
	end

	-- clear storage
	profession.Categories = profession.Categories or {}
	wipe(profession.Categories)
	
	local crafts = profession.Crafts
	wipe(crafts)
		
	local reagentsInfo = {}
	
	wipe(profession.Cooldowns)
	local link, recipeLink, itemID, recipeID
	
	for i = 1, numTradeSkills do
		skillName, skillType, _, _, altVerb = GetTradeSkillInfo(i)
		--print(format("skillName: %s, skillType: %s, altVerb : %s", skillName or "nil", skillType or "nil", altVerb or "nil")) --debug
		-- scan reagents for current skill
		wipe(reagentsInfo)
		local numReagents =  GetTradeSkillNumReagents(i)

		for reagentIndex = 1, numReagents do
			local _, _, count = GetTradeSkillReagentInfo(i, reagentIndex)
			link = GetTradeSkillReagentItemLink(i, reagentIndex)
			
			if link and count then
				itemID = tonumber(link:match("item:(%d+)"))
				if itemID then
					TableInsert(reagentsInfo, format("%s,%s", itemID, count))
				end
			end
		end
		
		-- Get recipeID
		
		if isCata then
			recipeLink = GetTradeSkillRecipeLink(i) -- add recipe link here to get recipeID
			if recipeLink then
				local found, _, enchantString = string.find(recipeLink, "^|%x+|H(.+)|h%[.+%]")
				recipeID = tonumber(enchantString:match("enchant:(%d+)"))
				if recipeID then
					reagentsDB[recipeID] = TableConcat(reagentsInfo, "|")
				end
			end
		end

		-- Resulting itemID if there is one
		link = GetTradeSkillItemLink(i)
		if link then
			itemID = tonumber(link:match("item:(%d+)"))
			
			if isCata then
				if itemID and recipeID then
					local maxMade = 1
					resultItemsDB[recipeID] = maxMade + bit64:LeftShift(itemID, 8) 	-- bits 0-7 = maxMade, bits 8+ = item id
				end
			else
				if itemID then
					reagentsDB[itemID] = TableConcat(reagentsInfo, "|")
				end
			end
			
		end
		
		-- Scan recipe
		local color = SkillTypeToColor[skillType]
		local craftInfo
		
		if color then
			if skillType == "header" then
				craftInfo = skillName or ""
				TableInsert(profession.Categories, skillName)
			else
				-- cooldowns, if any
				local cooldown = GetTradeSkillCooldown(i)
				if cooldown then
				-- ex: "Hexweave Cloth|86220|1533539676" expire at "now + cooldown"
					TableInsert(profession.Cooldowns, format("%s|%d|%d", skillName, cooldown, cooldown + time()))
				end

				-- if there is a valid recipeID, save it
				if isCata then
					craftInfo = (recipeLink and recipeID) and recipeID or ""
				else
					craftInfo = (link and itemID) and itemID or ""
				end
			end
			crafts[i] = format("%s|%s", color, craftInfo)
		end
	end
	
	DataStore:Broadcast("DATASTORE_RECIPES_SCANNED", char, tradeskillName)
end

local function ScanEnchantingRecipes()
	local tradeskillName = GetCraftDisplaySkillLine()
	
	local char = thisCharacter
	local profession = char.Professions[tradeskillName]
	
	-- There will be no categories for poisons, beast training, etc..
	if not profession or not profession.Categories then return end
	
	wipe(profession.Categories)
	
	TableInsert(profession.Categories, tradeskillName)	-- insert a fake "Enchanting" category
	
	local crafts = profession.Crafts
	wipe(crafts)
	
	TableInsert(crafts, format("0|%s", tradeskillName))	-- insert a fake "0|Enchanting" header
	
	local reagentsInfo = {}
	
	for i = 1, GetNumCrafts() do
		local name, _, skillType = GetCraftInfo(i)			-- Ex: Runed Copper Rod
		local _, _, icon, _, _, _, spellID = GetSpellInfo(name)		-- Gets : icon = 135225, spellID = 7421
		
		local color = SkillTypeToColor[skillType]
		if color then
			TableInsert(crafts, format("%d|%d|%d", color, spellID, icon))
		end
		
		-- scan reagents for current skill
		wipe(reagentsInfo)
		
		-- reagents
		for reagentIndex = 1, GetCraftNumReagents(i) do
			local _, _, count = GetCraftReagentInfo(i, reagentIndex)
			local link = GetCraftReagentItemLink(i, reagentIndex) 
    
			if link and count then
				itemID = tonumber(link:match("item:(%d+)"))
				if itemID then
					TableInsert(reagentsInfo, format("%s,%s", itemID, count))
				end
			end
		end
		
		-- Used a spell prefix for enchanting, to avoid having a spellID overwriting an itemID
		reagentsDB[format("spell:%d", spellID)] = TableConcat(reagentsInfo, "|")
	end
	
	thisCharacter.lastUpdate = time()
end

local function ScanTradeSkills()
	SaveActiveFilters()
	SaveHeaders()
	ScanRecipes()
	RestoreHeaders()
	RestoreActiveFilters()
	
	thisCharacter.lastUpdate = time()
end


-- *** Event Handlers ***

local function OnTradeSkillClose()
	addon:StopListeningTo("TRADE_SKILL_UPDATE")
	addon:StopListeningTo("TRADE_SKILL_CLOSE")
	addon.isOpen = nil
end

local updateCooldowns

local function OnTradeSkillUpdate()
	-- The hook in DoTradeSkill will set this flag so that we only update skills once.
	if updateCooldowns then
		ScanCooldowns()	-- only cooldowns need to be refreshed
		updateCooldowns = nil
	end	
end

local function OnTradeSkillShow()
	addon:ListenTo("TRADE_SKILL_CLOSE", OnTradeSkillClose)
	addon.isOpen = true
	
	addon:ListenTo("TRADE_SKILL_UPDATE", OnTradeSkillUpdate)
	ScanProfessionLinks()

	-- Scan 0.5 seconds after the SHOW event
	C_Timer.After(0.5, ScanTradeSkills)
end

local function OnCraftClose()
	addon:StopListeningTo("CRAFT_CLOSE")
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

	-- Do nothing if it is not a real profession
	local tradeSkillName = GetTradeSkillLine()
	if tradeSkillName == "UNKNOWN" then return end

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
	return (profession.Categories) and #profession.Categories or 0
end

local function _GetRecipeCategoryInfo(profession, index)
	return profession.Categories[index]
end

local function _GetRecipeSubCategoryInfo(profession, catIndex, subCatIndex)
	local catID = profession.Categories[catIndex].SubCategories[subCatIndex]
	
	-- return real category id, name, and list of recipes
	return catID, GetCategoryName(catID), profession.Crafts[catID]
end

local function _GetRecipeInfo(character, profession, index)
	local prof = DataStore:GetProfession(character, profession)
	local crafts = prof.Crafts
	
	-- id = itemID in vanilla, recipeID in LK
	local color, id, icon = strsplit("|", crafts[index])

	return tonumber(color), tonumber(id), icon
end

-- Iterate through all recipes, and callback a function for each of them
local function _IterateRecipes(profession, mainCategory, callback)
	-- mainCategory : category index (or 0 for all)
	local crafts = profession.Crafts
	local currentCategory = 0
	
	
	local stop
	
	-- loop through recipes
	for i = 1, #crafts do
		-- id = itemID in vanilla, recipeID in LK
		local color, id = strsplit("|", crafts[i])

		color = tonumber(color)
		if color == 0 then			-- it's a header
			currentCategory = currentCategory + 1
			-- no callback for headers
		else
			if (mainCategory == 0) or (currentCategory == mainCategory) then
				id = tonumber(id)	-- it's a spellID, return a number
				stop = callback(color, id, i)
			end
			
			-- exit if the callback returns true
			if stop then return end
		end
	end
	
	--[[
	
	-- loop through categories
	for catIndex = 1, _GetNumRecipeCategories(profession) do
		-- if there is no filter on main category, or if it is just the one we want to see
		if (mainCategory == 0) or (mainCategory == catIndex) then
			local stop
			
			-- loop through recipes
			for i = 1, #crafts do
				local color, itemID = strsplit("|", crafts[i])
	
				color = tonumber(color)
				if color == 0 then			-- it's a header
					currentCategory = currentCategory + 1
				end
					
				if (mainCategory == 0) or (currentCategory == catIndex) then
					itemID = tonumber(itemID)	-- it's a spellID, return a number
					stop = callback(color, itemID, i)
				end
				
				-- exit if the callback returns true
				if stop then return end
			end			
		end
	end
	--]]
end

local function _GetNumRecipesByColor(profession)
	-- counts the number of headers = [0], orange, yellow, green and grey recipes.
	local counts = { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0 }
	
	_IterateRecipes(profession, 0, function(color, itemID)
		counts[color] = counts[color] + 1
	end)
	
	return counts[1], counts[2], counts[3], counts[4]		-- orange, yellow, green, grey
end

local function _IsCraftKnown(profession, soughtID)
	-- returns true if a given item ID (LK) or spell ID (Vanilla) is known in the profession passed as first argument
	local isKnown
	
	_IterateRecipes(profession, 0, function(color, itemID)
		if itemID == soughtID then
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
		-- rawTables = {
			-- "DataStore_Crafts_Reagents",				-- [recipeID] = "itemID1,count1 | itemID2,count2 | ..."
			-- "DataStore_Crafts_ResultItems",			-- [recipeID] = (bits 0-7 = maxMade, bits 8+ = item id)
			-- "DataStore_Crafts_RecipeCategories",	-- [categoryID] = name
		-- },
		characterTables = {
			["DataStore_Crafts_Characters"] = {},
		}
	})
	
	DataStore:RegisterMethod(addon, "IsCraftKnown", _IsCraftKnown)
	DataStore:RegisterMethod(addon, "GetRecipeInfo", _GetRecipeInfo)
	DataStore:RegisterMethod(addon, "IterateRecipes", _IterateRecipes)
	DataStore:RegisterMethod(addon, "GetNumRecipesByColor", _GetNumRecipesByColor)
	DataStore:RegisterMethod(addon, "GetRecipeCategoryInfo", _GetRecipeCategoryInfo)

	thisCharacter = DataStore:GetCharacterDB("DataStore_Crafts_Characters", true)
	thisCharacter.Professions = thisCharacter.Professions or {}
	-- reagentsDB = DataStore_Crafts_Reagents
	-- resultItemsDB = DataStore_Crafts_ResultItems
	-- recipeCategoriesDB = DataStore_Crafts_RecipeCategories
end)

DataStore:OnPlayerLogin(function()
	addon:ListenTo("PLAYER_ALIVE", ScanProfessionLinks)
	addon:ListenTo("TRADE_SKILL_SHOW", OnTradeSkillShow)
	addon:ListenTo("CHAT_MSG_SKILL", OnChatMsgSkill)
	addon:ListenTo("CHAT_MSG_SYSTEM", OnChatMsgSystem)
	addon:ListenTo("TRADE_SKILL_DATA_SOURCE_CHANGED", function()
		if isCata 
			or	C_TradeSkillUI.IsTradeSkillLinked() 
			or C_TradeSkillUI.IsTradeSkillGuild() 
			or C_TradeSkillUI.IsNPCCrafting()
		then return end
		
		ScanTradeSkills()
	end)
	
	if not isCata then 
		addon:ListenTo("CRAFT_UPDATE", function()     
			addon:ListenTo("CRAFT_CLOSE", OnCraftClose)
			ScanProfessionLinks()
			ScanEnchantingRecipes()
		end)	-- For enchanting
	end
	
	hooksecurefunc("DoTradeSkill", function() updateCooldowns = true end)
end)

function addon:IsTradeSkillWindowOpen()
	-- note : maybe there's a function in the WoW API to test this, but I did not find it :(
	return addon.isOpen
end
