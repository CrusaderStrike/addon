--[[
  /cs export — show a versioned copy-paste export string in an EditBox.
]]

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike
CS.Export = CS.Export or {}
local Ex = CS.Export

local frame, edit, scroll

local function ensure_ui()
  if frame then
    return
  end
  frame = CreateFrame("Frame", "CrusaderStrikeExportFrame", UIParent, "BackdropTemplate")
  frame:SetSize(520, 220)
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
  hint:SetText("Ctrl+C to copy, then paste into crusaderstrike.gg")

  scroll = CreateFrame("ScrollFrame", "CrusaderStrikeExportScroll", frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -48)
  scroll:SetPoint("BOTTOMRIGHT", -30, 40)

  edit = CreateFrame("EditBox", "CrusaderStrikeExportEdit", scroll)
  edit:SetMultiLine(true)
  edit:SetFontObject(GameFontHighlightSmall)
  edit:SetWidth(460)
  edit:SetAutoFocus(false)
  edit:SetScript("OnEscapePressed", function()
    frame:Hide()
  end)
  scroll:SetScrollChild(edit)

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
  -- Most recently started closed/completed run.
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

function Ex.Show(keyHint)
  local run = pick_run(keyHint)
  if not run then
    CS.Print("No runs to export yet.")
    return
  end
  ensure_ui()
  local encoded = Ex.BuildString(run)
  edit:SetText(encoded)
  edit:HighlightText()
  edit:SetFocus()
  frame:Show()
  if CrusaderStrikeDB and CrusaderStrikeDB.companion then
    CrusaderStrikeDB.companion.lastSeenExportAt = (GetServerTime and GetServerTime()) or time()
  end
  CS.Print("Export ready for " .. (run.instance.name or run.idempotencyKey))
end
