local addonName, GG = ...

local Addon = CreateFrame("Frame")
GG.Addon = Addon

local chatEvents = {
    "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER",
    "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_PARTY",
    "CHAT_MSG_PARTY_LEADER",
}

function Addon:Initialize()
    GG.Database:Initialize()
    GG.Locale:Set(GG.Database:GetSettings().locale)
    GG.RollParser:Initialize()
    GG.Game:Initialize()
    GG.UI:CreateMainFrame()

    for _, eventName in ipairs(chatEvents) do
        self:RegisterEvent(eventName)
    end
    self:RegisterEvent("CHAT_MSG_SYSTEM")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")

    SLASH_GOLDGAMBIT1 = "/goldgambit"
    SLASH_GOLDGAMBIT2 = "/gg"
    SlashCmdList.GOLDGAMBIT = function(message)
        local command = GG.Util:Trim(message):lower()
        if command == "reset" then
            GG.Database:ResetStats()
            GG:Print(GG:L("STATS_RESET_DONE"))
            return
        end

        GG.UI.MainFrame:Toggle()
    end

    GG:Print(GG:L("ADDON_READY"))
end

Addon:RegisterEvent("ADDON_LOADED")
Addon:SetScript("OnEvent", function(self, eventName, ...)
    if eventName == "ADDON_LOADED" then
        local loadedAddon = ...
        if loadedAddon == addonName then
            self:UnregisterEvent("ADDON_LOADED")
            self:Initialize()
        end
        return
    end

    if eventName == "CHAT_MSG_SYSTEM" then
        GG.Game:OnSystemMessage(...)
        return
    end

    if eventName == "GROUP_ROSTER_UPDATE" then
        GG:Fire("GROUP_CHANGED")
        return
    end

    local message, author = ...
    GG.Game:OnChatMessage(eventName, message, author)
end)
