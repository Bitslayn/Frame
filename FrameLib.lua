--[[
____  ___ __   __
| __|/ _ \\ \ / /
| _|| (_) |> w <
|_|  \___//_/ \_\
FOX's FrameLib v1.0.0
--]]

--#REGION ˚♡ Setup ♡˚

local cam = models:newPart("c", "Camera")
local mat = matrices.mat4(); mat.v44 = 0
local dis = cam:newPart("d"):matrix(mat)
local piv = dis:newPart("p"):setLight(15)

---@type SpriteTask[]
local sprites = {}

local function compat() -- PermissionsScreen in AvatarPreviewAPI
  local a = client.getScaledWindowSize()
  local b, c = a:unpack()
  local d = b / 2
  local e = math.min(d - 6, 208)
  local f = math.min(c - 95 - 13.5, e)
  local g = math.floor(11 * f / 29)
  local h = vec(math.max(d + (e - f) / 2 + 1, d + 2), 28)
  local i = h + f
  return g, h, i
end
local entitySize, topLeft, bottomRight = compat()


--#ENDREGION
--#REGION ˚♡ Draw ♡˚

---@param l FrameLayer
---@param left number
---@param top number
---@param right number
---@param bottom number
---@param parallax Vector3
local function draw(l, left, top, right, bottom, parallax)
  local sprite = sprites[l]
  sprite:visible(l.visible and l.order >= 0 and l.order <= 999)
  if not sprite:isVisible() then return end

  -- Animation

  local frames = sprite:getDimensions():div(l.size)
  if l.frametime ~= 0 then
    l.frame = world.getTime() * l.frametime % (frames.x * frames.y)
  end
  sprite:uv(
    l.frame % frames.x / frames.x,
    math.floor(l.frame / frames.x) / frames.y
  )

  -- Alignment & Parallax

  if l.maximized then
    left, top, right, bottom = 0, 0, client.getScaledWindowSize():unpack()
  end

  local offset = math.abs(l.parallax)
  left = left - offset
  top = top - offset
  right = right + offset
  bottom = bottom + offset

  -- Transformations

  local size, pos, scale
  if l.mode == "stretch" or l.mode == "grid" then
    size = vec(right - left, bottom - top)
    pos = vec(-left, -top, -l.order)
    scale = vec(1, 1)
  else
    local trueScale = l.mode == "fit" and (right - left) / l.size.x or (bottom - top) / l.size.y
    trueScale = trueScale * l.scale

    size = l.size
    pos = vec(
      math.lerp(-left, -right + (l.size.x * trueScale.x) * l.region.x, l.pan.x),
      math.lerp(-top, -bottom + (l.size.y * trueScale.y) * l.region.y, l.pan.y),
      -l.order
    )
    scale = trueScale
  end

  sprite:size(size)
      :pos(pos - parallax * l.parallax)
      :scale((scale * l.region):augmented(0))
      :region((l.mode == "stretch" and l.size or size) * l.region)
      :color(l.color)
end

--#ENDREGION
--#REGION ˚♡ Core ♡˚

---@class FrameLib
local api = {}

---The current screen the host is on, or "none" if this avatar's preview isn't rendering
---@type "none"|"wardrobe"|"wardrobe_maximized"|"permissions"|"permissions_maximized"
api.currentScreen = "none"

---@type FrameLayer[]
local layers, layerCount = {}, 0
---@type table<FrameLayer, boolean>
local q, lastDraw = {}, 0

local left, top, right, bottom = topLeft.x, topLeft.y, bottomRight.x, bottomRight.y
local center, parallax = vec(0, 0), vec(0, 0, 0)
local range = 1
local viewer = client.getViewer()
local timer = 0
function events.render(_, context)
  local isFiguraGUI = context == "FIGURA_GUI"
  cam:visible(isFiguraGUI)

  timer = timer - 1
  if timer < 0 then
    api.currentScreen = "none"
  end

  if not isFiguraGUI then return end
  timer = 2

  ---@class AvatarPreviewAPI
  local store = viewer:getVariable("AvatarPreviewAPI") or {}

  local scale = store.scale or entitySize
  piv:scale(16 / scale)
  parallax = (center - (client.getMousePos() / client.getGuiScale())):augmented(0) / range

  if lastDraw == store.draw then
    for l in pairs(q) do
      draw(l, left, top, right, bottom, parallax)
      local priority = l.frametime ~= 0 or l.parallax ~= 0
      q[l] = priority
    end
    api.currentScreen = store.screen
    return
  end
  lastDraw = store.draw

  left = store.left or left
  top = store.top or top
  right = store.right or right
  bottom = store.bottom or bottom
  center = vec((left + right) / 2, (top + bottom) / 2)
  local retnec = -(center - client.getScaledWindowSize())
  range = math.max(center.x, center.y, retnec.x, retnec.y)

  for _, l in pairs(layers) do
    draw(l, left, top, right, bottom, parallax)
  end
end

--#ENDREGION
--#REGION ˚♡ API ♡˚

---@type FrameLayer[]
local binds = {}
local meta = {
  __index = function(s, k) return binds[s][k] end,
  __newindex = function(s, k, v)
    local l = binds[s]
    l[k] = v
    q[l] = true
  end,
  __type = "FrameLayer",
}

---Creates a new layer
---@param texture Texture
---@param name string? The layer's name, automatically gets set to layerN if none is set. This is the name you'd use when removing layers
---@param cfg FrameLayer?
---@return FrameLayer
function api.newLayer(texture, name, cfg)
  if type(texture) ~= "Texture" then error("Invalid texture", 2) end
  if name and type(name) ~= "string" then error("Layer name must be a string") end
  if cfg and type(cfg) ~= "table" then error("cfg parameter must be a table", 2) end

  layerCount = layerCount + 1
  if name then
    if layers[name] then
      error(("A layer with the name %s already exists"):format(name), 2)
    end
  else
    name = "layer" .. tostring(layerCount)
  end

  local size = texture:getDimensions()
  local sprite = piv:newSprite(name)
      :texture(texture)
      :dimensions(size)
      :region(size)
      :size(size)

  ---@alias FrameMode
  ---| "fill" The default mode, makes the entire texture fit vertically, cropping out the edges
  ---| "fit" Makes the entire texture fit horizontally
  ---| "stretch" Stretches the texture corners to fit the screen or preview
  ---| "grid" Repeats the texture infinitely to fit the screen or preview
  ---@class FrameLayer
  ---@field visible boolean? `true` - Whether this layer should render
  ---@field maximized boolean? `false` - If this layer should be forced to render expanded
  ---@field order number? `0` - The layer's z position
  ---@field pan Vector2? `vec(0.5, 0.5)` - The layer's relative position
  ---@field scale Vector2? `vec(1, 1)` - The layer's scale
  ---@field parallax number? `0` - The parallax effect intensity in pixels
  ---@field mode FrameMode? `"fill"` - A string which sets how the texture should be fitted
  ---@field size Vector2? The size of the texture. Not to be confused with layer scale. This is used for animations
  ---@field region Vector2? `vec(1, 1)` - Repeats the texture in a direction n times. Takes fractional numbers
  ---@field frame number? `0` - The current frame number, starts at 0 as the first frame, 1 for the second and so on. Frames are in row-column order, counting all sprites in a row before going to the next row
  ---@field frametime number? `0` - How long to display each frame in ticks
  ---@field color Vector3? `vec(1, 1, 1)` - The color to apply to the layer's texture
  local l = {
    visible = true,
    maximized = false,

    order = 0,
    pan = vec(0.5, 0.5),
    scale = vec(1, 1),
    parallax = 0,

    mode = "fill",
    size = size,
    region = vec(1, 1),

    frame = 0,
    frametime = 0,

    color = vec(1, 1, 1),
  }
  for k, v in pairs(cfg or {}) do l[k] = v end
  q[l] = true

  layers[name] = l
  local proxy = {}
  binds[proxy] = l
  sprites[l] = sprite

  return setmetatable(proxy, meta)
end

---Remove a layer by name
---@param name string
function api.removeLayer(name)
  q[layers[name]] = nil
  sprites[layers[name]]:remove()
  layers[name] = nil
end

---Returns a layer by name
---@return FrameLayer
function api.getLayer(name)
  return layers[name]
end

return api

--#ENDREGION
