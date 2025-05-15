-- game.lua
local constants  = require "constants"
local Card       = require "Card"
local Pile       = require "Pile"
local utils      = require "utils"

local game = {}

-- Create a fresh game state; requires card dimensions to compute layout
function game.newGame(images, cardW, cardH)
  local state = {}
  state.piles       = {}
  state.tableaus    = {}
  state.foundations = {}
  state.discard     = {}
  state.moveCount   = 0
  state.startTime   = love.timer.getTime()

  local margin = (constants.SCREEN_W - 7 * cardW - 6 * 20) / 2
  local topY, tabY = 60, 220

  -- Stock and waste spots
  state.stock = Pile:new("stock", margin, topY)
  state.waste = Pile:new("waste", margin + cardW + 20, topY)
  table.insert(state.piles, state.stock)
  table.insert(state.piles, state.waste)

  -- Foundations
  for i = 1, 4 do
    local x = margin + (3 + i) * (cardW + 20)
    local f = Pile:new("foundation", x, topY)
    table.insert(state.foundations, f)
    table.insert(state.piles, f)
  end

  -- Tableaus
  for i = 1, 7 do
    local x = margin + (i - 1) * (cardW + 20)
    local t = Pile:new("tableau", x, tabY)
    table.insert(state.tableaus, t)
    table.insert(state.piles, t)
  end

  -- Build and shuffle deck
  local deck = {}
  for _, suit in ipairs(constants.SUITS) do
    for rank = 1, 13 do
      table.insert(deck, Card:new(suit, rank, images[suit][rank]))
    end
  end
  utils.shuffle(deck)

  -- Deal into tableaus
  for i, t in ipairs(state.tableaus) do
    for j = 1, i do
      local card = table.remove(deck)
      t:add(card)
      card.x = t.x
      local gap = (j == i) and constants.SPACING.tableauFaceUp or constants.SPACING.tableauFaceDown
      card.y = t.y + (j - 1) * gap
      if j == i then card.faceUp = true end
    end
  end

  -- Remainder to stock
  for _, card in ipairs(deck) do
    state.stock:add(card)
    card.x, card.y = state.stock.x, state.stock.y
  end

  return state
end

return game