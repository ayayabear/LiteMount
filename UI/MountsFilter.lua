--[[----------------------------------------------------------------------------

  LiteMount/UI/MountsFilter.lua

  Options frame for the mount list.

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...

local L = LM.Localize

local LibDD = LibStub("LibUIDropDownMenu-4.0")

local MENU_SPLIT_SIZE = 20

--[[------------------------------------------------------------------------]]--

LiteMountFilterMixin = {}

function LiteMountFilterMixin:OnLoad()
    LM.UIFilter.RegisterCallback(self, "OnFilterChanged", "Update")
end

function LiteMountFilterMixin:Update()
    if LM.UIFilter.IsFiltered() then
        self.FilterButton.ClearButton:Show()
    else
        self.FilterButton.ClearButton:Hide()
    end
end

function LiteMountFilterMixin:Attach(parent, fromPoint, frame, toPoint, xOff, yOff)
    self:SetParent(parent)
    self:ClearAllPoints()
    self:SetPoint(fromPoint, frame, toPoint, xOff, yOff)
    self.Search:SetFocus()
    self:Show()
end

--[[------------------------------------------------------------------------]]--



LiteMountSearchBoxMixin = {}

function LiteMountSearchBoxMixin_OnTextChanged(self)
    SearchBoxTemplate_OnTextChanged(self)
    local searchText = self:GetText()
    
    -- Store search text
    LM.UIFilter.SetSearchText(searchText)
    
    -- Update appropriate panel based on context
    local currentPanel = LiteMountOptions.CurrentOptionsPanel
    if currentPanel then
        if currentPanel == LiteMountGroupsPanel then
            local selectedGroup = currentPanel.Groups.selectedGroup
            currentPanel.searchText = searchText
            
            -- First update will filter both lists
            currentPanel:Update()
            
            -- If we had a selection, ensure it stays in view and selected
            if selectedGroup then
                -- Force selected group to remain selected even if it doesn't match search
                currentPanel.Groups.selectedGroup = selectedGroup
                
                -- Re-update mounts to show search results while keeping selected group
                if currentPanel.Mounts and currentPanel.Mounts.Update then
                    currentPanel.Mounts:Update()
                end
            end
            
        elseif currentPanel == LiteMountFamiliesPanel then
            local selectedFamily = currentPanel.Families.selectedFamily
            currentPanel.searchText = searchText
            
            -- First update will filter both lists
            currentPanel:Update()
            
            -- If we had a selection, ensure it stays in view and selected
            if selectedFamily then
                -- Force selected family to remain selected even if it doesn't match search
                currentPanel.Families.selectedFamily = selectedFamily
                
                -- Re-update mounts to show search results while keeping selected family
                if currentPanel.Mounts and currentPanel.Mounts.Update then
                    currentPanel.Mounts:Update()
                end
            end
        else
            -- For other panels, just update normally
            if currentPanel.Update then
                currentPanel:Update()
            end
        end
    end
    
    -- Clear cache if search is cleared
    if searchText == "" then
        LM.MountList:ClearCache()
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

function LM.UIFilter.IsFilteredMount(mount)
    if not mount then return true end

    -- Special handling for group pseudo-mounts
    if mount.isGroup then
        -- Check if this group is filtered out
        if LM.UIFilter.filterList.group and
           LM.UIFilter.filterList.group[mount.name] == true then
            return true
        end
    end

    -- Special handling for groups with text search
    local filtertext = LM.UIFilter.GetSearchText()

    -- For groups/families
    if mount.isGroup or mount.isFamily then
        -- Check usability first
        local status = LM.GetGroupOrFamilyStatus(mount.isGroup, mount.name)
        if status.isRed and LM.UIFilter.filterList.other.UNUSABLE then
            return true
        end

        -- Check type filters if any are active
        if next(LM.UIFilter.filterList.flag) then
            local mounts = LM.GetMountsFromEntity(mount.isGroup, mount.name)
            local hasMatchingMount = false

            for _, m in ipairs(mounts) do
                -- Get mount's flags
                local mountFlags = m:GetFlags()
                local matchesAnyActiveFilter = false

                -- Check each possible type flag
                for flag, isFiltered in pairs(LM.UIFilter.filterList.flag) do
                    -- We only care about movement type flags
                    if flag == "AQUATIC" or flag == "GROUND" or flag == "FLYING" or flag == "DRAGONRIDING" then
                        -- If flag is not filtered (isFiltered is false) and mount has this flag
                        if not isFiltered and mountFlags[flag] then
                            matchesAnyActiveFilter = true
                            break
                        end
                    end
                end

                if matchesAnyActiveFilter then
                    hasMatchingMount = true
                    break
                end
            end

            -- Filter out if no contained mounts match active type filters
            if not hasMatchingMount then
                return true
            end
        end

        -- Handle search text
        if filtertext and filtertext ~= SEARCH and filtertext ~= "" then
            -- Existing search logic...
        end

        return false
    end

    -- Existing group filtering for regular mounts
    if mount.GetGroups then
        local mountGroups = mount:GetGroups()
        if not next(mountGroups) then
            if LM.UIFilter.filterList.group and
               LM.UIFilter.filterList.group[NONE] then
                return true
            end
        else
            local isFiltered = true
            for g in pairs(mountGroups) do
                if not (LM.UIFilter.filterList.group and
                        LM.UIFilter.filterList.group[g]) then
                    isFiltered = false
                end
            end
            if isFiltered then return true end
        end
    end

    -- Source filters
    local source = mount.sourceType
    if not source or source == 0 then
        source = LM.UIFilter.GetNumSources()
    end

    if LM.UIFilter.filterList.source[source] == true then
        return true
    end

    -- TypeName filters
    local typeInfo = LM.MOUNT_TYPE_INFO[mount.mountTypeID or 0]
    if typeInfo and LM.UIFilter.filterList.typename[typeInfo.name] == true then
        return true
    end

    -- Family filters
    if mount.family and LM.UIFilter.filterList.family[mount.family] == true then
        return true
    end

    -- Filter hidden mounts
    if mount.IsHidden and LM.UIFilter.filterList.other.HIDDEN and mount:IsHidden() then
        return true
    end

    -- Collection filters
    if mount.IsCollected and LM.UIFilter.filterList.other.COLLECTED and mount:IsCollected() then
        return true
    end

    if mount.IsCollected and LM.UIFilter.filterList.other.NOT_COLLECTED and not mount:IsCollected() then
        return true
    end

    -- Usability filter
    if LM.UIFilter.filterList.other.UNUSABLE then
        if mount.IsHidden and mount.IsFilterUsable and not mount:IsHidden() and not mount:IsFilterUsable() then
            return true
        end
    end

    -- Priority Filters
    if mount.GetPriority then
        for _, p in ipairs(LM.UIFilter.GetPriorities()) do
            if LM.UIFilter.filterList.priority[p] and mount:GetPriority() == p then
                return true
            end
        end
    end

    -- Flag filters
-- Flag filters
if mount.GetFlags and next(LM.UIFilter.filterList.flag) then
    local isFiltered = true
    for f in pairs(mount:GetFlags()) do
        if LM.FLAG[f] ~= nil and not LM.UIFilter.filterList.flag[f] then
            isFiltered = false
            break
        end
    end
    if isFiltered then return true end
end

    -- Search text from the input box
    if not filtertext or filtertext == SEARCH or filtertext == "" then
        return false
    end

    if filtertext == "=" and mount.name then
        local hasAura = AuraUtil.FindAuraByName(mount.name, "player")
        return hasAura == nil
    end

    -- Main search matching
    if mount.name and strfind(mount.name:lower(), filtertext:lower(), 1, true) then
        return false
    end

    -- Description search
    if mount.description and LM.UIFilter.SearchMatch(mount.description, filtertext) then
        return false
    end

    -- Source text search
    if mount.sourceText and LM.UIFilter.SearchMatch(LM.UIFilter.StripCodes(mount.sourceText), filtertext) then
        return false
    end

    -- If we get here, mount doesn't match search
    return true
end

--[[------------------------------------------------------------------------]]--

LiteMountFilterClearMixin = {}

function LiteMountFilterClearMixin:OnClick()
    LM.UIFilter.Clear()
end

--[[------------------------------------------------------------------------]]--

LiteMountFilterButtonMixin = {}

function LiteMountFilterButtonMixin:OnClick()
    LibDD:ToggleDropDownMenu(1, nil, self.FilterDropDown, self, 74, 15)
end

local DROPDOWNS = {
    ['COLLECTED'] = {
        value = 'COLLECTED',
        text = COLLECTED,
        checked = function () return LM.UIFilter.IsOtherChecked("COLLECTED") end,
        set = function (v) LM.UIFilter.SetOtherFilter("COLLECTED", v) end
    },
    ['NOT_COLLECTED'] = {
        value = 'NOT_COLLECTED',
        text = NOT_COLLECTED,
        checked = function () return LM.UIFilter.IsOtherChecked("NOT_COLLECTED") end,
        set = function (v) LM.UIFilter.SetOtherFilter("NOT_COLLECTED", v) end
    },
    ['UNUSABLE'] = {
        value = 'UNUSABLE',
        text = MOUNT_JOURNAL_FILTER_UNUSABLE,
        checked = function () return LM.UIFilter.IsOtherChecked("UNUSABLE") end,
        set = function (v) LM.UIFilter.SetOtherFilter("UNUSABLE", v) end
    },
    ['HIDDEN'] = {
        value = 'HIDDEN',
        text = L.LM_HIDDEN,
        checked = function () return LM.UIFilter.IsOtherChecked("HIDDEN") end,
        set = function (v) LM.UIFilter.SetOtherFilter("HIDDEN", v) end
    },
    ['PRIORITY'] = {
        value = 'PRIORITY',
        text = L.LM_PRIORITY,
        checked = function (k) return LM.UIFilter.IsPriorityChecked(k) end,
        set = function (k, v) LM.UIFilter.SetPriorityFilter(k, v) end,
        setall = function (v) LM.UIFilter.SetAllPriorityFilters(v) end,
        menulist = function () return LM.UIFilter.GetPriorities() end,
        gettext = function (k) return LM.UIFilter.GetPriorityText(k) end,
    },
    ['TYPENAME'] = {
        value = 'TYPENAME',
        text = string.format('%s (%s)', TYPE, ID),
        checked = function (k) return LM.UIFilter.IsTypeNameChecked(k) end,
        set = function (k, v) LM.UIFilter.SetTypeNameFilter(k, v) end,
        setall = function (v) LM.UIFilter.SetAllTypeNameFilters(v) end,
        menulist = function () return LM.UIFilter.GetTypeNames() end,
        gettext = function (k) return LM.UIFilter.GetTypeNameText(k) end,
    },
    ['GROUP'] = {
        value = 'GROUP',
        text = L.LM_GROUP,
        checked = function (k) return LM.UIFilter.IsGroupChecked(k) end,
        set = function (k, v) LM.UIFilter.SetGroupFilter(k, v) end,
        setall = function (v) LM.UIFilter.SetAllGroupFilters(v) end,
        menulist = function () return LM.UIFilter.GetGroups() end,
        gettext = function (k) return LM.UIFilter.GetGroupText(k) end,
    },
    ['FLAG'] = {
        value = 'FLAG',
        text = TYPE,
        checked = function (k) return LM.UIFilter.IsFlagChecked(k) end,
        set = function (k, v) LM.UIFilter.SetFlagFilter(k, v) end,
        setall = function (v) LM.UIFilter.SetAllFlagFilters(v) end,
        menulist = function () return LM.UIFilter.GetFlags() end,
        gettext = function (k) return LM.UIFilter.GetFlagText(k) end,
    },
    ['FAMILY'] = {
        value = 'FAMILY',
        text = L.LM_FAMILY,
        checked = function (k) return LM.UIFilter.IsFamilyChecked(k) end,
        set = function (k, v) LM.UIFilter.SetFamilyFilter(k, v) end,
        setall = function (v) LM.UIFilter.SetAllFamilyFilters(v) end,
        menulist = function () return LM.UIFilter.GetFamilies() end,
        gettext = function (k) return LM.UIFilter.GetFamilyText(k) end,
    },
    ['SOURCES'] = {
        value = 'SOURCES',
        text = SOURCES,
        checked = function (k) return LM.UIFilter.IsSourceChecked(k) end,
        set = function (k, v) LM.UIFilter.SetSourceFilter(k, v) end,
        setall = function (v) LM.UIFilter.SetAllSourceFilters(v) end,
        menulist = function () return LM.UIFilter.GetSources() end,
        gettext = function (k) return LM.UIFilter.GetSourceText(k) end,
    },
    ['SORTBY'] = {
        value = 'SORTBY',
        text = BLUE_FONT_COLOR:WrapTextInColorCode(RAID_FRAME_SORT_LABEL),
        checked = function (k) return LM.UIFilter.GetSortKey() == k end,
        set = function (k) LM.UIFilter.SetSortKey(k) end,
        menulist = function () return LM.UIFilter.GetSortKeys() end,
        gettext = function (k) return LM.UIFilter.GetSortKeyText(k) end,
    },
}

local function InitDropDownSection(template, self, level, menuList)

    local info = LibDD:UIDropDownMenu_CreateInfo()
    info.keepShownOnClick = true
    info.isNotRadio = true

    if level == 1 then
        if not template.menulist then
            info.text = template.text
            info.func = function (_, _, _, v) template.set(v) end
            info.checked = function () return template.checked() end
            LibDD:UIDropDownMenu_AddButton(info, level)
        else
            info.hasArrow = true
            info.notCheckable = true
            info.text = template.text
            info.value = template.value
            info.menuList = template.menulist()
            LibDD:UIDropDownMenu_AddButton(info, level)
        end
        return
    end

    if level == 2 and template.setall then
        info.notCheckable = true
        info.text = CHECK_ALL
        info.func = function ()
                template.setall(true)
                LibDD:UIDropDownMenu_Refresh(self, nil, level)
            end
        LibDD:UIDropDownMenu_AddButton(info, level)

        info.text = UNCHECK_ALL
        info.func = function ()
                template.setall(false)
                LibDD:UIDropDownMenu_Refresh(self, nil, level)
            end
        LibDD:UIDropDownMenu_AddButton(info, level)

        -- UIDropDownMenu_AddSeparator(level)
    end

    info.notCheckable = nil

    -- The complicated stride calc is because the %s...%s entries are super
    -- annoying and so we want to max out the number of entries in the leafs
    -- but still need to make sure each menu is small enough.

    if #menuList > MENU_SPLIT_SIZE * 1.5 then
        info.notCheckable = true
        info.hasArrow = true
        info.func = nil

        local stride = 1
        while #menuList/stride > MENU_SPLIT_SIZE do stride = stride * MENU_SPLIT_SIZE end

        for i = 1, #menuList, stride do
            local j = math.min(#menuList, i+stride-1)
            info.menuList = LM.tSlice(menuList, i, j)
            local f = template.gettext(info.menuList[1])
            if i + stride < #menuList then
                info.text = f .. " ..."
            else
                info.text = f
            end
            --local t = template.gettext(info.menuList[#info.menuList])
            --info.text = format('%s...%s', f, t)
            info.value = template.value
            LibDD:UIDropDownMenu_AddButton(info, level)
        end
    else
        for _, k in ipairs(menuList) do
            info.text = template.gettext(k)
            info.arg1 = k
            info.func = function (_, _, _, v)
                    if IsShiftKeyDown() then
                        template.setall(false)
                        template.set(k, true)
                    else
                        template.set(k, v)
                    end
                    LibDD:UIDropDownMenu_Refresh(self, nil, level)
                end
            info.checked = function ()
                    return template.checked(k)
                end
            LibDD:UIDropDownMenu_AddButton(info, level)
        end
    end
end

function LiteMountFilterButtonMixin:Initialize(level, menuList)
    if level == nil then return end

    if level == 1 then
        ---- 1. COLLECTED ----
        InitDropDownSection(DROPDOWNS.COLLECTED, self, level, menuList)

        ---- 2. NOT COLLECTED ----
        InitDropDownSection(DROPDOWNS.NOT_COLLECTED, self, level, menuList)

        ---- 3. UNUSABLE ----
        InitDropDownSection(DROPDOWNS.UNUSABLE, self, level, menuList)

        ---- 4. HIDDEN ----
        InitDropDownSection(DROPDOWNS.HIDDEN, self, level, menuList)

        ---- 5. FLAG ----
        InitDropDownSection(DROPDOWNS.FLAG, self, level, menuList)

        ---- 6. TYPENAME ----
        InitDropDownSection(DROPDOWNS.TYPENAME, self, level, menuList)
		
        ---- 7. GROUP ----
        InitDropDownSection(DROPDOWNS.GROUP, self, level, menuList)

        ---- 8. FAMILY ----
        if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
            InitDropDownSection(DROPDOWNS.FAMILY, self, level, menuList)
        end

        ---- 9. SOURCES ----
        if WOW_PROJECT_ID == WOW_PROJECT_MAINLINE then
            InitDropDownSection(DROPDOWNS.SOURCES, self, level, menuList)
        end

        ---- 10. PRIORITY ----
        InitDropDownSection(DROPDOWNS.PRIORITY, self, level, menuList)

        ---- 11. SORTBY ----
        InitDropDownSection(DROPDOWNS.SORTBY, self, level, menuList)
    else
        InitDropDownSection(DROPDOWNS[L_UIDROPDOWNMENU_MENU_VALUE], self, level, menuList)
    end
end

function LiteMountFilterButtonMixin:OnShow()
    LibDD:UIDropDownMenu_Initialize(self.FilterDropDown, self.Initialize, "MENU")
end

function LiteMountFilterButtonMixin:OnLoad()
    LibDD:Create_UIDropDownMenu(self.FilterDropDown)
end
