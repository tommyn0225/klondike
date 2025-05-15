-- Pile.lua
local Pile = {}
Pile.__index = Pile

function Pile:new(kind, x, y)
  return setmetatable({ kind = kind, x = x, y = y, cards = {} }, Pile)
end

function Pile:top()
  return self.cards[#self.cards]
end

function Pile:isEmpty()
  return #self.cards == 0
end

function Pile:add(card)
  table.insert(self.cards, card)
  card.pile = self
end

function Pile:removeFrom(card)
  local idx
  for i, c in ipairs(self.cards) do
    if c == card then idx = i break end
  end
  local moved = {}
  for i = idx, #self.cards do
    table.insert(moved, self.cards[i])
  end
  for i = #self.cards, idx, -1 do
    self.cards[i] = nil
  end
  return moved
end

function Pile:draw()
  if self.kind == "tableau" then
    for _, c in ipairs(self.cards) do c:draw() end
  elseif self.kind == "waste" then
    local n = #self.cards
    for i = math.max(1, n - 2), n do
      self.cards[i]:draw()
    end
  else
    local top = self:top()
    if top then
      top:draw()
    else
      love.graphics.setColor(0, 0, 0, 0.25)
      love.graphics.rectangle("line", self.x, self.y, CARD_W, CARD_H, 6, 6)
      love.graphics.setColor(1, 1, 1)
    end
  end
end

return Pile