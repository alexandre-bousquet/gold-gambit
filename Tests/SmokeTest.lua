-- Core smoke test for a standalone Lua runtime. This file is not loaded by WoW.

local sentMessages = {}
local chatLines = {}

LE_PARTY_CATEGORY_INSTANCE = 1
UNKNOWNOBJECT = "Unknown"
YOU = "You"
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"

function GetLocale()
    return "enUS"
end

function GetBuildInfo()
    return "12.1.0", "69111", "Aug 2026", 120100
end

function GetNormalizedRealmName()
    return "TestRealm"
end

function GetRealmName()
    return "Test Realm"
end

local units = {
    player = { "Alice", "TestRealm" },
    party1 = { "Bob", "TestRealm" },
}

function UnitExists(unit)
    return units[unit] ~= nil
end

function UnitFullName(unit)
    local entry = units[unit]
    if not entry then
        return nil
    end
    return entry[1], entry[2]
end

function UnitName(unit)
    local entry = units[unit]
    return entry and entry[1] or nil
end

function IsInRaid()
    return false
end

function IsInGroup(category)
    return category == LE_PARTY_CATEGORY_INSTANCE
end

function GetNumGroupMembers()
    return 2
end

function GetNumSubgroupMembers()
    return 1
end

function SendChatMessage(message, channel)
    table.insert(sentMessages, { message = message, channel = channel })
end

function RandomRoll(minimum, maximum)
    _G.lastRandomRoll = { minimum, maximum }
end

function time()
    return os.time()
end

function date(format, timestamp)
    return os.date(format, timestamp)
end

C_Timer = {
    After = function(_, callback)
        callback()
    end,
}

DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, message)
        table.insert(chatLines, message)
    end,
}

local GG = {}

local function loadAddonFile(path)
    local chunk, errorMessage = loadfile(path)
    assert(chunk, errorMessage)
    return chunk("GoldGambit", GG)
end

loadAddonFile("Bootstrap.lua")
loadAddonFile("Localization/Locale.lua")
loadAddonFile("Localization/enUS.lua")
loadAddonFile("Localization/frFR.lua")
loadAddonFile("Core/Util.lua")
loadAddonFile("Core/Database.lua")
loadAddonFile("Core/Chat.lua")
loadAddonFile("Core/RollParser.lua")
loadAddonFile("Core/Stats.lua")
loadAddonFile("Core/Game.lua")

GoldGambitDB = nil
GG.Database:Initialize()
GG.Locale:Set("enUS")
GG.RollParser:Initialize()
GG.Game:Initialize()

local positionalMatcher = GG.Util:CreateFormatMatcher("%1$s rolls %2$d (%3$d-%4$d)")
local positionalValues = GG.Util:MatchFormattedString(positionalMatcher, "Alice rolls 42 (1-100)")
assert(positionalValues[1] == "Alice")
assert(tonumber(positionalValues[2]) == 42)
assert(tonumber(positionalValues[3]) == 1)
assert(tonumber(positionalValues[4]) == 100)

RANDOM_ROLL_RESULT = "%s obtient un %d (%d-%d)"
GG.RollParser:Initialize()
local frenchName, frenchRoll, frenchMinimum, frenchMaximum =
    GG.RollParser:Parse("Alice obtient un 42 (1-100)")
assert(frenchName == "Alice")
assert(frenchRoll == 42)
assert(frenchMinimum == 1)
assert(frenchMaximum == 100)
RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
GG.RollParser:Initialize()

assert(GG.Game:Start(10000))
assert(GG.Game:GetState() == GG.Game.STATE_OPEN)
assert(GG.Game:GetParticipantCount() == 1)
GG.Game:OnChatMessage("CHAT_MSG_INSTANCE_CHAT", "1", "Bob-TestRealm")
assert(GG.Game:GetParticipantCount() == 2)
assert(GG.Game:CloseEntries())
assert(GG.Game:GetState() == GG.Game.STATE_ROLLING)

GG.Game:OnSystemMessage("Alice rolls 9000 (1-10000)")
GG.Game:OnSystemMessage("Bob rolls 1000 (1-10000)")
assert(GG.Game:GetState() == GG.Game.STATE_RESOLVED)
assert(#GoldGambitDB.history == 1)
assert(GoldGambitDB.history[1].winner == "Alice-TestRealm")
assert(GoldGambitDB.history[1].loser == "Bob-TestRealm")
assert(GoldGambitDB.history[1].payout == 8000)

local ranking, gamesCount = GG.Stats:BuildRanking("ALL")
assert(gamesCount == 1)
assert(#ranking == 2)
assert(ranking[1].name == "Alice-TestRealm")
assert(ranking[1].net == 8000)
assert(ranking[1].patron == "Bob-TestRealm")
assert(ranking[2].nemesis == "Alice-TestRealm")

assert(GG.Game:Start(50000))
GG.Game:OnChatMessage("CHAT_MSG_INSTANCE_CHAT", "1", "Bob-TestRealm")
assert(GG.Game:CloseEntries())

GG.Game:OnSystemMessage("Alice rolls 12 (1-100)")
assert(next(GG.Game:GetSession().rolls) == nil)

GG.Game:OnSystemMessage("Alice rolls 25000 (1-50000)")
GG.Game:OnSystemMessage("Alice rolls 30000 (1-50000)")
GG.Game:OnSystemMessage("Bob rolls 25000 (1-50000)")
assert(GG.Game:GetState() == GG.Game.STATE_ROLLING)
assert(GG.Game:GetSession().round == 2)
assert(next(GG.Game:GetSession().rolls) == nil)

GG.Game:OnSystemMessage("Alice rolls 45000 (1-50000)")
GG.Game:OnSystemMessage("Bob rolls 5000 (1-50000)")
assert(GG.Game:GetState() == GG.Game.STATE_RESOLVED)
assert(#GoldGambitDB.history == 2)
assert(GoldGambitDB.history[2].round == 2)
assert(GoldGambitDB.history[2].payout == 40000)

local patchRanking, patchGames = GG.Stats:BuildRanking("PATCH")
assert(#patchRanking == 2)
assert(patchGames == 2)

GG.Stats:Publish("ALL", "AUTO")
assert(#sentMessages >= 8)

local settingsBeforeStatsReset = GoldGambitDB.settings
GG.Database:ResetStats()
assert(#GoldGambitDB.history == 0)
assert(GoldGambitDB.settings == settingsBeforeStatsReset)
local resetRanking, resetGamesCount = GG.Stats:BuildRanking("ALL")
assert(#resetRanking == 0)
assert(resetGamesCount == 0)

print("Gold Gambit smoke test: OK")
