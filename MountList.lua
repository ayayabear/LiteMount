--[[----------------------------------------------------------------------------
  LiteMount/MountList.lua
  Copyright 2011 Mike Battersby
----------------------------------------------------------------------------]]--

local _, LM = ...
LM.MountList = LM.MountList or { }  -- Initialize if it doesn't exist
LM.MountList.__index = LM.MountList

local SortFunctions = {
    ['default'] = function(a, b)
        --LM.Debug("Default sorting: " .. a.name .. " vs " .. b.name)
        if a.isGroup ~= b.isGroup then 
            return a.isGroup 
        end
        if a.isFamily ~= b.isFamily then 
            return a.isFamily 
        end
        return a.name < b.name
    end,
    
    ['name'] = function(a, b)
        LM.Debug("Name sorting: " .. a.name .. " vs " .. b.name)
        return a.name < b.name
    end,
    
    ['rarity'] = function(a, b)
        LM.Debug("Rarity sorting: " .. a.name .. " vs " .. b.name)
        -- Mounts first, then groups/families
        if a.isGroup or a.isFamily then 
            if not (b.isGroup or b.isFamily) then
                return false
            end
        elseif b.isGroup or b.isFamily then
            return true
        end
        -- Regular mount rarity comparison if both are mounts
        if not (a.isGroup or a.isFamily) and not (b.isGroup or b.isFamily) then
            return (a:GetRarity() or 101) < (b:GetRarity() or 101)
        end
        return a.name < b.name
    end,
    
    ['summons'] = function(a, b)
        local aCount = a:GetSummonCount() or 0
        local bCount = b:GetSummonCount() or 0
        LM.Debug("Summons sorting: " .. a.name .. "(" .. aCount .. ") vs " .. b.name .. "(" .. bCount .. ")")
        if aCount == bCount then
            return a.name < b.name
        end
        return aCount > bCount
    end,
}

function LM.MountList:Sort(key)
    --LM.Debug("Sort called with key: " .. tostring(key))
    if not key then
        LM.Debug("No sort key provided, using default")
        key = 'default'
    end
    if not SortFunctions[key] then
       -- LM.Debug("Invalid sort key: " .. key .. ", using default")
        key = 'default'
    end
    table.sort(self, SortFunctions[key])
end

function LM.MountList:New(ml)
    return setmetatable(ml or {}, LM.MountList)
end

if not LM.usabilityCache then
    LM.usabilityCache = {
        groups = {},
        families = {},
        lastUpdate = 0
    }
end

function LM.MountList:ClearCache()
    self.cachedCombinedList = nil
    self.cachedSearchText = nil
end

function LM.MountList:GetCombinedList()
    -- If we already have a cached list and nothing has changed, return it
    if self.cachedCombinedList and
       self.cachedSearchText == LM.UIFilter.GetSearchText() then
        LM.Debug("Returning cached list with " .. #self.cachedCombinedList .. " items")
        return self.cachedCombinedList
    end

    local combinedList = self:New()
    local groups = LM.Options:GetGroupNames()
    local families = LM.Options:GetFamilyNames()

    LM.Debug("Found " .. #groups .. " groups and " .. #families .. " families")

    -- Get search text for filtering
    local filtertext = LM.UIFilter.GetSearchText()
    local isSearching = filtertext and filtertext ~= SEARCH and filtertext ~= ""

    -- Function to check if a name matches search
    local function matchesSearch(name)
        if not isSearching then return true end
        return string.find(string.lower(name), string.lower(filtertext), 1, true) ~= nil
    end

    -- Add groups that match search AND aren't filtered by checkboxes
    for _, groupName in ipairs(groups) do
        if matchesSearch(groupName) and not LM.UIFilter.filterList.group[groupName] then
            local groupMount = {
                isGroup = true,
                name = groupName,
                group = groupName,
                priority = LM.Options:GetGroupPriority(groupName),
                GetPriority = function() return LM.Options:GetGroupPriority(groupName) end,
                IsCollected = function() return true end,
                GetSummonCount = function() 
                    LM.Debug("Getting summon count for group: " .. groupName)
                    return LM.Options:GetEntitySummonCount(true, groupName) 
                end
            }
            table.insert(combinedList, groupMount)
        end
    end

    -- Add families that match search AND aren't filtered by checkboxes
    for _, familyName in ipairs(families) do
        if matchesSearch(familyName) and not LM.UIFilter.filterList.familygroup[familyName] then
            local familyMount = {
                isFamily = true,
                name = familyName,
                family = familyName,
                priority = LM.Options:GetFamilyPriority(familyName),
                GetPriority = function() return LM.Options:GetFamilyPriority(familyName) end,
                IsCollected = function() return true end,
                GetSummonCount = function() 
                    LM.Debug("Getting summon count for family: " .. familyName)
                    return LM.Options:GetEntitySummonCount(false, familyName) 
                end
            }
            table.insert(combinedList, familyMount)
        end
    end

    -- Add mounts that match search
    for _, mount in ipairs(self) do
        if matchesSearch(mount.name) then
            table.insert(combinedList, mount)
        end
    end

    -- Before returning, sort the list
    LM.Debug("Sorting combined list by: " .. (LM.UIFilter.GetSortKey() or "default"))
    combinedList:Sort(LM.UIFilter.GetSortKey())

    -- Cache and return the sorted list
    self.cachedCombinedList = combinedList
    self.cachedSearchText = filtertext

    return combinedList
end

function LM.GetGroupOrFamilyStatus(isGroup, name)
    local hasUsableMounts = false
    local hasCollectedMounts = false
    local hasPriorityMounts = false
    
    -- Check if any type filter is unchecked
    local typeFilters = {}
    for flagName in pairs(LM.FLAG) do
        if LM.UIFilter.filterList.flag[flagName] then
            typeFilters[flagName] = true
        end
    end
    local hasTypeFilters = next(typeFilters) ~= nil
    
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
                    
                    -- Check if the mount passes type filters
                    local passesTypeFilters = true
                    if hasTypeFilters then
                        passesTypeFilters = false
                        local mountFlags = mount:GetFlags()
                        for flagName in pairs(mountFlags) do
                            if LM.FLAG[flagName] and not typeFilters[flagName] then
                                passesTypeFilters = true
                                break
                            end
                        end
                    end
                    
                    -- Only count as usable if it meets all criteria
                    if isRightFaction and mount:IsUsable() and passesTypeFilters then
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

-- The RefreshUsabilityCache() function remains exactly the same as you had it
function LM.RefreshUsabilityCache()
    local cache = LM.usabilityCache
    cache.groups = {}
    cache.families = {}
    
    -- Get current search text
    local searchText = LM.UIFilter.GetSearchText()
    local isSearching = searchText and searchText ~= SEARCH and searchText ~= ""
    
    -- Check if any type filter is unchecked
    local typeFilters = {}
    for flagName in pairs(LM.FLAG) do
        if LM.UIFilter.filterList.flag[flagName] then
            typeFilters[flagName] = true
        end
    end
    local hasTypeFilters = next(typeFilters) ~= nil
    
    -- Refresh group usability
    for _, groupName in ipairs(LM.Options:GetGroupNames()) do
        local groupStatus = {
            hasCollectedMounts = false,
            hasUsableMounts = false,
            hasRightFactionMounts = false,
            isRed = false
        }
        
        -- Check each mount in the group
        for _, mount in ipairs(LM.MountRegistry.mounts) do
            if LM.Options:IsMountInGroup(mount, groupName) and mount:GetPriority() > 0 then
                -- Check if mount matches search filter
                local matchesSearch = true
                if isSearching then
                    matchesSearch = string.find(mount.name:lower(), searchText:lower(), 1, true) ~= nil
                end
                
                if matchesSearch then
                    -- Check faction using existing method
                    local isRightFaction = true
                    if mount.mountID then
                        local _, _, _, _, _, _, _, isFactionSpecific, faction = C_MountJournal.GetMountInfoByID(mount.mountID)
                        if isFactionSpecific then
                            local playerFaction = UnitFactionGroup('player')
                            isRightFaction = (playerFaction == 'Horde' and faction == 0) or 
                                             (playerFaction == 'Alliance' and faction == 1)
                        end
                    end
                    
                    -- Check if the mount passes type filters
                    local passesTypeFilters = true
                    if hasTypeFilters then
                        passesTypeFilters = false
                        local mountFlags = mount:GetFlags()
                        for flagName in pairs(mountFlags) do
                            if LM.FLAG[flagName] and not typeFilters[flagName] then
                                passesTypeFilters = true
                                break
                            end
                        end
                    end
                    
                    if mount:IsCollected() then
                        groupStatus.hasCollectedMounts = true
                        
                        -- Only consider usability if it's the right faction and passes type filters
                        if isRightFaction then
                            groupStatus.hasRightFactionMounts = true
                            if mount:IsUsable() and passesTypeFilters then
                                groupStatus.hasUsableMounts = true
                            end
                        end
                    end
                end
            end
        end
        
        groupStatus.isRed = groupStatus.hasCollectedMounts and groupStatus.hasRightFactionMounts and not groupStatus.hasUsableMounts
        cache.groups[groupName] = groupStatus
    end
    
    -- Apply the same logic for families
    for _, familyName in ipairs(LM.Options:GetFamilyNames()) do
        local familyStatus = {
            hasCollectedMounts = false,
            hasUsableMounts = false,
            hasRightFactionMounts = false,
            isRed = false
        }
        
        -- Check each mount in the family
        for _, mount in ipairs(LM.MountRegistry.mounts) do
            if LM.Options:IsMountInFamily(mount, familyName) and mount:GetPriority() > 0 then
                -- Check if mount matches search filter
                local matchesSearch = true
                if isSearching then
                    matchesSearch = string.find(mount.name:lower(), searchText:lower(), 1, true) ~= nil
                end
                
                if matchesSearch then
                    -- Check faction using existing method
                    local isRightFaction = true
                    if mount.mountID then
                        local _, _, _, _, _, _, _, isFactionSpecific, faction = C_MountJournal.GetMountInfoByID(mount.mountID)
                        if isFactionSpecific then
                            local playerFaction = UnitFactionGroup('player')
                            isRightFaction = (playerFaction == 'Horde' and faction == 0) or 
                                             (playerFaction == 'Alliance' and faction == 1)
                        end
                    end
                    
                    -- Check if the mount passes type filters
                    local passesTypeFilters = true
                    if hasTypeFilters then
                        passesTypeFilters = false
                        local mountFlags = mount:GetFlags()
                        for flagName in pairs(mountFlags) do
                            if LM.FLAG[flagName] and not typeFilters[flagName] then
                                passesTypeFilters = true
                                break
                            end
                        end
                    end
                    
                    if mount:IsCollected() then
                        familyStatus.hasCollectedMounts = true
                        
                        -- Only consider usability if it's the right faction and passes type filters
                        if isRightFaction then
                            familyStatus.hasRightFactionMounts = true
                            if mount:IsUsable() and passesTypeFilters then
                                familyStatus.hasUsableMounts = true
                            end
                        end
                    end
                end
            end
        end
        
        familyStatus.isRed = familyStatus.hasCollectedMounts and familyStatus.hasRightFactionMounts and not familyStatus.hasUsableMounts
        cache.families[familyName] = familyStatus
    end
    
    cache.lastUpdate = GetTime()
    LM.Debug("Refreshed usability cache with search: " .. tostring(searchText))
end

function LM.GetUsableMountsFromEntity(isGroup, entityName)
    local mounts = LM.MountList:New()
    local searchText = LM.UIFilter.GetSearchText()
    local isSearching = searchText and searchText ~= SEARCH and searchText ~= ""
    
    for _, mount in ipairs(LM.MountRegistry.mounts) do
        local isInEntity = false
        if isGroup then
            isInEntity = LM.Options:IsMountInGroup(mount, entityName)
        else
            isInEntity = LM.Options:IsMountInFamily(mount, entityName)
        end
        
        -- Check if the mount matches criteria
        if isInEntity and mount:IsCollected() and mount:IsUsable() and mount:GetPriority() > 0 then
            -- Only include the mount if it matches the search filter (or no search is active)
            local matchesSearch = true
            if isSearching then
                matchesSearch = string.find(mount.name:lower(), searchText:lower(), 1, true) ~= nil
            end
            
            if matchesSearch then
                table.insert(mounts, mount)
            end
        end
    end
    LM.Debug("GetUsableMountsFromEntity is defined: " .. tostring(type(LM.GetUsableMountsFromEntity) == "function"))
    return mounts
end

-- New direct summoning helper function that bypasses the usual mount selection logic

function LM.DirectlySummonRandomMountFromEntity(isGroup, entityName)
    LM.Debug("Starting DirectlySummonRandomMountFromEntity for: " .. tostring(entityName))
    
    local mounts = LM.GetMountsFromEntity(isGroup, entityName)
    if #mounts > 0 then
        local style = LM.Options:GetOption('randomWeightStyle')
        local selectedMount = mounts:Random(nil, style)
        
        if selectedMount and selectedMount.mountID then
            -- Increment entity count first
            LM.Debug("Incrementing count for " .. (isGroup and "group: " or "family: ") .. entityName)
            LM.Options:IncrementEntitySummonCount(isGroup, entityName)
            
            -- Then summon mount
            C_MountJournal.SummonByID(selectedMount.mountID)
            return true
        end
    end
    return false
end

-- Rest of the MountList.lua code remains exactly the same as before, starting from Copy() function


function LM.MountList:Copy()
    local out = { }
    for i,v in ipairs(self) do
        out[i] = v
    end
    return self:New(out)
end

function LM.MountList:Clear()
    table.wipe(self)
    return self
end

function LM.MountList:Extend(other)
    local exists = { }
    for _,m in ipairs(self) do
        exists[m] = true
    end
    for _,m in ipairs(other) do
        if not exists[m] then
            table.insert(self, m)
        end
    end
    return self
end

function LM.MountList:Reduce(other)
    local remove = { }
    for _,m in ipairs(other) do
        remove[m] = true
    end
    local j, n = 1, #self
    for i = 1, n do
        if remove[self[i]] then
            self[i] = nil
        else
            if i ~= j then
                self[j] = self[i]
                self[i] = nil
            end
            j = j + 1
        end
    end
    return self
end

function LM.MountList:Search(matchfunc, ...)
    local result = self:New()
    for _,m in ipairs(self) do
        if matchfunc(m, ...) then
            tinsert(result, m)
        end
    end
    return result
end

function LM.MountList:Find(matchfunc, ...)
    for _,m in ipairs(self) do
        if matchfunc(m, ...) then
            return m
        end
    end
end

function LM.MountList:Shuffle()
    for i = #self, 2, -1 do
        local r = math.random(i)
        self[i], self[r] = self[r], self[i]
    end
end

function LM.MountList:SimpleRandom(r)
    if #self > 0 then
        if r then
            r = math.ceil(r * #self)
        else
            r = math.random(#self)
        end
        return self[r]
    end
end

function LM.MountList:PriorityWeights()
    local weights = { total = 0 }
    local groupWeights = {}
    local familyWeights = {}
    local standaloneMounts = {}
    local maxPriorityFound = false
    
    -- First check for priority 4 groups, families, or mounts
    for i, m in ipairs(self) do
        weights[i] = 0  -- Initialize weight to 0
        
        -- Only process mounts with priority > 0
        if m:GetPriority() > 0 then
            -- Check if mount belongs to any groups
            local highestPriorityGroup = nil
            local highestGroupPriority = 0
            
            for _, groupName in ipairs(LM.Options:GetGroupNames()) do
                if LM.Options:IsMountInGroup(m, groupName) then
                    local groupPriority = LM.Options:GetGroupPriority(groupName)
                    if groupPriority > highestGroupPriority then
                        highestGroupPriority = groupPriority
                        highestPriorityGroup = groupName
                    end
                end
            end

            -- Check if mount belongs to any families
            local highestPriorityFamily = nil
            local highestFamilyPriority = 0
            
            for _, familyName in ipairs(LM.Options:GetFamilyNames()) do
                if LM.Options:IsMountInFamily(m, familyName) then
                    local familyPriority = LM.Options:GetFamilyPriority(familyName)
                    if familyPriority > highestFamilyPriority then
                        highestFamilyPriority = familyPriority
                        highestPriorityFamily = familyName
                    end
                end
            end

            -- Determine the highest priority between groups and families
            local highestPriority = math.max(highestGroupPriority, highestFamilyPriority)
            local highestPriorityEntity = highestGroupPriority > highestFamilyPriority and highestPriorityGroup or highestPriorityFamily
            local isGroup = highestGroupPriority > highestFamilyPriority

            if highestPriorityEntity then
                if highestPriority == 4 then
                    -- Handle priority 4 groups or families
                    if isGroup then
                        if not groupWeights[highestPriorityEntity] then
                            groupWeights[highestPriorityEntity] = {
                                mounts = {},
                                mountIndices = {},
                                priority = 4
                            }
                        end
                        table.insert(groupWeights[highestPriorityEntity].mounts, m)
                        groupWeights[highestPriorityEntity].mountIndices[i] = true
                    else
                        if not familyWeights[highestPriorityEntity] then
                            familyWeights[highestPriorityEntity] = {
                                mounts = {},
                                mountIndices = {},
                                priority = 4
                            }
                        end
                        table.insert(familyWeights[highestPriorityEntity].mounts, m)
                        familyWeights[highestPriorityEntity].mountIndices[i] = true
                    end
                    maxPriorityFound = true
                elseif highestPriority > 0 then
                    -- Handle non-priority 4 groups or families
                    if isGroup then
                        if not groupWeights[highestPriorityEntity] then
                            groupWeights[highestPriorityEntity] = {
                                mounts = {},
                                mountIndices = {},
                                priority = highestPriority
                            }
                        end
                        table.insert(groupWeights[highestPriorityEntity].mounts, m)
                        groupWeights[highestPriorityEntity].mountIndices[i] = true
                    else
                        if not familyWeights[highestPriorityEntity] then
                            familyWeights[highestPriorityEntity] = {
                                mounts = {},
                                mountIndices = {},
                                priority = highestPriority
                            }
                        end
                        table.insert(familyWeights[highestPriorityEntity].mounts, m)
                        familyWeights[highestPriorityEntity].mountIndices[i] = true
                    end
                end
            else
                -- Not in any group or family, add to standalone mounts
                local mountPriority = m:GetPriority()
                if mountPriority == 4 then
                    table.insert(standaloneMounts, {
                        index = i,
                        priority = 4
                    })
                    maxPriorityFound = true
                elseif mountPriority > 0 then
                    table.insert(standaloneMounts, {
                        index = i,
                        priority = mountPriority
                    })
                end
            end
        end
    end

    -- If we found any priority 4, only use those
    if maxPriorityFound then
        local maxPriorityEntities = {}
        local maxPriorityTotalMounts = 0
        
        -- Count standalone mounts with priority 4
        local priority4StandaloneMounts = 0
        for _, mount in ipairs(standaloneMounts) do
            if mount.priority == 4 then
                priority4StandaloneMounts = priority4StandaloneMounts + 1
            end
        end
        
        -- Collect priority 4 groups
        for groupName, group in pairs(groupWeights) do
            if group.priority == 4 then
                table.insert(maxPriorityEntities, group)
                maxPriorityTotalMounts = maxPriorityTotalMounts + 1 -- Each entity counts as ONE for selection
            end
        end

        -- Collect priority 4 families
        for familyName, family in pairs(familyWeights) do
            if family.priority == 4 then
                table.insert(maxPriorityEntities, family)
                maxPriorityTotalMounts = maxPriorityTotalMounts + 1 -- Each entity counts as ONE for selection
            end
        end

        local totalChoices = maxPriorityTotalMounts + priority4StandaloneMounts
        
        -- Set weights for priority 4 entities
        for i = 1, #self do
            weights[i] = 0
            
            -- Check priority 4 standalone mounts
            for _, mount in ipairs(standaloneMounts) do
                if mount.index == i and mount.priority == 4 then
                    weights[i] = 1 / totalChoices
                    weights.total = weights.total + weights[i]
                end
            end
            
            -- Check priority 4 groups and families
            for _, entity in pairs(maxPriorityEntities) do
                if entity.mountIndices[i] then
                    -- Distribute the entity's weight equally among its mounts
                    weights[i] = (1 / totalChoices) / #entity.mounts
                    weights.total = weights.total + weights[i]
                    break
                end
            end
        end
        
        return weights
    end

    -- Calculate total weight for non-max-priority entities
    local groupCount = 0
    local familyCount = 0
    local standaloneCount = #standaloneMounts
    local totalWeight = 0
    
    for _, group in pairs(groupWeights) do
        groupCount = groupCount + 1
        totalWeight = totalWeight + group.priority
    end
    
    for _, family in pairs(familyWeights) do
        familyCount = familyCount + 1
        totalWeight = totalWeight + family.priority
    end
    
    for _, mount in ipairs(standaloneMounts) do
        totalWeight = totalWeight + mount.priority
    end

    -- Set weights for regular priority entities
    for i = 1, #self do
        weights[i] = 0
        
        -- Check standalone mounts
        for _, mount in ipairs(standaloneMounts) do
            if mount.index == i then
                weights[i] = mount.priority / totalWeight
                weights.total = weights.total + weights[i]
            end
        end
        
        -- Check groups
        for groupName, group in pairs(groupWeights) do
            if group.mountIndices[i] then
                -- The group's weight is split among its mounts
                weights[i] = (group.priority / totalWeight) / #group.mounts
                weights.total = weights.total + weights[i]
                break
            end
        end
        
        -- Check families
        for familyName, family in pairs(familyWeights) do
            if family.mountIndices[i] then
                -- The family's weight is split among its mounts
                weights[i] = (family.priority / totalWeight) / #family.mounts
                weights.total = weights.total + weights[i]
                break
            end
        end
    end

    return weights
end

-- Rest of the functions remain exactly the same as in your original file
function LM.MountList:RarityWeights()
    local weights = { total=0 }

    for i, m in ipairs(self) do
        if m:GetPriority() == LM.Options.DISABLED_PRIORITY then
            weights[i] = 0
        else
            local rarity = m:GetRarity() or 50
            weights[i] = 101 / ( rarity + 1) - 1
        end
        weights.total = weights.total + weights[i]
    end

    return weights
end

function LM.MountList:LFUWeights()
    local weights = { total=0 }
    local lowestSummonCount

    for i, m in ipairs(self) do
        if m:GetPriority() ~= LM.Options.DISABLED_PRIORITY then
            local c = m:GetSummonCount()
            if c <= (lowestSummonCount or c) then
                lowestSummonCount = c
            end
        end
    end

    for i, m in ipairs(self) do
        if m:GetPriority() == LM.Options.DISABLED_PRIORITY then
            weights[i] = 0
        elseif m:GetSummonCount() == lowestSummonCount then
            weights[i] = 1
        else
            weights[i] = 0
        end
        weights.total = weights.total + weights[i]
    end

    return weights
end

function LM.MountList:WeightedRandom(weights, r)
    if weights.total == 0 then
        LM.Debug('  * WeightedRandom n=%d all weights 0', #self)
        return
    end

    local cutoff = (r or math.random()) * weights.total
    local t = 0
    
    for i = 1, #self do
        t = t + weights[i]
        if t > cutoff then
            return self[i]
        end
    end
end

-- Modify MountList:Random in MountList.lua to handle priority 0 mounts
function LM.MountList:Random(r, style)
    if #self == 0 then return end
    
    LM.Debug("MountList:Random called with " .. #self .. " mounts and style " .. tostring(style))
    
    if style == 'Priority' then
        -- Check if we only have priority 0 mounts
        local allZeroPriority = true
        for _, mount in ipairs(self) do
            if mount:GetPriority() > 0 then
                allZeroPriority = false
                break
            end
        end
        
        if allZeroPriority then
            LM.Debug("All mounts have priority 0, using SimpleRandom instead")
            return self:SimpleRandom(r)
        else
            -- Normal priority-based weighting
            local weights = self:PriorityWeights()
            return self:WeightedRandom(weights, r)
        end
    elseif style == 'Rarity' then
        local weights = self:RarityWeights()
        return self:WeightedRandom(weights, r)
    elseif style == 'LeastUsed' then
        local weights = self:LFUWeights()
        return self:WeightedRandom(weights, r)
    else
        return self:SimpleRandom(r)
    end
end

local function filterMatch(m, ...)
    return m:MatchesFilters(...)
end

function LM.MountList:FilterSearch(...)
    return self:Search(filterMatch, ...)
end

local function expressionMatch(m, e)
    return m:MatchesExpression(e)
end

function LM.MountList:ExpressionSearch(e)
    return self:Search(expressionMatch, e)
end

function LM.MountList:Limit(limits)
    local mounts = self:Copy()
    for _, arg in ipairs(limits) do
        local e = arg:ParseExpression()
        if e == nil then
            return nil
        elseif e.op == '+' then
            mounts = mounts:Extend(self:ExpressionSearch(e[1]))
        elseif e.op == '-' then
            mounts = mounts:Reduce(self:ExpressionSearch(e[1]))
        elseif e.op == '=' then
            mounts = self:ExpressionSearch(e[1])
        else
            mounts = mounts:ExpressionSearch(e)
        end
    end
    return mounts
end

function LM.MountList:Dump()
    for _,m in ipairs(self) do
        m:Dump()
    end
end

