--------------------------------------------------------------------------------
-- FenUI v2 - Panel Widget
-- 
-- Main window/panel creation with:
-- - Config object API (simple)
-- - Builder pattern API (fluent)
-- - Lifecycle hooks (onCreate, onShow, onHide, onThemeChange)
-- - Slot system for content injection
-- - Background support (via Layout component)
-- - Shadow support (via Layout component)
--
-- NOTE: Panel internally uses the Layout component as its base frame.
--------------------------------------------------------------------------------

local FenUI = FenUI

--------------------------------------------------------------------------------
-- Panel Mixin
--------------------------------------------------------------------------------

local PanelMixin = {}

--- Initialize the panel with configuration
function PanelMixin:Init(config)
    self.config = config or {}
    self.slots = {}
    self.hooks = {
        onCreate = config.onCreate,
        onShow = config.onShow,
        onHide = config.onHide,
        onThemeChange = config.onThemeChange,
    }
    
    -- Mark as supporting layouts for theme system
    self.fenUISupportsLayout = true
    
    -- Size is handled by Layout component or factory, but apply if needed
    if not self.config.usesLayout then
        self:SetSize(config.width or 400, config.height or 300)
    end
    
    -- Create SafeZone frame for systematic anchoring
    -- This frame is inset to clear the thick Blizzard metal borders
    self:CreateSafeZone()

    -- Default padding (from SafeZone edges to content)
    self.padding = { left = 0, right = 0, top = 0, bottom = 0 }
    if config.padding then
        self:SetPadding(config.padding)
    end
    
    if config.title then
        self:SetTitle(config.title)
    end
    
    if config.movable then
        self:MakeMovable()
    end
    
    if config.closable ~= false then
        self:CreateCloseButton()
    end
    
    -- Apply initial slots
    if config.slots then
        for slotName, frame in pairs(config.slots) do
            self:SetSlot(slotName, frame)
        end
    end
    
    -- Register for theme updates if requested
    if config.registerForThemeChanges ~= false then
        self:RegisterForThemeChanges()
    end
    
    -- Apply theme
    local themeName = config.theme or FenUI:GetGlobalTheme()
    FenUI:ApplyTheme(self, themeName)
    
    -- Fire onCreate hook
    if self.hooks.onCreate then
        self.hooks.onCreate(self)
    end
end

--------------------------------------------------------------------------------
-- Title
--------------------------------------------------------------------------------

-- Header bar height for Panel border style (approximate)
local HEADER_HEIGHT = 24

function PanelMixin:SetTitle(text)
    if not self.titleText then
        self.titleText = self:CreateFontString(nil, "OVERLAY")
        self.titleText:SetFontObject(FenUI:GetFont("fontTitle"))
    end
    
    self.titleText:SetText(text)
    local r, g, b = FenUI:GetColor("textHeading")
    self.titleText:SetTextColor(r, g, b)
    
    -- NOTE: Title Positioning (WoW Coordinate System)
    -- X: Positive = Right, Negative = Left
    -- Y: Positive = Up, Negative = Down
    self.titleText:ClearAllPoints()
    self.titleText:SetPoint("TOP", self, "TOP", 0, -6) -- 0 = Centered, -12 = 12px down from top
end

function PanelMixin:GetTitle()
    return self.titleText and self.titleText:GetText() or ""
end

--------------------------------------------------------------------------------
-- Movable
--------------------------------------------------------------------------------

function PanelMixin:MakeMovable()
    self:SetMovable(true)
    self:EnableMouse(true)
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", self.StartMoving)
    self:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        if frame.config.onMoved then
            frame.config.onMoved(frame)
        end
    end)
    self:SetClampedToScreen(true)
end

--------------------------------------------------------------------------------
-- Safe Zone (Systematic Anchoring)
--------------------------------------------------------------------------------

function PanelMixin:CreateSafeZone()
    if self.safeZone then return end
    
    -- The SafeZone is a logical frame that represents the "safe" usable area
    -- clear of borders and title bars.
    self.safeZone = CreateFrame("Frame", nil, self)
    
    -- Dynamic insets based on border pack and title presence
    local borderOffset = self.contentInset or 4 -- Fallback if not using custom border yet
    
    local left = borderOffset
    local right = borderOffset
    local top = borderOffset
    local bottom = borderOffset
    
    -- If we have a title bar, the safe zone top should clear it
    if self.config.title then
        top = top + 24 -- Space for title text
    end
    
    self.safeZone:SetPoint("TOPLEFT", self, "TOPLEFT", left, -top)
    self.safeZone:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -right, bottom)
end

function PanelMixin:GetSafeZone()
    if not self.safeZone then
        self:CreateSafeZone()
    end
    return self.safeZone
end

--------------------------------------------------------------------------------
-- Close Button
--------------------------------------------------------------------------------

function PanelMixin:CreateCloseButton()
    if self.closeButton then return end
    
    -- Create custom close button using FenUI components
    -- This avoids the "UIPanelCloseButton" template which has forced textures
    self.closeButton = FenUI:CreateImageButton(self, {
        texture = [[Interface\AddOns\FenUI\Assets\icon-close]], -- We'll need this asset
        size = 16,
        tooltip = "Close",
        onClick = function()
            self:Hide()
        end,
    })
    
    self.closeButton:ClearAllPoints()
    self.closeButton:SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, -8)
end

--------------------------------------------------------------------------------
-- Slots
--------------------------------------------------------------------------------

--[[
Available slots:
- headerLeft: Left side of header (before title)
- headerRight: Right side of header (before close button)
- content: Main content area
- footerLeft: Left side of footer
- footerRight: Right side of footer
- footer: Entire footer area
]]

function PanelMixin:SetSlot(slotName, frame)
    if not frame then return end
    
    -- Store the slot
    self.slots[slotName] = frame
    
    -- Parent and position the frame
    frame:SetParent(self)
    
    -- NOTE: Systematic Slot Positioning via SafeZone
    -- We anchor slots to the SafeZone frame rather than the main frame.
    -- This ensures they are automatically clear of the Blizzard metal border textures.
    local safeZone = self.safeZone
    local headerH = FenUI:GetLayout("headerHeight")
    local footerH = FenUI:GetLayout("footerHeight")
    
    if slotName == "headerLeft" then
        frame:SetPoint("TOPLEFT", safeZone, "TOPLEFT", 0, 0)
    elseif slotName == "headerRight" then
        local offset = self.closeButton and -28 or 0
        frame:SetPoint("TOPRIGHT", safeZone, "TOPRIGHT", offset, 0)
    elseif slotName == "content" then
        frame:SetPoint("TOPLEFT", safeZone, "TOPLEFT", 0, -headerH)
        frame:SetPoint("BOTTOMRIGHT", safeZone, "BOTTOMRIGHT", 0, footerH)
    elseif slotName == "footerLeft" then
        frame:SetPoint("BOTTOMLEFT", safeZone, "BOTTOMLEFT", 0, 0)
    elseif slotName == "footerRight" then
        frame:SetPoint("BOTTOMRIGHT", safeZone, "BOTTOMRIGHT", 0, 0)
    elseif slotName == "footer" then
        frame:SetPoint("BOTTOMLEFT", safeZone, "BOTTOMLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", safeZone, "BOTTOMRIGHT", 0, 0)
    end
    
    frame:Show()
end

function PanelMixin:GetSlot(slotName)
    return self.slots[slotName]
end

function PanelMixin:ClearSlot(slotName)
    local frame = self.slots[slotName]
    if frame then
        frame:Hide()
        frame:ClearAllPoints()
        self.slots[slotName] = nil
    end
end

--------------------------------------------------------------------------------
-- Content Frame (convenience)
--------------------------------------------------------------------------------

function PanelMixin:GetContentFrame()
    if not self.contentFrame then
        self.contentFrame = CreateFrame("Frame", nil, self)
        self:UpdateContentAnchors()
    end
    return self.contentFrame
end

function PanelMixin:SetPadding(padding)
    if type(padding) == "number" then
        self.padding = { left = padding, right = padding, top = padding, bottom = padding }
    elseif type(padding) == "table" then
        self.padding.left = padding.left or self.padding.left
        self.padding.right = padding.right or self.padding.right
        self.padding.top = padding.top or self.padding.top
        self.padding.bottom = padding.bottom or self.padding.bottom
    end
    
    if self.contentFrame then
        self:UpdateContentAnchors()
    end
end

function PanelMixin:UpdateContentAnchors()
    if not self.contentFrame then return end
    
    local safeZone = self.safeZone
    local headerH = FenUI:GetLayout("headerHeight")
    local footerH = FenUI:GetLayout("footerHeight")
    
    local p = self.padding
    self.contentFrame:ClearAllPoints()
    self.contentFrame:SetPoint("TOPLEFT", safeZone, "TOPLEFT", p.left, -(headerH + p.top))
    self.contentFrame:SetPoint("BOTTOMRIGHT", safeZone, "BOTTOMRIGHT", -p.right, footerH + p.bottom)
end

--------------------------------------------------------------------------------
-- Theme Integration
--------------------------------------------------------------------------------

function PanelMixin:RegisterForThemeChanges()
    FenUI:RegisterFrame(self, "panel")
end

function PanelMixin:UnregisterFromThemeChanges()
    FenUI:UnregisterFrame(self)
end

function PanelMixin:OnFenUIThemeChanged(themeName, theme)
    -- Update title color
    if self.titleText then
        local r, g, b = FenUI:GetColor("textHeading")
        self.titleText:SetTextColor(r, g, b)
    end
    
    -- Fire hook
    if self.hooks.onThemeChange then
        self.hooks.onThemeChange(self, themeName, theme)
    end
end

function PanelMixin:SetTheme(themeName)
    FenUI:ApplyTheme(self, themeName)
end

--------------------------------------------------------------------------------
-- Lifecycle Hooks
--------------------------------------------------------------------------------

function PanelMixin:SetOnShow(callback)
    self.hooks.onShow = callback
end

function PanelMixin:SetOnHide(callback)
    self.hooks.onHide = callback
end

function PanelMixin:SetOnThemeChange(callback)
    self.hooks.onThemeChange = callback
end

--------------------------------------------------------------------------------
-- Panel Factory (Config API)
--------------------------------------------------------------------------------

--- Create a panel with configuration object
---@param parent Frame Parent frame
---@param config table|string Configuration table or just a title string
---@return Frame panel
function FenUI:CreatePanel(parent, config)
    -- Allow simple string as title
    if type(config) == "string" then
        config = { title = config }
    end
    config = config or {}
    
    -- Determine layout/border
    local theme = FenUI:GetTheme(config.theme)
    local borderKey = config.layout or (theme and theme.layout) or "ModernDark"
    local textureKit = config.textureKit or (theme and theme.textureKit)
    
    -- Create base panel using Layout component
    local panel
    if FenUI.CreateLayout then
        -- Use Layout as base (preferred)
        local bgConfig = (config.background == nil) and "surfacePanel" or config.background
        panel = FenUI:CreateLayout(parent or UIParent, {
            name = config.name,
            width = config.width or 400,
            height = config.height or 300,
            border = borderKey,
            background = bgConfig,
            shadow = config.shadow,
            padding = config.padding,
            textureKit = textureKit,
        })
    else
        -- Fallback to direct frame creation
        panel = CreateFrame("Frame", config.name, parent or UIParent)
        panel:SetSize(config.width or 400, config.height or 300)
        FenUI:ApplyBorder(panel, borderKey)
    end
    
    -- Apply Panel mixin (title, close button, slots, hooks)
    FenUI.Mixin(panel, PanelMixin)
    
    -- Initialize with config
    panel:Init(config)
    
    -- Set up show/hide hooks
    panel:HookScript("OnShow", function(self)
        if self.hooks.onShow then
            self.hooks.onShow(self)
        end
    end)
    
    panel:HookScript("OnHide", function(self)
        if self.hooks.onHide then
            self.hooks.onHide(self)
        end
    end)
    
    return panel
end

--------------------------------------------------------------------------------
-- Panel Builder (Fluent API)
--------------------------------------------------------------------------------

local PanelBuilder = {}
PanelBuilder.__index = PanelBuilder

function PanelBuilder:new(parent)
    local builder = setmetatable({}, PanelBuilder)
    builder._parent = parent or UIParent
    builder._config = {}
    builder._slots = {}
    return builder
end

function PanelBuilder:name(name)
    self._config.name = name
    return self
end

function PanelBuilder:title(title)
    self._config.title = title
    return self
end

function PanelBuilder:size(width, height)
    self._config.width = width
    self._config.height = height
    return self
end

function PanelBuilder:width(width)
    self._config.width = width
    return self
end

function PanelBuilder:height(height)
    self._config.height = height
    return self
end

function PanelBuilder:theme(themeName)
    self._config.theme = themeName
    return self
end

function PanelBuilder:layout(layoutName)
    self._config.layout = layoutName
    return self
end

function PanelBuilder:background(bgConfig)
    self._config.background = bgConfig
    return self
end

function PanelBuilder:shadow(shadowConfig)
    self._config.shadow = shadowConfig
    return self
end

function PanelBuilder:padding(paddingConfig)
    self._config.padding = paddingConfig
    return self
end

function PanelBuilder:movable(enabled)
    self._config.movable = enabled ~= false
    return self
end

function PanelBuilder:closable(enabled)
    self._config.closable = enabled ~= false
    return self
end

function PanelBuilder:slot(slotName, frame)
    self._slots[slotName] = frame
    return self
end

function PanelBuilder:onCreate(callback)
    self._config.onCreate = callback
    return self
end

function PanelBuilder:onShow(callback)
    self._config.onShow = callback
    return self
end

function PanelBuilder:onHide(callback)
    self._config.onHide = callback
    return self
end

function PanelBuilder:onThemeChange(callback)
    self._config.onThemeChange = callback
    return self
end

function PanelBuilder:onMoved(callback)
    self._config.onMoved = callback
    return self
end

function PanelBuilder:registerForThemeChanges(enabled)
    self._config.registerForThemeChanges = enabled ~= false
    return self
end

function PanelBuilder:build()
    self._config.slots = self._slots
    return FenUI:CreatePanel(self._parent, self._config)
end

--- Start building a panel with fluent API
---@param parent Frame|nil Parent frame
---@return PanelBuilder builder
function FenUI.Panel(parent)
    return PanelBuilder:new(parent)
end

--------------------------------------------------------------------------------
-- Export Mixin for advanced use
--------------------------------------------------------------------------------

FenUI.PanelMixin = PanelMixin
