#!/usr/bin/env lua
-- Minimal test runner (busted-like asserts). Lua 5.1-compatible.

local addon_root = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
addon_root = addon_root:gsub("tests/$", "")

package.path = addon_root .. "?.lua;"
  .. addon_root .. "?/init.lua;"
  .. addon_root .. "Logic/?.lua;"
  .. addon_root .. "Data/?.lua;"
  .. addon_root .. "tests/?.lua;"
  .. package.path

dofile(addon_root .. "tests/mock_wow.lua")

-- Load pure modules directly (no CreateFrame side effects needed for most tests)
dofile(addon_root .. "Data/Bosses.lua")
dofile(addon_root .. "Data/Loot.lua")
dofile(addon_root .. "Logic/Idempotency.lua")
dofile(addon_root .. "Logic/Encoder.lua")
dofile(addon_root .. "Logic/RunLifecycle.lua")
dofile(addon_root .. "Logic/PvpHistory.lua")
dofile(addon_root .. "Logic/Detection.lua")
dofile(addon_root .. "Logic/DebugEvents.lua")
dofile(addon_root .. "Logic/WishList.lua")
dofile(addon_root .. "Logic/GearSlots.lua")
dofile(addon_root .. "Logic/GearEncoder.lua")
dofile(addon_root .. "Logic/EquippedGear.lua")
dofile(addon_root .. "Logic/GearSets.lua")

local passed, failed = 0, 0
local current = "?"

local function ok(cond, msg)
  if cond then
    passed = passed + 1
    io.write(".")
  else
    failed = failed + 1
    io.write("F")
    io.stderr:write(string.format("\nFAIL [%s] %s\n", current, msg or "assertion failed"))
  end
end

local function eq(a, b, msg)
  if a == b then
    ok(true, msg)
  else
    ok(false, (msg or "eq") .. string.format(" expected %s got %s", tostring(b), tostring(a)))
  end
end

_G.describe = function(name, fn)
  current = name
  fn()
end

_G.it = function(name, fn)
  current = name
  local co = coroutine.create(fn)
  local okc, err = coroutine.resume(co)
  if not okc then
    failed = failed + 1
    io.write("E")
    io.stderr:write(string.format("\nERROR [%s] %s\n", name, tostring(err)))
  end
end

_G.assert = assert
_G.eq = eq
_G.ok = ok

local files = {
  "test_idempotency.lua",
  "test_encoder.lua",
  "test_lifecycle.lua",
  "test_bosses.lua",
  "test_pvp.lua",
  "test_pvp_events.lua",
  "test_detection.lua",
  "test_wishlist.lua",
  "test_gear.lua",
  "test_simulate.lua",
}

-- Load frame-facing modules for handler tests (CreateFrame stubbed in mock_wow).
dofile(addon_root .. "Core.lua")
dofile(addon_root .. "DungeonLog.lua")
dofile(addon_root .. "LootBrowser.lua")
dofile(addon_root .. "GearSetsUI.lua")
dofile(addon_root .. "DebugSimulate.lua")
dofile(addon_root .. "Export.lua")

io.write("CrusaderStrike tests (Lua " .. _VERSION .. ")\n")
for _, f in ipairs(files) do
  dofile(addon_root .. "tests/" .. f)
end
io.write(string.format("\n%d passed, %d failed\n", passed, failed))
os.exit(failed == 0 and 0 or 1)
