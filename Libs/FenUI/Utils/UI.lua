--------------------------------------------------------------------------------
-- FenUI.Utils.UI
-- UI helpers, frame resolution, and visibility guards.
--------------------------------------------------------------------------------

local Utils = FenUI.Utils

--- Returns the current mouse focus frame.
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

--- Safe frame hiding that avoids combat taint and handles secret visibility.
---@param frame Frame|nil
function Utils:HideSafe(frame)
    if not frame then return end
    if InCombatLockdown() or self.IS_MIDNIGHT then
        frame:SetAlpha(0)
    else
        frame:Hide()
        frame:SetAlpha(0)
    end
end

--- Strips Blizzard decorations (borders, masks) from a frame.
---@param frame Frame|nil
function Utils:StripBlizzardDecorations(frame)
    if not frame then return end
    local regions = { frame:GetRegions() }
    local inCombat = InCombatLockdown()

    for _, region in ipairs(regions) do
        if region:IsObjectType("MaskTexture") or region:IsObjectType("Texture") then
            local name = region:GetDebugName()
            if name and (name:find("Border") or name:find("Overlay") or name:find("Mask")) then
                if inCombat then region:SetAlpha(0) else region:Hide() end
            end
        end
    end
end

--- Applies standardized icon crop to a texture.
---@param texture Texture|nil
---@param w number
---@param h number
function Utils:ApplyIconCrop(texture, w, h)
    if not texture or not w or not h then return end
    local ratio = w / h
    if ratio > 1 then
        local scale = h / w
        local range = 0.84 * scale
        local mid = 0.5
        texture:SetTexCoord(0.08, 0.92, mid - range / 2, mid + range / 2)
    elseif ratio < 1 then
        local scale = w / h
        local range = 0.84 * scale
        local mid = 0.5
        texture:SetTexCoord(mid - range / 2, mid + range / 2, 0.08, 0.92)
    else
        texture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
end

--- Aggressively hides a texture.
---@param texture Texture|nil
function Utils:HideTexture(texture)
    if not texture then return end
    texture:SetAlpha(0)
    texture:Hide()
    if texture.SetTexture then texture:SetTexture(nil) end
    if texture.SetAtlas then texture:SetAtlas(nil) end
end

--- Wrapper for Blizzard EasyMenu or modern MenuUtil.
---@param menuList table Array of menu definitions (EasyMenu format)
---@param anchor Frame|string|nil Anchor point or frame (default: "cursor")
function Utils:ShowMenu(menuList, anchor)
    if not menuList or #menuList == 0 then return end

    -- 1. Modern Client (11.0+) - MenuUtil
    local mu = _G.MenuUtil
    if mu and mu.CreateContextMenu then
        mu.CreateContextMenu(UIParent, function(owner, rootDescription)
            for _, info in ipairs(menuList) do
                if info.isTitle then
                    rootDescription:CreateTitle(info.text)
                elseif info.hasArrow then
                    -- Submenu support (recursive)
                    local submenu = rootDescription:CreateButton(info.text)
                    -- Note: Minimal implementation for now, enough for basic needs
                elseif info.text == nil or info.text == "" then
                    rootDescription:CreateDivider()
                else
                    local btn = rootDescription:CreateButton(info.text, info.func)
                    if info.notCheckable == false or info.checked ~= nil then
                        -- Checkbox/Radio support if needed
                        -- luacheck: ignore 542
                    end
                end
            end
        end)
        return
    end

    -- 2. Legacy Fallback - EasyMenu
    local em = _G.EasyMenu
    if em then
        if not self.menuFrame then
            self.menuFrame = CreateFrame("Frame", "FenUIMenuFrame", UIParent, "UIDropDownMenuTemplate")
        end
        em(menuList, self.menuFrame, anchor or "cursor", 0, 0, "MENU")
        return
    end

    -- 3. Last resort (should not happen if libraries are present)
    print("|cffff4444[FenUI Error]|r No menu system available (EasyMenu and MenuUtil both missing).")
end

--- Generic widget factory to ensure single instance per parent.
---@param parent table
---@param key string
---@param creator function
---@return any widget
function Utils:GetOrCreateWidget(parent, key, creator)
    if parent[key] then return parent[key] end
    local widget = creator(parent)
    parent[key] = widget
    return widget
end
