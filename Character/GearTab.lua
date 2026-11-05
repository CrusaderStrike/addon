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
  pending = false,
  dropOpen = false,
}

local hooked = {}
local hookedFrame
local secureOpen
local modeTab

local root
local topSetsBtn
local topBrowserBtn
local setsPanel
local browserPanel
local statsPanel
local dropFrame
local dungeonOptions = {}
local nameBox
local saveBtn
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

function refresh_stats()
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
  if statsPanel and statsPanel.SetShown then
    statsPanel:SetShown(state.view ~= "browser")
  elseif statsPanel then
    if state.view == "browser" then statsPanel:Hide() else statsPanel:Show() end
  end
  if state.view ~= "browser" and dropFrame and dropFrame.Hide then
    state.dropOpen = false
    dropFrame:Hide()
  end
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

local refresh_browser

local function show_view(view)
  state.view = view == "browser" and "browser" or "sets"
  refresh_top_tabs()
  if refresh_browser then
    refresh_browser()
  end
  if refresh_stats then
    refresh_stats()
  end
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
    return "All dungeons"
  end
  if CrusaderStrikeGearBrowser and CrusaderStrikeGearBrowser.ListDungeons then
    local list = CrusaderStrikeGearBrowser.ListDungeons(game_version())
    for _, dungeon in ipairs(list) do
      if dungeon.instanceId == state.instanceId then
        return dungeon.name or tostring(dungeon.instanceId)
      end
    end
  end
  return tostring(state.instanceId)
end

function refresh_browser()
  if not browserPanel then
    return
  end
  if dungeonBtn and dungeonBtn.SetText then
    dungeonBtn:SetText(dungeon_label())
  end
  local rows = browser_rows()
  local cap = #resultButtons
  if cap < 1 then
    cap = 16
  end
  local shown = math.min(#rows, cap)
  for i = 1, cap do
    local btn = resultButtons[i]
    local row = rows[i]
    if btn then
      if row then
        btn:Show()
        btn._itemId = row.itemId
        btn._label = row.name or ("item " .. tostring(row.itemId))
        local tex = "Interface\\Icons\\INV_Misc_QuestionMark"
        if type(GetItemIcon) == "function" then
          local ok, icon = pcall(GetItemIcon, row.itemId)
          if ok and icon then
            tex = icon
          end
        end
        if btn.icon and btn.icon.SetTexture then
          btn.icon:SetTexture(tex)
        end
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
    instanceId = state.instanceId,
    pending = state.pending,
  }
end

function UI.DeselectSlot()
  state.activeSlot = nil
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

-- Wishlist preview only. Never calls PickupInventoryItem / EquipItem / UseInventoryItem.
function UI.AssignPreviewItem(itemId)
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
  state.activeSlot = slot
  state.previewSlots[slot] = itemId
  local name
  if CrusaderStrikeGearBrowser and CrusaderStrikeGearBrowser.ItemName then
    name = CrusaderStrikeGearBrowser.ItemName(itemId, nil, game_version())
  end
  local label = SLOT_LABEL[slot] or slot
  local extra = name and (" (" .. name .. ")") or ""
  set_status("Preview " .. label .. " = " .. tostring(itemId) .. extra)
  refresh_stats()
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
    name = "Wishlist"
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
  set_status("Previewing set " .. (list.name or "") .. " (not equipped)")
  refresh_gear_list()
  refresh_stats()
  return true
end

-- While the CS tab is up, replace slot scripts so Blizzard equip/pickup never
-- runs. HookScript is not enough: it lets the original OnClick run first.
-- Restoring the saved scripts on leave does not call CharacterFrame refresh.
local HOOK_SCRIPTS = { "OnClick", "OnReceiveDrag", "OnDragStart" }

local function apply_hooks()
  for _, info in ipairs(UI.SLOT_BUTTONS) do
    local button = _G[info.global]
    if button and button.SetScript and button.GetScript then
      local rec = hooked[info.global]
      if not rec then
        rec = { saved = {}, replaced = false }
        hooked[info.global] = rec
        for _, script in ipairs(HOOK_SCRIPTS) do
          rec.saved[script] = button:GetScript(script)
        end
      end
      if not rec.replaced then
        local slotName = info.slot
        for _, scriptName in ipairs(HOOK_SCRIPTS) do
          local script = scriptName
          local function handler()
            if script == "OnClick" then
              UI.OnPaperDollSlot(slotName)
            end
          end
          pcall(button.SetScript, button, script, handler)
        end
        rec.replaced = true
      end
    end
  end
end

local function restore_hooks()
  for globalName, rec in pairs(hooked) do
    if rec.replaced then
      local button = _G[globalName]
      if button and button.SetScript then
        for _, script in ipairs(HOOK_SCRIPTS) do
          pcall(button.SetScript, button, script, rec.saved[script])
        end
      end
      rec.replaced = false
    end
  end
end

function UI.SelectDungeon(instanceId)
  if instanceId == nil or instanceId == 0 or instanceId == "all" then
    state.instanceId = nil
  else
    state.instanceId = tonumber(instanceId)
  end
  state.dropOpen = false
  if dropFrame and dropFrame.Hide then
    dropFrame:Hide()
  end
  refresh_browser()
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

local function refresh_dungeon_menu()
  if not dropFrame then
    return
  end
  local choices = dungeon_choices()
  local shown = 0
  for i, choice in ipairs(choices) do
    local btn = dungeonOptions[i]
    if btn then
      btn:Show()
      btn._instanceId = choice.instanceId
      btn:SetText(choice.name)
      shown = shown + 1
    end
  end
  for i = shown + 1, #dungeonOptions do
    if dungeonOptions[i] then
      dungeonOptions[i]:Hide()
      dungeonOptions[i]._instanceId = nil
    end
  end
  if dropFrame.SetShown then
    dropFrame:SetShown(state.dropOpen and true or false)
  elseif state.dropOpen then
    dropFrame:Show()
  else
    dropFrame:Hide()
  end
end

local function toggle_dungeon_menu()
  state.dropOpen = not state.dropOpen
  refresh_dungeon_menu()
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

  -- Browser owns the right pane (replaces the wishlist stats panel).
  browserPanel = CreateFrame("Frame", "CrusaderStrikeGearBrowserPanel", root, "BackdropTemplate")
  browserPanel:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -52)
  browserPanel:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -8, 8)
  if browserPanel.EnableMouse then
    browserPanel:EnableMouse(true)
  end
  if browserPanel.SetFrameLevel then
    browserPanel:SetFrameLevel(20)
  end
  apply_backdrop(browserPanel)
  browserPanel:Hide()

  dungeonBtn = CreateFrame("Button", "CrusaderStrikeGearDungeonButton", browserPanel, "UIPanelButtonTemplate")
  dungeonBtn:SetSize(200, 22)
  dungeonBtn:SetPoint("TOPLEFT", browserPanel, "TOPLEFT", 8, -8)
  dungeonBtn:SetText("All dungeons")
  dungeonBtn._isDropdown = true
  dungeonBtn:SetScript("OnClick", toggle_dungeon_menu)

  dropFrame = CreateFrame("Frame", "CrusaderStrikeGearDungeonDrop", browserPanel, "BackdropTemplate")
  dropFrame:SetPoint("TOPLEFT", dungeonBtn, "BOTTOMLEFT", 0, -2)
  dropFrame:SetSize(200, 180)
  if dropFrame.SetFrameLevel then
    dropFrame:SetFrameLevel(80)
  end
  apply_backdrop(dropFrame)
  dropFrame:Hide()
  local dropScroll = CreateFrame("ScrollFrame", "CrusaderStrikeGearDungeonScroll", dropFrame, "UIPanelScrollFrameTemplate")
  dropScroll:SetPoint("TOPLEFT", dropFrame, "TOPLEFT", 4, -4)
  dropScroll:SetPoint("BOTTOMRIGHT", dropFrame, "BOTTOMRIGHT", -22, 4)
  local dropChild = CreateFrame("Frame", nil, dropScroll)
  dropChild:SetSize(170, 18 * 40)
  if dropScroll.SetScrollChild then
    dropScroll:SetScrollChild(dropChild)
  end
  for i = 1, 40 do
    local opt = CreateFrame("Button", nil, dropChild, "UIPanelButtonTemplate")
    opt:SetSize(168, 16)
    opt:SetPoint("TOPLEFT", dropChild, "TOPLEFT", 0, -((i - 1) * 18))
    opt:Hide()
    opt:SetScript("OnClick", function(self)
      UI.SelectDungeon(self._instanceId)
    end)
    dungeonOptions[i] = opt
  end

  add_text(browserPanel, "GameFontHighlightSmall", "Name or item ID", 8, -36)
  searchBox = CreateFrame("EditBox", "CrusaderStrikeGearSearch", browserPanel, "InputBoxTemplate")
  searchBox:SetSize(90, 20)
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
    -58
  )
  if browserEmpty.SetWidth then
    browserEmpty:SetWidth(200)
  end
  browserMore = add_text(browserPanel, "GameFontDisableSmall", "", 8, -220)
  browserMore:Hide()

  for i = 1, 16 do
    local col = (i - 1) % 4
    local row = math.floor((i - 1) / 4)
    local btn = CreateFrame("Button", nil, browserPanel)
    btn:SetSize(36, 36)
    btn:SetPoint("TOPLEFT", browserPanel, "TOPLEFT", 8 + (col * 40), -78 - (row * 40))
    btn._isIcon = true
    if btn.CreateTexture then
      local icon = btn:CreateTexture(nil, "ARTWORK")
      if icon.SetAllPoints then
        icon:SetAllPoints()
      end
      btn.icon = icon
    end
    btn:Hide()
    btn:SetScript("OnClick", function(self)
      if self._itemId then
        UI.AssignPreviewItem(self._itemId)
      end
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
  end

  nameBox = CreateFrame("EditBox", "CrusaderStrikeGearSetName", browserPanel, "InputBoxTemplate")
  nameBox:SetSize(110, 20)
  nameBox:SetPoint("BOTTOMLEFT", browserPanel, "BOTTOMLEFT", 12, 10)
  nameBox:SetAutoFocus(false)
  if nameBox.SetMaxLetters then
    nameBox:SetMaxLetters(64)
  end
  saveBtn = CreateFrame("Button", "CrusaderStrikeGearSaveSet", browserPanel, "UIPanelButtonTemplate")
  saveBtn:SetSize(110, 22)
  saveBtn:SetPoint("BOTTOMRIGHT", browserPanel, "BOTTOMRIGHT", -8, 8)
  saveBtn:SetText("Create gear set")
  saveBtn:SetScript("OnClick", function()
    UI.SavePreviewAsSet(nameBox and nameBox.GetText and nameBox:GetText() or nil)
  end)

  statusText = add_text(center, "GameFontDisableSmall", "Select a paper doll slot, then pick an item. Wishlist preview only.", 8, -4)
  statusText:ClearAllPoints()
  statusText:SetPoint("BOTTOMLEFT", center, "BOTTOMLEFT", 8, 6)
  if statusText.SetWidth then
    statusText:SetWidth(220)
  end

  statsPanel = CreateFrame("Frame", nil, root, "BackdropTemplate")
  -- Below the 42px icon row (top of the right pane, y=-4).
  statsPanel:SetPoint("TOPLEFT", right, "TOPLEFT", 8, -52)
  statsPanel:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -8, 8)
  if statsPanel.EnableMouse then
    statsPanel:EnableMouse(true)
  end
  if statsPanel.SetFrameLevel then
    statsPanel:SetFrameLevel(10)
  end
  apply_backdrop(statsPanel)

  statsHeader = add_text(statsPanel, "GameFontNormal", "Wishlist preview", 10, -10)
  add_text(statsPanel, "GameFontDisableSmall", "Not equipped. Totals update when preview items are filled in.", 10, -28)
  for i, label in ipairs(UI.STAT_LABELS) do
    statLines[i] = add_text(statsPanel, "GameFontHighlightSmall", label .. "  —", 10, -52 - ((i - 1) * 16))
  end
  statsFooter = add_text(statsPanel, "GameFontDisableSmall", "Preview slots filled: 0. Stat totals are not computed yet.", 10, -52 - (#UI.STAT_LABELS * 16) - 8)
  if statsFooter.SetWidth then
    statsFooter:SetWidth(200)
  end

  show_view("sets")
end

local function mark_our_mode_tab(selected)
  if modeTab and modeTab.SetChecked then
    modeTab:SetChecked(selected and true or false)
  end
  if not selected then
    return
  end
  local cf = _G.CharacterFrame
  local tabs = cf and cf.ModeTabs and cf.ModeTabs.Tabs
  if type(tabs) ~= "table" then
    return
  end
  for _, tab in ipairs(tabs) do
    if tab ~= modeTab and tab.SetChecked then
      tab:SetChecked(false)
    end
  end
end

function UI.Leave()
  if not state.active then
    return
  end
  state.active = false
  state.pending = false
  restore_hooks()
  clear_preview_icons()
  mark_our_mode_tab(false)
  if root and root.IsShown and root:IsShown() then
    root:Hide()
  end
end

function UI.Enter()
  local cf = _G.CharacterFrame
  if not cf then
    return
  end
  -- Only CS-owned frames, slot-script swap, and preview icons.
  -- Do not Show/Hide Blizzard chrome or call CharacterFrame layout APIs.
  state.active = true
  state.pending = false
  ensure_ui()
  if root then
    root:Show()
  end
  apply_hooks()
  mark_our_mode_tab(true)
  refresh_all()
end

local function hook_show_subframe(cf)
  if not cf or cf == hookedFrame or type(hooksecurefunc) ~= "function" then
    return
  end
  if type(cf.ShowSubFrame) == "function" then
    hooksecurefunc(cf, "ShowSubFrame", function(_, frameName)
      if frameName == "PaperDollFrame" or frameName == UI.FRAME_NAME then
        if state.pending then
          UI.Enter()
        end
        return
      end
      UI.Leave()
    end)
  end
  if type(cf.OnShow) == "function" then
    hooksecurefunc(cf, "OnShow", function()
      if state.pending then
        UI.Enter()
      end
    end)
  end
  if type(cf.OnHide) == "function" then
    hooksecurefunc(cf, "OnHide", function()
      UI.Leave()
    end)
  end
  hookedFrame = cf
end

local function ensure_secure_open()
  if secureOpen then
    return secureOpen
  end
  local parent = _G.UIParent or _G.CharacterFrame
  local ok, btn = pcall(CreateFrame, "Button", "CrusaderStrikeOpenCharacterButton", parent, "SecureActionButtonTemplate")
  if not ok or not btn then
    return nil
  end
  secureOpen = btn
  if btn.SetAttribute then
    btn:SetAttribute("type", "click")
    if _G.CharacterMicroButton then
      btn:SetAttribute("clickbutton", _G.CharacterMicroButton)
    end
  end
  if btn.RegisterForClicks then
    btn:RegisterForClicks("AnyUp")
  end
  if btn.SetSize then
    btn:SetSize(1, 1)
  end
  if btn.EnableMouse then
    btn:EnableMouse(false)
  end
  if btn.Hide then
    btn:Hide()
  end
  return btn
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
  tab._csGearTab = true
  tab.tooltipText = "Crusader Strike"
  modeTab = tab
  if tab.SetCustomOnMouseUpHandler then
    tab:SetCustomOnMouseUpHandler(function(_, button, upInside)
      if button == "LeftButton" and (upInside == nil or upInside) then
        UI.Show()
      end
    end)
  else
    tab:SetScript("OnClick", function()
      UI.Show()
    end)
  end
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
  -- Never ShowUIPanel / CharacterFrame:Show / ShowSubFrame from here.
  -- Those refresh TextStatusBar while CrusaderStrike is still on the stack.
  if cf.IsShown and cf:IsShown() then
    UI.Enter()
    return
  end
  state.pending = true
  local btn = ensure_secure_open()
  local micro = _G.CharacterMicroButton
  if btn and btn.SetAttribute and micro then
    btn:SetAttribute("clickbutton", micro)
  end
  if btn and btn.Click then
    btn:Click()
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
