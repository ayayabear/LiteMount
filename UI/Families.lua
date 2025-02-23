--[[----------------------------------------------------------------------------

  LiteMount/UI/Families.lua

  Options frame for mount families.

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...

local L = LM.Localize

--[[------------------------------------------------------------------------]]--

StaticPopupDialogs["LM_OPTIONS_RESET_FAMILY"] = {
    text = format("Reset", L.LM_RESET_FAMILY or " Family?"),
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
    hideOnEscape = 1,
    OnAccept = function (self)
            LiteMountFamiliesPanel.Families.isDirty = true
            LM.Options:ResetFamilyToDefault(self.data)
            LiteMountFamiliesPanel:Update()
            self:Hide() -- Auto-close the dialog
        end,
    OnShow = function (self)
            self.text:SetText(format("LiteMount : %s : %s", L.LM_RESET_FAMILY or "Reset Family", self.data))
    end
}

--[[------------------------------------------------------------------------]]--

-- Create a popup dialog for exporting family data
StaticPopupDialogs["LM_EXPORT_FAMILIES"] = {
    text = "LiteMount : Export Families",
    button1 = CLOSE,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    hasEditBox = 1,
    enterClicksFirstButton = false,
    editBoxWidth = 350,
    OnShow = function(self)
        local exportString = LM.Options:ExportFamilies()
        self.editBox:SetText(exportString)
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end,
    EditBoxOnTextChanged = function(self)
        -- Prevent editing
        self:SetText(LM.Options:ExportFamilies())
        self:HighlightText()
    end,
    EditBoxOnEscapePressed = function(self)
        StaticPopup_Hide("LM_EXPORT_FAMILIES")
    end,
}

-- Create a popup dialog for importing family data
StaticPopupDialogs["LM_IMPORT_FAMILIES"] = {
    text = "LiteMount : Import Families\n\nPaste your import string below:",
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
        local success, message = LM.Options:ImportFamilies(importString)
        if success then
            LM.Print("Families imported successfully.")
            LiteMountFamiliesPanel:Update()
        else
            LM.Print("Import failed: " .. (message or "Unknown error"))
        end
        -- Close the dialog
        self:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        StaticPopup_Hide("LM_IMPORT_FAMILIES")
    end,
}
--[[------------------------------------------------------------------------]]--

function LM.Options:CountFamilies()
    local count = 0
    for f, mounts in pairs(LM.db.profile.families or {}) do
        local mountCount = 0
        for _ in pairs(mounts) do mountCount = mountCount + 1 end
        if mountCount > 0 then count = count + 1 end
    end
    return count
end

LiteMountFamiliesPanelMixin = {}

function LiteMountFamiliesPanelMixin:OnLoad()
    self.name = "Families"
    self.showAll = false
    
    -- Create Export button
    self.ExportButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    self.ExportButton:SetSize(80, 22)
    self.ExportButton:SetPoint("TOPRIGHT", -250, -16)
    self.ExportButton:SetText("Export")
    self.ExportButton:SetScript("OnClick", function() StaticPopup_Show("LM_EXPORT_FAMILIES") end)
    
    -- Create Import button
    self.ImportButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    self.ImportButton:SetSize(80, 22)
    self.ImportButton:SetPoint("RIGHT", self.ExportButton, "LEFT", -8, 0)
    self.ImportButton:SetText("Import")
    self.ImportButton:SetScript("OnClick", function() StaticPopup_Show("LM_IMPORT_FAMILIES") end)

    LiteMountOptionsPanel_RegisterControl(self.Families)
    LiteMountOptionsPanel_RegisterControl(self.Mounts)
    LiteMountOptionsPanel_OnLoad(self)
end

function LiteMountFamiliesPanelMixin:Update()
    -- This is the missing method
    self.Families:Update()
    self.Mounts:Update()
    self.ShowAll:SetChecked(self.showAll)
end

function LiteMountFamiliesPanelMixin:OnShow()
    LiteMountFilter:Attach(self, 'BOTTOMLEFT', self.Mounts, 'TOPLEFT', 0, 15)
    LM.UIFilter.RegisterCallback(self, "OnFilterChanged", "OnRefresh")
    self:Update()
    LiteMountOptionsPanel_OnShow(self)
end

function LiteMountFamiliesPanelMixin:OnHide()
    -- Clear search and filter state
    if LiteMountFilter.Search then
        LiteMountFilter.Search:SetText("")
    end
    self.searchText = nil
    
    LM.UIFilter.UnregisterAllCallbacks(self)
    LiteMountOptionsPanel_OnHide(self)
end

function LiteMountFamiliesPanelMixin:OnRefresh()
    self:Update()
end

function LiteMountFamiliesPanelMixin:ShowExportDialog()
    StaticPopup_Show("LM_EXPORT_FAMILIES")
end

function LiteMountFamiliesPanelMixin:ShowImportDialog()
    StaticPopup_Show("LM_IMPORT_FAMILIES")
end

function LiteMountFamiliesPanelMixin:ResetFamilyToDefault()
    local familyName = self.Families.selectedFamily
    if familyName then
        LM.Options:ResetFamilyToDefault(familyName)
        self:Update()
    end
end

--[[------------------------------------------------------------------------]]--

LiteMountFamiliesPanelFamilyMixin = {}

function LiteMountFamiliesPanelFamilyMixin:OnClick()
    if self.family then
        LiteMountFamiliesPanel.Families.selectedFamily = self.family
        LiteMountFamiliesPanel:Update()
    end
end

function LM.Options:IsMountInFamily(mount, family)

    -- First check if the mount is in the official family list from FamilyInfo.lua
    if mount.spellID and LM.MOUNTFAMILY[family] and LM.MOUNTFAMILY[family][mount.spellID] then

        -- Check if it's been explicitly excluded by the user
        local families = self:GetFamilies()
        if families[family] and families[family][mount.spellID] == false then
            return false
        end
        return true
    end

    -- Then check if the user added the mount to the family
    local families = self:GetFamilies()
    if families[family] and families[family][mount.spellID] == true then
        return true
    end

    return false
end
--[[------------------------------------------------------------------------]]--

LiteMountFamiliesPanelFamiliesMixin = {}

function LiteMountFamiliesPanelFamiliesMixin:Update()
    if not self.buttons then return end

    local offset = HybridScrollFrame_GetOffset(self)
    local allFamilies = LM.UIFilter.GetFamilies()

    -- Get the search text
    local searchText = LiteMountFamiliesPanel.searchText or ""

    -- Filter families by search text but retain current selection
    local filteredFamilies = {}
    local currentSelectionFound = false

    for _, family in ipairs(allFamilies) do
        if family == self.selectedFamily or
           searchText == "" or
           strfind(string.lower(family), string.lower(searchText), 1, true) then
            table.insert(filteredFamilies, family)
        end
        if family == self.selectedFamily then
            currentSelectionFound = true
        end
    end

    -- Only clear selection if there's no search text
    if searchText == "" and not currentSelectionFound then
        self.selectedFamily = nil
    end

    -- Sort filtered families
    table.sort(filteredFamilies)

    local totalHeight = #filteredFamilies * (self.buttons[1]:GetHeight() + 1)
    local displayedHeight = #self.buttons * self.buttons[1]:GetHeight()

    for i = 1, #self.buttons do
        local button = self.buttons[i]
        local index = offset + i
        if index <= #filteredFamilies then
            local familyText = L[filteredFamilies[index]] or filteredFamilies[index]
            button.Text:SetFormattedText(familyText)
            button.Text:Show()
            button:Show()
            button.family = filteredFamilies[index]

            -- Handle selection visibility
            button.SelectedTexture:SetShown(button.family == self.selectedFamily)
            button.SelectedArrow:SetShown(button.family == self.selectedFamily)
        else
            button:Hide()
            button.family = nil
        end
    end

    HybridScrollFrame_Update(self, totalHeight, displayedHeight)
end

function LiteMountFamiliesPanelFamiliesMixin:OnSizeChanged()
    HybridScrollFrame_CreateButtons(self, 'LiteMountFamiliesPanelFamilyTemplate')
    for _, b in ipairs(self.buttons) do
        b:SetWidth(self:GetWidth())
    end
end

function LiteMountFamiliesPanelFamiliesMixin:OnLoad()
    self.scrollBar:ClearAllPoints()
    self.scrollBar:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -16)
    self.scrollBar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 16)
    local track = _G[self.scrollBar:GetName().."Track"]
    track:Hide()
    self.update = self.Update
end

function LiteMountFamiliesPanelFamiliesMixin:GetOption()
    -- Family data is stored in the options
    local families = LM.Options:GetFamilies()
    return CopyTable(families)
end

function LiteMountFamiliesPanelFamiliesMixin:SetOption(v)
    LM.Options:SetFamilies(v)
end

function LiteMountFamiliesPanelFamiliesMixin:SetControl(v)
    self:Update()
end

--[[------------------------------------------------------------------------]]--

LiteMountFamiliesPanelMountMixin = {}

function LiteMountFamiliesPanelMountMixin:OnClick()
    LM.Debug("Mount clicked: " .. (self.mount and self.mount.name or "unknown"))
    LM.Debug("Mount spellID: " .. tostring(self.mount.spellID))
    local family = LiteMountFamiliesPanel.Families.selectedFamily
    if not family or not self.mount then
        return
    end

    if LM.Options:IsMountInFamily(self.mount, family) then
        LM.Options:RemoveMountFromFamily(self.mount, family)
    else
        LM.Options:AddMountToFamily(self.mount, family)
    end

    LiteMountFamiliesPanel.Mounts:Update()
end


function LiteMountFamiliesPanelMountMixin:OnEnter()
    if self.mount then
        LiteMountTooltip:SetOwner(self, "ANCHOR_RIGHT", -16, 0)
        LiteMountTooltip:SetMount(self.mount)
    end
end

function LiteMountFamiliesPanelMountMixin:OnLeave()
    LiteMountTooltip:Hide()
end

function LiteMountFamiliesPanelMountMixin:SetMount(mount, family)
    self.mount = mount

    self.Name:SetText(mount.name)
    
    local inFamily = family and LM.Options:IsMountInFamily(mount, family)
    LM.Debug("SetMount: " .. mount.name .. " in family " .. (family or "nil") .. ": " .. tostring(inFamily))
    
    if inFamily then
        self.Checked:Show()
    else
        self.Checked:Hide()
    end

    if not mount:IsCollected() then
        self.Name:SetFontObject("GameFontDisableSmall")
    else
        self.Name:SetFontObject("GameFontNormalSmall")
    end
end
--[[------------------------------------------------------------------------]]--

LiteMountFamiliesPanelMountScrollMixin = {}

function LiteMountFamiliesPanelMountScrollMixin:GetDisplayedMountList(family)
    if not family then
        return LM.MountList:New()
    end

    local mounts = LM.UIFilter.GetFilteredMountList()
    -- Filter out groups and families
    local mountsOnly = mounts:Search(function(m) return not (m.isGroup or m.isFamily) end)
    
    local searchText = LiteMountFamiliesPanel.searchText or ""
    
    local function sortByName(a, b)
        return a.name < b.name
    end
    
    -- If not showing all and not searching, only show family mounts
    if not LiteMountFamiliesPanel.showAll and searchText == "" then
        local result = mountsOnly:Search(function(m) return LM.Options:IsMountInFamily(m, family) end)
        table.sort(result, sortByName)
        return result
    end
    
    -- If searching, show mounts that either:
    -- 1. Belong to selected family OR
    -- 2. Match search term
    if searchText ~= "" then
        local result = mountsOnly:Search(function(m)
            local inFamily = LM.Options:IsMountInFamily(m, family)
            local matchesSearch = strfind(m.name:lower(), searchText:lower(), 1, true)
            return inFamily or matchesSearch
        end)
        table.sort(result, sortByName)
        return result
    end
    
    table.sort(mountsOnly, sortByName)
    return mountsOnly
end

function LiteMountFamiliesPanelMountScrollMixin:Update()
    if not self.buttons then return end

    local offset = HybridScrollFrame_GetOffset(self)

    local family = LiteMountFamiliesPanel.Families.selectedFamily
    local mounts = self:GetDisplayedMountList(family)

    for i, button in ipairs(self.buttons) do
        local index = ( offset + i - 1 ) * 2 + 1
        if index > #mounts then
            button:Hide()
        else
            button.mount1:SetMount(mounts[index], family)
            if button.mount1:IsMouseOver() then button.mount1:OnEnter() end
            if mounts[index+1] then
                button.mount2:SetMount(mounts[index+1], family)
                button.mount2:Show()
                if button.mount2:IsMouseOver() then button.mount2:OnEnter() end
            else
                button.mount2:Hide()
            end
            button:Show()
        end
    end

    local totalHeight = math.ceil(#mounts/2) * self.buttons[1]:GetHeight()
    local displayedHeight = #self.buttons * self.buttons[1]:GetHeight()

    HybridScrollFrame_Update(self, totalHeight, displayedHeight)
end

function LiteMountFamiliesPanelMountScrollMixin:OnSizeChanged()
    HybridScrollFrame_CreateButtons(self, 'LiteMountFamiliesPanelButtonTemplate')
    for _, b in ipairs(self.buttons) do
        b:SetWidth(self:GetWidth())
    end
end

function LiteMountFamiliesPanelMountScrollMixin:OnLoad()
    local track = _G[self.scrollBar:GetName().."Track"]
    track:Hide()
    self.update = self.Update
end

function LiteMountFamiliesPanelMountScrollMixin:SetControl(v)
    self:Update()
end


-- Add these functions to Options.lua for group import/export

function LM.Options:ExportGroups()
    local profileGroups, globalGroups = self:GetRawGroups()
    
    -- Create a distinctly different format from families export
    local exportData = {
        version = 1,
        date = date("%Y-%m-%d %H:%M:%S"),
        type = "groups",  -- Explicit type marker to distinguish from families
        profileGroups = {},
        globalGroups = {}
    }
    
    -- Export profile groups
    for groupName, mounts in pairs(profileGroups) do
        exportData.profileGroups[groupName] = {}
        for spellID in pairs(mounts) do
            -- Store as strings to ensure compatibility when importing
            exportData.profileGroups[groupName][tostring(spellID)] = true
        end
    end
    
    -- Export global groups
    for groupName, mounts in pairs(globalGroups) do
        exportData.globalGroups[groupName] = {}
        for spellID in pairs(mounts) do
            exportData.globalGroups[groupName][tostring(spellID)] = true
        end
    end
    
    -- Serialize and compress
    local serialized = LibStub("AceSerializer-3.0"):Serialize(exportData)
    local compressed = LibStub("LibDeflate"):CompressDeflate(serialized)
    local encoded = LibStub("LibDeflate"):EncodeForPrint(compressed)
    
    return encoded
end

function LM.Options:ImportGroups(importString)
    -- Decode and decompress
    local decoded = LibStub("LibDeflate"):DecodeForPrint(importString)
    if not decoded then
        return false, "Failed to decode import string"
    end
    
    local decompressed = LibStub("LibDeflate"):DecompressDeflate(decoded)
    if not decompressed then
        return false, "Failed to decompress data"
    end
    
    local success, importData = LibStub("AceSerializer-3.0"):Deserialize(decompressed)
    if not success then
        return false, "Failed to deserialize data"
    end
    
    -- Validate the import data and ensure it's a groups export
    if not importData.version or not importData.type or importData.type ~= "groups" then
        return false, "Invalid import data or not a groups export"
    end
    
    -- Get current groups
    local profileGroups, globalGroups = self:GetRawGroups()
    
    -- Clear existing groups
    table.wipe(profileGroups)
    table.wipe(globalGroups)
    
    -- Import profile groups
    local profileCount = 0
    if importData.profileGroups then
        for groupName, mounts in pairs(importData.profileGroups) do
            profileCount = profileCount + 1
            profileGroups[groupName] = {}
            for spellID in pairs(mounts) do
                profileGroups[groupName][tonumber(spellID)] = true
            end
        end
    end
    
    -- Import global groups
    local globalCount = 0
    if importData.globalGroups then
        for groupName, mounts in pairs(importData.globalGroups) do
            globalCount = globalCount + 1
            globalGroups[groupName] = {}
            for spellID in pairs(mounts) do
                globalGroups[groupName][tonumber(spellID)] = true
            end
        end
    end
    
    -- Update groups
    self:SetRawGroups(profileGroups, globalGroups)
    
    return true, string.format("Successfully imported %d profile groups and %d global groups", profileCount, globalCount)
end