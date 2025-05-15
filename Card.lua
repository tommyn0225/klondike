-- Card.lua
local Card = {}
Card.__index = Card

function Card:new(suit, rank, img)
  return setmetatable({
    suit   = suit,
    rank   = rank,
    img    = img,
    faceUp = false,
    x = 0, y = 0,
    pile = nil,
  }, Card)
end

function Card:draw()
  local texture = self.faceUp and self.img or CARD_BACK
  love.graphics.draw(texture, self.x, self.y)
end

return Card