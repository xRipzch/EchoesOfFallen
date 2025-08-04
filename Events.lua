-- Events.lua
local AddonName, Echoes = ...
local AceComm = LibStub("AceComm-3.0")
local Serializer = LibStub("AceSerializer-3.0")
local C_Timer = C_Timer

-- Import of nessecary functionss from Core.lua
local GenerateEntryID = Echoes.GenerateEntryID
local RoundCoords = Echoes.RoundCoords
local QueueBroadcast = Echoes.QueueBroadcast

-- Registration of events in Core.lua via OnEnable

function Echoes:OnPlayerDeath(event, ...)
    -- Grab basic player information
    local player = UnitName("player")
    local realm = GetRealmName()
    local ts = time()
    local zone = GetZoneText()
    local x, y = C_Map.GetBestMapForUnit("player") and C_Map.GetPlayerMapPosition(C_Map.GetBestMapForUnit("player"), "player"):GetXY() or 0, 0
x, y = RoundCoords(x, 2), RoundCoords(y, 2)

-- Create the entry
    local entry = {
        id = GenerateEntryID(),
        player = player,
        realm = realm,
        ts = ts,
        zone = zone,
        coords = { x = x, y = y },
        notes = "",
    }

-- Add the entry to the local database
    tinsert(EchoesDB, 1, entry)

-- Broadcast via Queue
    QueueBroadcast(entry)
end