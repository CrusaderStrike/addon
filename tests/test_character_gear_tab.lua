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
    -- No floating window. The pane only exists inside an open character tab.
    eq(_G.CrusaderStrikeCharacterGearFrame, nil)
    _G.CharacterFrame = prev
  end)

  it("opens a CS-owned window without mutating Character slots or ModeTabs", function()
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

    _G.CharacterFrame._width = 338
    _G.PaperDollFrame = {
      shown = true,
      Show = function(self) self.shown = true end,
      Hide = function(self) self.shown = false end,
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

    -- Normal Character mode tabs untouched. CS is its own window.
    eq(#tabs, 1)
    eq(_G.CharacterFrameModeTab7, nil)
    eq(#seen, 0)
    eq(showCalls, 0)
    eq(uiPanelCalls, 0)
    eq(equipHidden, false)
    -- PaperDoll stays in the tab list, but it is hidden while CS is showing
    -- so its text cannot bleed through the gear strip.
    eq(_G.PaperDollFrame.shown, false)
    eq(_G.CharacterFrame.activeSubframe, "PaperDollFrame")
    eq(_G.CharacterFrame._selected, nil)
    eq(_G.CharacterFrame._width, 338)
    -- One observe-only ShowSubFrame hook. CS does not call ShowSubFrame.
    eq(_G._CS_HookSecureCount or 0, prevHookCount + 1)

    local root = _G.CrusaderStrikeCharacterGearFrame
    ok(root._csOwnedWindow)
    eq(root._csTitle, "Crusader Strike")
    eq(root._csContentPane, true)
    eq(root:GetParent(), _G.CharacterFrame)
    eq(root._allPoints, nil)
    local rp, rrel, rrp = root:GetPoint(1)
    eq(rp, "TOPLEFT")
    eq(rrel, _G.CharacterFrame)
    eq(rrp, "TOPLEFT")
    local rp2, rrel2, rrp2 = root:GetPoint(2)
    eq(rp2, "BOTTOMRIGHT")
    eq(rrel2, _G.CharacterFrame)
    eq(rrp2, "BOTTOMRIGHT")
    local doll = _G.CrusaderStrikeGearDoll
    eq(doll:GetParent(), root)
    eq(doll._csPaperDoll, true)
    eq(doll._csOwnedDoll, true)
    eq(doll._allPoints, nil)
    eq(doll:GetParent() == _G.CharacterFrame, false)
    eq(doll:GetWidth(), 338)
    eq(doll:GetHeight(), 424)
    ok(_G.CrusaderStrikeCharacterGearClose ~= nil)
    eq(_G.CrusaderStrikeCharacterGearClose:GetParent(), root)

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
    eq(preview.popout, true)
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
    eq(_G.PaperDollFrame.shown, true)
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

    local csWrist = _G.CrusaderStrikeWristSlot
    ok(csWrist ~= nil)
    ok(csWrist._iconTex ~= nil)
    ok(csWrist._iconTex:find("14148") ~= nil)

    ok(UI.UnequipSlot("wrist"))
    preview = UI.GetPreview()
    eq(preview.slots.wrist, nil)
    saved = CrusaderStrikeGearSets.FindByLocalId(CrusaderStrikeCharDB, list.local_id)
    eq(saved.slots.wrist, nil)
    eq(csWrist._iconTex, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists")

    -- Right-click path on the CS slot button.
    ok(UI.EquipItem(14148))
    ok(csWrist._iconTex:find("14148") ~= nil)
    csWrist:GetScript("OnClick")(csWrist, "RightButton")
    eq(UI.GetPreview().slots.wrist, nil)
    eq(csWrist._iconTex, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists")

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
      _width = 338,
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
    -- Character tab stays closed. CS does not float a pane beside it.
    eq(showCalls, 0)
    eq(_G.CharacterFrame.shown, false)
    eq(_G.CharacterFrame._width, 338)
    eq(UI.GetPreview().pending, false)
    eq(UI.GetPreview().active, false)
    eq(_G.CrusaderStrikeCharacterGearFrame:IsShown(), false)
    ok(#printed >= 1)
    -- Hidden pane OnShow must not be hooked by CS.
    _G.CharacterFrame:OnShow()
    eq(showCalls, 0)
    eq(UI.GetPreview().active, false)
    CrusaderStrike.Print = prevPrint
    _G.CharacterFrame = prev
  end)

  it("anchors the right pop-out to the main pane and hides it when closed", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevChar = _G.CharacterFrame
    _G.CharacterFrame = {
      ModeTabs = { Tabs = {} },
      shown = true,
      IsShown = function(self) return self.shown end,
    }
    UI.Show()

    local root = _G.CrusaderStrikeCharacterGearFrame
    local pop = _G.CrusaderStrikeGearPopout
    ok(pop ~= nil)
    eq(pop:GetParent(), root)
    eq(pop._csInFrameColumn, true)
    eq(pop._allPoints, nil)
    eq(root:GetParent(), _G.CharacterFrame)
    eq(root._allPoints, nil)
    eq(root._csContentPane, true)
    eq(pop:GetWidth(), UI.SIDEBAR_WIDTH)
    ok(pop:GetWidth() < _G.CrusaderStrikeGearDoll:GetWidth())
    local point, rel, relPoint = pop:GetPoint(1)
    eq(point, "TOPLEFT")
    eq(rel, _G.CrusaderStrikeGearDoll)
    eq(relPoint, "TOPRIGHT")
    local point2, rel2, relPoint2 = pop:GetPoint(2)
    eq(point2, "BOTTOMLEFT")
    eq(rel2, _G.CrusaderStrikeGearDoll)
    eq(relPoint2, "BOTTOMRIGHT")

    local sets = _G.CrusaderStrikeGearSetsPanel
    local browser = _G.CrusaderStrikeGearBrowserPanel
    local stats = _G.CrusaderStrikeGearStatsPanel
    eq(sets:GetParent(), pop)
    eq(browser:GetParent(), pop)
    eq(stats:GetParent(), pop)
    eq(sets._csSidebarPanel, true)
    eq(browser._csSidebarPanel, true)
    eq(stats._csSidebarPanel, true)
    local sp, srel, _, _, sy = sets:GetPoint(1)
    eq(sp, "TOPLEFT")
    eq(srel, pop)
    eq(sy, -76 - UI.SIDEBAR_TAB_H - 4)

    -- Sidebar tabs match PaperDollSidebarTabTemplate and live in the right pane.
    local iconRow = _G.CrusaderStrikeGearIconRow
    eq(iconRow:GetParent(), pop)
    eq(_G.CrusaderStrikeGearSetsIcon:GetParent():GetParent(), pop)
    eq(_G.CrusaderStrikeGearSetsIcon:GetWidth(), UI.SIDEBAR_TAB_W)
    eq(_G.CrusaderStrikeGearSetsIcon:GetHeight(), UI.SIDEBAR_TAB_H)
    eq(_G.CrusaderStrikeGearBrowserIcon:GetWidth(), UI.SIDEBAR_TAB_W)
    eq(_G.CrusaderStrikeGearStatsIcon:GetWidth(), UI.SIDEBAR_TAB_W)
    local ip, irel, irp, _, iy = iconRow:GetPoint(1)
    eq(ip, "TOPRIGHT")
    eq(irel, pop)
    eq(irp, "TOPRIGHT")
    eq(iy, -76)
    eq(irel == root, false)
    eq(irel == _G.CrusaderStrikeGearDoll, false)

    local function slot_point(btn)
      return btn:GetPoint(1)
    end
    local mh = _G.CrusaderStrikeMainHandSlot
    local oh = _G.CrusaderStrikeSecondaryHandSlot
    local rg = _G.CrusaderStrikeRangedSlot
    local mp, _, mrp, mx, my = slot_point(mh)
    local op, _, orp, ox, oy = slot_point(oh)
    local rp, _, rrp, rx, ry = slot_point(rg)
    eq(mp, "BOTTOMLEFT")
    eq(op, "BOTTOMLEFT")
    eq(rp, "BOTTOMLEFT")
    eq(mrp, "BOTTOMLEFT")
    eq(orp, "BOTTOMLEFT")
    eq(rrp, "BOTTOMLEFT")
    eq(my, UI.WEAPON_ROW_Y)
    eq(oy, UI.WEAPON_ROW_Y)
    eq(ry, UI.WEAPON_ROW_Y)
    eq(mx, UI.WEAPON_ROW_X)
    eq(ox, UI.WEAPON_ROW_X + 37 + UI.WEAPON_ROW_GAP)
    eq(rx, ox + 37 + UI.WEAPON_ROW_GAP)
    eq(_G.CrusaderStrikeGearDoll:GetParent(), root)

    local list = _G.CrusaderStrikeGearDungeonList
    eq(list:GetParent(), browser)
    local lp, lrel, lrp = list:GetPoint(1)
    eq(lp, "TOPLEFT")
    eq(lrel, browser)
    eq(lrp, "TOPLEFT")
    local lp2, lrel2, lrp2 = list:GetPoint(2)
    eq(lp2, "TOPRIGHT")
    eq(lrel2, browser)
    eq(lrp2, "TOPRIGHT")

    local search = _G.CrusaderStrikeGearSearch
    eq(search:GetParent(), browser)
    local _, srel = search:GetPoint(1)
    eq(srel, list)
    local sp2, srel2 = search:GetPoint(2)
    eq(sp2, "TOPRIGHT")
    eq(srel2, list)

    local scroll = _G.CrusaderStrikeGearResultScroll
    eq(scroll:GetParent(), browser)
    local rp, rrel, rrp = scroll:GetPoint(scroll:GetNumPoints())
    eq(rp, "BOTTOMRIGHT")
    eq(rrel, browser)
    eq(rrp, "BOTTOMRIGHT")
    eq(scroll:GetParent() == root, false)
    eq(list:GetParent() == root, false)
    eq(search:GetParent() == root, false)

    eq(_G.CrusaderStrikeGearDungeonListChild:GetWidth(), UI.POPOUT_INNER)
    ok(UI.RESULT_COLS >= 3)
    local grid = UI.RESULT_COLS * 36 + (UI.RESULT_COLS - 1) * 4
    ok(grid <= UI.POPOUT_INNER)

    local preview = UI.GetPreview()
    if not preview.popout or preview.view ~= "browser" then
      UI.TogglePane("browser")
    end
    eq(UI.GetPreview().popout, true)
    eq(UI.GetPreview().view, "browser")
    ok(pop:IsShown())
    ok(browser:IsShown())
    eq(sets:IsShown(), false)
    eq(stats:IsShown(), false)

    -- Same toggle again closes the pop-out and every pane inside it.
    _G.CrusaderStrikeGearBrowserIcon:GetScript("OnClick")(_G.CrusaderStrikeGearBrowserIcon)
    eq(UI.GetPreview().popout, false)
    eq(pop:IsShown(), false)
    eq(sets:IsShown(), false)
    eq(browser:IsShown(), false)
    eq(stats:IsShown(), false)
    ok(root:IsShown())
    ok(_G.CrusaderStrikeGearDoll:IsShown())
    ok(_G.CrusaderStrikeGearSetsIcon:IsShown())
    ok(_G.CrusaderStrikeGearBrowserIcon:IsShown())
    ok(_G.CrusaderStrikeGearStatsIcon:IsShown())

    -- Re-open stats from the main-pane toggle. Content is the stats panel only.
    UI.TogglePane("stats")
    eq(UI.GetPreview().popout, true)
    eq(UI.GetPreview().view, "stats")
    ok(pop:IsShown())
    ok(stats:IsShown())
    eq(browser:IsShown(), false)
    eq(sets:IsShown(), false)

    _G.CharacterFrame = prevChar
  end)

  it("rejects class-illegal weapons and a second main-hand", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevClass = _G.UnitClass
    local prevInfo = _G.GetItemInfoInstant
    local prevChar = _G.CharacterFrame
    _G.CharacterFrame = {
      ModeTabs = { Tabs = {} },
      shown = true,
      IsShown = function(self) return self.shown end,
    }
    local info = {
      [900001] = { "Weapon", "One-Handed Swords", "INVTYPE_WEAPON", 2, 7 },
      [900002] = { "Weapon", "Crossbows", "INVTYPE_RANGED", 2, 18 },
      [900003] = { "Weapon", "One-Handed Maces", "INVTYPE_WEAPON", 2, 4 },
      [900004] = { "Weapon", "One-Handed Swords", "INVTYPE_WEAPONMAINHAND", 2, 7 },
      [900005] = { "Weapon", "Two-Handed Swords", "INVTYPE_2HWEAPON", 2, 8 },
      [900006] = { "Weapon", "Daggers", "INVTYPE_WEAPON", 2, 15 },
    }
    _G.GetItemInfoInstant = function(itemId)
      local row = info[tonumber(itemId)]
      if not row then
        return prevInfo(itemId)
      end
      return itemId, row[1], row[2], row[3], "Interface\\Icons\\INV_CS_Item_" .. tostring(itemId), row[4], row[5]
    end
    _G.UnitClass = function() return "Druid", "DRUID" end

    UI.Show()
    UI.DeselectSlot()
    local slots = UI.GetPreview().slots
    for slot in pairs(slots) do
      slots[slot] = nil
    end

    UI.OnGearSlot("main_hand", "LeftButton")
    local okSword, whySword = UI.EquipItem(900001)
    eq(okSword, false)
    eq(whySword, "class_weapon")
    eq(UI.GetPreview().slots.main_hand, nil)

    UI.OnGearSlot("ranged", "LeftButton")
    local okXbow, whyXbow = UI.EquipItem(900002)
    eq(okXbow, false)
    eq(whyXbow, "class_weapon")
    eq(UI.GetPreview().slots.ranged, nil)
    local okKnown, whyKnown = UI.EquipItem(272999)
    eq(okKnown, false)
    eq(whyKnown, "class_weapon")

    UI.OnGearSlot("main_hand", "LeftButton")
    ok(UI.EquipItem(900003))
    eq(UI.GetPreview().slots.main_hand, 900003)
    local mh = _G.CrusaderStrikeMainHandSlot
    ok(mh._iconTex ~= nil)
    ok(mh._iconTex:find("900003") ~= nil)

    UI.OnGearSlot("off_hand", "LeftButton")
    local okOff, whyOff = UI.EquipItem(900006)
    eq(okOff, false)
    eq(whyOff, "dual_mainhand")
    eq(UI.GetPreview().slots.off_hand, nil)
    eq(UI.GetPreview().slots.main_hand, 900003)

    _G.UnitClass = function() return "Warrior", "WARRIOR" end
    slots = UI.GetPreview().slots
    for slot in pairs(slots) do
      slots[slot] = nil
    end
    UI.OnGearSlot("main_hand", "LeftButton")
    ok(UI.EquipItem(900004))
    UI.OnGearSlot("off_hand", "LeftButton")
    local okSecond, whySecond = UI.EquipItem(900004)
    eq(okSecond, false)
    eq(whySecond, "dual_mainhand")
    eq(UI.GetPreview().slots.off_hand, nil)

    slots = UI.GetPreview().slots
    for slot in pairs(slots) do
      slots[slot] = nil
    end
    UI.OnGearSlot("main_hand", "LeftButton")
    ok(UI.EquipItem(900001))
    UI.OnGearSlot("off_hand", "LeftButton")
    ok(UI.EquipItem(900001))
    eq(UI.GetPreview().slots.main_hand, 900001)
    eq(UI.GetPreview().slots.off_hand, 900001)

    slots = UI.GetPreview().slots
    for slot in pairs(slots) do
      slots[slot] = nil
    end
    UI.OnGearSlot("main_hand", "LeftButton")
    ok(UI.EquipItem(900005))
    UI.OnGearSlot("off_hand", "LeftButton")
    local okTwo, whyTwo = UI.EquipItem(900006)
    eq(okTwo, false)
    eq(whyTwo, "dual_mainhand")

    eq(UI.AcceptsWeapon(900002, "ranged", "DRUID"), false)
    eq(UI.AcceptsWeapon(900002, nil, "DRUID"), false)
    eq(UI.AcceptsWeapon(900003, "main_hand", "DRUID"), true)
    eq(UI.AcceptsWeapon(900001, "main_hand", "DRUID"), false)
    eq(UI.AcceptsWeapon(14148, nil, "DRUID"), true)

    _G.UnitClass = prevClass
    _G.GetItemInfoInstant = prevInfo
    _G.CharacterFrame = prevChar
  end)

  it("allows armor by class with no level gate", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevClass = _G.UnitClass
    local prevLevel = _G.UnitLevel
    local prevInfo = _G.GetItemInfoInstant
    local prevChar = _G.CharacterFrame
    _G.UnitLevel = function() return 1 end
    _G.CharacterFrame = {
      ModeTabs = { Tabs = {} },
      shown = true,
      IsShown = function(self) return self.shown end,
    }
    local info = {
      [910001] = { "Armor", "Cloth", "INVTYPE_CHEST", 4, 1 },
      [910002] = { "Armor", "Leather", "INVTYPE_CHEST", 4, 2 },
      [910003] = { "Armor", "Mail", "INVTYPE_CHEST", 4, 3 },
      [910004] = { "Armor", "Plate", "INVTYPE_CHEST", 4, 4 },
    }
    _G.GetItemInfoInstant = function(itemId)
      local row = info[tonumber(itemId)]
      if not row then
        return prevInfo(itemId)
      end
      return itemId, row[1], row[2], row[3], "Interface\\Icons\\INV_CS_Item_" .. tostring(itemId), row[4], row[5]
    end
    local function clear_slots()
      local slots = UI.GetPreview().slots
      for slot in pairs(slots) do
        slots[slot] = nil
      end
    end
    local function wear(classToken, itemId)
      _G.UnitClass = function() return classToken, classToken end
      clear_slots()
      UI.OnGearSlot("chest", "LeftButton")
      return UI.EquipItem(itemId)
    end
    UI.Show()
    local okMail, whyMail = wear("SHAMAN", 910003)
    ok(okMail)
    eq(UI.GetPreview().slots.chest, 910003)
    local okPlate, whyPlate = wear("SHAMAN", 910004)
    eq(okPlate, false)
    eq(whyPlate, "class_armor")
    eq(UI.GetPreview().slots.chest, nil)
    local okDruidMail, whyDruid = wear("DRUID", 910003)
    eq(okDruidMail, false)
    eq(whyDruid, "class_armor")
    ok(wear("DRUID", 910002))
    eq(wear("MAGE", 910001), true)
    eq(select(1, wear("MAGE", 910002)), false)
    ok(wear("WARRIOR", 910004))
    ok(wear("PALADIN", 910004))
    ok(wear("HUNTER", 910003))
    eq(select(1, wear("ROGUE", 910003)), false)
    ok(wear("ROGUE", 910002))
    ok(wear("PRIEST", 910001))
    eq(select(1, wear("PRIEST", 910004)), false)
    eq(select(1, wear("WARLOCK", 910002)), false)
    eq(UI.AcceptsWeapon(910003, "chest", "SHAMAN"), true)
    eq(UI.AcceptsWeapon(910003, nil, "DRUID"), false)
    eq(UI.AcceptsWeapon(910004, "chest", "WARRIOR"), true)
    eq(UI.AcceptsWeapon(910001, "chest", "MAGE"), true)
    _G.UnitClass = prevClass
    _G.UnitLevel = prevLevel
    _G.GetItemInfoInstant = prevInfo
    _G.CharacterFrame = prevChar
  end)

  it("selects CS as the only content pane and hides it when another tab shows", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevChar = _G.CharacterFrame
    local prevPaper = _G.PaperDollFrame
    local prevHook = _G._CS_HookSecureCount or 0
    local tabs = {
      {
        frameName = "PaperDollFrame",
        SetChecked = function(self, checked) self._checked = checked end,
      },
      {
        frameName = "StatisticsFrame",
        SetChecked = function(self, checked) self._checked = checked end,
      },
    }
    local seen = {}
    local paper = {
      shown = true,
      Show = function(self) self.shown = true end,
      Hide = function(self) self.shown = false end,
      IsShown = function(self) return self.shown end,
    }
    _G.PaperDollFrame = paper
    _G.CharacterFrame = {
      ModeTabs = { Tabs = tabs },
      activeSubframe = "PaperDollFrame",
      shown = true,
      IsShown = function(self) return self.shown end,
    }
    function _G.CharacterFrame:ShowSubFrame(frameName)
      seen[#seen + 1] = frameName
      self.activeSubframe = frameName
    end
    local nTabs = #tabs
    UI.Show()
    eq(#tabs, nTabs)
    eq(_G.CharacterFrameModeTab7, nil)
    eq(#seen, 0)
    eq(paper.shown, false)
    local root = _G.CrusaderStrikeCharacterGearFrame
    ok(root:IsShown())
    eq(root._allPoints, nil)
    eq(root:GetParent(), _G.CharacterFrame)
    local toggle = _G.CrusaderStrikeGearTabToggle
    eq(toggle:GetChecked(), true)
    eq(tabs[1]._checked, false)
    eq(tabs[2]._checked, false)
    eq(_G._CS_HookSecureCount or 0, prevHook + 1)

    UI.Leave()
    eq(root:IsShown(), false)
    eq(paper.shown, true)
    eq(toggle:GetChecked(), false)
    eq(#seen, 0)

    paper.shown = true
    _G.CharacterFrame.activeSubframe = "PaperDollFrame"
    UI.Show()
    eq(#seen, 0)
    eq(paper.shown, false)
    ok(root:IsShown())
    eq(_G._CS_HookSecureCount or 0, prevHook + 1)
    _G.CharacterFrame:ShowSubFrame("StatisticsFrame")
    eq(#seen, 1)
    eq(seen[1], "StatisticsFrame")
    eq(root:IsShown(), false)
    eq(UI.GetPreview().active, false)
    eq(toggle:GetChecked(), false)
    eq(paper.shown, false)
    eq(#tabs, nTabs)

    _G.CharacterFrame = prevChar
    _G.PaperDollFrame = prevPaper
  end)
end)
