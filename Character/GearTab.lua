-- Crusader Strike gear pane, as a mode-tab sibling of Character / Statistics.
--
-- CrusaderStrikeCharacterGearFrame is a content pane on CharacterFrame, in
-- the same rectangle PaperDoll uses. It is not a SetAllPoints cover and it
-- does not sit on the side-tab strip. The doll (CrusaderStrikeGearDoll) and
-- the sets / browser / stats column are children of that pane.
--
-- The logo button uses CharacterFrameModeSideTabTemplate and is NOT inserted
-- into ModeTabs.Tabs (that injection tainted Character open). Selecting it
-- hides CharacterFrame.activeSubframe and shows this pane. An observe-only
-- hooksecurefunc on ShowSubFrame hides this pane when Forever switches tabs.
-- This file never replaces ShowSubFrame and never calls it.
--
-- Taint:
--   * No ModeTabs.Tabs write
--   * No ShowSubFrame replacement, no OnShow hook
--   * No SetScript swaps on Blizzard paper-doll buttons
--   * No ShowUIPanel / CharacterFrame:Show / RefreshDisplay / SecureActionButton:Click
--   * CS-owned slot buttons (CrusaderStrikeHeadSlot …), never Character*Slot
--
-- /cs geartab selects this tab only while CharacterFrame is already shown.
--
-- Weapon equip uses vanilla class proficiency (Forever 1.60.1 / Classic):
-- a Druid cannot take swords or crossbows, and nobody can wear two main-hand
-- weapons. Armor slots (head, shoulder, chest, waist, legs, feet, wrist,
-- hands) follow class armor with no level gate. Druid/rogue wear cloth and
-- leather. Shaman/hunter also wear mail at any level. Paladin/warrior also
-- wear plate at any level. Mage/priest/warlock wear cloth only. Cloaks,
-- rings, necks, and trinkets are not filtered by armor type.
-- Left-click a browser item to equip it into the current gear set; right-click
-- a CS gear-set slot to unequip. AtlasLoot Classic data.lua is a layout
-- reference only (GPL-2.0). See docs/character-gear-tab.md.

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike
CS.CharacterGearTab = CS.CharacterGearTab or {}
local UI = CS.CharacterGearTab

UI.FRAME_NAME = "CrusaderStrikeCharacterGearFrame"

-- Classic PaperDoll content (CharacterFrame) and the collapsible right pane
-- that holds Character Stats / Titles / Equipment Manager.
-- Sizes are the Blizzard PaperDoll sidebar geometry (read-only reference):
--   PaperDoll / CharacterFrame content 338 x 424
--   Item slots 37; left column TOPLEFT 21,-76 step -4; right TOPRIGHT -21,-76
--   Weapons BOTTOMLEFT 122,20 then +5: main hand, off hand, ranged
--   PaperDollSidebarTabTemplate 33 x 35, 4px gap, right-aligned
--   CharacterFrame InsetRight width 177
UI.PAPERDOLL_WIDTH = 338
UI.PAPERDOLL_HEIGHT = 424
UI.SIDEBAR_WIDTH = 177
UI.SIDEBAR_TAB_W = 33
UI.SIDEBAR_TAB_H = 35
UI.SIDEBAR_TAB_GAP = 4
UI.WEAPON_ROW_X = 122
UI.WEAPON_ROW_Y = 20
UI.WEAPON_ROW_GAP = 5
UI.POPOUT_WIDTH = UI.SIDEBAR_WIDTH
UI.POPOUT_INSET = 4
UI.POPOUT_SCROLLBAR = 22
UI.POPOUT_INNER = UI.POPOUT_WIDTH - (UI.POPOUT_INSET * 2) - UI.POPOUT_SCROLLBAR
local PAPERDOLL_WIDTH = UI.PAPERDOLL_WIDTH
local PAPERDOLL_HEIGHT = UI.PAPERDOLL_HEIGHT
local SLOT_LEFT_X = 21
local SLOT_TOP_Y = -76
local SLOT_RIGHT_X = -21
local SLOT_STEP = 37 + 4

-- CS-owned slot buttons. Names match GearSlots wire slots; globals are
-- CrusaderStrike* so Character*Slot is never touched.
UI.SLOT_BUTTONS = {
  { global = "CrusaderStrikeHeadSlot", slot = "head" },
  { global = "CrusaderStrikeNeckSlot", slot = "neck" },
  { global = "CrusaderStrikeShoulderSlot", slot = "shoulder" },
  { global = "CrusaderStrikeShirtSlot", slot = "shirt" },
  { global = "CrusaderStrikeChestSlot", slot = "chest" },
  { global = "CrusaderStrikeWaistSlot", slot = "waist" },
  { global = "CrusaderStrikeLegsSlot", slot = "legs" },
  { global = "CrusaderStrikeFeetSlot", slot = "feet" },
  { global = "CrusaderStrikeWristSlot", slot = "wrist" },
  { global = "CrusaderStrikeHandsSlot", slot = "hands" },
  { global = "CrusaderStrikeFinger0Slot", slot = "finger1" },
  { global = "CrusaderStrikeFinger1Slot", slot = "finger2" },
  { global = "CrusaderStrikeTrinket0Slot", slot = "trinket1" },
  { global = "CrusaderStrikeTrinket1Slot", slot = "trinket2" },
  { global = "CrusaderStrikeBackSlot", slot = "back" },
  { global = "CrusaderStrikeMainHandSlot", slot = "main_hand" },
  { global = "CrusaderStrikeSecondaryHandSlot", slot = "off_hand" },
  { global = "CrusaderStrikeRangedSlot", slot = "ranged" },
  { global = "CrusaderStrikeAmmoSlot", slot = "ammo" },
  { global = "CrusaderStrikeTabardSlot", slot = "tabard" },
}

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

local SLOT_SIZE = 37
local ICON_SIZE = 42
local RESULT_ICON = 36
local RESULT_GAP = 4
local RESULT_STRIDE = RESULT_ICON + RESULT_GAP
-- Fill the pop-out's inner width. A fixed 3-column grid left a gap and
-- looked detached from the pane.
local RESULT_COLS = math.max(1, math.floor((UI.POPOUT_INNER + RESULT_GAP) / RESULT_STRIDE))
UI.RESULT_COLS = RESULT_COLS
local DUNGEON_LIST_ROWS = 40
local SET_LIST_ROWS = 24
local GEAR_SETS_ICON = "Interface\\Icons\\INV_Misc_Gear_01"
local BROWSER_ICON = "Interface\\Icons\\INV_Misc_Bag_08"
local STATS_ICON = "Interface\\Icons\\INV_Misc_Note_01"
local CS_LOGO = "Interface\\AddOns\\CrusaderStrike\\assets\\logo.tga"
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local EMPTY_SLOT = {
  head = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head",
  neck = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck",
  shoulder = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder",
  shirt = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shirt",
  chest = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",
  waist = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist",
  legs = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs",
  feet = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet",
  wrist = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists",
  hands = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands",
  finger1 = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger",
  finger2 = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger",
  trinket1 = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",
  trinket2 = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket",
  back = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest",
  main_hand = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand",
  off_hand = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand",
  ranged = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged",
  ammo = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ammo",
  relic = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Relic",
  tabard = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Tabard",
}

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
  ammo = "Ammo",
  tabard = "Tabard",
}

local state = {
  active = false,
  view = "sets",
  popout = true,
  activeSlot = nil,
  localId = nil,
  previewSlots = {},
  filled = 0,
  search = "",
  instanceId = nil,
  gearSlot = nil,
  pending = false,
}

local csToggle
local root
local popout
local dollFrame
local topSetsBtn
local topBrowserBtn
local topStatsBtn
local setsPanel
local browserPanel
local statsPanel
local nameBox
local saveBtn
local setsEmpty
local browserEmpty
local setsMore
local browserMore
local searchBox
local statusText
local statsHeader
local statsFooter
local dungeonListChild
local dungeonListRows = {}
local resultScroll
local resultChild
local statLines = {}
local setButtons = {}
local resultButtons = {}
local slotButtons = {} -- slot name -> button
local itemInfoWatcher

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
    frame:SetBackdropColor(0, 0, 0, 0.92)
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

-- Resolve a real item icon. Forever IDs often need a load request first.
local function resolve_item_icon(itemId)
  itemId = tonumber(itemId)
  if not itemId or itemId < 1 then
    return nil
  end
  if C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, itemId)
  end
  local tex
  if C_Item and C_Item.GetItemIconByID then
    local ok, icon = pcall(C_Item.GetItemIconByID, itemId)
    if ok and icon and icon ~= 0 and icon ~= "" then
      tex = icon
    end
  end
  if not tex and type(GetItemIcon) == "function" then
    local ok, icon = pcall(GetItemIcon, itemId)
    if ok and icon and icon ~= 0 and icon ~= "" then
      tex = icon
    end
  end
  if not tex and type(GetItemInfoInstant) == "function" then
    local ok, _, _, _, icon = pcall(GetItemInfoInstant, itemId)
    if ok and icon and icon ~= 0 and icon ~= "" then
      tex = icon
    end
  end
  return tex
end

local function set_button_icon(btn, texture, fallback)
  if not btn or not btn.icon or not btn.icon.SetTexture then
    return
  end
  local tex = texture or fallback or QUESTION
  btn.icon:SetTexture(tex)
  btn._iconTex = tex
  if btn.icon.Show then
    btn.icon:Show()
  end
end

local function paint_slot(slotName, itemId)
  local button = slotButtons[slotName]
  if not button then
    return
  end
  button._itemId = itemId
  if itemId then
    local tex = resolve_item_icon(itemId)
    set_button_icon(button, tex, QUESTION)
  else
    set_button_icon(button, EMPTY_SLOT[slotName], QUESTION)
  end
end

local function refresh_slot_icons()
  for _, info in ipairs(UI.SLOT_BUTTONS) do
    paint_slot(info.slot, state.previewSlots[info.slot])
  end
end

function refresh_stats()
  state.filled = filled_count(state.previewSlots)
  for i, label in ipairs(UI.STAT_LABELS) do
    set_text(statLines[i], label .. "  —")
  end
  local slotNote = state.activeSlot and ("Slot: " .. state.activeSlot .. ". ") or ""
  set_text(
    statsFooter,
    slotNote .. "Slots filled: " .. tostring(state.filled) .. ". Stat totals are not computed yet."
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
  local open = state.popout and true or false
  mark_icon(topSetsBtn, open and state.view == "sets")
  mark_icon(topBrowserBtn, open and state.view == "browser")
  mark_icon(topStatsBtn, open and state.view == "stats")
  if popout then
    if open then
      popout:Show()
    else
      popout:Hide()
    end
  end
  local function show_panel(panel, want)
    if not panel then
      return
    end
    if panel.SetShown then
      panel:SetShown(want)
    elseif want then
      panel:Show()
    else
      panel:Hide()
    end
  end
  -- Panels live inside the pop-out. Hiding them (not only the host) keeps
  -- sets/browser/stats from drawing on the doll when the pane is closed.
  show_panel(setsPanel, open and state.view == "sets")
  show_panel(browserPanel, open and state.view == "browser")
  show_panel(statsPanel, open and state.view == "stats")
end

local refresh_browser

local function show_view(view)
  if view == "browser" then
    state.view = "browser"
  elseif view == "stats" then
    state.view = "stats"
  else
    state.view = "sets"
  end
  state.popout = true
  refresh_top_tabs()
  if refresh_browser then
    refresh_browser()
  end
  if refresh_stats then
    refresh_stats()
  end
end

-- Sidebar toggle: switch pane, or close the pop-out when that pane is already open.
function UI.TogglePane(view)
  if view ~= "browser" and view ~= "stats" then
    view = "sets"
  end
  if state.popout and state.view == view then
    state.popout = false
    refresh_top_tabs()
    return
  end
  show_view(view)
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
  local shown = 0
  for i = 1, SET_LIST_ROWS do
    local btn = setButtons[i]
    local list = lists[i]
    if btn then
      if list then
        btn:Show()
        btn._localId = list.local_id
        local mark = (list.local_id == state.localId) and "• " or ""
        btn:SetText(mark .. (list.name or "gear set"))
        shown = shown + 1
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
      set_text(setsMore, "Showing " .. tostring(shown) .. " of " .. tostring(#lists) .. ". Scroll the list.")
    else
      setsMore:Hide()
    end
  end
end

local function browser_rows()
  if not CrusaderStrikeGearBrowser or not CrusaderStrikeGearBrowser.Filter then
    return {}
  end
  local rows = CrusaderStrikeGearBrowser.Filter({
    instanceId = state.instanceId,
    search = state.search,
    gearSlot = state.gearSlot,
    difficulty = CrusaderStrikeGearBrowser.FOREVER_NORMAL,
  }, game_version())
  if not UI.AcceptsWeapon then
    return rows
  end
  local classToken = UI.PlayerClassToken()
  local kept = {}
  for i = 1, #rows do
    local row = rows[i]
    if UI.AcceptsWeapon(row.itemId, state.gearSlot, classToken) then
      kept[#kept + 1] = row
    end
  end
  return kept
end

local function browser_empty_text()
  if state.gearSlot then
    local label = SLOT_LABEL[state.gearSlot] or state.gearSlot
    return "No " .. label .. " items in the Forever overlay."
  end
  return "No matching items. Forever overlay is a stub — see docs/character-gear-tab.md."
end

local function dungeon_choices()
  local choices = { { name = "All dungeons", instanceId = nil } }
  if CrusaderStrikeGearBrowser and CrusaderStrikeGearBrowser.ListDungeons then
    for _, dungeon in ipairs(CrusaderStrikeGearBrowser.ListDungeons(game_version())) do
      choices[#choices + 1] = {
        name = dungeon.name or tostring(dungeon.instanceId),
        instanceId = dungeon.instanceId,
      }
    end
  end
  return choices
end

local function mark_list_row(row, selected)
  if not row then
    return
  end
  row._selected = selected and true or false
  if row.label and row.label.SetTextColor then
    if selected then
      row.label:SetTextColor(1, 0.82, 0)
    else
      row.label:SetTextColor(1, 1, 1)
    end
  end
  if selected and row.LockHighlight then
    row:LockHighlight()
  elseif row.UnlockHighlight then
    row:UnlockHighlight()
  end
end

local function refresh_dungeon_list()
  if not dungeonListChild then
    return
  end
  local choices = dungeon_choices()
  local shown = 0
  for i, choice in ipairs(choices) do
    local row = dungeonListRows[i]
    if row then
      row:Show()
      row._instanceId = choice.instanceId
      row._isListRow = true
      if row.label and row.label.SetText then
        row.label:SetText(choice.name)
      elseif row.SetText then
        row:SetText(choice.name)
      end
      local selected = (choice.instanceId == nil and state.instanceId == nil)
        or (choice.instanceId ~= nil and choice.instanceId == state.instanceId)
      mark_list_row(row, selected)
      shown = shown + 1
    end
  end
  for i = shown + 1, #dungeonListRows do
    if dungeonListRows[i] then
      dungeonListRows[i]:Hide()
      dungeonListRows[i]._instanceId = nil
    end
  end
  if dungeonListChild.SetHeight then
    dungeonListChild:SetHeight(math.max(18 * shown, 18))
  end
end

local function ensure_result_button(i)
  local btn = resultButtons[i]
  if btn then
    return btn
  end
  if not resultChild then
    return nil
  end
  local col = (i - 1) % RESULT_COLS
  local row = math.floor((i - 1) / RESULT_COLS)
  btn = CreateFrame("Button", nil, resultChild)
  btn:SetSize(RESULT_ICON, RESULT_ICON)
  btn:SetPoint(
    "TOPLEFT",
    resultChild,
    "TOPLEFT",
    col * (RESULT_ICON + RESULT_GAP),
    -row * (RESULT_ICON + RESULT_GAP)
  )
  btn._isIcon = true
  if btn.RegisterForClicks then
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  end
  if btn.CreateTexture then
    local icon = btn:CreateTexture(nil, "ARTWORK")
    if icon.SetAllPoints then
      icon:SetAllPoints()
    end
    if icon.SetTexCoord then
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    btn.icon = icon
  end
  btn:Hide()
  btn:SetScript("OnClick", function(self, button)
    if not self._itemId then
      return
    end
    if button == "RightButton" then
      return
    end
    UI.EquipItem(self._itemId)
  end)
  btn:SetScript("OnEnter", function(self)
    if not self._itemId or not GameTooltip then
      return
    end
    if GameTooltip.SetOwner then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    end
    if GameTooltip.SetItemByID then
      GameTooltip:SetItemByID(self._itemId)
    elseif GameTooltip.SetText then
      GameTooltip:SetText(self._label or tostring(self._itemId))
    end
    if GameTooltip.Show then
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function()
    if GameTooltip and GameTooltip.Hide then
      GameTooltip:Hide()
    end
  end)
  resultButtons[i] = btn
  return btn
end

function refresh_browser()
  if not browserPanel then
    return
  end
  refresh_dungeon_list()
  local rows = browser_rows()
  local count = #rows
  for i = 1, count do
    local btn = ensure_result_button(i)
    local row = rows[i]
    if btn and row then
      btn:Show()
      btn._itemId = row.itemId
      btn._label = row.name or ("item " .. tostring(row.itemId))
      local tex = resolve_item_icon(row.itemId)
      set_button_icon(btn, tex, QUESTION)
    end
  end
  for i = count + 1, #resultButtons do
    local btn = resultButtons[i]
    if btn then
      btn:Hide()
      btn._itemId = nil
      btn._iconTex = nil
    end
  end
  if resultChild and resultChild.SetHeight then
    local rowsNeeded = math.max(1, math.ceil(math.max(count, 1) / RESULT_COLS))
    resultChild:SetHeight(rowsNeeded * (RESULT_ICON + RESULT_GAP))
  end
  if browserEmpty then
    set_text(browserEmpty, browser_empty_text())
    if count == 0 then
      browserEmpty:Show()
    else
      browserEmpty:Hide()
    end
  end
  if browserMore then
    if count > 0 then
      browserMore:Show()
      set_text(browserMore, tostring(count) .. " item(s). Scroll for more.")
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
    popout = state.popout and true or false,
    gearSlot = state.gearSlot,
    instanceId = state.instanceId,
    pending = state.pending,
  }
end

function UI.DeselectSlot()
  state.activeSlot = nil
end

-- Left-click a CS gear-set slot: select it and open the browser filter.
function UI.OnGearSlot(slotName, button)
  if not CrusaderStrikeGearSlots or not CrusaderStrikeGearSlots.IsValidName(slotName) then
    return
  end
  local btn = slotButtons[slotName]
  if btn and btn._csClassHidden then
    return
  end
  if button == "RightButton" then
    UI.UnequipSlot(slotName)
    return
  end
  state.activeSlot = slotName
  state.gearSlot = slotName
  state.view = "browser"
  state.popout = true
  refresh_all()
  local label = SLOT_LABEL[slotName] or slotName
  set_status("Select a " .. label .. " item from the browser (left-click to equip).")
end

-- Back-compat alias used by older tests / call sites.
function UI.OnPaperDollSlot(slotName)
  UI.OnGearSlot(slotName, "LeftButton")
end

-- Vanilla weapon subclasses (item class 2). Forever 1.60.1 follows Classic.
local SUB = {
  AXE1 = 0, AXE2 = 1, BOW = 2, GUN = 3, MACE1 = 4, MACE2 = 5,
  POLEARM = 6, SWORD1 = 7, SWORD2 = 8, STAFF = 10, FIST = 13,
  DAGGER = 15, THROWN = 16, SPEAR = 17, XBOW = 18, WAND = 19, FISH = 20,
}

local function weapon_set(list)
  local t = {}
  for i = 1, #list do
    t[list[i]] = true
  end
  return t
end

-- Melee (main hand) proficiency. Off-hand weapons are a subset, and only
-- Warrior / Rogue may dual wield on vanilla.
local MELEE = {
  WARRIOR = weapon_set({ SUB.AXE1, SUB.AXE2, SUB.MACE1, SUB.MACE2, SUB.POLEARM, SUB.SWORD1, SUB.SWORD2, SUB.STAFF, SUB.FIST, SUB.DAGGER, SUB.FISH }),
  PALADIN = weapon_set({ SUB.AXE1, SUB.AXE2, SUB.MACE1, SUB.MACE2, SUB.POLEARM, SUB.SWORD1, SUB.SWORD2, SUB.FISH }),
  HUNTER = weapon_set({ SUB.AXE1, SUB.AXE2, SUB.POLEARM, SUB.SWORD1, SUB.SWORD2, SUB.STAFF, SUB.FIST, SUB.DAGGER, SUB.FISH }),
  ROGUE = weapon_set({ SUB.MACE1, SUB.SWORD1, SUB.FIST, SUB.DAGGER, SUB.FISH }),
  PRIEST = weapon_set({ SUB.MACE1, SUB.STAFF, SUB.DAGGER, SUB.FISH }),
  SHAMAN = weapon_set({ SUB.AXE1, SUB.AXE2, SUB.MACE1, SUB.MACE2, SUB.STAFF, SUB.FIST, SUB.DAGGER, SUB.FISH }),
  MAGE = weapon_set({ SUB.SWORD1, SUB.STAFF, SUB.DAGGER, SUB.FISH }),
  WARLOCK = weapon_set({ SUB.SWORD1, SUB.STAFF, SUB.DAGGER, SUB.FISH }),
  DRUID = weapon_set({ SUB.MACE1, SUB.MACE2, SUB.POLEARM, SUB.STAFF, SUB.FIST, SUB.DAGGER, SUB.FISH }),
}

local RANGED = {
  WARRIOR = weapon_set({ SUB.BOW, SUB.GUN, SUB.THROWN, SUB.XBOW }),
  HUNTER = weapon_set({ SUB.BOW, SUB.GUN, SUB.THROWN, SUB.XBOW }),
  ROGUE = weapon_set({ SUB.BOW, SUB.GUN, SUB.THROWN, SUB.XBOW }),
  PRIEST = weapon_set({ SUB.WAND }),
  MAGE = weapon_set({ SUB.WAND }),
  WARLOCK = weapon_set({ SUB.WAND }),
}

-- Vanilla Forever 1.60.1: only warrior and rogue dual-wield. Hunters and
-- shamans do not (that comes later). One-hand INVTYPE_WEAPON stays out of
-- the off hand for those classes.
local DUAL_WIELD = { WARRIOR = true, ROGUE = true }
local MAINHAND_ONLY_LOC = { INVTYPE_WEAPONMAINHAND = true, INVTYPE_2HWEAPON = true }
local OFFHAND_ONLY_LOC = { INVTYPE_WEAPONOFFHAND = true, INVTYPE_SHIELD = true, INVTYPE_HOLDABLE = true }
local RANGED_ONLY_LOC = {
  INVTYPE_RANGED = true,
  INVTYPE_RANGEDRIGHT = true,
  INVTYPE_THROWN = true,
  INVTYPE_RELIC = true,
}
local TWOHAND_SUB = {
  [SUB.AXE2] = true, [SUB.MACE2] = true, [SUB.POLEARM] = true,
  [SUB.SWORD2] = true, [SUB.STAFF] = true, [SUB.SPEAR] = true,
}
local OFFHAND_SUB = {
  [SUB.AXE1] = true, [SUB.MACE1] = true, [SUB.SWORD1] = true,
  [SUB.FIST] = true, [SUB.DAGGER] = true,
}

-- Verified Forever/Classic weapons used when the client has not cached subclass.
local KNOWN_WEAPONS = {
  [14145] = { classID = 2, subClassID = SUB.SWORD1, equipLoc = "INVTYPE_WEAPON" }, -- Cursed Felblade
  [272999] = { classID = 2, subClassID = SUB.XBOW, equipLoc = "INVTYPE_RANGED" }, -- Barbaric Crossbow
}

local SUBTYPE_TO_SUB = {
  ["one-handed axes"] = SUB.AXE1,
  ["two-handed axes"] = SUB.AXE2,
  ["bows"] = SUB.BOW,
  ["bow"] = SUB.BOW,
  ["guns"] = SUB.GUN,
  ["gun"] = SUB.GUN,
  ["one-handed maces"] = SUB.MACE1,
  ["two-handed maces"] = SUB.MACE2,
  ["polearms"] = SUB.POLEARM,
  ["polearm"] = SUB.POLEARM,
  ["one-handed swords"] = SUB.SWORD1,
  ["two-handed swords"] = SUB.SWORD2,
  ["swords"] = SUB.SWORD1,
  ["sword"] = SUB.SWORD1,
  ["staves"] = SUB.STAFF,
  ["staff"] = SUB.STAFF,
  ["fist weapons"] = SUB.FIST,
  ["fist weapon"] = SUB.FIST,
  ["daggers"] = SUB.DAGGER,
  ["dagger"] = SUB.DAGGER,
  ["thrown"] = SUB.THROWN,
  ["crossbows"] = SUB.XBOW,
  ["crossbow"] = SUB.XBOW,
  ["wands"] = SUB.WAND,
  ["wand"] = SUB.WAND,
  ["fishing poles"] = SUB.FISH,
  ["fishing pole"] = SUB.FISH,
}

-- Armor item class 4. Subclasses are cloth/leather/mail/plate only.
-- Shields and relics are not gated here. There is no level check:
-- shaman and hunter may wear mail at level 1, and plate has no 40 gate.
local ARMOR_SUB = { CLOTH = 1, LEATHER = 2, MAIL = 3, PLATE = 4 }
local ARMOR_NAME = {
  cloth = ARMOR_SUB.CLOTH,
  leather = ARMOR_SUB.LEATHER,
  mail = ARMOR_SUB.MAIL,
  plate = ARMOR_SUB.PLATE,
}
local ARMOR_ALLOWED = {
  MAGE = { [ARMOR_SUB.CLOTH] = true },
  PRIEST = { [ARMOR_SUB.CLOTH] = true },
  WARLOCK = { [ARMOR_SUB.CLOTH] = true },
  DRUID = { [ARMOR_SUB.CLOTH] = true, [ARMOR_SUB.LEATHER] = true },
  ROGUE = { [ARMOR_SUB.CLOTH] = true, [ARMOR_SUB.LEATHER] = true },
  SHAMAN = { [ARMOR_SUB.CLOTH] = true, [ARMOR_SUB.LEATHER] = true, [ARMOR_SUB.MAIL] = true },
  HUNTER = { [ARMOR_SUB.CLOTH] = true, [ARMOR_SUB.LEATHER] = true, [ARMOR_SUB.MAIL] = true },
  PALADIN = { [ARMOR_SUB.CLOTH] = true, [ARMOR_SUB.LEATHER] = true, [ARMOR_SUB.MAIL] = true, [ARMOR_SUB.PLATE] = true },
  WARRIOR = { [ARMOR_SUB.CLOTH] = true, [ARMOR_SUB.LEATHER] = true, [ARMOR_SUB.MAIL] = true, [ARMOR_SUB.PLATE] = true },
}

local WEAPON_LOCS = {
  INVTYPE_WEAPON = true,
  INVTYPE_2HWEAPON = true,
  INVTYPE_WEAPONMAINHAND = true,
  INVTYPE_WEAPONOFFHAND = true,
  INVTYPE_RANGED = true,
  INVTYPE_RANGEDRIGHT = true,
  INVTYPE_THROWN = true,
}

function UI.PlayerClassToken()
  if type(UnitClass) ~= "function" then
    return nil
  end
  local ok, _, token = pcall(UnitClass, "player")
  if not ok or type(token) ~= "string" or token == "" then
    return nil
  end
  return token:upper()
end

local function apply_subtype_name(rec)
  if rec.subClassID or type(rec.subType) ~= "string" then
    return
  end
  local key = rec.subType:lower()
  local sub = SUBTYPE_TO_SUB[key]
  if key == "sword" or key == "swords" then
    if rec.equipLoc == "INVTYPE_2HWEAPON" then
      sub = SUB.SWORD2
    else
      sub = SUB.SWORD1
    end
  elseif key == "axe" or key == "axes" then
    sub = (rec.equipLoc == "INVTYPE_2HWEAPON") and SUB.AXE2 or SUB.AXE1
  elseif key == "mace" or key == "maces" then
    sub = (rec.equipLoc == "INVTYPE_2HWEAPON") and SUB.MACE2 or SUB.MACE1
  end
  rec.subClassID = sub
end

local function weapon_record(itemId)
  itemId = tonumber(itemId)
  if not itemId then
    return nil
  end
  local rec = {}
  local known = KNOWN_WEAPONS[itemId]
  if known then
    rec.classID = known.classID
    rec.subClassID = known.subClassID
    rec.equipLoc = known.equipLoc
  end
  if type(GetItemInfoInstant) == "function" then
    local ok, _, itemType, itemSubType, equipLoc, _, classID, subClassID = pcall(GetItemInfoInstant, itemId)
    if ok then
      if type(classID) == "number" then
        rec.classID = classID
      end
      if type(subClassID) == "number" then
        rec.subClassID = subClassID
      end
      if type(equipLoc) == "string" and equipLoc ~= "" then
        rec.equipLoc = equipLoc:upper()
      end
      if type(itemSubType) == "string" and itemSubType ~= "" then
        rec.subType = itemSubType
      end
      if type(itemType) == "string" then
        local kind = itemType:lower()
        if kind == "weapon" then
          rec.classID = 2
        elseif kind == "armor" then
          rec.classID = 4
        end
      end
    end
  end
  if type(GetItemInfo) == "function" and not rec.subClassID then
    local ok, _, _, _, _, _, classStr, subStr, _, equipLoc = pcall(GetItemInfo, itemId)
    if ok then
      if type(classStr) == "string" then
        local kind = classStr:lower()
        if kind == "weapon" then
          rec.classID = 2
        elseif kind == "armor" then
          rec.classID = 4
        end
      end
      if type(subStr) == "string" and subStr ~= "" then
        rec.subType = rec.subType or subStr
      end
      if type(equipLoc) == "string" and equipLoc ~= "" and not rec.equipLoc then
        rec.equipLoc = equipLoc:upper()
      end
    end
  end
  if rec.equipLoc == "INVTYPE_2HWEAPON" and rec.subClassID == SUB.SWORD1 then
    rec.subClassID = SUB.SWORD2
  end
  apply_subtype_name(rec)
  if rec.classID ~= 2 and rec.equipLoc and WEAPON_LOCS[rec.equipLoc] then
    rec.classID = 2
  end
  if rec.classID ~= 2 or rec.subClassID == nil then
    return nil
  end
  return rec
end

local function armor_record(itemId)
  itemId = tonumber(itemId)
  if not itemId or type(GetItemInfoInstant) ~= "function" then
    -- Fall through to the shared instant/GetItemInfo read below when present.
  end
  local rec = {}
  if type(GetItemInfoInstant) == "function" then
    local ok, _, itemType, itemSubType, _, _, classID, subClassID = pcall(GetItemInfoInstant, itemId)
    if ok then
      if type(classID) == "number" then
        rec.classID = classID
      end
      if type(subClassID) == "number" then
        rec.subClassID = subClassID
      end
      if type(itemSubType) == "string" then
        rec.subType = itemSubType
      end
      if type(itemType) == "string" and itemType:lower() == "armor" then
        rec.classID = 4
      end
    end
  end
  if type(GetItemInfo) == "function" and rec.classID ~= 4 then
    local ok, _, _, _, _, _, classStr, subStr = pcall(GetItemInfo, itemId)
    if ok and type(classStr) == "string" and classStr:lower() == "armor" then
      rec.classID = 4
      if type(subStr) == "string" then
        rec.subType = rec.subType or subStr
      end
    end
  end
  if rec.subClassID == nil and type(rec.subType) == "string" then
    local key = rec.subType:lower()
    rec.subClassID = ARMOR_NAME[key]
    if not rec.subClassID then
      if key:find("plate", 1, true) then
        rec.subClassID = ARMOR_SUB.PLATE
      elseif key:find("mail", 1, true) then
        rec.subClassID = ARMOR_SUB.MAIL
      elseif key:find("leather", 1, true) then
        rec.subClassID = ARMOR_SUB.LEATHER
      elseif key:find("cloth", 1, true) then
        rec.subClassID = ARMOR_SUB.CLOTH
      end
    end
  end
  if rec.subClassID and rec.classID ~= 4 and rec.classID ~= 2 then
    rec.classID = 4
  end
  if rec.classID ~= 4 then
    return nil
  end
  if rec.subClassID ~= ARMOR_SUB.CLOTH and rec.subClassID ~= ARMOR_SUB.LEATHER
      and rec.subClassID ~= ARMOR_SUB.MAIL and rec.subClassID ~= ARMOR_SUB.PLATE then
    return nil
  end
  return rec
end

local ARMOR_SLOTS = {
  head = true,
  shoulder = true,
  chest = true,
  waist = true,
  legs = true,
  feet = true,
  wrist = true,
  hands = true,
}

local function class_can_wear(classToken, subClassID)
  local set = classToken and ARMOR_ALLOWED[classToken]
  if not set then
    return true
  end
  return set[subClassID] == true
end

local function item_equip_loc(itemId)
  itemId = tonumber(itemId)
  if not itemId then
    return nil
  end
  local known = KNOWN_WEAPONS[itemId]
  if known and type(known.equipLoc) == "string" and known.equipLoc ~= "" then
    return known.equipLoc
  end
  if type(GetItemInfoInstant) == "function" then
    local ok, _, _, _, equipLoc = pcall(GetItemInfoInstant, itemId)
    if ok and type(equipLoc) == "string" and equipLoc ~= "" then
      return equipLoc:upper()
    end
  end
  if type(GetItemInfo) == "function" then
    local ok, _, _, _, _, _, _, _, _, equipLoc = pcall(GetItemInfo, itemId)
    if ok and type(equipLoc) == "string" and equipLoc ~= "" then
      return equipLoc:upper()
    end
  end
  return nil
end

-- Where an equip location is allowed to land. Unknown locations are not blocked.
local function loc_fits_slot(equipLoc, slot, classToken)
  if classToken == "DRUID" and slot == "off_hand" then
    -- Druids do not dual-wield. Off hand is holdable items only:
    -- no shields, no INVTYPE_WEAPONOFFHAND, no generic one-handers.
    if equipLoc == "INVTYPE_HOLDABLE" then
      return true
    end
    return false, "wrong_slot"
  end
  if MAINHAND_ONLY_LOC[equipLoc] then
    if slot == "main_hand" then
      return true
    end
    return false, "wrong_slot"
  end
  if OFFHAND_ONLY_LOC[equipLoc] then
    if slot == "off_hand" then
      return true
    end
    return false, "wrong_slot"
  end
  if RANGED_ONLY_LOC[equipLoc] then
    if slot == "ranged" then
      return true
    end
    return false, "wrong_slot"
  end
  if equipLoc == "INVTYPE_WEAPON" then
    if slot == "main_hand" then
      return true
    end
    if slot == "off_hand" then
      if DUAL_WIELD[classToken] then
        return true
      end
      return false, "dual_mainhand"
    end
    return false, "wrong_slot"
  end
  return true
end

local RELIC_SUB = { DRUID = 8, SHAMAN = 9, PALADIN = 7 } -- idol, totem, libram
local WAND_CLASS = { PRIEST = true, MAGE = true, WARLOCK = true }
local AMMO_CLASS = { HUNTER = true, WARRIOR = true, ROGUE = true }

local function relic_sub(itemId)
  if type(GetItemInfoInstant) ~= "function" then
    return nil
  end
  local ok, _, _, _, _, _, _, subClassID = pcall(GetItemInfoInstant, itemId)
  if ok and (subClassID == 7 or subClassID == 8 or subClassID == 9) then
    return subClassID
  end
  return nil
end

local function ranged_slot_ok(classToken, itemId, equipLoc)
  if RELIC_SUB[classToken] then
    return equipLoc == "INVTYPE_RELIC" and relic_sub(itemId) == RELIC_SUB[classToken]
  end
  if WAND_CLASS[classToken] then
    local rec = weapon_record(itemId)
    return rec ~= nil and rec.subClassID == SUB.WAND
  end
  if AMMO_CLASS[classToken] then
    if equipLoc == "INVTYPE_RELIC" or equipLoc == "INVTYPE_AMMO" then
      return false
    end
    local rec = weapon_record(itemId)
    local set = RANGED[classToken]
    return rec ~= nil and set ~= nil and set[rec.subClassID] == true
  end
  return false
end

local function is_two_hand(rec)
  if not rec then
    return false
  end
  if rec.equipLoc == "INVTYPE_2HWEAPON" then
    return true
  end
  return TWOHAND_SUB[rec.subClassID] == true
end

local function is_mainhand_only(rec)
  return rec and rec.equipLoc == "INVTYPE_WEAPONMAINHAND"
end

local function class_slot_ok(classToken, slot, rec)
  if slot == "ranged" then
    local set = RANGED[classToken]
    if set and set[rec.subClassID] then
      return true
    end
    return false, "class_weapon"
  end
  local set = MELEE[classToken]
  if not set or not set[rec.subClassID] then
    return false, "class_weapon"
  end
  if slot == "off_hand" then
    if is_two_hand(rec) or is_mainhand_only(rec) or not OFFHAND_SUB[rec.subClassID] then
      if is_two_hand(rec) or is_mainhand_only(rec) then
        return false, "dual_mainhand"
      end
      return false, "class_weapon"
    end
    if not DUAL_WIELD[classToken] then
      return false, "dual_mainhand"
    end
  end
  return true
end

-- slot is main_hand / off_hand / ranged. Non-weapons and non-weapon slots pass.
-- reason is "class_weapon" or "dual_mainhand".
function UI.CheckEquip(itemId, slot, previewSlots, classToken)
  classToken = classToken or UI.PlayerClassToken()
  local armor = armor_record(itemId)
  if armor and ARMOR_SLOTS[slot] and not class_can_wear(classToken, armor.subClassID) then
    return false, "class_armor"
  end
  if slot == "ammo" then
    if not AMMO_CLASS[classToken] then
      return false, "wrong_slot"
    end
    if item_equip_loc(itemId) ~= "INVTYPE_AMMO" then
      return false, "wrong_slot"
    end
    return true
  end
  if slot == "main_hand" or slot == "off_hand" or slot == "ranged" then
    local equipLoc = item_equip_loc(itemId)
    if equipLoc then
      local locOk, locReason = loc_fits_slot(equipLoc, slot, classToken)
      if not locOk then
        return false, locReason
      end
    end
    if slot == "ranged" and not ranged_slot_ok(classToken, itemId, item_equip_loc(itemId)) then
      return false, "class_weapon"
    end
  end
  if slot ~= "main_hand" and slot ~= "off_hand" and slot ~= "ranged" then
    return true
  end
  local rec = weapon_record(itemId)
  if not rec then
    return true
  end
  previewSlots = type(previewSlots) == "table" and previewSlots or {}
  if classToken and MELEE[classToken] then
    local ok, reason = class_slot_ok(classToken, slot, rec)
    if not ok then
      return false, reason
    end
  end
  if slot == "off_hand" then
    if is_two_hand(rec) or is_mainhand_only(rec) then
      return false, "dual_mainhand"
    end
    local mainRec = weapon_record(previewSlots.main_hand)
    if mainRec and (is_two_hand(mainRec) or is_mainhand_only(mainRec)) then
      return false, "dual_mainhand"
    end
    if classToken and MELEE[classToken] and not DUAL_WIELD[classToken] then
      return false, "dual_mainhand"
    end
  elseif slot == "main_hand" then
    local offRec = weapon_record(previewSlots.off_hand)
    if offRec and (is_two_hand(rec) or is_mainhand_only(rec) or is_mainhand_only(offRec) or is_two_hand(offRec)) then
      return false, "dual_mainhand"
    end
    if classToken and MELEE[classToken] and not DUAL_WIELD[classToken] and offRec then
      return false, "dual_mainhand"
    end
  end
  return true
end

function UI.AcceptsWeapon(itemId, gearSlot, classToken)
  classToken = classToken or UI.PlayerClassToken()
  local armor = armor_record(itemId)
  if armor then
    if gearSlot == "main_hand" or gearSlot == "off_hand" or gearSlot == "ranged" or gearSlot == "ammo" then
      return UI.CheckEquip(itemId, gearSlot, state.previewSlots, classToken) and true or false
    end
    if gearSlot == nil or gearSlot == "" or ARMOR_SLOTS[gearSlot] then
      return class_can_wear(classToken, armor.subClassID)
    end
    return true
  end
  if not weapon_record(itemId) then
    -- Shields and off-hand holdables are not cloth/leather/mail/plate, so they
    -- are not armor_record hits. Still apply the slot rules.
    if gearSlot == "main_hand" or gearSlot == "off_hand" or gearSlot == "ranged" or gearSlot == "ammo" then
      return UI.CheckEquip(itemId, gearSlot, state.previewSlots, classToken) and true or false
    end
    return true
  end
  classToken = classToken or UI.PlayerClassToken()
  if gearSlot == "main_hand" or gearSlot == "off_hand" or gearSlot == "ranged" then
    return UI.CheckEquip(itemId, gearSlot, state.previewSlots, classToken) and true or false
  end
  if not classToken or not MELEE[classToken] then
    return true
  end
  if UI.CheckEquip(itemId, "main_hand", {}, classToken) then
    return true
  end
  if UI.CheckEquip(itemId, "off_hand", {}, classToken) then
    return true
  end
  if UI.CheckEquip(itemId, "ranged", {}, classToken) then
    return true
  end
  return false
end

local function reject_status(reason, classToken)
  if reason == "wrong_slot" then
    return "That item does not go in that slot."
  end
  if reason == "dual_mainhand" then
    return "Cannot equip two main-hand weapons."
  end
  local label = "This class"
  if type(classToken) == "string" and classToken ~= "" then
    label = classToken:sub(1, 1) .. classToken:sub(2):lower()
  end
  if reason == "class_armor" then
    return label .. " cannot equip that armor."
  end
  return label .. " cannot equip that weapon."
end

local function persist_slot(slot, itemId)
  local db = char_db()
  if not state.localId or not db or not CrusaderStrikeGearSets or not CrusaderStrikeGearSets.SetSlot then
    return false
  end
  local list, err = CrusaderStrikeGearSets.SetSlot(db, state.localId, slot, itemId)
  return list ~= nil, err
end

-- Left-click browser item → equip into the current gear set (preview + SetSlot).
function UI.EquipItem(itemId)
  itemId = tonumber(itemId)
  if not itemId or itemId < 1 or itemId ~= math.floor(itemId) then
    return false, "bad_item"
  end
  local slot = state.activeSlot
  if not slot or not CrusaderStrikeGearSlots or not CrusaderStrikeGearSlots.IsValidName(slot) then
    slot = nil
    if CrusaderStrikeGearBrowser and CrusaderStrikeGearBrowser.GearSlotForItem then
      slot = CrusaderStrikeGearBrowser.GearSlotForItem(itemId, game_version(), state.previewSlots)
    end
  end
  if not slot then
    slot = "head"
  end
  local classToken = UI.PlayerClassToken()
  local allowed, reason = UI.CheckEquip(itemId, slot, state.previewSlots, classToken)
  if not allowed then
    set_status(reject_status(reason, classToken))
    return false, reason
  end
  state.activeSlot = slot
  state.previewSlots[slot] = itemId
  local persisted = persist_slot(slot, itemId)
  local name
  if CrusaderStrikeGearBrowser and CrusaderStrikeGearBrowser.ItemName then
    name = CrusaderStrikeGearBrowser.ItemName(itemId, nil, game_version())
  end
  local label = SLOT_LABEL[slot] or slot
  local extra = name and (" (" .. name .. ")") or ""
  if persisted then
    set_status("Equipped " .. label .. " = " .. tostring(itemId) .. extra)
  else
    set_status("Equipped " .. label .. " = " .. tostring(itemId) .. extra .. " (preview — select/create a gear set to keep)")
  end
  refresh_stats()
  refresh_gear_list()
  return true
end

-- Wishlist-era name kept as an alias of EquipItem.
function UI.AssignPreviewItem(itemId)
  return UI.EquipItem(itemId)
end

-- Right-click a filled CS gear-set slot → unequip / clear.
function UI.UnequipSlot(slotName)
  if not CrusaderStrikeGearSlots or not CrusaderStrikeGearSlots.IsValidName(slotName) then
    return false, "bad_slot"
  end
  if state.previewSlots[slotName] == nil then
    set_status((SLOT_LABEL[slotName] or slotName) .. " is already empty.")
    return false, "empty"
  end
  state.previewSlots[slotName] = nil
  persist_slot(slotName, nil)
  local label = SLOT_LABEL[slotName] or slotName
  set_status("Unequipped " .. label)
  if state.activeSlot == slotName then
    -- keep filter on the slot so the player can re-pick
  end
  refresh_stats()
  refresh_gear_list()
  return true
end

function UI.SavePreviewAsSet(name)
  local db = char_db()
  if not db or not CrusaderStrikeGearSets or not CrusaderStrikeGearSets.CreateSet then
    set_status("Gear sets unavailable.")
    return false, "unavailable"
  end
  if filled_count(state.previewSlots) == 0 then
    set_status("Add items before creating a gear set.")
    return false, "empty"
  end
  if (type(name) ~= "string" or name:match("^%s*$")) and nameBox and nameBox.GetText then
    name = nameBox:GetText()
  end
  if type(name) ~= "string" or name:match("^%s*$") then
    name = "Gear set"
  end
  name = (name:match("^%s*(.-)%s*$"))
  local lvl = (UnitLevel and UnitLevel("player")) or 1
  local defaults = CrusaderStrikeGearSets.CreateDefaults(lvl)
  local fields = {
    name = name,
    type = defaults.type,
    slots = state.previewSlots,
  }
  if defaults.type == "leveling" then
    fields.until_level = defaults.until_level
  end
  local list, err = CrusaderStrikeGearSets.CreateSet(db, fields, lvl)
  if not list and err == "validation" then
    list, err = CrusaderStrikeGearSets.CreateSet(db, {
      name = name .. " 2",
      type = fields.type,
      until_level = fields.until_level,
      slots = state.previewSlots,
    }, lvl)
  end
  if not list then
    set_status("Could not create gear set.")
    return false, err
  end
  state.localId = list.local_id
  set_status("Created gear set " .. (list.name or name))
  refresh_gear_list()
  return true, list
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
  set_status("Gear set " .. (list.name or "") .. " — left-click browser to equip, right-click slot to unequip")
  refresh_gear_list()
  refresh_stats()
  return true
end

function UI.SelectDungeon(instanceId)
  if instanceId == nil or instanceId == 0 or instanceId == "all" then
    state.instanceId = nil
  else
    state.instanceId = tonumber(instanceId)
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
      icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
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
  if btn.Show then
    btn:Show()
  end
  return btn
end

local function make_slot_button(parent, info, x, y)
  local btn = CreateFrame("Button", info.global, parent)
  btn:SetSize(SLOT_SIZE, SLOT_SIZE)
  btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  btn._csSlot = info.slot
  btn._csOwnedSlot = true
  if btn.RegisterForClicks then
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  end
  if btn.EnableMouse then
    btn:EnableMouse(true)
  end
  if btn.CreateTexture then
    local icon = btn:CreateTexture(nil, "ARTWORK")
    if icon.SetAllPoints then
      icon:SetAllPoints()
    end
    if icon.SetTexCoord then
      icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    btn.icon = icon
  end
  set_button_icon(btn, EMPTY_SLOT[info.slot], QUESTION)
  btn:SetScript("OnClick", function(self, button)
    UI.OnGearSlot(self._csSlot, button or "LeftButton")
  end)
  btn:SetScript("OnEnter", function(self)
    if not GameTooltip then
      return
    end
    if GameTooltip.SetOwner then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    end
    if self._itemId and GameTooltip.SetItemByID then
      GameTooltip:SetItemByID(self._itemId)
    else
      local label = self._csLabel or SLOT_LABEL[self._csSlot] or self._csSlot
      if GameTooltip.SetText then
        GameTooltip:SetText(label .. " (right-click to unequip)")
      end
    end
    if GameTooltip.Show then
      GameTooltip:Show()
    end
  end)
  btn:SetScript("OnLeave", function()
    if GameTooltip and GameTooltip.Hide then
      GameTooltip:Hide()
    end
  end)
  slotButtons[info.slot] = btn
  return btn
end

local function place_slot(info, point, relPoint, x, y)
  local btn = make_slot_button(dollFrame, info, 0, 0)
  if btn.ClearAllPoints then
    btn:ClearAllPoints()
  end
  btn:SetPoint(point, dollFrame, relPoint, x, y)
  btn._csAnchor = point
  return btn
end

local function ranged_presentation(classToken)
  classToken = classToken or UI.PlayerClassToken()
  if classToken == "DRUID" then
    return "Relic", EMPTY_SLOT.relic, false
  end
  if classToken == "SHAMAN" then
    return "Totem", EMPTY_SLOT.relic, false
  end
  if classToken == "PALADIN" then
    return "Libram", EMPTY_SLOT.relic, false
  end
  if classToken == "PRIEST" or classToken == "MAGE" or classToken == "WARLOCK" then
    return "Wand", EMPTY_SLOT.ranged, false
  end
  return "Ranged", EMPTY_SLOT.ranged, true
end

local function apply_class_slots()
  local label, empty, showAmmo = ranged_presentation(UI.PlayerClassToken())
  local rangedBtn = slotButtons.ranged
  if rangedBtn then
    rangedBtn._csLabel = label
    if not rangedBtn._itemId then
      set_button_icon(rangedBtn, empty, QUESTION)
    end
    if rangedBtn.Show then
      rangedBtn:Show()
    end
  end
  local ammoBtn = slotButtons.ammo
  if ammoBtn then
    ammoBtn._csLabel = "Ammo"
    if showAmmo then
      ammoBtn._csClassHidden = false
      if not ammoBtn._itemId then
        set_button_icon(ammoBtn, EMPTY_SLOT.ammo, QUESTION)
      end
      if ammoBtn.Show then
        ammoBtn:Show()
      end
    elseif ammoBtn.Hide then
      ammoBtn._csClassHidden = true
      ammoBtn:Hide()
    end
  end
end

local function build_doll(parent)
  dollFrame = CreateFrame("Frame", "CrusaderStrikeGearDoll", parent, "BackdropTemplate")
  -- PaperDoll-sized viewer. Not CharacterFrame and not stretched over the sheet.
  dollFrame._csPaperDoll = true
  dollFrame._csOwnedDoll = true
  if dollFrame.SetParent then
    dollFrame:SetParent(parent)
  end
  if dollFrame.ClearAllPoints then
    dollFrame:ClearAllPoints()
  end
  -- Center on the CS tab content frame. The sidebar is attached to the doll's
  -- right, so the pair is centered by shifting left half the sidebar width.
  -- The relative frame is the tab content parent, never UIParent.
  dollFrame:SetPoint("CENTER", parent, "CENTER", -math.floor(UI.SIDEBAR_WIDTH / 2), 0)
  dollFrame:SetSize(PAPERDOLL_WIDTH, PAPERDOLL_HEIGHT)
  if dollFrame.EnableMouse then
    dollFrame:EnableMouse(true)
  end
  if dollFrame.SetFrameLevel then
    dollFrame:SetFrameLevel(20)
  end
  apply_backdrop(dollFrame)

  local bySlot = {}
  for _, info in ipairs(UI.SLOT_BUTTONS) do
    bySlot[info.slot] = info
  end
  local leftCol = { "head", "neck", "shoulder", "back", "chest", "shirt", "tabard", "wrist" }
  local rightCol = { "hands", "waist", "legs", "feet", "finger1", "finger2", "trinket1", "trinket2" }
  for i, slot in ipairs(leftCol) do
    place_slot(bySlot[slot], "TOPLEFT", "TOPLEFT", SLOT_LEFT_X, SLOT_TOP_Y - ((i - 1) * SLOT_STEP))
  end
  for i, slot in ipairs(rightCol) do
    place_slot(bySlot[slot], "TOPRIGHT", "TOPRIGHT", SLOT_RIGHT_X, SLOT_TOP_Y - ((i - 1) * SLOT_STEP))
  end
  -- PaperDoll weapon row: main hand, off hand, ranged, then ammo beside ranged.
  local weapons = { "main_hand", "off_hand", "ranged" }
  for i, slot in ipairs(weapons) do
    local x = UI.WEAPON_ROW_X + ((i - 1) * (SLOT_SIZE + UI.WEAPON_ROW_GAP))
    place_slot(bySlot[slot], "BOTTOMLEFT", "BOTTOMLEFT", x, UI.WEAPON_ROW_Y)
  end
  local ammoX = UI.WEAPON_ROW_X + (3 * (SLOT_SIZE + UI.WEAPON_ROW_GAP))
  place_slot(bySlot.ammo, "BOTTOMLEFT", "BOTTOMLEFT", ammoX, UI.WEAPON_ROW_Y)
  apply_class_slots()

  statusText = add_text(dollFrame, "GameFontDisableSmall", "", 8, -8)
  if statusText.ClearAllPoints then
    statusText:ClearAllPoints()
  end
  if statusText.SetPoint then
    statusText:SetPoint("BOTTOM", dollFrame, "BOTTOM", 0, UI.WEAPON_ROW_Y + SLOT_SIZE + 6)
  end
  if statusText.SetWidth then
    statusText:SetWidth(140)
  end
  set_status("Left-click browser to equip. Right-click a slot to unequip.")
end

local function refresh_toggle_checked()
  if not csToggle then
    return
  end
  if csToggle.SetChecked then
    csToggle:SetChecked(state.active and true or false)
  end
end

local function ensure_toggle(cf)
  if csToggle or not cf then
    return
  end
  local modeTabs = cf.ModeTabs
  local tabs = modeTabs and modeTabs.Tabs
  local parent = modeTabs or cf

  -- Visual integration: Forever side-tab template parented to ModeTabs so the
  -- logo sits in the strip chrome. Do NOT append to ModeTabs.Tabs (that injection
  -- is what tainted Character open earlier).
  local ok, tab = pcall(
    CreateFrame,
    "CheckButton",
    "CrusaderStrikeGearTabToggle",
    parent,
    "CharacterFrameModeSideTabTemplate"
  )
  if not ok or not tab then
    ok, tab = pcall(
      CreateFrame,
      "Button",
      "CrusaderStrikeGearTabToggle",
      parent,
      "CharacterFrameModeSideTabTemplate"
    )
  end
  if not ok or not tab then
    tab = CreateFrame("Button", "CrusaderStrikeGearTabToggle", parent)
    if tab.SetSize then
      tab:SetSize(ICON_SIZE, ICON_SIZE)
    end
  end
  csToggle = tab
  csToggle._csOwnedToggle = true
  csToggle._csGearTab = true
  csToggle._csIcon = CS_LOGO
  csToggle.tooltipText = "Crusader Strike"

  -- Apply logo into the template icon slot when present.
  if csToggle.Icon and csToggle.Icon.SetTexture then
    csToggle.Icon:SetTexture(CS_LOGO)
  elseif csToggle.icon and csToggle.icon.SetTexture then
    csToggle.icon:SetTexture(CS_LOGO)
  elseif csToggle.CreateTexture then
    local icon = csToggle:CreateTexture(nil, "ARTWORK")
    if icon.SetAllPoints then
      icon:SetAllPoints()
    end
    if icon.SetTexture then
      icon:SetTexture(CS_LOGO)
    end
    csToggle.icon = icon
  end

  if csToggle.ClearAllPoints then
    csToggle:ClearAllPoints()
  end
  local last
  if type(tabs) == "table" then
    for _, t in ipairs(tabs) do
      last = t
    end
  end
  if csToggle.SetPoint then
    if last and (not last.IsShown or last:IsShown()) then
      -- Sit under the last Forever mode tab (bottom of the strip).
      csToggle:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -2)
    elseif modeTabs then
      csToggle:SetPoint("TOPLEFT", modeTabs, "BOTTOMLEFT", 0, -4)
    else
      csToggle:SetPoint("BOTTOMLEFT", cf, "BOTTOMLEFT", 8, 8)
    end
  end

  local function on_toggle()
    if state.active then
      UI.Leave()
    else
      UI.Enter()
    end
  end
  if csToggle.SetCustomOnMouseUpHandler then
    csToggle:SetCustomOnMouseUpHandler(function(_, button, upInside)
      if button == "LeftButton" and (upInside == nil or upInside) then
        on_toggle()
      end
    end)
  else
    csToggle:SetScript("OnClick", on_toggle)
  end
  bind_icon_tooltip(csToggle, "Crusader Strike")
  refresh_toggle_checked()
  if csToggle.Show then
    csToggle:Show()
  end
end

local function register_escape_close()
  if type(_G.UISpecialFrames) ~= "table" then
    _G.UISpecialFrames = {}
  end
  for _, name in ipairs(_G.UISpecialFrames) do
    if name == UI.FRAME_NAME then
      return
    end
  end
  _G.UISpecialFrames[#_G.UISpecialFrames + 1] = UI.FRAME_NAME
end

local function anchor_content_pane(frame, cf)
  if not frame or not cf then
    return
  end
  if frame.SetParent then
    frame:SetParent(cf)
  end
  if frame.ClearAllPoints then
    frame:ClearAllPoints()
  end
  local copied = false
  local paper = _G.PaperDollFrame
  if paper and paper.GetNumPoints and paper.GetPoint then
    local n = paper:GetNumPoints()
    if type(n) == "number" and n > 0 then
      for i = 1, n do
        frame:SetPoint(paper:GetPoint(i))
      end
      copied = true
    end
  end
  -- Same rectangle as the open content pane. Not SetAllPoints: that covers
  -- the side-tab strip when ModeTabs is drawn inside the sheet.
  if not copied and frame.SetPoint then
    frame:SetPoint("TOPLEFT", cf, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", 0, 0)
  end
  frame._csContentPane = true
end

local function clear_mode_tab_checks(cf)
  local tabs = cf and cf.ModeTabs and cf.ModeTabs.Tabs
  if type(tabs) ~= "table" then
    return
  end
  for _, tab in ipairs(tabs) do
    if tab and tab ~= csToggle and tab.SetChecked then
      tab:SetChecked(false)
    end
  end
end

local function hide_active_subframe(cf)
  local name = cf and cf.activeSubframe
  if type(name) ~= "string" or name == "" or name == UI.FRAME_NAME then
    return
  end
  state.previousSubframe = name
  local pane = _G[name]
  if pane and pane ~= root and pane.Hide then
    pane:Hide()
  end
end

local function show_previous_subframe()
  local name = state.previousSubframe or "PaperDollFrame"
  if type(name) ~= "string" or name == "" or name == UI.FRAME_NAME then
    name = "PaperDollFrame"
  end
  local pane = _G[name]
  if pane and pane ~= root and pane.Show then
    pane:Show()
  end
end

-- Forever switched tabs. Hide CS only. Do not Show the previous pane and
-- do not call ShowSubFrame; Forever already showed the pane it selected.
function UI.HideForOtherTab(frameName)
  if not state.active then
    return
  end
  if type(frameName) == "string" and frameName ~= "" and frameName ~= UI.FRAME_NAME then
    state.previousSubframe = frameName
  end
  state._suppressLeave = true
  state.active = false
  refresh_toggle_checked()
  if root and root.Hide and root.IsShown and root:IsShown() then
    root:Hide()
  end
  state._suppressLeave = false
end

local function observe_show_subframe(cf)
  if not cf or cf._csShowSubFrameObserved then
    return
  end
  if type(cf.ShowSubFrame) ~= "function" or type(hooksecurefunc) ~= "function" then
    return
  end
  hooksecurefunc(cf, "ShowSubFrame", function(_, frameName)
    if frameName == UI.FRAME_NAME then
      return
    end
    UI.HideForOtherTab(frameName)
  end)
  cf._csShowSubFrameObserved = true
end

local function ensure_ui()
  local cf = _G.CharacterFrame
  if not cf then
    return false
  end
  if root then
    anchor_content_pane(root, cf)
    return true
  end

  -- Content pane on the character sheet. Not a cover over the side tabs.
  root = CreateFrame("Frame", UI.FRAME_NAME, cf, "BackdropTemplate")
  root._csOwnedWindow = true
  root._csTitle = "Crusader Strike"
  root._csContentPane = true
  if root.EnableMouse then
    root:EnableMouse(true)
  end
  apply_backdrop(root)
  root:SetScript("OnHide", function()
    if state._suppressLeave or state._leaving then
      return
    end
    UI.Leave()
  end)
  register_escape_close()

  if root.CreateTexture then
    local titleIcon = root:CreateTexture(nil, "ARTWORK")
    if titleIcon.SetSize then
      titleIcon:SetSize(20, 20)
    end
    if titleIcon.SetPoint then
      titleIcon:SetPoint("TOPLEFT", root, "TOPLEFT", 12, -12)
    end
    if titleIcon.SetTexture then
      titleIcon:SetTexture(CS_LOGO)
    end
  end
  add_text(root, "GameFontNormalLarge", "Crusader Strike", 38, -14)

  build_doll(root)
  if dollFrame and dollFrame.Show then
    dollFrame:Show()
  end

  -- CharacterFrame InsetRight: 177 wide, full height of the PaperDoll pane.
  popout = CreateFrame("Frame", "CrusaderStrikeGearPopout", root, "BackdropTemplate")
  popout._csInFrameColumn = true
  popout._csSidebar = true
  popout:SetWidth(UI.SIDEBAR_WIDTH)
  popout:SetPoint("TOPLEFT", dollFrame, "TOPRIGHT", 0, 0)
  popout:SetPoint("BOTTOMLEFT", dollFrame, "BOTTOMRIGHT", 0, 0)
  if popout.SetClipsChildren then
    popout:SetClipsChildren(true)
  end
  if popout.EnableMouse then
    popout:EnableMouse(true)
  end
  if popout.SetFrameLevel then
    popout:SetFrameLevel(30)
  end

  -- Mode buttons exist only on the right pane, at its top, above the
  -- sets / browser / stats body. They are not placed over the slot grid.
  -- The row spans the pop-out so the content frame can hang off its bottom.
  local iconRow = CreateFrame("Frame", "CrusaderStrikeGearIconRow", popout)
  iconRow:SetHeight(UI.SIDEBAR_TAB_H)
  iconRow:SetPoint("TOPLEFT", popout, "TOPLEFT", 0, -UI.SIDEBAR_TAB_GAP)
  iconRow:SetPoint("TOPRIGHT", popout, "TOPRIGHT", 0, -UI.SIDEBAR_TAB_GAP)
  if iconRow.EnableMouse then
    iconRow:EnableMouse(true)
  end
  if iconRow.SetFrameLevel then
    iconRow:SetFrameLevel(40)
  end
  if iconRow.Show then
    iconRow:Show()
  end

  topSetsBtn = add_icon_button(iconRow, "CrusaderStrikeGearSetsIcon", GEAR_SETS_ICON, "Gear Sets")
  topSetsBtn:SetScript("OnClick", function()
    UI.TogglePane("sets")
  end)
  topBrowserBtn = add_icon_button(iconRow, "CrusaderStrikeGearBrowserIcon", BROWSER_ICON, "Browser")
  topBrowserBtn:SetScript("OnClick", function()
    UI.TogglePane("browser")
  end)
  topStatsBtn = add_icon_button(iconRow, "CrusaderStrikeGearStatsIcon", STATS_ICON, "Stats")
  topStatsBtn:SetScript("OnClick", function()
    UI.TogglePane("stats")
  end)

  -- Sidebar tab row sits in the pane, same slot as Stats / Titles / Equipment.
  local function size_sidebar_tab(btn)
    btn:SetSize(UI.SIDEBAR_TAB_W, UI.SIDEBAR_TAB_H)
    if btn.ClearAllPoints then
      btn:ClearAllPoints()
    end
  end
  size_sidebar_tab(topStatsBtn)
  size_sidebar_tab(topBrowserBtn)
  size_sidebar_tab(topSetsBtn)
  topStatsBtn:SetPoint("RIGHT", iconRow, "RIGHT", -6, 0)
  topBrowserBtn:SetPoint("RIGHT", topStatsBtn, "LEFT", -UI.SIDEBAR_TAB_GAP, 0)
  topSetsBtn:SetPoint("RIGHT", topBrowserBtn, "LEFT", -UI.SIDEBAR_TAB_GAP, 0)

  -- Gear Sets, Browser, and Stats are children of the pop-out. Their top edge
  -- follows the tab row; the other edges follow the pop-out. No screen coords.
  local function anchor_sidebar_panel(panel)
    if panel.SetParent then
      panel:SetParent(popout)
    end
    if panel.ClearAllPoints then
      panel:ClearAllPoints()
    end
    panel:SetPoint("TOPLEFT", iconRow, "BOTTOMLEFT", 0, -UI.SIDEBAR_TAB_GAP)
    panel:SetPoint("BOTTOMRIGHT", popout, "BOTTOMRIGHT", 0, 0)
    panel._csSidebarPanel = true
  end

  -- Pane 1: Gear Sets list
  setsPanel = CreateFrame("Frame", "CrusaderStrikeGearSetsPanel", popout, "BackdropTemplate")
  anchor_sidebar_panel(setsPanel)
  apply_backdrop(setsPanel)
  add_text(setsPanel, "GameFontNormal", "Gear Sets", 8, -8)
  setsEmpty = add_text(
    setsPanel,
    "GameFontHighlightSmall",
    "No saved gear sets yet. Equip items from the browser, then Create gear set — or pick one below.",
    8,
    -28
  )
  if setsEmpty.SetWidth then
    setsEmpty:SetWidth(UI.POPOUT_INNER)
  end

  local setsScroll = CreateFrame("ScrollFrame", "CrusaderStrikeGearSetsScroll", setsPanel, "UIPanelScrollFrameTemplate")
  setsScroll:SetPoint("TOPLEFT", setsPanel, "TOPLEFT", UI.POPOUT_INSET, -70)
  setsScroll:SetPoint("BOTTOMRIGHT", setsPanel, "BOTTOMRIGHT", -(UI.POPOUT_SCROLLBAR + 2), 40)
  local setsChild = CreateFrame("Frame", "CrusaderStrikeGearSetsListChild", setsScroll)
  setsChild:SetSize(UI.POPOUT_INNER, SET_LIST_ROWS * 24)
  if setsScroll.SetScrollChild then
    setsScroll:SetScrollChild(setsChild)
  end
  for i = 1, SET_LIST_ROWS do
    local btn = CreateFrame("Button", nil, setsChild, "UIPanelButtonTemplate")
    btn:SetSize(UI.POPOUT_INNER, 22)
    btn:SetPoint("TOPLEFT", setsChild, "TOPLEFT", 0, -((i - 1) * 24))
    btn:Hide()
    btn:SetScript("OnClick", function(self)
      local localId = self._localId
      if localId then
        UI.SelectSet(localId)
      end
    end)
    setButtons[i] = btn
  end
  setsMore = add_text(setsPanel, "GameFontDisableSmall", "", 8, -52)
  setsMore:Hide()

  nameBox = CreateFrame("EditBox", "CrusaderStrikeGearSetName", setsPanel, "InputBoxTemplate")
  nameBox:SetSize(110, 20)
  nameBox:SetPoint("BOTTOMLEFT", setsPanel, "BOTTOMLEFT", 12, 10)
  nameBox:SetAutoFocus(false)
  if nameBox.SetMaxLetters then
    nameBox:SetMaxLetters(64)
  end
  saveBtn = CreateFrame("Button", "CrusaderStrikeGearSaveSet", setsPanel, "UIPanelButtonTemplate")
  saveBtn:SetSize(110, 22)
  saveBtn:SetPoint("BOTTOMRIGHT", setsPanel, "BOTTOMRIGHT", -8, 8)
  saveBtn:SetText("Create gear set")
  saveBtn:SetScript("OnClick", function()
    UI.SavePreviewAsSet(nameBox and nameBox.GetText and nameBox:GetText() or nil)
  end)

  -- Pane 2: Gear Browser
  browserPanel = CreateFrame("Frame", "CrusaderStrikeGearBrowserPanel", popout, "BackdropTemplate")
  anchor_sidebar_panel(browserPanel)
  if browserPanel.EnableMouse then
    browserPanel:EnableMouse(true)
  end
  apply_backdrop(browserPanel)
  browserPanel:Hide()

  local dungeonTitle = add_text(browserPanel, "GameFontNormal", "Dungeons", 8, -8)

  -- Stretch with the pane (fixed 220px width overflowed the right host and looked crooked).
  local listFrame = CreateFrame("Frame", "CrusaderStrikeGearDungeonList", browserPanel, "BackdropTemplate")
  listFrame:SetPoint("TOPLEFT", browserPanel, "TOPLEFT", 8, -24)
  listFrame:SetPoint("TOPRIGHT", browserPanel, "TOPRIGHT", -8, -24)
  listFrame:SetHeight(96)
  apply_backdrop(listFrame)

  local listScroll = CreateFrame("ScrollFrame", "CrusaderStrikeGearDungeonScroll", listFrame, "UIPanelScrollFrameTemplate")
  listScroll:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 4, -4)
  listScroll:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -22, 4)
  dungeonListChild = CreateFrame("Frame", "CrusaderStrikeGearDungeonListChild", listScroll)
  dungeonListChild:SetSize(UI.POPOUT_INNER, 18 * DUNGEON_LIST_ROWS)
  if listScroll.SetScrollChild then
    listScroll:SetScrollChild(dungeonListChild)
  end
  for i = 1, DUNGEON_LIST_ROWS do
    local row = CreateFrame("Button", nil, dungeonListChild)
    row:SetSize(UI.POPOUT_INNER, 16)
    row:SetPoint("TOPLEFT", dungeonListChild, "TOPLEFT", 0, -((i - 1) * 18))
    row:Hide()
    row._isListRow = true
    local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    if label.SetPoint then
      label:SetPoint("LEFT", row, "LEFT", 2, 0)
    end
    if label.SetJustifyH then
      label:SetJustifyH("LEFT")
    end
    row.label = label
    if row.SetHighlightTexture then
      row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    end
    row:SetScript("OnClick", function(self)
      UI.SelectDungeon(self._instanceId)
    end)
    dungeonListRows[i] = row
  end

  -- Search matches the dungeon list width (the pop-out's content width).
  -- A second anchor with a different Y was stretching the box off the list.
  local searchLabel = add_text(browserPanel, "GameFontHighlightSmall", "Name or item ID", 8, -128)
  searchLabel:ClearAllPoints()
  searchLabel:SetPoint("TOPLEFT", listFrame, "BOTTOMLEFT", 0, -4)

  searchBox = CreateFrame("EditBox", "CrusaderStrikeGearSearch", browserPanel, "InputBoxTemplate")
  searchBox:SetHeight(20)
  searchBox:SetPoint("TOPLEFT", listFrame, "BOTTOMLEFT", 0, -22)
  searchBox:SetPoint("TOPRIGHT", listFrame, "BOTTOMRIGHT", 0, -22)
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
    -162
  )
  -- Status line is its own row so the count/empty text does not sit on the icons.
  local statusLine = CreateFrame("Frame", "CrusaderStrikeGearBrowserStatus", browserPanel)
  statusLine:SetHeight(16)
  statusLine:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", 0, -4)
  statusLine:SetPoint("TOPRIGHT", searchBox, "BOTTOMRIGHT", 0, -4)

  browserEmpty:ClearAllPoints()
  browserEmpty:SetPoint("LEFT", statusLine, "LEFT", 0, 0)
  browserEmpty:SetPoint("RIGHT", statusLine, "RIGHT", 0, 0)
  if browserEmpty.SetWidth then
    browserEmpty:SetWidth(UI.POPOUT_INNER)
  end

  browserMore = add_text(browserPanel, "GameFontDisableSmall", "", 8, -180)
  browserMore:ClearAllPoints()
  browserMore:SetPoint("LEFT", statusLine, "LEFT", 0, 0)
  browserMore:SetPoint("RIGHT", statusLine, "RIGHT", 0, 0)
  browserMore:Hide()

  -- Scrollable result grid — every matching item is reachable (no hard 8-cap).
  -- Bottom-right is the browser panel, so the grid tracks the pop-out.
  resultScroll = CreateFrame("ScrollFrame", "CrusaderStrikeGearResultScroll", browserPanel, "UIPanelScrollFrameTemplate")
  resultScroll:SetPoint("TOPLEFT", statusLine, "BOTTOMLEFT", 0, -4)
  resultScroll:SetPoint("BOTTOMRIGHT", browserPanel, "BOTTOMRIGHT", -(UI.POPOUT_SCROLLBAR + 2), 8)
  resultChild = CreateFrame("Frame", "CrusaderStrikeGearResultChild", resultScroll)
  local gridWidth = RESULT_COLS * RESULT_ICON + math.max(0, RESULT_COLS - 1) * RESULT_GAP
  resultChild:SetSize(gridWidth, RESULT_ICON + RESULT_GAP)
  if resultScroll.SetScrollChild then
    resultScroll:SetScrollChild(resultChild)
  end

  -- Pane 3: Stats
  statsPanel = CreateFrame("Frame", "CrusaderStrikeGearStatsPanel", popout, "BackdropTemplate")
  anchor_sidebar_panel(statsPanel)
  if statsPanel.EnableMouse then
    statsPanel:EnableMouse(true)
  end
  apply_backdrop(statsPanel)
  statsPanel:Hide()

  statsHeader = add_text(statsPanel, "GameFontNormal", "Gear set stats", 10, -10)
  local statsHint = add_text(statsPanel, "GameFontDisableSmall", "Totals update when gear-set slots are filled. Not live character stats.", 10, -28)
  if statsHint.SetWidth then
    statsHint:SetWidth(UI.POPOUT_INNER)
  end
  for i, label in ipairs(UI.STAT_LABELS) do
    statLines[i] = add_text(statsPanel, "GameFontHighlightSmall", label .. "  —", 10, -52 - ((i - 1) * 16))
  end
  statsFooter = add_text(
    statsPanel,
    "GameFontDisableSmall",
    "Slots filled: 0. Stat totals are not computed yet.",
    10,
    -52 - (#UI.STAT_LABELS * 16) - 8
  )
  if statsFooter.SetWidth then
    statsFooter:SetWidth(UI.POPOUT_INNER)
  end

  show_view("sets")
  anchor_content_pane(root, cf)
  return true
end

function UI.Leave()
  if state._leaving or state._suppressLeave then
    return
  end
  state._leaving = true
  state.active = false
  refresh_toggle_checked()
  if root and root.Hide and root.IsShown and root:IsShown() then
    state._suppressLeave = true
    root:Hide()
    state._suppressLeave = false
  end
  show_previous_subframe()
  state._leaving = false
end

function UI.Enter()
  local cf = _G.CharacterFrame
  if not cf or (cf.IsShown and not cf:IsShown()) then
    return
  end
  ensure_toggle(cf)
  observe_show_subframe(cf)
  if not ensure_ui() then
    return
  end
  hide_active_subframe(cf)
  apply_class_slots()
  if not state.previousSubframe then
    state.previousSubframe = "PaperDollFrame"
  end
  state.active = true
  clear_mode_tab_checks(cf)
  refresh_toggle_checked()
  if root then
    root:Show()
  end
  refresh_all()
end

function UI.Install()
  local cf = _G.CharacterFrame
  if cf then
    ensure_toggle(cf)
  end
  if not itemInfoWatcher then
    itemInfoWatcher = CreateFrame("Frame", "CrusaderStrikeGearItemInfoWatcher")
    itemInfoWatcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    itemInfoWatcher:SetScript("OnEvent", function(_, event, itemId)
      if event ~= "GET_ITEM_INFO_RECEIVED" then
        return
      end
      if not state.active then
        return
      end
      itemId = tonumber(itemId)
      if not itemId then
        return
      end
      -- Refresh icons once the client has the Forever item texture.
      refresh_slot_icons()
      if state.view == "browser" then
        refresh_browser()
      end
    end)
  end
  -- False when CharacterFrame is not loaded yet so the login retry can
  -- attach the side-tab launcher once the frame exists.
  return cf ~= nil
end

function UI.Show()
  -- Fill the already-open character tab. Never ShowUIPanel / CharacterFrame:Show
  -- / ShowSubFrame / SecureActionButton:Click.
  UI.Install()
  local cf = _G.CharacterFrame
  if not cf or (cf.IsShown and not cf:IsShown()) then
    if CS.Print then
      CS.Print("Open the character pane first, then /cs geartab")
    end
    return
  end
  UI.Enter()
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
