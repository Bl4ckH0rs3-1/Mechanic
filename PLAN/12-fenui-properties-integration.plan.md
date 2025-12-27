# Phase 12: FenUI Properties Integration

> **Status**: Planning  
> **Priority**: Medium  
> **Complexity**: Medium  
> **Depends On**: Phase 11 (Inspect Properties Editor)

---

## Goal

Extend the Inspect Properties Editor to recognize FenUI components and expose their unique configuration options for live editing. This transforms the editor from a generic frame inspector into a **FenUI development playground**.

---

## Prerequisites

- Phase 11 (Inspect Properties Editor) must be complete
- FenUI v2.5.0+ with introspectable component metadata

---

## Architecture

When a FenUI component is selected, additional property sections appear:

```
┌─────────────────────────────────┐
│ Properties              📋 ⟳   │
├─────────────────────────────────┤
│ ▼ Geometry                      │  <- Standard (Phase 11)
│   W: [200]  H: [auto]           │
│                                 │
│ ▼ FenUI: Stack                  │  <- NEW (Phase 12)
│   Direction: [vertical ▼]       │
│   Gap: [md ▼]  (8px)            │
│   Align: [stretch ▼]            │
│   Justify: [start ▼]            │
│   Wrap: [ ]                     │
│                                 │
│ ▼ FenUI: Constraints            │  <- NEW (Phase 12)
│   Min W: [200]  Max W: [800]    │
│   Min H: [--]   Max H: [--]     │
│   Aspect: [--]                  │
│                                 │
│ ▼ FenUI: Tokens                 │  <- NEW (Phase 12)
│   Background: [surfacePanel ▼]  │
│   Border: [ModernDark ▼]        │
│                                 │
│ ▼ FenUI: State                  │  <- NEW (Phase 12)
│   Current: [normal ▼]           │
│   [Trigger hover] [Trigger active]│
│                                 │
└─────────────────────────────────┘
```

---

## FenUI Component Detection

### Detection Logic

```lua
function InspectProperties:IsFenUIComponent(frame)
    return frame.fenUISupportsLayout 
        or frame.config 
        or frame.fenUILayout
        or frame.fenUIFrameId
end

function InspectProperties:GetFenUIComponentType(frame)
    if frame.fenUILayout == "Stack" or frame.SetDirection then
        return "Stack"
    elseif frame.fenUILayout == "Panel" or frame.GetSafeZone then
        return "Panel"
    elseif frame.fenUILayout == "Layout" then
        return "Layout"
    elseif frame.fenUILayout == "SplitLayout" then
        return "SplitLayout"
    end
    return "Unknown"
end
```

---

## Editable FenUI Properties by Component Type

### Layout (Base)

| Property | Type | Method |
|----------|------|--------|
| Background Token | Dropdown | `SetBackground(token)` |
| Border Key | Dropdown | `SetBorder(key)` |
| Padding | Token/Number | `SetPadding(value)` |
| Shadow Type | Dropdown | `SetShadow(type)` |

### Stack/Flex

| Property | Type | Method |
|----------|------|--------|
| Direction | Dropdown (vertical/horizontal) | `SetDirection(dir)` |
| Gap | Token Dropdown | `SetGap(token)` |
| Align | Dropdown | `SetAlign(value)` |
| Justify | Dropdown | `SetJustify(value)` |
| Wrap | Checkbox | `SetWrap(bool)` |

### Panel

| Property | Type | Method |
|----------|------|--------|
| Title | Text Input | `SetTitle(text)` |
| Closable | Checkbox | `SetClosable(bool)` |
| Movable | Checkbox | `SetMovable(bool)` |
| Resizable | Checkbox | `SetResizable(bool)` |

### Constraints (Any Component)

| Property | Type | Method |
|----------|------|--------|
| Min Width | Number | `SetConstraints({ minWidth = n })` |
| Max Width | Number | `SetConstraints({ maxWidth = n })` |
| Min Height | Number | `SetConstraints({ minHeight = n })` |
| Max Height | Number | `SetConstraints({ maxHeight = n })` |
| Aspect Ratio | Number | `SetConstraints({ aspectRatio = n })` |

### State System (Any Component with States)

| Property | Type | Method |
|----------|------|--------|
| Current State | Dropdown | `SetState(name)` |
| State Triggers | Buttons | `SetState("hover")`, etc. |

---

## Token Dropdowns

For properties that accept design tokens, show a dropdown with available options:

### Background Tokens
```lua
local backgroundTokens = {
    "surfacePanel",
    "surfaceElevated", 
    "surfaceInset",
    "surfaceOverlay",
    "gray800",
    "gray900",
    -- etc.
}
```

### Gap/Spacing Tokens
```lua
local spacingTokens = {
    "xs",   -- 2px
    "sm",   -- 4px
    "md",   -- 8px
    "lg",   -- 16px
    "xl",   -- 24px
    "2xl",  -- 32px
}
```

### Border Keys
```lua
local borderKeys = {
    "ModernDark",
    "Inset",
    "Panel",
    "Tooltip",
    -- etc.
}
```

---

## Export Format with FenUI Properties

```markdown
## !Mechanic Frame Edit Export

**Target Frame**
- Path: `MyAddon.mainPanel.contentStack`
- Type: Frame
- FenUI Component: Stack
- FenUI Version: 2.5.0

**Changes**
| Property | Before | After |
|----------|--------|-------|
| Width | 200 | 250 |
| FenUI.direction | vertical | horizontal |
| FenUI.gap | md | lg |
| FenUI.background | surfacePanel | surfaceElevated |
| FenUI.maxWidth | 800 | 600 |

**Lua Implementation**
\`\`\`lua
local frame = MyAddon.mainPanel.contentStack

-- Standard properties
frame:SetWidth(250)

-- FenUI Stack properties
frame:SetDirection("horizontal")
frame:SetGap("lg")

-- FenUI Layout properties
frame:SetBackground("surfaceElevated")

-- FenUI Constraints
frame:SetConstraints({ maxWidth = 600 })
\`\`\`

**Context**
- Exported: 2025-12-26 23:45:00
- WoW Build: 12.0.1 (64914)
- !Mechanic Version: 1.2.3
- FenUI Version: 2.5.0
```

---

## Implementation Phases

### Phase 12.1: FenUI Detection & Base Layout
- [ ] Implement `IsFenUIComponent()` detection
- [ ] Implement `GetFenUIComponentType()` classification
- [ ] Add "FenUI: Layout" section for base properties
- [ ] Create token dropdown widget for background/border selection
- [ ] Wire up `SetBackground()`, `SetBorder()`, `SetPadding()`

### Phase 12.2: Stack/Flex Properties
- [ ] Add "FenUI: Stack" section when Stack component detected
- [ ] Create direction dropdown (vertical/horizontal)
- [ ] Create gap token dropdown
- [ ] Create align/justify dropdowns
- [ ] Wire up Stack methods

### Phase 12.3: Constraints & Panel
- [ ] Add "FenUI: Constraints" section
- [ ] Create min/max width/height inputs
- [ ] Add aspect ratio input
- [ ] Add "FenUI: Panel" section for Panel-specific props
- [ ] Wire up Panel methods (title, closable, movable, resizable)

### Phase 12.4: State System Integration
- [ ] Add "FenUI: State" section when states are defined
- [ ] Create state dropdown showing available states
- [ ] Add state trigger buttons for quick testing
- [ ] Show current state indicator

### Phase 12.5: Export Enhancement
- [ ] Detect FenUI component type in export
- [ ] Include FenUI-specific changes in export table
- [ ] Generate FenUI method calls in Lua snippet
- [ ] Include FenUI version in export metadata

---

## FenUI API Requirements

For this integration to work smoothly, FenUI components need:

### Introspection Methods (May Need to Add)
```lua
-- Get current config values
frame:GetDirection()      -- Stack
frame:GetGap()            -- Stack
frame:GetAlign()          -- Stack
frame:GetJustify()        -- Stack
frame:GetBackground()     -- Layout
frame:GetBorderKey()      -- Layout
frame:GetConstraints()    -- Any
frame:GetCurrentState()   -- Stateful components
frame:GetAvailableStates() -- Stateful components
```

### Setter Methods (Most Already Exist)
```lua
frame:SetDirection(dir)
frame:SetGap(token)
frame:SetAlign(value)
frame:SetJustify(value)
frame:SetBackground(token)
frame:SetBorder(key)
frame:SetConstraints(config)
frame:SetState(name)
```

---

## UI Components Needed

| Widget | Purpose | Source |
|--------|---------|--------|
| Token Dropdown | Select from predefined tokens | Custom (FenUI dropdown + token list) |
| State Buttons | Trigger state changes | FenUI Button row |
| Aspect Ratio Input | Numeric with "16:9" parsing | Custom |
| Constraint Group | Min/Max paired inputs | Custom layout |

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| FenUI API changes break integration | Version check, graceful fallback |
| Missing getter methods | Add introspection API to FenUI |
| Token list out of sync | Pull tokens dynamically from `FenUI.Tokens` |
| Performance with many dropdowns | Lazy-create on section expand |

---

## Success Criteria

1. FenUI components show additional property sections
2. Token dropdowns populate from live `FenUI.Tokens` data
3. Changes apply immediately and visually update
4. Export includes FenUI-specific Lua code
5. Non-FenUI frames work exactly as before (no regression)

---

## Future Enhancements

- **Animation Preview**: Trigger show/hide animations from Properties panel
- **Slot Inspector**: View and manipulate slot contents
- **Token Picker**: Visual color picker that maps to nearest token
- **FenUI Explorer Link**: "Open in FenUI Explorer" button for component type

