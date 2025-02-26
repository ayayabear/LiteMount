--[[----------------------------------------------------------------------------

  LiteMount/UI/Mounts.lua

  Options frame for the mount list.

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...

local C_Spell = LM.C_Spell or C_Spell

local L = LM.Localize

if LM.db and LM.db.callbacks then
    -- Save the original Fire method
    LM.db.callbacks.orig_Fire = LM.db.callbacks.Fire
    
    -- Replace with our own that ensures mount list updates
    LM.db.callbacks.Fire = function(self, event, ...)
        -- Call the original method
        self:orig_Fire(event, ...)
        
        -- If this was an options modified event, update the mount list
        if event == "OnOptionsModified" then
            if LiteMountMountsPanel and LiteMountMountsPanel.Update then
                LiteMountMountsPanel:Update()
            end
        end
    end
end


--[[----------------------------------------------------------------------------
  Priority Management Mixins
----------------------------------------------------------------------------]]--

LiteMountPriorityMixin = {}

-- Update priority display
function LiteMountPriorityMixin:Update()
    local parent = self:GetParent()
    local value

    -- Get priority value based on item type
    if parent.mount then
        value = parent.mount:GetPriority()
    elseif parent.group then
        value = LM.Options:GetGroupPriority(parent.group)
    elseif parent.family then
        value = LM.Options:GetFamilyPriority(parent.family)
    elseif self.family then
        value = LM.Options:GetFamilyPriority(self.family)
    end

    -- Update UI elements
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

    -- Set background color based on priority
    if LM.Options:GetOption('randomWeightStyle') == 'Priority' or value == 0 then
        local r, g, b = LM.UIFilter.GetPriorityColor(value):GetRGB()
        self.Background:SetColorTexture(r, g, b, 0.33)
    else
        local r, g, b = LM.UIFilter.GetPriorityColor(''):GetRGB()
        self.Background:SetColorTexture(r, g, b, 0.33)
    end
end

-- Get priority value
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

-- Set priority value
function LiteMountPriorityMixin:Set(v)
    local parent = self:GetParent()
    
    if parent.mount then
        LM.Options:SetPriority(parent.mount, v or LM.Options.DEFAULT_PRIORITY)
    elseif parent.group then
        LM.Options:SetGroupPriority(parent.group, v or LM.Options.DEFAULT_PRIORITY)
    elseif parent.family then
        LM.Options:SetFamilyPriority(parent.family, v or LM.Options.DEFAULT_PRIORITY)
    elseif self.family then
        LM.Options:SetFamilyPriority(self.family, v or LM.Options.DEFAULT_PRIORITY)
    end
    
    self:Update()
end

-- Increment priority
function LiteMountPriorityMixin:Increment()
    local v = self:Get()
    
    if v then
        self:Set(v + 1)
    else
        self:Set(LM.Options.DEFAULT_PRIORITY)
    end
end

-- Decrement priority
function LiteMountPriorityMixin:Decrement()
    local v = self:Get() or LM.Options.DEFAULT_PRIORITY
    self:Set(v - 1)
end

-- Tooltip handling
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

--[[----------------------------------------------------------------------------
  All Priority Control Mixin
----------------------------------------------------------------------------]]--

LiteMountAllPriorityMixin = {}

-- Set priority for all shown items
function LiteMountAllPriorityMixin:Set(v)
    -- Get all visible items
    local items = LM.UIFilter.GetFilteredMountList()
    
    -- Validate priority value
    if v then
        v = math.max(LM.Options.MIN_PRIORITY, math.min(LM.Options.MAX_PRIORITY, v))
    end

    -- Set priority for each item
    for _, item in ipairs(items) do
        if item.isGroup then
            LM.db.profile.groupPriorities[item.name] = v
        elseif item.isFamily then
            if not LM.db.profile.familyPriorities then
                LM.db.profile.familyPriorities = {}
            end
            LM.db.profile.familyPriorities[item.name] = v
        else
            LM.db.profile.mountPriorities[item.spellID] = v
        end
    end
    
    -- Fire callback to update UI
    LM.db.callbacks:Fire("OnOptionsModified")
end

-- Get priority if all items have the same priority
function LiteMountAllPriorityMixin:Get()
    local items = LM.UIFilter.GetFilteredMountList()
    local allValue

    -- Check if all items have the same priority
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

-- Increment all priorities
function LiteMountAllPriorityMixin:Increment()
    local v = self:Get()
    if v then
        self:Set(v + 1)
    else
        self:Set(LM.Options.DEFAULT_PRIORITY)
    end
end

-- Decrement all priorities
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

-- Mount tooltip handling
function LiteMountMountIconMixin:OnEnter()
    local parent = self:GetParent()
    local item = parent.mount or parent.group or parent.family
    if not item then return end

    if parent.family or (type(item) == "table" and item.isFamily) then
        -- Family tooltip
        local familyName = type(item) == "string" and item or item.name
        local familyStatus = LM.GetEntityStatus(false, familyName)
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
        
        -- Display family tooltip
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
        -- Group tooltip
        local groupName = type(item) == "string" and item or item.name
        local groupStatus = LM.GetEntityStatus(true, groupName)
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
        
        -- Display group tooltip
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

-- Mount icon click handling
function LiteMountMountIconMixin:OnLoad()
    self:SetAttribute("unit", "player")
    self:RegisterForClicks("AnyUp")
    self:RegisterForDrag("LeftButton")
    
    -- Click handler
    self:SetScript("OnClick", function(iconSelf, button)
        local parent = iconSelf:GetParent()
        if not parent then return end
        
        -- Handle left-click navigation
        if button == "LeftButton" then
            if parent.group then
                LiteMountGroupsPanel.Groups.selectedGroup = parent.group
                Settings.OpenToCategory(LiteMountGroupsPanel.category.ID)
                LiteMountGroupsPanel:Update()
            elseif parent.family then
                LiteMountFamiliesPanel.Families.selectedFamily = parent.family
                Settings.OpenToCategory(LiteMountFamiliesPanel.category.ID)
                LiteMountFamiliesPanel:Update()
            elseif parent.mount and parent.mount.spellID then
                -- For regular mounts, allow chat linking or spell pickup
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
            if parent.mount and parent.mount.mountID then
                -- Direct mount summoning
                C_MountJournal.SummonByID(parent.mount.mountID)
                parent.mount:OnSummon()
            elseif parent.group or parent.family then
                local entityName = parent.group or parent.family
                local isGroup = parent.group ~= nil
                
                if entityName then
                    -- Check if player is mounted and dismount first
                    if IsMounted() then
                        Dismount()
                        return
                    end
                    
                    -- Set the prevention flag before summoning
                    LM.preventDoubleCounting = true
                    
                    -- Using the unified function
                    LM.DirectlySummonRandomMountFromEntity(isGroup, entityName)
                    
                    -- Clear the prevention flag
                    LM.preventDoubleCounting = false
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

--[[------------------------------------------------------------------------]]--

LiteMountMountButtonMixin = {}

LiteMountMountButtonMixin = {}

-- Continuation of LiteMountMountButtonMixin:Update function
function LiteMountMountButtonMixin:Update(bitFlags, item)
    -- Clear all references first
    self.mount = nil
    self.group = nil
    self.family = nil

    if item.isFamily then
        -- Handle family
        self.family = item.name

        -- Setup icon
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

        -- Get family status
        local familyStatus = LM.GetEntityStatus(false, item.name)
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
        elseif familyStatus.shouldBeGray then
            -- Gray out if all mounts have priority 0 or none collected
            if self.Icon and self.Icon:GetNormalTexture() then
                self.Icon:GetNormalTexture():SetDesaturated(true)
                self.Icon:GetNormalTexture():SetVertexColor(1, 1, 1)
            end
            self.Name:SetFontObject("GameFontDisableLarge")
        elseif familyStatus.isRed then
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
        -- Handle group
        self.group = item.name

        -- Setup icon
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

        -- Get group status
        local groupStatus = LM.GetEntityStatus(true, item.name)

        -- Apply visual state based on content and search
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
        -- Handle regular mount
        self.mount = item
        self.Icon:SetNormalTexture(item.icon)
        self.Name:SetText(item.name)
        self.Name:SetFontObject("GameFontNormal")
        self.Name:SetTextColor(1, 1, 1)  -- Reset color

        -- Show summon count
        local count = item:GetSummonCount()
        if count > 0 then
            self.Icon.Count:SetText(count)
            self.Icon.Count:Show()
        else
            self.Icon.Count:Hide()
        end

        -- Set up action button if not in combat
        if not InCombatLockdown() then
            item:GetCastAction():SetupActionButton(self.Icon, 2)
        end

        -- Update mount-specific UI elements
        local i = 1
        while self["Bit"..i] do
            self["Bit"..i]:Update(bitFlags[i], item)
            i = i + 1
        end

        -- Update flags display
        local flagTexts = {}
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

    -- Setup secure button functionality after updating UI
    if not InCombatLockdown() then
        local button = self.Icon
        
        -- Set up appropriate attributes for secure button functionality
        button:SetAttribute("type", nil)

        if self.mount then
            -- For the secure button to work correctly for individual mounts
            self.mount:GetCastAction():SetupActionButton(button, 2)
        else
            -- For groups and families
            button:SetAttribute("type", "macro")
            button:SetAttribute("macrotext2", "")
            button:SetAttribute("macrotext1", "")
        end
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
    if LM.UIFilter then
        LM.UIFilter.ClearCache()
    end
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
LM.db.RegisterCallback(self, "OnOptionsModified", "OnRefresh") 
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
