# Phase 5: Console & Test Polish ✅ COMPLETE

Enhances existing Console and Tests modules with visual improvements and richer data display.

> **Status**: This phase has been fully implemented. The code exists in `UI/Console.lua` and `UI/Tests.lua`.

---

## Prerequisites

- Phase 1-4 complete
- Console module functional (`UI/Console.lua`)
- Tests module functional (`UI/Tests.lua`)
- MechanicLib categories defined

## Reference

- [MASTER_PLAN.md](MASTER_PLAN.md) - Sections 4 (Console Tab), 10 (Standard Categories)
- [13-midnight-secret-values.doc.md](../../ADDON_DEV/Addon_Dev_Guide/13-midnight-secret-values.doc.md) - SECRET category importance

---

## Scope

### In Scope
- SECRET category purple highlighting in Console
- Extensible category color mapping
- Extended test result schema with `details` array
- Rich rendering of test details in right panel
- Status-colored indicators for detail rows
- Copy format updates for detailed test results

### Out of Scope
- New tabs (Phase 6)
- MechanicLib capability extensions (Phase 6)
- Left-nav UI pattern (Phase 6)
- API Test Bench (Phase 7)

---

## Detailed Requirements

### 1. Category Color Mapping

**File**: `UI/Console.lua`

Add color coding for log categories, with SECRET being the most important for Midnight readiness:

```lua
-- Category color constants (as implemented - see UI/Console.lua)
-- Colors chosen for visibility and semantic meaning
local CATEGORY_COLORS = {
    ["[Secret]"]     = "|cffaa00ff",  -- Purple - critical for Midnight
    ["[Trigger]"]    = "|cff00ccff",  -- Cyan - action initiation
    ["[Event]"]      = "|cff88ff88",  -- Light green - system events
    ["[Validation]"] = "|cffffff00",  -- Yellow - test validation
    ["[Perf]"]       = "|cffff8800",  -- Orange - performance warnings
    ["[Core]"]       = "|cff8888ff",  -- Light blue - core lifecycle
    ["[Region]"]     = "|cffaaaaaa",  -- Grey - UI/Region updates
    ["[API]"]        = "|cff00ffcc",  -- Teal - API calls
    ["[Cooldown]"]   = "|cffffcc00",  -- Yellow-orange - Cooldowns
    ["[Load]"]       = "|cffccff00",  -- Lime - Load conditions
    -- Others default to white
}

-- Default color for uncategorized or unknown categories
local DEFAULT_CATEGORY_COLOR = "|cffffffff"
```

**Integration Point**: Modify `FormatEntries()` to apply category colors:

```lua
function Console:FormatEntries(entries)
    local lines = {}
    local showTimestamps = Mechanic.db.profile.showTimestamps
    
    for _, entry in ipairs(entries) do
        local timestamp = ""
        if showTimestamps then
            timestamp = date("[%H:%M:%S] ", entry.time)
        end

        -- Apply category color
        local category = ""
        if entry.category ~= "" then
            local color = CATEGORY_COLORS[entry.category] or DEFAULT_CATEGORY_COLOR
            category = " " .. color .. entry.category .. "|r"
        end
        
        local count = entry.count and entry.count > 1 and (" (x" .. entry.count .. ")") or ""

        table.insert(lines, string.format("%s[%s]%s %s%s", 
            timestamp, entry.source, category, entry.message, count))
    end
    return table.concat(lines, "\n")
end
```

**Acceptance Criteria**:
- [ ] SECRET category entries display in purple
- [ ] Other colored categories display correctly
- [ ] Unknown categories display in white (default)
- [ ] Colors visible in both light and dark UI themes
- [ ] Copy output does NOT include color codes (plain text)

### 2. Extended Test Result Schema

**File**: `Libs/MechanicLib/MechanicLib.lua` (documentation only - schema is addon-side)

The test result interface is extended to support a `details` array for structured diagnostic output:

```lua
-- Extended getResult(id) return schema
-- Addons implementing tests.getResult() can now return:
{
    passed = true,           -- boolean: true/false/nil (nil = pending)
    message = "Summary",     -- string: one-line result summary
    duration = 0.003,        -- number: execution time in seconds
    logs = { "line1", "line2" },  -- array: captured log lines (existing)
    
    -- NEW: Structured details array
    details = {
        {
            label = "C_Spell.GetSpellInfo",   -- string: what was tested
            value = "Returns table",          -- string: result/value
            status = "pass",                  -- string: "pass" | "warn" | "fail" | nil
        },
        {
            label = "GetSpellCooldown",
            value = "duration=SECRET",
            status = "warn",
        },
        {
            label = "C_UnitAuras.GetAuraData",
            value = "Protected API",
            status = "fail",
        },
    },
}
```

**Status Values**:
| Status | Color | Meaning |
|--------|-------|---------|
| `"pass"` | Green (`|cff00ff00`) | Test/check passed |
| `"warn"` | Yellow (`|cffffff00`) | Degraded but functional |
| `"fail"` | Red (`|cffff0000`) | Test/check failed |
| `nil` | White | Informational only |

**Acceptance Criteria**:
- [ ] Schema documented in MASTER_PLAN.md Section 3 (Test Interface Contract)
- [ ] Existing tests continue to work (backwards compatible)
- [ ] Details array is optional

### 3. Rich Details Panel Rendering

**File**: `UI/Tests.lua`

Update `UpdateDetailsPanel()` to render the `details` array:

```lua
-- Status color mapping
local DETAIL_STATUS_COLORS = {
    pass = "|cff00ff00",  -- Green
    warn = "|cffffff00",  -- Yellow
    fail = "|cffff0000",  -- Red
}
local DETAIL_STATUS_DEFAULT = "|cffffffff"  -- White

function TestsModule:UpdateDetailsPanel(testDef, result)
    -- Existing header rendering (name, category, status, duration)
    local typeTag = testDef.type == "manual" and "|cff888888(Manual)|r" or "|cff88ff88(Auto)|r"
    self.nameLabel:SetText(testDef.name .. " " .. typeTag)
    self.categoryLabel:SetText("Category: " .. testDef.category)

    if result then
        -- Status line (existing)
        local statusColor = result.passed == true and "|cff00ff00"
            or (result.passed == false and "|cffff0000" or "|cffffcc00")
        local statusText = result.passed == true and "PASSED" 
            or (result.passed == false and "FAILED" or "PENDING")
        self.statusLabel:SetText("Status: " .. statusColor .. statusText .. "|r")

        if result.duration then
            self.durationLabel:SetText(string.format("Duration: %.3fs", result.duration))
        else
            self.durationLabel:SetText("")
        end

        -- Build details text
        local detailLines = {}
        
        -- Message (existing)
        if result.message then
            table.insert(detailLines, "Message: " .. result.message)
            table.insert(detailLines, "")
        end
        
        -- NEW: Details array rendering
        if result.details and #result.details > 0 then
            table.insert(detailLines, "Details:")
            for _, detail in ipairs(result.details) do
                local statusColor = DETAIL_STATUS_COLORS[detail.status] or DETAIL_STATUS_DEFAULT
                local statusIcon = self:GetDetailStatusIcon(detail.status)
                table.insert(detailLines, string.format("  %s %s: %s%s|r",
                    statusIcon, detail.label, statusColor, detail.value))
            end
            table.insert(detailLines, "")
        end
        
        -- Captured logs (existing)
        if result.logs and #result.logs > 0 then
            table.insert(detailLines, "Captured Logs:")
            for _, log in ipairs(result.logs) do
                table.insert(detailLines, "  " .. log)
            end
        end
        
        if self.detailsBox then
            self.detailsBox:SetText(table.concat(detailLines, "\n"))
        end
    else
        -- Not run state (existing)
        self.statusLabel:SetText("Status: |cff888888Not run|r")
        self.durationLabel:SetText("")
        if self.detailsBox then
            self.detailsBox:SetText("")
        end
    end

    -- Description (existing)
    if testDef.description then
        self.descriptionLabel:SetText(testDef.description)
    else
        self.descriptionLabel:SetText("")
    end
end

-- Helper for status icons
function TestsModule:GetDetailStatusIcon(status)
    if status == "pass" then
        return "|cff00ff00[✓]|r"
    elseif status == "warn" then
        return "|cffffff00[!]|r"
    elseif status == "fail" then
        return "|cffff0000[✗]|r"
    else
        return "|cffffffff[-]|r"
    end
end
```

**Visual Output Example**:
```
Test Name (Auto)
Category: API Compliance
Status: PASSED
Duration: 0.015s

Message: 3/4 APIs fully readable

Details:
  [✓] C_Spell.GetSpellInfo: Returns table
  [!] GetSpellCooldown: duration=SECRET
  [✓] UnitHealth: Returns number
  [✗] C_UnitAuras.GetAuraData: Protected API

Captured Logs:
  [Validation] Testing C_Spell.GetSpellInfo...
  [Validation] Testing GetSpellCooldown...
```

**Acceptance Criteria**:
- [ ] Details array renders with colored status icons
- [ ] Pass/warn/fail colors are distinct and visible
- [ ] Empty details array shows nothing (graceful)
- [ ] Existing tests without details still work
- [ ] Long detail values don't break layout

### 4. Copy Format Updates

**File**: `UI/Tests.lua`

Update `GetCopyText()` to include details in plain text format:

```lua
function TestsModule:GetCopyText(includeHeader)
    local lines = {}

    if includeHeader then
        local header = Mechanic:GetEnvironmentHeader()
        if header then
            table.insert(lines, header)
            -- Add summary stats...
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
                            local test = entry.def
                            if test.category == category then
                                local result = capabilities.tests.getResult 
                                    and capabilities.tests.getResult(test.id)
                                local status = "[----]"
                                local detail = ""

                                if result then
                                    if result.passed == true then
                                        status = "[PASS]"
                                        detail = result.duration 
                                            and string.format(" (%.3fs)", result.duration) or ""
                                    elseif result.passed == false then
                                        status = "[FAIL]"
                                        detail = result.message 
                                            and (" - " .. result.message) or ""
                                    else
                                        status = "[PEND]"
                                        detail = result.message 
                                            and (" - " .. result.message) or ""
                                    end
                                end

                                table.insert(lines, string.format("  %s %s%s", 
                                    status, test.name, detail))
                                
                                -- NEW: Include details array in copy
                                if result and result.details and #result.details > 0 then
                                    for _, d in ipairs(result.details) do
                                        local statusTag = d.status 
                                            and string.upper(d.status) or "INFO"
                                        table.insert(lines, string.format("    [%s] %s: %s",
                                            statusTag, d.label, d.value))
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
```

**Copy Output Example**:
```
=== Mechanic Test Export ===
WoW: 12.0.0 | Client: PTR | Interface: 120001
Result: 3/4 passed, 1 failed, 0 pending
---
Flightsim > API Compliance
  [PASS] Secret Value Detection (0.015s)
    [PASS] C_Spell.GetSpellInfo: Returns table
    [WARN] GetSpellCooldown: duration=SECRET
    [PASS] UnitHealth: Returns number
    [FAIL] C_UnitAuras.GetAuraData: Protected API
  [PASS] Cooldown Passthrough (0.003s)
```

**Acceptance Criteria**:
- [ ] Copy includes details array in plain text
- [ ] No color codes in copy output
- [ ] Details indented under parent test
- [ ] Status tags uppercase for grep-friendliness

---

## Testing Checklist

### Console Category Colors
- [ ] Log with `MechanicLib.Categories.SECRET` shows purple
- [ ] Log with `MechanicLib.Categories.TRIGGER` shows cyan
- [ ] Log with unknown category shows white
- [ ] Copy console content has no color codes
- [ ] Colors readable on both dark and light backgrounds

### Test Details Rendering
- [ ] Test with `details` array renders correctly
- [ ] Test without `details` array still works
- [ ] Pass/warn/fail status colors are distinct
- [ ] Empty details array doesn't show "Details:" header
- [ ] Long values wrap or truncate gracefully

### Copy Format
- [ ] Test copy includes details rows
- [ ] Details use [PASS]/[WARN]/[FAIL]/[INFO] tags
- [ ] Indentation is consistent (2 spaces for test, 4 for details)
- [ ] No color codes in output

---

## Validation Workflow

```powershell
# Lint for errors
mcp_AddonDevTools_lint_addon({ name = "!Mechanic" })

# Format code
mcp_AddonDevTools_format_addon({ addon_name = "!Mechanic" })
```

**Manual Testing**:
1. Register an addon with tests that return `details` arrays
2. Run tests, verify details panel rendering
3. Copy test results, verify plain text format
4. Log with SECRET category, verify purple color
5. Log with unknown category, verify white color

---

## Handoff to Phase 6

Phase 6 requires:
- Category color system in place (extensible)
- Details array rendering functional
- Understanding of visual patterns established

Phase 6 will add:
- Tools tab with left-nav pattern
- Performance sub-counters with left-nav
- MechanicLib capability extensions (`tools`, `performance`)

