-- UI/Shared/SplitNavLayout.lua
-- !Mechanic - Reusable Split Navigation Layout Helper (Phase 6)
--
-- Provides a standard left-nav / right-content split layout pattern
-- used by Console, Errors, Tools, and Performance modules.

local ADDON_NAME, ns = ...
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true)
local SplitNavLayout = {}
ns.SplitNavLayout = SplitNavLayout

-- Configuration defaults
local NAV_WIDTH = 200
local NAV_ITEM_HEIGHT = 24
local NAV_PADDING = 4

---@class SplitNavConfig
---@field navWidth number? Width of left nav (default 200)
---@field items table[]? Array of {key, text, icon?} for nav items
---@field onSelect function? Callback(key) when item selected
---@field defaultKey string? Initial selection
---@field storageKey string? Key for persistence in Mechanic.db.profile.activeSubTabs

---Create a split navigation layout
---@param parent Frame Parent frame
---@param config SplitNavConfig
---@return table layout Layout controller object
function SplitNavLayout:Create(parent, config)
	local MechanicObj = _G.Mechanic
	local layout = {
		items = {},
		buttons = {},
		headers = {},
		selectedKey = nil,
		contentFrames = {},
		storageKey = config.storageKey,
		addonProfile = MechanicObj and MechanicObj.db and MechanicObj.db.profile,
		initializing = true, -- Flag to prevent saves during initialization
	}

	-- Load selected key from storage if available
	if layout.storageKey and layout.addonProfile and layout.addonProfile.activeSubTabs then
		layout.selectedKey = layout.addonProfile.activeSubTabs[layout.storageKey]
	end

	-- Fallback to default key
	if not layout.selectedKey then
		layout.selectedKey = config.defaultKey
	end

	local navWidth = config.navWidth or NAV_WIDTH

	-- Left navigation panel (using FenUI Layout for a proper frame/border)
	local navPanel = FenUI:CreateLayout(parent, {
		width = navWidth,
		border = "Inset",
		background = "surfacePanel",
		padding = NAV_PADDING,
	})
	navPanel:SetPoint("TOPLEFT", 0, 0)
	navPanel:SetPoint("BOTTOMLEFT", 0, 0)
	layout.navPanel = navPanel

	-- Scrollable nav content
	local navScroll = CreateFrame("ScrollFrame", nil, navPanel, "UIPanelScrollFrameTemplate")
	navScroll:SetPoint("TOPLEFT", 4, -4)
	navScroll:SetPoint("BOTTOMRIGHT", -26, 4)

	local navContent = CreateFrame("Frame", nil, navScroll)
	navContent:SetSize(navWidth - 35, 1) -- Initial reasonable width
	navScroll:SetScrollChild(navContent)
	layout.navContent = navContent

	-- Keep navContent width synced with navScroll to fill the space
	navScroll:SetScript("OnSizeChanged", function(self, width, height)
		navContent:SetWidth(width)
		layout:RefreshNav()
	end)

	-- Content area (right side)
	local contentArea = CreateFrame("Frame", nil, parent)
	contentArea:SetPoint("TOPLEFT", navPanel, "TOPRIGHT", 4, 0)
	contentArea:SetPoint("BOTTOMRIGHT", 0, 0)
	layout.contentArea = contentArea

	-- Methods
	function layout:SetItems(items)
		self.items = items

		-- We used to validate and clear selectedKey here if it wasn't in the list.
		-- However, this caused issues during initialization where addons hadn't
		-- registered yet, causing restored selections to be lost.
		-- Now we keep the selectedKey; if it's not in the list, no highlight will show,
		-- but it will stay saved so that when the addon registers later, it works.

		self:RefreshNav()
	end

	function layout:RefreshNav()
		-- Hide all existing buttons and headers
		for _, btn in ipairs(self.buttons) do
			btn:Hide()
		end
		for _, header in ipairs(self.headers) do
			header:Hide()
		end

		local yOffset = 0
		local buttonIndex = 1
		local headerIndex = 1

		for i, item in ipairs(self.items) do
			if item.isHeader then
				local header = self:GetOrCreateHeader(headerIndex)
				header:SetPoint("TOPLEFT", self.navContent, "TOPLEFT", 0, -yOffset)
				header:SetPoint("TOPRIGHT", self.navContent, "TOPRIGHT", 0, -yOffset)
				header:SetText(item.text)
				header:Show()

				yOffset = yOffset + header:GetHeight() + 2
				headerIndex = headerIndex + 1
			else
				local btn = self:GetOrCreateButton(buttonIndex)
				btn:SetPoint("TOPLEFT", self.navContent, "TOPLEFT", 0, -yOffset)
				btn:SetPoint("TOPRIGHT", self.navContent, "TOPRIGHT", 0, -yOffset)
				btn:SetHeight(NAV_ITEM_HEIGHT)
				btn.text:SetText(item.text)
				btn.key = item.key

				btn:Enable()
				btn.text:SetTextColor(1, 0.82, 0)

				btn:Show()
				yOffset = yOffset + NAV_ITEM_HEIGHT + 2
				buttonIndex = buttonIndex + 1
			end
		end

		self.navContent:SetHeight(math.max(1, yOffset))

		self:UpdateButtonStates()

		-- Ensure content frame for selected key is shown
		if self.selectedKey and self.contentFrames[self.selectedKey] then
			self.contentFrames[self.selectedKey]:Show()
		end
	end

	function layout:GetOrCreateButton(index)
		if self.buttons[index] then
			return self.buttons[index]
		end

		local btn = CreateFrame("Button", nil, self.navContent)
		btn:SetHeight(NAV_ITEM_HEIGHT)

		-- Background highlight
		local highlight = btn:CreateTexture(nil, "BACKGROUND")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.1)
		highlight:Hide()
		btn.highlight = highlight

		-- Hover highlight
		local hover = btn:CreateTexture(nil, "HIGHLIGHT")
		hover:SetAllPoints()
		hover:SetColorTexture(1, 1, 1, 0.05)

		-- Text
		local text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		text:SetPoint("LEFT", 8, 0)
		text:SetJustifyH("LEFT")
		text:SetText(L["Test Item"]) -- Default text
		btn.text = text

		btn:SetScript("OnClick", function()
			if btn.key then
				self:Select(btn.key)
			end
		end)

		self.buttons[index] = btn
		return btn
	end

	function layout:GetOrCreateHeader(index)
		if self.headers[index] then
			return self.headers[index]
		end

		local header = FenUI:CreateSectionHeader(self.navContent, {
			text = "Header",
			spacing = "md",
		})

		self.headers[index] = header
		return header
	end

	function layout:UpdateButtonStates()
		for _, btn in ipairs(self.buttons) do
			if btn:IsShown() then
				if btn.key == self.selectedKey then
					btn.highlight:Show()
				else
					btn.highlight:Hide()
				end
			end
		end
	end

	function layout:Select(key, force)
		if self.selectedKey == key and not force then
			return
		end

		local oldKey = self.selectedKey
		self.selectedKey = key

		-- Persist if storage key provided (but NOT during initialization)
		if self.storageKey and self.addonProfile and not self.initializing then
			self.addonProfile.activeSubTabs = self.addonProfile.activeSubTabs or {}
			self.addonProfile.activeSubTabs[self.storageKey] = key
		end

		self:UpdateButtonStates()

		-- Hide all content frames
		for _, frame in pairs(self.contentFrames) do
			frame:Hide()
		end

		-- Show selected content frame
		if self.contentFrames[key] then
			self.contentFrames[key]:Show()
		end

		-- Callback (only if NOT initializing)
		if config.onSelect and not self.initializing then
			config.onSelect(key)
		end
	end

	function layout:GetContentFrame(key)
		if not self.contentFrames[key] then
			local frame = CreateFrame("Frame", nil, self.contentArea)
			frame:SetAllPoints()
			self.contentFrames[key] = frame

			-- If this is already the selected key, show it immediately
			if self.selectedKey == key then
				frame:Show()
			else
				frame:Hide()
			end
		end
		return self.contentFrames[key]
	end

	function layout:GetSelectedKey()
		return self.selectedKey
	end

	-- Initial setup
	if config.items then
		layout:SetItems(config.items)
	end
	if not layout.selectedKey and config.defaultKey then
		layout:Select(config.defaultKey)
	end

	-- Clear initialization flag - now saves will work
	layout.initializing = false

	return layout
end

return SplitNavLayout
