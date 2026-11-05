--[[
  In-game dungeon loot browser + per-dungeon wish lists.
  Open with /cs loot (or /cs wishlist). Pure frames (BackdropTemplate) —
  no CLEU, no protected combat calls. Loot auto-obtain uses CHAT_MSG_LOOT.
]]

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike
CS.LootBrowser = CS.LootBrowser or {}
local LB = CS.LootBrowser

local frame
local state = {
  mapId = nil,
  search = "",
  slot = "All",
  view = "loot", -- "loot" | "wish"
}

local QUALITY_COLORS = {
  [0] = { 0.62, 0.62, 0.62 },
  [1] = { 1.00, 1.00, 1.00 },
  [2] = { 0.12, 1.00, 0.00 },
  [3] = { 0.00, 0.44, 0.87 },
  [4] = { 0.64, 0.21, 0.93 },
  [5] = { 1.00, 0.50, 0.00 },
}

local SLOT_FILTERS = {
  "All", "Weapon", "Ranged", "Back", "Chest", "Wrist", "Feet",
  "Head", "Neck", "Shoulder", "Hands", "Waist", "Legs", "Finger", "Trinket", "Shield",
  "Held In Off-hand", "Other",
}

local content -- scroll child
local rows = {} -- recycled row frames
local dungeonButtons = {}
local statusText
local searchBox
local titleText
local wishToggle
local highlightBanner

local function char_db()
  return CS.GetCharDB and CS.GetCharDB() or CrusaderStrikeCharDB
end

local function current_instance_map()
  if not GetInstanceInfo then
    return nil
  end
  local name, instanceType, _, _, _, _, _, instanceMapID = GetInstanceInfo()
  if instanceType == "party" or instanceType == "raid" then
    return instanceMapID, name
  end
  return nil, name
end

local function parse_loot_item_id(msg)
  if type(msg) ~= "string" then
    return nil
  end
  -- |Hitem:itemId:enchant:...|h[Name]|h  (WoW item link)
  local id = msg:match("|Hitem:(%d+):")
  return id and tonumber(id) or nil
end

-- Self-loot gate. CHAT_MSG_LOOT also carries party/raid lines ("X receives
-- loot: ..."), so only the player's own loot/create/win lines may mark a
-- wish-list item obtained. Patterns are built from the client's localized
-- GlobalStrings; the enUS values are used only if a global is missing.
local SELF_LOOT_GLOBALS = {
  { "LOOT_ITEM_SELF", "You receive loot: %s." },
  { "LOOT_ITEM_SELF_MULTIPLE", "You receive loot: %sx%d." },
  { "LOOT_ITEM_PUSHED_SELF", "You receive item: %s." },
  { "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "You receive item: %sx%d." },
  { "LOOT_ITEM_CREATED_SELF", "You create: %s." },
  { "LOOT_ROLL_YOU_WON", "You won: %s" },
}

local function format_to_pattern(fmt)
  -- Escape Lua magic chars, then turn %s / %d (incl. positional %1$s) into captures.
  local pat = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
  pat = pat:gsub("%%%d?%$?s", "(.+)")
  pat = pat:gsub("%%%d?%$?d", "(%%d+)")
  return "^" .. pat .. "$"
end

local selfLootPatterns
local function self_loot_patterns()
  if not selfLootPatterns then
    selfLootPatterns = {}
    for _, g in ipairs(SELF_LOOT_GLOBALS) do
      local fmt = _G[g[1]]
      if type(fmt) ~= "string" or fmt == "" then
        fmt = g[2]
      end
      selfLootPatterns[#selfLootPatterns + 1] = format_to_pattern(fmt)
    end
  end
  return selfLootPatterns
end

local function strip_realm(name)
  if type(name) ~= "string" then
    return nil
  end
  return (name:gsub("%-.*$", ""))
end

local function is_self_loot(msg, playerName)
  if type(msg) ~= "string" then
    return false
  end
  -- When the client supplies the looter (arg 5), it must be us.
  if type(playerName) == "string" and playerName ~= "" and UnitName then
    local me = UnitName("player")
    if me and strip_realm(playerName) ~= strip_realm(me) then
      return false
    end
  end
  for _, pat in ipairs(self_loot_patterns()) do
    if msg:match(pat) then
      return true
    end
  end
  return false
end

local function quality_color(q)
  return QUALITY_COLORS[q or 1] or QUALITY_COLORS[1]
end

local function ensure_ui()
  if frame then
    return
  end

  frame = CreateFrame("Frame", "CrusaderStrikeLootFrame", UIParent, "BackdropTemplate")
  frame:SetSize(720, 460)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  if frame.SetBackdrop then
    frame:SetBackdrop({
      bgFile = "Interface/Tooltips/UI-Tooltip-Background",
      edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
      tile = true,
      tileSize = 16,
      edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.92)
  end

  titleText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  titleText:SetPoint("TOPLEFT", 12, -12)
  titleText:SetText("CrusaderStrike loot browser")

  highlightBanner = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  highlightBanner:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -2)
  highlightBanner:SetText("")

  local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  close:SetSize(80, 22)
  close:SetPoint("TOPRIGHT", -12, -10)
  close:SetText("Close")
  close:SetScript("OnClick", function()
    frame:Hide()
  end)

  wishToggle = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  wishToggle:SetSize(110, 22)
  wishToggle:SetPoint("RIGHT", close, "LEFT", -8, 0)
  wishToggle:SetText("Wish list")
  wishToggle:SetScript("OnClick", function()
    if state.view == "loot" then
      state.view = "wish"
      wishToggle:SetText("Loot table")
    else
      state.view = "loot"
      wishToggle:SetText("Wish list")
    end
    LB.Refresh()
  end)

  -- Left dungeon list
  local left = CreateFrame("Frame", nil, frame)
  left:SetPoint("TOPLEFT", 10, -48)
  left:SetSize(180, 360)

  local leftTitle = left:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  leftTitle:SetPoint("TOPLEFT", 0, 0)
  leftTitle:SetText("Dungeons")

  local leftScroll = CreateFrame("ScrollFrame", "CrusaderStrikeLootDungeonScroll", left, "UIPanelScrollFrameTemplate")
  leftScroll:SetPoint("TOPLEFT", 0, -18)
  leftScroll:SetPoint("BOTTOMRIGHT", -20, 0)
  local leftChild = CreateFrame("Frame", nil, leftScroll)
  leftChild:SetSize(150, 10)
  leftScroll:SetScrollChild(leftChild)
  frame._dungeonList = leftChild

  -- Search + slot filter
  local searchLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  searchLabel:SetPoint("TOPLEFT", 200, -48)
  searchLabel:SetText("Search")

  searchBox = CreateFrame("EditBox", "CrusaderStrikeLootSearch", frame, "InputBoxTemplate")
  searchBox:SetSize(180, 20)
  searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
  searchBox:SetAutoFocus(false)
  searchBox:SetScript("OnTextChanged", function(self)
    state.search = self:GetText() or ""
    LB.RefreshContent()
  end)
  searchBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)

  local slotLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  slotLabel:SetPoint("LEFT", searchBox, "RIGHT", 12, 0)
  slotLabel:SetText("Slot")

  -- Simple cycling slot filter button (avoids DropdownTemplate deps).
  local slotBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  slotBtn:SetSize(100, 22)
  slotBtn:SetPoint("LEFT", slotLabel, "RIGHT", 6, 0)
  slotBtn:SetText("All")
  slotBtn:SetScript("OnClick", function(self)
    local idx = 1
    for i, s in ipairs(SLOT_FILTERS) do
      if s == state.slot then
        idx = i
        break
      end
    end
    idx = idx % #SLOT_FILTERS + 1
    state.slot = SLOT_FILTERS[idx]
    self:SetText(state.slot)
    LB.RefreshContent()
  end)
  frame._slotBtn = slotBtn

  -- Main content scroll
  local scroll = CreateFrame("ScrollFrame", "CrusaderStrikeLootScroll", frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 200, -78)
  scroll:SetPoint("BOTTOMRIGHT", -30, 36)
  content = CreateFrame("Frame", nil, scroll)
  content:SetSize(470, 10)
  scroll:SetScrollChild(content)

  statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusText:SetPoint("BOTTOMLEFT", 12, 14)
  statusText:SetText("")

  frame:Hide()
  frame:SetScript("OnShow", function()
    LB.Refresh()
  end)
end

local function clear_rows()
  for _, r in ipairs(rows) do
    r:Hide()
  end
end

local function item_icon(itemId)
  if C_Item and C_Item.GetItemIconByID then
    return C_Item.GetItemIconByID(itemId)
  end
  if GetItemIcon then
    return GetItemIcon(itemId)
  end
  return nil
end

local function set_row_icon(r, itemId)
  local tex = itemId and item_icon(itemId)
  if tex then
    r.icon:SetTexture(tex)
    if r.icon.Show then r.icon:Show() end
  else
    r.icon:SetTexture(nil)
    if r.icon.Hide then r.icon:Hide() end
  end
end

local function get_row(i)
  local r = rows[i]
  if r then
    return r
  end
  r = CreateFrame("Button", nil, content)
  r:SetSize(450, 22)
  r:EnableMouse(true)

  r.icon = r:CreateTexture(nil, "ARTWORK")
  if r.icon.SetSize then
    r.icon:SetSize(18, 18)
  end
  if r.icon.SetPoint then
    r.icon:SetPoint("LEFT", 2, 0)
  end

  r.label = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.label:SetPoint("LEFT", 24, 0)
  r.label:SetWidth(280)
  r.label:SetJustifyH("LEFT")

  r.meta = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.meta:SetPoint("LEFT", 310, 0)
  r.meta:SetWidth(70)
  r.meta:SetJustifyH("LEFT")

  r.action = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
  r.action:SetSize(60, 18)
  r.action:SetPoint("RIGHT", -2, 0)

  r:SetScript("OnEnter", function(self)
    if self._itemId and GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      if GameTooltip.SetItemByID then
        GameTooltip:SetItemByID(self._itemId)
      else
        GameTooltip:SetText(self._itemName or ("item:" .. tostring(self._itemId)))
      end
      GameTooltip:Show()
    end
  end)
  r:SetScript("OnLeave", function()
    if GameTooltip then
      GameTooltip:Hide()
    end
  end)

  rows[i] = r
  return r
end

local function paint_dungeon_list()
  local parent = frame._dungeonList
  for _, b in ipairs(dungeonButtons) do
    b:Hide()
  end
  local list = CrusaderStrikeLoot.ListDungeons(CS.GetGameVersion and CS.GetGameVersion() or "forever")
  -- Also show Forever dungeons from Bosses that have no loot yet (greyed).
  local bosses = CrusaderStrikeBosses and CrusaderStrikeBosses.GetTable and CrusaderStrikeBosses.GetTable("forever")
  if bosses then
    local have = {}
    for _, d in ipairs(list) do
      have[d.instanceMapId] = true
    end
    for mapId, dungeon in pairs(bosses) do
      if not have[mapId] then
        list[#list + 1] = {
          instanceMapId = mapId,
          name = dungeon.name,
          verified = false,
          itemCount = 0,
        }
      end
    end
    table.sort(list, function(a, b)
      return (a.name or "") < (b.name or "")
    end)
  end

  local y = 0
  for i, d in ipairs(list) do
    local b = dungeonButtons[i]
    if not b then
      b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
      b:SetSize(150, 20)
      dungeonButtons[i] = b
    end
    b:SetPoint("TOPLEFT", 0, -y)
    local mark = (d.itemCount and d.itemCount > 0) and "" or " *"
    b:SetText((d.name or ("Map " .. tostring(d.instanceMapId))) .. mark)
    local mapId = d.instanceMapId
    b:SetScript("OnClick", function()
      state.mapId = mapId
      state.view = "loot"
      if wishToggle then
        wishToggle:SetText("Wish list")
      end
      LB.Refresh()
    end)
    b:Show()
    y = y + 22
  end
  parent:SetSize(150, math.max(y, 10))
end

local function paint_loot_view()
  clear_rows()
  local dungeon = CrusaderStrikeLoot.GetDungeon(CS.GetGameVersion and CS.GetGameVersion() or "forever", state.mapId)
  if not dungeon then
    statusText:SetText("No verified loot data for this dungeon yet. See docs/loot-data.md.")
    content:SetSize(470, 10)
    return
  end
  local bosses = CrusaderStrikeLoot.FilterDungeon(dungeon, { search = state.search, slot = state.slot })
  local db = char_db()
  local y = 0
  local rowIdx = 0

  for _, boss in ipairs(bosses) do
    rowIdx = rowIdx + 1
    local header = get_row(rowIdx)
    header:SetPoint("TOPLEFT", 0, -y)
    header._itemId = nil
    header._itemName = nil
    header.label:SetText(boss.name or ("NPC " .. tostring(boss.npcId)))
    set_row_icon(header, nil)
    if header.label.SetTextColor then
      header.label:SetTextColor(1, 0.82, 0)
    end
    header.meta:SetText("")
    header.action:Hide()
    header:Show()
    y = y + 22

    for _, it in ipairs(boss.items or {}) do
      rowIdx = rowIdx + 1
      local r = get_row(rowIdx)
      r:SetPoint("TOPLEFT", 0, -y)
      r._itemId = it.itemId
      r._itemName = it.name
      local qc = quality_color(it.quality)
      local wished = CrusaderStrikeWishList.IsWished(db, state.mapId, it.itemId)
      local star = wished and " ★" or ""
      r.label:SetText(string.format("[%d] %s%s", it.itemId, it.name or "?", star))
      if r.label.SetTextColor then
        r.label:SetTextColor(qc[1], qc[2], qc[3])
      end
      r.meta:SetText(it.slot or "")
      set_row_icon(r, it.itemId)
      r.action:Show()
      if wished then
        r.action:SetText("Remove")
        r.action:SetScript("OnClick", function()
          CrusaderStrikeWishList.Remove(db, state.mapId, it.itemId)
          CS.Print("Removed from wish list: " .. (it.name or tostring(it.itemId)))
          LB.Refresh()
        end)
      else
        r.action:SetText("Add")
        local npcId = boss.npcId
        local itemId = it.itemId
        r.action:SetScript("OnClick", function()
          local ok, err = CrusaderStrikeWishList.Add(db, state.mapId, itemId, { bossNpcId = npcId })
          if ok then
            CS.Print("Wish-listed: " .. (it.name or tostring(itemId)))
          else
            CS.Print("Could not add (" .. tostring(err) .. ")")
          end
          LB.Refresh()
        end)
      end
      r:Show()
      y = y + 22
    end
  end

  content:SetSize(470, math.max(y, 10))
  local wanted, obtained, total = CrusaderStrikeWishList.WantedCount(db, state.mapId)
  local ver = dungeon.verified and "verified Forever IDs" or "unverified"
  statusText:SetText(string.format(
    "%s — %s. Wish list: %d wanted, %d obtained (%d total).",
    dungeon.name or "?", ver, wanted, obtained, total
  ))
end

local function paint_wish_view()
  clear_rows()
  local db = char_db()
  local list = CrusaderStrikeWishList.GetDungeonList(db, state.mapId)
  local y = 0
  local rowIdx = 0

  if #list == 0 then
    statusText:SetText("Wish list empty for this dungeon. Add items from the loot table.")
    content:SetSize(470, 10)
    return
  end

  for i, row in ipairs(list) do
    rowIdx = rowIdx + 1
    local r = get_row(rowIdx)
    r:SetPoint("TOPLEFT", 0, -y)
    r._itemId = row.itemId
    local it = CrusaderStrikeLoot.LookupItem and select(1, CrusaderStrikeLoot.LookupItem(CS.GetGameVersion and CS.GetGameVersion() or "forever", row.itemId))
    local name = (it and it.name) or ("item:" .. tostring(row.itemId))
    r._itemName = name
    local flag = row.obtained and " [obtained]" or " [wanted]"
    r.label:SetText(string.format("#%d [%d] %s%s", i, row.itemId, name, flag))
    if r.label.SetTextColor then
      if row.obtained then
        r.label:SetTextColor(0.5, 0.5, 0.5)
      else
        local qc = quality_color(it and it.quality or 3)
        r.label:SetTextColor(qc[1], qc[2], qc[3])
      end
    end
    r.meta:SetText(it and it.slot or "")
    set_row_icon(r, row.itemId)
    r.action:Show()
    r.action:SetText("Remove")
    local itemId = row.itemId
    r.action:SetScript("OnClick", function()
      CrusaderStrikeWishList.Remove(db, state.mapId, itemId)
      LB.Refresh()
    end)

    -- Up / down via click modifiers: Shift-click row to move up, Alt-click to move down.
    r:SetScript("OnClick", function(self, button)
      local IsShiftKeyDown = rawget(_G, "IsShiftKeyDown")
      local IsAltKeyDown = rawget(_G, "IsAltKeyDown")
      if IsShiftKeyDown and IsShiftKeyDown() then
        CrusaderStrikeWishList.Reorder(db, state.mapId, itemId, i - 1)
        LB.Refresh()
      elseif IsAltKeyDown and IsAltKeyDown() then
        CrusaderStrikeWishList.Reorder(db, state.mapId, itemId, i + 1)
        LB.Refresh()
      elseif not row.obtained then
        CrusaderStrikeWishList.MarkObtained(db, state.mapId, itemId, true)
        LB.Refresh()
      else
        CrusaderStrikeWishList.MarkObtained(db, state.mapId, itemId, false)
        LB.Refresh()
      end
    end)

    r:Show()
    y = y + 22
  end

  content:SetSize(470, math.max(y, 10))
  local wanted, obtained, total = CrusaderStrikeWishList.WantedCount(db, state.mapId)
  statusText:SetText(string.format(
    "Wish list — %d wanted, %d obtained (%d). Click to toggle obtained; Shift/Alt-click to reorder.",
    wanted, obtained, total
  ))
end

-- Repaint only the loot / wish pane (search + slot filter changes).
local function refresh_content()
  if state.view == "wish" then
    paint_wish_view()
  else
    paint_loot_view()
  end
end

function LB.Refresh()
  if not frame then
    return
  end
  paint_dungeon_list()
  if not state.mapId then
    local list = CrusaderStrikeLoot.ListDungeons(CS.GetGameVersion and CS.GetGameVersion() or "forever")
    if list[1] then
      state.mapId = list[1].instanceMapId
    end
  end
  local curMap, curName = current_instance_map()
  if curMap and state.mapId == curMap then
    local wanted = CrusaderStrikeWishList.WantedItemIds(char_db(), state.mapId)
    local n = 0
    for _ in pairs(wanted) do
      n = n + 1
    end
    highlightBanner:SetText(string.format(
      "You are in this dungeon. %d wish-list item(s) still wanted — loot them to auto-mark obtained.",
      n
    ))
  elseif curMap then
    highlightBanner:SetText("In instance: " .. tostring(curName or curMap) .. " (select it on the left to see wishes).")
  else
    highlightBanner:SetText("Pick a dungeon. * = no loot data bundled yet.")
  end

  refresh_content()
end

function LB.RefreshContent()
  if frame then
    refresh_content()
  end
end

function LB.Toggle()
  ensure_ui()
  local shown = false
  if frame.IsShown then
    shown = frame:IsShown()
  else
    shown = frame._shown and true or false
  end
  if shown then
    frame:Hide()
    return
  end
  local curMap = current_instance_map()
  if curMap then
    state.mapId = curMap
  end
  frame:Show()
  LB.Refresh()
end

function LB.Show(mapId)
  ensure_ui()
  if mapId then
    state.mapId = tonumber(mapId) or mapId
  else
    local curMap = current_instance_map()
    if curMap then
      state.mapId = curMap
    end
  end
  state.view = "loot"
  if wishToggle then
    wishToggle:SetText("Wish list")
  end
  frame:Show()
  LB.Refresh()
end

function LB.Hide()
  if frame then
    frame:Hide()
  end
end

-- Loot chat → mark obtained when the item is on a wish list.
-- Only the player's own loot lines count (see is_self_loot).
function LB.OnLootMessage(msg, playerName)
  if not is_self_loot(msg, playerName) then
    return
  end
  local itemId = parse_loot_item_id(msg)
  if not itemId then
    return
  end
  local db = char_db()
  if not db then
    return
  end
  local prefer = current_instance_map()
  local n = CrusaderStrikeWishList.MarkObtainedAny(db, itemId, true, prefer)
  if n > 0 then
    local it = CrusaderStrikeLoot.LookupItem and select(1, CrusaderStrikeLoot.LookupItem(CS.GetGameVersion and CS.GetGameVersion() or "forever", itemId))
    CS.Print("Wish-list obtained: " .. ((it and it.name) or tostring(itemId)))
    if frame and ((frame.IsShown and frame:IsShown()) or frame._shown) then
      LB.Refresh()
    end
  end
end

-- Expose for tests.
LB._parse_loot_item_id = parse_loot_item_id
LB._is_self_loot = is_self_loot
LB._format_to_pattern = format_to_pattern
function LB._reset_loot_patterns()
  selfLootPatterns = nil
end

local eventFrame = CreateFrame("Frame", "CrusaderStrikeLootEvents")
eventFrame:RegisterEvent("CHAT_MSG_LOOT")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:SetScript("OnEvent", function(_, event, ...)
  if event == "CHAT_MSG_LOOT" then
    local msg, _, _, _, playerName = ...
    LB.OnLootMessage(msg, playerName)
  elseif event == "PLAYER_ENTERING_WORLD" then
    if frame and ((frame.IsShown and frame:IsShown()) or frame._shown) then
      LB.Refresh()
    end
  end
end)
