-- UI/InspectTree.lua
-- !Mechanic - Inspect Tab: Frame Tree Component (Phase 8)

local ADDON_NAME, ns = ...
local Mechanic = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local InspectModule = Mechanic.Inspect

-- Helper: Get a descriptive name for a frame
-- Priority: Global Name > Leaf from FrameResolver path > <ObjectType>
local function GetDescriptiveName(frame)
	if not frame then
		return "<nil>"
	end

	-- 1. Check for global name first
	local globalName = frame.GetName and frame:GetName()
	if globalName and type(globalName) == "string" and globalName ~= "" then
		return globalName
	end

	-- 2. Try FrameResolver to get a path, then extract the leaf
	if ns.FrameResolver then
		local path = ns.FrameResolver:GetFramePath(frame)
		if path and type(path) == "string" and path ~= "<anonymous>" then
			-- Extract the leaf (last segment after last dot)
			local leaf = path:match("%.([^%.]+)$") or path
			if leaf and leaf ~= "?" then
				return leaf
			end
		end
	end

	-- 3. Fallback to object type
	local objType = frame.GetObjectType and frame:GetObjectType()
	if objType then
		return "<" .. objType .. ">"
	end

	return "<table>"
end

function InspectModule:InitializeTree(parent)
	local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 4, -4)
	scrollFrame:SetPoint("BOTTOMRIGHT", -24, 4)
	self.treeScroll = scrollFrame

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetWidth(parent:GetWidth() - 28)
	scrollFrame:SetScrollChild(content)
	self.treeContent = content

	self.treeNodes = {}
	self.expandedNodes = {} -- frame -> true
end

function InspectModule:UpdateTree(selectedFrame)
	-- For now, a simple list of parent -> self -> children
	-- A full tree would be more complex, but let's start with a "Contextual Tree"

	for _, node in ipairs(self.treeNodes) do
		node:Hide()
	end

	if not selectedFrame or type(selectedFrame) ~= "table" then
		return
	end

	local yOffset = 0
	local nodes = {}

	-- 1. Ancestors (Frames only)
	local ancestors = {}
	if selectedFrame.GetParent then
		local current = selectedFrame:GetParent()
		while current and current ~= UIParent do
			table.insert(ancestors, 1, current)
			current = current.GetParent and current:GetParent() or nil
		end
	end

	for _, frame in ipairs(ancestors) do
		table.insert(nodes, { frame = frame, indent = #nodes * 10, type = "ancestor" })
	end

	-- 2. Selected Frame
	local selectedIdx = #nodes + 1
	table.insert(nodes, { frame = selectedFrame, indent = #ancestors * 10, type = "selected" })

	-- 3. Children (Frames only)
	if selectedFrame.GetChildren then
		local children = { selectedFrame:GetChildren() }
		for _, child in ipairs(children) do
			table.insert(nodes, { frame = child, indent = (#ancestors + 1) * 10, type = "child" })
		end
	end

	-- Render nodes
	for i, nodeData in ipairs(nodes) do
		local node = self:GetOrCreateTreeNode(i)
		node:SetPoint("TOPLEFT", self.treeContent, "TOPLEFT", nodeData.indent, -yOffset)
		node:SetPoint("RIGHT", self.treeContent, "RIGHT", 0, 0)

		local name = GetDescriptiveName(nodeData.frame)
		node.text:SetText(name)

		-- Store the full path for tooltip
		local fullPath = ns.FrameResolver and ns.FrameResolver:GetFramePath(nodeData.frame) or name
		node.fullPath = fullPath

		if nodeData.type == "selected" then
			node.text:SetTextColor(1, 0.8, 0)
			node.bg:Show()
		elseif nodeData.type == "ancestor" then
			node.text:SetTextColor(0.6, 0.6, 0.6)
			node.bg:Hide()
		else
			node.text:SetTextColor(1, 1, 1)
			node.bg:Hide()
		end

		node.frame = nodeData.frame

		-- Update visibility toggle state
		if node.visBtn and nodeData.frame.IsVisible then
			local isVisible = nodeData.frame:IsVisible()
			node.visBtn.tex:SetAlpha(isVisible and 1 or 0.3)
		end

		-- Update pin state
		if node.pinBtn then
			local isPinned = InspectModule.pinnedFrame == nodeData.frame
			node.pinBtn.tex:SetDesaturated(not isPinned)
			node.pinBtn.tex:SetAlpha(isPinned and 1 or 0.4)
		end

		node:Show()
		yOffset = yOffset + 20
	end

	self.treeContent:SetHeight(yOffset)
end

function InspectModule:GetOrCreateTreeNode(index)
	if self.treeNodes[index] then
		return self.treeNodes[index]
	end

	local node = CreateFrame("Button", nil, self.treeContent)
	node:SetHeight(20)

	local bg = node:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(1, 1, 1, 0.1)
	bg:Hide()
	node.bg = bg

	-- Pin button (assign to _G.f for console access)
	local pinBtn = CreateFrame("Button", nil, node)
	pinBtn:SetSize(16, 16)
	pinBtn:SetPoint("RIGHT", -2, 0)
	local pinTex = pinBtn:CreateTexture(nil, "ARTWORK")
	pinTex:SetAllPoints()
	pinTex:SetAtlas("friendslist-recentallies-pin-yellow")
	pinBtn.tex = pinTex
	pinBtn:SetScript("OnClick", function(s)
		local targetFrame = s:GetParent().frame
		if targetFrame then
			_G.f = targetFrame
			InspectModule.pinnedFrame = targetFrame
			local name = GetDescriptiveName(targetFrame)
			Mechanic:Print("|cff00ff00Pinned:|r _G.f = " .. name)
			-- Refresh tree to update visual state of all pins
			InspectModule:UpdateTree(InspectModule.selectedFrame)
		end
	end)
	pinBtn:SetScript("OnEnter", function(s)
		GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Assign to _G.f", 1, 1, 1)
		GameTooltip:AddLine("Use /run print(f) in console", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	pinBtn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	node.pinBtn = pinBtn

	-- Visibility toggle button (small checkbox-like)
	local visBtn = CreateFrame("Button", nil, node)
	visBtn:SetSize(16, 16)
	visBtn:SetPoint("RIGHT", pinBtn, "LEFT", -2, 0)
	local visTex = visBtn:CreateTexture(nil, "ARTWORK")
	visTex:SetAllPoints()
	visTex:SetAtlas("socialqueuing-icon-eye")
	visBtn.tex = visTex
	visBtn:SetScript("OnClick", function(s)
		local targetFrame = s:GetParent().frame
		if targetFrame and targetFrame.IsVisible and targetFrame.SetShown then
			local newState = not targetFrame:IsVisible()
			targetFrame:SetShown(newState)
			-- Update icon appearance
			s.tex:SetAlpha(newState and 1 or 0.3)
			-- Refresh tree to update all visibility states
			InspectModule:UpdateTree(InspectModule.selectedFrame)
		end
	end)
	visBtn:SetScript("OnEnter", function(s)
		GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
		GameTooltip:AddLine("Toggle Visibility", 1, 1, 1)
		GameTooltip:Show()
	end)
	visBtn:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	node.visBtn = visBtn

	local text = node:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("LEFT", 4, 0)
	text:SetPoint("RIGHT", visBtn, "LEFT", -2, 0)
	text:SetJustifyH("LEFT")
	node.text = text

	node:SetScript("OnClick", function(s)
		InspectModule:SetSelectedFrame(s.frame)
	end)

	node:SetScript("OnEnter", function(s)
		InspectModule:ShowHighlight(s.frame)
		-- Show tooltip with full path and object type
		if s.fullPath or s.frame then
			GameTooltip:SetOwner(s, "ANCHOR_RIGHT")
			GameTooltip:AddLine(s.fullPath or "<anonymous>", 1, 0.82, 0)
			if s.frame and s.frame.GetObjectType then
				GameTooltip:AddLine(s.frame:GetObjectType(), 0.7, 0.7, 0.7)
			end
			if s.frame and s.frame.IsVisible then
				local visible = s.frame:IsVisible()
				GameTooltip:AddLine(visible and "Visible" or "Hidden", visible and 0 or 1, visible and 1 or 0, 0)
			end
			GameTooltip:Show()
		end
	end)

	node:SetScript("OnLeave", function(s)
		if InspectModule.selectedFrame then
			InspectModule:ShowHighlight(InspectModule.selectedFrame)
		else
			InspectModule:HideHighlight()
		end
		GameTooltip:Hide()
	end)

	self.treeNodes[index] = node
	return node
end
