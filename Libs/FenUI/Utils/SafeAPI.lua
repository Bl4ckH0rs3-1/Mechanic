--------------------------------------------------------------------------------
-- FenUI.Utils.SafeAPI
-- pcall-wrapped WoW API calls for Midnight and legacy compatibility.
--------------------------------------------------------------------------------

local Utils = FenUI.Utils

-- Internal cache for performance
local cooldownCache = {}
local chargesCache = {}
local textureCache = {}
local overlayCache = {}
local cacheTime = 0
local CACHE_DURATION = 0.016 -- ~1 frame

local function InvalidateCache()
    local now = GetTime()
    if now - cacheTime > CACHE_DURATION then
        wipe(cooldownCache)
        wipe(chargesCache)
        wipe(overlayCache)
        cacheTime = now
    end
end

--- Safe wrapper for C_Spell.GetSpellCooldown.
---@param spellID number
---@return table|nil info
function Utils:GetSpellCooldownSafe(spellID)
    if not spellID or not C_Spell or not C_Spell.GetSpellCooldown then return nil end
    InvalidateCache()
    if cooldownCache[spellID] ~= nil then return cooldownCache[spellID] or nil end
    local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
    cooldownCache[spellID] = ok and info or false
    return ok and info or nil
end

--- Safe wrapper for C_ActionBar.GetActionCooldown.
---@param actionID number
---@return number startTime, number duration, boolean isEnabled, number modRate
function Utils:GetActionCooldownSafe(actionID)
    if not actionID then return 0, 0, false, 1 end
    
    if self.IS_MIDNIGHT and C_ActionBar and C_ActionBar.GetActionCooldown then
        local ok, info = pcall(C_ActionBar.GetActionCooldown, actionID)
        if ok and info then
            return info.startTime or 0, info.duration or 0, info.isEnabled, info.modRate or 1
        end
    end

    if GetActionCooldown then
        return GetActionCooldown(actionID)
    end
    return 0, 0, false, 1
end

--- Safe wrapper for UnitHealthPercent (12.0+).
---@param unit string
---@return number|nil percent, boolean isRoyal
function Utils:GetUnitHealthSafe(unit)
    if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
        local ok, percent = pcall(UnitHealthPercent, unit, true, CurveConstants.ScaleTo100)
        if ok then return percent, true end
    end

    local cur = UnitHealth(unit)
    local max = UnitHealthMax(unit)
    if max and max > 0 then
        return (cur / max) * 100, false
    end
    return nil, false
end

--- Safe pcall wrapper that returns multiple results.
---@param func function
---@vararg any
---@return boolean success, table results
function Utils:SafeCall(func, ...)
    local results = { pcall(func, ...) }
    local success = table.remove(results, 1)
    return success, results
end

--- Safe wrapper for C_ActionBar.GetActionDisplayCount.
function Utils:GetActionDisplayCountSafe(actionID)
    if not actionID then return 0 end
    if self.IS_MIDNIGHT and C_ActionBar and C_ActionBar.GetActionDisplayCount then
        local ok, count = pcall(C_ActionBar.GetActionDisplayCount, actionID)
        if ok and count then return count end
    end
    if GetActionCount then
        local count = GetActionCount(actionID)
        if type(count) == "table" then return count.count or count.displayCount or 0 end
        return count or 0
    end
    return 0
end

--- Safe wrapper for C_ActionBar.GetActionBarPage.
function Utils:GetActionBarPageSafe()
    if self.IS_MIDNIGHT and C_ActionBar and C_ActionBar.GetActionBarPage then
        local ok, page = pcall(C_ActionBar.GetActionBarPage)
        if ok and page then
            if type(page) == "table" then return page.page or page.currentPage or 1 end
            return page or 1
        end
    end
    return GetActionBarPage and GetActionBarPage() or 1
end

--- Safe wrapper for C_ActionBar.GetActionTexture.
function Utils:GetActionTextureSafe(actionID)
    if not actionID then return nil end
    if self.IS_MIDNIGHT and C_ActionBar and C_ActionBar.GetActionTexture then
        local ok, texture = pcall(C_ActionBar.GetActionTexture, actionID)
        if ok and texture then
            if type(texture) == "table" then return texture.texture or texture.icon end
            return texture
        end
    end
    return GetActionTexture and GetActionTexture(actionID) or nil
end

--- Safe wrapper for C_ActionBar.IsUsableAction.
function Utils:IsUsableActionSafe(actionID)
    if not actionID then return false, false end
    if self.IS_MIDNIGHT and C_ActionBar and C_ActionBar.IsUsableAction then
        local ok, isUsable, noMana = pcall(C_ActionBar.IsUsableAction, actionID)
        if ok then
            if type(isUsable) == "table" then return isUsable.isUsable or isUsable.usable, isUsable.notEnoughMana or isUsable.noMana end
            return isUsable, noMana
        end
    end
    if IsUsableAction then
        return IsUsableAction(actionID)
    end
    return false, false
end

--- Safe wrapper for C_ActionBar.IsActionInRange.
function Utils:IsActionInRangeSafe(actionID)
    if not actionID then return nil end
    if self.IS_MIDNIGHT and C_ActionBar and C_ActionBar.IsActionInRange then
        local ok, inRange = pcall(C_ActionBar.IsActionInRange, actionID)
        if ok and inRange ~= nil then
            if type(inRange) == "table" then return inRange.inRange or inRange.isInRange end
            return inRange
        end
    end
    return IsActionInRange and IsActionInRange(actionID) or nil
end

--- Safe wrapper for C_SpecializationInfo.GetSpecialization.
function Utils:GetSpecializationSafe()
    if self.IS_MIDNIGHT and C_SpecializationInfo and C_SpecializationInfo.GetSpecialization then
        local ok, spec = pcall(C_SpecializationInfo.GetSpecialization)
        if ok then return tonumber(spec) or spec end
    end
    return GetSpecialization and GetSpecialization() or nil
end

--- Safe wrapper for C_Spell.GetSpellCharges.
function Utils:GetSpellChargesSafe(spellID)
    if not spellID or not C_Spell or not C_Spell.GetSpellCharges then return nil end
    InvalidateCache()
    if chargesCache[spellID] ~= nil then return chargesCache[spellID] or nil end
    local ok, info = pcall(C_Spell.GetSpellCharges, spellID)
    chargesCache[spellID] = ok and info or false
    return ok and info or nil
end

--- Safe wrapper for C_Spell.GetSpellTexture.
function Utils:GetSpellTextureSafe(spellID)
    if not spellID or not C_Spell or not C_Spell.GetSpellTexture then return nil end
    if textureCache[spellID] ~= nil then return textureCache[spellID] or nil end
    local ok, texture = pcall(C_Spell.GetSpellTexture, spellID)
    textureCache[spellID] = ok and texture or false
    return ok and texture or nil
end

--- Safe wrapper for C_Item.GetItemSpell.
function Utils:GetItemSpellSafe(itemInfo)
    if not itemInfo or not C_Item or not C_Item.GetItemSpell then return nil end
    local ok, name, spellID = pcall(C_Item.GetItemSpell, itemInfo)
    if ok then
        if type(name) == "table" then return name.name or name.spellName, name.spellID or name.id end
        return name, spellID
    end
    return nil
end

--- Safe wrapper for C_Item.GetItemCooldown / GetInventoryItemCooldown.
function Utils:GetInventoryItemCooldownSafe(unit, slot)
    if not unit or not slot then return 0, 0, false end
    if C_Item and C_Item.GetItemCooldown then
        local itemID = GetInventoryItemID(unit, slot)
        if itemID and itemID > 0 then
            local ok, info = pcall(C_Item.GetItemCooldown, itemID)
            if ok and info and type(info) == "table" then return info.startTime or 0, info.duration or 0, info.isEnabled end
        end
    end
    if GetInventoryItemCooldown then
        local ok, start, duration, enabled = pcall(GetInventoryItemCooldown, unit, slot)
        if ok then
            if type(start) == "table" then return start.startTime or 0, start.duration or 0, start.isEnabled end
            return start or 0, duration or 0, enabled
        end
    end
    return 0, 0, false
end

--- Safe wrapper for C_SpellActivationOverlay.IsSpellOverlayed.
function Utils:IsSpellOverlayedSafe(spellID)
    if not spellID then return false end
    InvalidateCache()
    if overlayCache[spellID] ~= nil then return overlayCache[spellID] end
    if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed then
        local ok, result = pcall(C_SpellActivationOverlay.IsSpellOverlayed, spellID)
        if ok then
            overlayCache[spellID] = result or false
            return result
        end
    end
    if IsSpellOverlayed then
        local ok, result = pcall(IsSpellOverlayed, spellID)
        if ok then
            overlayCache[spellID] = result or false
            return result
        end
    end
    overlayCache[spellID] = false
    return false
end

--- Wipes the texture cache (textures rarely change but can on spell changes).
function Utils:InvalidateTextureCache()
    wipe(textureCache)
end

--- Safe cooldown setup for frames.
function Utils:SetCooldownSafe(cdFrame, startOrDuration, duration)
    if not cdFrame then return end
    if self.Cap.IsRoyal and type(startOrDuration) == "table" then
        if cdFrame.SetCooldownFromDurationObject then
            local ok = pcall(cdFrame.SetCooldownFromDurationObject, cdFrame, startOrDuration)
            if ok then return end
        end
    end
    local start = duration and startOrDuration or 0
    local dur = duration or startOrDuration or 0
    if self:IsValueSecret(start) or self:IsValueSecret(dur) then return end
    cdFrame:SetCooldown(tonumber(start) or 0, tonumber(dur) or 0)
end

--- Safe aura duration retrieval.
function Utils:GetDurationSafe(unit, spellID, filter)
    if not unit or not spellID then return nil end
    if self.Cap.IsAuraLegacy then
        return C_UnitAuras and C_UnitAuras.GetAuraDurationRemaining(unit, spellID, filter)
    end
    local aura = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellID(unit, spellID, filter)
    return aura and aura.duration or nil
end

--- Safe timer setup for StatusBars.
function Utils:SetTimerSafe(bar, durationObj, interpolation, direction)
    if not bar or not durationObj then return false end
    if bar.SetTimerDuration then
        local ok = pcall(bar.SetTimerDuration, bar, durationObj, interpolation, direction)
        return ok
    end
    return false
end
