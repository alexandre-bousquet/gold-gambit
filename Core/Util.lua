local _, GG = ...

local Util = {}
GG.Util = Util

local instanceCategory = LE_PARTY_CATEGORY_INSTANCE
    or (Enum and Enum.PartyCategory and Enum.PartyCategory.Instance)
    or 1

function Util:GetInstanceGroupCategory()
    return instanceCategory
end

function Util:GetActiveGroupCategory()
    if IsInGroup(instanceCategory) then
        return instanceCategory
    end

    return nil
end

function Util:Trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return value:match("^%s*(.-)%s*$") or ""
end

function Util:TableCount(values)
    local count = 0
    for _ in pairs(values or {}) do
        count = count + 1
    end
    return count
end

function Util:CopyArray(values)
    local copy = {}
    for index, value in ipairs(values or {}) do
        copy[index] = value
    end
    return copy
end

function Util:FormatNumber(value)
    value = tonumber(value) or 0
    local negative = value < 0
    local digits = tostring(math.floor(math.abs(value) + 0.5))
    local separator = GG.Locale:GetCurrent() == "frFR" and " " or ","

    while true do
        local updated, replacements = digits:gsub("^(%d+)(%d%d%d)", "%1" .. separator .. "%2")
        digits = updated
        if replacements == 0 then
            break
        end
    end

    return (negative and "-" or "") .. digits
end

function Util:FormatPercent(value)
    return string.format("%.1f", tonumber(value) or 0)
end

function Util:GetCurrentPatch()
    local version = GetBuildInfo and GetBuildInfo() or "12.1.0"
    local major, minor = tostring(version):match("^(%d+)%.(%d+)")
    if not major then
        return "12.1"
    end

    return major .. "." .. minor
end

function Util:GetTodayKey(timestamp)
    return date("%Y-%m-%d", timestamp or time())
end

function Util:GetPlayerFullName()
    local name, realm = UnitFullName("player")
    if not name then
        name = UnitName("player") or UNKNOWNOBJECT
    end

    if not realm or realm == "" then
        realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
    end

    if realm and realm ~= "" then
        return name .. "-" .. realm:gsub("%s+", "")
    end

    return name
end

function Util:GetUnitFullName(unit)
    if not UnitExists(unit) then
        return nil
    end

    local name, realm = UnitFullName(unit)
    if not name then
        return nil
    end

    if not realm or realm == "" then
        realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
    end

    if realm and realm ~= "" then
        return name .. "-" .. realm:gsub("%s+", "")
    end

    return name
end

function Util:GetShortName(name)
    if type(name) ~= "string" then
        return "?"
    end

    return name:match("^([^-]+)") or name
end

function Util:GetGroupRoster()
    local roster = {}
    local seen = {}
    local category = self:GetActiveGroupCategory()

    local function addUnit(unit)
        local fullName = self:GetUnitFullName(unit)
        if fullName and not seen[fullName:lower()] then
            seen[fullName:lower()] = true
            table.insert(roster, fullName)
        end
    end

    if IsInRaid(category) then
        for index = 1, GetNumGroupMembers(category) do
            addUnit("raid" .. index)
        end
    else
        addUnit("player")
        if IsInGroup(category) then
            for index = 1, GetNumSubgroupMembers(category) do
                addUnit("party" .. index)
            end
        end
    end

    return roster
end

function Util:ResolveGroupName(rawName)
    rawName = self:Trim(rawName):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if rawName == "" then
        return nil
    end

    if YOU and rawName:lower() == tostring(YOU):lower() then
        return self:GetPlayerFullName()
    end

    local rawLower = rawName:lower()
    local rawShort = self:GetShortName(rawName):lower()
    local shortMatches = {}

    for _, fullName in ipairs(self:GetGroupRoster()) do
        if fullName:lower() == rawLower then
            return fullName
        end

        if self:GetShortName(fullName):lower() == rawShort then
            table.insert(shortMatches, fullName)
        end
    end

    if #shortMatches == 1 then
        return shortMatches[1]
    end

    if rawName:find("-", 1, true) then
        return rawName
    end

    local realm = GetNormalizedRealmName and GetNormalizedRealmName() or GetRealmName()
    if realm and realm ~= "" then
        return rawName .. "-" .. realm:gsub("%s+", "")
    end

    return rawName
end

local function escapePattern(value)
    return value:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

function Util:CreateFormatMatcher(formatString)
    if type(formatString) ~= "string" or formatString == "" then
        return nil
    end

    local tokens = {}
    local implicitPosition = 0

    local function addToken(kind, explicitPosition)
        implicitPosition = implicitPosition + 1
        local token = {
            kind = kind,
            position = tonumber(explicitPosition) or implicitPosition,
        }
        table.insert(tokens, token)
        return string.char(1) .. tostring(#tokens) .. string.char(2)
    end

    local marked = formatString:gsub("%%(%d+)%$([sd])", function(position, kind)
        return addToken(kind, position)
    end)

    marked = marked:gsub("%%([sd])", function(kind)
        return addToken(kind, nil)
    end)

    local pattern = escapePattern(marked)
    for index, token in ipairs(tokens) do
        local marker = string.char(1) .. tostring(index) .. string.char(2)
        local capture = token.kind == "d" and "(%d+)" or "(.+)"
        pattern = pattern:gsub(marker, function()
            return capture
        end)
    end

    return {
        pattern = "^" .. pattern .. "$",
        tokens = tokens,
    }
end

function Util:MatchFormattedString(matcher, message)
    if not matcher or type(message) ~= "string" then
        return nil
    end

    local captures = { message:match(matcher.pattern) }
    if #captures == 0 then
        return nil
    end

    local values = {}
    for index, token in ipairs(matcher.tokens) do
        values[token.position] = captures[index]
    end

    return values
end
