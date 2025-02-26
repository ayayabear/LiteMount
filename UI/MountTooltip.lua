--[[----------------------------------------------------------------------------

  LiteMount/UI/MountTooltip.lua

  Enhanced tooltip system for mounts, groups, and families.

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...

local L = LM.Localize

--[[----------------------------------------------------------------------------
  Tooltip Mixin
----------------------------------------------------------------------------]]--

LiteMountTooltipMixin = {}

-- Position the preview model correctly relative to the tooltip
function LiteMountTooltipMixin:AttachPreview()
    local w, h = self:GetSize()

    local maxTop = self:GetTop() + h
    local maxLeft = self:GetLeft() - w
    local maxBottom = self:GetBottom() - h
    local maxRight = self:GetRight() + w

    self.Preview:ClearAllPoints()

    -- Try to position the preview in the best available space
    -- Preferred attach order: RIGHT, BOTTOM, TOP, LEFT
    if maxRight <= GetScreenWidth() then
        self.Preview:SetPoint("TOPLEFT", self, "TOPRIGHT")
    elseif maxBottom >= 0 then
        self.Preview:SetPoint("TOP", self, "BOTTOM")
    elseif maxTop <= GetScreenHeight() then
        self.Preview:SetPoint("BOTTOM", self, "TOP")
    elseif maxLeft >= 0 then
        self.Preview:SetPoint("TOPRIGHT", self, "TOPLEFT")
    end
end

-- Set up the mount preview model
function LiteMountTooltipMixin:SetupPreview(m)
    if m.modelID and m.sceneID then
        -- Need width/height for ModelScene not to div/0
        self:AttachPreview()

        self.Preview.ModelScene:SetFromModelSceneID(m.sceneID)

        local mountActor = self.Preview.ModelScene:GetActorByTag("unwrapped")
        if mountActor then
            mountActor:SetModelByCreatureDisplayID(m.modelID)
            if m.isSelfMount then
                mountActor:SetAnimationBlendOperation(Enum.ModelBlendOperation.None)
                mountActor:SetAnimation(618)
            else
                mountActor:SetAnimationBlendOperation(Enum.ModelBlendOperation.Anim)
                mountActor:SetAnimation(0)
            end
        end
        
        -- I don't know why, but the playerActor affects the camera and the
        -- camera is wrong for some mounts without this. I think?
        local playerActor = self.Preview.ModelScene:GetActorByTag("player-rider")
        if playerActor then playerActor:ClearModel() end
        
        self.Preview:Show()
    else
        self.Preview:Hide()
    end
end

-- Clean up when tooltip is hidden
function LiteMountTooltipMixin:OnHide()
    -- No cleanup needed at the moment
end

-- Set up a tooltip for a mount, group, or family
function LiteMountTooltipMixin:SetMount(m, canMount)
    -- Don't handle invalid objects or groups (groups have their own tooltip)
    if not m or m.isGroup then return end 

    -- Set up base info
    if m.mountID then
        self:SetMountBySpellID(m.spellID)
    else
        self:SetSpellByID(m.spellID)
    end

    -- Add core information
    self:AddLine(" ")

    if m.mountID then
        self:AddLine("|cffffffff"..ID..":|r "..tostring(m.mountID))
    end

    self:AddLine("|cffffffff"..STAT_CATEGORY_SPELL..":|r "..tostring(m.spellID))

    -- Add summon count if available
    if type(m) == "table" and m.GetSummonCount then
        self:AddLine("|cffffffff"..SUMMONS..":|r "..tostring(m:GetSummonCount()))
    end

    -- Add family information
    if m.family then
        self:AddLine("|cffffffff"..L.LM_FAMILY..":|r "..L[m.family])
    end

    -- Add rarity information (only for retail WoW)
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        if type(m) == "table" and m.GetRarity then
            local r = m:GetRarity()
            if r then
                self:AddLine("|cffffffff"..RARITY..":|r "..string.format(L.LM_RARITY_FORMAT, r))
            end
        end
    end

    -- Add description if available
    if m.description and m.description ~= "" then
        self:AddLine(" ")
        self:AddLine("|cffffffff" .. DESCRIPTION .. "|r")
        self:AddLine(m.description, nil, nil, nil, true)
    end

    -- Add source information if available
    if m.sourceText and m.sourceText ~= "" then
        self:AddLine(" ")
        self:AddLine("|cffffffff" .. SOURCE .. "|r")
        self:AddLine(m.sourceText, nil, nil, nil, true)
    end

    -- Add mount instruction if the mount is usable
    if canMount and m:IsCastable() then
        self:AddLine(" ")
        self:AddLine("|cffff00ff" .. HELPFRAME_REPORT_PLAYER_RIGHT_CLICK .. ": " .. MOUNT .. "|r")
    end

    -- Show the tooltip and preview
    self:Show()
    self:SetupPreview(m)
end

-- Set up a tooltip for an entity (group or family)
function LiteMountTooltipMixin:SetEntity(name, isGroup)
    -- Clear previous tooltip content
    self:ClearLines()
    
    -- Get entity status
    local entityStatus = LM.GetEntityStatus(isGroup, name)
    local usableMounts = #LM.GetMountsFromEntity(isGroup, name)
    local totalMounts = 0
    
    -- Count total mounts in entity
    for _, mount in ipairs(LM.MountRegistry.mounts) do
        local inEntity
        if isGroup then
            inEntity = LM.Options:IsMountInGroup(mount, name)
        else
            inEntity = LM.Options:IsMountInFamily(mount, name)
        end
        
        if inEntity then
            totalMounts = totalMounts + 1
        end
    end
    
    -- Get entity info
    local priority = isGroup and LM.Options:GetGroupPriority(name) or LM.Options:GetFamilyPriority(name) or 0
    local summonCount = LM.Options:GetEntitySummonCount(isGroup, name)
    
    -- Set tooltip title color based on entity type
    if isGroup then
        self:AddLine(name, 1, 1, 0)  -- Yellow for groups
    else
        self:AddLine(name, 0, 0.7, 1)  -- Blue for families
    end
    
    -- Add entity information
    self:AddLine(" ")
    self:AddLine("|cffffffff" .. L.LM_PRIORITY .. ":|r " .. priority)
    self:AddLine("|cffffffff" .. L.LM_USABLE .. ":|r " .. usableMounts .. "/" .. totalMounts)
    self:AddLine("|cffffffff" .. SUMMONS .. ":|r " .. summonCount)
    
    -- Add status information
    if entityStatus.isRed then
        self:AddLine(" ")
        self:AddLine(L.LM_NO_USABLE_MOUNTS, 1, 0, 0)
    elseif entityStatus.shouldBeGray then
        self:AddLine(" ")
        self:AddLine(L.LM_ALL_MOUNTS_DISABLED, 0.5, 0.5, 0.5)
    end
    
    -- Add usage instructions
    self:AddLine(" ")
    self:AddLine("|cffffffff" .. L.LM_LEFT_CLICK .. ":|r " .. (isGroup and L.LM_VIEW_GROUP or L.LM_VIEW_FAMILY))
    
    if usableMounts > 0 then
        self:AddLine("|cffffffff" .. L.LM_RIGHT_CLICK .. ":|r " .. L.LM_SUMMON_RANDOM_MOUNT)
    end
    
    -- Show the tooltip (no preview for entities)
    self:Show()
end