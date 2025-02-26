--[[----------------------------------------------------------------------------

  LiteMount/UI/UIFilter.lua

  UI Filter state abstracted out similar to how C_MountJournal does it

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...
LM.UIFilter = LM.UIFilter or {} 

-- Ensure typeNamesInUse exists immediately to avoid nil errors during initialization
LM.UIFilter.typeNamesInUse = LM.UIFilter.typeNamesInUse or {}

-- Populate Family Group Defaults early
local function PopulateFamilyGroupDefaults(filterList)
    if LM.MOUNTFAMILY then
        for familyName in pairs(LM.MOUNTFAMILY) do
            filterList.familygroup[familyName] = true  -- true means filtered (hidden)
        end
    end
end

LM.UIFilter.filterList = LM.UIFilter.filterList or {
    family = { },
    familygroup = { },
    flag = { },
    group = { },
    other = { HIDDEN=true, UNUSABLE=true },
    priority = { },
    source = { },
    typename = { }
}

-- Populate family group defaults during initial setup
PopulateFamilyGroupDefaults(LM.UIFilter.filterList)

-- Add this function early so it's always available
function LM.UIFilter.RegisterUsedTypeID(id)
    local typeInfo = LM.MOUNT_TYPE_INFO and LM.MOUNT_TYPE_INFO[id]
    if typeInfo then
        LM.UIFilter.typeNamesInUse[typeInfo.name] = true
    end
end

-- Initialize callback handler if it doesn't exist
if not LM.UIFilter.callbacks then
    local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0", true)
    if CallbackHandler then
        LM.UIFilter.callbacks = CallbackHandler:New(LM.UIFilter)
    else
        -- Fallback stub implementation if we can't get CallbackHandler
        LM.UIFilter.callbacks = {
            Fire = function() end,
            RegisterCallback = function() end,
            UnregisterCallback = function() end,
            UnregisterAllCallbacks = function() end
        }
    end
end

local L = LM.Localize

-- Default filter settings
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

-- Populate family group defaults
PopulateFamilyGroupDefaults(DefaultFilterList)

-- Priority colors for UI display
local PriorityColors = {
    [''] = COMMON_GRAY_COLOR,
    [0] =  RED_FONT_COLOR,
    [1] =  UNCOMMON_GREEN_COLOR,
    [2] =  RARE_BLUE_COLOR,
    [3] =  EPIC_PURPLE_COLOR,
    [4] =  LEGENDARY_ORANGE_COLOR,
}

-- Sort key options by project
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

-- Sort key text labels
local SortKeyTexts = {
    ['default']     = DEFAULT,
    ['name']        = NAME,
    ['rarity']      = RARITY,
    ['summons']     = SUMMONS,
}

--[[----------------------------------------------------------------------------
  Initialization and Core Functions
----------------------------------------------------------------------------]]--

-- Initialize the UIFilter module
function LM.UIFilter.Initialize()
    -- Pre-populate the familygroup filters to hide all by default
    for _, familyName in ipairs(LM.Options:GetFamilyNames()) do
        DefaultFilterList.familygroup[familyName] = true  -- true means filtered (hidden)
    end
    
    -- Create the core filter object
    LM.UIFilter = {
        filteredMountList = LM.MountList:New(),
        searchText = "",
        sortKey = 'default',  -- Explicitly set default sort key
        filterList = CopyTable(DefaultFilterList),
        typeNamesInUse = {},
        lastCacheUpdate = 0,
    }
    
    -- Set up callback handler
    local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0", true)
    LM.UIFilter.callbacks = CallbackHandler:New(LM.UIFilter)
    
    -- Register event to refresh filter cache when mount registry updates
    if LM.MountRegistry then
        LM.MountRegistry.RegisterCallback(LM.UIFilter, "OnMountSummoned", "ClearCache")
    end
    
    -- Register for options changes
    if LM.db and LM.db.callbacks then
        LM.db.RegisterCallback(LM.UIFilter, "OnOptionsModified", "ClearCache")
    end
end

-- String utility functions
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

--[[----------------------------------------------------------------------------
  Cache Management
----------------------------------------------------------------------------]]--

-- Clear the filter cache completely
function LM.UIFilter.ClearCache()
    LM.UIFilter.lastCacheUpdate = 0
    if LM.UIFilter.filteredMountList then
        table.wipe(LM.UIFilter.filteredMountList)
    else
        LM.UIFilter.filteredMountList = LM.MountList:New()
    end
    
    -- Force a cache update on next request
    LM.UIFilter.cacheNeedsUpdate = true
end

-- Force invalidate the cache (useful for external calls)
function LM.UIFilter.InvalidateCache()
    LM.UIFilter.ClearCache()
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
end

-- Update the filter cache
function LM.UIFilter.UpdateCache()
    -- Skip if we just updated recently (throttle updates)
    local now = GetTime()
    if now - LM.UIFilter.lastCacheUpdate < 0.1 and not LM.UIFilter.cacheNeedsUpdate then
        return
    end
    
    -- Clear the current list
    if not LM.UIFilter.filteredMountList then
        LM.UIFilter.filteredMountList = LM.MountList:New()
    else
        table.wipe(LM.UIFilter.filteredMountList)
    end
    
    -- Get all mounts, groups, and families
    local allItems = {}
    
    -- Add all regular mounts
    for _, mount in ipairs(LM.MountRegistry.mounts) do
        table.insert(allItems, mount)
    end
    
    -- Add all groups
    for _, groupName in ipairs(LM.Options:GetGroupNames()) do
        if groupName and groupName ~= "" then
            local groupItem = {
                name = groupName,
                isGroup = true,
            }
            table.insert(allItems, groupItem)
        end
    end
    
    -- Add all families (for mainline WoW)
    if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
        for _, familyName in ipairs(LM.Options:GetFamilyNames()) do
            if familyName and familyName ~= "" then
                local familyItem = {
                    name = familyName,
                    isFamily = true,
                }
                table.insert(allItems, familyItem)
            end
        end
    end
    
    -- Filter the items
    for _, item in ipairs(allItems) do
        if not LM.UIFilter.IsFilteredMount(item) then
            table.insert(LM.UIFilter.filteredMountList, item)
        end
    end
    
    -- Sort the filtered list
    LM.UIFilter.filteredMountList:Sort(LM.UIFilter.GetSortKey())
    
    -- Update timestamp and clear need flag
    LM.UIFilter.lastCacheUpdate = now
    LM.UIFilter.cacheNeedsUpdate = false
end

-- Get the filtered and sorted mount list
function LM.UIFilter.GetFilteredMountList()
    LM.UIFilter.UpdateCache()
    return LM.UIFilter.filteredMountList
end

--[[----------------------------------------------------------------------------
  Filter Controls
----------------------------------------------------------------------------]]--

-- Clear all filters
function LM.UIFilter.Clear()
    LM.UIFilter.ClearCache()
    LM.UIFilter.filterList = CopyTable(DefaultFilterList)
    LM.UIFilter.searchText = ""
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
end

-- Check if any filters are active
function LM.UIFilter.IsFiltered()
    return not tCompare(LM.UIFilter.filterList, DefaultFilterList, 2)
end

--[[----------------------------------------------------------------------------
  Sort Controls
----------------------------------------------------------------------------]]--

function LM.UIFilter.GetSortKey()
    return LM.UIFilter.sortKey
end

function LM.UIFilter.SetSortKey(k)
    if LM.UIFilter.sortKey == k then
        return
    else
        LM.UIFilter.sortKey = (k or 'default')
        LM.UIFilter.ClearCache()
        LM.UIFilter.callbacks:Fire('OnFilterChanged')
    end
end

function LM.UIFilter.GetSortKeys()
    return SortKeysByProject[WOW_PROJECT_ID]
end

function LM.UIFilter.GetSortKeyText(k)
    return SortKeyTexts[k] or UNKNOWN
end

-- Helper function for sort key checked state
function LM.UIFilter.IsSortKeyChecked(k)
    -- If k is nil, return true for the dropdown menu header
    if not k then
        return true
    end
    -- Check if the current sort key matches
    return LM.UIFilter.GetSortKey() == k
end

--[[----------------------------------------------------------------------------
  Source Filters
----------------------------------------------------------------------------]]--

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
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.SetSourceFilter(i, v)
    LM.UIFilter.ClearCache()
    if v then
        LM.UIFilter.filterList.source[i] = nil
    else
        LM.UIFilter.filterList.source[i] = true
    end
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
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

--[[----------------------------------------------------------------------------
  Family Filters
----------------------------------------------------------------------------]]--

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
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.SetFamilyFilter(i, v)
    LM.UIFilter.ClearCache()
    if v then
        LM.UIFilter.filterList.family[i] = nil
    else
        LM.UIFilter.filterList.family[i] = true
    end
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
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

--[[----------------------------------------------------------------------------
  Family Groups Filters
----------------------------------------------------------------------------]]--

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
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
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
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
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

--[[----------------------------------------------------------------------------
  TypeName Filters
----------------------------------------------------------------------------]]--

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
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
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
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
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

--[[----------------------------------------------------------------------------
  Flag Filters
----------------------------------------------------------------------------]]--

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
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
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
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.GetFlags()
    return LM.Options:GetFlags()
end

function LM.UIFilter.GetFlagText(f)
    return L[f] or f
end

--[[----------------------------------------------------------------------------
  Group Filters
----------------------------------------------------------------------------]]--

function LM.UIFilter.SetGroupFilter(g, v)
    LM.UIFilter.ClearCache()
    if v then
        LM.UIFilter.filterList.group[g] = nil
    else
        LM.UIFilter.filterList.group[g] = true
    end
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
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
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.GetGroups()
    local groups = LM.Options:GetGroupNames()
    table.sort(groups)  -- Sort alphabetically
    return groups
end

function LM.UIFilter.GetGroupText(f)
    if f == NONE then
        return f:upper()
    else
        return f
    end
end

--[[----------------------------------------------------------------------------
  Priority Filters
----------------------------------------------------------------------------]]--

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
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
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
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
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

--[[----------------------------------------------------------------------------
  Rarity Filters
----------------------------------------------------------------------------]]--

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

--[[----------------------------------------------------------------------------
  Other Filters
----------------------------------------------------------------------------]]--

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
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
end

--[[----------------------------------------------------------------------------
  Search Filters
----------------------------------------------------------------------------]]--

function LM.UIFilter.SetSearchText(t)
    LM.UIFilter.ClearCache()
    LM.UIFilter.searchText = t
    LM.UIFilter.callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.GetSearchText()
    return LM.UIFilter.searchText
end

--[[----------------------------------------------------------------------------
  Mount Filter Logic
----------------------------------------------------------------------------]]--

-- Main function to determine if a mount should be filtered (hidden)
function LM.UIFilter.IsFilteredMount(m)
    if not m then return true end

    local filterList = LM.UIFilter.filterList
    local filtertext = LM.UIFilter.GetSearchText()
    local isSearching = filtertext and filtertext ~= SEARCH and filtertext ~= ""

    -- Groups and Families filtering
    if m.isGroup or m.isFamily then
        -- Group/Family checkbox filters
        if m.isGroup and filterList.group[m.name] then
            return true
        elseif m.isFamily and filterList.familygroup[m.name] then
            return true
        end

        -- Search text filter
        if isSearching then
            local matchesSearch = strfind(m.name:lower(), filtertext:lower(), 1, true)
            if not matchesSearch then
                return true
            end
        end
        
        -- Priority filter for groups/families
        if next(filterList.priority) then
            local entityPriority = m.isGroup and LM.Options:GetGroupPriority(m.name) or 
                                   m.isFamily and LM.Options:GetFamilyPriority(m.name)
            for _, p in ipairs(LM.UIFilter.GetPriorities()) do
                if filterList.priority[p] and entityPriority == p then
                    return true
                end
            end
        end

        -- Comprehensive mount-level filtering for groups/families
        if (next(filterList.flag) or next(filterList.typename) or next(filterList.source)) then
            local entityHasMatchingMount = false
            
            if LM.MountRegistry and LM.MountRegistry.mounts then
                for _, mount in ipairs(LM.MountRegistry.mounts) do
                    -- Check if mount belongs to this group/family
                    local belongsToEntity = (m.isGroup and LM.Options:IsMountInGroup(mount, m.name)) or 
                                            (m.isFamily and mount.family == m.name)
                    
                    if belongsToEntity then
                        -- Type Filters
                        local typeInfo = LM.MOUNT_TYPE_INFO[mount.mountTypeID or 0]
                        local typeFiltered = typeInfo and filterList.typename[typeInfo.name]
                        
                        -- Source Filters
                        local sourceFiltered = next(filterList.source) and 
                                               filterList.source[mount.sourceType or LM.UIFilter.GetNumSources()]
                        
                        -- Flag Filters
                        local flagFiltered = false
                        if mount.GetFlags and next(filterList.flag) then
                            flagFiltered = true
                            for f in pairs(mount:GetFlags()) do
                                if LM.FLAG[f] ~= nil and not filterList.flag[f] then
                                    flagFiltered = false
                                    break
                                end
                            end
                        end
                        
                        -- If any mount passes these filters, keep the group/family
                        if not (typeFiltered or sourceFiltered or flagFiltered) then
                            entityHasMatchingMount = true
                            break
                        end
                    end
                end
            end
            
            -- Hide if no mount passes the filters
            if not entityHasMatchingMount then
                return true
            end
        end
        
        -- Usability check
        local status = LM.GetEntityStatus(m.isGroup, m.name)
        if not status.hasUsableMounts and filterList.other.UNUSABLE then
            return true
        end
        
        return false
    end

    -- Collection filters
    if m.IsCollected and filterList.other.COLLECTED and m:IsCollected() then
        return true
    end

    if m.IsCollected and filterList.other.NOT_COLLECTED and not m:IsCollected() then
        return true
    end

    if m.IsHidden and filterList.other.HIDDEN and m:IsHidden() then
        return true
    end

    -- Usability filter
    if filterList.other.UNUSABLE then
        if m.IsHidden and m.IsFilterUsable and not m:IsHidden() and not m:IsFilterUsable() then
            return true
        end
    end

    -- Type filters
    local typeInfo = LM.MOUNT_TYPE_INFO[m.mountTypeID or 0]
    if typeInfo and filterList.typename[typeInfo.name] then
        return true
    end

    -- Source filters
    if next(filterList.source) then
        local source = m.sourceType or LM.UIFilter.GetNumSources()
        if filterList.source[source] then
            return true
        end
    end

    -- Priority filter
    if m.GetPriority then
        for _, p in ipairs(LM.UIFilter.GetPriorities()) do
            if filterList.priority[p] and m:GetPriority() == p then
                return true
            end
        end
    end

    -- Flag filters
    if m.GetFlags and next(filterList.flag) then
        local isFiltered = true
        for f in pairs(m:GetFlags()) do
            if LM.FLAG[f] ~= nil and not filterList.flag[f] then
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

-- Return the module for external use
return LM.UIFilter