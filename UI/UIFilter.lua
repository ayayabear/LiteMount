--[[----------------------------------------------------------------------------

  LiteMount/UI/UIFilter.lua

  UI Filter state abstracted out similar to how C_MountJournal does it

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...
LM.UIFilter = LM.UIFilter or {} 

local L = LM.Localize

local DefaultFilterList = {
    family = { },
    familygroup = { },  -- Add this new filter type with empty default
    flag = { },
    group = { },
    other = { HIDDEN=true, UNUSABLE=true },
    priority = { },
    source = { },
    typename = { }
}


-- Pre-populate the familygroup filters to hide all by default
for _, familyName in ipairs(LM.Options:GetFamilyNames()) do
    DefaultFilterList.familygroup[familyName] = true  -- true means filtered (hidden)
end

LM.UIFilter = {
        filteredMountList = LM.MountList:New(),
        searchText = nil,
        sortKey = 'default',
        filterList = CopyTable(DefaultFilterList),
        typeNamesInUse = {},
    }

function LM.UIFilter.StripCodes(str)
    if not str then return "" end
    return str:gsub("|c........(.-)|r", "%1"):gsub("|T.-|t", "")
end

function LM.UIFilter.SearchMatch(src, text)
    if not src or not text then return false end
    src = src:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
    text = text:lower()
    return src:find(text, 1, true) ~= nil
end

local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0", true)
local callbacks = CallbackHandler:New(LM.UIFilter)

local PriorityColors = {
    [''] = COMMON_GRAY_COLOR,
    [0] =  RED_FONT_COLOR,
    [1] =  UNCOMMON_GREEN_COLOR,
    [2] =  RARE_BLUE_COLOR,
    [3] =  EPIC_PURPLE_COLOR,
    [4] =  LEGENDARY_ORANGE_COLOR,
}

local function searchMatch(src, text)
    src = src:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
    text = text:lower()
    return src:find(text, 1, true) ~= nil
end

-- Clear -----------------------------------------------------------------------

function LM.UIFilter.Clear()
    LM.UIFilter.ClearCache()
    LM.UIFilter.filterList = CopyTable(DefaultFilterList)
    LM.UIFilter.searchText = ""
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.IsFiltered()
    return not tCompare(LM.UIFilter.filterList, DefaultFilterList, 2)
end

-- Sorting ---------------------------------------------------------------------

local SortKeysByProject = LM.TableWithDefault({
    [1] = {
        'default',
        'name',
        'rarity',
        'summons'
    },
    DEFAULT = {
        'default',
        'name',
        'summons'
    },
})

local SortKeyTexts = {
    ['default']     = DEFAULT,
    ['name']        = NAME,
    ['rarity']      = RARITY,
    ['summons']     = SUMMONS,
}

function LM.UIFilter.GetSortKey()
    return LM.UIFilter.sortKey
end

function LM.UIFilter.SetSortKey(k)
    LM.Debug("SetSortKey called with: " .. tostring(k))
    if LM.UIFilter.sortKey == k then
        LM.Debug("Sort key unchanged")
        return
    else
        LM.UIFilter.sortKey = (k or 'default')
        LM.UIFilter.ClearCache()
        LM.Debug("Sort key set to: " .. LM.UIFilter.sortKey)
        callbacks:Fire('OnFilterChanged')
    end
end

function LM.UIFilter.GetSortKeys()
    return SortKeysByProject[WOW_PROJECT_ID]
end

function LM.UIFilter.GetSortKeyText(k)
    return SortKeyTexts[k] or UNKNOWN
end

function LM.UIFilter.GetFilteredMountList()
   -- LM.Debug("GetFilteredMountList called")
    
    -- CRITICAL CHANGE: Always clear cache when getting filtered mount list
    -- This ensures we always have fresh data after group/family operations
    LM.UIFilter.ClearCache()
    
    -- Initialize if nil
    if not LM.UIFilter.filteredMountList then
        LM.UIFilter.filteredMountList = {}
    end
    
    -- Force cache update every time
  --  LM.Debug("Updating mount list cache")
    LM.UIFilter.UpdateCache()
    
    --LM.Debug("Filtered list has " .. #LM.UIFilter.filteredMountList .. " items")
    return LM.UIFilter.filteredMountList
end

-- Fetch -----------------------------------------------------------------------

function LM.UIFilter.UpdateCache()
    --LM.Debug("Starting UpdateCache")
    
    -- Initialize if nil
    if not LM.UIFilter.filteredMountList then
        LM.UIFilter.filteredMountList = {}
    else
        table.wipe(LM.UIFilter.filteredMountList)
    end
    
    -- Get all regular mounts
    local mountList = {}
    for _, mount in ipairs(LM.MountRegistry.mounts) do
        table.insert(mountList, mount)
    end
    
    -- Always add fresh groups - regardless of cache
    for _, groupName in ipairs(LM.Options:GetGroupNames()) do
        if groupName and groupName ~= "" then
            local groupItem = {
                name = groupName,
                isGroup = true,
            }
            table.insert(mountList, groupItem)
        end
    end
    
    -- Add fresh families
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        for _, familyName in ipairs(LM.Options:GetFamilyNames()) do
            if familyName and familyName ~= "" then
                local familyItem = {
                    name = familyName,
                    isFamily = true,
                }
                table.insert(mountList, familyItem)
            end
        end
    end
    
    -- Filter items
    local filteredList = LM.MountList:New()
    for _, item in ipairs(mountList) do
        if not LM.UIFilter.IsFilteredMount(item) then
            table.insert(filteredList, item)
        end
    end
    
    -- Sort the filtered list
    --LM.Debug("Sorting filtered list by: " .. tostring(LM.UIFilter.GetSortKey()))
    filteredList:Sort(LM.UIFilter.GetSortKey())
    
    -- Store the result
    LM.UIFilter.filteredMountList = filteredList
    
    --LM.Debug("FilteredMountList now has " .. #LM.UIFilter.filteredMountList .. " items")
end

function LM.UIFilter.ClearCache()
    if LM.UIFilter.filteredMountList then
        table.wipe(LM.UIFilter.filteredMountList)
    else
        LM.UIFilter.filteredMountList = {}
    end
end

function LM.UIFilter.InvalidateCache()
    LM.Debug("Forcibly invalidating UIFilter cache")
    LM.UIFilter.filteredMountList = nil
end

-- Sources ---------------------------------------------------------------------

function LM.UIFilter.GetSources()
    local out = {}
    for i = 1, LM.UIFilter.GetNumSources() do
        if LM.UIFilter.IsValidSourceFilter(i) then
            out[#out+1] = i
        end
    end
    return out
end

function LM.UIFilter.GetNumSources()
    return C_PetJournal.GetNumPetSources() + 1
end

function LM.UIFilter.SetAllSourceFilters(v)
    LM.UIFilter.ClearCache()
    if v then
        table.wipe(LM.UIFilter.filterList.source)
    else
        for i = 1,LM.UIFilter.GetNumSources() do
            if LM.UIFilter.IsValidSourceFilter(i) then
                LM.UIFilter.filterList.source[i] = true
            end
        end
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.SetSourceFilter(i, v)
    LM.UIFilter.ClearCache()
    if v then
        LM.UIFilter.filterList.source[i] = nil
    else
        LM.UIFilter.filterList.source[i] = true
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.IsSourceChecked(i)
    return not LM.UIFilter.filterList.source[i]
end

function LM.UIFilter.IsValidSourceFilter(i)
    -- Mounts have an extra filter "OTHER" that pets don't have
    if C_MountJournal.IsValidSourceFilter(i) then
        return true
    elseif i == C_PetJournal.GetNumPetSources() + 1 then
        return true
    else
        return false
    end
end

function LM.UIFilter.GetSourceText(i)
    local n = C_PetJournal.GetNumPetSources()
    if i <= n then
        return _G["BATTLE_PET_SOURCE_"..i]
    elseif i == n+1 then
        return OTHER
    end
end


-- Families --------------------------------------------------------------------

function LM.UIFilter.GetFamilies()
    local out = {}
    for k in pairs(LM.MOUNTFAMILY) do
        table.insert(out, k)
    end
    table.sort(out, function (a, b) return L[a] < L[b] end)
    return out
end

function LM.UIFilter.SetAllFamilyFilters(v)
    LM.UIFilter.ClearCache()
    if v then
        table.wipe(LM.UIFilter.filterList.family)
    else
        for k in pairs(LM.MOUNTFAMILY) do
            LM.UIFilter.filterList.family[k] = true
        end
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.SetFamilyFilter(i, v)
    LM.UIFilter.ClearCache()
    if v then
        LM.UIFilter.filterList.family[i] = nil
    else
        LM.UIFilter.filterList.family[i] = true
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.IsFamilyChecked(i)
    return not LM.UIFilter.filterList.family[i]
end

function LM.UIFilter.IsValidFamilyFilter(i)
    return LM.MOUNTFAMILY[i] ~= nil
end

function LM.UIFilter.GetFamilyText(i)
    return L[i]
end

-- Family Groups ---------------------------------------------------------------

function LM.UIFilter.GetFamilyGroups()
    local out = {}
    for k in pairs(LM.MOUNTFAMILY) do
        table.insert(out, k)
    end
    table.sort(out, function (a, b) return L[a] < L[b] end)
    return out
end

function LM.UIFilter.SetAllFamilyGroupFilters(v)
    LM.UIFilter.ClearCache()
    if v then
        -- When checking all, clear the filter to show all
        table.wipe(LM.UIFilter.filterList.familygroup)
    else
        -- When unchecking all, add all to filter to hide all
        for _, familyName in ipairs(LM.UIFilter.GetFamilyGroups()) do
            LM.UIFilter.filterList.familygroup[familyName] = true
        end
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.SetFamilyGroupFilter(i, v)
    LM.UIFilter.ClearCache()
    if v then
        -- When checked (v is true), remove from filter to show
        LM.UIFilter.filterList.familygroup[i] = nil
    else
        -- When unchecked (v is false), add to filter to hide
        LM.UIFilter.filterList.familygroup[i] = true
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.IsFamilyGroupChecked(i)
    return not LM.UIFilter.filterList.familygroup[i]  -- Return true if NOT filtered
end

function LM.UIFilter.IsValidFamilyGroupFilter(i)
    return LM.MOUNTFAMILY[i] ~= nil
end

function LM.UIFilter.GetFamilyGroupText(i)
    return L[i] or i
end

-- TypeNames -------------------------------------------------------------------

function LM.UIFilter.IsTypeNameChecked(t)
    return not LM.UIFilter.filterList.typename[t]
end

function LM.UIFilter.SetTypeNameFilter(t, v)
    LM.UIFilter.ClearCache()
    if v then
        LM.UIFilter.filterList.typename[t] = nil
    else
        LM.UIFilter.filterList.typename[t] = true
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.SetAllTypeNameFilters(v)
    LM.UIFilter.ClearCache()
    for n in pairs(LM.MOUNT_TYPE_NAMES) do
        if v then
            LM.UIFilter.filterList.typename[n] = nil
        else
            LM.UIFilter.filterList.typename[n] = true
        end
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.GetTypeNames()
    local out = {}
    for t in pairs(LM.MOUNT_TYPE_NAMES) do
        if LM.UIFilter.typeNamesInUse[t] then
            table.insert(out, t)
        end
    end
    sort(out)
    return out
end

function LM.UIFilter.GetTypeNameText(t)
    return t
end

function LM.UIFilter.RegisterUsedTypeID(id)
    local typeInfo = LM.MOUNT_TYPE_INFO[id]
    if typeInfo then
        LM.UIFilter.typeNamesInUse[typeInfo.name] = true
    end
end


-- Flags ("Type" now) ----------------------------------------------------------

function LM.UIFilter.IsFlagChecked(f)
    return not LM.UIFilter.filterList.flag[f]
end

function LM.UIFilter.SetFlagFilter(f, v)
    LM.UIFilter.ClearCache()
    if v then
        LM.UIFilter.filterList.flag[f] = nil
    else
        LM.UIFilter.filterList.flag[f] = true
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.SetAllFlagFilters(v)
    LM.UIFilter.ClearCache()
    for _,f in ipairs(LM.UIFilter.GetFlags()) do
        if v then
            LM.UIFilter.filterList.flag[f] = nil
        else
            LM.UIFilter.filterList.flag[f] = true
        end
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.GetFlags()
    return LM.Options:GetFlags()
end

function LM.UIFilter.GetFlagText(f)
    -- "FAVORITES -> _G.FAVORITES
    return L[f] or f
end


-- Groups ----------------------------------------------------------------------

function LM.UIFilter.SetGroupFilter(g, v)
    LM.Debug("Setting group filter: " .. g .. " = " .. tostring(v))
    LM.UIFilter.ClearCache()
    if v then
        LM.UIFilter.filterList.group[g] = nil
    else
        LM.UIFilter.filterList.group[g] = true
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.IsGroupChecked(g)
    return not LM.UIFilter.filterList.group[g]
end

function LM.UIFilter.SetAllGroupFilters(v)
    LM.UIFilter.ClearCache()
    if v then
        table.wipe(LM.UIFilter.filterList.group)
    else
        -- Get all groups
        for _, groupName in ipairs(LM.Options:GetGroupNames()) do
            LM.UIFilter.filterList.group[groupName] = true
        end
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.GetGroups()
    local groups = LM.Options:GetGroupNames()
    table.sort(groups)  -- Sort alphabetically
    return groups  -- No longer adding NONE
end

function LM.UIFilter.GetGroupText(f)
    if f == NONE then
        return f:upper()
    else
        return f
    end
end

-- Priorities ------------------------------------------------------------------

function LM.UIFilter.IsPriorityChecked(p)
    return not LM.UIFilter.filterList.priority[p]
end

function LM.UIFilter.SetPriorityFilter(p, v)
    LM.UIFilter.ClearCache()
    if v then
        LM.UIFilter.filterList.priority[p] = nil
    else
        LM.UIFilter.filterList.priority[p] = true
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.SetAllPriorityFilters(v)
    LM.UIFilter.ClearCache()
    if v then
        table.wipe(LM.UIFilter.filterList.priority)
    else
        for _,p in ipairs(LM.UIFilter.GetPriorities()) do
            LM.UIFilter.filterList.priority[p] = true
        end
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.GetPriorities()
    return LM.Options:GetAllPriorities()
end

function LM.UIFilter.GetPriorityColor(p)
    return PriorityColors[p] or PriorityColors['']
end

function LM.UIFilter.GetPriorityText(p)
    local c = PriorityColors[p] or PriorityColors['']
    return c:WrapTextInColorCode(p),
           c:WrapTextInColorCode(L['LM_PRIORITY_DESC'..p])
end


-- Rarities --------------------------------------------------------------------

-- 0 <= r <= 1

function LM.UIFilter.GetRarityColor(r)
    r = r or 50
    if r <= 1 then
        return PriorityColors[4]
    elseif r <= 5 then
        return PriorityColors[3]
    elseif r <= 20 then
        return PriorityColors[2]
    elseif r <= 50 then
        return PriorityColors[1]
    else
        return PriorityColors['']
    end
end

-- Other -----------------------------------------------------------------------

function LM.UIFilter.IsOtherChecked(k)
    return not LM.UIFilter.filterList.other[k]
end

function LM.UIFilter.SetOtherFilter(k, v)
    LM.UIFilter.ClearCache()
    if v then
        LM.UIFilter.filterList.other[k] = nil
    else
        LM.UIFilter.filterList.other[k] = true
    end
    callbacks:Fire('OnFilterChanged')
end

-- Search ----------------------------------------------------------------------

function LM.UIFilter.SetSearchText(t)
    LM.UIFilter.ClearCache()
    LM.UIFilter.searchText = t
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.GetSearchText(t)
    return LM.UIFilter.searchText
end


-- Check -----------------------------------------------------------------------

local function stripcodes(str)
    return str:gsub("|c........(.-)|r", "%1"):gsub("|T.-|t", "")
end

--[[----------------------------------------------------------------------------
  Fix for type checkboxes with groups/families
  Add this to IsFilteredMount in MountsFilter.lua where it handles groups/families
----------------------------------------------------------------------------]]--

function LM.UIFilter.IsFilteredMount(m)
    if not m then return true end

    local filtertext = LM.UIFilter.GetSearchText()
    local isSearching = filtertext and filtertext ~= SEARCH and filtertext ~= ""

    -- Check if any type filter is unchecked
    local anyTypeUnchecked = false
    for i = 1, Enum.MountTypeMeta.NumValues do
        if C_MountJournal.IsValidTypeFilter(i) and not C_MountJournal.IsTypeChecked(i) then
            anyTypeUnchecked = true
            break
        end
    end

-- Groups and Families filtering
if m.isGroup or m.isFamily then
    -- Group/Family checkbox filters
    if m.isGroup and LM.UIFilter.filterList.group[m.name] then
        return true
    elseif m.isFamily and LM.UIFilter.filterList.familygroup[m.name] then
        return true
    end

    -- Search text filter
    if isSearching then
        local matchesSearch = strfind(m.name:lower(), filtertext:lower(), 1, true)
        if not matchesSearch then
            return true
        end
    end
    
    -- Handle Priority filter for groups/families - based on their own priority
    if next(LM.UIFilter.filterList.priority) then
        if m.isGroup then
            local groupPriority = LM.Options:GetGroupPriority(m.name)
            for _, p in ipairs(LM.UIFilter.GetPriorities()) do
                if LM.UIFilter.filterList.priority[p] and groupPriority == p then
                    return true
                end
            end
        elseif m.isFamily then
            local familyPriority = LM.Options:GetFamilyPriority(m.name)
            for _, p in ipairs(LM.UIFilter.GetPriorities()) do
                if LM.UIFilter.filterList.priority[p] and familyPriority == p then
                    return true
                end
            end
        end
    end
    
    -- Always check if the group/family has ANY usable mounts for the player's class and faction
    local hasAnyUsableMounts = false
    local entityName = m.name
    local isGroup = m.isGroup
    
    for _, mount in ipairs(LM.MountRegistry.mounts) do
        local isInEntity = false
        if isGroup then
            isInEntity = LM.Options:IsMountInGroup(mount, entityName)
        else
            isInEntity = LM.Options:IsMountInFamily(mount, entityName)
        end
        
        if isInEntity and mount:IsCollected() and mount:GetPriority() > 0 then
            -- Check if mount is usable by the player's class
            if mount:IsUsable() then
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
                
                if isRightFaction then
                    hasAnyUsableMounts = true
                    break
                end
            end
        end
    end
    
    -- Hide the group/family if it doesn't have ANY usable mounts,
    -- UNLESS the "Unusable" filter is unchecked (which means show unusable items)
    if not hasAnyUsableMounts and LM.UIFilter.filterList.other.UNUSABLE then
        return true
    end
    
    -- Check for active type filters
    local hasTypeFilters = next(LM.UIFilter.filterList.flag) ~= nil
    local hasTypeNameFilters = next(LM.UIFilter.filterList.typename) ~= nil
    local hasSourceFilters = next(LM.UIFilter.filterList.source) ~= nil
    
    -- If any of these filters are active, we need to check the mounts in the group/family
    if hasTypeFilters or hasTypeNameFilters or hasSourceFilters then
        local hasMountsThatPassFilters = false
        
        for _, mount in ipairs(LM.MountRegistry.mounts) do
            local isInEntity = false
            if isGroup then
                isInEntity = LM.Options:IsMountInGroup(mount, entityName)
            else
                isInEntity = LM.Options:IsMountInFamily(mount, entityName)
            end
            
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
                
                -- Skip mounts that aren't available to the player's faction
                if not isRightFaction then 
                    -- Just continue to the next mount
                else
                    local passesAllFilters = true
                    
                    -- Check if mount passes type filters
                    if hasTypeFilters then
                        local passesTypeFilter = false
                        local mountFlags = mount:GetFlags()
                        for flagName in pairs(mountFlags) do
                            if LM.FLAG[flagName] and not LM.UIFilter.filterList.flag[flagName] then
                                passesTypeFilter = true
                                break
                            end
                        end
                        if not passesTypeFilter then
                            passesAllFilters = false
                        end
                    end
                    
                    -- Check if mount passes typename (Type ID) filters
                    if passesAllFilters and hasTypeNameFilters then
                        local typeInfo = LM.MOUNT_TYPE_INFO[mount.mountTypeID or 0]
                        if typeInfo and LM.UIFilter.filterList.typename[typeInfo.name] then
                            passesAllFilters = false
                        end
                    end
                    
                    -- Check if mount passes source filters
                    if passesAllFilters and hasSourceFilters then
                        local source = mount.sourceType or LM.UIFilter.GetNumSources()
                        if LM.UIFilter.filterList.source[source] then
                            passesAllFilters = false
                        end
                    end
                    
                    -- If the mount passed all filters, mark the group/family as having usable mounts
                    if passesAllFilters then
                        hasMountsThatPassFilters = true
                        break
                    end
                end
            end
        end
        
        -- Hide the group/family if it doesn't have any mounts that pass the active filters,
        -- UNLESS the "Unusable" filter is unchecked (which means show unusable items)
        if not hasMountsThatPassFilters and LM.UIFilter.filterList.other.UNUSABLE then
            return true
        end
    end

    return false
end

    -- Regular mount filtering
    -- Group filter should not hide individual mounts
    if m.GetGroups then
        local mountGroups = m:GetGroups()
        if next(mountGroups) then
            for g in pairs(mountGroups) do
                if LM.UIFilter.filterList.group[g] then
                    -- If group is filtered, do NOT hide the mount
                    break
                end
            end
        end
    end

    -- Existing filters for individual mounts
    if m.IsCollected and LM.UIFilter.filterList.other.COLLECTED and m:IsCollected() then
        return true
    end

    if m.IsCollected and LM.UIFilter.filterList.other.NOT_COLLECTED and not m:IsCollected() then
        return true
    end

    if m.IsHidden and LM.UIFilter.filterList.other.HIDDEN and m:IsHidden() then
        return true
    end

    if LM.UIFilter.filterList.other.UNUSABLE then
        if m.IsHidden and m.IsFilterUsable and not m:IsHidden() and not m:IsFilterUsable() then
            return true
        end
    end

    local typeInfo = LM.MOUNT_TYPE_INFO[m.mountTypeID or 0]
    if typeInfo and LM.UIFilter.filterList.typename[typeInfo.name] then
        return true
    end

    if next(LM.UIFilter.filterList.source) then
        local source = m.sourceType or LM.UIFilter.GetNumSources()
        if LM.UIFilter.filterList.source[source] then
            return true
        end
    end

    if m.GetPriority then
        for _, p in ipairs(LM.UIFilter.GetPriorities()) do
            if LM.UIFilter.filterList.priority[p] and m:GetPriority() == p then
                return true
            end
        end
    end

    if m.GetFlags and next(LM.UIFilter.filterList.flag) then
        local isFiltered = true
        for f in pairs(m:GetFlags()) do
            if LM.FLAG[f] ~= nil and not LM.UIFilter.filterList.flag[f] then
                isFiltered = false
                break
            end
        end
        if isFiltered then return true end
    end

    -- Search matching
    if isSearching then
        if filtertext == "=" and m.name then
            local hasAura = AuraUtil.FindAuraByName(m.name, "player")
            return hasAura == nil
        end

        if m.name and not strfind(m.name:lower(), filtertext:lower(), 1, true) then
            if not (m.description and LM.UIFilter.SearchMatch(m.description, filtertext)) and
               not (m.sourceText and LM.UIFilter.SearchMatch(LM.UIFilter.StripCodes(m.sourceText), filtertext)) then
                return true
            end
        end
    end

    return false
end
