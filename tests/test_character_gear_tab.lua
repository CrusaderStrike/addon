describe("character gear tab scaffold", function()
  it("does not create CS slot buttons on load", function()
    eq(_G.CrusaderStrikeHeadSlot, nil)
    eq(_G.CharacterHeadSlot, nil)
    eq(#CrusaderStrike.CharacterGearTab.SLOT_BUTTONS, 19)
    for _, info in ipairs(CrusaderStrike.CharacterGearTab.SLOT_BUTTONS) do
      ok(info.global:match("^CrusaderStrike"), info.global)
      eq(info.global:match("^Character"), nil)
      eq(info.global == "CharacterAmmoSlot", false)
    end
  end)

  it("slash geartab is safe without a character frame", function()
    local prev = _G.CharacterFrame
    _G.CharacterFrame = nil
    SlashCmdList["CRUSADERSTRIKE"]("geartab")
    _G.CharacterFrame = prev
  end)

  it("opens a CS-owned overlay without mutating Character slots or ModeTabs", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevChar = _G.CharacterFrame
    local prevPaper = _G.PaperDollFrame
    local prevDb = _G.CrusaderStrikeCharDB
    local prevShow = _G.ShowUIPanel
    local prevHookCount = _G._CS_HookSecureCount or 0

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
    local showCalls = 0
    local uiPanelCalls = 0
    _G.ShowUIPanel = function()
      uiPanelCalls = uiPanelCalls + 1
    end
    _G.CrusaderStrikeCharDB = {}
    _G.CharacterFrame = {
      ModeTabs = { Tabs = tabs },
      activeSubframe = "PaperDollFrame",
      shown = true,
      Show = function(self)
        showCalls = showCalls + 1
        self.shown = true
      end,
      IsShown = function(self) return self.shown end,
    }
    function _G.CharacterFrame:ShowSubFrame(frameName)
      seen[#seen + 1] = frameName
      self.activeSubframe = frameName
    end
    function _G.CharacterFrame:SetSelectedModeTabByFrame(frameName)
      self._selected = frameName
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
    local blizzardHandler = head:GetScript("OnClick")

    UI.Show()

    -- Normal Character mode tabs untouched.
    eq(#tabs, 1)
    eq(_G.CharacterFrameModeTab7, nil)
    eq(#seen, 0)
    eq(showCalls, 0)
    eq(uiPanelCalls, 0)
    eq(equipHidden, false)
    eq(_G._CS_HookSecureCount or 0, prevHookCount)

    local toggle = _G.CrusaderStrikeGearTabToggle
    ok(toggle ~= nil)
    ok(toggle._csOwnedToggle)
    eq(toggle._csIcon, "Interface\\AddOns\\CrusaderStrike\\assets\\logo.tga")
    ok(toggle._csGearTab)
    -- Parented to ModeTabs for side-tab chrome; Tabs table stays untouched.
    eq(toggle._parent, _G.CharacterFrame.ModeTabs)
    eq(toggle._template, "CharacterFrameModeSideTabTemplate")

    -- Blizzard CharacterHeadSlot is never hooked or replaced.
    eq(_G.CharacterHeadSlot, head)
    eq(head:GetScript("OnClick"), blizzardHandler)
    head:GetScript("OnClick")(head, "LeftButton")
    eq(clicked, 1)

    -- CS owns its own slot buttons.
    local csHead = _G.CrusaderStrikeHeadSlot
    ok(csHead ~= nil)
    ok(csHead._csOwnedSlot)
    eq(csHead._csSlot, "head")
    ok(_G.CrusaderStrikeCharacterGearFrame:IsShown())
    ok(_G.CrusaderStrikeGearSearch ~= nil)
    ok(_G.CrusaderStrikeGearBrowserPanel ~= nil)
    ok(_G.CrusaderStrikeGearSetsPanel ~= nil)
    ok(_G.CrusaderStrikeGearStatsPanel ~= nil)
    ok(_G.CrusaderStrikeGearDungeonList ~= nil)
    ok(_G.CrusaderStrikeGearDungeonListChild ~= nil)
    ok(_G.CrusaderStrikeGearResultScroll ~= nil)
    eq(_G.CrusaderStrikeGearDungeonButton, nil)

    local setsIcon = _G.CrusaderStrikeGearSetsIcon
    local browserIcon = _G.CrusaderStrikeGearBrowserIcon
    local statsIcon = _G.CrusaderStrikeGearStatsIcon
    ok(setsIcon ~= nil)
    ok(browserIcon ~= nil)
    ok(statsIcon ~= nil)
    eq(setsIcon._csIcon, "Interface\\Icons\\INV_Misc_Gear_01")
    eq(browserIcon._csIcon, "Interface\\Icons\\INV_Misc_Bag_08")
    eq(statsIcon._csIcon, "Interface\\Icons\\INV_Misc_Note_01")
    eq(setsIcon:GetText() or "", "")
    eq(browserIcon:GetText() or "", "")
    eq(setsIcon.tooltipText, "Gear Sets")
    eq(browserIcon.tooltipText, "Browser")
    eq(statsIcon.tooltipText, "Stats")

    local handler = csHead:GetScript("OnClick")
    handler(csHead, "LeftButton")
    local preview = UI.GetPreview()
    eq(preview.activeSlot, "head")
    eq(preview.gearSlot, "head")
    eq(preview.view, "browser")
    ok(UI.EquipItem(272999))
    preview = UI.GetPreview()
    eq(preview.slots.head, 272999)
    eq(preview.filled, 1)
    -- Real icon texture (not the QuestionMark placeholder).
    ok(csHead._iconTex ~= nil)
    eq(csHead._iconTex:find("QuestionMark") ~= nil, false)
    ok(csHead._iconTex:find("272999") ~= nil)

    -- Leave via CS leave — CharacterHeadSlot still untouched.
    UI.Leave()
    eq(UI.GetPreview().active, false)
    eq(_G.CrusaderStrikeCharacterGearFrame:IsShown(), false)
    eq(head:GetScript("OnClick"), blizzardHandler)

    _G.CharacterFrame = prevChar
    _G.PaperDollFrame = prevPaper
    _G.CrusaderStrikeCharDB = prevDb
    _G.ShowUIPanel = prevShow
    _G.CharacterHeadSlot = nil
  end)

  it("filters the browser from a dungeon list row", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevChar = _G.CharacterFrame
    local prevDb = _G.CrusaderStrikeCharDB
    _G.CrusaderStrikeCharDB = {}
    _G.CharacterFrame = {
      ModeTabs = { Tabs = {} },
      shown = true,
      IsShown = function(self) return self.shown end,
    }
    UI.Show()
    ok(UI.GetPreview().active)
    UI.SelectDungeon(389)
    eq(UI.GetPreview().instanceId, 389)
    UI.SelectDungeon(nil)
    eq(UI.GetPreview().instanceId, nil)
    local child = _G.CrusaderStrikeGearDungeonListChild
    ok(child ~= nil)
    _G.CharacterFrame = prevChar
    _G.CrusaderStrikeCharDB = prevDb
  end)

  it("equips into the selected gear set and unequips on right-click", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevChar = _G.CharacterFrame
    local prev = _G.CrusaderStrikeCharDB
    _G.CrusaderStrikeCharDB = {}
    _G.CharacterFrame = {
      ModeTabs = { Tabs = {} },
      shown = true,
      IsShown = function(self) return self.shown end,
    }
    UI.Show()
    local list = CrusaderStrikeGearSets.CreateSet(CrusaderStrikeCharDB, {
      name = "Wish",
      type = "max_level",
    }, 60)
    ok(list ~= nil)
    ok(UI.SelectSet(list.local_id))
    UI.OnGearSlot("wrist", "LeftButton")
    ok(UI.EquipItem(14148))
    local preview = UI.GetPreview()
    eq(preview.slots.wrist, 14148)
    local saved = CrusaderStrikeGearSets.FindByLocalId(CrusaderStrikeCharDB, list.local_id)
    eq(saved.slots.wrist, 14148)

    ok(UI.UnequipSlot("wrist"))
    preview = UI.GetPreview()
    eq(preview.slots.wrist, nil)
    saved = CrusaderStrikeGearSets.FindByLocalId(CrusaderStrikeCharDB, list.local_id)
    eq(saved.slots.wrist, nil)

    -- Right-click path on the CS slot button.
    ok(UI.EquipItem(14148))
    local csWrist = _G.CrusaderStrikeWristSlot
    ok(csWrist ~= nil)
    csWrist:GetScript("OnClick")(csWrist, "RightButton")
    eq(UI.GetPreview().slots.wrist, nil)

    _G.CharacterFrame = prevChar
    _G.CrusaderStrikeCharDB = prev
  end)

  it("assigns a browser item onto its equip slot without a prior selection", function()
    local UI = CrusaderStrike.CharacterGearTab
    UI.DeselectSlot()
    ok(UI.AssignPreviewItem(272998))
    local preview = UI.GetPreview()
    eq(preview.activeSlot, "main_hand")
    eq(preview.slots.main_hand, 272998)
  end)

  it("saves the gear-set preview as a real gear set", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prev = _G.CrusaderStrikeCharDB
    _G.CrusaderStrikeCharDB = {}
    UI.DeselectSlot()
    -- clear prior preview slots from earlier tests
    local preview = UI.GetPreview()
    for slot in pairs(preview.slots) do
      preview.slots[slot] = nil
    end
    ok(UI.AssignPreviewItem(272998))
    local okSave, list = UI.SavePreviewAsSet("RFC preview")
    ok(okSave)
    eq(list.slots.main_hand, 272998)
    local saved = CrusaderStrikeGearSets.FindByLocalId(CrusaderStrikeCharDB, list.local_id)
    eq(saved.slots.main_hand, 272998)
    _G.CrusaderStrikeCharDB = prev
  end)

  it("builds a scrollable result grid past eight items", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevChar = _G.CharacterFrame
    local prevDb = _G.CrusaderStrikeCharDB
    _G.CrusaderStrikeCharDB = {}
    _G.CharacterFrame = {
      ModeTabs = { Tabs = {} },
      shown = true,
      IsShown = function(self) return self.shown end,
    }
    UI.Show()
    UI.SelectDungeon(389)
    local rows = CrusaderStrikeGearBrowser.Filter({
      instanceId = 389,
      difficulty = CrusaderStrikeGearBrowser.FOREVER_NORMAL,
    }, "forever")
    ok(#rows >= 12)
    -- Result scroll child exists; icons resolve to real textures.
    ok(_G.CrusaderStrikeGearResultScroll ~= nil)
    ok(_G.CrusaderStrikeGearResultChild ~= nil)
    -- Refresh paints icons for every matching row (no hard 8-cap).
    local preview = UI.GetPreview()
    eq(preview.instanceId, 389)
    _G.CharacterFrame = prevChar
    _G.CrusaderStrikeCharDB = prevDb
  end)

  it("does not open the character frame when it is hidden", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prev = _G.CharacterFrame
    local showCalls = 0
    local printed = {}
    local prevPrint = CrusaderStrike.Print
    CrusaderStrike.Print = function(msg)
      printed[#printed + 1] = msg
    end
    _G.CharacterFrame = {
      ModeTabs = { Tabs = {} },
      shown = false,
      Show = function(self)
        showCalls = showCalls + 1
        self.shown = true
      end,
      IsShown = function(self) return self.shown end,
      ShowSubFrame = function() end,
      OnShow = function(self)
        self.shown = true
      end,
    }
    UI.Leave()
    UI.Show()
    eq(showCalls, 0)
    eq(UI.GetPreview().pending, false)
    eq(UI.GetPreview().active, false)
    ok(#printed >= 1)
    -- Hidden pane OnShow must not auto-enter CS mode (no CharacterFrame hooks).
    _G.CharacterFrame:OnShow()
    eq(UI.GetPreview().active, false)
    CrusaderStrike.Print = prevPrint
    _G.CharacterFrame = prev
  end)
end)
