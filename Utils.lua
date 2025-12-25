-- Utils.lua
-- !Mechanic - Shared Utility Functions
--
-- Pure functions for formatting, detection, and data manipulation.
-- These are stored in ns.Utils and exposed via Mechanic.Utils.

local ADDON_NAME, ns = ...
local Utils = {}
ns.Utils = Utils

--------------------------------------------------------------------------------
-- Constants & Colors
--------------------------------------------------------------------------------

Utils.Colors = {
	-- Category color constants (from Console.lua)
	Categories = {
		["[Secret]"] = "|cffaa00ff", -- Purple - critical for Midnight
		["[Trigger]"] = "|cff00ccff", -- Cyan - action initiation
		["[Event]"] = "|cff88ff88", -- Light green - system events
		["[Validation]"] = "|cffffff00", -- Yellow - test validation
		["[Perf]"] = "|cffff8800", -- Orange - performance warnings
		["[Core]"] = "|cff8888ff", -- Light blue - core lifecycle
		["[Region]"] = "|cffaaaaaa", -- Grey - UI/Region updates
		["[API]"] = "|cff00ffcc", -- Teal - API calls
		["[Cooldown]"] = "|cffffcc00", -- Yellow-orange - Cooldowns
		["[Load]"] = "|cffccff00", -- Lime - Load conditions
		["[Error]"] = "|cffff4444", -- Soft red - captured errors
	},
	-- Status color mapping (from Tests.lua)
	Status = {
		pass = "|cff00ff00", -- Green
		warn = "|cffffff00", -- Yellow
		fail = "|cffff0000", -- Red
		pending = "|cffffcc00", -- Yellow-orange
		default = "|cffffffff", -- White
		not_run = "|cff888888", -- Grey
	},
	-- Impact color mapping (from API.lua)
	Impact = {
		HIGH = "|cffff4444", -- Red
		CONDITIONAL = "|cffffaa00", -- Orange
		RESTRICTED = "|cffffff00", -- Yellow
		LOW = "|cff00ff00", -- Green
	}
}

--------------------------------------------------------------------------------
-- Environment Detection
--------------------------------------------------------------------------------

--- Detects the client type (Retail/PTR/Beta).
---@return string client "Retail", "PTR", or "Beta"
function Utils:GetClientType()
	-- 1. Try native build type checks (standard WoW API globals)
	if _G.IsBetaBuild and _G.IsBetaBuild() then
		return "Beta"
	end
	if _G.IsTestBuild and _G.IsTestBuild() then
		return "PTR"
	end

	-- 2. Fallback to portal CVar (very reliable for developers)
	local project = GetCVar("portal") or ""
	if project:find("test") then
		return "PTR"
	elseif project:find("beta") then
		return "Beta"
	end

	-- 3. Final fallback based on interface version during transition
	local _, _, _, interface = GetBuildInfo()
	if interface >= 120000 then
		return "Retail"
	end

	return "Retail"
end

--- Returns a formatted version string: "11.0.5 (57212)"
---@return string versionString
function Utils:GetVersionString()
	local version, build = GetBuildInfo()
	return string.format("%s (%s)", version, build)
end

--- Returns a formatted interface string with client type: "110005 (Retail)"
---@return string interfaceString
function Utils:GetInterfaceString()
	local _, _, _, interface = GetBuildInfo()
	local client = self:GetClientType()
	return string.format("%d (%s)", interface, client)
end

--------------------------------------------------------------------------------
-- System & UI Helpers
--------------------------------------------------------------------------------

--- Generic widget factory to ensure single instance per parent.
---@param parent table The parent frame/object
---@param key string The key to store/retrieve the widget
---@param creator function Function that creates the widget: creator(parent)
---@return any widget
function Utils:GetOrCreateWidget(parent, key, creator)
	if parent[key] then
		return parent[key]
	end
	local widget = creator(parent)
	parent[key] = widget
	return widget
end

--- Wrapper for Blizzard EasyMenu.
---@param menuList table Array of menu definitions
---@param anchor string|table Anchor point or frame (default: "cursor")
function Utils:ShowMenu(menuList, anchor)
	if not self.menuFrame then
		self.menuFrame = CreateFrame("Frame", "MechanicUtilsMenu", UIParent, "UIDropDownMenuTemplate")
	end
	EasyMenu(menuList, self.menuFrame, anchor or "cursor", 0, 0, "MENU")
end

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

--- Returns the current mouse focus frame across all WoW versions.
---@return Frame|nil focus
function Utils:GetMouseFocus()
	if C_UI and C_UI.GetMouseFocus then
		return C_UI.GetMouseFocus()
	elseif _G.GetMouseFocus then
		return _G.GetMouseFocus()
	else
		local foci = GetMouseFoci()
		return foci and foci[1]
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
-- Formatting Helpers
--------------------------------------------------------------------------------

--- Formats memory usage in KB or MB
---@param kb number Memory in KB
---@return string formatted
function Utils:FormatMemory(kb)
	if kb >= 1024 then
		return string.format("%.1f MB", kb / 1024)
	else
		return string.format("%.0f KB", kb)
	end
end

--- Formats a duration in seconds to "Xm Ys"
---@param seconds number
---@return string formatted
function Utils:FormatDuration(seconds)
	local mins = math.floor(seconds / 60)
	local secs = math.floor(seconds % 60)
	return string.format("%dm %ds", mins, secs)
end

--------------------------------------------------------------------------------
-- Performance & Metrics
--------------------------------------------------------------------------------

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

--- Executes a function with pcall and returns (success, resultsTable).
---@param func function The function to call
---@vararg any Arguments to pass to func
---@return boolean success, table results
function Utils:SafeCall(func, ...)
	local results = { pcall(func, ...) }
	local success = table.remove(results, 1)
	return success, results
end

--------------------------------------------------------------------------------
-- Error Analysis & Formatting
--------------------------------------------------------------------------------

--- Detects the source addon from an error message or stack trace
---@param errorMsg string
---@return string|nil addonName
function Utils:DetectErrorSource(errorMsg)
	if not errorMsg then return nil end
	
	-- Look for addon name in path (e.g., "ActionHud\Core.lua" or "ActionHud/Core.lua")
	local addon = errorMsg:match("([%w_!]+)[/\\]")
	if addon then
		return addon
	end

	-- Look for Interface/AddOns path (forward slash)
	addon = errorMsg:match("Interface/AddOns/([%w_!]+)/")
	if addon then
		return addon
	end

	return nil
end

--- Colorizes a stack trace line for UI display
---@param line string
---@return string colorizedLine
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
---@param locals string
---@return string colorizedLocals
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
---@param err table The error object from BugGrabber
---@return string formattedText
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

--- Formats a value for display, handling secrets and tables.
---@param value any The value to format
---@param options table? {fields: string[], plain: boolean}
---@return string formatted
function Utils:FormatValue(value, options)
	if value == nil then
		return "nil"
	end

	-- Check if secret
	local isSecret = issecretvalue and issecretvalue(value)
	local secretTag = isSecret and (options and options.plain and " (SECRET)" or " |cffaa00ff(SECRET)|r") or ""

	if type(value) == "table" then
		local parts = {}
		if not options or not options.plain then
			table.insert(parts, "{")
		end

		if options and options.fields then
			for _, fieldName in ipairs(options.fields) do
				local fieldValue = value[fieldName]
				local fieldSecret = issecretvalue and issecretvalue(fieldValue)
				local fieldSecretTag = fieldSecret and (options.plain and " (SECRET)" or " |cffaa00ff(SECRET)|r") or ""
				table.insert(parts, string.format("  .%s = %s%s", fieldName, tostring(fieldValue), fieldSecretTag))
			end
		else
			local count = 0
			for k, v in pairs(value) do
				local fieldSecret = issecretvalue and issecretvalue(v)
				local fieldSecretTag = fieldSecret and (options and options.plain and " (SECRET)" or " |cffaa00ff(SECRET)|r") or ""
				table.insert(parts, string.format("  .%s = %s%s", tostring(k), tostring(v), fieldSecretTag))
				count = count + 1
				if count > 20 and not (options and options.fields) then
					table.insert(parts, "  ...")
					break
				end
			end
		end

		if not options or not options.plain then
			table.insert(parts, "}")
			return table.concat(parts, "\n")
		else
			return string.format("{\n%s\n  }", table.concat(parts, "\n"))
		end
	end

	return string.format("%s%s", tostring(value), secretTag)
end

--- Counts secret values within a results table.
---@param results table The results to scan
---@return number count
function Utils:CountSecrets(results)
	local count = 0
	if not results then
		return 0
	end
	for _, value in ipairs(results) do
		if issecretvalue and issecretvalue(value) then
			count = count + 1
		elseif type(value) == "table" then
			for _, v in pairs(value) do
				if issecretvalue and issecretvalue(v) then
					count = count + 1
				end
			end
		end
	end
	return count
end

--------------------------------------------------------------------------------
-- Table Helpers
--------------------------------------------------------------------------------

--- Performs a deep copy of a table.
---@param orig table The table to copy
---@return table copy
function Utils:DeepCopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[self:DeepCopy(orig_key)] = self:DeepCopy(orig_value)
		end
		setmetatable(copy, self:DeepCopy(getmetatable(orig)))
	else -- number, string, boolean, etc
		copy = orig
	end
	return copy
end

return Utils

