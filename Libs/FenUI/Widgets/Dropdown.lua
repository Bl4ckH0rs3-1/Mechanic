--------------------------------------------------------------------------------
-- FenUI - Dropdown Widget
--
-- A stylized dropdown menu.
--------------------------------------------------------------------------------

local WidgetMixin = {}

function WidgetMixin:Init(config)
    self.config = config or {}
    self.items = config.items or {}

    -- Main Button
    local button = FenUI:CreateButton(self, {
        text = self.config.defaultText or "Select...",
        width = self:GetWidth(),
        height = self:GetHeight(),
    })
    button:SetAllPoints()
    self.button = button

    button:SetScript("OnClick", function()
        self:ToggleMenu()
    end)
end

function WidgetMixin:UpdateMenuList()
    self.menuList = {}
    local U = FenUI.Utils
    
    for _, item in ipairs(self.items) do
        local isTable = type(item) == "table"
        local text = isTable and item.text or item
        local value = isTable and item.value or item
        
        -- Safeguard: If text is still a table (means item.text was nil), fallback to value
        if type(text) == "table" then
            text = tostring(value)
        end

        -- Sanitize text for Blizzard SetText (handles AceLocale 'true')
        text = U and U:SanitizeText(text, tostring(value)) or (text == true and tostring(value) or text)

        table.insert(self.menuList, {
            text = text,
            func = function()
                if not self.config.fixedText then
                    self.button:SetText(text)
                end
                if self.config.onSelect then
                    self.config.onSelect(value)
                end
            end,
            notCheckable = true,
        })
    end
end

function WidgetMixin:ToggleMenu()
    if not self.items or #self.items == 0 then return end
    
    if not self.menuList then
        self:UpdateMenuList()
    end

    -- Use the shared ShowMenu utility (bridged or direct)
    if FenUI.Utils and FenUI.Utils.ShowMenu then
        FenUI.Utils:ShowMenu(self.menuList, self.button)
    else
        -- Fallback to EasyMenu
        if not self.menuFrame then
            self.menuFrame = CreateFrame("Frame", nil, UIParent, "UIDropDownMenuTemplate")
        end
        EasyMenu(self.menuList, self.menuFrame, self.button, 0, 0, "MENU")
    end
end

function WidgetMixin:SetItems(items)
    self.items = items or {}
    self.menuList = nil -- Force update on next toggle
end

function WidgetMixin:SetValue(value)
    local U = FenUI.Utils
    for _, item in ipairs(self.items) do
        local isTable = type(item) == "table"
        local itemValue = isTable and item.value or item
        local itemText = isTable and item.text or item
        
        if itemValue == value then
            -- Safeguard: If itemText is still a table (means item.text was nil), fallback to value
            if type(itemText) == "table" then
                itemText = tostring(itemValue)
            end

            -- Sanitize text for Blizzard SetText (handles AceLocale 'true')
            itemText = U and U:SanitizeText(itemText, tostring(itemValue)) or (itemText == true and tostring(itemValue) or itemText)
            self.button:SetText(itemText)
            return
        end
    end
end

-- Factory function
function FenUI:CreateDropdown(parent, config)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(config.width or 150, config.height or 24)
    
    FenUI.Mixin(frame, WidgetMixin)
    frame:Init(config)
    
    return frame
end
