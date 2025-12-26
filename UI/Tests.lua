-- UI/Tests.lua
-- !Mechanic - Tests Tab Module (Phase 2)

local ADDON_NAME, ns = ...
local Mechanic = LibStub("AceAddon-3.0"):GetAddon(ADDON_NAME)
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON_NAME)
local TestsModule = {}
Mechanic.Tests = TestsModule

local STATUS_COLORS = Mechanic.Utils.Colors.Status

TestsModule.selectedAddon = nil
TestsModule.selectedTest = nil
TestsModule.exportMode = false

function Mechanic:InitializeTests()
	if TestsModule.frame then
		return
	end

	local parent = self.frame.moduleContent
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	TestsModule.frame = frame

	-- Toolbar
	local toolbar = FenUI:CreateToolbar(frame, {
		height = 32,
		padding = 4,
	})
	toolbar:SetPoint("TOPLEFT", 0, 0)
	toolbar:SetPoint("TOPRIGHT", 0, 0)

	local runSelectedBtn = toolbar:AddButton({
		text = "Run Selected",
		width = 110,
		onClick = function()
			TestsModule:RunSelected()
		end,
	})

	local runAllBtn = toolbar:AddButton({
		text = "Run All Auto",
		width = 110,
		onClick = function()
			TestsModule:RunAllAuto()
		end,
	})

	toolbar:AddSpacer("flex")

	local exportBtn = toolbar:AddButton({
		text = "Export",
		width = 70,
		onClick = function()
			TestsModule:ToggleExportMode()
		end,
	})
	TestsModule.exportButton = exportBtn

	local clearBtn = toolbar:AddButton({
		text = "Clear",
		width = 60,
		onClick = function()
			TestsModule:ClearResults()
		end,
	})

	-- Summary Bar
	local testSummaryBar = CreateFrame("Frame", nil, frame)
	testSummaryBar:SetHeight(24)
	testSummaryBar:SetPoint("BOTTOMLEFT", 8, 4)
	testSummaryBar:SetPoint("BOTTOMRIGHT", -8, 4)
	TestsModule.summaryBar = testSummaryBar

	local summaryLabel = testSummaryBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	summaryLabel:SetPoint("LEFT", 0, 0)
	TestsModule.summaryLabel = summaryLabel

	-- Tree Panel (replacing AceGUI-TreeGroup)
	local tree = FenUI:CreateTree(frame, {
		onSelect = function(value)
		local parts = { strsplit(":", value) }
		if #parts == 2 then
			TestsModule:OnTestSelected(parts[1], parts[2])
		end
		end,
	})
	tree:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -4)
	tree:SetPoint("BOTTOMLEFT", testSummaryBar, "TOPLEFT", 0, 4)
	tree:SetWidth(200)
	TestsModule.tree = tree

	-- Right Panel: Details
	local detailsFrame = CreateFrame("Frame", nil, frame)
	detailsFrame:SetPoint("TOPLEFT", tree, "TOPRIGHT", 4, 0)
	detailsFrame:SetPoint("BOTTOMRIGHT", testSummaryBar, "TOPRIGHT", 0, 4)
	TestsModule.detailsFrame = detailsFrame

	local nameLabel = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	nameLabel:SetPoint("TOPLEFT", 8, -8)
	nameLabel:SetText(L["Select a test"])
	TestsModule.nameLabel = nameLabel

	local categoryLabel = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	categoryLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -4)
	TestsModule.categoryLabel = categoryLabel

	local statusLabel = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	statusLabel:SetPoint("TOPLEFT", categoryLabel, "BOTTOMLEFT", 0, -8)
	TestsModule.statusLabel = statusLabel

	local durationLabel = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	durationLabel:SetPoint("LEFT", statusLabel, "RIGHT", 16, 0)
	TestsModule.durationLabel = durationLabel

	local descriptionLabel = detailsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	descriptionLabel:SetPoint("TOPLEFT", statusLabel, "BOTTOMLEFT", 0, -8)
	descriptionLabel:SetWidth(400)
	descriptionLabel:SetJustifyH("LEFT")
	TestsModule.descriptionLabel = descriptionLabel

	local detailsBox = FenUI:CreateMultiLineEditBox(detailsFrame, {
		readOnly = true,
		background = "surfaceInset",
	})
	detailsBox:SetPoint("TOPLEFT", descriptionLabel, "BOTTOMLEFT", 0, -12)
	detailsBox:SetPoint("BOTTOMRIGHT", -8, 8)
	TestsModule.detailsBox = detailsBox

	-- Export Mode: Full-tab text display (hidden by default)
	local exportBox = FenUI:CreateMultiLineEditBox(frame, {
		readOnly = true,
		background = "surfaceInset",
		autoScroll = false,
	})
	exportBox:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -4)
	exportBox:SetPoint("BOTTOMRIGHT", testSummaryBar, "TOPRIGHT", 0, 4)
	exportBox:Hide()
	TestsModule.exportBox = exportBox

	TestsModule:RefreshTree()
	TestsModule:UpdateSummary()
end

function TestsModule:RefreshTree()
	if not self.frame or not self.tree then
		return
	end
	local tree = self:BuildTree()
	self.tree:SetData(tree)
end

function TestsModule:BuildTree()
	local tree = {}
	local MechanicLib = LibStub("MechanicLib-1.0", true)
	if not MechanicLib then
		return tree
	end

	local textParts = {}

	for addonName, capabilities in pairs(MechanicLib:GetRegistered()) do
		if capabilities.tests then
			local addonNode = {
				text = addonName,
				value = addonName,
				children = {},
			}

			-- Get categories
			if capabilities.tests.getCategories then
				local categories = capabilities.tests.getCategories()
				for _, category in ipairs(categories) do
					local categoryNode = {
						text = category,
						value = string.format("%s:%s", addonName, category),
						children = {},
					}

					-- Get tests in category
					if capabilities.tests.getAll then
						local allTests = capabilities.tests.getAll()
						for _, entry in ipairs(allTests) do
							local test = entry.def or entry -- Support both {def={...}} and direct {...}
							if test and test.id and test.category == category then
								local result = capabilities.tests.getResult and capabilities.tests.getResult(test.id)
								local icon = self:GetStatusIcon(result)

								wipe(textParts)
								table.insert(textParts, icon)
								table.insert(textParts, " ")
								table.insert(textParts, test.name)

								table.insert(categoryNode.children, {
									text = table.concat(textParts),
									value = string.format("%s:%s", addonName, test.id),
								})
							end
						end
					end

					table.insert(addonNode.children, categoryNode)
				end
			end

			table.insert(tree, addonNode)
		end
	end

	return tree
end

function TestsModule:GetStatusIcon(result)
	if not result then
		return string.format("%s[-]|r", STATUS_COLORS.not_run) -- Not run
	elseif result.passed == true then
		return string.format("%s[✓]|r", STATUS_COLORS.pass) -- Passed
	elseif result.passed == false then
		return string.format("%s[✗]|r", STATUS_COLORS.fail) -- Failed
	else
		return string.format("%s[~]|r", STATUS_COLORS.pending) -- Pending
	end
end

function TestsModule:OnTestSelected(addonName, testId)
	self.selectedAddon = addonName
	self.selectedTest = testId

	local MechanicLib = LibStub("MechanicLib-1.0", true)
	local capabilities = MechanicLib and MechanicLib:GetRegistered()[addonName]
	if not capabilities or not capabilities.tests then
		return
	end

	-- Find test definition
	local testDef = nil
	if capabilities.tests.getAll then
		for _, entry in ipairs(capabilities.tests.getAll()) do
			local test = entry.def or entry
			if test and test.id == testId then
				testDef = test
				break
			end
		end
	end

	if not testDef then
		return
	end

	-- Get result
	local result = capabilities.tests.getResult and capabilities.tests.getResult(testId)

	-- Update display
	self:UpdateDetailsPanel(testDef, result)
end

function TestsModule:UpdateDetailsPanel(testDef, result)
	local typeTag = testDef.type == "manual" and "|cff888888(Manual)|r" or "|cff88ff88(Auto)|r"
	self.nameLabel:SetText(string.format("%s %s", testDef.name, typeTag))
	self.categoryLabel:SetText(string.format(L["Category: %s"], testDef.category))

	if result then
		local statusColor = result.passed == true and STATUS_COLORS.pass
			or (result.passed == false and STATUS_COLORS.fail or STATUS_COLORS.pending)
		local statusText = result.passed == true and L["PASSED"] or (result.passed == false and L["FAILED"] or L["PENDING"])
		self.statusLabel:SetText(string.format(L["Status: %s%s|r"], statusColor, statusText))

		if result.duration then
			self.durationLabel:SetText(string.format(L["Duration: %.3fs"], result.duration))
		else
			self.durationLabel:SetText("")
		end

		local details = {}
		if result.message then
			table.insert(details, string.format(L["Message: %s"], result.message))
			table.insert(details, "")
		end

		-- NEW: Details array rendering per Phase 5
		if result.details and #result.details > 0 then
			table.insert(details, L["Details:"])
			for _, detail in ipairs(result.details) do
				local statusColor = STATUS_COLORS[detail.status] or STATUS_COLORS.default
				local statusIcon = self:GetDetailStatusIcon(detail.status)
				table.insert(
					details,
					string.format(L["  %s %s: %s%s|r"], statusIcon, detail.label, statusColor, detail.value)
				)
			end
			table.insert(details, "")
		end

		if result.logs and #result.logs > 0 then
			table.insert(details, L["Captured Logs:"])
			for _, log in ipairs(result.logs) do
				table.insert(details, string.format(L["  %s"], log))
			end
		end

		if self.detailsBox then
			self.detailsBox:SetText(table.concat(details, "\n"))
		end
	else
		self.statusLabel:SetText(L["Status: |cff888888Not run|r"])
		self.durationLabel:SetText("")
		if self.detailsBox then
			self.detailsBox:SetText("")
		end
	end

	if testDef.description then
		self.descriptionLabel:SetText(testDef.description)
	else
		self.descriptionLabel:SetText("")
	end
end

-- Helper for status icons per Phase 5
function TestsModule:GetDetailStatusIcon(status)
	if status == "pass" then
		return string.format("%s[✓]|r", STATUS_COLORS.pass)
	elseif status == "warn" then
		return string.format("%s[!]|r", STATUS_COLORS.warn)
	elseif status == "fail" then
		return string.format("%s[✗]|r", STATUS_COLORS.fail)
	else
		return string.format("%s[-]|r", STATUS_COLORS.default)
	end
end

function TestsModule:RunSelected()
	if not self.selectedAddon or not self.selectedTest then
		Mechanic:Print(L["No test selected."])
		return
	end

	local MechanicLib = LibStub("MechanicLib-1.0", true)
	local capabilities = MechanicLib and MechanicLib:GetRegistered()[self.selectedAddon]
	if capabilities and capabilities.tests and capabilities.tests.run then
		capabilities.tests.run(self.selectedTest)
		self:RefreshTree()
		self:OnTestSelected(self.selectedAddon, self.selectedTest)
		self:UpdateSummary()
	end
end

function TestsModule:RunAllAuto()
	local MechanicLib = LibStub("MechanicLib-1.0", true)
	if not MechanicLib then
		return
	end

	local totalPassed, totalTests = 0, 0
	for addonName, capabilities in pairs(MechanicLib:GetRegistered()) do
		if capabilities.tests and capabilities.tests.runAll then
			local passed, total = capabilities.tests.runAll()
			totalPassed = totalPassed + passed
			totalTests = totalTests + total
		end
	end

	Mechanic:Print(string.format("Tests complete: %d/%d passed", totalPassed, totalTests))
	self:RefreshTree()
	self:UpdateSummary()
end

function TestsModule:ClearResults()
	local MechanicLib = LibStub("MechanicLib-1.0", true)
	if not MechanicLib then
		return
	end

	for addonName, capabilities in pairs(MechanicLib:GetRegistered()) do
		if capabilities.tests and capabilities.tests.clearResults then
			capabilities.tests.clearResults()
		end
	end
	self:RefreshTree()
	self:UpdateSummary()
	self.statusLabel:SetText(L["Status: |cff888888Not run|r"])
	if self.detailsBox then
		self.detailsBox:SetText("")
	end
end

function TestsModule:UpdateSummary()
	if not self.summaryLabel then
		return
	end
	local total, passed, failed, pending = 0, 0, 0, 0
	local MechanicLib = LibStub("MechanicLib-1.0", true)
	if not MechanicLib then
		return
	end

	for addonName, capabilities in pairs(MechanicLib:GetRegistered()) do
		if capabilities.tests and capabilities.tests.getAll then
			for _, entry in ipairs(capabilities.tests.getAll()) do
				local test = entry.def or entry
				if test and test.id then
				total = total + 1
					local result = capabilities.tests.getResult and capabilities.tests.getResult(test.id)
				if result then
					if result.passed == true then
						passed = passed + 1
					elseif result.passed == false then
						failed = failed + 1
					else
						pending = pending + 1
						end
					end
				end
			end
		end
	end

	self.summaryLabel:SetText(
		string.format("Total: %d | Passed: %d | Failed: %d | Pending: %d", total, passed, failed, pending)
	)
end

function TestsModule:ToggleExportMode()
	self.exportMode = not self.exportMode

	if self.exportMode then
		-- Hide tree/details, show export box
		if self.tree then
			self.tree:Hide()
		end
		if self.detailsFrame then
			self.detailsFrame:Hide()
		end
		if self.exportBox then
			local text = self:GetCopyText(Mechanic.db.profile.includeEnvHeader)
			self.exportBox:SetText(text)
			self.exportBox:Show()
			self.exportBox:ScrollToTop()
		end
		if self.exportButton then
			self.exportButton:SetText(L["Tree View"])
		end
	else
		-- Hide export box, show tree/details
		if self.exportBox then
			self.exportBox:Hide()
		end
		if self.tree then
			self.tree:Show()
		end
		if self.detailsFrame then
			self.detailsFrame:Show()
		end
		if self.exportButton then
			self.exportButton:SetText(L["Export"])
		end
	end
end

function TestsModule:GetCopyText(includeHeader)
	local lines = {}

	if includeHeader then
		local header = Mechanic:GetEnvironmentHeader()
		if header then
			table.insert(lines, header)
			local total, passed, failed, pending = 0, 0, 0, 0
			-- Recalculate for summary
			local MechanicLib = LibStub("MechanicLib-1.0", true)
			if MechanicLib then
				for _, caps in pairs(MechanicLib:GetRegistered()) do
					if caps.tests and caps.tests.getAll then
						for _, entry in ipairs(caps.tests.getAll()) do
							local test = entry.def or entry
							if test and test.id then
							total = total + 1
								local res = caps.tests.getResult and caps.tests.getResult(test.id)
							if res then
								if res.passed == true then
									passed = passed + 1
								elseif res.passed == false then
									failed = failed + 1
								else
									pending = pending + 1
									end
								end
							end
						end
					end
				end
			end
			table.insert(
				lines,
				string.format("Result: %d/%d passed, %d failed, %d pending", passed, total, failed, pending)
			)
			table.insert(lines, "---")
		end
	end

	local MechanicLib = LibStub("MechanicLib-1.0", true)
	if MechanicLib then
		for addonName, capabilities in pairs(MechanicLib:GetRegistered()) do
			if capabilities.tests and capabilities.tests.getCategories then
				local categories = capabilities.tests.getCategories()
				for _, category in ipairs(categories) do
					table.insert(lines, string.format("%s > %s", addonName, category))

					if capabilities.tests.getAll then
						for _, entry in ipairs(capabilities.tests.getAll()) do
							local test = entry.def or entry
							if test and test.id and test.category == category then
								local result = capabilities.tests.getResult and capabilities.tests.getResult(test.id)
								local status = "[----]"
								local detail = ""

								if result then
									if result.passed == true then
										status = "[PASS]"
										detail = result.duration and string.format(" (%.3fs)", result.duration) or ""
									elseif result.passed == false then
										status = "[FAIL]"
										detail = result.message and string.format(" - %s", result.message) or ""
									else
										status = "[PEND]"
										detail = result.message and string.format(" - %s", result.message) or ""
									end
								end

								table.insert(lines, string.format("  %s %s%s", status, test.name, detail))

								-- NEW: Include details array in copy per Phase 5
								if result and result.details and #result.details > 0 then
									for _, d in ipairs(result.details) do
										local statusTag = d.status and string.upper(d.status) or "INFO"
										table.insert(
											lines,
											string.format("    [%s] %s: %s", statusTag, d.label, d.value)
										)
									end
								end
							end
						end
					end
				end
			end
		end
	end

	return table.concat(lines, "\n")
end
