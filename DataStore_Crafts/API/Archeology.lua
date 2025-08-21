if WOW_PROJECT_ID == WOW_PROJECT_CLASSIC then return end

local addonName, addon = ...
local thisCharacter

local DataStore = DataStore
local GetNumArchaeologyRaces, GetNumArtifactsByRace, GetArtifactInfoByRace = GetNumArchaeologyRaces, GetNumArtifactsByRace, GetArtifactInfoByRace
local API_GetSpellName = GetSpellInfo or C_Spell.GetSpellName										 

local function ScanArcheologyItems()
	if not IsArtifactCompletionHistoryAvailable() then return end
	
	local names = {}
	local spellName
	local numArtifactsByRace
	
	for raceIndex = 1, GetNumArchaeologyRaces() do
		wipe(names)
		
		numArtifactsByRace = GetNumArtifactsByRace(raceIndex)
		
		if numArtifactsByRace > 0 and addon.artifactDB[raceIndex] then
			-- Create a table where ["Artifact Name"] = associated spell id 
			-- this is necessary because the archaeology API does not return any other way to match artifacts with either spell ID or item ID
			for index, artifact in pairs(addon.artifactDB[raceIndex]) do
				spellName = API_GetSpellName(artifact.spellID)
				names[spellName] = artifact.spellID
			end
			
			for artifactIndex = 1, GetNumArtifactsByRace(raceIndex) do
				local artifactName, _, _, _, _, _, _, _, _, completionCount = GetArtifactInfoByRace(raceIndex, artifactIndex)

				-- debug only
				-- if not names[artifactName] then
					-- print(artifactName .. " not found")
				-- end
				
				if names[artifactName] and completionCount > 0 then
					thisCharacter[names[artifactName]] = true
				end
			end
		end
	end
end

AddonFactory:OnAddonLoaded(addonName, function() 
	DataStore:RegisterTables({
		addon = addon,
		characterTables = {
			["DataStore_Crafts_ArcheologyItems"] = {
				IsArtifactKnown = function(character, spellID)
					return character[spellID]
				end,
			},
		}
	})
	
	DataStore:RegisterMethod(addon, "GetArchaeologyRaceArtifacts", function(race)
		return addon.artifactDB[race]
	end)
	DataStore:RegisterMethod(addon, "GetRaceNumArtifacts", function(race)
		return #addon.artifactDB[race]
	end)
	DataStore:RegisterMethod(addon, "GetArtifactInfo", function(race, index)
		return addon.artifactDB[race][index]
	end)

	thisCharacter = DataStore:GetCharacterDB("DataStore_Crafts_ArcheologyItems", true)
end)

AddonFactory:OnPlayerLogin(function()
	local _, _, arch = GetProfessions()
	
	if arch then
		ScanArcheologyItems()
		addon:ListenTo("RESEARCH_ARTIFACT_COMPLETE", ScanArcheologyItems)
	end
end)
