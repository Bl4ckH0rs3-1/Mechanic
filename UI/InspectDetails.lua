-- UI/InspectDetails.lua
-- !Mechanic - Inspect Tab: Details Panel Component (Phase 8)

local ADDON_NAME, ns = ...
local Mechanic = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME, true)
local InspectModule = Mechanic.Inspect

function InspectModule:InitializeDetails(parent)
	local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 8, -8)
	scrollFrame:SetPoint("BOTTOMRIGHT", -24, 8)
	self.detailsScroll = scrollFrame

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetWidth(parent:GetWidth() - 32)
	scrollFrame:SetScrollChild(content)
	self.detailsContent = content

	self.detailSections = {}
end

function InspectModule:UpdateDetails(frame)
	if not self.detailsContent then
		return
	end

	-- Clear old sections
	local L = LibStub("AceLocale-3.0"):GetLocale("!Mechanic")
	for _, section in ipairs(self.detailSections) do
		section:Hide()
	end

	if not frame or type(frame) ~= "table" then
		return
	end

	local yOffset = 0

	-- 1. Header Section
	yOffset = self:AddDetailHeader(frame, yOffset)

	-- 2. Interactivity Section (Frames only)
	if frame.IsMouseEnabled then
		yOffset = self:AddDetailInteractivity(frame, yOffset)
	end

	-- 3. Geometry Section (Frames only)
	if frame.GetObjectType and frame.GetSize then
		yOffset = self:AddDetailGeometry(frame, yOffset)
	end

	-- 4. Anchors Section (Frames only)
	if frame.GetNumPoints then
		yOffset = self:AddDetailAnchors(frame, yOffset)
	end

	-- 5. Regions Section (Frames only)
	if frame.GetRegions then
		yOffset = self:AddDetailRegions(frame, yOffset)
	end

	-- 6. Properties Section
	yOffset = self:AddDetailProperties(frame, yOffset)

	-- 7. Attributes Section (Frames only)
	if frame.GetAttribute then
		yOffset = self:AddDetailAttributes(frame, yOffset)
	end

	-- 8. Scripts Section (Frames only)
	if frame.HasScript then
		yOffset = self:AddDetailScripts(frame, yOffset)
	end

	self.detailsContent:SetHeight(-yOffset)
end

function InspectModule:AddDetailHeader(frame, yOffset)
	local section = self:GetOrCreateDetailSection("Header", yOffset)

	-- Helper for consistent name resolution
	local function getDescriptiveName(target)
		if not target then return nil end
		local name = target.GetName and target:GetName()
		if (not name or name == "") and target.GetObjectType then
			local path = ns.FrameResolver:GetFramePath(target)
			if path and type(path) == "string" then
				name = path:match("([^%.]+)$")
			end
		end
		return name or (target.GetObjectType and target:GetObjectType()) or "<anonymous>"
	end

	local globalName = frame.GetName and frame:GetName()
	local displayName = getDescriptiveName(frame)
	section.title:SetText(displayName)

	local info
	if frame.GetObjectType then
		local parent = frame:GetParent()
		local parentName = parent and getDescriptiveName(parent) or "None"

		info = string.format(
			"Type: %s | Level: %d | Strata: %s\nParent: %s\nGlobal: %s",
			frame:GetObjectType(),
			frame.GetFrameLevel and frame:GetFrameLevel() or 0,
			frame.GetFrameStrata and frame:GetFrameStrata() or "N/A",
			parentName,
			(globalName and globalName ~= "") and globalName or "<none>"
		)
	else
		info = "Type: Table (Global)"
	end
	section.content:SetText(info)

	-- Add Copy Path button
	if not section.copyBtn then
		local btn = CreateFrame("Button", nil, section, "UIPanelButtonTemplate")
		btn:SetSize(70, 18)
		btn:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 2)
		btn:SetText("Copy Path")
		btn:GetFontString():SetFont(btn:GetFontString():GetFont(), 10)
		section.copyBtn = btn
	end

	-- Update the button's click handler with current frame
	section.copyBtn:SetScript("OnClick", function()
		local path = ns.FrameResolver:GetFramePath(frame)
		if path and type(path) == "string" then
			-- Copy to clipboard via editbox trick
			local editBox = ChatFrame1EditBox or _G.ChatFrame1EditBox
			if editBox then
				editBox:SetText(path)
				editBox:HighlightText()
				editBox:SetFocus()
				Mechanic:Print("Path copied to chat: " .. path)
			else
				Mechanic:Print("Path: " .. path)
			end
		else
			Mechanic:Print("Could not resolve path for this frame")
		end
	end)
	section.copyBtn:Show()

	local height = 60
	section:SetHeight(height)
	section:Show()
	return yOffset - height - 2
end

function InspectModule:AddDetailInteractivity(frame, yOffset)
	local section = self:GetOrCreateDetailSection("Interactivity", yOffset)
	section.title:SetText("Interactivity")

	local mouse = (frame.IsMouseEnabled and frame:IsMouseEnabled()) and "|cff00ff00Enabled|r" or "|cff888888Disabled|r"
	local mouseClick = (frame.IsMouseClickEnabled and frame:IsMouseClickEnabled()) and "|cff00ff00Enabled|r" or "|cff888888Disabled|r"
	local keyboard = (frame.IsKeyboardEnabled and frame:IsKeyboardEnabled()) and "|cff00ff00Enabled|r" or "|cff888888Disabled|r"
	local propagate = (frame.GetPropagateKeyboardInput and frame:GetPropagateKeyboardInput()) and "Yes" or "No"
	local protected = (frame.IsProtected and frame:IsProtected()) and "|cffff6666Yes|r" or "No"

	local info = string.format(
		"Mouse Motion: %s\nMouse Click: %s\nKeyboard: %s (Propagate: %s)\nProtected: %s",
		mouse,
		mouseClick,
		keyboard,
		propagate,
		protected
	)
	section.content:SetText(info)

	local height = 80
	section:SetHeight(height)
	section:Show()
	return yOffset - height - 2
end

function InspectModule:AddDetailGeometry(frame, yOffset)
	local section = self:GetOrCreateDetailSection("Geometry", yOffset)
	section.title:SetText(L["Geometry"])

	local w, h = frame:GetSize()
	local scale = frame:GetScale()
	local alpha = frame:GetAlpha()

	-- Calculate effective scale (includes all parents)
	local effectiveScale = frame:GetEffectiveScale()

	-- Calculate effective alpha (includes all parents)
	local effectiveAlpha = alpha
	local parent = frame:GetParent()
	while parent do
		if parent.GetAlpha then
			effectiveAlpha = effectiveAlpha * parent:GetAlpha()
		end
		parent = parent.GetParent and parent:GetParent()
	end

	local info = string.format(
		"Size: %.1f x %.1f\nScale: %.2f (Effective: %.2f)\nAlpha: %.2f (Effective: %.2f)\nVisible: %s (Shown: %s)",
		w,
		h,
		scale,
		effectiveScale,
		alpha,
		effectiveAlpha,
		tostring(frame:IsVisible()),
		tostring(frame:IsShown())
	)
	section.content:SetText(info)

	local height = 80
	section:SetHeight(height)
	section:Show()
	return yOffset - height - 2
end

function InspectModule:AddDetailAnchors(frame, yOffset)
	local section = self:GetOrCreateDetailSection("Anchors", yOffset)
	section.title:SetText("Anchors")

	local numPoints = frame:GetNumPoints()
	local anchors = {}

	if numPoints == 0 then
		table.insert(anchors, "No anchors set")
	else
		for i = 1, numPoints do
			local point, relativeTo, relativePoint, xOfs, yOfs = frame:GetPoint(i)
			local relativeName = "<nil>"
			if relativeTo then
				relativeName = relativeTo.GetName and relativeTo:GetName() or "<anonymous>"
			end
			table.insert(anchors, string.format(
				"%s -> %s:%s (%.0f, %.0f)",
				point or "?",
				relativeName,
				relativePoint or "?",
				xOfs or 0,
				yOfs or 0
			))
		end
	end

	section.content:SetText(table.concat(anchors, "\n"))

	local height = 20 + (#anchors * 14)
	section:SetHeight(height)
	section:Show()
	return yOffset - height - 2
end

function InspectModule:AddDetailRegions(frame, yOffset)
	local section = self:GetOrCreateDetailSection("Regions", yOffset)
	section.title:SetText("Regions (Textures/FontStrings)")

	local regions = { frame:GetRegions() }
	local regionList = {}

	if #regions == 0 then
		table.insert(regionList, "None")
	else
		for _, region in ipairs(regions) do
			local objType = region.GetObjectType and region:GetObjectType() or "Unknown"
			local name = region.GetName and region:GetName()
			if name and name ~= "" then
				table.insert(regionList, string.format("[%s] %s", objType, name))
			else
				-- Try to get more info for textures/mask textures
				local extra = ""
				local isTextureType = objType == "Texture" or objType == "MaskTexture"
				if isTextureType then
					-- Try atlas first
					if region.GetAtlas then
						local atlas = region:GetAtlas()
						if atlas and atlas ~= "" then
							extra = " atlas:" .. atlas
						end
					end
					-- If no atlas, try texture file path
					if extra == "" and region.GetTexture then
						local texPath = region:GetTexture()
						if texPath then
							if type(texPath) == "number" then
								-- FileID
								extra = (texPath == 0) and " [empty]" or " fileID:" .. texPath
							elseif type(texPath) == "string" and texPath ~= "" then
								-- Clean up "FileData ID 0" style strings or numeric strings
								local fileID = texPath:match("FileData ID (%d+)") or texPath:match("^(%d+)$")
								if fileID then
									extra = (fileID == "0") and " [empty]" or " fileID:" .. fileID
								else
									-- Extract just the filename from full path
									local filename = texPath:match("([^\\]+)$") or texPath
									extra = " file:" .. filename
								end
							end
						end
					end
				elseif objType == "FontString" then
					-- For FontStrings, show preview + font info
					local text = region.GetText and region:GetText()
					if text and text ~= "" then
						-- Truncate long text
						if #text > 20 then
							text = text:sub(1, 17) .. "..."
						end
						extra = ' "' .. text .. '"'
					end

					-- Add font info (font file and size)
					if region.GetFont then
						local font, size = region:GetFont()
						if font then
							local fontName = font:match("([^\\]+)$") or font
							extra = extra .. " font:" .. fontName .. "(" .. math.floor(size + 0.5) .. ")"
						end
					end
				end
				table.insert(regionList, string.format("[%s] <anonymous>%s", objType, extra))
			end
		end
	end

	section.content:SetText(table.concat(regionList, "\n"))

	local height = 20 + (#regionList * 14)
	section:SetHeight(height)
	section:Show()
	return yOffset - height - 2
end

function InspectModule:AddDetailProperties(frame, yOffset)
	local section = self:GetOrCreateDetailSection("Properties", yOffset)
	section.title:SetText(L["Common Properties"])

	-- Helper to safely get values (handles Midnight secret values)
	local function safeGet(func, ...)
		local ok, result = pcall(func, ...)
		if not ok then return nil, true end  -- Error, likely secret
		-- Check if result is a secret value (Midnight 12.0+)
		if issecretvalue and issecretvalue(result) then
			return nil, true
		end
		return result, false
	end

	local props = {}
	if type(frame.GetText) == "function" then
		local text, isSecret = safeGet(frame.GetText, frame)
		if isSecret then
			table.insert(props, "Text: [secret]")
		elseif text then
			table.insert(props, string.format("Text: %s", tostring(text)))
		else
			table.insert(props, "Text: nil")
		end
	end
	if type(frame.GetValue) == "function" then
		local value, isSecret = safeGet(frame.GetValue, frame)
		if isSecret then
			table.insert(props, "Value: [secret]")
		elseif value then
			table.insert(props, string.format("Value: %s", tostring(value)))
		end
	end
	if type(frame.GetMinMaxValues) == "function" then
		local ok, min, max = pcall(frame.GetMinMaxValues, frame)
		if ok and min and max then
			-- Check for secret values
			local minSecret = issecretvalue and issecretvalue(min)
			local maxSecret = issecretvalue and issecretvalue(max)
			if minSecret or maxSecret then
				table.insert(props, "Min/Max: [secret]")
			else
		table.insert(props, string.format("Min/Max: %.1f - %.1f", min, max))
			end
		end
	end

	-- For plain tables, show some members
	if not frame.GetObjectType then
		local ok, formatted = pcall(Mechanic.Utils.FormatValue, Mechanic.Utils, frame, { plain = true })
		if ok and formatted then
		table.insert(props, formatted)
		end
	end

	if #props == 0 then
		table.insert(props, "None")
	end
	section.content:SetText(table.concat(props, "\n"))

	local height = 20 + (section.content:GetStringHeight() or 14)
	section:SetHeight(height)
	section:Show()
	return yOffset - height - 2
end

function InspectModule:AddDetailAttributes(frame, yOffset)
	local section = self:GetOrCreateDetailSection("Attributes", yOffset)
	section.title:SetText("Attributes")

	-- Helper for consistent value conversion
	local function safeToString(val)
		if val == nil then return "nil" end
		if issecretvalue and issecretvalue(val) then return "[secret]" end
		local ok, str = pcall(tostring, val)
		return ok and str or "[error]"
	end

	-- Attributes are key-value pairs set via SetAttribute
	-- There's no way to iterate all attributes, so we check common ones used by Blizzard/addons
	local common = {
		-- Secure Button attributes
		"type", "action", "unit", "spell", "item", "macro", "macrotext",
		"target-slot", "attribute", "value", "pressbutton", "clickbutton",
		"initialConfigFunction", "initialConfigFunction",
		-- State Driver attributes
		"state-visibility", "state-parent", "state-unit", "state-page",
		-- Backdrop/UI attributes
		"tableIndex", "id", "name", "label",
		-- UnitFrame attributes
		"showPlayer", "showSolo", "showParty", "showRaid",
	}

	local attributes = {}
	for _, attr in ipairs(common) do
		local val = frame:GetAttribute(attr)
		if val ~= nil then
			table.insert(attributes, string.format("%s: %s", attr, safeToString(val)))
		end
	end

	if #attributes == 0 then
		table.insert(attributes, "None")
	end
	section.content:SetText(table.concat(attributes, "\n"))

	local height = 20 + (#attributes * 14)
	section:SetHeight(height)
	section:Show()
	return yOffset - height - 2
end

function InspectModule:AddDetailScripts(frame, yOffset)
	local section = self:GetOrCreateDetailSection("Scripts", yOffset)
	section.title:SetText(L["Scripts"])

	-- Helper for consistent value conversion
	local function safeToString(val)
		if val == nil then return "nil" end
		if issecretvalue and issecretvalue(val) then return "[secret]" end
		local ok, str = pcall(tostring, val)
		return ok and str or "[error]"
	end

	local scripts = {
		"OnUpdate", "OnEvent", "OnShow", "OnHide",
		"OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp", "OnClick",
		"OnValueChanged", "OnSizeChanged", "OnAttributeChanged",
		"OnDragStart", "OnDragStop", "OnTooltipShow",
		"OnLoad", "OnScrollRangeChanged", "OnHorizontalScroll", "OnVerticalScroll",
	}

	local active = {}
	for _, script in ipairs(scripts) do
		if frame:HasScript(script) then
			local func = frame:GetScript(script)
			if func then
				-- Get function address for identity checking
				-- WoW tostring(func) can be "function: 0x..." or "function: 000..."
				local str = safeToString(func)
				local addr = str:match(":(%s*0x%x+)") or str:match(":%s*(%x+)") or str:match("(%x+)") or "ptr"
				-- Clean up whitespace and 0x
				addr = addr:gsub("%s", ""):gsub("^0x", "")
				-- Show last 8 chars for brevity if it's a long address
				if #addr > 8 then
					addr = addr:sub(-8)
				end
				table.insert(active, string.format("%s: [%s]", script, addr))
			end
		end
	end

	if #active == 0 then
		table.insert(active, "None")
	end
	section.content:SetText(table.concat(active, "\n"))

	local height = 20 + (#active * 14)
	section:SetHeight(height)
	section:Show()
	return yOffset - height - 2
end

function InspectModule:GetOrCreateDetailSection(name, yOffset)
	local section = Mechanic.Utils:GetOrCreateWidget(self.detailsContent, "section_" .. name, function(p)
		local s = CreateFrame("Frame", nil, p)
		s:SetPoint("RIGHT", p, "RIGHT", 0, 0)

		s.title = s:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		s.title:SetPoint("TOPLEFT", 0, 0)

		s.content = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		s.content:SetPoint("TOPLEFT", 4, -16)
		s.content:SetJustifyH("LEFT")
		s.content:SetWidth(p:GetWidth() - 8)

		return s
	end)

	section:SetPoint("TOPLEFT", self.detailsContent, "TOPLEFT", 0, yOffset)
	self.detailSections[name] = section
	if not _G.tContains(self.detailSections, section) then
		table.insert(self.detailSections, section)
	end

	return section
end
