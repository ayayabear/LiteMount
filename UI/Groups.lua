--[[----------------------------------------------------------------------------

  LiteMount/UI/Groups.lua

  Options frame for mount groups.
  Integrated with EntityHelpers for shared functionality.

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...

local L = LM.Localize

--[[----------------------------------------------------------------------------
  Group Validation
----------------------------------------------------------------------------]]--

-- Check if a group name is valid and doesn't conflict with existing entities
local function IsValidGroupName(text)
    if not text or text == "" then return false end
    if LM.Options:IsFlag(text) then return false end
    if LM.Options:IsGroup(text) then return false end
    if tonumber(text) then return false end
    if text:find(':') then return false end
    if text:sub(1, 1) == '~' then return false end
    return true
end

--[[----------------------------------------------------------------------------
  Group-Specific Dialog Definitions
----------------------------------------------------------------------------]]--

-- New group dialog
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

-- Rename group dialog
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

-- Delete group dialog
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

--[[----------------------------------------------------------------------------
  Groups Panel
----------------------------------------------------------------------------]]--

LiteMountGroupsPanelMixin = {}

function LiteMountGroupsPanelMixin:OnLoad()
    self.showAll = true

    -- Register controls
    LiteMountOptionsPanel_RegisterControl(self.Groups)
    LiteMountOptionsPanel_RegisterControl(self.Mounts)
    LiteMountOptionsPanel_OnLoad(self)

    -- Set up export/import buttons using the helper
    LM.EntityHelpers.InitializeExportImportButtons(self, true)

    -- Set up standard panel behaviors
    LM.EntityHelpers.SetupEntityPanel(self, true)
end

function LiteMountGroupsPanelMixin:OnShow()
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
end

function LiteMountGroupsPanelMixin:OnHide()
    -- Clear search and filter state
    if LiteMountFilter.Search then
        LiteMountFilter.Search:SetText("")
    end
    self.searchText = nil

    -- Unregister callbacks
    LM.UIFilter.UnregisterAllCallbacks(self)
    LiteMountOptionsPanel_OnHide(self)
end

function LiteMountGroupsPanelMixin:Update()
    -- Update the UI components
    self.Groups:Update()
    self.Mounts:Update()
    self.ShowAll:SetChecked(self.showAll)
end

function LiteMountGroupsPanelMixin:OnRefresh()
    self:Update()
end

function LiteMountGroupsPanelMixin:ShowExportDialog()
    StaticPopup_Show("LM_EXPORT_GROUPS")
end

function LiteMountGroupsPanelMixin:ShowImportDialog()
    StaticPopup_Show("LM_IMPORT_GROUPS")
end

--[[----------------------------------------------------------------------------
  Group Item
----------------------------------------------------------------------------]]--

LiteMountGroupsPanelGroupMixin = {}

function LiteMountGroupsPanelGroupMixin:OnClick()
    if self.group then
        LiteMountGroupsPanel.Groups.selectedGroup = self.group
        LiteMountGroupsPanel:Update()
    end
end

--[[----------------------------------------------------------------------------
  Groups List Panel
----------------------------------------------------------------------------]]--

LiteMountGroupsPanelGroupsMixin = {}

function LiteMountGroupsPanelGroupsMixin:Update()
    if not self.buttons then return end

    local allGroups = LM.Options:GetGroupNames()
    local searchText = LiteMountGroupsPanel.searchText or ""

    -- Filter and sort groups using the helper
    local filteredGroups, selectedGroup = LM.EntityHelpers.FilterEntityList(
        allGroups, self.selectedGroup, searchText)
    self.selectedGroup = selectedGroup

    -- Hide the Add button initially
    self.AddGroupButton:SetParent(nil)
    self.AddGroupButton:Hide()

    -- Use shared update function
    LM.EntityHelpers.UpdateEntityList(self, filteredGroups, self.selectedGroup, true)

    -- Position the Add button (after the list update)
    if #self.buttons > 0 and #filteredGroups < #self.buttons then
        local button = self.buttons[#filteredGroups + 1]
        if button then
            button.Text:Hide()
            button:Show()
            self.AddGroupButton:SetParent(button)
            self.AddGroupButton:ClearAllPoints()
            self.AddGroupButton:SetPoint("CENTER")
            self.AddGroupButton:Show()
        end
    end
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

--[[----------------------------------------------------------------------------
  Group Mount Item
----------------------------------------------------------------------------]]--

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

--[[----------------------------------------------------------------------------
  Group Mount List
----------------------------------------------------------------------------]]--

LiteMountGroupsPanelMountScrollMixin = {}

function LiteMountGroupsPanelMountScrollMixin:GetDisplayedMountList(group)
    return LM.EntityHelpers.GetDisplayedMountList(LiteMountGroupsPanel, group, true)
end

function LiteMountGroupsPanelMountScrollMixin:Update()
    local group = LiteMountGroupsPanel.Groups.selectedGroup
    LM.EntityHelpers.UpdateMountScroll(self, group, true)
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
