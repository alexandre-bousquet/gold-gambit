local _, GG = ...

local RollParser = {}
GG.RollParser = RollParser

function RollParser:Initialize()
    self.matcher = GG.Util:CreateFormatMatcher(RANDOM_ROLL_RESULT or "%s rolls %d (%d-%d)")
end

function RollParser:Parse(message)
    local values = GG.Util:MatchFormattedString(self.matcher, message)
    if values then
        local roll = tonumber(values[2])
        local minimum = tonumber(values[3])
        local maximum = tonumber(values[4])
        if values[1] and roll and minimum and maximum then
            return values[1], roll, minimum, maximum
        end
    end

    local cleanMessage = tostring(message):gsub("%.$", "")
    local name, roll, minimum, maximum = cleanMessage:match("^(.+) rolls (%d+) %((%d+)%-(%d+)%)$")
    if not name then
        name, roll, minimum, maximum = cleanMessage:match("^(.+) obtient un (%d+) %((%d+)%-(%d+)%)$")
    end

    if name then
        return name, tonumber(roll), tonumber(minimum), tonumber(maximum)
    end

    return nil
end
