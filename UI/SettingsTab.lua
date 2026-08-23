local _, GG = ...

function GG.UI:CreateSettingsTab(parent)
    local tab = CreateFrame("Frame", nil, parent)
    tab:SetAllPoints()

    tab.languagePanel = self:CreatePanel(tab)
    tab.languagePanel:SetPoint("TOPLEFT", 0, 0)
    tab.languagePanel:SetPoint("TOPRIGHT", 0, 0)
    tab.languagePanel:SetHeight(116)

    tab.languageTitle = self:CreateLabel(tab.languagePanel, "GameFontNormalLarge")
    tab.languageTitle:SetPoint("TOPLEFT", 16, -14)

    tab.languageHelp = self:CreateLabel(tab.languagePanel, "GameFontHighlightSmall")
    tab.languageHelp:SetPoint("TOPLEFT", 16, -42)
    tab.languageHelp:SetWidth(480)
    tab.languageHelp:SetWordWrap(true)

    tab.frButton = self:CreateButton(tab.languagePanel, 54, 28, "FR", function()
        tab:SetLocale("frFR")
    end)
    tab.frButton:SetPoint("TOPRIGHT", -78, -43)

    tab.enButton = self:CreateButton(tab.languagePanel, 54, 28, "EN", function()
        tab:SetLocale("enUS")
    end)
    tab.enButton:SetPoint("LEFT", tab.frButton, "RIGHT", 6, 0)

    tab.namePanel = self:CreatePanel(tab)
    tab.namePanel:SetPoint("TOPLEFT", 0, -132)
    tab.namePanel:SetPoint("TOPRIGHT", 0, -132)
    tab.namePanel:SetHeight(116)

    tab.nameTitle = self:CreateLabel(tab.namePanel, "GameFontNormalLarge")
    tab.nameTitle:SetPoint("TOPLEFT", 16, -14)

    tab.nameEdit = self:CreateEditBox(tab.namePanel, 390, 30)
    tab.nameEdit:SetPoint("TOPLEFT", 16, -53)
    tab.nameEdit:SetMaxLetters(32)
    tab.nameEdit:SetScript("OnEnterPressed", function(editBox)
        tab:ApplyGameName()
        editBox:ClearFocus()
    end)

    tab.applyButton = self:CreateButton(tab.namePanel, 120, 28, "", function()
        tab:ApplyGameName()
    end)
    tab.applyButton:SetPoint("LEFT", tab.nameEdit, "RIGHT", 12, 0)

    tab.minimapPanel = self:CreatePanel(tab)
    tab.minimapPanel:SetPoint("TOPLEFT", 0, -264)
    tab.minimapPanel:SetPoint("TOPRIGHT", 0, -264)
    tab.minimapPanel:SetHeight(76)

    tab.minimapTitle = self:CreateLabel(tab.minimapPanel, "GameFontNormalLarge")
    tab.minimapTitle:SetPoint("TOPLEFT", 16, -14)

    tab.showMinimapButton = self:CreateCheckButton(tab.minimapPanel, "", function(check)
        GG.Database:GetSettings().minimapButton.hide = not check:GetChecked()
        GG:Fire("SETTINGS_CHANGED")
    end)
    tab.showMinimapButton:SetPoint("TOPLEFT", 16, -42)

    tab.resetPanel = self:CreatePanel(tab)
    tab.resetPanel:SetPoint("TOPLEFT", 0, -356)
    tab.resetPanel:SetPoint("TOPRIGHT", 0, -356)
    tab.resetPanel:SetHeight(128)

    tab.resetTitle = self:CreateLabel(tab.resetPanel, "GameFontNormalLarge")
    tab.resetTitle:SetPoint("TOPLEFT", 16, -14)
    tab.resetTitle:SetTextColor(unpack(GG.colors.danger))

    tab.resetHelp = self:CreateLabel(tab.resetPanel, "GameFontHighlightSmall")
    tab.resetHelp:SetPoint("TOPLEFT", 16, -43)

    tab.resetButton = self:CreateButton(tab.resetPanel, 170, 30, "", function()
        tab:ShowResetConfirmation()
    end)
    tab.resetButton:SetPoint("TOPLEFT", 16, -75)

    function tab:SetLocale(locale)
        GG.Database:GetSettings().locale = locale
        GG.Locale:Set(locale)
        GG:Fire("LOCALE_CHANGED")
        GG:Fire("SETTINGS_CHANGED")
    end

    function tab:ApplyGameName()
        local value = GG.Util:Trim(self.nameEdit:GetText()):gsub("[%c]", "")
        if value == "" then
            value = "Gold Gambit"
        end
        GG.Database:GetSettings().gameName = value
        self.nameEdit:SetText(value)
        GG:Fire("SETTINGS_CHANGED")
        GG:Print(GG:L("SETTINGS_SAVED"))
    end

    function tab:ShowResetConfirmation()
        StaticPopupDialogs.GOLD_GAMBIT_RESET = {
            text = GG:L("RESET_CONFIRM"),
            button1 = GG:L("RESET_ACCEPT"),
            button2 = GG:L("RESET_CANCEL"),
            OnAccept = function()
                GG.Game:ResetRuntime()
                GG.Database:Reset()
                GG:Print(GG:L("RESET_DONE"))
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("GOLD_GAMBIT_RESET")
    end

    function tab:RefreshLanguageButtons()
        local locale = GG.Locale:GetCurrent()
        if locale == "frFR" then
            self.frButton:LockHighlight()
            self.enButton:UnlockHighlight()
        else
            self.enButton:LockHighlight()
            self.frButton:UnlockHighlight()
        end
    end

    function tab:ApplyLocale()
        self.languageTitle:SetText(GG:L("LANGUAGE"))
        self.languageHelp:SetText(GG:L("LANGUAGE_HELP"))
        self.nameTitle:SetText(GG:L("GAME_NAME"))
        self.applyButton:SetText(GG:L("APPLY"))
        self.minimapTitle:SetText(GG:L("MINIMAP_BUTTON"))
        self.showMinimapButton.label:SetText(GG:L("SHOW_MINIMAP_BUTTON"))
        self.resetTitle:SetText(GG:L("RESET_ALL"))
        self.resetHelp:SetText(GG:L("RESET_HELP"))
        self.resetButton:SetText(GG:L("RESET_ALL"))
        self:Refresh()
    end

    function tab:Refresh()
        local settings = GG.Database:GetSettings()
        if not self.nameEdit:HasFocus() then
            self.nameEdit:SetText(settings.gameName or "Gold Gambit")
        end
        self.showMinimapButton:SetChecked(not settings.minimapButton.hide)
        self:RefreshLanguageButtons()
    end

    GG:RegisterCallback("SETTINGS_CHANGED", tab, "Refresh")
    GG:RegisterCallback("DATABASE_RESET", tab, "ApplyLocale")
    return tab
end
