local _, GG = ...

local columns = {
    { key = "rank", label = "RANK", x = 4, width = 28, align = "CENTER" },
    { key = "player", label = "PLAYER", x = 36, width = 100, align = "LEFT" },
    { key = "won", label = "WON", x = 140, width = 68, align = "RIGHT" },
    { key = "lost", label = "LOST", x = 212, width = 68, align = "RIGHT" },
    { key = "net", label = "NET", x = 284, width = 68, align = "RIGHT" },
    { key = "wr", label = "WIN_RATE", x = 358, width = 43, align = "RIGHT" },
    { key = "lr", label = "LOSS_RATE", x = 405, width = 43, align = "RIGHT" },
    { key = "nemesis", label = "NEMESIS", x = 462, width = 110, align = "LEFT" },
    { key = "patron", label = "PATRON", x = 571, width = 110, align = "LEFT" },
}

local function offsetDropdownValue(dropdown, yOffset)
    local text = dropdown.Text or dropdown:GetFontString()
    if not text then
        return
    end

    if not dropdown.valueTextAnchors then
        dropdown.valueTextAnchors = {}
        for index = 1, text:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = text:GetPoint(index)
            dropdown.valueTextAnchors[index] = { point, relativeTo, relativePoint, x, y }
        end
    end

    text:ClearAllPoints()
    for _, anchor in ipairs(dropdown.valueTextAnchors) do
        text:SetPoint(anchor[1], anchor[2], anchor[3], anchor[4], anchor[5] + yOffset)
    end
end

local function createStatsRow(parent, index)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    if index % 2 == 0 then
        row:SetBackdropColor(0.10, 0.11, 0.14, 0.55)
    else
        row:SetBackdropColor(0.075, 0.08, 0.10, 0.40)
    end

    row.cells = {}
    for _, column in ipairs(columns) do
        local cell = GG.UI:CreateLabel(row, "GameFontHighlightSmall")
        cell:SetPoint("LEFT", column.x, 0)
        cell:SetWidth(column.width)
        cell:SetJustifyH(column.align)
        row.cells[column.key] = cell
    end

    function row:SetData(player)
        self.cells.rank:SetText(player.rank)
        self.cells.player:SetText(player.displayName)
        self.cells.won:SetText(GG.Util:FormatNumber(player.goldWon))
        self.cells.lost:SetText(GG.Util:FormatNumber(player.goldLost))
        self.cells.net:SetText(GG.Util:FormatNumber(player.net))
        self.cells.wr:SetText(GG.Util:FormatPercent(player.winRate) .. "%")
        self.cells.lr:SetText(GG.Util:FormatPercent(player.lossRate) .. "%")
        self.cells.nemesis:SetText(player.nemesisDisplay)
        self.cells.patron:SetText(player.patronDisplay)

        if player.net > 0 then
            self.cells.net:SetTextColor(unpack(GG.colors.success))
        elseif player.net < 0 then
            self.cells.net:SetTextColor(unpack(GG.colors.danger))
        else
            self.cells.net:SetTextColor(unpack(GG.colors.muted))
        end
    end

    return row
end

function GG.UI:CreateStatsTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints()

    tab.periodLabel = self:CreateLabel(tab, "GameFontNormal")
    tab.periodLabel:SetPoint("TOPLEFT", 6, -7)

    tab.periodDropdown = self:CreateDropdown(tab, 190, function(value)
        GG.Database:GetSettings().statsPeriod = value
        tab:Refresh()
    end)
    tab.periodDropdown:SetPoint("TOPLEFT", 2, -27)

    tab.channelLabel = self:CreateLabel(tab, "GameFontNormal")
    tab.channelLabel:SetPoint("TOPLEFT", 254, -7)

    tab.channelDropdown = self:CreateDropdown(tab, 145, function(value)
        GG.Database:GetSettings().statsChannel = value
    end)
    tab.channelDropdown:SetPoint("TOPLEFT", 250, -27)

    tab.sendButton = self:CreateButton(tab, 78, 28, "", function()
        GG.Sync:SendPeriod(GG.Database:GetSettings().statsPeriod or "ALL")
    end)
    tab.sendButton:SetPoint("BOTTOMLEFT", 4, 6)

    tab.receiveButton = self:CreateButton(tab, 106, 28, "", function()
        GG.Sync:ToggleReceiving()
    end)
    tab.receiveButton:SetPoint("LEFT", tab.sendButton, "RIGHT", 4, 0)

    tab.publishButton = self:CreateButton(tab, 120, 28, "", function()
        local settings = GG.Database:GetSettings()
        GG.Stats:Publish(settings.statsPeriod, settings.statsChannel)
    end)
    tab.publishButton:SetPoint("TOPRIGHT", -2, -29)

    tab.tablePanel = self:CreatePanel(tab)
    tab.tablePanel:SetPoint("TOPLEFT", 0, -78)
    tab.tablePanel:SetPoint("BOTTOMRIGHT", 0, 74)

    tab.headers = {}
    for _, column in ipairs(columns) do
        local header = self:CreateLabel(tab.tablePanel, "GameFontNormalSmall")
        header:SetPoint("TOPLEFT", column.x + 5, -10)
        header:SetWidth(column.width)
        header:SetJustifyH("CENTER")
        tab.headers[column.key] = {
            label = header,
            localeKey = column.label,
        }
    end

    tab.statsList = self:CreateScrollList(tab.tablePanel, 706, 303, 25, createStatsRow)
    tab.statsList:SetPoint("TOPLEFT", 5, -30)

    tab.emptyText = self:CreateLabel(tab.tablePanel, "GameFontDisable")
    tab.emptyText:SetPoint("CENTER", 0, -5)

    tab.summaryText = self:CreateLabel(tab, "GameFontHighlightSmall")
    tab.summaryText:SetPoint("BOTTOMLEFT", 4, 45)

    function tab:RebuildDropdowns()
        local settings = GG.Database:GetSettings()
        self.periodDropdown:SetItems({
            { value = "ALL", text = GG:L("PERIOD_ALL") },
            { value = "PATCH", text = GG:L("PERIOD_PATCH", GG.Util:GetCurrentPatch()) },
            { value = "TODAY", text = GG:L("PERIOD_TODAY") },
        })
        self.periodDropdown:SetValue(settings.statsPeriod or "ALL", false)
        offsetDropdownValue(self.periodDropdown, -2)

        self.channelDropdown:SetItems({
            { value = "AUTO", text = GG:L("CHANNEL_AUTO") },
            { value = "INSTANCE_CHAT", text = GG:L("CHANNEL_INSTANCE") },
            { value = "RAID", text = GG:L("CHANNEL_RAID") },
            { value = "PARTY", text = GG:L("CHANNEL_PARTY") },
            { value = "SAY", text = GG:L("CHANNEL_SAY") },
        })
        self.channelDropdown:SetValue(settings.statsChannel or "AUTO", false)
        offsetDropdownValue(self.channelDropdown, -2)
    end

    function tab:ApplyLocale()
        self.periodLabel:SetText(GG:L("STATS_PERIOD"))
        self.channelLabel:SetText(GG:L("CHAT_CHANNEL"))
        self.sendButton:SetText(GG:L("SYNC_SEND"))
        self.publishButton:SetText(GG:L("PUBLISH"))
        self.emptyText:SetText(GG:L("NO_STATS"))
        for _, header in pairs(self.headers) do
            header.label:SetText(GG:L(header.localeKey))
        end
        self:RebuildDropdowns()
        self:Refresh()
    end

    function tab:Refresh()
        local settings = GG.Database:GetSettings()
        local ranking, gamesCount = GG.Stats:BuildRanking(settings.statsPeriod or "ALL")
        self.statsList:SetData(ranking)
        self.emptyText:SetShown(#ranking == 0)
        self.summaryText:SetText(GG:L("GAMES_COUNT", gamesCount))
        GG:SetEnabled(self.publishButton, #ranking > 0)
        self.receiveButton:SetText(GG:L(GG.Sync:IsReceiving() and "SYNC_RECEIVE_ON" or "SYNC_RECEIVE_OFF"))

        local hasGroupChannel = GG.Chat:GetAutomaticChannel() ~= nil
        GG:SetEnabled(self.sendButton, gamesCount > 0 and hasGroupChannel and not GG.Sync:IsSending())
        GG:SetEnabled(self.receiveButton, hasGroupChannel)
    end

    GG:RegisterCallback("HISTORY_CHANGED", tab, "Refresh")
    GG:RegisterCallback("DATABASE_RESET", tab, "ApplyLocale")
    GG:RegisterCallback("SYNC_STATE_CHANGED", tab, "Refresh")
    GG:RegisterCallback("GROUP_CHANGED", tab, "Refresh")
    return tab
end
