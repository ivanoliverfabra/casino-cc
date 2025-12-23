--- @class UIComponent
--- @field x number
--- @field y number
--- @field type "button" | "label" | "box"

--- @class UIButton : UIComponent
--- @field w number
--- @field h number
--- @field text string
--- @field bg number
--- @field fg number
--- @field callback fun()

--- @class UILabel : UIComponent
--- @field text string
--- @field bg number
--- @field fg number

--- @class UIInstance
--- @field layer Layer
--- @field components UIComponent[]
local UI = {}
UI.__index = UI

local api = {}

function api.new(layer)
  local self = setmetatable({}, UI)
  self.layer = layer
  self.components = {}
  return self
end

function UI:addButton(x, y, w, h, text, bg, fg, callback)
  table.insert(self.components, {
    type = "button",
    x = math.floor(x),
    y = math.floor(y),
    w = math.floor(w),
    h = math.floor(h),
    text = text,
    bg = bg,
    fg = fg,
    callback = callback,
  })
end

function UI:addLabel(x, y, text, fg, bg)
  table.insert(self.components, {
    type = "label",
    x = math.floor(x),
    y = math.floor(y),
    text = text,
    fg = fg or colors.white,
    bg = bg or colors.transparent,
  })
end

function UI:addBox(x, y, w, h, color)
  table.insert(self.components, {
    type = "box",
    x = math.floor(x),
    y = math.floor(y),
    w = math.floor(w),
    h = math.floor(h),
    bg = color,
  })
end

function UI:clear()
  self.components = {}
end

function UI:render()
  for _, c in ipairs(self.components) do
    if c.type == "button" then
      local line = string.rep(" ", c.w)
      for i = 0, c.h - 1 do
        self.layer.text(c.x, c.y + i, line, c.bg, c.bg)
      end
      local tx = c.x + math.floor((c.w - #c.text) / 2)
      local ty = c.y + math.floor(c.h / 2)
      self.layer.text(tx, ty, c.text, c.fg, c.bg)
    elseif c.type == "label" then
      self.layer.text(c.x, c.y, c.text, c.fg, c.bg)
    elseif c.type == "box" then
      local line = string.rep(" ", c.w)
      for i = 0, c.h - 1 do
        self.layer.text(c.x, c.y + i, line, c.bg, c.bg)
      end
    end
  end
end

function UI:handleEvent(event, button, x, y)
  if event ~= "mouse_click" and event ~= "monitor_touch" then
    return
  end
  for _, c in ipairs(self.components) do
    if c.type == "button" then
      if x >= c.x and x < c.x + c.w and y >= c.y and y < c.y + c.h then
        c.callback()
        return true
      end
    end
  end
  return false
end

return api