-- Minimal WoW API stubs for loading addon files under plain Lua 5.1.

local M = {}

local function noop() end

_G.DEFAULT_CHAT_FRAME = {
  AddMessage = function(_, msg)
    if os.getenv("CS_TEST_VERBOSE") then
      io.stderr:write(tostring(msg) .. "\n")
    end
  end,
}

_G.UIParent = {}
_G.GameFontNormalLarge = {}
_G.GameFontHighlightSmall = {}

function _G.CreateFrame(frameType, name, parent, template)
  local f = {
    _type = frameType,
    _name = name,
    _scripts = {},
    _events = {},
    _shown = false,
  }
  function f:RegisterEvent(e)
    if e == "COMBAT_LOG_EVENT_UNFILTERED" then
      _G._CS_CleuRegisterAttempts = (_G._CS_CleuRegisterAttempts or 0) + 1
      error("COMBAT_LOG_EVENT_UNFILTERED registration is protected on Forever 1.60.1", 0)
    end
    self._events[e] = true
  end
  function f:UnregisterEvent(e) self._events[e] = nil end
  function f:SetScript(ev, fn) self._scripts[ev] = fn end
  function f:SetSize() end
  function f:SetPoint() end
  function f:SetFrameStrata() end
  function f:SetMovable() end
  function f:EnableMouse() end
  function f:RegisterForDrag() end
  function f:StartMoving() end
  function f:StopMovingOrSizing() end
  function f:SetBackdrop() end
  function f:SetBackdropColor() end
  function f:CreateFontString()
    return { SetPoint = noop, SetText = noop }
  end
  function f:SetMultiLine() end
  function f:SetFontObject() end
  function f:SetWidth() end
  function f:SetAutoFocus() end
  function f:SetText(t) self._text = t end
  function f:GetText() return self._text end
  function f:HighlightText() end
  function f:SetFocus() end
  function f:SetScrollChild() end
  function f:Hide() self._shown = false end
  function f:Show() self._shown = true end
  function f:SetText() end -- button
  if name then
    _G[name] = f
  end
  return f
end

_G.SlashCmdList = {}
_G.time = os.time
_G.GetServerTime = os.time
_G.GetRealmName = function() return "CrusaderStrike" end
_G.GetNormalizedRealmName = function() return "CrusaderStrike" end
_G.UnitName = function(unit)
  if unit == "player" then return "Tester" end
  return nil
end
_G.UnitClass = function() return "Paladin", "PALADIN" end
_G.UnitLevel = function() return 25 end
_G.UnitExists = function(unit) return unit == "player" end
_G.UnitIsUnit = function(a, b) return a == b end
_G.UnitInParty = function() return true end
_G.IsInInstance = function() return false, nil end
_G.GetInstanceInfo = function()
  return nil, nil, nil, nil, nil, nil, nil, nil
end
-- Forever 1.60.1: calling this (even under pcall) triggers ADDON_ACTION_BLOCKED.
_G._CS_CombatLogCallCount = 0
_G.CombatLogGetCurrentEventInfo = function()
  _G._CS_CombatLogCallCount = (_G._CS_CombatLogCallCount or 0) + 1
  error("CombatLogGetCurrentEventInfo is protected on Forever 1.60.1", 0)
end
_G.UnitIsDead = function() return false end
_G.UnitIsDeadOrGhost = function() return false end
_G.UnitGUID = function(unit)
  if unit == "player" then return "Player-1-00000001" end
  return nil
end
_G.GetBuildInfo = function() return "1.60.1", "70790", "Nov 4 2026", 16001 end
-- TODO(unverified): Forever reportedly reports WOW_PROJECT_MAINLINE (1).
_G.WOW_PROJECT_ID = 1
_G.WOW_PROJECT_MAINLINE = 1

function M.load_addon()
  local root = arg and arg[0] and arg[0]:match("(.*/)") or "./"
  -- tests/ is cwd relative; prefer absolute via package path setup in run_tests
  local base = package.path:match("(/[^;]+)/Logic/%?.lua")
  if not base then
    base = "."
  end
  local files = {
    "Data/Bosses.lua",
    "Logic/Idempotency.lua",
    "Logic/Encoder.lua",
    "Logic/RunLifecycle.lua",
    "Logic/PvpHistory.lua",
    "Logic/Detection.lua",
    "Logic/DebugEvents.lua",
    "Core.lua",
    "DungeonLog.lua",
    "Export.lua",
    "PvpLog.lua",
  }
  for _, rel in ipairs(files) do
    local path = base .. "/" .. rel
    local fn, err = loadfile(path)
    if not fn then
      error("loadfile failed: " .. path .. " :: " .. tostring(err))
    end
    fn()
  end
end

return M
