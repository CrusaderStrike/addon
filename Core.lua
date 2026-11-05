--[[
  CrusaderStrike core: SavedVariables bootstrap, gameVersion (WoW Forever only), slash cmds.
  Storage is companion-uploader friendly:
    CrusaderStrikeDB (account)   — schemaVersion, settings, uploadQueue meta
    CrusaderStrikeCharDB (char)  — gameVersion, activeRun, runs[idempotencyKey]=run
]]

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike

CS.ADDON_NAME = "CrusaderStrike"
CS.VERSION = "0.1.0"
CS.SCHEMA_VERSION = 1

local defaultsAccount = {
  schemaVersion = CS.SCHEMA_VERSION,
  settings = {
    resumeWindowSec = 3 * 60 * 60,
    debug = false,
  },
  -- Companion may append acknowledgements here later (uploadedKeys).
  companion = {
    lastSeenExportAt = nil,
  },
}

local defaultsChar = {
  schemaVersion = CS.SCHEMA_VERSION,
  gameVersion = "forever",
  activeRunKey = nil,
  runs = {}, -- [idempotencyKey] = run table
}

local function deep_copy(src)
  if type(src) ~= "table" then
    return src
  end
  local t = {}
  for k, v in pairs(src) do
    t[k] = deep_copy(v)
  end
  return t
end

local function apply_defaults(db, defaults)
  if type(db) ~= "table" then
    return deep_copy(defaults)
  end
  for k, v in pairs(defaults) do
    if db[k] == nil then
      db[k] = deep_copy(v)
    elseif type(v) == "table" and type(db[k]) == "table" then
      apply_defaults(db[k], v)
    end
  end
  return db
end

function CS.DetectGameVersion()
  -- CrusaderStrike supports World of Warcraft: Forever ONLY.
  -- Forever reports WOW_PROJECT_CAMELOT (18) per Warcraft Wiki ProjectConstants;
  -- also accept toc Interface 16001 / GetBuildInfo interface version.
  local project = rawget(_G, "WOW_PROJECT_ID")
  local camelot = rawget(_G, "WOW_PROJECT_CAMELOT") or 18
  if project ~= nil and project ~= camelot and project ~= rawget(_G, "WOW_PROJECT_MAINLINE") then
    -- Non-Forever classic/retail project: still force forever label so we never
    -- emit another gameVersion; operators should not load this TOC elsewhere
    -- (AllowLoadGameType: forever, camelot).
  end
  return "forever"
end

function CS.Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffd4a017CrusaderStrike|r: " .. tostring(msg))
end

function CS.Debug(msg)
  if CrusaderStrikeDB and CrusaderStrikeDB.settings and CrusaderStrikeDB.settings.debug then
    CS.Print("[debug] " .. tostring(msg))
  end
end

function CS.GetCharDB()
  return CrusaderStrikeCharDB
end

function CS.GetAccountDB()
  return CrusaderStrikeDB
end

function CS.GetGameVersion()
  return (CrusaderStrikeCharDB and CrusaderStrikeCharDB.gameVersion) or CS.DetectGameVersion()
end

function CS.StoreRun(run)
  if not run or not run.idempotencyKey then
    return
  end
  CrusaderStrikeCharDB.runs[run.idempotencyKey] = run
  if run.status == "in_progress" then
    CrusaderStrikeCharDB.activeRunKey = run.idempotencyKey
  end
end

function CS.GetActiveRun()
  local key = CrusaderStrikeCharDB and CrusaderStrikeCharDB.activeRunKey
  if not key then
    return nil
  end
  return CrusaderStrikeCharDB.runs[key]
end

function CS.ClearActiveRunKey()
  if CrusaderStrikeCharDB then
    CrusaderStrikeCharDB.activeRunKey = nil
  end
end

local frame = CreateFrame("Frame", "CrusaderStrikeCoreFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == CS.ADDON_NAME then
    CrusaderStrikeDB = apply_defaults(CrusaderStrikeDB, defaultsAccount)
    CrusaderStrikeCharDB = apply_defaults(CrusaderStrikeCharDB, defaultsChar)
    CrusaderStrikeCharDB.schemaVersion = CS.SCHEMA_VERSION
    CrusaderStrikeDB.schemaVersion = CS.SCHEMA_VERSION
    CrusaderStrikeCharDB.gameVersion = CS.DetectGameVersion()
    CS.Debug("Loaded schema v" .. CS.SCHEMA_VERSION .. " gameVersion=" .. CrusaderStrikeCharDB.gameVersion)
  elseif event == "PLAYER_LOGIN" then
    if CS.DungeonLog and CS.DungeonLog.OnLogin then
      CS.DungeonLog.OnLogin()
    end
  end
end)

SLASH_CRUSADERSTRIKE1 = "/cs"
SLASH_CRUSADERSTRIKE2 = "/crusaderstrike"
SlashCmdList["CRUSADERSTRIKE"] = function(msg)
  msg = (msg or ""):match("^%s*(.-)%s*$") or ""
  local cmd, rest = msg:match("^(%S+)%s*(.*)$")
  cmd = cmd and cmd:lower() or "help"
  if cmd == "export" then
    if CS.Export and CS.Export.Show then
      CS.Export.Show(rest)
    end
  elseif cmd == "status" then
    local run = CS.GetActiveRun()
    if run then
      CS.Print(string.format(
        "Active run %s in %s (%d bosses, %d deaths)",
        run.idempotencyKey,
        run.instance.name or "?",
        #(run.bosses or {}),
        #(run.deaths or {})
      ))
    else
      local n = 0
      for _ in pairs(CrusaderStrikeCharDB.runs or {}) do
        n = n + 1
      end
      CS.Print("No active run. Stored runs: " .. n)
    end
  elseif cmd == "debug" then
    CrusaderStrikeDB.settings.debug = not CrusaderStrikeDB.settings.debug
    CS.Print("debug=" .. tostring(CrusaderStrikeDB.settings.debug))
  else
    CS.Print("Commands: /cs export [key] | /cs status | /cs debug")
  end
end
