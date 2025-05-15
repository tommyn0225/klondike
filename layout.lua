-- layout.lua
local layout = {}
local constants = require "constants"

function layout.layoutTableau(pile)
  for i, c in ipairs(pile.cards) do
    c.x = pile.x
    local gap = c.faceUp and constants.SPACING.tableauFaceUp or constants.SPACING.tableauFaceDown
    c.y = pile.y + gap * (i - 1)
  end
end

function layout.layoutWaste(waste)
  local n = #waste.cards
  for i, c in ipairs(waste.cards) do
    local slot = i - (n - 2)
    c.x = waste.x + (slot - 1) * constants.SPACING.wasteFanX
    c.y = waste.y
  end
end

return layout