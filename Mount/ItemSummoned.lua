--[[----------------------------------------------------------------------------

  LiteMount/LM_ItemSummoned.lua

  Copyright 2011-2017 Mike Battersby

----------------------------------------------------------------------------]]--

LM_ItemSummoned = setmetatable({ }, LM_Mount)
LM_ItemSummoned.__index = LM_ItemSummoned

local function PlayerHasItem(itemID)
    if GetItemCount(itemID) > 0 then
        return true
    else
        return false
    end
end

-- In theory we might be able to just use the itemID and use
--      spellName = GetItemSpell(itemID)
-- the trouble is the names aren't definitely unique and that makes me
-- worried.  Since there are such a small number of these, keeping track of
-- the spell as well isn't a burden.

function LM_ItemSummoned:Get(itemID, spellID, flagList)

    local m = LM_Spell:Get(spellID, true)
    if not m then return end

    setmetatable(m, LM_ItemSummoned)

    local itemName = GetItemInfo(itemID)
    if not itemName then
        LM_Debug("LM_Mount: Failed GetItemInfo #"..itemID)
        return
    end

    m.itemID = itemID
    m.itemName = itemName
    m.flags = { }
    for _,f in ipairs(flagList) do m.flags[f] = true end
    self:Refresh()

    return m
end

function LM_ItemSummoned:Refresh()
    self.isCollected = PlayerHasItem(self.itemID)
end

function LM_ItemSummoned:GetSecureAttributes()
    return { type = "item", item = self.itemName }
end

function LM_ItemSummoned:IsUsable()

    -- IsUsableSpell seems to test correctly whether it's indoors etc.
    if spellId and not IsUsableSpell(self.spellId) then
        return false
    end

    if IsEquippableItem(self.itemID) then
        if not IsEquippedItem(self.itemID) then
            return false
        end
    else
        if not PlayerHasItem(self.itemID) then
            return false
        end
    end

    -- Either equipped or non-equippable and in bags
    local start, duration, enable = GetItemCooldown(self.itemID)
    if duration > 0 and enable == 1 then
        return false
    end

    return true
end

