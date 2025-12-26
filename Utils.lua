--------------------------------------------------------------------------------
-- Utils.lua
-- !Mechanic - Shared Utility Functions
--
-- Pure functions for formatting, detection, and data manipulation.
-- These are stored in ns.Utils and exposed via Mechanic.Utils.
--------------------------------------------------------------------------------

local ADDON_NAME, ns = ...
local Utils = {}
ns.Utils = Utils

-- Use shared FenUI utilities if available
local F = FenUI and FenUI.Utils

--------------------------------------------------------------------------------
-- Constants & Colors
--------------------------------------------------------------------------------

-- Inherit shared colors and provide local overrides/additions
Utils.Colors = F and F.Colors or { Categories = {}, Status = {}, Impact = {} }

--------------------------------------------------------------------------------
-- Environment & System
--------------------------------------------------------------------------------

function Utils:GetClientType() return F and F:GetClientType() or "Retail" end
function Utils:GetVersionString() return F and F:GetVersionString() or "Unknown" end
function Utils:GetInterfaceString() return F and F:GetInterfaceString() or "Unknown" end

--- Robustly opens the settings panel for an addon.
---@param categoryName string|table The category name or object
function Utils:OpenSettings(categoryName)
	if InCombatLockdown() then
		print("|cffff4444[Mechanic Error]|r Settings cannot be opened while in combat.")
		return
	end

	if Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(categoryName)
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(categoryName)
	end
end

--------------------------------------------------------------------------------
-- UI Helpers
--------------------------------------------------------------------------------

--- Generic widget factory to ensure single instance per parent.
function Utils:GetOrCreateWidget(parent, key, creator)
    return F and F:GetOrCreateWidget(parent, key, creator) or creator(parent)
end

--- Returns the current mouse focus frame across all WoW versions.
function Utils:GetMouseFocus()
    return F and F:GetMouseFocus() or _G.GetMouseFocus()
end

--- Wrapper for Blizzard EasyMenu.
---@param menuList table Array of menu definitions
---@param anchor string|table Anchor point or frame (default: "cursor")
function Utils:ShowMenu(menuList, anchor)
    if F and F.ShowMenu then
        F:ShowMenu(menuList, anchor)
        return
    end

	if not self.menuFrame then
		self.menuFrame = CreateFrame("Frame", "MechanicUtilsMenu", UIParent, "UIDropDownMenuTemplate")
	end
    
    if EasyMenu then
	    EasyMenu(menuList, self.menuFrame, anchor or "cursor", 0, 0, "MENU")
    else
        print("|cffff4444[Mechanic Error]|r EasyMenu is not available in this WoW version.")
    end
end

--- Resolves a string path to either a frame or a global table.
---@param input string|table The path or object reference
---@return any|nil resolved
function Utils:ResolveFrameOrTable(input)
	if type(input) ~= "string" then
		return input
	end

	-- Try FrameResolver first
	if ns.FrameResolver then
		local frame = ns.FrameResolver:ResolvePath(input)
		if frame then return frame end
	end

	-- Fallback to global traversal
	local parts = { strsplit(".", input) }
	local current = _G
	for _, part in ipairs(parts) do
		if type(current) ~= "table" then return nil end
		current = current[part]
		if not current then return nil end
	end

	return current
end

--------------------------------------------------------------------------------
-- Mechanic Export Header
--------------------------------------------------------------------------------

--- Generates a header with environment information for copy/paste.
---@param profile table The addon profile containing inclusion settings
---@return string|nil header
function Utils:GetEnvironmentHeader(profile)
	if not profile or not profile.includeEnvHeader then
		return nil
	end

	local lines = {
		"=== Mechanic Export ===",
	}

	-- WoW version + build
	table.insert(lines, string.format("WoW: %s | Interface: %s", self:GetVersionString(), self:GetInterfaceString()))

	-- Character info (optional)
	if profile.includeCharacterInfo then
		local name = UnitName("player")
		local realm = GetRealmName()
		local _, class = UnitClass("player")
		local spec = GetSpecialization()
		local specName = spec and select(2, GetSpecializationInfo(spec)) or "None"
		table.insert(lines, string.format("Character: %s-%s (%s, %s)", name, realm, class, specName))
	end

	-- Timestamp (optional)
	if profile.includeTimestamp then
		table.insert(lines, string.format("Exported: %s", date("%Y-%m-%d %H:%M:%S")))
	end

	-- Registered addons
	local MechanicLib = LibStub("MechanicLib-1.0", true)
	if MechanicLib then
		local registered = {}
		for name, caps in pairs(MechanicLib:GetRegistered()) do
			local ver = caps.version or "?"
			table.insert(registered, string.format("%s %s", name, ver))
		end
		if #registered > 0 then
			table.insert(lines, string.format("Registered: %s", table.concat(registered, ", ")))
		end
	end

	return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Formatting & Metrics
--------------------------------------------------------------------------------

function Utils:FormatMemory(kb) return F and F:FormatMemory(kb) or tostring(kb) end
function Utils:FormatDuration(seconds) return F and F:FormatDuration(seconds) or tostring(seconds) end
function Utils:FormatValue(value, options) return F and F:FormatValue(value, options) or tostring(value) end
function Utils:CountSecrets(results) return F and F:CountSecrets(results) or 0 end
function Utils:DeepCopy(orig) return F and F:DeepCopy(orig) or orig end
function Utils:SafeCall(func, ...) return F and F:SafeCall(func, ...) or pcall(func, ...) end

--- Returns standard performance metrics (FPS, Latency, Lua Memory).
---@return table metrics {fps, latencyHome, latencyWorld, luaMemory}
function Utils:GetExtendedMetrics()
	local fps = GetFramerate()
	local _, _, latencyHome, latencyWorld = GetNetStats()
	local luaMemory = collectgarbage("count") -- KB

	return {
		fps = fps,
		latencyHome = latencyHome,
		latencyWorld = latencyWorld,
		luaMemory = luaMemory,
	}
end

--------------------------------------------------------------------------------
-- Error Analysis (BugGrabber specific)
--------------------------------------------------------------------------------

--- Detects the source addon from an error message or stack trace
function Utils:DetectErrorSource(errorMsg)
	if not errorMsg then return nil end
	
	-- Look for addon name in path (e.g., "ActionHud\Core.lua" or "ActionHud/Core.lua")
	local addon = errorMsg:match("([%w_!]+)[/\\]")
	if addon then return addon end

	-- Look for Interface/AddOns path (forward slash)
	addon = errorMsg:match("Interface/AddOns/([%w_!]+)/")
	if addon then return addon end

	return nil
end

--- Colorizes a stack trace line for UI display
function Utils:ColorizeStackLine(line)
	-- Remove Interface/AddOns prefix for readability
	local cleanLine = line:gsub("[%.I][%.n][%.t][%.e][%.r]face/", "")
	cleanLine = cleanLine:gsub("%.?%.?%.?/?AddOns/", "")

	-- Highlight line numbers
	cleanLine = cleanLine:gsub(":(%d+)", ":|cff00ff00%1|r")

	-- Highlight lua files
	cleanLine = cleanLine:gsub("([^/]+%.lua)", "|cffffffff%1|r")

	return cleanLine
end

--- Colorizes Lua locals string for UI display
function Utils:ColorizeLocals(locals)
	if not locals then return "" end
	local result = locals
	-- Highlight variable names
	result = result:gsub("(%s-)([%a_][%a_%d]*) = ", "%1|cffffff80%2|r = ")
	-- Highlight nil
	result = result:gsub("= nil", "= |cffff7f7fnil|r")
	-- Highlight numbers
	result = result:gsub("= (%-?[%d%.]+)", "= |cffff7fff%1|r")
	return result
end

--- Formats a BugGrabber error object into a colorized string.
function Utils:FormatError(err)
	local lines = {}

	-- Count and message
	table.insert(lines, string.format("|cffffffff%dx|r %s", err.counter or 1, err.message))
	table.insert(lines, "")

	-- Stack trace
	if err.stack then
		table.insert(lines, "|cff888888Stack:|r")
		for line in err.stack:gmatch("[^\n]+") do
			table.insert(lines, string.format("  %s", self:ColorizeStackLine(line)))
		end
		table.insert(lines, "")
	end

	-- Locals
	if err.locals then
		table.insert(lines, "|cff888888Locals:|r")
		table.insert(lines, self:ColorizeLocals(err.locals))
	end

	return table.concat(lines, "\n")
end

return Utils
