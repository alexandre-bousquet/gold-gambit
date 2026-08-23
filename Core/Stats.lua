local _, GG = ...

local Stats = {}
GG.Stats = Stats

local function isGameInPeriod(game, period)
    if period == "ALL" then
        return true
    end

    if period == "PATCH" then
        return game.patch == GG.Util:GetCurrentPatch()
    end

    if period == "TODAY" then
        local day = game.day or GG.Util:GetTodayKey(game.completedAt)
        return day == GG.Util:GetTodayKey()
    end

    return true
end

local function getRelationshipLeader(values)
    local bestName
    local bestAmount = -1

    for name, amount in pairs(values or {}) do
        if not bestName or amount > bestAmount or (amount == bestAmount and name < bestName) then
            bestName = name
            bestAmount = amount
        end
    end

    return bestName, math.max(bestAmount, 0)
end

local function ensurePlayer(aggregate, name)
    if not aggregate[name] then
        aggregate[name] = {
            name = name,
            games = 0,
            wins = 0,
            losses = 0,
            goldWon = 0,
            goldLost = 0,
            paidTo = {},
            receivedFrom = {},
        }
    end

    return aggregate[name]
end

function Stats:GetPeriodLabel(period)
    if period == "PATCH" then
        return GG:L("PERIOD_PATCH", GG.Util:GetCurrentPatch())
    end

    if period == "TODAY" then
        return GG:L("PERIOD_TODAY")
    end

    return GG:L("PERIOD_ALL")
end

function Stats:GetGamesForPeriod(period)
    local games = {}
    for _, game in ipairs(GG.Database:GetHistory()) do
        if isGameInPeriod(game, period) then
            table.insert(games, game)
        end
    end
    return games
end

function Stats:BuildRanking(period)
    local aggregate = {}
    local gamesCount = 0

    for _, game in ipairs(GG.Database:GetHistory()) do
        if isGameInPeriod(game, period) then
            gamesCount = gamesCount + 1

            local participants = game.participants or {}
            if #participants == 0 then
                for _, roll in ipairs(game.rolls or {}) do
                    table.insert(participants, roll.name)
                end
            end

            for _, name in ipairs(participants) do
                local player = ensurePlayer(aggregate, name)
                player.games = player.games + 1
            end

            local payout = tonumber(game.payout) or 0
            local winner = game.winner and ensurePlayer(aggregate, game.winner) or nil
            local loser = game.loser and ensurePlayer(aggregate, game.loser) or nil

            if winner then
                winner.wins = winner.wins + 1
                winner.goldWon = winner.goldWon + payout
                if loser then
                    winner.receivedFrom[loser.name] = (winner.receivedFrom[loser.name] or 0) + payout
                end
            end

            if loser then
                loser.losses = loser.losses + 1
                loser.goldLost = loser.goldLost + payout
                if winner then
                    loser.paidTo[winner.name] = (loser.paidTo[winner.name] or 0) + payout
                end
            end
        end
    end

    local ranking = {}
    for _, player in pairs(aggregate) do
        player.net = player.goldWon - player.goldLost
        player.winRate = player.games > 0 and (player.wins / player.games) * 100 or 0
        player.lossRate = player.games > 0 and (player.losses / player.games) * 100 or 0
        player.nemesis = getRelationshipLeader(player.paidTo)
        player.patron = getRelationshipLeader(player.receivedFrom)
        player.displayName = GG.Util:GetShortName(player.name)
        table.insert(ranking, player)
    end

    table.sort(ranking, function(left, right)
        if left.net ~= right.net then
            return left.net > right.net
        end
        if left.goldWon ~= right.goldWon then
            return left.goldWon > right.goldWon
        end
        if left.wins ~= right.wins then
            return left.wins > right.wins
        end
        return left.name < right.name
    end)

    for rank, player in ipairs(ranking) do
        player.rank = rank
        player.nemesisDisplay = player.nemesis and GG.Util:GetShortName(player.nemesis) or "-"
        player.patronDisplay = player.patron and GG.Util:GetShortName(player.patron) or "-"
    end

    return ranking, gamesCount
end

function Stats:Publish(period, channelPreference)
    local ranking = self:BuildRanking(period)
    if #ranking == 0 then
        GG:Print(GG:L("NO_STATS"))
        return
    end

    local gameName = GG.Database:GetSettings().gameName
    local lines = {
        GG:L("STATS_HEADER", gameName, self:GetPeriodLabel(period)),
    }

    for _, player in ipairs(ranking) do
        table.insert(lines, GG:L(
            "STATS_ROW",
            player.rank,
            player.displayName,
            GG.Util:FormatNumber(player.net),
            GG.Util:FormatPercent(player.winRate)
        ))
    end

    GG.Chat:SendLines(lines, channelPreference)
end
