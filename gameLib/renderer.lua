--- @class Renderer
local api = {}

local CARD_W = 11
local CARD_H = 12
local STACK_OFFSET = 3 
local GAP_OFFSET = 12   

--- @param layer Layer
local function drawRoundedCardBody(layer, tx, ty, tw, th, color)
  if not layer or not layer.pixel then return end -- Safety check
  
  local x = (tx - 1) * 2 + 1
  local y = (ty - 1) * 3 + 1
  local w = tw * 2
  local h = th * 3

  -- Body
  for py = y + 1, y + h - 2 do
    for px = x, x + w - 1 do 
        layer.pixel(px, py, color) 
    end
  end
  -- Corners
  for px = x + 1, x + w - 2 do
    layer.pixel(px, y, color)
    layer.pixel(px, y + h - 1, color)
  end
end

--- @param layers {pixel: Layer, text: Layer}
function api.drawCard(layers, x, y, card, isFaceDown)
  if not layers or not layers.pixel or not layers.text then return end

  if isFaceDown then
    drawRoundedCardBody(layers.pixel, x, y, CARD_W, CARD_H, colors.blue)
    layers.text.text(x + 4, y + 4, "???", colors.white, colors.blue)
    return
  end

  local suitColor = (card.suit.name == "Hearts" or card.suit.name == "Diamonds") 
                    and colors.red or colors.black
  
  drawRoundedCardBody(layers.pixel, x, y, CARD_W, CARD_H, colors.white)

  local rank = card.rank == "10" and "10" or card.rank:sub(1, 1)
  local sym = card.suit.symbol

  layers.text.text(x + 1, y + 1, rank, suitColor, colors.white)
  layers.text.text(x + 1, y + 2, sym, suitColor, colors.white)
  layers.text.text(x + 5, y + 4, sym, suitColor, colors.white)
  layers.text.text(x + CARD_W - 2, y + CARD_H - 2, rank, suitColor, colors.white)
  layers.text.text(x + CARD_W - 2, y + CARD_H - 3, sym, suitColor, colors.white)
end

--- @param layerPool table
function api.drawHand(layerPool, x, y, hand, options)
  local offset = options.overlay and STACK_OFFSET or GAP_OFFSET
  local startIdx = (options.layerOffset or 0)
  
  for i, card in ipairs(hand.cards) do
    local xPos = x + ((i - 1) * offset)
    -- Important: Match index to the pool
    local currentLayers = layerPool[i + startIdx]
    
    if currentLayers then
        api.drawCard(currentLayers, xPos, y, card, i == 1 and options.hideFirst)
    end
  end
end

return api