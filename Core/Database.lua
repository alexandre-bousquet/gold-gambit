local _, GG = ...

local Database = {}
GG.Database = Database

local function createDefaults()
    return {
        schemaVersion = GG.schemaVersion,
        settings = {
            locale = GG.Locale:DetectDefault(),
            gameName = "Gold Gambit",
            autoJoin = true,
            statsPeriod = "ALL",
            statsChannel = "AUTO",
            lastAmount = 10000,
        },
        history = {},
    }
end

local function mergeMissing(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            if type(value) == "table" then
                target[key] = {}
                mergeMissing(target[key], value)
            else
                target[key] = value
            end
        elseif type(value) == "table" and type(target[key]) == "table" then
            mergeMissing(target[key], value)
        end
    end
end

function Database:Initialize()
    if type(_G.GoldGambitDB) ~= "table" then
        _G.GoldGambitDB = createDefaults()
    end

    mergeMissing(_G.GoldGambitDB, createDefaults())

    if type(_G.GoldGambitDB.settings) ~= "table" then
        _G.GoldGambitDB.settings = createDefaults().settings
    end

    if type(_G.GoldGambitDB.history) ~= "table" then
        _G.GoldGambitDB.history = {}
    end

    local settings = _G.GoldGambitDB.settings
    if settings.locale ~= "frFR" and settings.locale ~= "enUS" then
        settings.locale = GG.Locale:DetectDefault()
    end
    if type(settings.gameName) ~= "string" or settings.gameName == "" then
        settings.gameName = "Gold Gambit"
    end
    if type(settings.autoJoin) ~= "boolean" then
        settings.autoJoin = true
    end
    if settings.statsPeriod ~= "ALL" and settings.statsPeriod ~= "PATCH" and settings.statsPeriod ~= "TODAY" then
        settings.statsPeriod = "ALL"
    end
    local allowedChannels = {
        AUTO = true,
        INSTANCE_CHAT = true,
        RAID = true,
        PARTY = true,
        SAY = true,
    }
    if not allowedChannels[settings.statsChannel] then
        settings.statsChannel = "AUTO"
    end
    settings.lastAmount = tonumber(settings.lastAmount) or 10000
    if settings.lastAmount < 2 or settings.lastAmount > 1000000000 then
        settings.lastAmount = 10000
    end

    _G.GoldGambitDB.schemaVersion = GG.schemaVersion
    self.data = _G.GoldGambitDB
end

function Database:GetSettings()
    return self.data.settings
end

function Database:GetHistory()
    return self.data.history
end

function Database:AddGame(game)
    table.insert(self.data.history, game)
    GG:Fire("HISTORY_CHANGED", game)
end

function Database:ResetStats()
    self.data.history = {}
    _G.GoldGambitDB.history = self.data.history
    GG:Fire("HISTORY_CHANGED")
end

function Database:Reset()
    _G.GoldGambitDB = createDefaults()
    self.data = _G.GoldGambitDB
    GG.Locale:Set(self.data.settings.locale)
    GG:Fire("DATABASE_RESET")
    GG:Fire("LOCALE_CHANGED")
    GG:Fire("SETTINGS_CHANGED")
    GG:Fire("HISTORY_CHANGED")
end
