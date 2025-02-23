--[[----------------------------------------------------------------------------

  LiteMount/UI/Groups.lua

  Options frame to plug in to the Blizzard interface menu.

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...

local L = LM.Localize

--[[------------------------------------------------------------------------]]--

-- Group names can't match anything that LM.Mount:MatchesOneFilter will parse
-- as something other than a group. Don't care about mount names though that
-- should be obvious to people as something that won't work.

local function IsValidGroupName(text)
    if not text or text == "" then return false end
    if LM.Options:IsFlag(text) then return false end
    if LM.Options:IsGroup(text) then return false end
    if tonumber(text) then return false end
    if text:find(':') then return false end
    if text:sub(1, 1) == '~' then return false end
    return true
end

StaticPopupDialogs["LM_OPTIONS_NEW_GROUP"] = {
    text = format("LiteMount : %s", L.LM_NEW_GROUP),
    button1 = L.LM_CREATE_PROFILE_GROUP,    -- Note: OnAccept
    button2 = L.LM_CREATE_GLOBAL_GROUP,     -- Note: OnCancel (ugh)
    button3 = CANCEL,                       -- Note: OnAlt
    hasEditBox = 1,
    maxLetters = 24,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
    hideOnEscape = 1,
    OnAccept = function (self)
            LiteMountGroupsPanel.Groups.isDirty = true
            local text = self.editBox:GetText()
            LiteMountGroupsPanel.Groups.selectedGroup = text
            LM.Options:CreateGroup(text)
        end,
    -- This is not "Cancel", it's "Global" == button2
    OnCancel = function (self)
            LiteMountGroupsPanel.Groups.isDirty = true
            local text = self.editBox:GetText()
            LiteMountGroupsPanel.Groups.selectedGroup = text
            LM.Options:CreateGroup(text, true)
        end,
    -- This is cancel (button3)
    OnAlt = function (self) end,
    EditBoxOnEnterPressed = function (self)
            if self:GetParent().button1:IsEnabled() then
                StaticPopup_OnClick(self:GetParent(), 1)
            end
        end,
    EditBoxOnEscapePressed = function (self)
            self:GetParent():Hide()
        end,
    EditBoxOnTextChanged = function (self)
            local text = self:GetText()
            local valid = IsValidGroupName(text)
            self:GetParent().button1:SetEnabled(valid)
            self:GetParent().button2:SetEnabled(valid)
        end,
    OnShow = function (self)
        self.editBox:SetFocus()
    end,
}

StaticPopupDialogs["LM_OPTIONS_RENAME_GROUP"] = {
    text = format("LiteMount : %s", L.LM_RENAME_GROUP),
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = 24,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
    hideOnEscape = 1,
    OnAccept = function (self)
            LiteMountGroupsPanel.Groups.isDirty = true
            local text = self.editBox:GetText()
            LiteMountGroupsPanel.Groups.selectedGroup = text
            LM.Options:RenameGroup(self.data, text)
        end,
    EditBoxOnEnterPressed = function (self)
            if self:GetParent().button1:IsEnabled() then
                StaticPopup_OnClick(self:GetParent(), 1)
            end
        end,
    EditBoxOnEscapePressed = function (self)
            self:GetParent():Hide()
        end,
    EditBoxOnTextChanged = function (self)
            local text = self:GetText()
            local valid = text ~= self.data and IsValidGroupName(text)
            self:GetParent().button1:SetEnabled(valid)
        end,
    OnShow = function (self)
        self.editBox:SetFocus()
    end,
}

StaticPopupDialogs["LM_OPTIONS_DELETE_GROUP"] = {
    text = format("LiteMount : %s", L.LM_DELETE_GROUP),
    button1 = ACCEPT,
    button2 = CANCEL,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
    hideOnEscape = 1,
    OnAccept = function (self)
            LiteMountGroupsPanel.Groups.isDirty = true
            LM.Options:DeleteGroup(self.data)
        end,
    OnShow = function (self)
            self.text:SetText(format("LiteMount : %s : %s", L.LM_DELETE_GROUP, self.data))
    end
}


StaticPopupDialogs["LM_EXPORT_GROUPS"] = {
    text = "LiteMount : Export Groups",
    button1 = CLOSE,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    hasEditBox = 1,
    enterClicksFirstButton = false,
    editBoxWidth = 350,
    OnShow = function(self)
        local exportString = LM.Options:ExportGroups()
        self.editBox:SetText(exportString)
        self.editBox:SetFocus()
        self.editBox:HighlightText()
    end,
    EditBoxOnTextChanged = function(self)
        -- Prevent editing
        self:SetText(LM.Options:ExportGroups())
        self:HighlightText()
    end,
    EditBoxOnEscapePressed = function(self)
        StaticPopup_Hide("LM_EXPORT_GROUPS")
    end,
}

-- Create a popup dialog for importing group data
StaticPopupDialogs["LM_IMPORT_GROUPS"] = {
    text = "LiteMount : Import Groups\n\nPaste your import string below:",
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
        local success, message = LM.Options:ImportGroups(importString)
        if success then
            LM.Print("Groups imported successfully.")
            LiteMountGroupsPanel:Update()
        else
            LM.Print("Import failed: " .. (message or "Unknown error"))
        end
        -- Close the dialog
        self:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        StaticPopup_Hide("LM_IMPORT_GROUPS")
    end,
}

--[[------------------------------------------------------------------------]]--


LiteMountGroupsPanelMixin = {}

function LiteMountGroupsPanelMixin:OnLoad()
    self.showAll = true
    LiteMountOptionsPanel_RegisterControl(self.Groups)
    LiteMountOptionsPanel_RegisterControl(self.Mounts)
    LiteMountOptionsPanel_OnLoad(self)
	
    -- Create Export button
    self.ExportButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    self.ExportButton:SetSize(80, 22)
    self.ExportButton:SetPoint("TOPRIGHT", -250, -16)  
    self.ExportButton:SetText("Export")
    self.ExportButton:SetScript("OnClick", function() self:ShowExportDialog() end)
    
    -- Create Import button
    self.ImportButton = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    self.ImportButton:SetSize(80, 22)
    self.ImportButton:SetPoint("RIGHT", self.ExportButton, "LEFT", -8, 0)
    self.ImportButton:SetText("Import")
    self.ImportButton:SetScript("OnClick", function() self:ShowImportDialog() end)

end

function LiteMountGroupsPanelMixin:OnShow()
    -- Clear any existing search
    if LiteMountFilter.Search then
        LiteMountFilter.Search:SetText("")
    end
    
    LiteMountFilter:Attach(self, 'BOTTOMLEFT', self.Mounts, 'TOPLEFT', 0, 15)
    LM.UIFilter.RegisterCallback(self, "OnFilterChanged", "OnRefresh")
    self:Update()
    LiteMountOptionsPanel_OnShow(self)
end

function LiteMountGroupsPanelMixin:OnHide()
    -- Clear search and filter state
    if LiteMountFilter.Search then
        LiteMountFilter.Search:SetText("")
    end
    self.searchText = nil
    
    LM.UIFilter.UnregisterAllCallbacks(self)
    LiteMountOptionsPanel_OnHide(self)
end

function LiteMountGroupsPanelMixin:Update()
    LM.Debug("Groups Panel: Update called")
    self.Groups:Update()
    self.Mounts:Update()
    self.ShowAll:SetChecked(self.showAll)
    LM.Debug("Groups Panel: Update finished")
end

function LiteMountGroupsPanelMixin:ShowExportDialog()
    StaticPopup_Show("LM_EXPORT_GROUPS")
end

function LiteMountGroupsPanelMixin:ShowImportDialog()
    StaticPopup_Show("LM_IMPORT_GROUPS")
end

--[[------------------------------------------------------------------------]]--

LiteMountGroupsPanelGroupMixin = {}

function LiteMountGroupsPanelGroupMixin:OnClick()
    if self.group then
        LiteMountGroupsPanel.Groups.selectedGroup = self.group
        LiteMountGroupsPanel:Update()
    end
end


--[[------------------------------------------------------------------------]]--

LiteMountGroupsPanelGroupsMixin = {}

function LiteMountGroupsPanelGroupsMixin:Update()
    if not self.buttons then return end

    local offset = HybridScrollFrame_GetOffset(self)
    local allGroups = LM.Options:GetGroupNames()

    -- Get the search text
    local searchText = LiteMountGroupsPanel.searchText or ""

    -- Filter groups by search text
    local filteredGroups = {}
    for _, group in ipairs(allGroups) do
        -- Include group if it matches search OR if it's selected
        if group == self.selectedGroup or
           searchText == "" or 
           strfind(string.lower(group), string.lower(searchText), 1, true) then
            table.insert(filteredGroups, group)
        end
    end

    -- Keep existing selection regardless of search
    local selectedStillExists = false
    for _, group in ipairs(allGroups) do
        if group == self.selectedGroup then
            selectedStillExists = true
            break
        end
    end
    
    -- Only clear selection if group no longer exists at all
    if not selectedStillExists then
        self.selectedGroup = nil
    end

    local totalHeight = (#filteredGroups + 1) * (self.buttons[1]:GetHeight() + 1)
    local displayedHeight = #self.buttons * self.buttons[1]:GetHeight()

    self.AddGroupButton:SetParent(nil)
    self.AddGroupButton:Hide()

    for i = 1, #self.buttons do
        local button = self.buttons[i]
        local index = offset + i
        if index <= #filteredGroups then
            -- Normal group display logic here
            local groupText = filteredGroups[index]
            if LM.Options:IsGlobalGroup(groupText) then
                groupText = BLUE_FONT_COLOR:WrapTextInColorCode(groupText)
            end
            button.Text:SetFormattedText(groupText)
            button.Text:Show()
            button:Show()
            button.group = filteredGroups[index]

            -- Handle selection visibility
            button.SelectedTexture:SetShown(button.group == self.selectedGroup)
            button.SelectedArrow:SetShown(button.group == self.selectedGroup)
        elseif index == #filteredGroups + 1 then
            -- Add button handling
            button.Text:Hide()
            button:Show()
            self.AddGroupButton:SetParent(button)
            self.AddGroupButton:ClearAllPoints()
            self.AddGroupButton:SetPoint("CENTER")
            self.AddGroupButton:Show()
            button.group = nil
        else
            button:Hide()
            button.group = nil
        end
    end
	table.sort(filteredGroups)
    HybridScrollFrame_Update(self, totalHeight, displayedHeight)
end

function LiteMountGroupsPanelGroupsMixin:OnSizeChanged()
    HybridScrollFrame_CreateButtons(self, 'LiteMountGroupsPanelGroupTemplate')
    for _, b in ipairs(self.buttons) do
        b:SetWidth(self:GetWidth())
    end
end

function LiteMountGroupsPanelGroupsMixin:OnLoad()
    self.scrollBar:ClearAllPoints()
    self.scrollBar:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -16)
    self.scrollBar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, 16)
    local track = _G[self.scrollBar:GetName().."Track"]
    track:Hide()
    -- self.scrollBar.doNotHide = true
    self.update = self.Update
end

function LiteMountGroupsPanelGroupsMixin:GetOption()
    local profile, global = LM.Options:GetRawGroups()
    return { CopyTable(profile), CopyTable(global) }
end

function LiteMountGroupsPanelGroupsMixin:SetOption(v)
    LM.Options:SetRawGroups(unpack(v))
end

function LiteMountGroupsPanelGroupsMixin:SetControl(v)
    self:Update()
end


--[[------------------------------------------------------------------------]]--

LiteMountGroupsPanelMountMixin = {}

function LiteMountGroupsPanelMountMixin:OnClick()
    LiteMountGroupsPanel.Groups.isDirty = true
    local group = LiteMountGroupsPanel.Groups.selectedGroup
    if LM.Options:IsMountInGroup(self.mount, group) then
        LM.Options:ClearMountGroup(self.mount, group)
    else
        LM.Options:SetMountGroup(self.mount, group)
    end
    LiteMountGroupsPanel.Mounts:Update()
end

function LiteMountGroupsPanelMountMixin:OnEnter()
    if self.mount then
        -- GameTooltip_SetDefaultAnchor(LiteMountTooltip, UIParent)
        LiteMountTooltip:SetOwner(self, "ANCHOR_RIGHT", -16, 0)
        LiteMountTooltip:SetMount(self.mount)
    end
end

function LiteMountGroupsPanelMountMixin:OnLeave()
    LiteMountTooltip:Hide()
end

function LiteMountGroupsPanelMountMixin:SetMount(mount, group)
    self.mount = mount

    self.Name:SetText(mount.name)
    if group and LM.Options:IsMountInGroup(self.mount, group) then
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

LiteMountGroupsPanelMountScrollMixin = {}

function LiteMountGroupsPanelMountScrollMixin:GetDisplayedMountList(group)
    if not group then
        return LM.MountList:New()
    end

    local mounts = LM.UIFilter.GetFilteredMountList()
    -- Filter out groups and families
    local mountsOnly = mounts:Search(function(m) return not (m.isGroup or m.isFamily) end)

    local searchText = LiteMountGroupsPanel.searchText or ""

    -- Sorting function
    local function sortByName(a, b)
        return a.name < b.name
    end

    -- If not showing all and not searching, only show group mounts
    if not LiteMountGroupsPanel.showAll and searchText == "" then
        local result = mountsOnly:Search(function(m) return LM.Options:IsMountInGroup(m, group) end)
        table.sort(result, sortByName)
        return result
    end

    -- If searching, show any mount that either:
    -- 1. Belongs to the selected group OR
    -- 2. Matches the search term
    if searchText ~= "" then
        local result = mountsOnly:Search(function(m)
            local inGroup = LM.Options:IsMountInGroup(m, group)
            local matchesSearch = strfind(m.name:lower(), searchText:lower(), 1, true)
            return inGroup or matchesSearch
        end)
        table.sort(result, sortByName)
        return result
    end

    -- If showing all, return all mounts sorted
    table.sort(mountsOnly, sortByName)
    return mountsOnly
end

function LiteMountGroupsPanelMountScrollMixin:Update()
    if not self.buttons then return end

    local offset = HybridScrollFrame_GetOffset(self)

    local group = LiteMountGroupsPanel.Groups.selectedGroup
    local mounts = self:GetDisplayedMountList(group)

    for i, button in ipairs(self.buttons) do
        local index = ( offset + i - 1 ) * 2 + 1
        if index > #mounts then
            button:Hide()
        else
            button.mount1:SetMount(mounts[index], group)
            if button.mount1:IsMouseOver() then button.mount1:OnEnter() end
            if mounts[index+1] then
                button.mount2:SetMount(mounts[index+1], group)
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

function LiteMountGroupsPanelMountScrollMixin:OnSizeChanged()
    HybridScrollFrame_CreateButtons(self, 'LiteMountGroupsPanelButtonTemplate')
    for _, b in ipairs(self.buttons) do
        b:SetWidth(self:GetWidth())
    end
end

function LiteMountGroupsPanelMountScrollMixin:OnLoad()
    local track = _G[self.scrollBar:GetName().."Track"]
    track:Hide()
    self.update = self.Update
end

function LiteMountGroupsPanelMountScrollMixin:SetControl(v)
    self:Update()
end
