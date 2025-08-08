-- Core.lua
local ADDON_NAME, NS = ...
local AceAddon   = LibStub("AceAddon-3.0")
local AceEvent   = LibStub("AceEvent-3.0")
local AceDB      = LibStub("AceDB-3.0")
local AceComm    = LibStub("AceComm-3.0")
local Serializer = LibStub("AceSerializer-3.0")

-- Create Addon Object
local Echoes = AceAddon:NewAddon(ADDON_NAME, "AceEvent-3.0", "AceComm-3.0")
NS.Addon = Echoes

-- Defaults (profile)
local defaults = {
    profile = {
        maxEntries = 200,
        reminderDuration = 8,
        showNotes = true,
        syncLimit = 50,
    }
}

-- SavedVariables (global tables)
EchoesDB = EchoesDB or {}            
ArchivedEchoesDB = ArchivedEchoesDB or {}
EchoesProfileDB = EchoesProfileDB or {} 

-- Utils ---------------------------------------------------------------

-- Unique ID (player-realm-ts)
function Echoes:GenerateEntryID(player, realm, ts)
    player = player or UnitName("player")
    realm  = realm or GetRealmName()
    ts     = ts or time()
    return string.format("%s-%s-%d", player, realm, ts)
end

-- Round coordinates (0..1)
function Echoes:RoundCoords(coord, digits)
    local mult = 10 ^ (digits or 0)
    return math.floor(coord * mult + 0.5) / mult
end

-- Shallow copy
local function copyTable(t)
    local n = {}
    for k,v in pairs(t) do n[k] = v end
    return n
end

-- Merge: insert/replace by id, prefer non-empty note
function Echoes:MergeEntry(entry)
    if type(entry) ~= "table" or not entry.id then return end
    for _, e in ipairs(EchoesDB) do
        if e.id == entry.id then
            if (not e.note or e.note == "") and entry.note and entry.note ~= "" then
                e.note = entry.note
            end
            return
        end
    end
    table.insert(EchoesDB, 1, copyTable(entry))
    -- cap
    local cap = self.profile and self.profile.maxEntries or 200
    while #EchoesDB > cap do
        table.remove(EchoesDB)
    end
end

-- Broadcast of single entry
function Echoes:QueueBroadcast(entry)
    if not IsInGuild() then return end
    local ok, payload = Serializer:Serialize({ op = "ENTRY", data = entry })
    if ok then
        self:SendCommMessage("EOF", payload, "GUILD")
    end
end

-- Bulk response (last N entries)
function Echoes:SendBulk(to, limit)
    limit = math.min(limit or (self.profile and self.profile.syncLimit or 50), #EchoesDB)
    local slice = {}
    for i = 1, limit do
        table.insert(slice, EchoesDB[i])
    end
    local ok, payload = Serializer:Serialize({ op = "BULK", data = slice })
    if ok then
        local channel = to and to ~= "" and "WHISPER" or "GUILD"
        local target = to and to ~= "" and to or nil
        self:SendCommMessage("EOF", payload, channel, target)
    end
end

-- AceComm receiver
function Echoes:OnCommReceived(prefix, msg, dist, sender)
    if prefix ~= "EOF" then return end
    local ok, obj = Serializer:Deserialize(msg)
    if not ok or type(obj) ~= "table" then return end

    if obj.op == "ENTRY" and type(obj.data) == "table" then
        self:MergeEntry(obj.data)
        self:UIRefresh()
    elseif obj.op == "REQ" then
        self:SendBulk(sender, self.profile and self.profile.syncLimit or 50)
    elseif obj.op == "BULK" and type(obj.data) == "table" then
        for _, e in ipairs(obj.data) do
            self:MergeEntry(e)
        end
        self:UIRefresh()
    end
end

-- UI refresh shim
function Echoes:UIRefresh()
    if self.UI and self.UI.Refresh then
        self.UI:Refresh()
    end
end

-- Lifecycle -----------------------------------------------------------

function Echoes:OnInitialize()
    -- AceDB
    self.db = AceDB:New("EchoesProfileDB", defaults, true)
    self.profile = self.db and self.db.profile or defaults.profile

    -- Ensure SV tables
    EchoesDB = EchoesDB or {}
    ArchivedEchoesDB = ArchivedEchoesDB or {}
end

function Echoes:OnEnable()
    -- Events are registered – actual handlers are in Events.lua
    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")
    self:RegisterEvent("PLAYER_DEAD", "OnPlayerDeath")

    -- AceComm
    self:RegisterComm("EOF")
end

-- Placeholders (implemented in Events.lua)
function Echoes:OnPlayerLogin() end
function Echoes:OnPlayerDeath() end
