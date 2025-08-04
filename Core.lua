-- Core.lua

local AddonName, Echoes = ...
local AceAddon = LibStub("AceAddon-3.0")
local AceDB = LibStub("AceDB-3.0")

-- Create addon object with AceEvent
Echoes = AceAddon:NewAddon(AddonName, "AceEvent-3.0")

-- Default SavedVars
local defaults = {
    profile = {
        maxEntries = 100,
        remainderDuration = 8,
        showNotes = true,
        syncLimit = 50,
    }
}

function Echoes:OnInitialize()
    -- Initialize the database
    self.db = AceDB:New(AddonName .. "DB", defaults, true)
    self.profile = self.db.profile

    -- initialize headtable for storing echoes
    if not EchoesDB then EchoesDB = {} end
    if not ArchivedEchoesDB then ArchivedEchoesDB = {} end
end

function Echoes:OnEnable()
    -- Register events
    self:RegisterEvent("PLAYER_DEAD", "OnPlayerDeath")
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")
end

-- TODO: Implement death detection
function Echoes:OnPlayerDeath(event, ...)
    --placeholder
end

-- TODO: Implement login Sync
function Echoes:OnPlayerLogin(event, ...)
    --placeholder
end