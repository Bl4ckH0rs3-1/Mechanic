--------------------------------------------------------------------------------
-- FenUI v2 - MultiLineEditBox Widget
-- 
-- Wrapper around native EditBox with multi-line and scroll support.
-- Ideal for console output and copyable text areas.
--------------------------------------------------------------------------------

local FenUI = FenUI

--------------------------------------------------------------------------------
-- MultiLineEditBox Mixin
--------------------------------------------------------------------------------

local MultiLineEditBoxMixin = {}

function MultiLineEditBoxMixin:Init(config)
    self.config = config or {}
    
    -- Create scroll frame
    self.scrollFrame = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
    self.scrollFrame:SetPoint("TOPLEFT", 4, -4)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", -26, 4)
    
    -- Create edit box
    self.editBox = CreateFrame("EditBox", nil, self.scrollFrame)
    self.editBox:SetMultiLine(true)
    self.editBox:SetMaxLetters(0)
    self.editBox:SetFontObject(FenUI:GetFont("fontMono") or "ChatFontNormal")
    self.editBox:SetWidth(self.scrollFrame:GetWidth())
    self.editBox:SetAutoFocus(false)
    
    self.scrollFrame:SetScrollChild(self.editBox)
    
    -- Configure behavior
    if config.readOnly then
        self:SetReadOnly(true)
    end
    
    if config.label then
        self:SetLabel(config.label)
    end
    
    -- Initial text
    if config.text then
        self:SetText(config.text)
    end
    
    -- Handle size changes
    self:SetScript("OnSizeChanged", function(_, width)
        self.editBox:SetWidth(width - 30)
    end)
    
    -- Click to focus - ensure the editBox captures keyboard input
    local function FocusEditBox()
        self.editBox:SetFocus()
    end
    self:SetScript("OnMouseDown", FocusEditBox)
    self.scrollFrame:SetScript("OnMouseDown", FocusEditBox)
    
    -- Auto-scroll to bottom on text change (can be disabled)
    self.autoScroll = config.autoScroll ~= false
    self.editBox:SetScript("OnTextChanged", function(eb)
        if self.autoScroll then
            self.scrollFrame:SetVerticalScroll(self.scrollFrame:GetVerticalScrollRange())
        end
    end)
    
    -- Tab behavior
    self.editBox:SetScript("OnTabPressed", function(eb)
        eb:Insert("    ")
    end)
    
    -- Escape to clear focus
    self.editBox:SetScript("OnEscapePressed", function(eb)
        eb:ClearFocus()
    end)
end

function MultiLineEditBoxMixin:SetText(text)
    self.editBox:SetText(text or "")
end

function MultiLineEditBoxMixin:GetText()
    return self.editBox:GetText()
end

function MultiLineEditBoxMixin:Clear()
    self.editBox:SetText("")
end

function MultiLineEditBoxMixin:SelectAll()
    self.editBox:SetFocus()
    self.editBox:HighlightText()
end

function MultiLineEditBoxMixin:SetAutoScroll(enabled)
    self.autoScroll = enabled
end

function MultiLineEditBoxMixin:ScrollToTop()
    self.scrollFrame:SetVerticalScroll(0)
end

function MultiLineEditBoxMixin:ScrollToBottom()
    self.scrollFrame:SetVerticalScroll(self.scrollFrame:GetVerticalScrollRange())
end

function MultiLineEditBoxMixin:SetReadOnly(readOnly)
    -- Do NOT use SetEnabled(false) as it prevents focus and copy.
    -- Instead, we block character input but keep the widget enabled for selection.
    self.isReadOnly = readOnly
    if readOnly then
        self.editBox:SetScript("OnChar", function(eb)
            -- Block all character input; prevent fallthrough to game
            eb:SetPropagateKeyboardInput(false)
        end)
        self.editBox:SetScript("OnKeyDown", function(eb, key)
            -- Default: do not propagate to game bindings
            eb:SetPropagateKeyboardInput(false)

            -- Allow Ctrl+C (copy)
            if key == "C" and IsControlKeyDown() then
                eb:SetPropagateKeyboardInput(true)
                return
            end

            -- Allow Ctrl+A (select all)
            if key == "A" and IsControlKeyDown() then
                self:SelectAll()
                return
            end

            -- Allow navigation keys
            if
                key == "UP"
                or key == "DOWN"
                or key == "LEFT"
                or key == "RIGHT"
                or key == "PAGEUP"
                or key == "PAGEDOWN"
                or key == "HOME"
                or key == "END"
            then
                eb:SetPropagateKeyboardInput(true)
                return
            end

            -- Allow Escape to clear focus
            if key == "ESCAPE" then
                eb:ClearFocus()
                return
            end

            -- Block destructive keys silently
        end)
    else
        self.editBox:SetScript("OnChar", nil)
        self.editBox:SetScript("OnKeyDown", nil)
    end
end

function MultiLineEditBoxMixin:SetLabel(text)
    if not self.label then
        self.label = self:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        self.label:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, 2)
    end
    self.label:SetText(text)
end

--------------------------------------------------------------------------------
-- Factory
--------------------------------------------------------------------------------

--- Create a multi-line edit box with scroll support
---@param parent Frame Parent frame
---@param config table Configuration
---@return Frame editBox
function FenUI:CreateMultiLineEditBox(parent, config)
    config = config or {}
    
    -- We use a Layout as the container for border/background
    local container = self:CreateLayout(parent, {
        name = config.name,
        border = config.border or "Inset",
        background = config.background or "surfaceInset",
        width = config.width or 400,
        height = config.height or (config.numLines and (config.numLines * 14 + 10)) or 200,
    })
    
    FenUI.Mixin(container, MultiLineEditBoxMixin)
    container:Init(config)
    
    return container
end

FenUI.MultiLineEditBoxMixin = MultiLineEditBoxMixin

