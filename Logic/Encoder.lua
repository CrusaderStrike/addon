-- Versioned export-string encode/decode (pure Lua 5.1).
-- Format: CSRUN1:<base64(payloadJson)>
-- Payload is a compact JSON object (see docs/run-schema.md).

CrusaderStrikeEncoder = CrusaderStrikeEncoder or {}

local PREFIX = "CSRUN1:"

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function to_binary_string(n, bits)
  local t = {}
  for i = bits, 1, -1 do
    t[#t + 1] = math.floor(n / 2 ^ (i - 1)) % 2
  end
  return table.concat(t)
end

local function from_binary_string(s)
  local n = 0
  for i = 1, #s do
    n = n * 2 + (s:sub(i, i) == "1" and 1 or 0)
  end
  return n
end

function CrusaderStrikeEncoder.Base64Encode(data)
  local bitstr = {}
  for i = 1, #data do
    bitstr[#bitstr + 1] = to_binary_string(data:byte(i), 8)
  end
  local bits = table.concat(bitstr)
  local pad = (6 - (#bits % 6)) % 6
  bits = bits .. string.rep("0", pad)
  local out = {}
  for i = 1, #bits, 6 do
    local chunk = bits:sub(i, i + 5)
    out[#out + 1] = B64:sub(from_binary_string(chunk) + 1, from_binary_string(chunk) + 1)
  end
  local padding = (4 - (#out % 4)) % 4
  for _ = 1, padding do
    out[#out + 1] = "="
  end
  return table.concat(out)
end

function CrusaderStrikeEncoder.Base64Decode(data)
  data = data:gsub("%s", ""):gsub("=", "")
  local bitstr = {}
  for i = 1, #data do
    local c = data:sub(i, i)
    local idx = B64:find(c, 1, true)
    if not idx then
      return nil, "invalid base64"
    end
    bitstr[#bitstr + 1] = to_binary_string(idx - 1, 6)
  end
  local bits = table.concat(bitstr)
  local out = {}
  for i = 1, #bits - 7, 8 do
    out[#out + 1] = string.char(from_binary_string(bits:sub(i, i + 7)))
  end
  return table.concat(out)
end

-- Minimal JSON encoder for our schema (numbers, strings, bools, arrays, objects).
local function json_escape(s)
  s = s:gsub("\\", "\\\\")
  s = s:gsub('"', '\\"')
  s = s:gsub("\n", "\\n")
  s = s:gsub("\r", "\\r")
  s = s:gsub("\t", "\\t")
  return s
end

-- JSON null sentinel (distinct from Lua nil so object keys survive ToJson).
-- Use for CSGEAR1 wire fields that must emit explicit null (character_id, id,
-- until_level on max_level, role_spec). Decode still yields Lua nil.
CrusaderStrikeEncoder.Null = CrusaderStrikeEncoder.Null or {}

local OBJECT_MT = { __jsontype = "object" }

-- Force empty/non-empty maps to encode as {} not [] (Lua empty tables are ambiguous).
function CrusaderStrikeEncoder.AsObject(t)
  if type(t) ~= "table" then
    t = {}
  end
  return setmetatable(t, OBJECT_MT)
end

local function is_array(t)
  local mt = getmetatable(t)
  if mt and mt.__jsontype == "object" then
    return false
  end
  if mt and mt.__jsontype == "array" then
    return true
  end
  local n = 0
  for k, _ in pairs(t) do
    if type(k) ~= "number" then
      return false
    end
    if k > n then
      n = k
    end
  end
  return n == #t
end

function CrusaderStrikeEncoder.ToJson(value)
  local tv = type(value)
  if value == nil or value == CrusaderStrikeEncoder.Null then
    return "null"
  elseif tv == "boolean" then
    return value and "true" or "false"
  elseif tv == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      return "null"
    end
    -- Prefer integers when whole.
    if value == math.floor(value) then
      return string.format("%d", value)
    end
    return tostring(value)
  elseif tv == "string" then
    return '"' .. json_escape(value) .. '"'
  elseif tv == "table" then
    if is_array(value) then
      local parts = {}
      for i = 1, #value do
        parts[i] = CrusaderStrikeEncoder.ToJson(value[i])
      end
      return "[" .. table.concat(parts, ",") .. "]"
    else
      local parts = {}
      local keys = {}
      for k in pairs(value) do
        if type(k) == "string" then
          keys[#keys + 1] = k
        end
      end
      table.sort(keys)
      for _, k in ipairs(keys) do
        parts[#parts + 1] = '"' .. json_escape(k) .. '":' .. CrusaderStrikeEncoder.ToJson(value[k])
      end
      return "{" .. table.concat(parts, ",") .. "}"
    end
  end
  return "null"
end

-- Tiny JSON decoder sufficient for round-trip of our payloads.
local function decode_error(msg, i)
  return nil, msg .. " at " .. tostring(i)
end

function CrusaderStrikeEncoder.FromJson(str)
  if type(str) ~= "string" then
    return nil, "not a string"
  end
  local i = 1
  local n = #str

  local function peek()
    return str:sub(i, i)
  end

  local function skip_ws()
    while i <= n and str:sub(i, i):match("%s") do
      i = i + 1
    end
  end

  local parse_value

  local function parse_string()
    if peek() ~= '"' then
      return decode_error("expected string", i)
    end
    i = i + 1
    local buf = {}
    while i <= n do
      local c = str:sub(i, i)
      if c == '"' then
        i = i + 1
        return table.concat(buf)
      elseif c == "\\" then
        local n2 = str:sub(i + 1, i + 1)
        local map = { n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\" }
        buf[#buf + 1] = map[n2] or n2
        i = i + 2
      else
        buf[#buf + 1] = c
        i = i + 1
      end
    end
    return decode_error("unterminated string", i)
  end

  local function parse_number()
    local s, e = str:find("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", i)
    if not s then
      return decode_error("bad number", i)
    end
    local num = tonumber(str:sub(s, e))
    i = e + 1
    return num
  end

  local function parse_array()
    i = i + 1 -- [
    skip_ws()
    local arr = {}
    if peek() == "]" then
      i = i + 1
      return arr
    end
    while true do
      local v, err = parse_value()
      if err then
        return nil, err
      end
      arr[#arr + 1] = v
      skip_ws()
      local c = peek()
      if c == "]" then
        i = i + 1
        return arr
      elseif c == "," then
        i = i + 1
        skip_ws()
      else
        return decode_error("expected , or ]", i)
      end
    end
  end

  local function parse_object()
    i = i + 1 -- {
    skip_ws()
    local obj = {}
    if peek() == "}" then
      i = i + 1
      return obj
    end
    while true do
      skip_ws()
      local key, err = parse_string()
      if err then
        return nil, err
      end
      skip_ws()
      if peek() ~= ":" then
        return decode_error("expected :", i)
      end
      i = i + 1
      skip_ws()
      local val, err2 = parse_value()
      if err2 then
        return nil, err2
      end
      obj[key] = val
      skip_ws()
      local c = peek()
      if c == "}" then
        i = i + 1
        return obj
      elseif c == "," then
        i = i + 1
      else
        return decode_error("expected , or }", i)
      end
    end
  end

  parse_value = function()
    skip_ws()
    local c = peek()
    if c == '"' then
      return parse_string()
    elseif c == "{" then
      return parse_object()
    elseif c == "[" then
      return parse_array()
    elseif c == "t" and str:sub(i, i + 3) == "true" then
      i = i + 4
      return true
    elseif c == "f" and str:sub(i, i + 4) == "false" then
      i = i + 5
      return false
    elseif c == "n" and str:sub(i, i + 3) == "null" then
      i = i + 4
      return nil
    elseif c == "-" or c:match("%d") then
      return parse_number()
    end
    return decode_error("unexpected char", i)
  end

  local value, err = parse_value()
  if err then
    return nil, err
  end
  skip_ws()
  if i <= n then
    return decode_error("trailing junk", i)
  end
  return value
end

function CrusaderStrikeEncoder.EncodeRun(runTable)
  local json = CrusaderStrikeEncoder.ToJson(runTable)
  return PREFIX .. CrusaderStrikeEncoder.Base64Encode(json)
end

function CrusaderStrikeEncoder.DecodeExport(exportString)
  if type(exportString) ~= "string" then
    return nil, "not a string"
  end
  exportString = exportString:gsub("^%s+", ""):gsub("%s+$", "")
  if exportString:sub(1, #PREFIX) ~= PREFIX then
    return nil, "missing CSRUN1: prefix"
  end
  local b64 = exportString:sub(#PREFIX + 1)
  local json, err = CrusaderStrikeEncoder.Base64Decode(b64)
  if not json then
    return nil, err or "base64 decode failed"
  end
  return CrusaderStrikeEncoder.FromJson(json)
end

CrusaderStrikeEncoder.PREFIX = PREFIX
