local addonName, GG = ...

GG.addonName = addonName
GG.displayName = "Gold Gambit"
GG.schemaVersion = 1
GG.callbacks = {}

GG.colors = {
    accent = { 0.95, 0.76, 0.20 },
    success = { 0.28, 0.82, 0.45 },
    danger = { 0.92, 0.30, 0.30 },
    muted = { 0.62, 0.65, 0.70 },
    panel = { 0.055, 0.062, 0.075, 0.94 },
    row = { 0.10, 0.11, 0.14, 0.72 },
}

function GG:RegisterCallback(eventName, owner, method)
    if not self.callbacks[eventName] then
        self.callbacks[eventName] = {}
    end

    table.insert(self.callbacks[eventName], {
        owner = owner,
        method = method,
    })
end

function GG:Fire(eventName, ...)
    local listeners = self.callbacks[eventName]
    if not listeners then
        return
    end

    for _, listener in ipairs(listeners) do
        local method = listener.method
        if type(method) == "string" then
            method = listener.owner[method]
        end

        if method then
            method(listener.owner, ...)
        end
    end
end

function GG:L(key, ...)
    return self.Locale:Get(key, ...)
end

function GG:Print(message)
    local prefix = string.format("|cfff2c234%s|r", self.displayName)
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: %s", prefix, tostring(message)))
end

function GG:SetEnabled(button, enabled)
    if enabled then
        button:Enable()
        button:SetAlpha(1)
    else
        button:Disable()
        button:SetAlpha(0.45)
    end
end

_G.GoldGambit = GG
