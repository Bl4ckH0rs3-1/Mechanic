-- UI/InspectWatch.lua
-- !Mechanic - Inspect Tab: Watch List Component (Phase 8)

local ADDON_NAME, ns = ...
local Mechanic = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true)
local InspectModule = Mechanic.Inspect

function InspectModule:InitializeWatch(parent)
	local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 8, -8)
	title:SetText(L["Watch List"])

	local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 4, -30)
	scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)
	self.watchScroll = scrollFrame

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetWidth(parent:GetWidth() - 28)
	scrollFrame:SetScrollChild(content)
	self.watchContent = content

	self.watchNodes = {}
	for i = 1, 20 do
		self:GetOrCreateWatchNode(i)
	end

	-- Live Update Timer
	self.watchTicker = C_Timer.NewTicker(0.5, function()
		if parent:IsVisible() then
			self:RefreshWatchList()
		end
	end)
end

function InspectModule:RefreshWatchList()
	if not self.watchContent then
		return
	end

	local MechanicLib = LibStub("MechanicLib-1.0", true)
	if not MechanicLib then
		return
	end

	local watchList = MechanicLib:GetWatchList()
	local sortedKeys = {}
	for key in pairs(watchList) do
		table.insert(sortedKeys, key)
	end
	table.sort(sortedKeys)

	for _, node in ipairs(self.watchNodes) do
		node:Hide()
	end

	local yOffset = 0
	for i, key in ipairs(sortedKeys) do
		local data = watchList[key]
		local node = self:GetOrCreateWatchNode(i)
		node:SetPoint("TOPLEFT", self.watchContent, "TOPLEFT", 0, -yOffset)
		node:SetPoint("RIGHT", self.watchContent, "RIGHT", 0, 0)

		node.label:SetText(data.label)
		node.label:SetPoint("TOPLEFT", 4, -4)

		-- Show source (Addon or Manual)
		if not node.source then
			node.source = node:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			node.source:SetTextColor(0.5, 0.5, 0.5)
			node.source:SetJustifyH("LEFT")
		end
		node.source:SetPoint("BOTTOMLEFT", 4, 4)
		node.source:SetText(data.source or "Manual")

		-- Add unwatch button for manual watches
		if not node.removeBtn then
			node.removeBtn = CreateFrame("Button", nil, node)
			node.removeBtn:SetSize(18, 18)
			node.removeBtn:SetPoint("TOPRIGHT", -4, -4)
			
			local tex = node.removeBtn:CreateTexture(nil, "OVERLAY")
			tex:SetAllPoints()
			-- Use a high-visibility delete icon
			tex:SetAtlas("sharedxml-inv-delete")
			node.removeBtn.tex = tex

			-- Visual feedback for the button
			node.removeBtn:SetScript("OnEnter", function(s) s.tex:SetVertexColor(1, 0.2, 0.2) end)
			node.removeBtn:SetScript("OnLeave", function(s) s.tex:SetVertexColor(1, 1, 1) end)
		end

		if data.source == "Manual" then
			node.removeBtn:Show()
			node.removeBtn:SetFrameLevel(node:GetFrameLevel() + 5)
			node.removeBtn:SetScript("OnClick", function()
				MechanicLib:RemoveFromWatchList(data.target)
			end)
		else
			node.removeBtn:Hide()
		end

		local frame = type(data.target) == "string" and ns.FrameResolver:ResolvePath(data.target) or data.target
		local value = "???"

		-- Helper for consistent value conversion
		local function safeToString(val)
			if val == nil then return "nil" end
			if issecretvalue and issecretvalue(val) then return "[secret]" end
			local ok, str = pcall(tostring, val)
			if ok then
				-- Handle numeric formatting for common properties
				if type(val) == "number" then
					return string.format("%.1f", val)
				end
				-- Clean up function addresses
				if type(val) == "function" then
					local addr = str:match(":(%s*0x%x+)") or str:match(":%s*(%x+)") or str:match("(%x+)") or "ptr"
					addr = addr:gsub("%s", ""):gsub("^0x", "")
					if #addr > 8 then addr = addr:sub(-8) end
					return "[" .. addr .. "]"
				end
				return str
			end
			return "[error]"
		end

		if frame then
			local property = data.property
			if property == "Visibility" then
				value = frame:IsVisible() and "Visible" or "Hidden"
			elseif property == "Text" and frame.GetText then
				value = safeToString(frame:GetText())
			elseif property == "Value" and frame.GetValue then
				value = safeToString(frame:GetValue())
			elseif property == "Width" and frame.GetWidth then
				value = safeToString(frame:GetWidth())
			elseif property == "Height" and frame.GetHeight then
				value = safeToString(frame:GetHeight())
			else
				-- Auto-detection fallback
				if frame.GetValue then
					value = safeToString(frame:GetValue())
				elseif frame.GetText then
					value = safeToString(frame:GetText())
				elseif frame.IsVisible then
					value = frame:IsVisible() and "Visible" or "Hidden"
				end
			end
		end

		node.value:SetText(value)
		node.value:SetPoint("BOTTOMRIGHT", -4, 4)
		-- Ensure value doesn't overlap with label
		node.value:SetWidth(node:GetWidth() - 80) -- Leave room for source
		node.value:SetWordWrap(false)

		node.label:SetWidth(node:GetWidth() - 24) -- Leave room for X
		node.label:SetWordWrap(false)
		node.frame = frame
		node.path = type(data.target) == "string" and data.target or nil

		node:Show()
		yOffset = yOffset + 34
	end

	self.watchContent:SetHeight(yOffset)
end

function InspectModule:GetOrCreateWatchNode(index)
	if self.watchNodes[index] then
		return self.watchNodes[index]
	end

	local node = CreateFrame("Button", nil, self.watchContent)
	node:SetHeight(32)

	local bg = node:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(1, 1, 1, 0.05)
	node.bg = bg

	local label = node:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", 4, -4)
	label:SetPoint("TOPRIGHT", -4, -4)
	label:SetJustifyH("LEFT")
	node.label = label

	local value = node:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	value:SetPoint("BOTTOMLEFT", 4, 4)
	value:SetPoint("BOTTOMRIGHT", -4, 4)
	value:SetJustifyH("RIGHT")
	node.value = value

	node:SetScript("OnClick", function(s)
		InspectModule:SetSelectedFrame(s.frame, s.path)
	end)

	self.watchNodes[index] = node
	return node
end
