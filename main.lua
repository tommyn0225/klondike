-- Card suits and color definitions
local SUITS       = { "clubs", "diamonds", "hearts", "spades" }
local RED_SUITS   = { diamonds = true, hearts = true }

-- How far apart cards sit in different piles
local SPACING = {
  tableauFaceUp   = 32,
  tableauFaceDown = 12,
  wasteFanX       = 20,
}

-- Screen and HUD settings
local SCREEN_W, SCREEN_H = 1280, 720
local HUD_FONT_SIZE      = 22

-- Globals for card size and images
local CARD_W, CARD_H, CARD_BACK
local images = {}

-- Piles and game state trackers
local piles, stock, waste, foundations, tableaus
local dragging, discard, moveCount, startTime
local hudFont
local btnNewGame = { w = 140, h = 44 }

-- Check if a suit is red
local function isRed(suit)
  return RED_SUITS[suit]
end

-- Check if two suits are opposite colors
local function isOppositeColor(a, b)
  return isRed(a) ~= isRed(b)
end

-- Can we move card c onto tableau top d?
local function canPlaceOnTableau(c, d)
  if d then
    return c.rank == d.rank - 1 and isOppositeColor(c.suit, d.suit)
  else
    return c.rank == 13  -- king on empty spot
  end
end

-- Can we move card c onto foundation top d?
local function canPlaceOnFoundation(c, d)
  if d then
    return c.suit == d.suit and c.rank == d.rank + 1
  else
    return c.rank == 1   -- ace on empty spot
  end
end

-- Fisher–Yates shuffle
local function shuffle(t)
  for i = #t, 2, -1 do
    local j = love.math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

-- Card class
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

-- Pile class (stock, waste, tableau, foundation)
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

-- Pull off cards starting from the given one
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

-- Draw pile and its cards
function Pile:draw()
  if self.kind == "tableau" then
    for _, c in ipairs(self.cards) do c:draw() end
  elseif self.kind == "waste" then
    local n = #self.cards
    for i = math.max(1, n - 2), n do
      self.cards[i]:draw()
    end
  else  -- stock or foundation
    local top = self:top()
    if top then
      top:draw()
    else
      love.graphics.setColor(0,0,0,0.25)
      love.graphics.rectangle("line", self.x, self.y, CARD_W, CARD_H, 6, 6)
      love.graphics.setColor(1,1,1)
    end
  end
end

-- Position cards in a tableau pile
local function layoutTableau(pile)
  for i, c in ipairs(pile.cards) do
    c.x = pile.x
    local gap = c.faceUp and SPACING.tableauFaceUp or SPACING.tableauFaceDown
    c.y = pile.y + gap * (i - 1)
  end
end

-- Fan out the waste cards nicely
local function layoutWaste()
  local n = #waste.cards
  for i, c in ipairs(waste.cards) do
    local slot = i - (n - 2)
    c.x = waste.x + (slot - 1) * SPACING.wasteFanX
    c.y = waste.y
  end
end

-- Load all the card textures
local function loadImages()
  for _, suit in ipairs(SUITS) do
    images[suit] = {}
    for rank = 1, 13 do
      images[suit][rank] = love.graphics.newImage(
        ("assets/cards/card-%s-%d.png"):format(suit, rank)
      )
    end
  end
  CARD_BACK = love.graphics.newImage("assets/cards/card-back1.png")
  CARD_W, CARD_H = CARD_BACK:getWidth(), CARD_BACK:getHeight()
end

-- Set up a brand-new game state
local function newGame()
  piles, tableaus, foundations = {}, {}, {}
  discard, dragging = {}, nil
  moveCount = 0
  startTime = love.timer.getTime()

  local margin = (SCREEN_W - 7 * CARD_W - 6 * 20) / 2
  local topY, tabY = 60, 220

  -- Stock and waste spots
  stock = Pile:new("stock", margin, topY)
  waste = Pile:new("waste", margin + CARD_W + 20, topY)
  table.insert(piles, stock)
  table.insert(piles, waste)

  -- Foundations
  for i = 1, 4 do
    local x = margin + (3 + i) * (CARD_W + 20)
    local f = Pile:new("foundation", x, topY)
    table.insert(foundations, f)
    table.insert(piles, f)
  end

  -- Tableaus
  for i = 1, 7 do
    local x = margin + (i - 1) * (CARD_W + 20)
    local t = Pile:new("tableau", x, tabY)
    table.insert(tableaus, t)
    table.insert(piles, t)
  end

  -- Build and shuffle deck
  local deck = {}
  for _, suit in ipairs(SUITS) do
    for rank = 1, 13 do
      table.insert(deck, Card:new(suit, rank, images[suit][rank]))
    end
  end
  shuffle(deck)

  -- Deal into tableaus
  for i, t in ipairs(tableaus) do
    for j = 1, i do
      local card = table.remove(deck)
      t:add(card)
      card.x = t.x
      local gap = (j == i) and SPACING.tableauFaceUp or SPACING.tableauFaceDown
      card.y = t.y + (j - 1) * gap
      if j == i then card.faceUp = true end
    end
  end

  -- Remainder goes to stock
  for _, card in ipairs(deck) do
    stock:add(card)
    card.x, card.y = stock.x, stock.y
  end
end

-- LOVE2D entry point
function love.load()
  love.window.setMode(SCREEN_W, SCREEN_H)
  love.math.setRandomSeed(os.time())
  loadImages()
  hudFont = love.graphics.newFont(HUD_FONT_SIZE)
  btnNewGame.x, btnNewGame.y = SCREEN_W - btnNewGame.w - 30, 20
  newGame()
end

-- Helper: is point over a pile header?
local function isOverHeader(p, x, y)
  return x >= p.x and x <= p.x + CARD_W and y >= p.y and y <= p.y + CARD_H
end

-- Helper: is point over a pile area?
local function isOverPile(p, x, y)
  if x < p.x or x > p.x + CARD_W then return false end
  if p.kind == "tableau" then
    local bottom = (#p.cards == 0) and (p.y + CARD_H) or (p:top().y + CARD_H)
    return y >= p.y and y <= bottom
  else
    return y >= p.y and y <= p.y + CARD_H
  end
end

-- Find the topmost face-up card under (x,y)
local function findCard(x, y)
  for i = #piles, 1, -1 do
    local p = piles[i]
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

-- Check if New Game button clicked
local function clickedNew(x, y)
  return x >= btnNewGame.x and x <= btnNewGame.x + btnNewGame.w
     and y >= btnNewGame.y and y <= btnNewGame.y + btnNewGame.h
end

-- Start dragging cards
function love.mousepressed(x, y, button)
  if button ~= 1 then return end
  if clickedNew(x, y) then
    newGame()
    return
  end

  if isOverHeader(stock, x, y) then
    -- draw three or reset stock
    if stock:isEmpty() then
      -- reset all cards back into stock
      for i = #waste.cards, 1, -1 do
        local c = table.remove(waste.cards)
        c.faceUp = false; stock:add(c)
        c.x, c.y = stock.x, stock.y
      end
      for i = #discard, 1, -1 do
        local c = table.remove(discard)
        c.faceUp = false; stock:add(c)
        c.x, c.y = stock.x, stock.y
      end
    else
      -- move waste to discard then draw
      for i = #waste.cards, 1, -1 do
        table.insert(discard, table.remove(waste.cards))
      end
      for i = 1, math.min(3, #stock.cards) do
        local c = table.remove(stock.cards)
        c.faceUp = true; waste:add(c)
      end
      layoutWaste()
    end
    moveCount = moveCount + 1
    return
  end

  local c = findCard(x, y)
  if not c or not c.faceUp or c.pile.kind == "foundation" then return end
  if c.pile.kind == "waste" and c ~= c.pile:top() then return end

  -- start dragging this card and any below it
  dragging = {
    cards  = c.pile:removeFrom(c),
    dx     = x - c.x,
    dy     = y - c.y,
    origin = c.pile,
  }
  if dragging.origin.kind == "tableau" then layoutTableau(dragging.origin) end
  if dragging.origin.kind == "waste"   then layoutWaste()            end
end

-- Move dragged cards with mouse
function love.mousemoved(x, y)
  if not dragging then return end
  for i, card in ipairs(dragging.cards) do
    card.x = x - dragging.dx
    card.y = y - dragging.dy + (i - 1) * SPACING.tableauFaceUp
  end
end

-- Try placing dragged cards, or snap back
local function tryPlace(stack, dest)
  local first = stack[1]
  if dest.kind == "tableau" then
    if canPlaceOnTableau(first, dest:top()) then
      for _, c in ipairs(stack) do dest:add(c) end
      layoutTableau(dest)
      return true
    end
  elseif dest.kind == "foundation" and #stack == 1 then
    if canPlaceOnFoundation(first, dest:top()) then
      dest:add(first)
      first.x, first.y = dest.x, dest.y
      return true
    end
  end
  return false
end

-- Drop logic
function love.mousereleased(x, y)
  if not dragging then return end
  local placed = false
  for _, p in ipairs(piles) do
    if isOverPile(p, x, y) and tryPlace(dragging.cards, p) then
      placed = true; moveCount = moveCount + 1; break
    end
  end
  if not placed then
    -- snap back
    for _, c in ipairs(dragging.cards) do dragging.origin:add(c) end
  end
  -- flip card if needed
  if dragging.origin.kind == "tableau" and not dragging.origin:isEmpty() then
    local top = dragging.origin:top()
    if not top.faceUp then top.faceUp = true end
  end
  dragging = nil
end

-- Main draw function
function love.draw()
  love.graphics.setBackgroundColor(0.11, 0.43, 0.07)
  for _, p in ipairs(piles) do p:draw() end
  if dragging then for _, c in ipairs(dragging.cards) do c:draw() end end

  -- HUD with time and moves
  love.graphics.setFont(hudFont)
  local elapsed = math.floor(love.timer.getTime() - startTime)
  local mins, secs = math.floor(elapsed/60), elapsed % 60
  local hudText = string.format("Time %02d:%02d   Moves %d", mins, secs, moveCount)
  love.graphics.setColor(1,1,1)
  love.graphics.print(hudText, (SCREEN_W - hudFont:getWidth(hudText))/2, 25)

  -- New Game button
  love.graphics.setColor(0.2,0.2,0.2,0.8)
  love.graphics.rectangle("fill", btnNewGame.x, btnNewGame.y, btnNewGame.w, btnNewGame.h, 6,6)
  love.graphics.setColor(1,1,1)
  love.graphics.printf("New Game", btnNewGame.x, btnNewGame.y+10, btnNewGame.w, "center")

  -- Win message
  local won = true
  for _, f in ipairs(foundations) do
    if #f.cards < 13 then won = false; break end
  end
  if won then
    love.graphics.setColor(1,1,0)
    love.graphics.printf("YOU WIN!", 0, SCREEN_H/2-40, SCREEN_W, "center", 0, 2, 2)
  end
end
