--[[
  /cs export — show versioned copy-paste strings in an EditBox.
  Box contains CSRUN1: (unchanged) then CSGEAR1:, plus a separate Copy gear button.
]]

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike
CS.Export = CS.Export or {}
local Ex = CS.Export

local frame, edit, scroll, gearEdit

local function ensure_ui()
  if frame then
    return
  end
  frame = CreateFrame("Frame", "CrusaderStrikeExportFrame", UIParent, "BackdropTemplate")
  frame:SetSize(520, 300)
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
    frame:SetBackdropColor(0, 0, 0, 0.9)
  end

  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 12, -12)
  title:SetText("CrusaderStrike export")

  local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  hint:SetText("CSRUN1 then CSGEAR1. Ctrl+C to copy; use Copy gear for the gear line only.")

  scroll = CreateFrame("ScrollFrame", "CrusaderStrikeExportScroll", frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -48)
  scroll:SetPoint("BOTTOMRIGHT", -30, 70)

  edit = CreateFrame("EditBox", "CrusaderStrikeExportEdit", scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(GameFontHighlightSmall)
  edit:SetWidth(460)
  edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  scroll:SetScrollChild(edit)

  -- Hidden single-line buffer for Copy gear (selects CSGEAR1 only).
  gearEdit = CreateFrame("EditBox", "CrusaderStrikeExportGearEdit", frame)
  gearEdit:SetMultiLine(false)
  gearEdit:SetFontObject(GameFontHighlightSmall)
  gearEdit:SetWidth(1)
  gearEdit:SetHeight(1)
  gearEdit:SetPoint("TOPLEFT", 0, 0)
  gearEdit:SetAutoFocus(false)
  gearEdit:Hide()

  local close = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  close:SetSize(80, 22)
  close:SetPoint("BOTTOMRIGHT", -12, 10)
  close:SetText("Close")
  close:SetScript("OnClick", function()
    frame:Hide()
  end)

  local selectAll = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  selectAll:SetSize(100, 22)
  selectAll:SetPoint("RIGHT", close, "LEFT", -8, 0)
  selectAll:SetText("Select all")
  selectAll:SetScript("OnClick", function()
    edit:SetFocus()
    edit:HighlightText()
  end)

  local copyGear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
  copyGear:SetSize(100, 22)
  copyGear:SetPoint("RIGHT", selectAll, "LEFT", -8, 0)
  copyGear:SetText("Copy gear")
  copyGear:SetScript("OnClick", function()
    local gear = frame._gearLine
    if not gear or gear == "" then
      CS.Print("No gear export available")
      return
    end
    gearEdit:Show()
    gearEdit:SetText(gear)
    gearEdit:SetFocus()
    gearEdit:HighlightText()
    CS.Print("Gear line selected — Ctrl+C to copy")
  end)

  frame:Hide()
end

local function pick_run(keyHint)
  local charDB = CS.GetCharDB()
  if keyHint and keyHint ~= "" then
    local run = charDB.runs[keyHint]
    if run then
      return run
    end
    CS.Print("No run with key: " .. keyHint)
    return nil
  end
  local active = CS.GetActiveRun()
  if active then
    return active
  end
  local best
  for _, run in pairs(charDB.runs or {}) do
    if not best or (run.startedAt or 0) > (best.startedAt or 0) then
      best = run
    end
  end
  return best
end

function Ex.BuildString(run)
  local payload = CrusaderStrikeRunLifecycle.ToExportTable(run)
  return CrusaderStrikeEncoder.EncodeRun(payload)
end

function Ex.BuildGearString()
  if not CrusaderStrikeGearSets or not CrusaderStrikeGearEncoder then
    return nil, "unavailable"
  end
  local charDB = CS.GetCharDB()
  local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""
  local character = (UnitName and UnitName("player")) or ""
  local payload = CrusaderStrikeGearSets.BuildExportPayload(charDB, {
    realm = realm,
    character = character,
    region = (charDB.gearSets and charDB.gearSets.region) or "us",
  })
  return CrusaderStrikeGearEncoder.Encode(payload)
end

function Ex.Show(keyHint)
  ensure_ui()
  local lines = {}
  local run = pick_run(keyHint)
  local runLabel = nil
  if run then
    lines[#lines + 1] = Ex.BuildString(run)
    runLabel = run.instance and run.instance.name or run.idempotencyKey
  else
    CS.Print("No runs to export yet (gear line still available).")
  end
  local gear, gerr = Ex.BuildGearString()
  if gear then
    lines[#lines + 1] = gear
    frame._gearLine = gear
  else
    frame._gearLine = nil
    if gerr then
      CS.Print("Gear export skipped: " .. tostring(gerr))
    end
  end
  if #lines == 0 then
    return
  end
  edit:SetText(table.concat(lines, "\n"))
  edit:HighlightText()
  edit:SetFocus()
  frame:Show()
  if CrusaderStrikeDB and CrusaderStrikeDB.companion then
    CrusaderStrikeDB.companion.lastSeenExportAt = (GetServerTime and GetServerTime()) or time()
  end
  if runLabel then
    CS.Print("Export ready for " .. runLabel)
  else
    CS.Print("Gear export ready")
  end
end
