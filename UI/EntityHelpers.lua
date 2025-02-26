--[[----------------------------------------------------------------------------

  LiteMount/UI/EntityHelpers.lua

  Shared helper functions for Group and Family UI panels.
  This contains common functionality to reduce code duplication.

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...

local L = LM.Localize

LM.EntityHelpers = {}

--[[----------------------------------------------------------------------------
  Common Dialog Templates
----------------------------------------------------------------------------]]--

-- Create an import dialog for either groups or families
function LM.EntityHelpers.CreateImportDialog(isGroup)
    local entityType = isGroup and "Groups" or "Families"
    local dialogName = "LM_IMPORT_" .. string.upper(entityType)
    
    StaticPopupDialogs[dialogName] = {
        text = "LiteMount : Import " .. entityType .. "\n\nPaste your import string below:",
        button1 = ACCEPT,
        button2 = CANCEL,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        hasEditBox = 1,
        enterClicksFirstButton = true,
        editBoxWidth = 350,
        OnShow = function(self)
            self.editBox:SetText("")
            self.editBox:SetFocus()
        end,
        OnAccept = function(self)
            local importString = self.editBox:GetText()
            local success, message
            
            if isGroup then
                success, message = LM.Options:ImportGroups(importString)
                if success then
                    LM.Print("Groups imported successfully.")
                    LiteMountGroupsPanel:Update()
                end
            else
                success, message = LM.Options:ImportFamilies(importString)
                if success then
                    LM.Print("Families imported successfully.")
                    LiteMountFamiliesPanel:Update()
                end
            end
            
            if not success then
                LM.Print("Import failed: " .. (message or "Unknown error"))
            end
            
            -- Close the dialog
            self:Hide()
        end,
        EditBoxOnEscapePressed = function(self)
            StaticPopup_Hide(dialogName)
        end,
    }
end

-- Create an export dialog for either groups or families
function LM.EntityHelpers.CreateExportDialog(isGroup)
    local entityType = isGroup and "Groups" or "Families"
    local dialogName = "LM_EXPORT_" .. string.upper(entityType)
    
    StaticPopupDialogs[dialogName] = {
        text = "LiteMount : Export " .. entityType,
        button1 = CLOSE,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1,
        hasEditBox = 1,
        enterClicksFirstButton = false,
        editBoxWidth = 350,
        OnShow = function(self)
            local exportString
            if isGroup then
                exportString = LM.Options:ExportGroups()
            else
                exportString = LM.Options:ExportFamilies()
            end
            
            self.editBox:SetText(exportString)
            self.editBox:SetFocus()
            self.editBox:HighlightText()
        end,
        EditBoxOnTextChanged = function(self)
            -- Prevent editing
            local exportString
            if isGroup then
                exportString = LM.Options:ExportGroups()
            else
                exportString = LM.Options:ExportFamilies()
            end
            self:SetText(exportString)
            self:HighlightText()
        end,
        EditBoxOnEscapePressed = function(self)
            StaticPopup_Hide(dialogName)
        end,
    }
end

--[[----------------------------------------------------------------------------
  Mount List Functions
----------------------------------------------------------------------------]]--

-- Get a list of mounts for either a group or family panel
function LM.EntityHelpers.GetDisplayedMountList(panel, entityName, isGroup)
    if not entityName then
        return LM.MountList:New()
    end

    local mounts = LM.UIFilter.GetFilteredMountList()
    -- Filter out groups and families
    local mountsOnly = mounts:Search(function(m) return not (m.isGroup or m.isFamily) end)
    
    local searchText = panel.searchText or ""
    
    local function sortByName(a, b)
        return a.name < b.name
    end
    
    -- If not showing all and not searching, only show entity mounts
    if not panel.showAll and searchText == "" then
        local result
        if isGroup then
            result = mountsOnly:Search(function(m) return LM.Options:IsMountInGroup(m, entityName) end)
        else
            result = mountsOnly:Search(function(m) return LM.Options:IsMountInFamily(m, entityName) end)
        end
        table.sort(result, sortByName)
        return result
    end
    
    -- If searching, show mounts that either belong to entity OR match search
    if searchText ~= "" then
        local result = mountsOnly:Search(function(m)
            local inEntity
            if isGroup then
                inEntity = LM.Options:IsMountInGroup(m, entityName)
            else
                inEntity = LM.Options:IsMountInFamily(m, entityName)
            end
            local matchesSearch = strfind(m.name:lower(), searchText:lower(), 1, true)
            return inEntity or matchesSearch
        end)
        table.sort(result, sortByName)
        return result
    end
    
    -- If showing all, return all mounts sorted
    table.sort(mountsOnly, sortByName)
    return mountsOnly
end

-- Update a mount scroll frame for either panel
function LM.EntityHelpers.UpdateMountScroll(scroll, entityName, isGroup)
    if not scroll.buttons then return end

    local offset = HybridScrollFrame_GetOffset(scroll)
    local panel = scroll:GetParent()
    local mounts = LM.EntityHelpers.GetDisplayedMountList(panel, entityName, isGroup)

    for i, button in ipairs(scroll.buttons) do
        local index = (offset + i - 1) * 2 + 1
        if index > #mounts then
            button:Hide()
        else
            -- Set first mount
            if isGroup then
                button.mount1:SetMount(mounts[index], entityName)
            else
                button.mount1:SetMount(mounts[index], entityName)
            end
            
            if button.mount1:IsMouseOver() then button.mount1:OnEnter() end
            
            -- Set second mount if exists
            if mounts[index+1] then
                if isGroup then
                    button.mount2:SetMount(mounts[index+1], entityName)
                else
                    button.mount2:SetMount(mounts[index+1], entityName)
                end
                button.mount2:Show()
                if button.mount2:IsMouseOver() then button.mount2:OnEnter() end
            else
                button.mount2:Hide()
            end
            
            button:Show()
        end
    end

    local totalHeight = math.ceil(#mounts/2) * scroll.buttons[1]:GetHeight()
    local displayedHeight = #scroll.buttons * scroll.buttons[1]:GetHeight()

    HybridScrollFrame_Update(scroll, totalHeight, displayedHeight)
end

--[[----------------------------------------------------------------------------
  Entity List Functions
----------------------------------------------------------------------------]]--

-- Filter an entity list by search text
function LM.EntityHelpers.FilterEntityList(allEntities, selectedEntity, searchText)
    local filteredEntities = {}
    local currentSelectionFound = false

    for _, entity in ipairs(allEntities) do
        if entity == selectedEntity or
           searchText == "" or
           strfind(string.lower(entity), string.lower(searchText), 1, true) then
            table.insert(filteredEntities, entity)
        end
        if entity == selectedEntity then
            currentSelectionFound = true
        end
    end

    -- Only clear selection if there's no search text
    if searchText == "" and not currentSelectionFound then
        selectedEntity = nil
    end

    -- Sort filtered entities
    table.sort(filteredEntities)
    
    return filteredEntities, selectedEntity
end

-- Update an entity list scroll frame
function LM.EntityHelpers.UpdateEntityList(scroll, entities, selectedEntity, isGroup)
    if not scroll.buttons then return end

    local offset = HybridScrollFrame_GetOffset(scroll)
    
    -- Update scroll frame
    local totalHeight = #entities * (scroll.buttons[1]:GetHeight() + 1)
    local displayedHeight = #scroll.buttons * scroll.buttons[1]:GetHeight()

    -- Update buttons
    for i = 1, #scroll.buttons do
        local button = scroll.buttons[i]
        local index = offset + i
        if index <= #entities then
            local entityText = entities[index]
            
            -- Format text based on entity type
            if isGroup and LM.Options:IsGlobalGroup(entityText) then
                entityText = BLUE_FONT_COLOR:WrapTextInColorCode(entityText)
            elseif not isGroup then
                entityText = L[entityText] or entityText
            end
            
            button.Text:SetFormattedText(entityText)
            button.Text:Show()
            button:Show()
            
            -- Set entity reference
            if isGroup then
                button.group = entities[index]
                button.family = nil
            else
                button.family = entities[index]
                button.group = nil
            end

            -- Handle selection visibility
            local isSelected = isGroup and button.group == selectedEntity or 
                               not isGroup and button.family == selectedEntity
            button.SelectedTexture:SetShown(isSelected)
            button.SelectedArrow:SetShown(isSelected)
        else
            button:Hide()
            button.group = nil
            button.family = nil
        end
    end

    HybridScrollFrame_Update(scroll, totalHeight, displayedHeight)
end

--[[----------------------------------------------------------------------------
  Panel Helper Functions
----------------------------------------------------------------------------]]--

-- Initialize export/import buttons for a panel
function LM.EntityHelpers.InitializeExportImportButtons(panel, isGroup)
    local entityType = isGroup and "Groups" or "Families"
    
    -- Create Export button
    panel.ExportButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.ExportButton:SetSize(80, 22)
    panel.ExportButton:SetPoint("TOPRIGHT", -250, -16)
    panel.ExportButton:SetText("Export")
    panel.ExportButton:SetScript("OnClick", function() 
        StaticPopup_Show("LM_EXPORT_" .. string.upper(entityType)) 
    end)
    
    -- Create Import button
    panel.ImportButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    panel.ImportButton:SetSize(80, 22)
    panel.ImportButton:SetPoint("RIGHT", panel.ExportButton, "LEFT", -8, 0)
    panel.ImportButton:SetText("Import")
    panel.ImportButton:SetScript("OnClick", function() 
        StaticPopup_Show("LM_IMPORT_" .. string.upper(entityType)) 
    end)
    
    -- Create the dialogs if needed
    if not StaticPopupDialogs["LM_EXPORT_" .. string.upper(entityType)] then
        LM.EntityHelpers.CreateExportDialog(isGroup)
    end
    
    if not StaticPopupDialogs["LM_IMPORT_" .. string.upper(entityType)] then
        LM.EntityHelpers.CreateImportDialog(isGroup)
    end
end

-- Standard panel setup procedures
function LM.EntityHelpers.SetupEntityPanel(panel, isGroup)
    -- Initialize export/import
    LM.EntityHelpers.InitializeExportImportButtons(panel, isGroup)
    
    -- Set up standard event handlers
    panel:SetScript("OnShow", function(self)
        -- Clear any existing search
        if LiteMountFilter.Search then
            LiteMountFilter.Search:SetText("")
        end
        
        -- Attach filter UI
        LiteMountFilter:Attach(self, 'BOTTOMLEFT', self.Mounts, 'TOPLEFT', 0, 15)
        
        -- Register for filter changes
        LM.UIFilter.RegisterCallback(self, "OnFilterChanged", "OnRefresh")
        
        -- Update the UI
        self:Update()
        LiteMountOptionsPanel_OnShow(self)
    end)
    
    panel:SetScript("OnHide", function(self)
        -- Clear search and filter state
        if LiteMountFilter.Search then
            LiteMountFilter.Search:SetText("")
        end
        self.searchText = nil
        
        -- Unregister callbacks
        LM.UIFilter.UnregisterAllCallbacks(self)
        LiteMountOptionsPanel_OnHide(self)
    end)
    
    -- Add refresh handler
    panel.OnRefresh = function(self)
        self:Update()
    end
end