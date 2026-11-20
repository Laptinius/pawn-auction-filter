local _, addon = ...

local titleText = "Min. upgrade"

function addon.GetMinimumPercent()
    return PawnAuctionFilterMinimumPercent or 0
end

local function createPanel(button, onMinimumChanged)
    local panel = CreateFrame("Frame", nil, button, "BackdropTemplate")
    panel:Hide()
    panel:SetSize(164, 65)
    panel:SetPoint("TOP", button, "BOTTOM", 0, -15)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -10)
    title:SetText(titleText)
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -3, -3)
    close:SetScript("OnClick", function() panel:Hide() end)

    local input = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    input:SetSize(54, 22)
    input:SetPoint("BOTTOMLEFT", 17, 9)
    input:SetAutoFocus(false)
    local unit = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    unit:SetText("%")
    unit:SetPoint("LEFT", input, "RIGHT", 5, 0)
    local ok = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    ok:SetSize(45, 22)
    ok:SetPoint("BOTTOMRIGHT", -11, 9)
    ok:SetText("OK")

    local value
    input:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        value = text:match("^%d+$") and tonumber(text)
        ok:SetEnabled(value ~= nil and value < math.huge)
    end)
    local function apply()
        if not ok:IsEnabled() then return end
        if value ~= addon.GetMinimumPercent() then
            PawnAuctionFilterMinimumPercent = value
            onMinimumChanged(value)
        end
        panel:Hide()
    end
    ok:SetScript("OnClick", apply)
    input:SetScript("OnEnterPressed", apply)
    input:SetScript("OnEscapePressed", function() panel:Hide() end)
    panel:SetScript("OnShow", function(self)
        input:SetText(string.format("%.0f", addon.GetMinimumPercent()))
        input:SetFocus()
        input:HighlightText()
        self:RegisterEvent("GLOBAL_MOUSE_DOWN")
    end)
    panel:SetScript("OnEvent", function(self)
        if not self:IsMouseOver() and not button:IsMouseOver() then self:Hide() end
    end)
    panel:SetScript("OnHide", function(self)
        self:UnregisterEvent("GLOBAL_MOUSE_DOWN")
        input:ClearFocus()
    end)
    return panel
end

function addon.ConfigureFilterButton(button, onToggle, onMinimumChanged)
    local panel
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" then
            if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
            if not panel then panel = createPanel(self, onMinimumChanged) end
            panel:SetShown(not panel:IsShown())
        else
            if panel then panel:Hide() end
            onToggle()
        end
    end)
    button:HookScript("OnEnter", function(self)
        if panel and panel:IsShown() then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(string.format("%s: %.0f%%", titleText, addon.GetMinimumPercent()))
        GameTooltip:AddLine("Right-click to edit.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:HookScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    button:HookScript("OnHide", function()
        if panel then panel:Hide() end
    end)
end
