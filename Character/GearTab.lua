-- Character-pane wishlist tab (scaffold).
--
-- Last mode tab on Forever's Camelot CharacterFrame. The CS subframe reuses the
-- real PaperDoll slot buttons (CharacterHeadSlot … CharacterTabardSlot). It does
-- not draw copy slots, does not equip, and does not sync with Equipment Manager.
--
-- AtlasLoot Classic data.lua is a layout reference only (GPL-2.0). Do not copy
-- it wholesale. See docs/character-gear-tab.md.
--
-- The addon is Lua-only. This file is the CreateFrame stand-in for a FrameXML
-- child: the tab has to be appended at runtime onto CharacterFrame.ModeTabs.
--
-- ShowSubFrame is observed with hooksecurefunc (never replaced) and the CS
-- enter work is deferred with C_Timer.After(0) so Blizzard's character-frame
-- refresh is not tainted. PaperDoll slot buttons are HookScript'd, not
-- SetScript-replaced. Gear Sets / Browser are icon buttons on the right-pane
-- header (PaperDollSidebarTabs strip), not text buttons over the portrait.

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike
CS.CharacterGearTab = CS.CharacterGearTab or {}
local UI = CS.CharacterGearTab

UI.FRAME_NAME = "CrusaderStrikeCharacterGearFrame"

-- Blizzard PaperDollItemsFrame buttons (Forever Camelot PaperDollFrame.xml).
-- inv order matches Logic/GearSlots.lua. Ammo is not a gear-set slot.
UI.SLOT_BUTTONS = {
  { global = "CharacterHeadSlot", slot = "head" },
  { global = "CharacterNeckSlot", slot = "neck" },
  { global = "CharacterShoulderSlot", slot = "shoulder" },
  { global = "CharacterShirtSlot", slot = "shirt" },
  { global = "CharacterChestSlot", slot = "chest" },
  { global = "CharacterWaistSlot", slot = "waist" },
  { global = "CharacterLegsSlot", slot = "legs" },
  { global = "CharacterFeetSlot", slot = "feet" },
  { global = "CharacterWristSlot", slot = "wrist" },
  { global = "CharacterHandsSlot", slot = "hands" },
  { global = "CharacterFinger0Slot", slot = "finger1" },
  { global = "CharacterFinger1Slot", slot = "finger2" },
  { global = "CharacterTrinket0Slot", slot = "trinket1" },
  { global = "CharacterTrinket1Slot", slot = "trinket2" },
  { global = "CharacterBackSlot", slot = "back" },
  { global = "CharacterMainHandSlot", slot = "main_hand" },
  { global = "CharacterSecondaryHandSlot", slot = "off_hand" },
  { global = "CharacterRangedSlot", slot = "ranged" },
  { global = "CharacterTabardSlot", slot = "tabard" },
}

-- Placeholder rows. Next step: sum Forever item stats for preview slots.
UI.STAT_LABELS = {
  "Strength",
  "Agility",
  "Stamina",
  "Intellect",
  "Spirit",
  "Armor",
  "Attack Power",
  "Spell Power",
}

-- Forever Camelot insets so chrome does not cover Character*Slot buttons.
-- Head slot: TOPLEFT of LeftPaneHost (24, -60). Weapon row: BOTTOM of
-- LeftPaneHost, y=30 (PaperDollItemSlotButton_OnLoad). The level/class line
-- sits on PaperDollFrame.TopBackgroundStripHost (36px, left pane only).
-- Confirm in client.
local SLOT_SIDE_INSET = 72
local SLOT_TOP_INSET = 44
local WEAPON_BOTTOM_INSET = 84
local MAX_ROWS = 8
-- PaperDollSidebarTabTemplate is 42x42, anchored TOP of the right pane.
local ICON_SIZE = 42
local GEAR_SETS_ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local BROWSER_ICON = "Interface\\Icons\\INV_Misc_Bag_08"
local CS_LOGO = "Interface\\AddOns\\CrusaderStrike\\assets\\logo.tga"

local SLOT_LABEL = {
  head = "Head",
  neck = "Neck",
  shoulder = "Shoulder",
  shirt = "Shirt",
  chest = "Chest",
  waist = "Waist",
  legs = "Legs",
  feet = "Feet",
  wrist = "Wrist",
  hands = "Hands",
  finger1 = "Finger",
  finger2 = "Finger",
  trinket1 = "Trinket",
  trinket2 = "Trinket",
  back = "Back",
  main_hand = "Main Hand",
  off_hand = "Off Hand",
  ranged = "Ranged",
  tabard = "Tabard",
}

local state = {
  active = false,
  tabAdded = false,
  view = "sets",
  activeSlot = nil,
  localId = nil,
  previewSlots = {},
  filled = 0,
  search = "",
  instanceId = nil,
  dungeonPick = 0,
  gearSlot = nil,
}

local hooked = {}
local subframeHooked = false

local root
local topSetsBtn
local topBrowserBtn
local setsPanel
local browserPanel
local setsEmpty
local browserEmpty
local setsMore
local browserMore
local dungeonBtn
local searchBox
local statusText
local statsHeader
local statsFooter
local statLines = {}
local setButtons = {}
local resultButtons = {}

local BACKDROP = {
  bgFile = "Interface/Tooltips/UI-Tooltip-Background",
  edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function char_db()
  return CS.GetCharDB and CS.GetCharDB() or CrusaderStrikeCharDB
end

local function game_version()
  if CS.GetGameVersion then
    return CS.GetGameVersion()
  end
  return "forever"
end

local function filled_count(slots)
  local n = 0
  if type(slots) ~= "table" then
    return 0
  end
  for _, v in pairs(slots) do
    if type(v) == "number" then
      n = n + 1
    end
  end
  return n
end

local function apply_backdrop(frame)
  if frame and frame.SetBackdrop then
    frame:SetBackdrop(BACKDROP)
  end
  if frame and frame.SetBackdropColor then
    frame:SetBackdropColor(0, 0, 0, 0.88)
  end
end

local function add_text(parent, template, text, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x or 8, y or -8)
  if fs.SetJustifyH then
    fs:SetJustifyH("LEFT")
  end
  if fs.SetWordWrap then
    fs:SetWordWrap(true)
  end
  if text and fs.SetText then
    fs:SetText(text)
  end
  return fs
end

local function set_text(fs, text)
  if fs and fs.SetText then
    fs:SetText(text or "")
  end
end

local function set_status(msg)
  set_text(statusText, msg or "")
end

local function hide_frame(obj)
  if obj and obj.Hide then
    obj:Hide()
  end
end

local function hide_equip_chrome()
  -- Equipment Manager already lives on the character sheet. Keep its Equip
  -- button out of this wishlist tab.
  hide_frame(_G.PaperDollSidebarTabs)
  local pd = _G.PaperDollFrame
  if pd then
    hide_frame(pd.EquipmentManagerPane)
  end
  if type(_G.PAPERDOLL_SIDEBARS) == "table" and type(_G.GetPaperDollSideBarFrame) == "function" then
    for i = 1, #_G.PAPERDOLL_SIDEBARS do
      hide_frame(_G.GetPaperDollSideBarFrame(i))
    end
  end
end

local function restore_chrome()
  local cf = _G.CharacterFrame
  local pd = _G.PaperDollFrame
  if cf and cf.Expand and pd and pd.IsShown and pd:IsShown() then
    pcall(cf.Expand, cf)
  elseif type(_G.PaperDollFrame_UpdateSidebarTabs) == "function" then
    pcall(_G.PaperDollFrame_UpdateSidebarTabs)
  end
end

local function button_for_slot(slotName)
  for _, info in ipairs(UI.SLOT_BUTTONS) do
    if info.slot == slotName then
      return _G[info.global]
    end
  end
  return nil
end

local function restore_icon(button)
  local icon = button and (button.icon or button.Icon)
  if not icon or not icon.SetTexture or not icon._csPrev then
    return
  end
  icon:SetTexture(icon._csPrev)
  icon._csPrev = nil
end

local function paint_slot(slotName, itemId)
  local button = button_for_slot(slotName)
  if not button then
    return
  end
  local icon = button.icon or button.Icon
  if not icon or not icon.SetTexture then
    return
  end
  if not itemId then
    restore_icon(button)
    return
  end
  if type(GetItemIcon) ~= "function" then
    return
  end
  local ok, texture = pcall(GetItemIcon, itemId)
  if not ok or not texture then
    return
  end
  if not icon._csPrev and icon.GetTexture then
    icon._csPrev = icon:GetTexture()
  end
  icon:SetTexture(texture)
end

local function refresh_slot_icons()
  for _, info in ipairs(UI.SLOT_BUTTONS) do
    paint_slot(info.slot, state.previewSlots[info.slot])
  end
end

local function clear_preview_icons()
  for _, info in ipairs(UI.SLOT_BUTTONS) do
    local button = _G[info.global]
    if button then
      restore_icon(button)
    end
  end
end

local function refresh_stats()
  state.filled = filled_count(state.previewSlots)
  -- Placeholder totals. Item-stat math is the next step; do not invent numbers.
  for i, label in ipairs(UI.STAT_LABELS) do
    set_text(statLines[i], label .. "  —")
  end
  local slotNote = state.activeSlot and ("Slot: " .. state.activeSlot .. ". ") or ""
  set_text(
    statsFooter,
    slotNote .. "Preview slots filled: " .. tostring(state.filled) .. ". Stat totals are not computed yet."
  )
  refresh_slot_icons()
end

local function mark_icon(btn, selected)
  if not btn then
    return
  end
  if btn.SetChecked then
    btn:SetChecked(selected and true or false)
  end
  local glow = btn._csGlow
  if glow then
    if selected and glow.Show then
      glow:Show()
    elseif glow.Hide then
      glow:Hide()
    end
  end
  if selected and btn.LockHighlight then
    btn:LockHighlight()
  elseif btn.UnlockHighlight then
    btn:UnlockHighlight()
  end
end

local function refresh_top_tabs()
  -- Icons only. Names live on the tooltip. No bracketed text labels.
  mark_icon(topSetsBtn, state.view == "sets")
  mark_icon(topBrowserBtn, state.view == "browser")
  if setsPanel and setsPanel.SetShown then
    setsPanel:SetShown(state.view == "sets")
  elseif setsPanel then
    if state.view == "sets" then setsPanel:Show() else setsPanel:Hide() end
  end
  if browserPanel and browserPanel.SetShown then
    browserPanel:SetShown(state.view == "browser")
  elseif browserPanel then
    if state.view == "browser" then browserPanel:Show() else browserPanel:Hide() end
  end
end

local function show_view(view)
  state.view = view == "browser" and "browser" or "sets"
  refresh_top_tabs()
end

local function saved_lists()
  local db = char_db()
  if not db or not CrusaderStrikeGearSets or not CrusaderStrikeGearSets.EnsureDB then
    return {}
  end
  local bucket = CrusaderStrikeGearSets.EnsureDB(db)
  if not bucket or type(bucket.lists) ~= "table" then
    return {}
  end
  return bucket.lists
end

local function refresh_gear_list()
  if not setsPanel then
    return
  end
  local lists = saved_lists()
  local shown = math.min(#lists, MAX_ROWS)
  for i = 1, MAX_ROWS do
    local btn = setButtons[i]
    local list = lists[i]
    if btn then
      if list then
        btn:Show()
        btn._localId = list.local_id
        local mark = (list.local_id == state.localId) and "• " or ""
        btn:SetText(mark .. (list.name or "gear set"))
      else
        btn:Hide()
        btn._localId = nil
      end
    end
  end
  if setsEmpty then
    if #lists == 0 then
      setsEmpty:Show()
    else
      setsEmpty:Hide()
    end
  end
  if setsMore then
    if #lists > shown then
      setsMore:Show()
      set_text(setsMore, "Showing " .. tostring(shown) .. " of " .. tostring(#lists) .. ".")
    else
      setsMore:Hide()
    end
  end
end

local function browser_rows()
  if not CrusaderStrikeGearBrowser or not CrusaderStrikeGearBrowser.Filter then
    return {}
  end
  return CrusaderStrikeGearBrowser.Filter({
    instanceId = state.instanceId,
    search = state.search,
    gearSlot = state.gearSlot,
    difficulty = CrusaderStrikeGearBrowser.FOREVER_NORMAL,
  }, game_version())
end

local function browser_empty_text()
  if state.gearSlot then
    local label = SLOT_LABEL[state.gearSlot] or state.gearSlot
    return "No " .. label .. " items in the Forever overlay."
  end
  return "No matching items. Forever overlay is a stub — see docs/character-gear-tab.md."
end

local function dungeon_label()
  if not state.instanceId then
    return "Dungeon: All"
  end
  if CrusaderStrikeGearBrowser and CrusaderStrikeGearBrowser.ListDungeons then
    local list = CrusaderStrikeGearBrowser.ListDungeons(game_version())
    for _, dungeon in ipairs(list) do
      if dungeon.instanceId == state.instanceId then
        return "Dungeon: " .. (dungeon.name or tostring(dungeon.instanceId))
      end
    end
  end
  return "Dungeon: " .. tostring(state.instanceId)
end

local function refresh_browser()
  if not browserPanel then
    return
  end
  if dungeonBtn and dungeonBtn.SetText then
    dungeonBtn:SetText(dungeon_label())
  end
  local rows = browser_rows()
  local shown = math.min(#rows, MAX_ROWS)
  for i = 1, MAX_ROWS do
    local btn = resultButtons[i]
    local row = rows[i]
    if btn then
      if row then
        btn:Show()
        btn._itemId = row.itemId
        local name = row.name or ("item " .. tostring(row.itemId))
        local boss = row.bossName and (row.bossName .. ": ") or ""
        btn:SetText(boss .. name .. "  " .. tostring(row.itemId))
      else
        btn:Hide()
        btn._itemId = nil
      end
    end
  end
  if browserEmpty then
    set_text(browserEmpty, browser_empty_text())
    if #rows == 0 then
      browserEmpty:Show()
    else
      browserEmpty:Hide()
    end
  end
  if browserMore then
    if #rows > shown then
      browserMore:Show()
      set_text(browserMore, "Showing " .. tostring(shown) .. " of " .. tostring(#rows) .. ".")
    else
      browserMore:Hide()
    end
  end
end

local function refresh_all()
  refresh_top_tabs()
  refresh_gear_list()
  refresh_browser()
  refresh_stats()
end

function UI.GetPreview()
  return {
    active = state.active,
    activeSlot = state.activeSlot,
    localId = state.localId,
    slots = state.previewSlots,
    filled = state.filled,
    view = state.view,
    gearSlot = state.gearSlot,
  }
end

function UI.OnPaperDollSlot(slotName)
  if not CrusaderStrikeGearSlots or not CrusaderStrikeGearSlots.IsValidName(slotName) then
    return
  end
  state.activeSlot = slotName
  state.gearSlot = slotName
  state.view = "browser"
  refresh_all()
  local label = SLOT_LABEL[slotName] or slotName
  set_status("Wishlist " .. label .. " — pick an item (not equipped)")
end

-- In-memory wishlist preview only. Does not write the saved set or equip.
function UI.AssignPreviewItem(itemId)
  if not state.activeSlot then
    set_status("Select a paper doll slot first.")
    return false, "no_slot"
  end
  itemId = tonumber(itemId)
  if not itemId or itemId < 1 or itemId ~= math.floor(itemId) then
    return false, "bad_item"
  end
  state.previewSlots[state.activeSlot] = itemId
  local name
  if CrusaderStrikeGearBrowser and CrusaderStrikeGearBrowser.ItemName then
    name = CrusaderStrikeGearBrowser.ItemName(itemId, nil, game_version())
  end
  local extra = name and (" (" .. name .. ")") or ""
  set_status("Preview " .. state.activeSlot .. " = " .. tostring(itemId) .. extra)
  refresh_stats()
  return true
end

function UI.SelectSet(localId)
  local db = char_db()
  if not db or not CrusaderStrikeGearSets or not CrusaderStrikeGearSets.FindByLocalId then
    return false
  end
  local list = CrusaderStrikeGearSets.FindByLocalId(db, localId)
  if not list then
    return false
  end
  state.localId = localId
  state.previewSlots = {}
  if type(list.slots) == "table" then
    for slot, itemId in pairs(list.slots) do
      if type(itemId) == "number" and CrusaderStrikeGearSlots.IsValidName(slot) then
        state.previewSlots[slot] = itemId
      end
    end
  end
  set_status("Previewing set " .. (list.name or "") .. " (not equipped)")
  refresh_gear_list()
  refresh_stats()
  return true
end

-- Post-hooks only. SetScript would replace Blizzard's handler and taint the
-- paper doll. HookScript leaves that handler in place; disabling the record
-- turns our callback into a no-op (WoW has no UnhookScript). The hook never
-- calls PickupInventoryItem, UseInventoryItem, or Equipment Manager APIs.
local HOOK_SCRIPTS = { "OnClick", "OnReceiveDrag", "OnDragStart" }

local function apply_hooks()
  for _, info in ipairs(UI.SLOT_BUTTONS) do
    local button = _G[info.global]
    local rec = hooked[info.global]
    if rec then
      rec.enabled = true
    elseif button and button.HookScript then
      local slotName = info.slot
      rec = { enabled = true }
      hooked[info.global] = rec
      for _, scriptName in ipairs(HOOK_SCRIPTS) do
        local script = scriptName
        local function handler()
          if not rec.enabled or not state.active then
            return
          end
          if script == "OnClick" then
            UI.OnPaperDollSlot(slotName)
          end
        end
        pcall(button.HookScript, button, script, handler)
      end
    end
  end
end

local function restore_hooks()
  for _, rec in pairs(hooked) do
    rec.enabled = false
  end
end

local function cycle_dungeon()
  local list = {}
  if CrusaderStrikeGearBrowser and CrusaderStrikeGearBrowser.ListDungeons then
    list = CrusaderStrikeGearBrowser.ListDungeons(game_version())
  end
  state.dungeonPick = (state.dungeonPick or 0) + 1
  if state.dungeonPick > #list then
    state.dungeonPick = 0
    state.instanceId = nil
  else
    state.instanceId = list[state.dungeonPick].instanceId
  end
  refresh_browser()
end

local function bind_icon_tooltip(btn, tooltip)
  btn.tooltipText = tooltip
  btn:SetScript("OnEnter", function(self)
    if GameTooltip and GameTooltip.SetOwner then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltip)
      if GameTooltip.Show then
        GameTooltip:Show()
      end
    end
  end)
  btn:SetScript("OnLeave", function()
    if GameTooltip and GameTooltip.Hide then
      GameTooltip:Hide()
    end
  end)
end

local function add_icon_button(parent, name, texture, tooltip)
  local btn = CreateFrame("CheckButton", name, parent)
  btn:SetSize(ICON_SIZE, ICON_SIZE)
  btn._csIcon = texture
  if btn.CreateTexture then
    local icon = btn:CreateTexture(nil, "ARTWORK")
    if icon.SetPoint then
      icon:SetPoint("CENTER")
    end
    if icon.SetSize then
      icon:SetSize(36, 36)
    end
    if icon.SetTexture then
      icon:SetTexture(texture)
    end
    if icon.SetTexCoord then
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    btn.icon = icon
    local glow = btn:CreateTexture(nil, "OVERLAY")
    if glow.SetAllPoints then
      glow:SetAllPoints()
    end
    if glow.SetTexture then
      glow:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    end
    if glow.SetBlendMode then
      glow:SetBlendMode("ADD")
    end
    if glow.Hide then
      glow:Hide()
    end
    btn._csGlow = glow
  end
  bind_icon_tooltip(btn, tooltip)
  return btn
end

local function ensure_ui()
  local cf = _G.CharacterFrame
  if root or not cf then
    return
  end

  root = CreateFrame("Frame", UI.FRAME_NAME, cf)
  root:SetAllPoints(cf)
  if root.EnableMouse then
    root:EnableMouse(false)
  end
  if root.SetFrameLevel then
    root:SetFrameLevel(1)
  end
  root:SetScript("OnHide", function()
    UI.Leave()
  end)

  local left = cf.LeftPaneHost or cf
  local right = cf.RightPaneHost or cf

  -- Same strip as PaperDollSidebarTabs: TOP of the right pane, 42px icons.
  -- Not on the left pane, so CharacterLevelText stays visible.
  local iconRow = CreateFrame("Frame", "CrusaderStrikeGearIconRow", root)
  iconRow:SetSize(92, 46)
  iconRow:SetPoint("TOP", right, "TOP", 0, -4)
  if iconRow.EnableMouse then
    iconRow:EnableMouse(false)
  end
  if iconRow.SetFrameLevel then
    iconRow:SetFrameLevel(40)
  end

  topSetsBtn = add_icon_button(iconRow, "CrusaderStrikeGearSetsIcon", GEAR_SETS_ICON, "Gear Sets")
  topSetsBtn:SetPoint("RIGHT", iconRow, "CENTER", -2, 0)
  topSetsBtn:SetScript("OnClick", function()
    show_view("sets")
  end)

  topBrowserBtn = add_icon_button(iconRow, "CrusaderStrikeGearBrowserIcon", BROWSER_ICON, "Browser")
  topBrowserBtn:SetPoint("LEFT", iconRow, "CENTER", 2, 0)
  topBrowserBtn:SetScript("OnClick", function()
    show_view("browser")
  end)

  local leftPane = left
  local center = CreateFrame("Frame", nil, root, "BackdropTemplate")
  center:SetPoint("TOPLEFT", leftPane, "TOPLEFT", SLOT_SIDE_INSET, -SLOT_TOP_INSET)
  center:SetPoint("BOTTOMRIGHT", leftPane, "BOTTOMRIGHT", -SLOT_SIDE_INSET, WEAPON_BOTTOM_INSET)
  if center.EnableMouse then
    center:EnableMouse(true)
  end
  if center.SetFrameLevel then
    center:SetFrameLevel(80)
  end
  apply_backdrop(center)

  setsPanel = CreateFrame("Frame", nil, center)
  setsPanel:SetAllPoints(center)
  browserPanel = CreateFrame("Frame", nil, center)
  browserPanel:SetAllPoints(center)
  browserPanel:Hide()

  setsEmpty = add_text(
    setsPanel,
    "GameFontHighlightSmall",
    "No saved gear sets yet. Create them with /cs gearsets. This list only previews a wishlist.",
    8,
    -8
  )
  if setsEmpty.SetWidth then
    setsEmpty:SetWidth(220)
  end
  setsMore = add_text(setsPanel, "GameFontDisableSmall", "", 8, -8 - (MAX_ROWS * 24))
  setsMore:Hide()

  for i = 1, MAX_ROWS do
    local btn = CreateFrame("Button", nil, setsPanel, "UIPanelButtonTemplate")
    btn:SetSize(220, 22)
    btn:SetPoint("TOPLEFT", setsPanel, "TOPLEFT", 8, -8 - ((i - 1) * 24))
    btn:Hide()
    btn:SetScript("OnClick", function(self)
      local localId = self._localId
      if localId then
        UI.SelectSet(localId)
      end
    end)
    setButtons[i] = btn
  end

  dungeonBtn = CreateFrame("Button", nil, browserPanel, "UIPanelButtonTemplate")
  dungeonBtn:SetSize(220, 22)
  dungeonBtn:SetPoint("TOPLEFT", browserPanel, "TOPLEFT", 8, -8)
  dungeonBtn:SetText("Dungeon: All")
  dungeonBtn:SetScript("OnClick", cycle_dungeon)

  add_text(browserPanel, "GameFontHighlightSmall", "Name or item ID", 8, -36)
  searchBox = CreateFrame("EditBox", "CrusaderStrikeGearSearch", browserPanel, "InputBoxTemplate")
  searchBox:SetSize(120, 20)
  searchBox:SetPoint("TOPLEFT", browserPanel, "TOPLEFT", 110, -32)
  searchBox:SetAutoFocus(false)
  if searchBox.SetMaxLetters then
    searchBox:SetMaxLetters(64)
  end
  searchBox:SetScript("OnEnterPressed", function(self)
    if self.ClearFocus then
      self:ClearFocus()
    end
  end)
  searchBox:SetScript("OnTextChanged", function(self)
    state.search = (self.GetText and self:GetText()) or ""
    refresh_browser()
  end)

  browserEmpty = add_text(
    browserPanel,
    "GameFontHighlightSmall",
    "No matching items. Forever overlay is a stub — see docs/character-gear-tab.md.",
    8,
    -64
  )
  if browserEmpty.SetWidth then
    browserEmpty:SetWidth(220)
  end
  browserMore = add_text(browserPanel, "GameFontDisableSmall", "", 8, -64 - 16 - (MAX_ROWS * 22))
  browserMore:Hide()

  for i = 1, MAX_ROWS do
    local btn = CreateFrame("Button", nil, browserPanel, "UIPanelButtonTemplate")
    btn:SetSize(220, 20)
    btn:SetPoint("TOPLEFT", browserPanel, "TOPLEFT", 8, -84 - ((i - 1) * 22))
    btn:Hide()
    btn:SetScript("OnClick", function(self)
      local itemId = self._itemId
      if itemId then
        UI.AssignPreviewItem(itemId)
      end
    end)
    resultButtons[i] = btn
  end

  statusText = add_text(center, "GameFontDisableSmall", "Select a paper doll slot, then pick an item. Wishlist preview only.", 8, -4)
  statusText:ClearAllPoints()
  statusText:SetPoint("BOTTOMLEFT", center, "BOTTOMLEFT", 8, 6)
  if statusText.SetWidth then
    statusText:SetWidth(220)
  end

  local stats = CreateFrame("Frame", nil, root, "BackdropTemplate")
  -- Below the 42px icon row (top of the right pane, y=-4).
  stats:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -52)
  stats:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -8, 8)
  if stats.EnableMouse then
    stats:EnableMouse(true)
  end
  if stats.SetFrameLevel then
    stats:SetFrameLevel(10)
  end
  apply_backdrop(stats)

  statsHeader = add_text(stats, "GameFontNormal", "Wishlist preview", 10, -10)
  add_text(stats, "GameFontDisableSmall", "Not equipped. Totals update when preview items are filled in.", 10, -28)
  for i, label in ipairs(UI.STAT_LABELS) do
    statLines[i] = add_text(stats, "GameFontHighlightSmall", label .. "  —", 10, -52 - ((i - 1) * 16))
  end
  statsFooter = add_text(stats, "GameFontDisableSmall", "Preview slots filled: 0. Stat totals are not computed yet.", 10, -52 - (#UI.STAT_LABELS * 16) - 8)
  if statsFooter.SetWidth then
    statsFooter:SetWidth(200)
  end

  show_view("sets")
end

function UI.Leave()
  if not state.active then
    return
  end
  state.active = false
  restore_hooks()
  clear_preview_icons()
  if root and root.IsShown and root:IsShown() then
    root:Hide()
  end
  restore_chrome()
end

function UI.Enter()
  local cf = _G.CharacterFrame
  if not cf then
    return
  end
  state.active = true
  local pd = _G.PaperDollFrame
  if pd and pd.Show then
    pd:Show()
  end
  if cf.IsRightPaneCollapsed and cf.SetRightPaneCollapsed and cf:IsRightPaneCollapsed() then
    pcall(cf.SetRightPaneCollapsed, cf, false)
  end
  hide_equip_chrome()
  ensure_ui()
  if root then
    root:Show()
  end
  apply_hooks()
  if cf.SetSelectedModeTabByFrame then
    pcall(cf.SetSelectedModeTabByFrame, cf, UI.FRAME_NAME)
  end
  -- Do not call CharacterFrame:RefreshDisplay(). That runs TextStatusBar
  -- updates on our call stack and taints secret number compares.
  refresh_all()
end

local function defer(fn)
  if C_Timer and C_Timer.After then
    C_Timer.After(0, fn)
  else
    fn()
  end
end

local function hook_show_subframe(cf)
  if subframeHooked or not cf or type(cf.ShowSubFrame) ~= "function" then
    return
  end
  if type(hooksecurefunc) ~= "function" then
    return
  end
  -- Post-hook only. Replacing ShowSubFrame runs Blizzard's refresh tainted.
  hooksecurefunc(cf, "ShowSubFrame", function(_, frameName)
    defer(function()
      if frameName == UI.FRAME_NAME then
        UI.Enter()
      else
        UI.Leave()
      end
    end)
  end)
  subframeHooked = true
end

local function add_mode_tab(cf)
  if state.tabAdded then
    return
  end
  local modeTabs = cf.ModeTabs
  local tabs = modeTabs and modeTabs.Tabs
  if not modeTabs or type(tabs) ~= "table" then
    return
  end
  local nextId = 1
  local last
  for _, tab in ipairs(tabs) do
    last = tab
    local id = 0
    if tab.GetID then
      id = tab:GetID() or 0
    end
    if id >= nextId then
      nextId = id + 1
    end
  end
  local tabName = "CharacterFrameModeTab" .. tostring(nextId)
  if _G[tabName] then
    state.tabAdded = true
    return
  end
  local ok, tab = pcall(CreateFrame, "CheckButton", tabName, modeTabs, "CharacterFrameModeSideTabTemplate")
  if not ok or not tab then
    ok, tab = pcall(CreateFrame, "Frame", tabName, modeTabs, "CharacterFrameModeSideTabTemplate")
  end
  if not ok or not tab then
    return
  end
  if tab.SetID then
    tab:SetID(nextId)
  end
  tab.frameName = UI.FRAME_NAME
  tab.tooltipText = "Crusader Strike"
  if tab.SetCustomOnMouseUpHandler then
    tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
      if button == "LeftButton" and (upInside == nil or upInside) then
        UI.Show()
      end
    end)
  end
  tab:SetScript("OnClick", function()
    UI.Show()
  end)
  tab:SetScript("OnEnter", function(self)
    if GameTooltip and GameTooltip.SetOwner then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Crusader Strike")
      if GameTooltip.Show then
        GameTooltip:Show()
      end
    end
  end)
  tab:SetScript("OnLeave", function()
    if GameTooltip and GameTooltip.Hide then
      GameTooltip:Hide()
    end
  end)
  tab._csIcon = CS_LOGO
  if tab.Icon and tab.Icon.SetTexture then
    tab.Icon:SetTexture(CS_LOGO)
  elseif tab.icon and tab.icon.SetTexture then
    tab.icon:SetTexture(CS_LOGO)
  end
  if tab.ClearAllPoints then
    tab:ClearAllPoints()
  end
  if last and tab.SetPoint then
    local anchorToLast = last.IsShown and last:IsShown()
    if anchorToLast then
      tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2)
    else
      tab:SetPoint("TOPLEFT", modeTabs, "TOPLEFT", 0, 0)
    end
  end
  if tab.Show then
    tab:Show()
  end
  tabs[#tabs + 1] = tab
  state.tabAdded = true
  if cf.UpdateTabLayout then
    pcall(cf.UpdateTabLayout, cf)
  end
end

function UI.Install()
  local cf = _G.CharacterFrame
  if not cf then
    return false
  end
  hook_show_subframe(cf)
  add_mode_tab(cf)
  return true
end

function UI.Show()
  if not UI.Install() then
    if CS.Print then
      CS.Print("character pane unavailable")
    end
    return
  end
  local cf = _G.CharacterFrame
  if ShowUIPanel then
    ShowUIPanel(cf)
  elseif cf.Show then
    cf:Show()
  end
  if cf.ShowSubFrame then
    cf:ShowSubFrame(UI.FRAME_NAME)
  else
    UI.Enter()
  end
end

local watcher = CreateFrame("Frame", "CrusaderStrikeCharacterGearWatcher")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 ~= (CS.ADDON_NAME or "CrusaderStrike") then
    return
  end
  if not UI.Install() and C_Timer and C_Timer.After then
    C_Timer.After(1, function()
      UI.Install()
    end)
  end
end)
