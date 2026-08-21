local _, GG = ...

local UI = {
    widgetCounter = 0,
}

GG.UI = UI

function UI:GetWidgetName(prefix)
    self.widgetCounter = self.widgetCounter + 1
    return (GG.addonName or "GoldGambit") .. prefix .. self.widgetCounter
end

function UI:CreatePanel(parent)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(unpack(GG.colors.panel))
    panel:SetBackdropBorderColor(0.20, 0.22, 0.27, 0.9)
    return panel
end

function UI:CreateLabel(parent, fontObject, text)
    local label = parent:CreateFontString(nil, "ARTWORK", fontObject or "GameFontHighlight")
    label:SetText(text or "")
    label:SetJustifyH("LEFT")
    return label
end

function UI:CreateButton(parent, width, height, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, height)
    button:SetText(text or "")
    if onClick then
        button:SetScript("OnClick", onClick)
    end
    return button
end

function UI:CreateEditBox(parent, width, height)
    local editBox = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    editBox:SetSize(width, height)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject("ChatFontNormal")
    editBox:SetTextInsets(6, 6, 0, 0)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    return editBox
end

function UI:CreateCheckButton(parent, text, onClick)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check.label = self:CreateLabel(check, "GameFontHighlight", text)
    check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    check:SetHitRectInsets(0, -220, 0, 0)
    if onClick then
        check:SetScript("OnClick", onClick)
    end
    return check
end

function UI:CreateDropdown(parent, width, onValueChanged)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetSize(width, 30)
    dropdown.items = {}
    dropdown.value = nil
    dropdown.onValueChanged = onValueChanged

    function dropdown:SetItems(items)
        self.items = items or {}
        self:SetupMenu(function(owner, rootDescription)
            for _, item in ipairs(owner.items) do
                rootDescription:CreateRadio(
                    item.text,
                    function(value)
                        return owner.value == value
                    end,
                    function(value)
                        owner:SetValue(value, true)
                    end,
                    item.value
                )
            end
        end)
        self:GenerateMenu()
    end

    function dropdown:SetValue(value, notify)
        self.value = value
        self:GenerateMenu()

        if notify and self.onValueChanged then
            self.onValueChanged(value)
        end
    end

    function dropdown:GetValue()
        return self.value
    end

    dropdown:SetDefaultText("-")
    return dropdown
end

function UI:CreateScrollList(parent, width, height, rowHeight, rowFactory)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(width, height)

    local scrollFrame = CreateFrame(
        "ScrollFrame",
        self:GetWidgetName("ScrollFrame"),
        container,
        "UIPanelScrollFrameTemplate"
    )
    scrollFrame:SetPoint("TOPLEFT")
    scrollFrame:SetPoint("BOTTOMRIGHT", -27, 0)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(width - 29, 1)
    scrollFrame:SetScrollChild(content)

    container.scrollFrame = scrollFrame
    container.content = content
    container.rows = {}
    container.data = {}

    function container:SetData(data)
        self.data = data or {}

        for index, entry in ipairs(self.data) do
            local row = self.rows[index]
            if not row then
                row = rowFactory(self.content, index)
                row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -((index - 1) * rowHeight))
                row:SetPoint("TOPRIGHT", self.content, "TOPRIGHT", 0, -((index - 1) * rowHeight))
                row:SetHeight(rowHeight)
                self.rows[index] = row
            end

            row:SetData(entry, index)
            row:Show()
        end

        for index = #self.data + 1, #self.rows do
            self.rows[index]:Hide()
        end

        self.content:SetHeight(math.max(1, #self.data * rowHeight))
        self.scrollFrame:SetVerticalScroll(0)
    end

    return container
end

function UI:ColorText(fontString, color)
    fontString:SetTextColor(color[1], color[2], color[3])
end
