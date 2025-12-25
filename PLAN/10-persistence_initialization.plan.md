# Phase 10: Persistence & Initialization

## Overview

Phase 10 focuses on ensuring the addon's state persists correctly across UI reloads and that the UI initializes reliably without blank content areas. It also includes several UI/UX refinements and architectural fixes for the `SplitNavLayout` and various modules.

## Deliverables

### 1. Tab Persistence
- **Main Tab Memory**: Remembers and restores the last active main tab (Console, Errors, etc.) across reloads.
- **Sub-Tab Memory**: Remembers and restores the last active navigation item in modules using `SplitNavLayout` (Console sources, Performance addons, etc.).
- **Persistence Mechanism**: Uses `AceDB-3.0` to save state to `MechanicDB`.

### 2. Initialization Race Condition Fixes
- **Startup Sequence**: Refactored `MainFrame.lua` to ensure the initial tab is not only visually selected but also explicitly initialized via `OnTabChanged`.
- **Callback Guarding**: Modified `SplitNavLayout` to block navigation callbacks during the initialization phase to prevent overwriting saved state.
- **Manual Selection Triggers**: Modules now explicitly trigger their initial selection logic at the end of their `Initialize` functions, ensuring all UI elements are ready.

### 3. SplitNavLayout Enhancements
- **Robust Sizing**: Navigation buttons now use dynamic anchoring (`TOPLEFT`, `TOPRIGHT`) to fill the available width, eliminating empty space.
- **Scrollbar Inset**: Adjusted scrollbar positioning to prevent overlap with the panel border.
- **Stable Closures**: Moved button event handlers out of the refresh loop to ensure stable and reliable interactions.
- **Lazy Content Showing**: Content frames are now immediately shown if they match the current selection during creation.

### 4. UI/UX Refinements
- **Performance Tab**:
    - Re-implemented the auto-refresh button icon and coloring logic.
    - Added a structured "General" section and an "Addons" section in the left navigation.
    - Implemented a `SectionHeader` widget in FenUI for polished Blizzard-like headers.
- **Global Addon Filtering**: Moved the addon filter logic to the core level, allowing users to temporarily disable logs/metrics from specific addons across all modules.
- **ReadOnly Selectability**: Updated the FenUI `MultiLineEditBox` to allow text selection and copying even when in read-only mode, fixing the Export button's UX.
- **Reload Button**: Changed the "Reload UI" icon button to a standard text button for better clarity.
- **Title Branding**: Removed the "!" from the main window title for a cleaner appearance.

### 5. Architectural Improvements
- **navDirty Flag**: Introduced a flag-based refresh system for navigation items to avoid redundant UI updates.
- **Developer Feedback**: Added proactive validation in `Core.lua` and `Tests.lua` to log warnings when registered addons provide malformed or incomplete data.

## Implementation Details

- **Database Path**: `self.db.profile.activeTab` and `self.db.profile.activeSubTabs[storageKey]`.
- **FenUI Sync**: Synced `MultiLineEditBox` and `SectionHeader` changes to the shared library.
- **Debug Logging**: Added extensive `[MechDebug]` logging to trace startup and persistence issues.

