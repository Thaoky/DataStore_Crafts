local addonName, addon = ...

local L = AddonFactory:GetLocale(addonName)
local isVanilla = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)

local SPELL_ID_ALCHEMY = 2259
local SPELL_ID_BLACKSMITHING = 3100
local SPELL_ID_ENCHANTING = 7411
local SPELL_ID_ENGINEERING = 4036
local SPELL_ID_LEATHERWORKING = 2108
local SPELL_ID_TAILORING = 3908
local SPELL_ID_SKINNING = 8613
local SPELL_ID_MINING = 2575
local SPELL_ID_HERBALISM = 2366
local SPELL_ID_SMELTING = 2656
local SPELL_ID_COOKING = 2550

local SPELL_ID_FISHING = isRetail and 131474 or 7732			-- do not use 7733, it's "Artisan Fishing", not "Fishing"
local SPELL_ID_FIRSTAID = isRetail and nil or 3273
local SPELL_ID_INSCRIPTION = isVanilla and nil or 45357
local SPELL_ID_JEWELCRAFTING = isVanilla and nil or 25229

local spellIDs = {
	-- GetSpellInfo with this value will return localized spell name
	["Alchemy"] = SPELL_ID_ALCHEMY,
	["Blacksmithing"] = SPELL_ID_BLACKSMITHING,
	["Enchanting"] = SPELL_ID_ENCHANTING,
	["Engineering"] = SPELL_ID_ENGINEERING,
	["Inscription"] = SPELL_ID_INSCRIPTION,
	["Jewelcrafting"] = SPELL_ID_JEWELCRAFTING,
	["Leatherworking"] = SPELL_ID_LEATHERWORKING,
	["Tailoring"] = SPELL_ID_TAILORING,
	["Skinning"] = SPELL_ID_SKINNING,
	["Mining"] = SPELL_ID_MINING,
	["Herbalism"] = SPELL_ID_HERBALISM,
	["Smelting"] = SPELL_ID_SMELTING,
	["Cooking"] = SPELL_ID_COOKING,
	["Fishing"] = SPELL_ID_FISHING,
	["First Aid"] = SPELL_ID_FIRSTAID,
}

-- Add localized names
for english, localized in pairs(L) do
	if spellIDs[english] then
		spellIDs[localized] = spellIDs[english]
	end
end

AddonFactory:OnAddonLoaded(addonName, function() 
	DataStore:RegisterMethod(addon, "GetProfessionSpellID", function(name)
		-- name can be either the english name or the localized name
		return spellIDs[name] or 0
	end)
end)

AddonFactory:OnPlayerLogin(function()
	-- Add localized entries in the spellIDs table
	
	local localizedSpells = {}		-- avoid infinite loop by storing in a temp table first
	local localizedName
	
	for englishName, spellID in pairs(spellIDs) do
		localizedName = C_Spell.GetSpellName(spellID)
		localizedSpells[localizedName] = spellID
	end
	
	for name, id in pairs(localizedSpells) do
		spellIDs[name] = id
	end
end)
