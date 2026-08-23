local _, GG = ...

local function createParticipantRow(parent, index)
    local row = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    row:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    if index % 2 == 0 then
        row:SetBackdropColor(0.10, 0.11, 0.14, 0.55)
    else
        row:SetBackdropColor(0.075, 0.08, 0.10, 0.40)
    end

    row.nameText = GG.UI:CreateLabel(row, "GameFontHighlight")
    row.nameText:SetPoint("LEFT", 10, 0)
    row.nameText:SetWidth(285)

    row.statusText = GG.UI:CreateLabel(row, "GameFontHighlightSmall")
    row.statusText:SetPoint("LEFT", 310, 0)
    row.statusText:SetWidth(180)

    row.rollText = GG.UI:CreateLabel(row, "GameFontHighlight")
    row.rollText:SetPoint("RIGHT", -14, 0)
    row.rollText:SetWidth(130)
    row.rollText:SetJustifyH("RIGHT")

    function row:SetData(entry)
        self.nameText:SetText(entry.displayName)
        if entry.roll then
            self.statusText:SetText(GG:L("PLAYED"))
            self.statusText:SetTextColor(unpack(GG.colors.success))
            self.rollText:SetText(GG.Util:FormatNumber(entry.roll))
        elseif GG.Game:GetState() == GG.Game.STATE_OPEN then
            self.statusText:SetText(GG:L("JOINED"))
            self.statusText:SetTextColor(unpack(GG.colors.accent))
            self.rollText:SetText("-")
        else
            self.statusText:SetText(GG:L("WAITING"))
            self.statusText:SetTextColor(unpack(GG.colors.muted))
            self.rollText:SetText("-")
        end
    end

    return row
end

function GG.UI:CreateGameTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints()

    tab.setupPanel = self:CreatePanel(tab)
    tab.setupPanel:SetPoint("TOPLEFT", 0, 0)
    tab.setupPanel:SetPoint("TOPRIGHT", 0, 0)
    tab.setupPanel:SetHeight(102)

    tab.setupTitle = self:CreateLabel(tab.setupPanel, "GameFontNormalLarge")
    tab.setupTitle:SetPoint("TOPLEFT", 14, -10)

    tab.amountLabel = self:CreateLabel(tab.setupPanel, "GameFontNormal")
    tab.amountLabel:SetPoint("TOPLEFT", 16, -39)

    tab.amountEdit = self:CreateEditBox(tab.setupPanel, 118, 28)
    tab.amountEdit:SetPoint("TOPLEFT", 16, -59)
    tab.amountEdit:SetNumeric(true)
    tab.amountEdit:SetMaxLetters(10)
    tab.amountEdit:SetScript("OnEnterPressed", function(editBox)
        editBox:ClearFocus()
    end)

    tab.amountSuffix = self:CreateLabel(tab.setupPanel, "GameFontHighlightSmall")
    tab.amountSuffix:SetPoint("LEFT", tab.amountEdit, "RIGHT", 7, 0)

    tab.presetButtons = {}
    local presets = {
        { label = "10K", value = 10000 },
        { label = "50K", value = 50000 },
        { label = "100K", value = 100000 },
        { label = "+10K", value = 10000, increment = true },
    }
    for index, preset in ipairs(presets) do
        local button = self:CreateButton(tab.setupPanel, 60, 24, preset.label, function()
            local amount = preset.increment
                and math.min(tab.amountEdit:GetNumber() + preset.value, 1000000000)
                or preset.value
            tab.amountEdit:SetText(tostring(amount))
        end)
        button:SetPoint("LEFT", tab.amountEdit, "RIGHT", 65 + ((index - 1) * 65), 0)
        table.insert(tab.presetButtons, button)
    end

    tab.autoJoin = self:CreateCheckButton(tab.setupPanel, "", function(check)
        local settings = GG.Database:GetSettings()
        settings.autoJoin = check:GetChecked() and true or false
        if settings.autoJoin then
            GG.Game:JoinHostIfPossible()
        end
        GG:Fire("SETTINGS_CHANGED")
    end)
    tab.autoJoin:SetPoint("TOPLEFT", 500, -61)

    tab.startButton = self:CreateButton(tab, 112, 30, "", function()
        GG.Game:Start(tab.amountEdit:GetNumber())
    end)
    tab.startButton:SetPoint("TOPLEFT", 0, -116)

    tab.reminderButton = self:CreateButton(tab, 112, 30, "", function()
        GG.Game:Reminder()
    end)
    tab.reminderButton:SetPoint("LEFT", tab.startButton, "RIGHT", 8, 0)

    tab.closeButton = self:CreateButton(tab, 112, 30, "", function()
        GG.Game:CloseEntries()
    end)
    tab.closeButton:SetPoint("LEFT", tab.reminderButton, "RIGHT", 8, 0)

    tab.rollButton = self:CreateButton(tab, 112, 30, "", function()
        GG.Game:RollHost()
    end)
    tab.rollButton:SetPoint("LEFT", tab.closeButton, "RIGHT", 8, 0)

    tab.cancelButton = self:CreateButton(tab, 112, 30, "", function()
        GG.Game:Cancel()
    end)
    tab.cancelButton:SetPoint("LEFT", tab.rollButton, "RIGHT", 8, 0)

    tab.stateText = self:CreateLabel(tab, "GameFontNormal")
    tab.stateText:SetPoint("LEFT", tab.cancelButton, "RIGHT", 12, 0)
    tab.stateText:SetPoint("RIGHT", tab, "RIGHT", 0, 0)
    tab.stateText:SetJustifyH("RIGHT")

    tab.participantsPanel = self:CreatePanel(tab)
    tab.participantsPanel:SetPoint("TOPLEFT", 0, -160)
    tab.participantsPanel:SetPoint("TOPRIGHT", 0, -160)
    tab.participantsPanel:SetHeight(248)

    tab.participantsTitle = self:CreateLabel(tab.participantsPanel, "GameFontNormalLarge")
    tab.participantsTitle:SetPoint("TOPLEFT", 14, -10)

    tab.playerCount = self:CreateLabel(tab.participantsPanel, "GameFontHighlightSmall")
    tab.playerCount:SetPoint("TOPRIGHT", -14, -14)
    tab.playerCount:SetJustifyH("RIGHT")

    tab.playerHeader = self:CreateLabel(tab.participantsPanel, "GameFontNormalSmall")
    tab.playerHeader:SetPoint("TOPLEFT", 24, -38)
    tab.playerHeader:SetWidth(285)

    tab.statusHeader = self:CreateLabel(tab.participantsPanel, "GameFontNormalSmall")
    tab.statusHeader:SetPoint("TOPLEFT", 324, -38)
    tab.statusHeader:SetWidth(180)

    tab.rollHeader = self:CreateLabel(tab.participantsPanel, "GameFontNormalSmall")
    tab.rollHeader:SetPoint("TOPRIGHT", -43, -38)
    tab.rollHeader:SetWidth(130)
    tab.rollHeader:SetJustifyH("RIGHT")

    tab.participantList = self:CreateScrollList(tab.participantsPanel, 686, 185, 27, createParticipantRow)
    tab.participantList:SetPoint("TOPLEFT", 10, -55)

    tab.emptyText = self:CreateLabel(tab.participantsPanel, "GameFontDisable")
    tab.emptyText:SetPoint("CENTER", 0, -14)

    tab.helpText = self:CreateLabel(tab, "GameFontHighlight")
    tab.helpText:SetPoint("TOPLEFT", 4, -424)
    tab.helpText:SetPoint("TOPRIGHT", -4, -424)
    tab.helpText:SetJustifyH("CENTER")
    tab.helpText:SetWordWrap(true)

    function tab:ApplyLocale()
        self.setupTitle:SetText(GG:L("GAME_SETUP"))
        self.amountLabel:SetText(GG:L("AMOUNT"))
        self.amountSuffix:SetText(GG:L("GOLD_SUFFIX"))
        self.autoJoin.label:SetText(GG:L("AUTO_JOIN"))
        self.startButton:SetText(GG:L("START"))
        self.reminderButton:SetText(GG:L("REMINDER"))
        self.closeButton:SetText(GG:L("CLOSE_ENTRIES"))
        self.rollButton:SetText(GG:L("ROLL"))
        self.cancelButton:SetText(GG:L("CANCEL"))
        self.participantsTitle:SetText(GG:L("PARTICIPANTS"))
        self.playerHeader:SetText(GG:L("PLAYER"))
        self.statusHeader:SetText(GG:L("STATUS"))
        self.rollHeader:SetText(GG:L("ROLL_VALUE"))
        self.emptyText:SetText(GG:L("NO_PARTICIPANTS"))
        self:Refresh()
    end

    function tab:Refresh()
        local settings = GG.Database:GetSettings()
        local session = GG.Game:GetSession()
        local state = GG.Game:GetState()
        local rows = GG.Game:GetParticipantRows()

        self.autoJoin:SetChecked(settings.autoJoin)

        if not self.amountEdit:HasFocus() and (not session or state == GG.Game.STATE_RESOLVED) then
            self.amountEdit:SetText(tostring(settings.lastAmount or 10000))
        end

        local canConfigure = state == GG.Game.STATE_IDLE or state == GG.Game.STATE_RESOLVED
        self.amountEdit:SetEnabled(canConfigure)
        for _, button in ipairs(self.presetButtons) do
            GG:SetEnabled(button, canConfigure)
        end

        GG:SetEnabled(self.startButton, canConfigure)
        GG:SetEnabled(self.reminderButton, state == GG.Game.STATE_OPEN)
        GG:SetEnabled(self.closeButton, state == GG.Game.STATE_OPEN and #rows >= 2)
        local canHostRoll = false
        if state == GG.Game.STATE_ROLLING then
            local hostKey = GG.Game:FindParticipant(GG.Util:GetPlayerFullName())
            canHostRoll = hostKey ~= nil and session.rolls[hostKey] == nil
        end
        GG:SetEnabled(self.rollButton, canHostRoll)
        local canCancel = state == GG.Game.STATE_OPEN or state == GG.Game.STATE_ROLLING
        GG:SetEnabled(self.cancelButton, canCancel)

        self.participantList:SetData(rows)
        self.emptyText:SetShown(#rows == 0)
        self.playerCount:SetText(GG:L("PLAYER_COUNT", #rows))

        if state == GG.Game.STATE_OPEN then
            self.stateText:SetText(GG:L("STATE_OPEN"))
            self.stateText:SetTextColor(unpack(GG.colors.accent))
            self.helpText:SetText(GG:L("OPEN_HELP"))
        elseif state == GG.Game.STATE_ROLLING then
            self.stateText:SetText(GG:L("STATE_ROLLING"))
            self.stateText:SetTextColor(unpack(GG.colors.accent))
            self.helpText:SetText(GG:L("ROLL_HELP", GG.Util:FormatNumber(session.amount)))
        elseif state == GG.Game.STATE_RESOLVED then
            self.stateText:SetText(GG:L("STATE_RESOLVED"))
            self.stateText:SetTextColor(unpack(GG.colors.success))
            self.helpText:SetText(GG:L(
                "RESULT_UI",
                GG.Util:GetShortName(session.result.loser),
                GG.Util:FormatNumber(session.result.payout),
                GG.Util:GetShortName(session.result.winner)
            ))
        else
            self.stateText:SetText(GG:L("STATE_IDLE"))
            self.stateText:SetTextColor(unpack(GG.colors.muted))
            self.helpText:SetText(GG:L("OPEN_HELP"))
        end

        if session and session.round and session.round > 1 then
            self.stateText:SetText(self.stateText:GetText() .. " · " .. GG:L("ROUND", session.round))
        end
    end

    GG:RegisterCallback("GAME_CHANGED", tab, "Refresh")
    GG:RegisterCallback("SETTINGS_CHANGED", tab, "Refresh")
    return tab
end
