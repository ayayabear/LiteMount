--[[----------------------------------------------------------------------------

  LiteMount/UI/Families.lua

  Options frame for mount families.
  Integrated with EntityHelpers for shared functionality.

  Copyright 2011 Mike Battersby

----------------------------------------------------------------------------]]--

local _, LM = ...

local L = LM.Localize

--[[----------------------------------------------------------------------------
  Family-Specific Dialog Definitions
----------------------------------------------------------------------------]]--

-- Reset family dialog
StaticPopupDialogs["LM_OPTIONS_RESET_FAMILY"] = {
    text = format("Reset %s", L.LM_RESET_FAMILY or "Family?"),
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

--[[----------------------------------------------------------------------------
  Families Panel
----------------------------------------------------------------------------]]--

LiteMountFamiliesPanelMixin = {}

function LiteMountFamiliesPanelMixin:OnLoad()
    self.name = "Families"
    self.showAll = false

    -- Register controls
    LiteMountOptionsPanel_RegisterControl(self.Families)
    LiteMountOptionsPanel_RegisterControl(self.Mounts)
    LiteMountOptionsPanel_OnLoad(self)

    -- Set up export/import buttons using the helper
    LM.EntityHelpers.InitializeExportImportButtons(self, false)

    -- Set up standard panel behaviors
    LM.EntityHelpers.SetupEntityPanel(self, false)
end

function LiteMountFamiliesPanelMixin:OnShow()
    -- Attach filter UI
    LiteMountFilter:Attach(self, 'BOTTOMLEFT', self.Mounts, 'TOPLEFT', 0, 15)

    -- Register for filter changes
    LM.UIFilter.RegisterCallback(self, "OnFilterChanged", "OnRefresh")

    -- Update the UI
    self:Update()
    LiteMountOptionsPanel_OnShow(self)
end

function LiteMountFamiliesPanelMixin:OnHide()
    -- Clear search and filter state
    if LiteMountFilter.Search then
        LiteMountFilter.Search:SetText("")
    end
    self.searchText = nil

    -- Unregister callbacks
    LM.UIFilter.UnregisterAllCallbacks(self)
    LiteMountOptionsPanel_OnHide(self)
end

function LiteMountFamiliesPanelMixin:Update()
    -- Update the UI components
    self.Families:Update()
    self.Mounts:Update()
    self.ShowAll:SetChecked(self.showAll)
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

--[[----------------------------------------------------------------------------
  Family Item Mixin
----------------------------------------------------------------------------]]--

LiteMountFamiliesPanelFamilyMixin = {}

function LiteMountFamiliesPanelFamilyMixin:OnClick()
    if self.family then
        LiteMountFamiliesPanel.Families.selectedFamily = self.family
        LiteMountFamiliesPanel:Update()
    end
end

--[[----------------------------------------------------------------------------
  Families List Panel
----------------------------------------------------------------------------]]--

LiteMountFamiliesPanelFamiliesMixin = {}

function LiteMountFamiliesPanelFamiliesMixin:Update()
    if not self.buttons then return end

    local allFamilies = LM.UIFilter.GetFamilies()
    local searchText = LiteMountFamiliesPanel.searchText or ""

    -- Filter and sort families using the helper
    local filteredFamilies, selectedFamily = LM.EntityHelpers.FilterEntityList(
        allFamilies, self.selectedFamily, searchText)
    self.selectedFamily = selectedFamily

    -- Use shared update function
    LM.EntityHelpers.UpdateEntityList(self, filteredFamilies, self.selectedFamily, false)
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

--[[----------------------------------------------------------------------------
  Family Mount Item
----------------------------------------------------------------------------]]--

LiteMountFamiliesPanelMountMixin = {}

function LiteMountFamiliesPanelMountMixin:OnClick()
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

--[[----------------------------------------------------------------------------
  Family Mount List
----------------------------------------------------------------------------]]--

LiteMountFamiliesPanelMountScrollMixin = {}

function LiteMountFamiliesPanelMountScrollMixin:GetDisplayedMountList(family)
    return LM.EntityHelpers.GetDisplayedMountList(LiteMountFamiliesPanel, family, false)
end

function LiteMountFamiliesPanelMountScrollMixin:Update()
    local family = LiteMountFamiliesPanel.Families.selectedFamily
    LM.EntityHelpers.UpdateMountScroll(self, family, false)
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
