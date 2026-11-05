describe("character gear tab scaffold", function()
  it("does not create copy paper doll slots on load", function()
    eq(_G.CharacterHeadSlot, nil)
    eq(_G.CharacterAmmoSlot, nil)
    eq(#CrusaderStrike.CharacterGearTab.SLOT_BUTTONS, 19)
    for _, info in ipairs(CrusaderStrike.CharacterGearTab.SLOT_BUTTONS) do
      ok(info.global:match("^Character"), info.global)
      eq(info.global == "CharacterAmmoSlot", false)
    end
  end)

  it("slash geartab is safe without a character frame", function()
    local prev = _G.CharacterFrame
    _G.CharacterFrame = nil
    SlashCmdList["CRUSADERSTRIKE"]("geartab")
    _G.CharacterFrame = prev
  end)

  it("appends a last character tab and reuses paper doll clicks", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevChar = _G.CharacterFrame
    local prevPaper = _G.PaperDollFrame
    local prevDb = _G.CrusaderStrikeCharDB
    local prevShow = _G.ShowUIPanel

    local tabs = {
      {
        frameName = "StatisticsFrame",
        IsShown = function() return true end,
        ClearAllPoints = function() end,
        SetPoint = function() end,
        GetID = function() return 6 end,
      },
    }
    local seen = {}
    local equipHidden = false
    _G.ShowUIPanel = nil
    _G.CrusaderStrikeCharDB = {}
    _G.CharacterFrame = {
      ModeTabs = { Tabs = tabs },
      activeSubframe = "PaperDollFrame",
      Show = function(self) self.shown = true end,
      IsShown = function(self) return self.shown end,
    }
    function _G.CharacterFrame:ShowSubFrame(frameName)
      seen[#seen + 1] = frameName
      self.activeSubframe = frameName
    end
    function _G.CharacterFrame:SetSelectedModeTabByFrame(frameName)
      self._selected = frameName
      for _, tab in ipairs(self.ModeTabs.Tabs) do
        if tab.SetChecked then
          tab:SetChecked(tab.frameName == frameName)
        end
      end
    end

    _G.PaperDollFrame = {
      Show = function(self) self.shown = true end,
      IsShown = function(self) return self.shown end,
      EquipmentManagerPane = {
        Hide = function() equipHidden = true end,
        IsShown = function() return false end,
      },
    }

    local clicked = 0
    local head = CreateFrame("Button", "CharacterHeadSlot")
    head:SetScript("OnClick", function()
      clicked = clicked + 1
    end)

    UI.Show()

    eq(#tabs, 2)
    eq(tabs[2]:GetID(), 7)
    eq(tabs[2]._name, "CharacterFrameModeTab7")
    eq(tabs[2].frameName, UI.FRAME_NAME)
    eq(_G.CharacterFrameModeTab7:GetChecked(), true)
    eq(seen[1], UI.FRAME_NAME)
    eq(_G.CharacterHeadSlot, head)
    eq(_G.CrusaderStrikeHeadSlot, nil)
    ok(_G.CrusaderStrikeCharacterGearFrame:IsShown())
    ok(_G.CrusaderStrikeGearSearch ~= nil)
    ok(equipHidden)
    ok(_G.PaperDollFrame.shown)

    local setsIcon = _G.CrusaderStrikeGearSetsIcon
    local browserIcon = _G.CrusaderStrikeGearBrowserIcon
    ok(setsIcon ~= nil)
    ok(browserIcon ~= nil)
    eq(setsIcon._csIcon, "Interface\\Icons\\INV_Misc_Gear_01")
    eq(browserIcon._csIcon, "Interface\\Icons\\INV_Misc_Bag_08")
    eq(setsIcon:GetText() or "", "")
    eq(browserIcon:GetText() or "", "")
    eq(setsIcon.tooltipText, "Gear Sets")
    eq(browserIcon.tooltipText, "Browser")
    eq(tabs[2]._csIcon, "Interface\\AddOns\\CrusaderStrike\\assets\\logo.tga")
    ok(_G._CS_HookSecureCount and _G._CS_HookSecureCount > 0)

    local handler = head:GetScript("OnClick")
    handler(head, "LeftButton")
    -- Blizzard's original click still runs (HookScript, not SetScript).
    eq(clicked, 1)
    local preview = UI.GetPreview()
    eq(preview.activeSlot, "head")
    eq(preview.gearSlot, "head")
    eq(preview.view, "browser")
    ok(UI.AssignPreviewItem(272999))
    preview = UI.GetPreview()
    eq(preview.slots.head, 272999)
    eq(preview.filled, 1)

    _G.CharacterFrame:ShowSubFrame("PaperDollFrame")
    eq(UI.GetPreview().active, false)
    eq(_G.CrusaderStrikeCharacterGearFrame:IsShown(), false)
    head:GetScript("OnClick")(head, "LeftButton")
    eq(clicked, 2)

    _G.CharacterFrame = prevChar
    _G.PaperDollFrame = prevPaper
    _G.CrusaderStrikeCharDB = prevDb
    _G.ShowUIPanel = prevShow
    _G.CharacterHeadSlot = nil
  end)

  it("previews a saved set without writing it back", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prev = _G.CrusaderStrikeCharDB
    _G.CrusaderStrikeCharDB = {}
    local list = CrusaderStrikeGearSets.CreateSet(CrusaderStrikeCharDB, {
      name = "Wish",
      type = "max_level",
    }, 60)
    ok(list ~= nil)
    CrusaderStrikeGearSets.SetSlot(CrusaderStrikeCharDB, list.local_id, "head", 14145)
    ok(UI.SelectSet(list.local_id))
    local preview = UI.GetPreview()
    eq(preview.slots.head, 14145)
    UI.OnPaperDollSlot("wrist")
    ok(UI.AssignPreviewItem(14148))
    preview = UI.GetPreview()
    eq(preview.slots.wrist, 14148)
    eq(preview.filled, 2)
    local saved = CrusaderStrikeGearSets.FindByLocalId(CrusaderStrikeCharDB, list.local_id)
    eq(saved.slots.head, 14145)
    eq(saved.slots.wrist, nil)
    _G.CrusaderStrikeCharDB = prev
  end)
end)
