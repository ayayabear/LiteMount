--[[----------------------------------------------------------------------------

  LiteMount/MountRegistry.lua

  Central registry for all mount information.

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...

local C_MountJournal = LM.C_MountJournal or C_MountJournal
local C_Spell = LM.C_Spell

local CallbackHandler = LibStub:GetLibrary("CallbackHandler-1.0", true)

-- List of attributes to index for quick lookup
local IndexAttributes = { 'mountID', 'name', 'spellID', 'overrideSpellID' }

-- Flag to prevent double counting when summoning from a group/family
LM.preventDoubleCounting = false

--[[----------------------------------------------------------------------------
  Mount Type Definitions
----------------------------------------------------------------------------]]--

-- Type, type class create args
local MOUNT_SPELLS = {
    { "RunningWild", LM.SPELL.RUNNING_WILD },
    { "GhostWolf", LM.SPELL.GHOST_WOLF, 'RUN', 'SLOW' },
    { "Nagrand", LM.SPELL.FROSTWOLF_WAR_WOLF, 'Horde', 'RUN' },
    { "Nagrand", LM.SPELL.TELAARI_TALBUK, 'Alliance', 'RUN' },
    { "Soar", LM.SPELL.SOAR, 'FLY', 'DRAGONRIDING' },
    { "Drive", LM.SPELL.G_99_BREAKNECK, 'DRIVE' },
    { "ItemSummoned",
        LM.ITEM.MAGIC_BROOM, LM.SPELL.MAGIC_BROOM, 'RUN', 'FLY', },
    { "ItemSummoned",
        LM.ITEM.SHIMMERING_MOONSTONE, LM.SPELL.MOONFANG, 'RUN', },
    { "ItemSummoned",
        LM.ITEM.RATSTALLION_HARNESS, LM.SPELL.RATSTALLION_HARNESS, 'RUN', },
    { "ItemSummoned",
        LM.ITEM.SAPPHIRE_QIRAJI_RESONATING_CRYSTAL, LM.SPELL.BLUE_QIRAJI_WAR_TANK, 'RUN', },
    { "ItemSummoned",
        LM.ITEM.RUBY_QIRAJI_RESONATING_CRYSTAL, LM.SPELL.RED_QIRAJI_WAR_TANK, 'RUN', },
    { "ItemSummoned",
        LM.ITEM.MAWRAT_HARNESS, LM.SPELL.MAWRAT_HARNESS, 'RUN' },
    { "ItemSummoned",
        LM.ITEM.SPECTRAL_BRIDLE, LM.SPELL.SPECTRAL_BRIDLE, 'RUN' },
    { "ItemSummoned",
        LM.ITEM.DEADSOUL_HOUND_HARNESS, LM.SPELL.DEADSOUL_HOUND_HARNESS, 'RUN' },
    { "ItemSummoned",
        LM.ITEM.MAW_SEEKER_HARNESS, LM.SPELL.MAW_SEEKER_HARNESS, 'RUN' },
}

-- Project-specific mount spells
local MOUNT_SPELLS_BY_PROJECT = LM.TableWithDefault({
    [1] = {  -- Retail
        { "TravelForm", LM.SPELL.TRAVEL_FORM, 'DRAGONRIDING', 'RUN', 'FLY', 'SWIM' },
        { "TravelForm", LM.SPELL.MOUNT_FORM, 'RUN' },
    },
    DEFAULT = {  -- Classic
        { "TravelForm", LM.SPELL.TRAVEL_FORM, 'RUN', 'SLOW' },
        { "TravelForm", LM.SPELL.AQUATIC_FORM_CLASSIC, 'SWIM' },
        { "TravelForm", LM.SPELL.FLIGHT_FORM_CLASSIC, 'FLY' },
        { "TravelForm", LM.SPELL.SWIFT_FLIGHT_FORM_CLASSIC, 'FLY' },
    },
})

-- Combine all mount spells
tAppendAll(MOUNT_SPELLS, MOUNT_SPELLS_BY_PROJECT[WOW_PROJECT_ID])

--[[----------------------------------------------------------------------------
  Registry Events
----------------------------------------------------------------------------]]--

-- Events that should trigger a registry refresh
local RefreshEvents = {
    ["NEW_MOUNT_ADDED"] = true,
    ["COMPANION_LEARNED"] = true,
    ["COMPANION_UNLEARNED"] = true,
    ["ACTIVE_TALENT_GROUP_CHANGED"] = true,
    ["PLAYER_LEVEL_UP"] = true,
    ["PLAYER_TALENT_UPDATE"] = true,
    ["BAG_UPDATE_DELAYED"] = true,
    ["ACHIEVEMENT_EARNED"] = true,
}

--[[----------------------------------------------------------------------------
  MountRegistry Object
----------------------------------------------------------------------------]]--

LM.MountRegistry = CreateFrame("Frame", nil, UIParent)
LM.MountRegistry.callbacks = CallbackHandler:New(LM.MountRegistry)

function LM.MountRegistry:OnEvent(event, ...)
    if RefreshEvents[event] then
        LM.Debug("Got refresh event " .. event)
        self.needRefresh = true
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local _, _, spellID = ...
        local m = self.indexes.spellID[spellID] or self.indexes.overrideSpellID[spellID]
        if m then
            m:OnSummon()
            self.callbacks:Fire("OnMountSummoned", m)
        end
    end
end

function LM.MountRegistry:Initialize()
    -- Initialize the mount list
    self.mounts = LM.MountList:New()

    -- Add mounts in the correct order
    self:AddSpellMounts()      -- Custom spell mounts first
    self:AddJournalMounts()    -- Journal mounts second
    self:UpdateFilterUsability()

    -- Build indexes for quick lookup
    self:BuildIndexes()

    -- Set up event handling
    self:SetScript("OnEvent", self.OnEvent)

    -- Register for refresh events
    for ev in pairs(RefreshEvents) do
        self:RegisterEvent(ev)
    end
    
    -- Track mount summoning
    self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
end

-- Build lookup indexes for quick access to mounts
function LM.MountRegistry:BuildIndexes()
    self.indexes = { }
    for _, index in ipairs(IndexAttributes) do
        self.indexes[index] = {}
        for _, m in ipairs(self.mounts) do
            if m[index] then
                self.indexes[index][m[index]] = m
            end
        end
    end
end

-- Add a mount to the registry
function LM.MountRegistry:AddMount(m)
    local existing = self:GetMountBySpell(m.spellID)

    if existing then
        -- If mount already exists, copy any missing attributes
        for _, attr in ipairs({'modelID', 'sceneID', 'mountID', 'isSelfMount', 
                               'description', 'sourceType', 'sourceText'}) do
            existing[attr] = existing[attr] or m[attr]
        end
    else
        -- Otherwise add the new mount
        tinsert(self.mounts, m)
    end

    -- Register mount type ID for filtering
    if LM.UIFilter and LM.UIFilter.RegisterUsedTypeID then
        LM.UIFilter.RegisterUsedTypeID(m.mountTypeID or 0)
    end
end

--[[----------------------------------------------------------------------------
  Journal Mount Filtering
----------------------------------------------------------------------------]]--

-- Default filter settings for reading all mounts from journal
local CollectedFilterSettings = {
    [LE_MOUNT_JOURNAL_FILTER_COLLECTED] = true,
    [LE_MOUNT_JOURNAL_FILTER_NOT_COLLECTED] = true,
    [LE_MOUNT_JOURNAL_FILTER_UNUSABLE] = false,
}

-- Save and modify journal filters temporarily
local function SaveAndSetJournalFilters()
    local data = {
        collected = {},
        sources = {},
        types = {},
    }

    -- Save and set collected filters
    for setting, value in pairs(CollectedFilterSettings) do
        data.collected[setting] = C_MountJournal.GetCollectedFilterSetting(setting)
        C_MountJournal.SetCollectedFilterSetting(setting, value)
    end

    -- Save and set source filters
    for i = 1, C_PetJournal.GetNumPetSources() do
        if C_MountJournal.IsValidSourceFilter(i) then
            data.sources[i] = C_MountJournal.IsSourceChecked(i)
            C_MountJournal.SetSourceFilter(i, true)
        end
    end

    -- Save and set type filters
    for i = 1, Enum.MountTypeMeta.NumValues do
        if C_MountJournal.IsValidTypeFilter(i) then
            data.types[i] = C_MountJournal.IsTypeChecked(i)
            C_MountJournal.SetTypeFilter(i, true)
        end
    end

    -- Save search text
    if MountJournalSearchBox then
        data.searchText = MountJournalSearchBox:GetText()
        C_MountJournal.SetSearch("")
    else
        data.searchText = ""
    end

    return data
end

-- Restore journal filters
local function RestoreJournalFilters(data)
    -- Restore collected filters
    for setting, value in pairs(data.collected) do
        C_MountJournal.SetCollectedFilterSetting(setting, value)
    end
    
    -- Restore source filters
    for i, value in pairs(data.sources) do
        C_MountJournal.SetSourceFilter(i, value)
    end
    
    -- Restore type filters
    for i, value in pairs(data.types) do
        C_MountJournal.SetTypeFilter(i, value)
    end
    
    -- Restore search
    C_MountJournal.SetSearch(data.searchText)
end

-- Update mount usability flags based on journal filter
function LM.MountRegistry:UpdateFilterUsability()
    -- Save current filter state
    local data = SaveAndSetJournalFilters()

    -- Create a lookup of usable mounts according to the journal
    local filterUsableMounts = {}
    for i = 1, C_MountJournal.GetNumDisplayedMounts() do
        local mountID = select(12, C_MountJournal.GetDisplayedMountInfo(i))
        filterUsableMounts[mountID] = true
    end

    -- Update usability flags for all journal mounts
    for _, m in ipairs(self:FilterSearch("JOURNAL")) do
        m.isFilterUsable = filterUsableMounts[m.mountID] or false
    end

    -- Restore original filter state
    RestoreJournalFilters(data)
end

-- Add journal mounts to registry
function LM.MountRegistry:AddJournalMounts()
    for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
        local m = LM.Mount:Get("Journal", mountID)
        if m then self:AddMount(m) end
    end
end

-- Add spell-based mounts to registry
function LM.MountRegistry:AddSpellMounts()
    for _, typeAndArgs in ipairs(MOUNT_SPELLS) do
        local m = LM.Mount:Get(unpack(typeAndArgs))
        if m then
            self:AddMount(m)
        end
    end
end

-- Refresh all mounts if needed
function LM.MountRegistry:RefreshMounts()
    if self.needRefresh then
        LM.Debug("Refreshing status of all mounts.")
        for _, m in ipairs(self.mounts) do
            m:Refresh()
        end
        self.needRefresh = nil
    end
end

--[[----------------------------------------------------------------------------
  Mount Filtering and Lookup
----------------------------------------------------------------------------]]--

-- Filter mounts based on criteria
function LM.MountRegistry:FilterSearch(...)
    return self.mounts:FilterSearch(...)
end

-- Apply mount limits
function LM.MountRegistry:Limit(...)
    return self.mounts:Limit(...)
end

-- Find a mount based on active buffs
function LM.MountRegistry:GetMountFromUnitAura(unitid)
    local buffNames = { }
    local i = 1
    
    -- Collect all buff names
    while true do
        local auraInfo = C_UnitAuras.GetAuraDataByIndex(unitid, i)
        if auraInfo then 
            buffNames[auraInfo.name] = true 
        else 
            break 
        end
        i = i + 1
    end
    
    -- Find matching mount
    return self.mounts:Find(function(m, names) 
        if names[m.name] then return true end
        local spellName = C_Spell.GetSpellName(m.spellID)
        if spellName and names[spellName] then return true end
        return false
    end, buffNames)
end

-- Get the currently active mount
function LM.MountRegistry:GetActiveMount()
    local buffIDs = { }
    local i = 1
    
    -- Collect all buff IDs
    while true do
        local auraInfo = C_UnitAuras.GetAuraDataByIndex('player', i)
        if auraInfo then 
            buffIDs[auraInfo.spellId] = true 
        else 
            break 
        end
        i = i + 1
    end
    
    -- Find mount matching active buffs
    return self.mounts:Find(function (m) return m:IsActive(buffIDs) end)
end

-- Find mount by name
function LM.MountRegistry:GetMountByName(name)
    return self.mounts:Find(function(m) return m.name == name end)
end

-- Find mount by spell ID
function LM.MountRegistry:GetMountBySpell(id)
    return self.mounts:Find(function(m) return m.spellID == id end)
end

-- Find mount by journal ID
function LM.MountRegistry:GetMountByID(id)
    return self.mounts:Find(function(m) return m.mountID == id end)
end

-- Find mount based on shapeshift form
function LM.MountRegistry:GetMountByShapeshiftForm(i)
    if not i then
        return
    elseif i == 1 and select(2, UnitClass("player")) == "SHAMAN" then
         return self:GetMountBySpell(LM.SPELL.GHOST_WOLF)
    else
        local spellID
        spellID = select(4, GetShapeshiftFormInfo(i))
        if spellID then return self:GetMountBySpell(spellID) end
    end
end

--[[----------------------------------------------------------------------------
  Journal Mount Information
----------------------------------------------------------------------------]]--

-- Helper to check faction
local function IsRightFaction(info)
    if not info[9] then
        return true
    end
    local faction = UnitFactionGroup('player')
    local fnum = PLAYER_FACTION_GROUP[faction]
    if info[9] == fnum then
        return true
    end
end

-- Mounts that don't count towards usable total
local notCounted = {
    [367]   = true,     -- Exarch's Elekk
    [368]   = true,     -- Great Exarch's Elekk
    [1046]  = true,     -- Darkforge Ram
    [1047]  = true,     -- Dawnforge Ram
    [350]   = true,     -- Sunwalker Kodo
    [351]   = true,     -- Great Sunwalker Kodo
    [149]   = true,     -- Thalassian Charger
    [150]   = true,     -- Thalassian Warhorse
    [1225]  = true,     -- Crusader's Direhorn
    [780]   = true,     -- Felsaber
}

-- Helper to check if mount counts for usable total
local function IsCounted(info)
    if notCounted[info[12]] then
        return info[4]
    else
        return true
    end
end

-- Get mount totals for display
function LM.MountRegistry:GetJournalTotals()
    local c = { total=0, collected=0, usable=0 }

    for _, id in ipairs(C_MountJournal.GetMountIDs()) do
        local info = { C_MountJournal.GetMountInfoByID(id) }
        c.total = c.total + 1
        if info[11] and not info[10] then
            c.collected = c.collected + 1
            if IsRightFaction(info) and IsCounted(info) then
                c.usable = c.usable + 1
            end
        end
    end
    return c
end