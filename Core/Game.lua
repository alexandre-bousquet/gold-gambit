local _, GG = ...

local Game = {
    STATE_IDLE = "IDLE",
    STATE_OPEN = "OPEN",
    STATE_ROLLING = "ROLLING",
    STATE_RESOLVED = "RESOLVED",
}

GG.Game = Game

local function fail(key, ...)
    GG:Print(GG:L(key, ...))
    return false
end

function Game:Initialize()
    self.session = nil
end

function Game:GetState()
    return self.session and self.session.state or self.STATE_IDLE
end

function Game:GetSession()
    return self.session
end

function Game:GetParticipantCount()
    return self.session and #self.session.participantOrder or 0
end

function Game:GetParticipantRows()
    local rows = {}
    if not self.session then
        return rows
    end

    for _, key in ipairs(self.session.participantOrder) do
        local participant = self.session.participants[key]
        local roll = self.session.rolls[key]
        table.insert(rows, {
            key = key,
            name = participant.name,
            displayName = GG.Util:GetShortName(participant.name),
            roll = roll and roll.value or nil,
        })
    end

    return rows
end

function Game:ValidateAmount(amount)
    amount = tonumber(amount)
    if not amount or amount ~= math.floor(amount) or amount < 2 or amount > 1000000000 then
        return nil
    end

    return amount
end

function Game:Start(amount)
    local state = self:GetState()
    if state == self.STATE_OPEN or state == self.STATE_ROLLING then
        return fail("ERROR_GAME_ACTIVE")
    end

    amount = self:ValidateAmount(amount)
    if not amount then
        return fail("ERROR_AMOUNT_INVALID")
    end

    local channel = GG.Chat:GetAutomaticChannel()
    if not channel then
        return fail("ERROR_GROUP_REQUIRED")
    end

    local settings = GG.Database:GetSettings()
    settings.lastAmount = amount

    self.session = {
        id = tostring(time()) .. ":" .. tostring(math.random(100000, 999999)),
        state = self.STATE_OPEN,
        amount = amount,
        gameName = settings.gameName,
        channel = channel,
        createdAt = time(),
        round = 1,
        participants = {},
        participantOrder = {},
        rolls = {},
        result = nil,
    }

    if settings.autoJoin then
        self:AddParticipant(GG.Util:GetPlayerFullName(), true)
    end

    local message = GG:L(
        "CHAT_OPEN",
        self.session.gameName,
        GG.Util:FormatNumber(amount)
    )
    GG.Chat:Send(message, channel)
    GG:Fire("GAME_CHANGED")
    return true
end

function Game:AddParticipant(rawName, silent)
    if not self.session or self.session.state ~= self.STATE_OPEN then
        return false
    end

    local name = GG.Util:ResolveGroupName(rawName)
    if not name then
        return false
    end

    local key = name:lower()
    if self.session.participants[key] then
        return false
    end

    self.session.participants[key] = {
        name = name,
        joinedAt = time(),
    }
    table.insert(self.session.participantOrder, key)

    if not silent then
        GG:Print(GG:L("PLAYER_JOINED_LOCAL", GG.Util:GetShortName(name)))
    end

    GG:Fire("GAME_CHANGED")
    return true
end

function Game:JoinHostIfPossible()
    if self.session and self.session.state == self.STATE_OPEN then
        self:AddParticipant(GG.Util:GetPlayerFullName(), true)
    end
end

function Game:OnChatMessage(eventName, message, author)
    if not self.session or self.session.state ~= self.STATE_OPEN then
        return
    end

    if not GG.Chat:EventMatchesChannel(eventName, self.session.channel) then
        return
    end

    if GG.Util:Trim(message) ~= "1" then
        return
    end

    self:AddParticipant(author, false)
end

function Game:Reminder()
    if not self.session or self.session.state ~= self.STATE_OPEN then
        return fail("ERROR_NO_GAME")
    end

    GG.Chat:Send(GG:L(
        "CHAT_REMINDER",
        self.session.gameName,
        GG.Util:FormatNumber(self.session.amount),
        self:GetParticipantCount()
    ), self.session.channel)
    return true
end

function Game:CloseEntries()
    if not self.session or self.session.state ~= self.STATE_OPEN then
        return fail("ERROR_NO_GAME")
    end

    if self:GetParticipantCount() < 2 then
        return fail("ERROR_NOT_ENOUGH_PLAYERS")
    end

    self.session.state = self.STATE_ROLLING
    self.session.rolls = {}

    GG.Chat:Send(GG:L(
        "CHAT_CLOSED",
        self.session.gameName,
        self:GetParticipantCount(),
        self.session.amount
    ), self.session.channel)

    GG:Fire("GAME_CHANGED")
    return true
end

function Game:FindParticipant(rawName)
    if not self.session then
        return nil
    end

    local resolved = GG.Util:ResolveGroupName(rawName)
    if resolved then
        local exact = self.session.participants[resolved:lower()]
        if exact then
            return resolved:lower(), exact
        end
    end

    local rawShort = GG.Util:GetShortName(rawName):lower()
    local matchKey
    local match

    for key, participant in pairs(self.session.participants) do
        if GG.Util:GetShortName(participant.name):lower() == rawShort then
            if match then
                return nil
            end
            matchKey = key
            match = participant
        end
    end

    return matchKey, match
end

function Game:RollHost()
    if not self.session or self.session.state ~= self.STATE_ROLLING then
        return fail("ERROR_NO_GAME")
    end

    local key = GG.Util:GetPlayerFullName():lower()
    if not self.session.participants[key] then
        local foundKey = self:FindParticipant(GG.Util:GetPlayerFullName())
        key = foundKey
    end

    if not key or not self.session.participants[key] then
        return fail("ERROR_NOT_PARTICIPANT")
    end

    if self.session.rolls[key] then
        return fail("ERROR_ALREADY_ROLLED")
    end

    RandomRoll(1, self.session.amount)
    return true
end

function Game:OnSystemMessage(message)
    if not self.session or self.session.state ~= self.STATE_ROLLING then
        return
    end

    local rawName, value, minimum, maximum = GG.RollParser:Parse(message)
    if not rawName then
        return
    end

    local key, participant = self:FindParticipant(rawName)
    if not participant then
        return
    end

    if minimum ~= 1 or maximum ~= self.session.amount then
        GG:Print(GG:L(
            "INVALID_ROLL",
            GG.Util:GetShortName(participant.name),
            value,
            minimum,
            maximum,
            self.session.amount
        ))
        return
    end

    if self.session.rolls[key] then
        return
    end

    self.session.rolls[key] = {
        name = participant.name,
        value = value,
        rolledAt = time(),
    }

    GG:Fire("GAME_CHANGED")

    if self:HaveAllPlayersRolled() then
        self:ResolveRound()
    end
end

function Game:HaveAllPlayersRolled()
    if not self.session then
        return false
    end

    for _, key in ipairs(self.session.participantOrder) do
        if not self.session.rolls[key] then
            return false
        end
    end

    return #self.session.participantOrder >= 2
end

function Game:ResolveRound()
    local highestValue = -1
    local lowestValue = self.session.amount + 1
    local highestKeys = {}
    local lowestKeys = {}

    for _, key in ipairs(self.session.participantOrder) do
        local value = self.session.rolls[key].value

        if value > highestValue then
            highestValue = value
            highestKeys = { key }
        elseif value == highestValue then
            table.insert(highestKeys, key)
        end

        if value < lowestValue then
            lowestValue = value
            lowestKeys = { key }
        elseif value == lowestValue then
            table.insert(lowestKeys, key)
        end
    end

    if #highestKeys > 1 or #lowestKeys > 1 then
        local tied = {}
        local seen = {}
        for _, key in ipairs(highestKeys) do
            if not seen[key] then
                seen[key] = true
                table.insert(tied, GG.Util:GetShortName(self.session.participants[key].name))
            end
        end
        for _, key in ipairs(lowestKeys) do
            if not seen[key] then
                seen[key] = true
                table.insert(tied, GG.Util:GetShortName(self.session.participants[key].name))
            end
        end

        self.session.round = self.session.round + 1
        self.session.rolls = {}
        GG.Chat:Send(GG:L(
            "CHAT_TIE",
            self.session.gameName,
            table.concat(tied, ", "),
            self.session.amount
        ), self.session.channel)
        GG:Fire("GAME_CHANGED")
        return
    end

    local winnerKey = highestKeys[1]
    local loserKey = lowestKeys[1]
    local winner = self.session.participants[winnerKey].name
    local loser = self.session.participants[loserKey].name
    local payout = highestValue - lowestValue
    local completedAt = time()
    local rolls = {}
    local participants = {}

    for _, key in ipairs(self.session.participantOrder) do
        local participant = self.session.participants[key]
        table.insert(participants, participant.name)
        table.insert(rolls, {
            name = participant.name,
            value = self.session.rolls[key].value,
        })
    end

    local record = {
        id = self.session.id,
        completedAt = completedAt,
        day = GG.Util:GetTodayKey(completedAt),
        patch = GG.Util:GetCurrentPatch(),
        amount = self.session.amount,
        gameName = self.session.gameName,
        round = self.session.round,
        participants = participants,
        rolls = rolls,
        winner = winner,
        loser = loser,
        payout = payout,
    }

    self.session.state = self.STATE_RESOLVED
    self.session.result = record
    GG.Database:AddGame(record)

    GG.Chat:Send(GG:L(
        "CHAT_RESULT",
        GG.Util:GetShortName(loser),
        GG.Util:FormatNumber(payout),
        GG.Util:GetShortName(winner)
    ), self.session.channel)

    GG:Fire("GAME_CHANGED")
end

function Game:Cancel()
    if not self.session then
        return fail("ERROR_NO_GAME")
    end

    if self.session.state == self.STATE_OPEN or self.session.state == self.STATE_ROLLING then
        GG.Chat:Send(GG:L(
            "CHAT_CANCELLED",
            self.session.gameName
        ), self.session.channel)
    end

    self.session = nil
    GG:Fire("GAME_CHANGED")
    return true
end

function Game:ResetRuntime()
    self.session = nil
    GG:Fire("GAME_CHANGED")
end
