local _, GG = ...

local Chat = {}
GG.Chat = Chat

local instanceCategory = GG.Util:GetInstanceGroupCategory()

local eventChannels = {
    CHAT_MSG_INSTANCE_CHAT = "INSTANCE_CHAT",
    CHAT_MSG_INSTANCE_CHAT_LEADER = "INSTANCE_CHAT",
    CHAT_MSG_RAID = "RAID",
    CHAT_MSG_RAID_LEADER = "RAID",
    CHAT_MSG_PARTY = "PARTY",
    CHAT_MSG_PARTY_LEADER = "PARTY",
}

function Chat:GetAutomaticChannel()
    if IsInGroup(instanceCategory) then
        return "INSTANCE_CHAT"
    end

    if IsInRaid() then
        return "RAID"
    end

    if IsInGroup() then
        return "PARTY"
    end

    return nil
end

function Chat:IsChannelAvailable(channel)
    if channel == "SAY" then
        return true
    end

    if channel == "INSTANCE_CHAT" then
        return IsInGroup(instanceCategory)
    end

    if channel == "RAID" then
        return IsInRaid()
    end

    if channel == "PARTY" then
        return IsInGroup() and not IsInRaid()
    end

    return false
end

function Chat:ResolveChannel(preference)
    if preference and preference ~= "AUTO" and self:IsChannelAvailable(preference) then
        return preference
    end

    return self:GetAutomaticChannel()
end

function Chat:Send(message, preference)
    local channel = self:ResolveChannel(preference)
    if not channel then
        GG:Print(GG:L("ERROR_NO_CHANNEL"))
        return false
    end

    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(message, channel)
    else
        SendChatMessage(message, channel)
    end
    return true
end

function Chat:SendLines(lines, preference)
    for index, message in ipairs(lines) do
        local currentMessage = message
        C_Timer.After((index - 1) * 0.45, function()
            self:Send(currentMessage, preference)
        end)
    end
end

function Chat:GetChannelForEvent(eventName)
    return eventChannels[eventName]
end

function Chat:EventMatchesChannel(eventName, channel)
    return eventChannels[eventName] == channel
end
