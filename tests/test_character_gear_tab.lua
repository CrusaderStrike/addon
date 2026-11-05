describe("character gear tab scaffold", function()
  it("does not create CS slot buttons on load", function()
    eq(_G.CrusaderStrikeHeadSlot, nil)
    eq(_G.CharacterHeadSlot, nil)
    eq(#CrusaderStrike.CharacterGearTab.SLOT_BUTTONS, 20)
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
    eq(doll:GetParent() == _G.UIParent, false)
    local dp, drel, drp, dx, dy = doll:GetPoint(1)
    eq(dp, "CENTER")
    eq(drel, root)
    eq(drp, "CENTER")
    eq(dx, 0)
    eq(dy, 0)
    eq(drel == _G.UIParent, false)
    eq(drel == _G.CharacterFrame, false)
    eq(doll:GetWidth(), 338)
    eq(doll:GetHeight(), 424)

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

    local iconRow = _G.CrusaderStrikeGearIconRow
    eq(iconRow:GetParent(), pop)

    -- Tab row spans the pop-out. The three panes hang off the bottom of that row.
    local ip, irel, irp, ix, iy = iconRow:GetPoint(1)
    eq(ip, "TOPLEFT")
    eq(irel, pop)
    eq(irp, "TOPLEFT")
    eq(ix, 0)
    eq(iy, -UI.SIDEBAR_TAB_GAP)
    local ip2, irel2, irp2, ix2, iy2 = iconRow:GetPoint(2)
    eq(ip2, "TOPRIGHT")
    eq(irel2, pop)
    eq(irp2, "TOPRIGHT")
    eq(ix2, 0)
    eq(iy2, -UI.SIDEBAR_TAB_GAP)
    eq(irel == root, false)
    eq(irel == _G.CrusaderStrikeGearDoll, false)
    eq(irel == _G.UIParent, false)
    eq(irel == _G.CharacterFrame, false)

    local sets = _G.CrusaderStrikeGearSetsPanel
    local browser = _G.CrusaderStrikeGearBrowserPanel
    local stats = _G.CrusaderStrikeGearStatsPanel

    local function anchored_in_popout(panel)
      eq(panel._csSidebarPanel, true)
      eq(panel:GetParent(), pop)
      eq(panel:GetParent() == root, false)
      eq(panel:GetParent() == _G.CharacterFrame, false)
      eq(panel:GetParent() == _G.UIParent, false)
      local p1, rel1, rp1, x1, y1 = panel:GetPoint(1)
      eq(p1, "TOPLEFT")
      eq(rel1, iconRow)
      eq(rp1, "BOTTOMLEFT")
      eq(x1, 0)
      eq(y1, -UI.SIDEBAR_TAB_GAP)
      local p2, rel2, rp2, x2, y2 = panel:GetPoint(2)
      eq(p2, "BOTTOMRIGHT")
      eq(rel2, pop)
      eq(rp2, "BOTTOMRIGHT")
      eq(x2, 0)
      eq(y2, 0)
      eq(rel1:GetParent(), pop)
      eq(rel1 == root, false)
      eq(rel1 == _G.CharacterFrame, false)
      eq(rel1 == _G.UIParent, false)
      eq(rel2 == root, false)
      eq(rel2 == _G.CharacterFrame, false)
      eq(rel2 == _G.UIParent, false)
    end
    anchored_in_popout(sets)
    anchored_in_popout(browser)
    anchored_in_popout(stats)

    local doll = _G.CrusaderStrikeGearDoll
    eq(doll:GetParent(), root)
    local dp, drel, drp, dx, dy = doll:GetPoint(1)
    eq(dp, "CENTER")
    eq(drel, root)
    eq(drp, "CENTER")
    eq(dx, 0)
    eq(dy, 0)
    eq(drel == _G.UIParent, false)
    eq(drel == _G.CharacterFrame, false)

    -- Sidebar tabs match PaperDollSidebarTabTemplate and live in the right pane.
    eq(_G.CrusaderStrikeGearSetsIcon:GetParent():GetParent(), pop)
    eq(_G.CrusaderStrikeGearSetsIcon:GetWidth(), UI.SIDEBAR_TAB_W)
    eq(_G.CrusaderStrikeGearSetsIcon:GetHeight(), UI.SIDEBAR_TAB_H)
    eq(_G.CrusaderStrikeGearBrowserIcon:GetWidth(), UI.SIDEBAR_TAB_W)
    eq(_G.CrusaderStrikeGearStatsIcon:GetWidth(), UI.SIDEBAR_TAB_W)

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
    -- Closing the side pane hides its icon buttons too. The edge toggle stays.
    eq(_G.CrusaderStrikeGearSetsIcon:IsShown(), false)
    eq(_G.CrusaderStrikeGearBrowserIcon:IsShown(), false)
    eq(_G.CrusaderStrikeGearStatsIcon:IsShown(), false)
    local sideToggle = _G.CrusaderStrikeGearSideToggle
    ok(sideToggle ~= nil)
    ok(sideToggle:IsShown())
    eq(sideToggle:GetParent(), _G.CrusaderStrikeGearDoll)
    eq(sideToggle._csSideToggle, true)
    sideToggle:GetScript("OnClick")(sideToggle)
    eq(UI.GetPreview().popout, true)
    eq(UI.GetPreview().view, "browser")
    ok(pop:IsShown())
    ok(browser:IsShown())
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

    -- Gear Sets is the same kind of child: open with its tab, hidden when the pop-out closes.
    UI.TogglePane("sets")
    eq(UI.GetPreview().view, "sets")
    ok(pop:IsShown())
    ok(sets:IsShown())
    eq(browser:IsShown(), false)
    eq(stats:IsShown(), false)
    _G.CrusaderStrikeGearSetsIcon:GetScript("OnClick")(_G.CrusaderStrikeGearSetsIcon)
    eq(UI.GetPreview().popout, false)
    eq(pop:IsShown(), false)
    eq(sets:IsShown(), false)
    eq(browser:IsShown(), false)
    eq(stats:IsShown(), false)

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
    eq(whyOff, "wrong_slot")
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
    eq(whySecond, "wrong_slot")
    eq(UI.GetPreview().slots.off_hand, nil)

    slots = UI.GetPreview().slots
    for slot in pairs(slots) do
      slots[slot] = nil
    end
    UI.OnGearSlot("main_hand", "LeftButton")
    ok(UI.EquipItem(900001))
    UI.OnGearSlot("off_hand", "LeftButton")
    local okGeneric, whyGeneric = UI.EquipItem(900001)
    eq(okGeneric, false)
    eq(whyGeneric, "wrong_slot")
    eq(UI.GetPreview().slots.main_hand, 900001)
    eq(UI.GetPreview().slots.off_hand, nil)

    slots = UI.GetPreview().slots
    for slot in pairs(slots) do
      slots[slot] = nil
    end
    UI.OnGearSlot("main_hand", "LeftButton")
    ok(UI.EquipItem(900005))
    UI.OnGearSlot("off_hand", "LeftButton")
    local okTwo, whyTwo = UI.EquipItem(900006)
    eq(okTwo, false)
    eq(whyTwo, "wrong_slot")

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
    local prevDb = _G.CrusaderStrikeCharDB
    _G.CrusaderStrikeCharDB = {}
    _G.UnitLevel = function() return 10 end
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
    local low = CrusaderStrikeGearSets.CreateSet(CrusaderStrikeCharDB, {
      name = "To 10",
      type = "leveling",
      until_level = 10,
    }, 1)
    ok(low ~= nil)
    ok(UI.SelectSet(low.local_id))
    local okMail = wear("SHAMAN", 910003)
    ok(okMail)
    eq(UI.GetPreview().slots.chest, 910003)
    ok(wear("HUNTER", 910003))
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
    eq(select(1, wear("ROGUE", 910003)), false)
    ok(wear("ROGUE", 910002))
    ok(wear("PRIEST", 910001))
    eq(select(1, wear("PRIEST", 910004)), false)
    eq(select(1, wear("WARLOCK", 910002)), false)
    eq(UI.AcceptsWeapon(910003, "chest", "SHAMAN"), true)
    eq(UI.AcceptsWeapon(910003, "chest", "HUNTER"), true)
    eq(UI.AcceptsWeapon(910003, nil, "DRUID"), false)
    eq(UI.AcceptsWeapon(910004, "chest", "WARRIOR"), true)
    eq(UI.AcceptsWeapon(910001, "chest", "MAGE"), true)
    eq(UI.AcceptsWeapon(910003, "wrist", "DRUID"), false)
    eq(UI.AcceptsWeapon(910003, "back", "DRUID"), true)
    eq(UI.AcceptsWeapon(910002, "hands", "DRUID"), true)
    _G.UnitClass = function() return "Druid", "DRUID" end
    clear_slots()
    UI.OnGearSlot("back", "LeftButton")
    ok(UI.EquipItem(910003))
    eq(UI.GetPreview().slots.back, 910003)
    _G.UnitClass = prevClass
    _G.UnitLevel = prevLevel
    _G.GetItemInfoInstant = prevInfo
    _G.CharacterFrame = prevChar
    _G.CrusaderStrikeCharDB = prevDb
  end)

  it("rejects weapons that do not belong in the selected hand", function()
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
      [920001] = { "Weapon", "One-Handed Swords", "INVTYPE_WEAPONMAINHAND", 2, 7 },
      [920002] = { "Weapon", "Two-Handed Swords", "INVTYPE_2HWEAPON", 2, 8 },
      [920003] = { "Weapon", "One-Handed Swords", "INVTYPE_WEAPON", 2, 7 },
      [920004] = { "Weapon", "Daggers", "INVTYPE_WEAPONOFFHAND", 2, 15 },
      [920005] = { "Armor", "Shields", "INVTYPE_SHIELD", 4, 6 },
      [920006] = { "Armor", "Miscellaneous", "INVTYPE_HOLDABLE", 4, 0 },
      [920007] = { "Weapon", "Crossbows", "INVTYPE_RANGED", 2, 18 },
      [920008] = { "Weapon", "Wands", "INVTYPE_RANGEDRIGHT", 2, 19 },
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
    local function try_slot(classToken, slotName, itemId)
      _G.UnitClass = function() return classToken, classToken end
      clear_slots()
      UI.OnGearSlot(slotName, "LeftButton")
      return UI.EquipItem(itemId)
    end
    UI.Show()
    local okMH, whyMH = try_slot("WARRIOR", "off_hand", 920001)
    eq(okMH, false)
    eq(whyMH, "wrong_slot")
    eq(UI.GetPreview().slots.off_hand, nil)
    eq(select(1, try_slot("WARRIOR", "off_hand", 920002)), false)
    eq(UI.GetPreview().slots.off_hand, nil)
    ok(try_slot("WARRIOR", "main_hand", 920001))
    eq(UI.GetPreview().slots.main_hand, 920001)
    eq(select(1, try_slot("WARRIOR", "off_hand", 920003)), false)
    eq(UI.GetPreview().slots.off_hand, nil)
    local okOne, whyOne = try_slot("DRUID", "off_hand", 920003)
    eq(okOne, false)
    eq(whyOne, "wrong_slot")
    eq(UI.GetPreview().slots.off_hand, nil)
    local okHunter, whyHunter = try_slot("HUNTER", "off_hand", 920003)
    eq(okHunter, false)
    eq(whyHunter, "wrong_slot")
    eq(select(1, try_slot("ROGUE", "off_hand", 920003)), false)
    eq(select(1, try_slot("WARRIOR", "main_hand", 920004)), false)
    ok(try_slot("WARRIOR", "off_hand", 920004))
    eq(select(1, try_slot("WARRIOR", "main_hand", 920005)), false)
    ok(try_slot("WARRIOR", "off_hand", 920005))
    eq(select(1, try_slot("MAGE", "main_hand", 920006)), false)
    ok(try_slot("MAGE", "off_hand", 920006))
    eq(select(1, try_slot("HUNTER", "main_hand", 920007)), false)
    eq(select(1, try_slot("HUNTER", "off_hand", 920007)), false)
    ok(try_slot("HUNTER", "ranged", 920007))
    eq(select(1, try_slot("MAGE", "main_hand", 920008)), false)
    ok(try_slot("MAGE", "ranged", 920008))
    eq(UI.AcceptsWeapon(920001, "off_hand", "WARRIOR"), false)
    eq(UI.AcceptsWeapon(920003, "off_hand", "WARRIOR"), false)
    eq(UI.AcceptsWeapon(920003, "off_hand", "HUNTER"), false)
    eq(UI.AcceptsWeapon(920003, "off_hand", "ROGUE"), false)
    eq(select(1, try_slot("DRUID", "off_hand", 920003)), false)
    eq(select(1, try_slot("DRUID", "off_hand", 920004)), false)
    eq(select(1, try_slot("DRUID", "off_hand", 920005)), false)
    eq(UI.AcceptsWeapon(920001, "off_hand", "DRUID"), false)
    eq(UI.AcceptsWeapon(920002, "off_hand", "DRUID"), false)
    eq(UI.AcceptsWeapon(920003, "off_hand", "DRUID"), false)
    eq(UI.AcceptsWeapon(920004, "off_hand", "DRUID"), false)
    eq(UI.AcceptsWeapon(920005, "off_hand", "DRUID"), false)
    eq(UI.AcceptsWeapon(920006, "off_hand", "DRUID"), true)
    ok(try_slot("DRUID", "off_hand", 920006))
    eq(UI.GetPreview().slots.off_hand, 920006)
    local idol = { "Armor", "Idol", "INVTYPE_RELIC", 4, 8 }
    local totem = { "Armor", "Totem", "INVTYPE_RELIC", 4, 9 }
    local libram = { "Armor", "Libram", "INVTYPE_RELIC", 4, 7 }
    local ammo = { "Projectile", "Arrow", "INVTYPE_AMMO", 6, 2 }
    info[920009] = idol
    info[920010] = totem
    info[920011] = libram
    info[920012] = ammo
    eq(select(1, try_slot("DRUID", "ranged", 920007)), false)
    ok(try_slot("DRUID", "ranged", 920009))
    eq(UI.GetPreview().slots.ranged, 920009)
    ok(try_slot("SHAMAN", "ranged", 920010))
    ok(try_slot("PALADIN", "ranged", 920011))
    eq(select(1, try_slot("PALADIN", "ranged", 920009)), false)
    eq(select(1, try_slot("MAGE", "ranged", 920007)), false)
    _G.UnitClass = function() return "Hunter", "HUNTER" end
    UI.GetPreview().slots.ranged = nil
    UI.Show()
    ok(_G.CrusaderStrikeAmmoSlot:IsShown())
    eq(_G.CrusaderStrikeRangedSlot._csLabel, "Ranged")
    eq(_G.CrusaderStrikeRangedSlot._csEmptyTex, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged")
    ok(try_slot("HUNTER", "ammo", 920012))
    eq(UI.GetPreview().slots.ammo, 920012)
    local mageAmmo, mageWhy = UI.CheckEquip(920012, "ammo", {}, "MAGE")
    eq(mageAmmo, false)
    eq(mageWhy, "wrong_slot")
    _G.UnitClass = function() return "Mage", "MAGE" end
    UI.Show()
    eq(_G.CrusaderStrikeAmmoSlot:IsShown(), false)
    eq(_G.CrusaderStrikeRangedSlot._csLabel, "Wand")
    _G.UnitClass = function() return "Druid", "DRUID" end
    UI.Show()
    eq(_G.CrusaderStrikeRangedSlot._csLabel, "Relic")
    _G.UnitClass = prevClass
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

  it("keeps the CS tab selected when the logo is clicked again", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevChar = _G.CharacterFrame
    local prevPaper = _G.PaperDollFrame
    local paper = {
      shown = true,
      Show = function(self) self.shown = true end,
      Hide = function(self) self.shown = false end,
      IsShown = function(self) return self.shown end,
    }
    _G.PaperDollFrame = paper
    _G.CharacterFrame = {
      ModeTabs = { Tabs = {} },
      activeSubframe = "PaperDollFrame",
      shown = true,
      IsShown = function(self) return self.shown end,
      ShowSubFrame = function(self, frameName)
        self.activeSubframe = frameName
        if self._csShowSubFrameObserved then
          -- hooksecurefunc wrapper calls the original then the hook.
        end
      end,
    }
    UI.Leave()
    eq(UI.GetPreview().active, false)
    local toggle = _G.CrusaderStrikeGearTabToggle
    toggle:GetScript("OnClick")(toggle)
    local root = _G.CrusaderStrikeCharacterGearFrame
    eq(UI.GetPreview().active, true)
    ok(root:IsShown())
    toggle:GetScript("OnClick")(toggle)
    eq(UI.GetPreview().active, true)
    ok(root:IsShown())
    eq(paper.shown, false)
    _G.CharacterFrame:ShowSubFrame("StatisticsFrame")
    eq(root:IsShown(), false)
    eq(UI.GetPreview().active, false)
    _G.CharacterFrame = prevChar
    _G.PaperDollFrame = prevPaper
  end)

  it("uses a class-specific empty icon on the ranged slot", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevClass = _G.UnitClass
    local prevChar = _G.CharacterFrame
    _G.CharacterFrame = {
      ModeTabs = { Tabs = {} },
      shown = true,
      IsShown = function(self) return self.shown end,
    }
    local L = CrusaderStrikeGearLayout
    eq(L.panes.main.owns[1], "doll")
    eq(L.panes.side.frame, "CrusaderStrikeGearPopout")
    eq(L.panels.browser.align, "center")
    eq(L.doll.anchor.point, "CENTER")
    eq(L.doll.anchor.x, 0)
    eq(L.doll.anchor.y, 0)
    UI.Show()
    local ranged = _G.CrusaderStrikeRangedSlot
    local ammo = _G.CrusaderStrikeAmmoSlot
    for _, token in ipairs({
      "DRUID", "SHAMAN", "PALADIN",
      "HUNTER", "WARRIOR", "ROGUE",
      "PRIEST", "MAGE", "WARLOCK",
    }) do
      local spec = L.rangedByClass[token]
      _G.UnitClass = function() return token, token end
      UI.GetPreview().slots.ranged = nil
      UI.Show()
      eq(ranged._csLabel, spec.label)
      eq(ranged._csEmptyTex, spec.empty)
      eq(ranged._iconTex, spec.empty)
      eq(ammo:IsShown(), spec.ammo == true)
    end
    eq(L.rangedByClass.DRUID.empty, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Relic")
    eq(L.rangedByClass.HUNTER.empty, "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged")
    eq(L.rangedByClass.MAGE.empty, "Interface\\Icons\\INV_Wand_01")
    eq(L.rangedByClass.SHAMAN.empty, "Interface\\Icons\\Spell_Nature_SlowingTotem")
    eq(L.rangedByClass.PALADIN.empty, "Interface\\Icons\\INV_Misc_Book_11")
    _G.UnitClass = prevClass
    _G.CharacterFrame = prevChar
  end)

  it("keeps the pop-out open the first time Gear Sets is selected", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevChar = _G.CharacterFrame
    _G.CharacterFrame = {
      ModeTabs = { Tabs = {} },
      shown = true,
      IsShown = function(self) return self.shown end,
    }
    UI.Show()
    UI.TogglePane("browser")
    UI.TogglePane("sets")
    -- Default open: Gear Sets is showing, but the player has not latched it yet.
    _G.CrusaderStrikeGearPopout._csPaneLatched = false
    eq(UI.GetPreview().popout, true)
    eq(UI.GetPreview().view, "sets")
    local icon = _G.CrusaderStrikeGearSetsIcon
    icon:GetScript("OnClick")(icon)
    eq(UI.GetPreview().popout, true)
    eq(UI.GetPreview().view, "sets")
    ok(_G.CrusaderStrikeGearPopout:IsShown())
    ok(_G.CrusaderStrikeGearSetsPanel:IsShown())
    eq(_G.CrusaderStrikeGearBrowserPanel:IsShown(), false)
    eq(_G.CrusaderStrikeGearStatsPanel:IsShown(), false)
    _G.CharacterFrame = prevChar
  end)

  it("lists a saved gear set and updates on rename and delete", function()
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
    UI.TogglePane("sets")
    UI.OnGearSlot("head", "LeftButton")
    ok(UI.EquipItem(14148))
    _G.CrusaderStrikeGearSetName:SetText("lol")
    _G.CrusaderStrikeGearSaveSet:GetScript("OnClick")()
    local row = _G.CrusaderStrikeGearSetsPanel._csRows[1]
    ok(row:IsShown())
    ok(row:GetText():find("lol", 1, true) ~= nil)
    eq(row:GetParent(), _G.CrusaderStrikeGearSetsPanel)
    local localId = row._localId
    ok(localId ~= nil)
    local updated = CrusaderStrikeGearSets.UpdateSet(_G.CrusaderStrikeCharDB, localId, { name = "renamed" }, 25)
    ok(updated ~= nil)
    ok(row:IsShown())
    ok(row:GetText():find("renamed", 1, true) ~= nil)
    row:GetScript("OnClick")(row)
    eq(UI.GetPreview().localId, localId)
    ok(CrusaderStrikeGearSets.DeleteSet(_G.CrusaderStrikeCharDB, localId))
    eq(row:IsShown(), false)
    eq(UI.GetPreview().localId, nil)
    _G.CharacterFrame = prevChar
    _G.CrusaderStrikeCharDB = prevDb
  end)

  it("enforces off-hand marks and armor tiers on every equip path", function()
    local UI = CrusaderStrike.CharacterGearTab
    local prevClass = _G.UnitClass
    local prevInfo = _G.GetItemInfoInstant
    local prevDb = _G.CrusaderStrikeCharDB
    local prevChar = _G.CharacterFrame
    _G.CrusaderStrikeCharDB = {}
    _G.CharacterFrame = {
      ModeTabs = { Tabs = {} },
      shown = true,
      IsShown = function(self) return self.shown end,
    }
    local info = {
      [930101] = { "Weapon", "Daggers", "INVTYPE_WEAPONOFFHAND", 2, 15 },
      [930102] = { "Weapon", "Daggers", "INVTYPE_WEAPONMAINHAND", 2, 15 },
      [930103] = { "Weapon", "Daggers", "INVTYPE_WEAPON", 2, 15 },
      [930104] = { "Weapon", "Two-Handed Swords", "INVTYPE_2HWEAPON", 2, 8 },
      [930105] = { "Armor", "Shields", "INVTYPE_SHIELD", 4, 6 },
      [930106] = { "Armor", "Miscellaneous", "INVTYPE_HOLDABLE", 4, 0 },
      [930111] = { "Armor", "Cloth", "INVTYPE_CHEST", 4, 1 },
      [930112] = { "Armor", "Leather", "INVTYPE_CHEST", 4, 2 },
      [930113] = { "Armor", "Mail", "INVTYPE_CHEST", 4, 3 },
      [930114] = { "Armor", "Plate", "INVTYPE_CHEST", 4, 4 },
    }
    _G.GetItemInfoInstant = function(itemId)
      local row = info[tonumber(itemId)]
      if not row then
        return prevInfo(itemId)
      end
      return itemId, row[1], row[2], row[3], "Interface\\Icons\\INV_CS_Item_" .. tostring(itemId), row[4], row[5]
    end
    local classes = { "WARRIOR", "ROGUE", "HUNTER", "DRUID", "SHAMAN", "PALADIN", "MAGE", "PRIEST", "WARLOCK" }
    local offhandWeapon = { WARRIOR = true, ROGUE = true, HUNTER = true }
    local shieldClass = { WARRIOR = true, PALADIN = true, SHAMAN = true }
    local armorMax = {
      MAGE = 1, PRIEST = 1, WARLOCK = 1,
      DRUID = 2, ROGUE = 2,
      HUNTER = 3, SHAMAN = 3,
      WARRIOR = 4, PALADIN = 4,
    }
    local armorItem = { [1] = 930111, [2] = 930112, [3] = 930113, [4] = 930114 }
    for _, classToken in ipairs(classes) do
      eq(select(1, UI.CheckEquip(930101, "off_hand", {}, classToken)), offhandWeapon[classToken] == true)
      eq(select(1, UI.CheckEquip(930102, "off_hand", {}, classToken)), false)
      eq(select(1, UI.CheckEquip(930103, "off_hand", {}, classToken)), false)
      eq(select(1, UI.CheckEquip(930104, "off_hand", {}, classToken)), false)
      eq(select(1, UI.CheckEquip(930105, "off_hand", {}, classToken)), shieldClass[classToken] == true)
      eq(select(1, UI.CheckEquip(930106, "off_hand", {}, classToken)), true)
      eq(select(1, UI.CheckEquip(930199, "off_hand", {}, classToken)), false)
      for tier = 1, 4 do
        local allowed = tier <= armorMax[classToken]
        eq(select(1, UI.CheckEquip(armorItem[tier], "chest", {}, classToken)), allowed)
        eq(UI.AcceptsWeapon(armorItem[tier], "chest", classToken), allowed)
      end
    end
    -- Cloak slot is not tiered. Mail on the back is unaffected.
    eq(UI.AcceptsWeapon(930113, "back", "DRUID"), true)

    _G.UnitClass = function() return "Druid", "DRUID" end
    UI.Show()
    UI.OnGearSlot("chest", "LeftButton")
    eq(select(1, UI.EquipItem(930113)), false)
    eq(select(1, UI.EquipItem(930114)), false)
    UI.OnGearSlot("off_hand", "LeftButton")
    eq(select(1, UI.EquipItem(930101)), false)
    eq(select(1, UI.EquipItem(930103)), false)
    ok(select(1, UI.EquipItem(930106)))

    local db = _G.CrusaderStrikeCharDB
    local list = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Path",
      type = "leveling",
      until_level = 20,
    }, 10)
    ok(list ~= nil)
    local savedMail, mailErr = CrusaderStrikeGearSets.SetSlot(db, list.local_id, "chest", 930113)
    eq(savedMail, nil)
    eq(mailErr, "class_armor")
    eq(list.slots.chest, nil)
    local savedPlate, plateErr = CrusaderStrikeGearSets.SetSlot(db, list.local_id, "chest", 930114)
    eq(savedPlate, nil)
    eq(plateErr, "class_armor")
    local savedLeather = CrusaderStrikeGearSets.SetSlot(db, list.local_id, "hands", 930112)
    ok(savedLeather ~= nil)
    eq(list.slots.hands, 930112)
    local savedOH, ohErr = CrusaderStrikeGearSets.SetSlot(db, list.local_id, "off_hand", 930101)
    eq(savedOH, nil)
    eq(ohErr, "wrong_slot")

    ok(CrusaderStrikeGearSets.ApplyImport(db, {
      lists = {
        {
          local_id = "mail-imp",
          name = "Imported",
          type = "max_level",
          edited_at = "2099-01-01T00:00:00Z",
          edited_in = "web",
          slots = { chest = 930113, head = 930112, off_hand = 930102 },
          removes = {},
        },
      },
    }))
    local imported = CrusaderStrikeGearSets.FindByLocalId(db, "mail-imp")
    eq(imported.slots.chest, nil)
    eq(imported.slots.head, 930112)
    eq(imported.slots.off_hand, nil)

    local live = CrusaderStrikeGearSets.FindByLocalId(db, list.local_id)
    live.slots.chest = 930113
    live.slots.wrist = 930111
    ok(UI.SelectSet(live.local_id))
    eq(UI.GetPreview().slots.chest, nil)
    eq(UI.GetPreview().slots.wrist, 930111)
    eq(UI.GetPreview().slots.hands, 930112)

    _G.UnitClass = function() return "Hunter", "HUNTER" end
    local hunterSet = CrusaderStrikeGearSets.CreateSet(db, {
      name = "Hunter OH",
      type = "leveling",
      until_level = 20,
    }, 10)
    local hunterOH = CrusaderStrikeGearSets.SetSlot(db, hunterSet.local_id, "off_hand", 930101)
    ok(hunterOH ~= nil)
    eq(hunterSet.slots.off_hand, 930101)
    local hunterGeneric = CrusaderStrikeGearSets.SetSlot(db, hunterSet.local_id, "off_hand", 930103)
    eq(hunterGeneric, nil)

    _G.UnitClass = prevClass
    _G.GetItemInfoInstant = prevInfo
    _G.CrusaderStrikeCharDB = prevDb
    _G.CharacterFrame = prevChar
  end)
end)
