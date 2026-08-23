local addonName, GG = ...

local MINIMAP_LAUNCHER_NAME = "GoldGambit"
local MINIMAP_ICON = "Interface\\AddOns\\" .. addonName .. "\\Media\\GoldGambitIcon.png"

function GG.UI:RefreshMinimapButton()
    if not self.MinimapButtonLibrary then
        return
    end

    local settings = GG.Database:GetSettings()
    self.MinimapButtonLibrary:Refresh(MINIMAP_LAUNCHER_NAME, settings.minimapButton)
end

function GG.UI:CreateMinimapButton()
    local dataBroker = LibStub("LibDataBroker-1.1")
    local iconLibrary = LibStub("LibDBIcon-1.0")
    local launcher = dataBroker:NewDataObject(MINIMAP_LAUNCHER_NAME, {
        type = "launcher",
        label = GG.displayName,
        icon = MINIMAP_ICON,
        iconCoords = { 0, 1, 0, 1 },
        OnClick = function(_, button)
            if button == "LeftButton" then
                GG.UI.MainFrame:Toggle()
            end
        end,
        OnTooltipShow = function(tooltip)
            local settings = GG.Database:GetSettings()
            tooltip:AddLine(settings.gameName or GG.displayName)
            tooltip:AddLine(GG:L("MINIMAP_TOOLTIP"), 1, 1, 1, true)
        end,
    })

    iconLibrary:Register(MINIMAP_LAUNCHER_NAME, launcher, GG.Database:GetSettings().minimapButton)
    self.MinimapButtonLibrary = iconLibrary
    self.MinimapButton = iconLibrary:GetMinimapButton(MINIMAP_LAUNCHER_NAME)
    GG:RegisterCallback("SETTINGS_CHANGED", self, "RefreshMinimapButton")
    return self.MinimapButton
end

function GG.UI:CreateMainFrame()
    local frameName = addonName .. "MainFrame"
    local frame = CreateFrame("Frame", frameName, UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(760, 580)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)
    frame:Hide()

    frame.titleText = frame.TitleText or _G[frameName .. "TitleText"]

    frame.content = CreateFrame("Frame", nil, frame)
    frame.content:SetPoint("TOPLEFT", 22, -40)
    frame.content:SetPoint("BOTTOMRIGHT", -22, 48)

    frame.pages = {
        self:CreateGameTab(frame.content),
        self:CreateStatsTab(frame.content),
        self:CreateSettingsTab(frame.content),
    }

    frame.tabs = {}
    local localeKeys = { "TAB_GAME", "TAB_STATS", "TAB_SETTINGS" }

    for index = 1, 3 do
        local tabButton = CreateFrame(
            "Button",
            frameName .. "Tab" .. index,
            frame,
            "PanelTabButtonTemplate"
        )
        tabButton:SetID(index)
        tabButton:SetWidth(170)
        tabButton.localeKey = localeKeys[index]
        tabButton:SetScript("OnClick", function(button)
            frame:SelectTab(button:GetID())
        end)

        if index == 1 then
            tabButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, -28)
        else
            tabButton:SetPoint("LEFT", frame.tabs[index - 1], "RIGHT", -14, 0)
        end

        frame.tabs[index] = tabButton
    end

    PanelTemplates_SetNumTabs(frame, 3)

    function frame:SelectTab(index)
        self.selectedTab = index
        PanelTemplates_SetTab(self, index)
        for pageIndex, page in ipairs(self.pages) do
            page:SetShown(pageIndex == index)
            if pageIndex == index and page.Refresh then
                page:Refresh()
            end
        end
    end

    function frame:ApplyLocale()
        local settings = GG.Database:GetSettings()
        if self.titleText then
            self.titleText:SetText(settings.gameName or GG.displayName)
        end

        for _, tabButton in ipairs(self.tabs) do
            tabButton:SetText(GG:L(tabButton.localeKey))
        end

        for _, page in ipairs(self.pages) do
            if page.ApplyLocale then
                page:ApplyLocale()
            end
        end
    end

    function frame:Toggle()
        if self:IsShown() then
            self:Hide()
        else
            self:Show()
        end
    end

    frame:SetScript("OnShow", function(self)
        self:ApplyLocale()
        self:SelectTab(self.selectedTab or 1)
    end)

    frame:SelectTab(1)
    frame:ApplyLocale()

    table.insert(UISpecialFrames, frameName)
    self.MainFrame = frame
    self:CreateMinimapButton()

    GG:RegisterCallback("LOCALE_CHANGED", frame, "ApplyLocale")
    GG:RegisterCallback("SETTINGS_CHANGED", frame, "ApplyLocale")
    return frame
end
