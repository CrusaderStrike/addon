--[[
  CrusaderStrike core: SavedVariables bootstrap, gameVersion (WoW Forever only), slash cmds.
  Storage is companion-uploader friendly:
    CrusaderStrikeDB (account)   — schemaVersion, settings, uploadQueue meta
    CrusaderStrikeCharDB (char)  — gameVersion, activeRun, runs[idempotencyKey]=run, pvp{world[],battlegrounds[]}, wishLists
]]

CrusaderStrike = CrusaderStrike or {}
local CS = CrusaderStrike

CS.ADDON_NAME = "CrusaderStrike"
CS.VERSION = "0.2.0"
-- SavedVariables layout version. 3 adds CrusaderStrikeCharDB.wishLists (docs/loot-data.md).
-- 2 added CrusaderStrikeCharDB.pvp (docs/pvp-schema.md).
-- The run export payload keeps its own schemaVersion (1) in Logic/RunLifecycle.lua.
CS.SCHEMA_VERSION = 3

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
  pvp = { world = {}, battlegrounds = {}, seq = 0 }, -- schema v2, see docs/pvp-schema.md
  wishLists = {}, -- schema v3, per-dungeon wish lists; see docs/loot-data.md
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
  elseif cmd == "pvp" then
    if CS.PvpLog and CS.PvpLog.Summary then
      for _, line in ipairs(CS.PvpLog.Summary()) do
        CS.Print(line)
      end
    end
  elseif cmd == "debug" then
    local sub, rest2 = (rest or ""):match("^(%S+)%s*(.*)$")
    sub = sub and sub:lower() or nil
    if sub == "events" then
      local mode = (rest2 or ""):match("^(%S+)")
      mode = mode and mode:lower() or "on"
      if not CrusaderStrikeDebugEvents then
        CS.Print("debug events unavailable")
        return
      end
      if mode == "on" then
        CrusaderStrikeDebugEvents.SetEnabled(true)
        CS.Print("debug events ON (buffer capped at 500). Enter a dungeon, kill a boss, then /cs debug events dump")
      elseif mode == "off" then
        CrusaderStrikeDebugEvents.SetEnabled(false)
        CS.Print("debug events OFF")
      elseif mode == "dump" then
        local summary = CrusaderStrikeDebugEvents.Summarize(60)
        for line in summary:gmatch("[^\n]+") do
          CS.Print(line)
        end
      elseif mode == "clear" then
        CrusaderStrikeDebugEvents.Clear()
        CS.Print("debug events cleared")
      else
        CS.Print("usage: /cs debug events [on|off|dump|clear]")
      end
    else
      CrusaderStrikeDB.settings.debug = not CrusaderStrikeDB.settings.debug
      CS.Print("debug=" .. tostring(CrusaderStrikeDB.settings.debug) .. " (use /cs debug events on for Forever event capture)")
    end
  elseif cmd == "loot" or cmd == "wishlist" or cmd == "wl" then
    if CS.LootBrowser and CS.LootBrowser.Show then
      local mapHint = rest and rest:match("^(%S+)")
      CS.LootBrowser.Show(mapHint)
    else
      CS.Print("loot browser unavailable")
    end
  else
    CS.Print("Commands: /cs loot | /cs wishlist | /cs export [key] | /cs status | /cs pvp | /cs debug | /cs debug events [on|off|dump]")
  end
end
