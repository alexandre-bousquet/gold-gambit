local _, GG = ...

local Locale = {
    dictionaries = {},
    current = "enUS",
}

GG.Locale = Locale

function Locale:Register(locale, translations)
    self.dictionaries[locale] = translations
end

function Locale:DetectDefault()
    return GetLocale() == "frFR" and "frFR" or "enUS"
end

function Locale:Set(locale)
    if not self.dictionaries[locale] then
        locale = "enUS"
    end

    self.current = locale
end

function Locale:GetCurrent()
    return self.current
end

function Locale:Get(key, ...)
    local dictionary = self.dictionaries[self.current] or self.dictionaries.enUS or {}
    local fallback = self.dictionaries.enUS or {}
    local value = dictionary[key] or fallback[key] or key

    if select("#", ...) > 0 then
        local ok, formatted = pcall(string.format, value, ...)
        if ok then
            return formatted
        end
    end

    return value
end
