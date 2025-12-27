# Phase 11: Live Frame Property Editor

> **Status**: Planning  
> **Priority**: High  
> **Complexity**: Medium-High  
> **Enables**: Phase 12 (FenUI Properties Integration)

---

## Goal

Create a DevTools-style property editor within the Inspect tab that allows live editing of frame properties with export functionality for agent consumption.

**Forward Compatibility**: This phase establishes extensible patterns that Phase 12 will use to add FenUI-specific property sections.

---

## Architecture

Four-column layout: **Tree** (navigate) | **Properties** (edit) | **Details** (understand) | **Watch** (control)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Tree        │  Properties         │  Details            │  Watch List      │
│  (Navigate)  │  (Edit)         📋⟳ │  (Understand)       │  (Control)   👁⟳ │
├──────────────┼─────────────────────┼─────────────────────┼──────────────────┤
│ ▼ UIParent   │ ▼ Geometry          │ Type: Frame         │ Speed Bar   0.0  │
│   ▼ Frame    │   W:[616] H:[1678]  │ Strata: HIGH        │ Accel Bar   2.0  │
│     ▶ child  │   X:[0]  Y:[-700]   │ ▼ Anchors (5)       │ [+ Watch]        │
│              │ ▼ Visibility        │ ▼ Regions (3)       │                  │
│              │   Alpha: [1.0]      │ ▼ Scripts (2)       │                  │
│              │   Shown: [✓]        │                     │                  │
└──────────────┴─────────────────────┴─────────────────────┴──────────────────┘
```

**Header Pattern**: Each panel has a header with title + action icons (top-right), matching Watch List's existing pattern:
- **Properties**: Export (clipboard icon) + Reset (refresh icon)
- **Watch List**: Eye (visibility) + Refresh icons

---

## Key Files

| File | Action | Purpose |
|------|--------|---------|
| `UI/InspectProperties.lua` | **Create** | New property editor module |
| `UI/Inspect.lua` | Modify | Refactor to 4-column layout |
| `UI/InspectDetails.lua` | Modify | Compress verbose sections |
| `UI/InspectTree.lua` | Modify | Narrower column |
| `UI/InspectWatch.lua` | Modify | Narrower column |
| `Locales/*.lua` | Modify | Add new UI strings |

---

## Editable Properties

| Category | Properties | Input Type | Combat Safe |
|----------|------------|------------|-------------|
| **Geometry** | Width, Height | Number inputs | Yes |
| **Geometry** | X Offset, Y Offset | Number inputs | Yes* |
| **Visibility** | Alpha | Slider 0-1 | Yes |
| **Visibility** | Shown | Checkbox | Yes* |
| **Layering** | FrameLevel | Number input | Yes |
| **Layering** | FrameStrata | Dropdown | Yes |
| **Scale** | Scale | Number input | Yes |
| **Texture** | VertexColor RGBA | Color inputs | Yes |
| **FontString** | TextColor RGBA | Color inputs | Yes |
| **FontString** | Text Content | Text input | Yes |
| **StatusBar** | Value, Min, Max | Number inputs | Yes |

*May be blocked on protected Blizzard frames during combat*

---

## Export Format

Markdown with embedded Lua - human readable and agent-ready:

```markdown
## !Mechanic Frame Edit Export

**Target Frame**
- Path: `MainFrame.safeZone.content.scrollFrame`
- Type: Frame
- Parent: content
- Strata: HIGH

**Changes**
| Property | Before | After |
|----------|--------|-------|
| Width | 616 | 620 |
| Height | 1678 | 1700 |
| Alpha | 1.0 | 0.9 |

**Lua Implementation**
\`\`\`lua
-- Resolve the frame
local frame = MainFrame.safeZone.content.scrollFrame

-- Apply changes
frame:SetSize(620, 1700)
frame:SetAlpha(0.9)
\`\`\`

**Context**
- Exported: 2025-12-26 23:15:42
- WoW Build: 12.0.1 (64914)
- !Mechanic Version: 1.2.3
```

---

## Implementation Phases

### Phase 11.1: Foundation & Architecture
- [ ] Refactor `Inspect.lua` to 4-column FenUI layout
- [ ] Create `InspectProperties.lua` with header (title + icons) and scrollable body
- [ ] **Implement Section Registry pattern** (for Phase 12 extensibility)
- [ ] **Implement Input Widget Factory** (number, checkbox, dropdown, slider)
- [ ] Implement Geometry editing as first registered section

### Phase 11.2: Core Editing
- [ ] Add Visibility section (alpha slider, shown toggle)
- [ ] Add Layering section (level input, strata dropdown)
- [ ] Add Scale section
- [ ] Implement change tracking (before/after diff per section)
- [ ] **Add FenUI detection stub** (show badge, no editing yet)

### Phase 11.3: Export and Polish
- [ ] Build export icon handler using **section contribution pattern**
- [ ] Add reset icon handler (revert all changes across sections)
- [ ] Add region-specific props (texture color, text color) as sections
- [ ] Compress Details column (collapsible sections)

### Phase 11.4: Future Enhancements (Out of Scope)
- [ ] Draggable column widths
- [ ] Undo/Redo stack
- [ ] Responsive breakpoints
- [ ] **Phase 12**: FenUI-specific property sections

---

## Extensibility Architecture (Phase 12 Preparation)

### Section Registry Pattern

Design sections as pluggable modules that Phase 12 can extend:

```lua
-- Section registry allows future extensions
InspectProperties.sections = {}

function InspectProperties:RegisterSection(key, config)
    -- config = { title, order, shouldShow(frame), createUI(parent, frame), 
    --            getExportData(frame), getExportLua(frame) }
    self.sections[key] = config
    self:SortSections()
end

-- Built-in sections (Phase 11)
InspectProperties:RegisterSection("geometry", {
    title = L["Geometry"],
    order = 10,
    shouldShow = function(frame) return frame.GetWidth ~= nil end,
    createUI = function(parent, frame) ... end,
    getExportData = function(frame) ... end,
    getExportLua = function(frame) ... end,
})

-- Phase 12 will add:
-- InspectProperties:RegisterSection("fenui_stack", { ... })
-- InspectProperties:RegisterSection("fenui_constraints", { ... })
```

### Input Widget Factory

Create reusable input creators that Phase 12 can extend:

```lua
InspectProperties.inputs = {
    number = function(parent, config) 
        -- config = { label, value, min, max, onChange }
        return FenUI:CreateInput(parent, { ... })
    end,
    checkbox = function(parent, config)
        return FenUI:CreateCheckbox(parent, { ... })
    end,
    dropdown = function(parent, config)
        -- config = { label, options, selected, onChange }
        return CreateDropdown(parent, config)
    end,
    slider = function(parent, config)
        -- config = { label, min, max, value, onChange }
        return CreateSlider(parent, config)
    end,
}

-- Phase 12 adds:
-- InspectProperties.inputs.tokenDropdown = function(parent, config) ... end
```

### FenUI Detection Stub

Detect FenUI components early to show indicator (Phase 12 adds full editing):

```lua
function InspectProperties:IsFenUIComponent(frame)
    return frame.fenUISupportsLayout 
        or frame.config 
        or frame.fenUILayout
        or frame.fenUIFrameId
end

-- In header rendering:
if self:IsFenUIComponent(frame) then
    -- Show "FenUI" badge next to title
    -- Phase 12 will add the actual editable sections
end
```

### Export Contribution Pattern

Each section contributes to the export independently:

```lua
function InspectProperties:GenerateExport()
    local exportData = {}
    local luaLines = {}
    
    -- Collect from all visible sections
    for key, section in pairs(self.sections) do
        if section.shouldShow(self.currentFrame) then
            local data = section.getExportData(self.currentFrame)
            local lua = section.getExportLua(self.currentFrame)
            if data then tAppendAll(exportData, data) end
            if lua then table.insert(luaLines, lua) end
        end
    end
    
    return self:FormatExport(exportData, luaLines)
end
```

---

## Technical Notes

### Change Tracking System

```lua
-- Store original values when frame is selected
local originalValues = {
    width = frame:GetWidth(),
    height = frame:GetHeight(),
    alpha = frame:GetAlpha(),
    -- etc.
}

-- Track changes as user edits
local pendingChanges = {}

function TrackChange(property, newValue)
    if newValue ~= originalValues[property] then
        pendingChanges[property] = {
            before = originalValues[property],
            after = newValue,
        }
    else
        pendingChanges[property] = nil
    end
end
```

### Export Generation

```lua
function GenerateExport()
    local lines = {}
    table.insert(lines, "## !Mechanic Frame Edit Export")
    table.insert(lines, "")
    table.insert(lines, "**Target Frame**")
    table.insert(lines, string.format("- Path: `%s`", currentPath))
    -- ... build markdown table of changes
    -- ... generate Lua snippet
    return table.concat(lines, "\n")
end
```

### Input Widgets Needed

| Widget | Source | Notes |
|--------|--------|-------|
| Number Input | FenUI `CreateInput` | With validation |
| Checkbox | FenUI `CreateCheckbox` | For boolean props |
| Slider | Native or FenUI | For alpha 0-1 |
| Dropdown | FenUI or native | For strata selection |
| Color Picker | Native `ColorPickerFrame` | For RGBA values |

---

## Dependencies

- FenUI v2.5.0+ (for 4-column layout, custom scrollbar)
- Existing Inspect infrastructure (tree, details, watch)

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Protected frame editing blocked | Detect `IsProtected()` and show warning |
| Combat lockdown blocks edits | Queue changes for `PLAYER_REGEN_ENABLED` |
| Performance with many inputs | Lazy-create inputs on section expand |
| Complex anchor editing | Start with offset-only, defer full anchor editing |

---

## Success Criteria

1. User can select a frame and edit its geometry, visibility, layering, and scale
2. Changes apply immediately and are visible in-game
3. Export produces valid, agent-consumable markdown with Lua snippet
4. Reset reverts all pending changes to original values
5. UI follows existing !Mechanic patterns (header icons, scrollable panels)
6. **Section Registry is functional** - new sections can be added without modifying core code
7. **FenUI components show badge** - indicator that Phase 12 will add more options

