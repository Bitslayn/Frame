--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's Avatar Preview API

This script is required for most functionality of scripts that depend on it to work.
It is required on host, even if you don't use FrameLib

This script does not need to be uploaded with your avatar.
It can be saved to your data folder.
--]]

if not host:isHost() then return end

--#REGION ˚♡ Screens ♡˚
-- Snippets taken directly from Figura source code

local screens = {
  WardrobeScreen = function()
    local size = client.getScaledWindowSize()
    local width, height = size:unpack()

    local middle = width / 2
    local panels = math.min(width / 3, 256) - 8

    local modelBgSize = math.min(width - panels * 2 - 16, height - 96)

    local entitySize = math.floor(11 * modelBgSize / 29)
    local topLeft = vec(middle - modelBgSize / 2, height / 2 - modelBgSize / 2)
    local bottomRight = topLeft + modelBgSize

    return entitySize, topLeft, bottomRight, "wardrobe"
  end,
  PermissionsScreen = function()
    local size = client.getScaledWindowSize()
    local width, height = size:unpack()

    local middle = width / 2
    local listWidth = math.min(middle - 6, 208)
    local lineHeight = 9

    local entitySize = math.min(height - 95 - lineHeight * 1.5, listWidth)
    local modelSize = math.floor(11 * entitySize / 29)
    local topLeft = vec(math.max(middle + (listWidth - entitySize) / 2 + 1, middle + 2), 28)
    local bottomRight = topLeft + entitySize

    return modelSize, topLeft, bottomRight, "permissions"
  end,
}

local screenId = "PermissionsScreen"
function screens.AvatarScreen()
  assert(screenId ~= "AvatarScreen", "Stack overflow")
  return screens[screenId](), vec(0, 0), client.getScaledWindowSize(),
      screenId:lower():match("(.-)screen") .. "_maximized"
end

--#ENDREGION
--#REGION ˚♡ Resetting ♡˚

---@class AvatarPreviewAPI
---@field scale number The host's zoom in the avatar preview
---@field draw number The world time the window was last refreshed. This changes whenever the window gets resized, or the page has changed
---@field left number The avatar preview's left bound
---@field top number The avatar preview's top bound
---@field right number The avatar preview's right bound
---@field bottom number The avatar preview's bottom bound
---@field screen string The very short snake case screen the host is on
local store = {}
avatar:store("AvatarPreviewAPI", store)

local scale, scaledValue = 0, 0
local screen = screens[screenId]
local topLeft, bottomRight = vec(0, 0), vec(0, 0)
local newId
local function draw()
  local lastScreenId = screenId
  screenId = string.match(host:getScreen() or "", "screens%.(.*)")
  screen = screens[screenId]
  screenId = screenId ~= "AvatarScreen" and screenId or lastScreenId
  if not screen then return end

  scaledValue = 0
  scale, topLeft, bottomRight, newId = screen()
  store.scale = scale
  store.draw = world.getTime()
  store.left = topLeft.x
  store.top = topLeft.y
  store.right = bottomRight.x
  store.bottom = bottomRight.y
  store.screen = newId
end

local w, s
function events.tick()
  local _w, _s = client.getWindowSize(), host:getScreen()
  if w ~= _w or s ~= _s then
    w, s = _w, _s
    draw()
  end
end

--#ENDREGION
--#REGION ˚♡ Mouse ♡˚

---Returns if x is inside a and b
---@param a Vector2
---@param b Vector2
---@param x Vector2
local function inside(a, b, x)
  return a.x <= x.x and x.x <= b.x and a.y <= x.y and x.y <= b.y
end

function events.mouse_scroll(amount)
  if not inside(topLeft, bottomRight, client.getMousePos() / client.getGuiScale()) then return end

  amount = (amount > 0) and 1.1 or 1 / 1.1
  scaledValue = ((scale + scaledValue) * amount) - scale
  store.scale = scale + scaledValue
end

---@diagnostic disable-next-line: redefined-local
function events.mouse_press(button, state)
  if button ~= 2 or state ~= 1 then return end
  if not inside(topLeft, bottomRight, client.getMousePos() / client.getGuiScale()) then return end
  draw()
end

--#ENDREGION
