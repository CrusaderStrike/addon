--[[
  /cs gearsets — character-window style armory frame for named gear sets.
  No CLEU, no protected calls. Click a slot to set (item ID or shift-click link)
  or clear. Create/edit: below 60 default leveling + Up to level; at 60 max_level only.
]]

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike
CS.GearSetsUI = CS.GearSetsUI or {}
local UI = CS.GearSetsUI

local frame
local state = {
  local_id = nil,
  creating = false,
}

local titleText
local statusText
local dropdown
local nameBox
local untilBox
local roleBox
local typeBtn
local slotButtons = {}
local createPanel

local function char_db()
  return CS.GetCharDB and CS.GetCharDB() or CrusaderStrikeCharDB
end

local function player_level()
  if UnitLevel then
    return UnitLevel("player") or 1
  end
  return 1
end

local function set_status(msg)
  if statusText then
    statusText:SetText(msg or "")
  end
  if msg and msg ~= "" and CS.Print then
    -- keep chat quiet for routine refreshes
  end
end

local function current_list()
  if not state.local_id then
    return nil
  end
  return CrusaderStrikeGearSets.FindByLocalId(char_db(), state.local_id)
end

local function refresh_slots()
  local list = current_list()
  for slot, btn in pairs(slotButtons) do
    local id = list and list.slots and list.slots[slot]
    if id then
      btn:SetText(slot .. "\n" .. tostring(id))
    else
      btn:SetText(slot .. "\n—")
    end
  end
end

local function refresh_form()
  local list = current_list()
  local lvl = player_level()
  if list then
    if nameBox then
      nameBox:SetText(list.name or "")
    end
    if roleBox then
      roleBox:SetText(list.role_spec or "")
    end
    if typeBtn then
      typeBtn:SetText(list.type == "max_level" and "Type: max_level" or "Type: leveling")
    end
    if untilBox then
      if list.type == "leveling" and lvl < 60 then
        untilBox:Show()
        untilBox:SetText(tostring(list.until_level or (lvl + 1)))
      else
        untilBox:SetText("")
        untilBox:Hide()
      end
    end
  end
  refresh_slots()
end

local function rebuild_dropdown_label()
  if not dropdown then
    return
  end
  local list = current_list()
  if state.creating then
    dropdown:SetText("Add a new gear set")
  elseif list then
    dropdown:SetText(list.name)
  else
    dropdown:SetText("Select a gear set…")
  end
end

local function open_create()
  state.creating = true
  state.local_id = nil
  local lvl = player_level()
  if nameBox then
    nameBox:SetText("")
  end
  if roleBox then
    roleBox:SetText("")
  end
  if typeBtn then
    if lvl >= 60 then
      typeBtn:SetText("Type: max_level")
    else
      typeBtn:SetText("Type: leveling")
    end
  end
  if untilBox then
    if lvl >= 60 then
      untilBox:Hide()
    else
      untilBox:Show()
      untilBox:SetText(tostring(math.min(60, lvl + 1)))
    end
  end
  rebuild_dropdown_label()
  refresh_slots()
  set_status("New set — enter a name, then Save")
end

local function select_set(local_id)
  state.creating = false
  state.local_id = local_id
  rebuild_dropdown_label()
  refresh_form()
  set_status("")
end

local function cycle_set(dir)
  local bucket = CrusaderStrikeGearSets.EnsureDB(char_db())
  if not bucket or #bucket.lists == 0 then
    open_create()
    return
  end
  local idx = 1
  for i, list in ipairs(bucket.lists) do
    if list.local_id == state.local_id then
      idx = i
      break
    end
  end
  idx = idx + (dir or 1)
  if idx < 1 then
    idx = #bucket.lists
  elseif idx > #bucket.lists then
    -- past end → add new
    open_create()
    return
  end
  select_set(bucket.lists[idx].local_id)
end

local function parse_item_input(text)
  text = (tostring(text or ""):match("^%s*(.-)%s*$")) or ""
  if text == "" then
    return nil
  end
  if CrusaderStrikeEquippedGear and CrusaderStrikeEquippedGear.ParseItemLink then
    local parsed = CrusaderStrikeEquippedGear.ParseItemLink(text)
    if parsed then
      return parsed.item_id
    end
  end
  local id = tonumber(text)
  if id and id == math.floor(id) and id >= 1 then
    return id
  end
  return nil
end

local function prompt_slot(slot)
  local list = current_list()
  if not list then
    set_status("Select or create a gear set first")
    return
  end
  -- Shift-click link in chat / edit: use Static-like EditBox on the frame.
  if not frame._slotEdit then
    local eb = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    eb:SetSize(180, 20)
    eb:SetPoint("BOTTOM", frame, "BOTTOM", 0, 36)
    eb:SetAutoFocus(false)
    eb:Hide()
    frame._slotEdit = eb
    local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOM", eb, "TOP", 0, 2)
    hint:SetText("Item ID or shift-click link; empty clears. Enter=save Esc=cancel")
    frame._slotHint = hint
    eb:SetScript("OnEnterPressed", function(self)
      local slotName = self._slot
      local text = self:GetText() or ""
      self:Hide()
      if frame._slotHint then
        frame._slotHint:Hide()
      end
      if text == "" then
        local _, err = CrusaderStrikeGearSets.SetSlot(char_db(), list.local_id, slotName, nil)
        if err then
          set_status("clear failed: " .. err)
        else
          set_status("Cleared " .. slotName)
          refresh_slots()
        end
      else
        local item_id = parse_item_input(text)
        if not item_id then
          set_status("Invalid item id / link")
          return
        end
        local _, err = CrusaderStrikeGearSets.SetSlot(char_db(), list.local_id, slotName, item_id)
        if err then
          set_status("set failed: " .. err)
        else
          set_status(slotName .. " = " .. tostring(item_id))
          refresh_slots()
        end
      end
    end)
    eb:SetScript("OnEscapePressed", function(self)
      self:Hide()
      if frame._slotHint then
        frame._slotHint:Hide()
      end
    end)
  end
  frame._slotEdit._slot = slot
  frame._slotEdit:SetText("")
  frame._slotEdit:Show()
  if frame._slotHint then
    frame._slotHint:Show()
  end
  frame._slotEdit:SetFocus()
end

local function save_create_or_edit()
  local lvl = player_level()
  local name = nameBox and nameBox:GetText() or ""
  local role = roleBox and roleBox:GetText() or ""
  local type_label = typeBtn and typeBtn:GetText() or ""
  local set_type = type_label:find("max_level") and "max_level" or "leveling"
  if lvl >= 60 then
    set_type = "max_level"
  end
  local until_level = nil
  if set_type == "leveling" then
    until_level = tonumber(untilBox and untilBox:GetText() or "")
  end
  if state.creating then
    local list, err = CrusaderStrikeGearSets.CreateSet(char_db(), {
      name = name,
      type = set_type,
      until_level = until_level,
      role_spec = role,
    }, lvl)
    if not list then
      set_status("Create failed: " .. tostring(err))
      if CS.Print then
        CS.Print("gear set create failed: " .. tostring(err))
      end
      return
    end
    select_set(list.local_id)
    set_status("Created " .. list.name)
    if CS.Print then
      CS.Print("Created gear set: " .. list.name)
    end
  else
    local list, err = CrusaderStrikeGearSets.UpdateSet(char_db(), state.local_id, {
      name = name,
      type = set_type,
      until_level = until_level,
      role_spec = role,
    }, lvl)
    if not list then
      set_status("Update failed: " .. tostring(err))
      return
    end
    rebuild_dropdown_label()
    refresh_form()
    set_status("Saved " .. list.name)
  end
end

local function toggle_type()
  local lvl = player_level()
  if lvl >= 60 then
    typeBtn:SetText("Type: max_level")
    if untilBox then
      untilBox:Hide()
    end
    return
  end
  local cur = typeBtn:GetText() or ""
  if cur:find("max_level") then
    typeBtn:SetText("Type: leveling")
    if untilBox then
      untilBox:Show()
      untilBox:SetText(tostring(math.min(60, lvl + 1)))
    end
  else
    typeBtn:SetText("Type: max_level")
    if untilBox then
      untilBox:Hide()
    end
  end
end

local function ensure_ui()
  if frame then
    return
  end
  frame = CreateFrame("Frame", "CrusaderStrikeGearSetsFrame", UIParent, "BackdropTemplate")
  frame:SetSize(420, 520)
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
  titleText:SetText("CrusaderStrike gear sets")

  dropdown = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  dropdown:SetSize(220, 22)
  dropdown:SetPoint("TOPLEFT", 12, -40)
  dropdown:SetText("Select a gear set…")
  dropdown:SetScript("OnClick", function()
    cycle_set(1)
  end)

  local prev = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  prev:SetSize(28, 22)
  prev:SetPoint("LEFT", dropdown, "RIGHT", 4, 0)
  prev:SetText("<")
  prev:SetScript("OnClick", function()
    cycle_set(-1)
  end)

  local addBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  addBtn:SetSize(70, 22)
  addBtn:SetPoint("LEFT", prev, "RIGHT", 4, 0)
  addBtn:SetText("Add")
  addBtn:SetScript("OnClick", open_create)

  nameBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  nameBox:SetSize(200, 20)
  nameBox:SetPoint("TOPLEFT", 16, -72)
  nameBox:SetAutoFocus(false)
  local nameLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  nameLabel:SetPoint("BOTTOMLEFT", nameBox, "TOPLEFT", 0, 2)
  nameLabel:SetText("Name")

  typeBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  typeBtn:SetSize(140, 22)
  typeBtn:SetPoint("LEFT", nameBox, "RIGHT", 12, 0)
  typeBtn:SetText("Type: leveling")
  typeBtn:SetScript("OnClick", toggle_type)

  untilBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  untilBox:SetSize(60, 20)
  untilBox:SetPoint("TOPLEFT", nameBox, "BOTTOMLEFT", 0, -18)
  untilBox:SetAutoFocus(false)
  local untilLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  untilLabel:SetPoint("BOTTOMLEFT", untilBox, "TOPLEFT", 0, 2)
  untilLabel:SetText("Up to level")

  roleBox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
  roleBox:SetSize(120, 20)
  roleBox:SetPoint("LEFT", untilBox, "RIGHT", 24, 0)
  roleBox:SetAutoFocus(false)
  local roleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  roleLabel:SetPoint("BOTTOMLEFT", roleBox, "TOPLEFT", 0, 2)
  roleLabel:SetText("Role / spec")

  local saveBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  saveBtn:SetSize(80, 22)
  saveBtn:SetPoint("TOPRIGHT", -12, -72)
  saveBtn:SetText("Save")
  saveBtn:SetScript("OnClick", save_create_or_edit)

  local delBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  delBtn:SetSize(80, 22)
  delBtn:SetPoint("TOPRIGHT", -12, -98)
  delBtn:SetText("Delete")
  delBtn:SetScript("OnClick", function()
    if not state.local_id then
      return
    end
    local ok, err = CrusaderStrikeGearSets.DeleteSet(char_db(), state.local_id)
    if not ok then
      set_status("Delete failed: " .. tostring(err))
      return
    end
    state.local_id = nil
    local bucket = CrusaderStrikeGearSets.EnsureDB(char_db())
    if bucket and bucket.lists[1] then
      select_set(bucket.lists[1].local_id)
    else
      open_create()
    end
    set_status("Deleted")
  end)

  -- Armory slot grid
  local GS = CrusaderStrikeGearSlots
  local top = -150
  for rowIdx, pair in ipairs(GS.LAYOUT) do
    for col, slot in ipairs(pair) do
      if slot then
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(120, 28)
        local x = (col == 1) and 16 or 220
        local y = top - (rowIdx - 1) * 32
        btn:SetPoint("TOPLEFT", x, y)
        btn:SetText(slot)
        btn:SetScript("OnClick", function()
          prompt_slot(slot)
        end)
        slotButtons[slot] = btn
      end
    end
  end

  statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  statusText:SetPoint("BOTTOMLEFT", 12, 14)
  statusText:SetPoint("BOTTOMRIGHT", -12, 14)
  statusText:SetJustifyH("LEFT")
  statusText:SetText("")

  local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  close:SetSize(80, 22)
  close:SetPoint("BOTTOMRIGHT", -12, 10)
  close:SetText("Close")
  close:SetScript("OnClick", function()
    frame:Hide()
  end)

  frame:Hide()
end

function UI.Show()
  ensure_ui()
  if CrusaderStrikeEquippedGear then
    CrusaderStrikeEquippedGear.ScanNow()
  end
  local bucket = CrusaderStrikeGearSets.EnsureDB(char_db())
  if state.local_id and CrusaderStrikeGearSets.FindByLocalId(char_db(), state.local_id) then
    select_set(state.local_id)
  elseif bucket and bucket.lists[1] then
    select_set(bucket.lists[1].local_id)
  else
    open_create()
  end
  frame:Show()
end

function UI.Hide()
  if frame then
    frame:Hide()
  end
end
