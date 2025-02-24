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
    flag = { },
    group = { },
    other = { HIDDEN=true, UNUSABLE=true },
    priority = { },
    source = { },
    typename = { }
}

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

-- Fetch -----------------------------------------------------------------------

function LM.UIFilter.UpdateCache()
    LM.Debug("Starting UpdateCache")
    table.wipe(LM.UIFilter.filteredMountList)
    
    -- Get the combined list
    local mounts = LM.MountRegistry.mounts:GetCombinedList()
    
    -- Filter items
    local filteredList = LM.MountList:New()
    for _, item in ipairs(mounts) do
        if not LM.UIFilter.IsFilteredMount(item) then
            table.insert(filteredList, item)
        end
    end
    
    -- Sort the filtered list using MountList's Sort method
    LM.Debug("Sorting filtered list by: " .. tostring(LM.UIFilter.GetSortKey()))
    filteredList:Sort(LM.UIFilter.GetSortKey())
    
    -- Store the result
    LM.UIFilter.filteredMountList = filteredList
    
    LM.Debug("FilteredMountList now has " .. #LM.UIFilter.filteredMountList .. " items")
end

function LM.UIFilter.ClearCache()
    table.wipe(LM.UIFilter.filteredMountList)
end

function LM.UIFilter.GetFilteredMountList()
    LM.Debug("GetFilteredMountList called")
    if next(LM.UIFilter.filteredMountList) == nil then
        LM.Debug("Updating mount list cache")  -- Add this line
        LM.UIFilter.UpdateCache()
    end
	    LM.Debug("Filtered list has " .. #LM.UIFilter.filteredMountList .. " items")
    return LM.UIFilter.filteredMountList
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

function LM.UIFilter.SetFamilyFilter(f, v)
    LM.Debug("Setting family filter: " .. f .. " = " .. tostring(v))
    LM.UIFilter.ClearCache()
    if v then
        LM.UIFilter.filterList.family[f] = nil
    else
        LM.UIFilter.filterList.family[f] = true
    end
    callbacks:Fire('OnFilterChanged')
end

function LM.UIFilter.IsGroupChecked(g)
    return not LM.UIFilter.filterList.group[g]
end

function LM.UIFilter.IsFamilyChecked(f)
    return not LM.UIFilter.filterList.family[f]
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

function LM.UIFilter.SetAllFamilyFilters(v)
    LM.UIFilter.ClearCache()
    if v then
        table.wipe(LM.UIFilter.filterList.family)
    else
        -- Get all families
        for _, familyName in ipairs(LM.Options:GetFamilyNames()) do
            LM.UIFilter.filterList.family[familyName] = true
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

function LM.UIFilter.IsFilteredMount(m)
    -- Handle groups and families first
    if m.isGroup or m.isFamily then
        -- Text search handling
        local filtertext = LM.UIFilter.GetSearchText()
        if filtertext and filtertext ~= SEARCH and filtertext ~= "" then
            local matches = strfind(m.name:lower(), filtertext:lower(), 1, true)
            return not matches
        end

        -- Group/Family filter handling
        if m.isGroup then
            -- Return true (filter out) if the group is NOT checked
            LM.Debug("Checking group filter for: " .. m.name .. " = " .. tostring(LM.UIFilter.filterList.group[m.name]))
            return LM.UIFilter.filterList.group[m.name] or false
        elseif m.isFamily then
            -- Return true (filter out) if the family is NOT checked
            LM.Debug("Checking family filter for: " .. m.name .. " = " .. tostring(LM.UIFilter.filterList.family[m.name]))
            return LM.UIFilter.filterList.family[m.name] or false
        end
        return false
    end

    -- Source filters
    local source = m.sourceType
    if not source or source == 0 then
        source = LM.UIFilter.GetNumSources()
    end
    if LM.UIFilter.filterList.source[source] == true then
        return true
    end

    -- TypeName filters
    local typeInfo = LM.MOUNT_TYPE_INFO[m.mountTypeID or 0]
    if typeInfo and LM.UIFilter.filterList.typename[typeInfo.name] == true then
        return true
    end

    -- Family filters
    if m.family and LM.UIFilter.filterList.family[m.family] == true then
        return true
    end

    -- Does the mount info indicate it should be hidden
    if LM.UIFilter.filterList.other.HIDDEN and m:IsHidden() then
        return true
    end

    if LM.UIFilter.filterList.other.COLLECTED and m:IsCollected() then
        return true
    end

    if LM.UIFilter.filterList.other.NOT_COLLECTED and not m:IsCollected() then
        return true
    end

    if LM.UIFilter.filterList.other.UNUSABLE then
        if not m:IsHidden() and not m:IsFilterUsable() then
            return true
        end
    end

    -- Priority Filters
    for _, p in ipairs(LM.UIFilter.GetPriorities()) do
        if LM.UIFilter.filterList.priority[p] and LM.Options:GetPriority(m) == p then
            return true
        end
    end

    -- Groups filter has a magic NONE for anything with no groups
    local mountGroups = m:GetGroups()
    if not next(mountGroups) then
        if LM.UIFilter.filterList.group[NONE] then return true end
    else
        local isFiltered = true
        for g in pairs(mountGroups) do
            if not LM.UIFilter.filterList.group[g] then
                isFiltered = false
            end
        end
        if isFiltered then return true end
    end

    -- Flags
    if next(LM.UIFilter.filterList.flag) then
        local isFiltered = true
        for f in pairs(m:GetFlags()) do
            if LM.FLAG[f] ~= nil and not LM.UIFilter.filterList.flag[f] then
                isFiltered = false
                break
            end
        end
        if isFiltered then return true end
    end

    -- Search text from the input box.
    local filtertext = LM.UIFilter.GetSearchText()
    if not filtertext or filtertext == SEARCH or filtertext == "" then
        return false
    end

    if filtertext == "=" then
        local hasAura = AuraUtil.FindAuraByName(m.name, "player")
        return hasAura == nil
    end

--[==[@debug@
    if tonumber(filtertext) then
        return m.mountTypeID ~= tonumber(filtertext)
    end
--@end-debug@]==]

    if strfind(m.name:lower(), filtertext:lower(), 1, true) then
        return false
    end

    if m.description and searchMatch(m.description, filtertext) then
        return false
    end

    if m.sourceText and searchMatch(stripcodes(m.sourceText), filtertext) then
        return false
    end

    return true
end
