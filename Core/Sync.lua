local _, GG = ...

local Sync = {}
GG.Sync = Sync

local PREFIX = "GGSYNC1"
local CHUNK_SIZE = 180
local MAX_GAMES = 1000
local MAX_CHUNKS_PER_GAME = 100
local TRANSFER_TIMEOUT = 120

local supportedChannels = {
    INSTANCE_CHAT = true,
    RAID = true,
    PARTY = true,
}

local function escape(value)
    local encoded = tostring(value or ""):gsub("([^%w%._%-])", function(character)
        return string.format("%%%02X", string.byte(character))
    end)
    return encoded
end

local function unescape(value)
    local decoded = (value or ""):gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    return decoded
end

local function split(value, separator)
    local values = {}
    for part in ((value or "") .. separator):gmatch("(.-)" .. separator) do
        table.insert(values, part)
    end
    return values
end

local function encodeNames(names)
    local encoded = {}
    for _, name in ipairs(names or {}) do
        table.insert(encoded, escape(name))
    end
    return table.concat(encoded, ",")
end

local function decodeNames(value)
    local names = {}
    for _, encoded in ipairs(split(value, ",")) do
        if encoded ~= "" then
            table.insert(names, unescape(encoded))
        end
    end
    return names
end

local function encodeRolls(rolls)
    local encoded = {}
    for _, roll in ipairs(rolls or {}) do
        table.insert(encoded, escape(roll.name) .. ":" .. tostring(tonumber(roll.value) or 0))
    end
    return table.concat(encoded, ",")
end

local function decodeRolls(value)
    local rolls = {}
    for _, encoded in ipairs(split(value, ",")) do
        if encoded ~= "" then
            local name, rollValue = encoded:match("^(.-):(%-?%d+)$")
            if not name then
                return nil
            end
            table.insert(rolls, {
                name = unescape(name),
                value = tonumber(rollValue),
            })
        end
    end
    return rolls
end

local function normalizeSender(sender)
    return GG.Util:ResolveGroupName(sender) or sender
end

local function isSelf(sender)
    if type(sender) ~= "string" then
        return false
    end
    return normalizeSender(sender):lower() == GG.Util:GetPlayerFullName():lower()
end

local function isGroupMember(sender)
    if type(sender) ~= "string" then
        return false
    end

    local normalized = normalizeSender(sender):lower()
    for _, name in ipairs(GG.Util:GetGroupRoster()) do
        if name:lower() == normalized then
            return true
        end
    end
    return false
end

local function makeTransferId()
    return tostring(time()) .. tostring(math.random(100000, 999999))
end

function Sync:SerializeGame(game)
    return table.concat({
        escape(game.id),
        tostring(tonumber(game.completedAt) or 0),
        escape(game.day),
        escape(game.patch),
        tostring(tonumber(game.amount) or 0),
        escape(game.gameName),
        tostring(tonumber(game.round) or 1),
        escape(game.winner),
        escape(game.loser),
        tostring(tonumber(game.payout) or 0),
        encodeNames(game.participants),
        encodeRolls(game.rolls),
    }, "|")
end

function Sync:DeserializeGame(payload)
    local fields = split(payload, "|")
    if #fields ~= 12 then
        return nil
    end

    local rolls = decodeRolls(fields[12])
    if not rolls then
        return nil
    end

    return {
        id = unescape(fields[1]),
        completedAt = tonumber(fields[2]),
        day = unescape(fields[3]),
        patch = unescape(fields[4]),
        amount = tonumber(fields[5]),
        gameName = unescape(fields[6]),
        round = tonumber(fields[7]),
        winner = unescape(fields[8]),
        loser = unescape(fields[9]),
        payout = tonumber(fields[10]),
        participants = decodeNames(fields[11]),
        rolls = rolls,
    }
end

function Sync:ValidateGame(game)
    if type(game) ~= "table" or type(game.id) ~= "string" or game.id == "" or #game.id > 128 then
        return false
    end

    game.completedAt = tonumber(game.completedAt)
    game.amount = tonumber(game.amount)
    game.round = tonumber(game.round)
    game.payout = tonumber(game.payout)
    if not game.completedAt or game.completedAt <= 0 or game.completedAt ~= math.floor(game.completedAt) then
        return false
    end
    if type(game.day) ~= "string" or not game.day:match("^%d%d%d%d%-%d%d%-%d%d$") then
        return false
    end
    if type(game.patch) ~= "string" or #game.patch > 32
        or type(game.gameName) ~= "string" or game.gameName == "" or #game.gameName > 128
        or type(game.winner) ~= "string" or type(game.loser) ~= "string"
    then
        return false
    end
    if not game.amount or game.amount < 2 or game.amount > 1000000000 or game.amount ~= math.floor(game.amount) then
        return false
    end
    if not game.round or game.round < 1 or game.round ~= math.floor(game.round) then
        return false
    end
    if type(game.participants) ~= "table" or #game.participants < 2 or #game.participants > 40 then
        return false
    end
    if type(game.rolls) ~= "table" or #game.rolls ~= #game.participants then
        return false
    end

    local participantNames = {}
    for _, name in ipairs(game.participants) do
        if type(name) ~= "string" or name == "" or #name > 128 then
            return false
        end
        local normalizedName = name:lower()
        if participantNames[normalizedName] then
            return false
        end
        participantNames[normalizedName] = true
    end

    local highestValue = -1
    local lowestValue = game.amount + 1
    local highestName
    local lowestName
    local highestCount = 0
    local lowestCount = 0
    local rolledNames = {}
    for _, roll in ipairs(game.rolls) do
        local value = tonumber(roll.value)
        local normalizedName = type(roll.name) == "string" and roll.name:lower() or nil
        if not normalizedName or not participantNames[normalizedName] or rolledNames[normalizedName] then
            return false
        end
        rolledNames[normalizedName] = true
        if not value or value < 1 or value > game.amount or value ~= math.floor(value) then
            return false
        end

        if value > highestValue then
            highestValue = value
            highestName = roll.name
            highestCount = 1
        elseif value == highestValue then
            highestCount = highestCount + 1
        end

        if value < lowestValue then
            lowestValue = value
            lowestName = roll.name
            lowestCount = 1
        elseif value == lowestValue then
            lowestCount = lowestCount + 1
        end
    end

    return highestCount == 1
        and lowestCount == 1
        and game.winner == highestName
        and game.loser == lowestName
        and game.payout == highestValue - lowestValue
end

function Sync:IsReceiving()
    return self.receiving == true
end

function Sync:IsSending()
    return self.sending == true
end

function Sync:SetReceiving(enabled)
    enabled = enabled and true or false
    if enabled and not GG.Chat:GetAutomaticChannel() then
        GG:Print(GG:L("ERROR_GROUP_REQUIRED"))
        return false
    end

    self.receiving = enabled
    if not enabled then
        self.incomingTransfers = {}
    end
    GG:Fire("SYNC_STATE_CHANGED")
    GG:Print(GG:L(enabled and "SYNC_RECEIVE_ENABLED" or "SYNC_RECEIVE_DISABLED"))
    return true
end

function Sync:ToggleReceiving()
    return self:SetReceiving(not self:IsReceiving())
end

function Sync:SendAddonMessage(message, channel, queueName, callback)
    ChatThrottleLib:SendAddonMessage(
        "NORMAL",
        PREFIX,
        message,
        channel,
        nil,
        queueName or PREFIX,
        callback
    )
end

function Sync:SendPeriod(period)
    if self:IsSending() then
        return false
    end

    local channel = GG.Chat:GetAutomaticChannel()
    if not channel then
        GG:Print(GG:L("ERROR_GROUP_REQUIRED"))
        return false
    end

    local games = GG.Stats:GetGamesForPeriod(period)
    if #games == 0 then
        GG:Print(GG:L("NO_STATS"))
        return false
    end
    if #games > MAX_GAMES then
        GG:Print(GG:L("SYNC_TOO_MANY_GAMES", MAX_GAMES))
        return false
    end

    local requestId = makeTransferId()
    local request = {
        id = requestId,
        period = period,
        games = games,
        channel = channel,
        listeners = {},
    }
    self.pendingRequests[requestId] = request
    self.sending = true
    GG:Fire("SYNC_STATE_CHANGED")
    self:SendAddonMessage("Q|" .. requestId, channel, PREFIX .. requestId)

    C_Timer.After(1, function()
        if self.pendingRequests[requestId] == request then
            self:BeginTransfer(request)
        end
    end)
    return true
end

function Sync:BeginTransfer(request)
    self.pendingRequests[request.id] = nil
    local listenerCount = GG.Util:TableCount(request.listeners)
    if listenerCount == 0 then
        self.sending = false
        GG:Fire("SYNC_STATE_CHANGED")
        GG:Print(GG:L("SYNC_NO_LISTENERS"))
        return
    end

    local payloads = {}
    for gameIndex, game in ipairs(request.games) do
        if not self:ValidateGame(game) then
            self.sending = false
            GG:Fire("SYNC_STATE_CHANGED")
            GG:Print(GG:L("SYNC_TRANSFER_FAILED"))
            return
        end

        local payload = self:SerializeGame(game)
        local chunkCount = math.ceil(#payload / CHUNK_SIZE)
        if chunkCount < 1 or chunkCount > MAX_CHUNKS_PER_GAME then
            self.sending = false
            GG:Fire("SYNC_STATE_CHANGED")
            GG:Print(GG:L("SYNC_TRANSFER_FAILED"))
            return
        end
        payloads[gameIndex] = { payload = payload, chunkCount = chunkCount }
    end

    local transferId = makeTransferId()
    local queueName = PREFIX .. transferId
    self:SendAddonMessage(
        table.concat({ "B", transferId, tostring(#request.games), request.period }, "|"),
        request.channel,
        queueName
    )

    for gameIndex, payloadEntry in ipairs(payloads) do
        local payload = payloadEntry.payload
        local chunkCount = payloadEntry.chunkCount

        for chunkIndex = 1, chunkCount do
            local first = ((chunkIndex - 1) * CHUNK_SIZE) + 1
            local chunk = payload:sub(first, first + CHUNK_SIZE - 1)
            self:SendAddonMessage(table.concat({
                "D",
                transferId,
                tostring(gameIndex),
                tostring(chunkIndex),
                tostring(chunkCount),
                chunk,
            }, "|"), request.channel, queueName)
        end
    end

    self:SendAddonMessage("E|" .. transferId .. "|" .. tostring(#request.games), request.channel, queueName,
        function(_, success)
            self.sending = false
            GG:Fire("SYNC_STATE_CHANGED")
            if success then
                GG:Print(GG:L("SYNC_SEND_DONE", #request.games, listenerCount))
            else
                GG:Print(GG:L("SYNC_TRANSFER_FAILED"))
            end
        end)
end

function Sync:ScheduleIncomingTimeout(key, transfer)
    C_Timer.After(TRANSFER_TIMEOUT, function()
        if self.incomingTransfers[key] ~= transfer then
            return
        end

        local idleTime = time() - transfer.lastActivity
        if idleTime < TRANSFER_TIMEOUT then
            self:ScheduleIncomingTimeout(key, transfer)
            return
        end

        self.incomingTransfers[key] = nil
        GG:Fire("SYNC_STATE_CHANGED")
        GG:Print(GG:L("SYNC_TRANSFER_FAILED"))
    end)
end

function Sync:BeginIncomingTransfer(sender, transferId, gameCount, period)
    if not self:IsReceiving() or gameCount < 1 or gameCount > MAX_GAMES then
        return
    end

    local senderKey = sender:lower()
    for existingKey, existingTransfer in pairs(self.incomingTransfers) do
        if existingTransfer.sender:lower() == senderKey then
            self.incomingTransfers[existingKey] = nil
        end
    end

    local key = senderKey .. "|" .. transferId
    local transfer = {
        sender = sender,
        id = transferId,
        expectedGames = gameCount,
        period = period,
        games = {},
        lastActivity = time(),
    }
    self.incomingTransfers[key] = transfer
    GG:Fire("SYNC_STATE_CHANGED")
    self:ScheduleIncomingTimeout(key, transfer)
end

function Sync:StoreIncomingChunk(sender, transferId, gameIndex, chunkIndex, chunkCount, chunk)
    local key = sender:lower() .. "|" .. transferId
    local transfer = self.incomingTransfers[key]
    if not transfer
        or gameIndex < 1
        or gameIndex > transfer.expectedGames
        or chunkIndex < 1
        or chunkCount < 1
        or chunkCount > MAX_CHUNKS_PER_GAME
        or chunkIndex > chunkCount
    then
        return
    end

    local entry = transfer.games[gameIndex]
    if not entry then
        entry = { expectedChunks = chunkCount, chunks = {} }
        transfer.games[gameIndex] = entry
    elseif entry.expectedChunks ~= chunkCount then
        return
    end
    entry.chunks[chunkIndex] = chunk
    transfer.lastActivity = time()
end

function Sync:FinishIncomingTransfer(sender, transferId, gameCount)
    local key = sender:lower() .. "|" .. transferId
    local transfer = self.incomingTransfers[key]
    if not transfer or gameCount ~= transfer.expectedGames then
        return
    end

    local games = {}
    for gameIndex = 1, transfer.expectedGames do
        local entry = transfer.games[gameIndex]
        if not entry then
            self.incomingTransfers[key] = nil
            GG:Fire("SYNC_STATE_CHANGED")
            GG:Print(GG:L("SYNC_TRANSFER_FAILED"))
            return
        end

        local chunks = {}
        for chunkIndex = 1, entry.expectedChunks do
            if not entry.chunks[chunkIndex] then
                self.incomingTransfers[key] = nil
                GG:Fire("SYNC_STATE_CHANGED")
                GG:Print(GG:L("SYNC_TRANSFER_FAILED"))
                return
            end
            chunks[chunkIndex] = entry.chunks[chunkIndex]
        end

        local game = self:DeserializeGame(table.concat(chunks))
        if not self:ValidateGame(game) then
            self.incomingTransfers[key] = nil
            GG:Fire("SYNC_STATE_CHANGED")
            GG:Print(GG:L("SYNC_TRANSFER_FAILED"))
            return
        end
        games[gameIndex] = game
    end

    self.incomingTransfers[key] = nil
    local imported, skipped = GG.Database:InsertGamesIfMissing(games)
    GG:Fire("SYNC_STATE_CHANGED")
    GG:Print(GG:L("SYNC_RECEIVE_DONE", GG.Util:GetShortName(sender), imported, skipped))
end

function Sync:OnAddonMessage(prefix, message, channel, sender)
    if prefix ~= PREFIX
        or type(message) ~= "string"
        or not supportedChannels[channel]
        or isSelf(sender)
        or not isGroupMember(sender)
    then
        return
    end

    sender = normalizeSender(sender)

    local requestId = message:match("^Q|([^|]+)$")
    if requestId then
        if self:IsReceiving() then
            self:SendAddonMessage("L|" .. requestId, channel, PREFIX .. requestId)
        end
        return
    end

    requestId = message:match("^L|([^|]+)$")
    if requestId then
        local request = self.pendingRequests[requestId]
        if request and request.channel == channel then
            request.listeners[sender:lower()] = true
        end
        return
    end

    local transferId, gameCount, period = message:match("^B|([^|]+)|(%d+)|([A-Z]+)$")
    if transferId and (period == "ALL" or period == "PATCH" or period == "TODAY") then
        self:BeginIncomingTransfer(sender, transferId, tonumber(gameCount), period)
        return
    end

    local gameIndex, chunkIndex, chunkCount, chunk
    transferId, gameIndex, chunkIndex, chunkCount, chunk =
        message:match("^D|([^|]+)|(%d+)|(%d+)|(%d+)|(.*)$")
    if transferId then
        self:StoreIncomingChunk(
            sender,
            transferId,
            tonumber(gameIndex),
            tonumber(chunkIndex),
            tonumber(chunkCount),
            chunk
        )
        return
    end

    transferId, gameCount = message:match("^E|([^|]+)|(%d+)$")
    if transferId then
        self:FinishIncomingTransfer(sender, transferId, tonumber(gameCount))
    end
end

function Sync:OnGroupChanged()
    if not GG.Chat:GetAutomaticChannel() then
        self.receiving = false
        self.sending = false
        self.pendingRequests = {}
        self.incomingTransfers = {}
        GG:Fire("SYNC_STATE_CHANGED")
    end
end

function Sync:Initialize()
    self.receiving = false
    self.sending = false
    self.pendingRequests = {}
    self.incomingTransfers = {}
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    GG:RegisterCallback("GROUP_CHANGED", self, "OnGroupChanged")
end
