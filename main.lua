-- main.lua
local constants = require "constants"
local utils     = require "utils"
local Card      = require "Card"
local Pile      = require "Pile"
local layout    = require "layout"
local game      = require "game"

-- Globals for assets and state
local images, CARD_BACK, CARD_W, CARD_H
local state, dragging, hudFont, btnNewGame

-- Game rule checks
local function canPlaceOnTableau(c, d)
  if d then
    return c.rank == d.rank - 1 and utils.isOppositeColor(c.suit, d.suit)
  else
    return c.rank == 13
  end
end

local function canPlaceOnFoundation(c, d)
  if d then
    return c.suit == d.suit and c.rank == d.rank + 1
  else
    return c.rank == 1
  end
end

-- Preview check without mutating
local function canPlace(stack, dest)
  local first = stack[1]
  if dest.kind == "tableau" then
    return canPlaceOnTableau(first, dest:top())
  elseif dest.kind == "foundation" and #stack == 1 then
    return canPlaceOnFoundation(first, dest:top())
  end
  return false
end

-- Helpers for mouse interaction
local function isOverHeader(p, x, y)
  -- p may be pile or button
  if p.w and p.h then
    return x >= p.x and x <= p.x + p.w and y >= p.y and y <= p.y + p.h
  else
    return x >= p.x and x <= p.x + CARD_W and y >= p.y and y <= p.y + CARD_H
  end
end

local function isOverPile(p, x, y)
  if x < p.x or x > p.x + CARD_W then return false end
  if p.kind == "tableau" then
    local bottom = (#p.cards == 0 and p.y + CARD_H) or (p:top().y + CARD_H)
    return y >= p.y and y <= bottom
  else
    return y >= p.y and y <= p.y + CARD_H
  end
end

local function findCard(x, y)
  for i = #state.piles, 1, -1 do
    local p = state.piles[i]
    local stack = (p.kind == "tableau" or p.kind == "waste") and p.cards or {p:top()}
    for j = #stack, 1, -1 do
      local c = stack[j]
      if c and c.faceUp
         and x >= c.x and x <= c.x + CARD_W
         and y >= c.y and y <= c.y + CARD_H then
        return c
      end
    end
  end
end

local function tryPlace(stack, dest)
  if dest.kind == "tableau" then
    if canPlaceOnTableau(stack[1], dest:top()) then
      for _, c in ipairs(stack) do dest:add(c) end
      layout.layoutTableau(dest)
      return true
    end
  elseif dest.kind == "foundation" and #stack == 1 then
    if canPlaceOnFoundation(stack[1], dest:top()) then
      dest:add(stack[1])
      stack[1].x, stack[1].y = dest.x, dest.y
      return true
    end
  end
  return false
end

function love.load()
  love.window.setMode(constants.SCREEN_W, constants.SCREEN_H)
  love.math.setRandomSeed(os.time())

  images, CARD_BACK, CARD_W, CARD_H = utils.loadImages()
  _G.CARD_W, _G.CARD_H = CARD_W, CARD_H
  _G.CARD_BACK = CARD_BACK

  hudFont = love.graphics.newFont(constants.HUD_FONT_SIZE)
  btnNewGame = { x = constants.SCREEN_W - 150, y = 20, w = 140, h = 44 }

  state = game.newGame(images, CARD_W, CARD_H)
end

function love.mousepressed(x, y, button)
  if button ~= 1 then return end

  if isOverHeader(btnNewGame, x, y) then
    state = game.newGame(images, CARD_W, CARD_H)
    return
  end

  if isOverHeader(state.stock, x, y) then
    if state.stock:isEmpty() then
      for i = #state.waste.cards, 1, -1 do
        local c = table.remove(state.waste.cards)
        c.faceUp = false; state.stock:add(c)
        c.x, c.y = state.stock.x, state.stock.y
      end
      for i = #state.discard, 1, -1 do
        local c = table.remove(state.discard)
        c.faceUp = false; state.stock:add(c)
        c.x, c.y = state.stock.x, state.stock.y
      end
    else
      for i = #state.waste.cards, 1, -1 do
        table.insert(state.discard, table.remove(state.waste.cards))
      end
      for i = 1, math.min(3, #state.stock.cards) do
        local c = table.remove(state.stock.cards)
        c.faceUp = true; state.waste:add(c)
      end
      layout.layoutWaste(state.waste)
    end
    state.moveCount = state.moveCount + 1
    return
  end

  local c = findCard(x, y)
  if not c or not c.faceUp or c.pile.kind == "foundation" then return end
  if c.pile.kind == "waste" and c ~= c.pile:top() then return end

  dragging = {
    cards = c.pile:removeFrom(c),
    dx    = x - c.x,
    dy    = y - c.y,
    origin = c.pile,
  }
end

function love.mousemoved(x, y)
  if not dragging then return end
  local overValid = false
  for _, p in ipairs(state.piles) do
    if isOverPile(p, x, y) and canPlace(dragging.cards, p) then
      overValid = true
      if p.kind == "tableau" then
        for i, c in ipairs(dragging.cards) do
          c.x = p.x
          c.y = p.y + (i - 1) * constants.SPACING.tableauFaceUp
        end
      else
        local c0 = dragging.cards[1]
        c0.x, c0.y = p.x, p.y
      end
      break
    end
  end
  if not overValid then
    for i, c in ipairs(dragging.cards) do
      c.x = x - dragging.dx
      c.y = y - dragging.dy + (i - 1) * constants.SPACING.tableauFaceUp
    end
  end
end

function love.mousereleased(x, y)
  if not dragging then return end
  local placed = false
  for _, p in ipairs(state.piles) do
    if isOverPile(p, x, y) and tryPlace(dragging.cards, p) then
      placed = true; state.moveCount = state.moveCount + 1; break
    end
  end
  if not placed then
    for _, c in ipairs(dragging.cards) do
      dragging.origin:add(c)
    end
    if dragging.origin.kind == "tableau" then
      layout.layoutTableau(dragging.origin)
    else
      layout.layoutWaste(dragging.origin)
    end
  end
  if dragging.origin.kind == "tableau" and not dragging.origin:isEmpty() then
    local t = dragging.origin:top()
    if not t.faceUp then t.faceUp = true end
  end
  dragging = nil
end

function love.draw()
  love.graphics.setBackgroundColor(0.11, 0.43, 0.07)
  for _, p in ipairs(state.piles) do p:draw() end
  if dragging then for _, c in ipairs(dragging.cards) do c:draw() end end

  love.graphics.setFont(hudFont)
  local elapsed = math.floor(love.timer.getTime() - state.startTime)
  local mins, secs = math.floor(elapsed/60), elapsed % 60
  local text = string.format("Time %02d:%02d   Moves %d", mins, secs, state.moveCount)
  love.graphics.setColor(1,1,1)
  love.graphics.print(text, (constants.SCREEN_W - hudFont:getWidth(text))/2, 25)

  love.graphics.setColor(0.2,0.2,0.2,0.8)
  love.graphics.rectangle("fill", btnNewGame.x, btnNewGame.y, btnNewGame.w, btnNewGame.h, 6,6)
  love.graphics.setColor(1,1,1)
  love.graphics.printf("New Game", btnNewGame.x, btnNewGame.y+10, btnNewGame.w, "center")

  local won = true
  for _, f in ipairs(state.foundations) do if #f.cards < 13 then won = false; break end end
  if won then
    love.graphics.setColor(1,1,0)
    love.graphics.printf("YOU WIN!", 0, constants.SCREEN_H/2-40, constants.SCREEN_W, "center", 0, 2, 2)
  end
end