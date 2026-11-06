-- Single source of truth for the CS character tab layout.
-- Anchors are relative to the paper doll or the side pane, not the screen.
-- GearTab.lua builds the doll, slots, and panes from this table.

CrusaderStrikeGearLayout = CrusaderStrikeGearLayout or {}
local L = CrusaderStrikeGearLayout

-- The CS content frame can grow with CharacterFrame when the native right
-- pane opens. The doll is centered in mainPane, which tracks LeftPaneHost
-- (fixed width, Forever CharacterFrame.xml) and does not include RightPaneHost.
L.panes = {
  main = {
    frame = "CrusaderStrikeGearMainPane",
    owns = { "doll" },
  },
  side = {
    frame = "CrusaderStrikeGearPopout",
    -- Used only when CharacterFrame.RightPaneHost is missing.
    width = 177,
    -- Forever CharacterFrame.xml RightPaneHost width.
    hostWidth = 233,
    owns = { "iconRow", "sets", "browser", "stats" },
    -- Fills the native right pane so the pop-out center is that pane's center.
    anchorToRightPane = {
      { point = "TOPLEFT", rel = "rightPane", relPoint = "TOPLEFT", x = 0, y = 0 },
      { point = "BOTTOMRIGHT", rel = "rightPane", relPoint = "BOTTOMRIGHT", x = 0, y = 0 },
    },
    -- Fallback: hang off the doll's right edge.
    anchor = {
      { point = "TOPLEFT", rel = "doll", relPoint = "TOPRIGHT", x = 0, y = 0 },
      { point = "BOTTOMLEFT", rel = "doll", relPoint = "BOTTOMRIGHT", x = 0, y = 0 },
    },
  },
}

-- Forever CharacterFrame.xml: LeftPaneHost is 398 wide and stays put when
-- RightPaneHost (233) is shown or hidden.
L.mainPane = {
  frame = "CrusaderStrikeGearMainPane",
  width = 398,
  -- Prefer filling CharacterFrame.LeftPaneHost. Otherwise pin the left edge
  -- of the CS content frame and keep this fixed width.
  anchorToLeftPane = {
    { point = "TOPLEFT", rel = "leftPane", relPoint = "TOPLEFT", x = 0, y = 0 },
    { point = "BOTTOMRIGHT", rel = "leftPane", relPoint = "BOTTOMRIGHT", x = 0, y = 0 },
  },
  anchorFixed = {
    { point = "TOPLEFT", rel = "root", relPoint = "TOPLEFT", x = 0, y = 0 },
    { point = "BOTTOMLEFT", rel = "root", relPoint = "BOTTOMLEFT", x = 0, y = 0 },
  },
}

-- Paper doll is centered in mainPane, not in the full CharacterFrame.
L.doll = {
  parent = "mainPane",
  width = 338,
  height = 424,
  anchor = { point = "CENTER", rel = "mainPane", relPoint = "CENTER", x = 0, y = 0 },
}

L.slotSize = 37

-- Forever PaperDollItemSlotButton*Template draws these from
-- Interface\CharacterFrame\Char-Paperdoll-Parts (CharacterFrame.xml).
-- Left column uses Char-LeftSlot, right column Char-RightSlot, weapon row
-- Char-BottomSlot. Tex coords and sizes match that file.
L.slotBorder = {
  file = "Interface\\CharacterFrame\\Char-Paperdoll-Parts",
  left = {
    w = 49, h = 44,
    coords = { 0.20703125, 0.39843750, 0.59375000, 0.93750000 },
    point = "TOPLEFT", x = -4, y = 0,
  },
  right = {
    w = 50, h = 44,
    coords = { 0.00390625, 0.19921875, 0.59375000, 0.93750000 },
    point = "TOPRIGHT", x = 4, y = 0,
  },
  bottom = {
    w = 42, h = 53,
    coords = { 0.67187500, 0.83593750, 0.00781250, 0.42187500 },
    point = "TOPLEFT", x = -4, y = 8,
  },
}

-- Columns are ordered lists anchored to the doll. `step` is the distance
-- from one slot to the next along that column. Offsets are doll-relative.
L.columns = {
  {
    name = "left",
    point = "TOPLEFT",
    relPoint = "TOPLEFT",
    x = 21,
    y = -76,
    step = 41,
    slots = { "head", "neck", "shoulder", "back", "chest", "shirt", "tabard", "wrist" },
  },
  {
    name = "right",
    point = "TOPRIGHT",
    relPoint = "TOPRIGHT",
    x = -21,
    y = -76,
    step = 41,
    slots = { "hands", "waist", "legs", "feet", "finger1", "finger2", "trinket1", "trinket2" },
  },
}

-- Weapon row along the bottom of the doll: main, off, ranged, ammo.
L.weaponRow = {
  point = "BOTTOMLEFT",
  relPoint = "BOTTOMLEFT",
  x = 122,
  y = 20,
  gap = 5,
  slots = { "main_hand", "off_hand", "ranged", "ammo" },
}

-- The side pane follows Blizzard's CharacterFrame right-pane toggle.
-- Frame: CharacterFrameRightPaneToggleButton (parentKey RightPaneToggleButton).
-- Click calls CharacterFrame:ToggleRightPane -> SetRightPaneCollapsed.
-- Collapsed state is CharacterFrame:IsRightPaneCollapsed (CVar characterFrameCollapsed).
-- The addon only observes that; it does not create its own toggle button.
L.nativeSideToggle = {
  frame = "CharacterFrameRightPaneToggleButton",
  parentKey = "RightPaneToggleButton",
  owner = "CharacterFrame",
  toggle = "ToggleRightPane",
  set = "SetRightPaneCollapsed",
  query = "IsRightPaneCollapsed",
}

L.iconRow = {
  parent = "side",
  height = 35,
  gap = 4,
  tabW = 33,
  tabH = 35,
  -- No extra right inset: the row is only as wide as the three buttons and
  -- its top-center sits on the pop-out's top-center.
  rightInset = 0,
  width = (33 * 3) + (4 * 2),
  points = {
    { point = "TOP", rel = "side", relPoint = "TOP", x = 0, y = -4 },
  },
}

-- Sets, Browser, and Stats sit under the icon row. Left and right insets match
-- so each panel's horizontal center is the pop-out's center.
L.panels = {
  sets = { parent = "side" },
  browser = { parent = "side", align = "center" },
  stats = { parent = "side" },
  content = {
    inset = 0,
    points = {
      { point = "TOP", rel = "iconRow", relPoint = "BOTTOM", x = 0, y = -4 },
      { point = "LEFT", rel = "side", relPoint = "LEFT", x = 0, y = 0 },
      { point = "RIGHT", rel = "side", relPoint = "RIGHT", x = 0, y = 0 },
      { point = "BOTTOM", rel = "side", relPoint = "BOTTOM", x = 0, y = 0 },
    },
  },
}

-- Empty art for the wire slot `ranged`. Ammo stays the PaperDoll ammo slot
-- and is only shown for hunter, warrior, and rogue.
--
-- Texture choices (Classic / Forever client paths):
--   * Hunter, warrior, rogue: Interface\PaperDoll\UI-PaperDoll-Slot-Ranged
--     (the bow empty-slot art).
--   * Druid: Interface\PaperDoll\UI-PaperDoll-Slot-Relic (relic empty slot).
--     There is no separate idol paperdoll texture.
--   * Shaman: Interface\Icons\Spell_Nature_SlowingTotem. No
--     UI-PaperDoll-Slot-Totem exists; this is a vanilla totem icon.
--   * Paladin: Interface\Icons\INV_Misc_Book_11. No libram paperdoll slot
--     texture; this is a vanilla book icon used as the libram empty art.
--   * Priest, mage, warlock: Interface\Icons\INV_Wand_01. The paperdoll
--     ranged slot is a bow, so the wand uses a vanilla wand item icon.
L.rangedByClass = {
  HUNTER = { label = "Ranged", empty = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged", ammo = true },
  WARRIOR = { label = "Ranged", empty = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged", ammo = true },
  ROGUE = { label = "Ranged", empty = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ranged", ammo = true },
  DRUID = { label = "Relic", empty = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Relic", ammo = false },
  SHAMAN = { label = "Totem", empty = "Interface\\Icons\\Spell_Nature_SlowingTotem", ammo = false },
  PALADIN = { label = "Libram", empty = "Interface\\Icons\\INV_Misc_Book_11", ammo = false },
  PRIEST = { label = "Wand", empty = "Interface\\Icons\\INV_Wand_01", ammo = false },
  MAGE = { label = "Wand", empty = "Interface\\Icons\\INV_Wand_01", ammo = false },
  WARLOCK = { label = "Wand", empty = "Interface\\Icons\\INV_Wand_01", ammo = false },
}

L.ammoEmpty = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Ammo"

function L.RangedFor(classToken)
  if type(classToken) == "string" then
    local row = L.rangedByClass[classToken:upper()]
    if row then
      return row
    end
  end
  return L.rangedByClass.HUNTER
end
