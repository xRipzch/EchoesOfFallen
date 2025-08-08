-- UI.lua (with filters)
local ADDON_NAME, NS = ...
local Echoes = NS.Addon or _G[ADDON_NAME]

Echoes.UI = Echoes.UI or {}
local UI = Echoes.UI

-- =========================
-- Layout constants
-- =========================
local ROW_HEIGHT    = 18
local VISIBLE_ROWS  = 18
local HEADER_HEIGHT = 54  -- space for filters row

-- Frames / state
local wallFrame, scrollFrame, contentFrame, rows = nil, nil, nil, {}
UI.state = UI.state or {
    dateRange = "ALL",   -- "ALL" | "7D" | "30D"
    zone      = "ALL",   -- "ALL" or exact zone string
    player    = "ALL",   -- "ALL" | "ME" | exact player name
}

-- =========================
-- Utilities
-- =========================
local function FormatTime(ts)
    local d = date("*t", ts)
    return string.format("%04d-%02d-%02d %02d:%02d", d.year, d.month, d.day, d.hour, d.min)
end

local function Now()
    return time()
end

-- Returns true if entry matches current filters
local function PassesFilters(entry)
    -- Date filter
    if UI.state.dateRange ~= "ALL" then
        local limitSec = (UI.state.dateRange == "7D" and 7 or 30) * 24 * 60 * 60
        if (Now() - (entry.ts or 0)) > limitSec then
            return false
        end
    end

    -- Zone filter
    if UI.state.zone ~= "ALL" then
        if (entry.zone or "") ~= UI.state.zone then
            return false
        end
    end

    -- Player filter
    if UI.state.player == "ME" then
        if (entry.player or "") ~= UnitName("player") then
            return false
        end
    elseif UI.state.player ~= "ALL" then
        if (entry.player or "") ~= UI.state.player then
            return false
        end
    end

    return true
end

-- Compute filtered list (in memory)
local function BuildFiltered()
    local out = {}
    for i = 1, #EchoesDB do
        local e = EchoesDB[i]
        if PassesFilters(e) then
            table.insert(out, e)
        end
    end
    return out
end

-- Build unique zone list and player list from EchoesDB (for dropdowns)
local function CollectZonesAndPlayers()
    local zones, zoneSet = {}, {}
    local players, playerSet = {}, {}
    for _, e in ipairs(EchoesDB) do
        local z = e.zone or ""
        if z ~= "" and not zoneSet[z] then
            zoneSet[z] = true
            table.insert(zones, z)
        end
        local p = e.player or ""
        if p ~= "" and not playerSet[p] then
            playerSet[p] = true
            table.insert(players, p)
        end
    end
    table.sort(zones)
    table.sort(players)
    return zones, players
end

-- =========================
-- UI construction
-- =========================
local function EnsureWall()
    if wallFrame then return end

    -- Main frame
    wallFrame = CreateFrame("Frame", "EchoesWallFrame", UIParent, "BasicFrameTemplateWithInset")
    wallFrame:SetSize(720, 480)
    wallFrame:SetPoint("CENTER")
    wallFrame:Hide()

    wallFrame.title = wallFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    wallFrame.title:SetPoint("TOPLEFT", 12, -6)
    wallFrame.title:SetText("Echoes of Fallen")

    -- --- Filters row (date, zone, player, reset) --------------------
    local filtersContainer = CreateFrame("Frame", nil, wallFrame)
    filtersContainer:SetPoint("TOPLEFT", 10, -28)
    filtersContainer:SetPoint("TOPRIGHT", -10, -28)
    filtersContainer:SetHeight(HEADER_HEIGHT)

    -- Helper label creator
    local function Label(parent, text)
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetText(text)
        return fs
    end

    -- DATE DROPDOWN
    local dateLabel = Label(filtersContainer, "Date:")
    dateLabel:SetPoint("TOPLEFT", 6, -6)

    local dateDrop = CreateFrame("Frame", "EchoesDateDrop", filtersContainer, "UIDropDownMenuTemplate")
    dateDrop:SetPoint("TOPLEFT", dateLabel, "BOTTOMLEFT", -14, -2)

    UIDropDownMenu_SetWidth(dateDrop, 120)
    UIDropDownMenu_SetText(dateDrop, "All time")

    UIDropDownMenu_Initialize(dateDrop, function(self, level)
        local function item(text, value)
            local info = UIDropDownMenu_CreateInfo()
            info.text = text
            info.func = function()
                UI.state.dateRange = value
                UIDropDownMenu_SetText(dateDrop,
                    value == "ALL" and "All time" or (value == "7D" and "Last 7 days" or "Last 30 days"))
                Echoes.UI:Refresh(true) -- true => clamp scroll
            end
            info.checked = (UI.state.dateRange == value)
            UIDropDownMenu_AddButton(info, level)
        end
        item("All time", "ALL")
        item("Last 7 days", "7D")
        item("Last 30 days", "30D")
    end)

    -- ZONE DROPDOWN
    local zoneLabel = Label(filtersContainer, "Zone:")
    zoneLabel:SetPoint("TOPLEFT", dateDrop, "TOPRIGHT", 110, 6)

    local zoneDrop = CreateFrame("Frame", "EchoesZoneDrop", filtersContainer, "UIDropDownMenuTemplate")
    zoneDrop:SetPoint("TOPLEFT", zoneLabel, "BOTTOMLEFT", -14, -2)
    UIDropDownMenu_SetWidth(zoneDrop, 180)
    UIDropDownMenu_SetText(zoneDrop, "All zones")

    local function InitZoneDropdown()
        UIDropDownMenu_Initialize(zoneDrop, function(self, level)
            local zones = select(1, CollectZonesAndPlayers())

            local function add(text, value, checked)
                local info = UIDropDownMenu_CreateInfo()
                info.text = text
                info.func = function()
                    UI.state.zone = value
                    UIDropDownMenu_SetText(zoneDrop, (value == "ALL") and "All zones" or value)
                    Echoes.UI:Refresh(true)
                end
                info.checked = checked
                UIDropDownMenu_AddButton(info, level)
            end

            add("All zones", "ALL", UI.state.zone == "ALL")
            for _, z in ipairs(zones) do
                add(z, z, UI.state.zone == z)
            end
        end)
    end
    InitZoneDropdown()

    -- PLAYER DROPDOWN
    local playerLabel = Label(filtersContainer, "Player:")
    playerLabel:SetPoint("TOPLEFT", zoneDrop, "TOPRIGHT", 120, 6)

    local playerDrop = CreateFrame("Frame", "EchoesPlayerDrop", filtersContainer, "UIDropDownMenuTemplate")
    playerDrop:SetPoint("TOPLEFT", playerLabel, "BOTTOMLEFT", -14, -2)
    UIDropDownMenu_SetWidth(playerDrop, 160)
    UIDropDownMenu_SetText(playerDrop, "All players")

    local function InitPlayerDropdown()
        UIDropDownMenu_Initialize(playerDrop, function(self, level)
            local _, players = CollectZonesAndPlayers()

            local function add(text, value, checked)
                local info = UIDropDownMenu_CreateInfo()
                info.text = text
                info.func = function()
                    UI.state.player = value
                    local label = (value == "ALL" and "All players")
                                 or (value == "ME" and "Only me")
                                 or value
                    UIDropDownMenu_SetText(playerDrop, label)
                    Echoes.UI:Refresh(true)
                end
                info.checked = checked
                UIDropDownMenu_AddButton(info, level)
            end

            add("All players", "ALL", UI.state.player == "ALL")
            add("Only me", "ME", UI.state.player == "ME")
            for _, p in ipairs(players) do
                add(p, p, UI.state.player == p)
            end
        end)
    end
    InitPlayerDropdown()

    -- RESET FILTERS BUTTON
    local resetBtn = CreateFrame("Button", nil, filtersContainer, "UIPanelButtonTemplate")
    resetBtn:SetSize(90, 22)
    resetBtn:SetPoint("TOPRIGHT", -6, -8)
    resetBtn:SetText("Reset")
    resetBtn:SetScript("OnClick", function()
        UI.state.dateRange = "ALL"
        UI.state.zone      = "ALL"
        UI.state.player    = "ALL"
        UIDropDownMenu_SetText(dateDrop, "All time")
        UIDropDownMenu_SetText(zoneDrop, "All zones")
        UIDropDownMenu_SetText(playerDrop, "All players")
        Echoes.UI:Refresh(true)
    end)

    -- --- ScrollFrame + rows -----------------------------------------
    scrollFrame = CreateFrame("ScrollFrame", "EchoesScrollFrame", wallFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 12, -28 - HEADER_HEIGHT)
    scrollFrame:SetPoint("BOTTOMRIGHT", -28, 12)

    contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(1, 1)
    scrollFrame:SetScrollChild(contentFrame)

    -- Mousewheel to move N rows per notch
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local step = ROW_HEIGHT * 3
        self:SetVerticalScroll(math.max(0, cur - delta * step))
        Echoes.UI:Refresh()
    end)

    -- Data rows
    for i = 1, VISIBLE_ROWS do
        local row = CreateFrame("Button", nil, contentFrame)
        row:SetSize(640, ROW_HEIGHT)
        row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)

        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.text:SetPoint("LEFT", 4, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetWidth(620)

        -- Shift-click: insert a shareable text snippet into chat
        row:SetScript("OnClick", function(self)
            if IsShiftKeyDown() then
                local e = self._entry
                if e then
                    local txt = string.format("%s — %s (%.0f, %.0f) @ %s",
                        e.player, e.zone or "?", (e.coords and e.coords.x or 0)*100,
                        (e.coords and e.coords.y or 0)*100, FormatTime(e.ts))
                    if not ChatEdit_GetActiveWindow() then
                        ChatFrame_OpenChat("")
                    end
                    ChatEdit_InsertLink(txt)
                end
            end
        end)

        rows[i] = row
    end

    -- Expose small helpers to re-init dropdown content when dataset changes
    UI._InitZoneDropdown = InitZoneDropdown
    UI._InitPlayerDropdown = InitPlayerDropdown
end

-- =========================
-- Public UI API
-- =========================
function UI:Toggle()
    EnsureWall()
    if wallFrame:IsShown() then
        wallFrame:Hide()
    else
        wallFrame:Show()
        self:Refresh(true) -- clamp scroll on first open
    end
end

-- Refresh the list; if clampScroll==true, ensure scroll is within range after re-filter
function UI:Refresh(clampScroll)
    if not wallFrame or not wallFrame:IsShown() then return end

    -- rebuild filtered set
    local filtered = BuildFiltered()

    -- Rebuild dropdown choices (zones/players) so options reflect current data
    if self._InitZoneDropdown then self._InitZoneDropdown() end
    if self._InitPlayerDropdown then self._InitPlayerDropdown() end

    -- Clamp scroll if necessary
    local total = math.max(#filtered, VISIBLE_ROWS)
    contentFrame:SetHeight(total * ROW_HEIGHT)

    if clampScroll then
        local maxScroll = math.max(0, total * ROW_HEIGHT - VISIBLE_ROWS * ROW_HEIGHT)
        if scrollFrame:GetVerticalScroll() > maxScroll then
            scrollFrame:SetVerticalScroll(maxScroll)
        end
    end

    local offset = math.floor(scrollFrame:GetVerticalScroll() / ROW_HEIGHT) + 1
    for i = 1, VISIBLE_ROWS do
        local idx = offset + i - 1
        local row = rows[i]
        local e = filtered[idx]
        row._entry = e
        if e then
            local note = (Echoes.profile.showNotes and e.note and e.note ~= "") and (" |cffaaaaaa— "..e.note.."|r") or ""
            local xy = e.coords and string.format(" (%.0f,%.0f)", (e.coords.x or 0)*100, (e.coords.y or 0)*100) or ""
            row.text:SetText(string.format("|cffffffff%s|r  |cff00ccff%s|r  |cffcccccc%s|r%s%s",
                FormatTime(e.ts), e.player, e.zone or "?", xy, note))
            row:Show()
        else
            row.text:SetText("")
            row:Hide()
        end
    end
end

-- Death reminder popup
local reminderFrame
function UI:ShowReminder()
    local duration = Echoes.profile and Echoes.profile.reminderDuration or 8
    if not reminderFrame then
        reminderFrame = CreateFrame("Frame", "EchoesReminderFrame", UIParent, "TooltipBorderedFrameTemplate")
        reminderFrame:SetSize(420, 80)
        reminderFrame:SetPoint("TOP", UIParent, "TOP", 0, -100)
        reminderFrame.text1 = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        reminderFrame.text1:SetPoint("TOP", 0, -10)
        reminderFrame.text1:SetText("You have fallen! Remember to add a note:")
        reminderFrame.text2 = reminderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        reminderFrame.text2:SetPoint("TOP", reminderFrame.text1, "BOTTOM", 0, -6)
        reminderFrame.text2:SetText('/memorial add "Your note here"')
        reminderFrame:Hide()
        reminderFrame:SetAlpha(0)
    end
    reminderFrame:Show()
    UIFrameFadeIn(reminderFrame, 0.25, 0, 1)
    C_Timer.After(duration, function()
        UIFrameFadeOut(reminderFrame, 0.4, 1, 0)
        C_Timer.After(0.4, function() reminderFrame:Hide() end)
    end)
end
