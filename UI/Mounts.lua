--[[----------------------------------------------------------------------------

  LiteMount/UI/Mounts.lua

  Options frame for the mount list.

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...

local C_Spell = LM.C_Spell or C_Spell

local L = LM.Localize

if LM.db and LM.db.callbacks then
    LM.db.callbacks.orig_Fire = LM.db.callbacks.Fire
end

--[[------------------------------------------------------------------------]]--

LiteMountPriorityMixin = {}

function LiteMountPriorityMixin:Update()
    local parent = self:GetParent()
    local value

    if parent.mount then
        value = parent.mount:GetPriority()
    elseif parent.group then
        value = LM.Options:GetGroupPriority(parent.group)
    elseif parent.family then
        value = LM.Options:GetFamilyPriority(parent.family)
    elseif self.family then
        value = LM.Options:GetFamilyPriority(self.family)
    end

    if value then
        self.Minus:SetShown(value > LM.Options.MIN_PRIORITY)
        self.Plus:SetShown(value < LM.Options.MAX_PRIORITY)
        self.Priority:SetText(value)
    else
        -- Default display when there's no value
        self.Minus:Show()
        self.Plus:Show()
        self.Priority:SetText('0')
    end

    if LM.Options:GetOption('randomWeightStyle') == 'Priority' or value == 0 then
        local r, g, b = LM.UIFilter.GetPriorityColor(value):GetRGB()
        self.Background:SetColorTexture(r, g, b, 0.33)
    else
        local r, g, b = LM.UIFilter.GetPriorityColor(''):GetRGB()
        self.Background:SetColorTexture(r, g, b, 0.33)
    end
end
	
function LiteMountPriorityMixin:Get()
    local parent = self:GetParent()
    if parent.mount then
        return parent.mount:GetPriority()
    elseif parent.group then
        return LM.Options:GetGroupPriority(parent.group)
    elseif parent.family then
        return LM.Options:GetFamilyPriority(parent.family)
    elseif self.family then
        return LM.Options:GetFamilyPriority(self.family)
    end
end

function LiteMountPriorityMixin:Set(v)
    local parent = self:GetParent()
    if parent.mount then
        LiteMountMountsPanel.MountScroll.isDirty = true
        LM.Options:SetPriority(parent.mount, v or LM.Options.DEFAULT_PRIORITY)
    elseif parent.group then
        LiteMountMountsPanel.MountScroll.isDirty = true
        LM.Options:SetGroupPriority(parent.group, v or LM.Options.DEFAULT_PRIORITY)
    elseif parent.family then
        LiteMountMountsPanel.MountScroll.isDirty = true
        LM.Options:SetFamilyPriority(parent.family, v or LM.Options.DEFAULT_PRIORITY)
    elseif self.family then
        LiteMountMountsPanel.MountScroll.isDirty = true
        LM.Options:SetFamilyPriority(self.family, v or LM.Options.DEFAULT_PRIORITY)
    end
end

function LiteMountPriorityMixin:Increment()
    local parent = self:GetParent()
    local v
    if parent.mount then
        v = parent.mount:GetPriority()
    elseif parent.group then
        v = LM.Options:GetGroupPriority(parent.group)
    elseif parent.family then
        v = LM.Options:GetFamilyPriority(parent.family)
    elseif self.family then
        v = LM.Options:GetFamilyPriority(self.family)
    end

    if v then
        if parent.mount then
            LM.Options:SetPriority(parent.mount, v + 1)
        elseif parent.group then
            LM.Options:SetGroupPriority(parent.group, v + 1)
        elseif parent.family then
            LM.Options:SetFamilyPriority(parent.family, v + 1)
        elseif self.family then
            LM.Options:SetFamilyPriority(self.family, v + 1)
        end
        self:Update()
    else
        if parent.mount then
            LM.Options:SetPriority(parent.mount, LM.Options.DEFAULT_PRIORITY)
        elseif parent.group then
            LM.Options:SetGroupPriority(parent.group, LM.Options.DEFAULT_PRIORITY)
        elseif parent.family then
            LM.Options:SetFamilyPriority(parent.family, LM.Options.DEFAULT_PRIORITY)
        elseif self.family then
            LM.Options:SetFamilyPriority(self.family, LM.Options.DEFAULT_PRIORITY)
        end
        self:Update()
    end
end

function LiteMountPriorityMixin:Decrement()
    local parent = self:GetParent()
    local v
    if parent.mount then
        v = parent.mount:GetPriority() or LM.Options.DEFAULT_PRIORITY
    elseif parent.group then
        v = LM.Options:GetGroupPriority(parent.group) or LM.Options.DEFAULT_PRIORITY
    elseif parent.family then
        v = LM.Options:GetFamilyPriority(parent.family) or LM.Options.DEFAULT_PRIORITY
    elseif self.family then
        v = LM.Options:GetFamilyPriority(self.family) or LM.Options.DEFAULT_PRIORITY
    end

    if parent.mount then
        LM.Options:SetPriority(parent.mount, v - 1)
    elseif parent.group then
        LM.Options:SetGroupPriority(parent.group, v - 1)
    elseif parent.family then
        LM.Options:SetFamilyPriority(parent.family, v - 1)
    elseif self.family then
        LM.Options:SetFamilyPriority(self.family, v - 1)
    end
    self:Update()
end

function LiteMountPriorityMixin:OnEnter()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:ClearLines()
    GameTooltip:AddLine(L.LM_PRIORITY)

    if LM.Options:GetOption('randomWeightStyle') ~= 'Priority' then
        GameTooltip:AddLine(' ')
        GameTooltip:AddLine(L.LM_RARITY_DISABLES_PRIORITY, 1, 1, 1, true)
        GameTooltip:AddLine(' ')
    end

    for _,p in ipairs(LM.UIFilter.GetPriorities()) do
        local t, d = LM.UIFilter.GetPriorityText(p)
        GameTooltip:AddLine(t .. ' - ' .. d)
    end
    GameTooltip:Show()
end

function LiteMountPriorityMixin:OnLeave()
    GameTooltip:Hide()
end

--[[------------------------------------------------------------------------]]--

LiteMountAllPriorityMixin = {}

function LiteMountAllPriorityMixin:Set(v)
    -- Get all visible items
    local items = LM.UIFilter.GetFilteredMountList()
    LiteMountMountsPanel.MountScroll.isDirty = true
	LM.Debug("All Priority Set: Got " .. #items .. " items")
    
    -- Validate priority value
    if v then
        v = math.max(LM.Options.MIN_PRIORITY, math.min(LM.Options.MAX_PRIORITY, v))
    end

    for _, item in ipairs(items) do
        if item.isGroup then
            LM.db.profile.groupPriorities[item.name] = v
			
        elseif item.isFamily then
            LM.Debug("Setting family " .. item.name .. " to priority " .. tostring(v))			
            if not LM.db.profile.familyPriorities then
                LM.db.profile.familyPriorities = {}
            end
            LM.db.profile.familyPriorities[item.name] = v
        else
			LM.Debug("Setting mount " .. item.name .. " to priority " .. tostring(v))
            LM.db.profile.mountPriorities[item.spellID] = v
        end
    end
    
    -- Fire callback to update UI
    LM.db.callbacks:Fire("OnOptionsModified")
end

function LiteMountAllPriorityMixin:Get()
    local items = LM.UIFilter.GetFilteredMountList()
    local allValue

    for _, item in ipairs(items) do
        local v
        if item.isGroup then
            v = LM.db.profile.groupPriorities[item.name]
        elseif item.isFamily then 
            v = LM.db.profile.familyPriorities and LM.db.profile.familyPriorities[item.name]
        else
            v = LM.db.profile.mountPriorities[item.spellID]
        end
        
        if allValue == nil then
            allValue = v
        elseif allValue ~= v then
            return nil
        end
    end

    return allValue
end

function LiteMountAllPriorityMixin:Increment()
    local v = self:Get()
    if v then
        self:Set(v + 1)
    else
        self:Set(LM.Options.DEFAULT_PRIORITY)
    end
end

function LiteMountAllPriorityMixin:Decrement()
    local v = self:Get() or LM.Options.DEFAULT_PRIORITY
    self:Set(v - 1)
end

--[[------------------------------------------------------------------------]]--

LiteMountFlagBitMixin = {}

function LiteMountFlagBitMixin:OnClick()
    local mount = self:GetParent().mount

    LiteMountMountsPanel.MountScroll.isDirty = true
    if self:GetChecked() then
        LM.Options:SetMountFlag(mount, self.flag)
    else
        LM.Options:ClearMountFlag(mount, self.flag)
    end
end

function LiteMountFlagBitMixin:OnEnter()
    if self.flag then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L[self.flag])
        GameTooltip:Show()
    end
end

function LiteMountFlagBitMixin:OnLeave()
    if GameTooltip:GetOwner() == self then
        GameTooltip:Hide()
    end
end

function LiteMountFlagBitMixin:Update(flag, mount)
    self.flag = flag

    local cur = mount:GetFlags()

    self:SetChecked(cur[flag] or false)

    -- If we changed this from the default then color the background
    self.Modified:SetShown(mount.flags[flag] ~= cur[flag])

    -- You can turn off any flag, but the only ones you can turn on when they
    -- were originally off are RUN for flying and dragonriding mounts and
    -- SWIM for any mount.

    if cur[flag] or mount.flags[flag] then
        self:Enable()
        self:Show()
    elseif flag == "SWIM" and not mount.flags.DRIVE then
        self:Enable()
        self:Show()
    elseif flag == "RUN" and ( mount.flags.FLY or mount.flags.DRAGONRIDING ) then
        self:Enable()
        self:Show()
    elseif flag == "FLY" and mount.flags.DRAGONRIDING then
        self:Enable()
        self:Show()
    else
        self:Hide()
        self:Disable()
    end

end

--[[------------------------------------------------------------------------]]--

-- This is a minimal emulation of LM.ActionButton

LiteMountMountIconMixin = {}

function LiteMountMountIconMixin:OnEnter()
    local parent = self:GetParent()
    local item = parent.mount or parent.group or parent.family
    if not item then return end

    if parent.family or (type(item) == "table" and item.isFamily) then
        local familyName = type(item) == "string" and item or item.name
        local familyStatus = LM.GetGroupOrFamilyStatus(false, familyName)
        local mounts = LM.GetMountsFromEntity(false, familyName)
        local usableMounts = 0
        local totalMounts = 0
        
        for _, mount in ipairs(LM.MountRegistry.mounts) do
            if LM.Options:IsMountInFamily(mount, familyName) then
                totalMounts = totalMounts + 1
                if mount:IsCollected() and mount:IsUsable() and mount:GetPriority() > 0 then
                    usableMounts = usableMounts + 1
                end
            end
        end
        
        local priority = LM.Options:GetFamilyPriority(familyName) or 0
        local summonCount = LM.Options:GetEntitySummonCount(false, familyName)
        
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 8)
        GameTooltip:AddLine(familyName, 0, 0.7, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Priority: " .. priority)
        GameTooltip:AddLine("Usable Mounts: " .. usableMounts .. "/" .. totalMounts)
        GameTooltip:AddLine("Total Summons: " .. summonCount)
        
        if familyStatus.isRed then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("No usable mounts available", 1, 0, 0)
        end
        
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click to view family")
        if usableMounts > 0 then
            GameTooltip:AddLine("Right-Click to summon random mount from family")
        end
        GameTooltip:Show()
        
    elseif parent.group or (type(item) == "table" and item.isGroup) then
        local groupName = type(item) == "string" and item or item.name
        local groupStatus = LM.GetGroupOrFamilyStatus(true, groupName)
        local mounts = LM.GetMountsFromEntity(true, groupName)
        local usableMounts = 0
        local totalMounts = 0
        
        for _, mount in ipairs(LM.MountRegistry.mounts) do
            if LM.Options:IsMountInGroup(mount, groupName) then
                totalMounts = totalMounts + 1
                if mount:IsCollected() and mount:IsUsable() and mount:GetPriority() > 0 then
                    usableMounts = usableMounts + 1
                end
            end
        end
        
        local priority = LM.Options:GetGroupPriority(groupName) or 0
        local summonCount = LM.Options:GetEntitySummonCount(true, groupName)
        
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 8)
        GameTooltip:AddLine(groupName, 1, 1, 0)  -- Yellow for groups
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Priority: " .. priority)
        GameTooltip:AddLine("Usable Mounts: " .. usableMounts .. "/" .. totalMounts)
        GameTooltip:AddLine("Total Summons: " .. summonCount)
        
        if groupStatus.isRed then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("No usable mounts available", 1, 0, 0)
        elseif groupStatus.shouldBeGray then
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine("All mounts disabled (priority 0)", 0.5, 0.5, 0.5)
        end
        
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Left-Click to view group")
        if usableMounts > 0 then
            GameTooltip:AddLine("Right-Click to summon random mount from group")
        end
        GameTooltip:Show()
    else
        -- Regular mount tooltip
        LiteMountTooltip:SetOwner(self, "ANCHOR_RIGHT", 8)
        LiteMountTooltip:SetMount(item, true)
    end
end

function LiteMountMountIconMixin:OnLeave()
    GameTooltip:Hide()
    LiteMountTooltip:Hide()
end
-- 
function LiteMountMountIconMixin:HandleGroupFamilySummon(parent)
    if not parent.group and not parent.family then return false end
    
    -- Only handle right-click summoning
    local button = GetMouseButtonClicked()
    if button ~= "RightButton" then return false end
    
    -- Block the summon to prevent the bug from occurring
    LM.Debug("Blocking right-click summon for " .. 
             (parent.group and "group: " .. parent.group or "family: " .. parent.family))
    
    return true -- Return true to indicate we handled the click
end

-- Modify the original OnClickHook to use our helper
function LiteMountMountIconMixin:OnClickHook(mouseButton, isDown)
    local parent = self:GetParent()
    
    LM.Debug("Mount icon clicked: " .. button .. " for " .. 
             (parent.mount and "mount " .. parent.mount.name or
              parent.group and "group " .. parent.group or
              parent.family and "family " .. parent.family or
              "unknown"))

    if button == "RightButton" then
        -- Handle mount summoning
        if parent.mount and parent.mount.mountID then
            -- Direct mount summoning
            C_MountJournal.SummonByID(parent.mount.mountID)
            parent.mount:OnSummon()
        elseif parent.group or parent.family then
            -- Group/Family summoning
            local entityName = parent.group or parent.family
            local isGroup = parent.group ~= nil
            
            -- Get filtered list of mounts
            local mounts = LM.GetMountsFromEntity(isGroup, entityName)
            
            if #mounts > 0 then
                -- Select mount using current weight style
                local style = LM.Options:GetOption('randomWeightStyle')
                local selectedMount = mounts:Random(nil, style)
                
                if selectedMount and selectedMount.mountID then
                    -- First increment the entity counter
                    LM.Options:IncrementEntitySummonCount(isGroup, entityName)
                    
                    -- Then summon the mount and trigger its OnSummon
                    C_MountJournal.SummonByID(selectedMount.mountID)
                    selectedMount:OnSummon()
                end
            end
        end
    elseif button == "LeftButton" then
        -- Handle left-click navigation and chat linking
        if IsModifiedClick("CHATLINK") and parent.mount then
            local mountLink = GetSpellLink(parent.mount.spellID)
            if mountLink then
                ChatEdit_InsertLink(mountLink)
            end
        elseif parent.group then
            LiteMountGroupsPanel.Groups.selectedGroup = parent.group
            Settings.OpenToCategory(LiteMountGroupsPanel.category.ID)
            LiteMountGroupsPanel:Update()
        elseif parent.family then
            LiteMountFamiliesPanel.Families.selectedFamily = parent.family
            Settings.OpenToCategory(LiteMountFamiliesPanel.category.ID)
            LiteMountFamiliesPanel:Update()
        end
    end
end

-- Replace OnClickHook

function LiteMountMountIconMixin:OnLoad()
    self:SetAttribute("unit", "player")
    self:RegisterForClicks("AnyUp")
    self:RegisterForDrag("LeftButton")
    
    -- Replace the OnClick handler completely instead of hooking it
    self:SetScript("OnClick", function(self, button, isDown)
        local parent = self:GetParent()
        
        LM.Debug("Icon clicked: " .. button .. " on " .. 
                (parent.group and "group: " .. parent.group or 
                 parent.family and "family: " .. parent.family or 
                 parent.mount and "mount: " .. parent.mount.name or "unknown"))
        
        -- Handle left-click navigation
        if button == "LeftButton" then
            -- Call the original PreClick for chat link functionality
            if self.PreClick then
                self:PreClick(button, isDown)
            end
            
            if parent.group then
                LiteMountGroupsPanel.Groups.selectedGroup = parent.group
                Settings.OpenToCategory(LiteMountGroupsPanel.category.ID)
                LiteMountGroupsPanel:Update()
            elseif parent.family then
                LiteMountFamiliesPanel.Families.selectedFamily = parent.family
                Settings.OpenToCategory(LiteMountFamiliesPanel.category.ID)
                LiteMountFamiliesPanel:Update()
            elseif parent.mount and parent.mount.spellID then
                -- For regular mounts, allow chat linking
                if IsModifiedClick("CHATLINK") then
                    local mountLink = GetSpellLink(parent.mount.spellID)
                    if mountLink then
                        ChatEdit_InsertLink(mountLink)
                    end
                else
                    -- Regular click - pickup spell
                    C_Spell.PickupSpell(parent.mount.spellID)
                end
            end
        elseif button == "RightButton" then
            -- Handle mount summoning
            if parent.group or parent.family then
                local entityName = parent.group or parent.family
                local isGroup = parent.group ~= nil
                
                local mounts = LM.GetMountsFromEntity(isGroup, entityName)
                
                if #mounts > 0 then
                    local style = LM.Options:GetOption('randomWeightStyle')
                    local mount = mounts:Random(nil, style)
                    
                    if mount and mount.mountID then
                        LM.Debug("Summoning " .. mount.name .. " from " .. 
                                (isGroup and "group: " or "family: ") .. entityName)
                        C_MountJournal.SummonByID(mount.mountID)
                        mount:OnSummon()
                    end
                else
                    LM.Debug("No usable mounts found in " .. 
                            (isGroup and "group: " or "family: ") .. entityName)
                end
            elseif parent.mount and parent.mount.mountID then
                -- Direct mount summoning
                C_MountJournal.SummonByID(parent.mount.mountID)
                if parent.mount.OnSummon then
                    parent.mount:OnSummon()
                end
            end
        end
    end)
end

function LiteMountMountIconMixin:OnDragStart()
    local mount = self:GetParent().mount
    if mount and mount.spellID then
        C_Spell.PickupSpell(mount.spellID)
    end
end

function LM.GetMountsFromEntity(isGroup, entityName)
    local mounts = LM.MountList:New()
    
    -- When getting mounts for summoning, ignore search filter
    local context = LiteMountOptions.CurrentOptionsPanel
    local isSummoning = not context or (context ~= LiteMountGroupsPanel and context ~= LiteMountFamiliesPanel)
    
    -- Get current search state
    local filtertext = isSummoning and "" or LM.UIFilter.GetSearchText()
    local isSearching = filtertext and filtertext ~= SEARCH and filtertext ~= ""

    for _, mount in ipairs(LM.MountRegistry.mounts) do
        local isInEntity = false
        if isGroup then
            isInEntity = LM.Options:IsMountInGroup(mount, entityName)
        else
            isInEntity = LM.Options:IsMountInFamily(mount, entityName)
        end
        
        -- Only check if mount is in entity, collected, usable and has priority
        if isInEntity and mount:IsCollected() and mount:IsUsable() and mount:GetPriority() > 0 then
            -- Check faction requirements
            local isRightFaction = true
            if mount.mountID then
                local _, _, _, _, _, _, _, isFactionSpecific, faction = C_MountJournal.GetMountInfoByID(mount.mountID)
                if isFactionSpecific then
                    local playerFaction = UnitFactionGroup('player')
                    isRightFaction = (playerFaction == 'Horde' and faction == 0) or 
                                   (playerFaction == 'Alliance' and faction == 1)
                end
            end
            
            -- Check if mount matches search if searching
            local matchesSearch = true
            if isSearching then
                matchesSearch = strfind(mount.name:lower(), filtertext:lower(), 1, true)
            end

            -- Add mount if it passes all checks
            if isRightFaction and (not isSearching or matchesSearch) then
                table.insert(mounts, mount)
            end
        end
    end

    return mounts
end

-- Status checking function used by UI
function LM.GetGroupOrFamilyStatus(isGroup, name)
    local hasUsableMounts = false
    local hasCollectedMounts = false
    local hasPriorityMounts = false
    
    for _, mount in ipairs(LM.MountRegistry.mounts) do
        local isMountInEntity = false
        
        if isGroup then
            isMountInEntity = LM.Options:IsMountInGroup(mount, name)
        else
            isMountInEntity = LM.Options:IsMountInFamily(mount, name)
        end
        
        if isMountInEntity then
            -- Check if mount has priority > 0
            if mount:GetPriority() > 0 then
                hasPriorityMounts = true
                
                -- Check faction
                local isRightFaction = true
                if mount.mountID then
                    local _, _, _, _, _, _, _, isFactionSpecific, faction = C_MountJournal.GetMountInfoByID(mount.mountID)
                    if isFactionSpecific then
                        local playerFaction = UnitFactionGroup('player')
                        isRightFaction = (playerFaction == 'Horde' and faction == 0) or 
                                       (playerFaction == 'Alliance' and faction == 1)
                    end
                end
                
                if mount:IsCollected() then
                    hasCollectedMounts = true
                    
                    -- Only count as usable if it's the right faction and can be summoned
                    if isRightFaction and mount:IsUsable() then
                        hasUsableMounts = true
                    end
                end
            end
        end
    end
    
    -- A group/family is:
    -- - Normal if it has at least one usable mount with priority > 0
    -- - Red if it has mounts with priority > 0 but none are usable
    -- - Gray if it has no mounts with priority > 0
    local isRed = hasPriorityMounts and hasCollectedMounts and not hasUsableMounts
    
    return {
        hasCollectedMounts = hasCollectedMounts,
        hasUsableMounts = hasUsableMounts,
        hasPriorityMounts = hasPriorityMounts,
        isRed = isRed,
        shouldBeGray = not hasPriorityMounts
    }
end

-- Helper function specific to family mount collection

--[[------------------------------------------------------------------------]]--

LiteMountMountButtonMixin = {}

function LiteMountMountButtonMixin:Update(bitFlags, item)
    --LM.Debug("Button Update start for " .. (item.isFamily and "family " .. item.name or item.isGroup and "group " .. item.name or "mount " .. item.name))

    -- Clear all references first
    self.mount = nil
    self.group = nil
    self.family = nil

    if item.isFamily then
        -- This is a family
        self.family = item.name

        if self.Icon and self.Icon:GetNormalTexture() then
            self.Icon:GetNormalTexture():SetDesaturated(false)
            self.Icon:GetNormalTexture():SetVertexColor(1, 1, 1)
        end

        if self.Icon then
            self.Icon:SetNormalTexture("Interface\\Icons\\Ability_Druid_MasterShapeShifter")
            if self.Icon.Count then
                self.Icon.Count:Hide()
            end
        end

        if self.Name then
            self.Name:SetText(item.name)
            self.Name:SetFontObject("GameFontNormalLarge")
            self.Name:SetTextColor(0, 0.7, 1)  -- Blue color for families
        end

-- Get family status AND check mounts for this search
        local familyStatus = LM.GetGroupOrFamilyStatus(false, item.name)
        local mounts = LM.GetMountsFromEntity(false, item.name)
        local hasMatchingMounts = #mounts > 0

        -- Apply visual state based on content and search
        if hasMatchingMounts then
            -- Normal appearance if has matching usable mounts
            if self.Icon and self.Icon:GetNormalTexture() then
                self.Icon:GetNormalTexture():SetDesaturated(false)
                self.Icon:GetNormalTexture():SetVertexColor(1, 1, 1)
            end
            self.Name:SetFontObject("GameFontNormalLarge")
            self.Name:SetTextColor(0, 0.7, 1)  -- Blue color for families
        elseif not hasCollectedMounts then
            -- Gray out if no collected mounts in family
            if self.Icon and self.Icon:GetNormalTexture() then
                self.Icon:GetNormalTexture():SetDesaturated(true)
                self.Icon:GetNormalTexture():SetVertexColor(1, 1, 1)
            end
            self.Name:SetFontObject("GameFontDisableLarge")
        elseif not hasUsableMounts then
            -- Red if has mounts but none are usable
            if self.Icon and self.Icon:GetNormalTexture() then
                self.Icon:GetNormalTexture():SetDesaturated(true)
                self.Icon:GetNormalTexture():SetVertexColor(0.6, 0.2, 0.2)
            end
            self.Name:SetFontObject("GameFontNormalLarge")
        end

        -- Hide mount-specific UI elements safely
        for i = 1, 4 do
            local bit = self["Bit"..i]
            if bit then bit:Hide() end
        end
        if self.Types then self.Types:Hide() end
        if self.Rarity then self.Rarity:Hide() end

        -- Update priority for family safely
        if self.Priority then
            if self.Priority.Update then
                self.Priority:Update()
            end
            self.Priority:Show()
        end
    elseif item.isGroup then
        -- This is a group
        self.group = item.name

        if self.Icon and self.Icon:GetNormalTexture() then
            self.Icon:GetNormalTexture():SetDesaturated(false)
            self.Icon:GetNormalTexture():SetVertexColor(1, 1, 1)
        end

        if self.Icon then
            self.Icon:SetNormalTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
            if self.Icon.Count then
                self.Icon.Count:Hide()
            end
        end

        if self.Name then
            self.Name:SetText(item.name)
            self.Name:SetFontObject("GameFontNormalLarge")
            self.Name:SetTextColor(1, 1, 0)  -- Yellow color for groups
        end

		-- For groups
		local groupStatus = LM.GetGroupOrFamilyStatus(true, item.name)

		if groupStatus.shouldBeGray then
		-- Gray out if all mounts are priority 0
			if self.Icon and self.Icon:GetNormalTexture() then
			self.Icon:GetNormalTexture():SetDesaturated(true)
			self.Icon:GetNormalTexture():SetVertexColor(1, 1, 1)
		end
		self.Name:SetFontObject("GameFontDisableLarge")
		elseif groupStatus.isRed then
		-- Red if has mounts with priority > 0 but none are usable
			if self.Icon and self.Icon:GetNormalTexture() then
			self.Icon:GetNormalTexture():SetDesaturated(true)
			self.Icon:GetNormalTexture():SetVertexColor(0.6, 0.2, 0.2)
		end
		self.Name:SetFontObject("GameFontNormalLarge")
		else
    -- Normal appearance if has usable mounts with priority > 0
    if self.Icon and self.Icon:GetNormalTexture() then
        self.Icon:GetNormalTexture():SetDesaturated(false)
        self.Icon:GetNormalTexture():SetVertexColor(1, 1, 1)
    end
    self.Name:SetFontObject("GameFontNormalLarge")
    self.Name:SetTextColor(1, 1, 0)  -- Yellow color for groups
end

        -- Hide mount-specific UI elements safely
        for i = 1, 4 do
            local bit = self["Bit"..i]
            if bit then bit:Hide() end
        end
        if self.Types then self.Types:Hide() end
        if self.Rarity then self.Rarity:Hide() end

        -- Update priority for group safely
        if self.Priority then
            if self.Priority.Update then
                self.Priority:Update()
            end
            self.Priority:Show()
        end
    else
        -- This is a regular mount
        self.mount = item
        self.Icon:SetNormalTexture(item.icon)
        self.Name:SetText(item.name)
        self.Name:SetFontObject("GameFontNormal")
        self.Name:SetTextColor(1, 1, 1)  -- Reset color

        local count = item:GetSummonCount()
        if count > 0 then
            self.Icon.Count:SetText(count)
            self.Icon.Count:Show()
        else
            self.Icon.Count:Hide()
        end

        if not InCombatLockdown() then
            item:GetCastAction():SetupActionButton(self.Icon, 2)
        end

        -- Update mount-specific UI elements
        local i = 1
        while self["Bit"..i] do
            self["Bit"..i]:Update(bitFlags[i], item)
            i = i + 1
        end

        local flagTexts = { }
        for _, flag in ipairs(LM.Options:GetFlags()) do
            if item.flags[flag] then
                table.insert(flagTexts, L[flag])
            end
        end
        self.Types:SetText(strjoin(' ', unpack(flagTexts)))
        self.Types:Show()

        -- Update mount appearance based on state
        if not item:IsCollected() then
            self.Name:SetFontObject("GameFontDisable")
            self.Icon:GetNormalTexture():SetVertexColor(1, 1, 1)
            self.Icon:GetNormalTexture():SetDesaturated(true)
        elseif not item:IsUsable() then
            self.Name:SetFontObject("GameFontNormal")
            self.Icon:GetNormalTexture():SetDesaturated(true)
            self.Icon:GetNormalTexture():SetVertexColor(0.6, 0.2, 0.2)
        else
            self.Name:SetFontObject("GameFontNormal")
            self.Icon:GetNormalTexture():SetVertexColor(1, 1, 1)
            self.Icon:GetNormalTexture():SetDesaturated(false)
        end

        self.Priority:Update()
    end

    -- Add the new code here
if (self.group or self.family) and not InCombatLockdown() then
    -- Setup secure attributes for groups/families
    local button = self.Icon
    button:SetAttribute("type", "macro")
    button:SetAttribute("macrotext2", "") -- Right click
    button:SetAttribute("macrotext1", "") -- Left click

    -- Handle clicks through OnClick rather than clickHookFunction
    button:SetScript("OnClick", function(self, mouseButton, isDown)
        local parent = self:GetParent()
        
        if mouseButton == "LeftButton" then
            if parent.group then
                LiteMountGroupsPanel.Groups.selectedGroup = parent.group
                Settings.OpenToCategory(LiteMountGroupsPanel.category.ID)
                LiteMountGroupsPanel:Update()
            elseif parent.family then
                LiteMountFamiliesPanel.Families.selectedFamily = parent.family
                Settings.OpenToCategory(LiteMountFamiliesPanel.category.ID)
                LiteMountFamiliesPanel:Update()
            end
        elseif mouseButton == "RightButton" then
            local entityName = parent.group or parent.family
            local isGroup = parent.group ~= nil
            
            local mounts = LM.GetMountsFromEntity(isGroup, entityName)
            
            if #mounts > 0 then
                local style = LM.Options:GetOption('randomWeightStyle')
                local mount = mounts:Random(nil, style)
                
                if mount and mount.mountID then
                    LM.Debug("Summoning " .. mount.name .. " from " .. 
                            (isGroup and "group: " or "family: ") .. entityName)
                    C_MountJournal.SummonByID(mount.mountID)
                    mount:OnSummon()
                end
            else
                LM.Debug("No usable mounts found in " .. 
                        (isGroup and "group: " or "family: ") .. entityName)
            end
        end
    end)
end
end


function LiteMountMountButtonMixin:OnShow()
    local parent = self:GetParent()
    if parent then
        self:SetWidth(parent:GetWidth())
    end
end

--[[------------------------------------------------------------------------]]--

LiteMountMountScrollMixin = {}

-- Because we get attached inside the blizzard options container, we
-- are size 0x0 on create and even after OnShow, we have to trap
-- OnSizeChanged on the scrollframe to make the buttons correctly.
function LiteMountMountScrollMixin:CreateMoreButtons()
    HybridScrollFrame_CreateButtons(self, "LiteMountMountButtonTemplate")
end

function LiteMountMountScrollMixin:OnLoad()
    local track = _G[self.scrollBar:GetName().."Track"]
    track:Hide()
    self.update = self.Update
end

function LiteMountMountScrollMixin:OnSizeChanged()
    self:CreateMoreButtons()
    self:Update()
end

function LiteMountMountScrollMixin:Update()
    if not self.buttons then return end
    if InCombatLockdown() then return end

    local offset = HybridScrollFrame_GetOffset(self)
    local mounts = LM.UIFilter.GetFilteredMountList()

    -- Deduplicate the list
    local seen = {}
    local deduped = {}
    for _, item in ipairs(mounts) do
        local key
        if item.isGroup then
            key = "group:" .. item.name
        elseif item.isFamily then
            key = "family:" .. item.name
        else
            key = "mount:" .. item.spellID
        end
        
        if not seen[key] then
            seen[key] = true
            table.insert(deduped, item)
        else
            LM.Debug("Filtered out duplicate: " .. key)
        end
    end

    -- Use deduped list for display
    for i = 1, #self.buttons do
        local button = self.buttons[i]
        local index = offset + i
        if index <= #deduped then
            button:Update(LiteMountMountsPanel.allFlags, deduped[index])
            button:Show()
            if button.Icon:IsMouseOver() then button.Icon:OnEnter() end
        else
            button:Hide()
        end
    end

    local totalHeight = #deduped * self.buttonHeight
    local shownHeight = self:GetHeight()

    HybridScrollFrame_Update(self, totalHeight, shownHeight)
end

function LiteMountMountScrollMixin:GetOption()
    return {
        LM.tCopyShallow(LM.Options:GetRawFlagChanges()),
        LM.tCopyShallow(LM.Options:GetRawMountPriorities())
    }
end

function LiteMountMountScrollMixin:SetOption(v)
    LM.Options:SetRawFlagChanges(v[1])
    LM.Options:SetRawMountPriorities(v[2])
end

-- The only control: does all the triggered updating for the entire panel
function LiteMountMountScrollMixin:SetControl(v)
    self:GetParent():Update()
end

--[[------------------------------------------------------------------------]]--

LiteMountMountsPanelMixin = {}

function LiteMountMountsPanelMixin:Update()
    LM.UIFilter.ClearCache()
    self.MountScroll:Update()
    self.AllPriority:Update()
end

function LiteMountMountsPanelMixin:OnDefault()
    LM.UIDebug(self, 'Custom_Default')
    self.MountScroll.isDirty = true
    LM.Options:ResetAllMountFlags()
    LM.Options:SetPriorities(LM.MountRegistry.mounts, nil)
end

function LiteMountMountsPanelMixin:OnLoad()

    -- Because we're the wrong size at the moment we'll only have 1 button after
    -- this but that's enough to stop everything crapping out.
    self.MountScroll:CreateMoreButtons()

    self.name = MOUNTS

    self.allFlags = LM.Options:GetFlags()

    for i = 1, 4 do
        local label = self["BitLabel"..i]
        if self.allFlags[i] then
            label:SetText(L[self.allFlags[i]])
        end
    end

    self:SetScript('OnEvent', function () self.MountScroll:Update() end)

    -- We are using the MountScroll SetControl to do ALL the updating.

    LiteMountOptionsPanel_RegisterControl(self.MountScroll)

    LiteMountOptionsPanel_OnLoad(self)
end

function LiteMountMountsPanelMixin:OnShow()
    LiteMountFilter:Attach(self, 'BOTTOMLEFT', self.MountScroll, 'TOPLEFT', 0, 15)
    LM.UIFilter.RegisterCallback(self, "OnFilterChanged", "OnRefresh")
    LM.MountRegistry:RefreshMounts()
    LM.MountRegistry:UpdateFilterUsability()
    LM.MountRegistry.RegisterCallback(self, "OnMountSummoned", "OnRefresh")

    -- Update the counts, Journal-only
    local counts = LM.MountRegistry:GetJournalTotals()
    self.Counts:SetText(
            string.format(
                '%s: %s %s: %s %s: %s',
                TOTAL,
                WHITE_FONT_COLOR:WrapTextInColorCode(counts.total),
                COLLECTED,
                WHITE_FONT_COLOR:WrapTextInColorCode(counts.collected),
                L.LM_USABLE,
                WHITE_FONT_COLOR:WrapTextInColorCode(counts.usable)
            )
        )

    self:RegisterEvent('MOUNT_JOURNAL_USABILITY_CHANGED')

    LiteMountOptionsPanel_OnShow(self)
end

function LiteMountMountsPanelMixin:OnHide()
    LM.UIFilter.UnregisterAllCallbacks(self)
    LM.MountRegistry.UnregisterAllCallbacks(self)
    self:UnregisterAllEvents()
    LiteMountOptionsPanel_OnHide(self)
end

--[[------------------------------------------------------------------------]]--
function LM.GetUsableMountsFromFamily(familyName)
    local mounts = LM.MountList:New()
    local filtertext = LM.UIFilter.GetSearchText()
    local isSearching = filtertext and filtertext ~= SEARCH and filtertext ~= ""

    for _, mount in ipairs(LM.MountRegistry.mounts) do
        -- Only include collected, usable mounts with priority > 0
        if mount:IsCollected() and mount:IsUsable() and mount:GetPriority() > 0 and
           LM.Options:IsMountInFamily(mount, familyName) then

            -- Check if mount matches search if searching
            local matchesSearch = true
            if isSearching then
                matchesSearch = strfind(mount.name:lower(), filtertext:lower(), 1, true)
            end

            if matchesSearch then
                table.insert(mounts, mount)
            end
        end
    end

    return mounts
end

--[[------------------------------------------------------------------------]]--
-- End of LiteMount/UI/Mounts.lua
