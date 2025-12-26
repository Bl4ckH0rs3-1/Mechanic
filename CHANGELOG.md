# Changelog

All notable changes to !Mechanic will be documented in this file.









## [1.1.8] - 2025-12-25

### Changed
- Refactored UI to use FenUI widgets.
Consolidated utilities into FenUI.Utils.
Fixed hardcoded strings and added localization keys.
Synced libraries to latest versions.
Midnight compatibility verified.

## [1.1.7] - 2025-12-25

### Changed
- - Implemented dynamic minimap icon based on error state.
- Updated LibDBIcon-1.0 to modern version (Minor 55).
- Fixed Performance tab export overlapping table view.
- Fixed MultiLineEditBox text selection and scrolling issues.
- Optimized Inspect Watch list by switching from OnUpdate to Ticker.
- Cleaned up API definitions for Midnight 12.0 compatibility.

## [1.1.6] - 2025-12-25

### Added
- **Utility Consolidation (Round 2)**: Further consolidated UI and formatting logic across API and Inspect modules.
- Added `Mechanic.Utils:GetOrCreateWidget()` generic UI factory to eliminate repeated boilerplate.
- Added `Utils:FormatValue()` with support for table serialization, field filtering, and secret value detection (standardized across Test Bench and Inspector).
- Added `Utils:SafeCall()` helper for safe API execution with multiple return values.
- Added `Utils:ShowMenu()` wrapper for Blizzard's EasyMenu.
- Added `Utils:ResolveFrameOrTable()` to centralize string-to-object resolution.
- Added `Utils.Colors.Impact` for standardized API impact highlighting.

### Fixed
- **Inspect**: Fixed layout issues in property details where text height wasn't correctly accounted for. Improved table inspection by using the new unified serializer.
- **API**: Standardized parameter input creation and example menu handling.

### Changed
- Refactored `API.lua`, `Inspect.lua`, and `InspectDetails.lua` to remove local helper redundancy.

## [1.1.6] - 2025-12-24

### Added
- **Phase 9: API Database Automation**:
  - Integrated 3,000+ Midnight-affected and restricted APIs via automated discovery.
  - Implemented lazy-loading architecture with namespace-specific files and a central registry.
  - Added real-world usage examples from hundreds of addons to the Test Bench parameter presets.
  - Automates "Protected" status detection for APIs that cannot be called in combat.

## [1.1.5] - 2025-12-23

### Changed
- Added unified Inspect tab with frame tree, detailed property inspection, and live-updating watch list with pick mode. Updated MechanicLib to 1.1 Minor 2 with new watch list APIs.

## [1.1.4] - 2025-12-23

### Changed
- Added Phase 7: API Test Bench for WoW API exploration and Midnight secret value detection. Includes organized API categories, parameter presets, and batch testing support.

## [1.1.0] - 2025-12-23

### Changed
- Phase 6: Extensibility Framework - Standardized SplitNavLayout, new Tools tab for registered addon diagnostics, and Performance sub-metrics support.

## [1.1.0] - 2025-12-23

### Changed
- Phase 5 Complete: Enhanced console category colors (purple for [Secret]), rich test details with status-colored icons, and clean plain-text copy logic. Fixed multiple performance bottlenecks in loops.

## [1.0.0] - 2025-12-23

### Changed
- Initial stable release. Completed Phase 4 (Migration) and consolidated development hub features including Console, Error monitoring (BugGrabber), Test execution (MechanicLib), and Performance metrics. Improved UI with FenUI StatusRow/MultiLineEditBox and fixed various race conditions and layering issues. Added support for ActionHud and WimpyAuras integration.
