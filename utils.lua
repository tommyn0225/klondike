-- utils.lua
local constants = require "constants"
local utils = {}

-- Fisher–Yates shuffle
default_random = nil -- placeholder to avoid global noise
function utils.shuffle(t)
  for i = #t, 2, -1 do
    local j = love.math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

function utils.isRed(suit)
  return constants.RED_SUITS[suit]
end

function utils.isOppositeColor(a, b)
  return utils.isRed(a) ~= utils.isRed(b)
end

-- Load all card images and return images table, back image, width, height
function utils.loadImages()
  local images = {}
  for _, suit in ipairs(constants.SUITS) do
    images[suit] = {}
    for rank = 1, 13 do
      images[suit][rank] = love.graphics.newImage(
        ("assets/cards/card-%s-%d.png"):format(suit, rank)
      )
    end
  end
  local cardBack = love.graphics.newImage("assets/cards/card-back1.png")
  local cardW, cardH = cardBack:getWidth(), cardBack:getHeight()
  return images, cardBack, cardW, cardH
end

return utils