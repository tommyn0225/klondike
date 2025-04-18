---------------------------------------------------------------------------
-- CONSTANTS
---------------------------------------------------------------------------

-- Card suit definitions
local SUITS       = { "clubs", "diamonds", "hearts", "spades" }
local RED_SUITS   = { diamonds = true, hearts = true }

-- Layout constants
local TABLEAU_GAP_FACEUP   = 32   -- spacing for face-up cards in tableau
local TABLEAU_GAP_FACEDOWN = 12   -- spacing for face-down cards in tableau
local WASTE_FAN_X          = 20   -- horizontal offset for fanned waste cards
local HUD_FONT_SIZE        = 22
local SCREEN_W, SCREEN_H   = 1280, 720

---------------------------------------------------------------------------
-- GLOBAL STATE
---------------------------------------------------------------------------

-- Card dimensions and assets
local CARD_W, CARD_H, CARD_BACK
local images = {}

-- Piles and game state
local piles, stock, waste, discard, tableaus, foundations
local dragging
local startTime, moveCount
local hudFont
local btnNewGame = { w = 140, h = 44 } -- New Game button dimensions

---------------------------------------------------------------------------
-- HELPERS
---------------------------------------------------------------------------

-- Returns true if suit is red
local function is_red(s) return RED_SUITS[s] end

-- Returns true if suits are opposite colors
local function opp_color(a,b) return is_red(a) ~= is_red(b) end

-- Checks if card `c` can be placed on tableau card `d`
local function can_tab(c,d)
  return (d and c.rank==d.rank-1 and opp_color(c.suit,d.suit))
      or (not d and c.rank==13) -- king on empty pile
end

-- Checks if card `c` can be placed on foundation card `d`
local function can_found(c,d)
  return (d and c.suit==d.suit and c.rank==d.rank+1)
      or (not d and c.rank==1) -- ace on empty pile
end

-- Shuffles a table in-place
local function shuffle(t)
  for i=#t,2,-1 do
    local j=love.math.random(i)
    t[i],t[j]=t[j],t[i]
  end
end

---------------------------------------------------------------------------
-- OBJECTS
---------------------------------------------------------------------------

-- Card object
local Card = {}
Card.__index = Card

function Card:new(s, r, img)
  return setmetatable({suit=s, rank=r, img=img, faceUp=false, x=0, y=0, pile=nil}, Card)
end

function Card:draw()
  love.graphics.draw(self.faceUp and self.img or CARD_BACK, self.x, self.y)
end

-- Pile object
local Pile = {}
Pile.__index = Pile

function Pile:new(kind, x, y)
  return setmetatable({kind=kind, x=x, y=y, cards={}}, Pile)
end

function Pile:top()
  return self.cards[#self.cards]
end

function Pile:isEmpty()
  return #self.cards == 0
end

function Pile:add(c)
  self.cards[#self.cards + 1] = c
  c.pile = self
end

-- Removes and returns cards from the given card to the top
function Pile:remove_from(card)
  local idx
  for i, c in ipairs(self.cards) do
    if c == card then idx = i break end
  end
  local mv = {}
  for i = idx, #self.cards do mv[#mv + 1] = self.cards[i] end
  for i = #self.cards, idx, -1 do self.cards[i] = nil end
  return mv
end

-- Draws the pile and its cards based on type
function Pile:draw()
  if self.kind == "tableau" then
    for _, c in ipairs(self.cards) do c:draw() end
  elseif self.kind == "waste" then
    local n = #self.cards
    for i = math.max(1, n - 2), n do self.cards[i]:draw() end
  else -- stock or foundation
    local c = self:top()
    if c then c:draw()
    else
      love.graphics.setColor(0,0,0,0.25)
      love.graphics.rectangle("line", self.x, self.y, CARD_W, CARD_H, 6, 6)
      love.graphics.setColor(1,1,1)
    end
  end
end

---------------------------------------------------------------------------
-- LAYOUT
---------------------------------------------------------------------------

-- Update tableau card positions
local function layout_tableau(t)
  for i, c in ipairs(t.cards) do
    c.x = t.x
    c.y = t.y + (c.faceUp and TABLEAU_GAP_FACEUP or TABLEAU_GAP_FACEDOWN) * (i - 1)
  end
end

-- Update waste pile fan layout
local function layout_waste()
  local n = #waste.cards
  for i, c in ipairs(waste.cards) do
    local slot = i - (n - 2)
    c.x = waste.x + (slot - 1) * WASTE_FAN_X
    c.y = waste.y
  end
end

---------------------------------------------------------------------------
-- IMAGE LOAD
---------------------------------------------------------------------------

-- Load card images from assets
local function load_images()
  for _, s in ipairs(SUITS) do
    images[s] = {}
    for r = 1, 13 do
      images[s][r] = love.graphics.newImage(("assets/cards/card-%s-%d.png"):format(s, r))
    end
  end
  CARD_BACK = love.graphics.newImage("assets/cards/card-back1.png")
  CARD_W, CARD_H = CARD_BACK:getWidth(), CARD_BACK:getHeight()
end

---------------------------------------------------------------------------
-- GAME SETUP
---------------------------------------------------------------------------

-- Initializes a new game
local function new_game()
  piles, tableaus, foundations = {}, {}, {}
  dragging = nil
  moveCount = 0
  startTime = love.timer.getTime()

  local margin = (SCREEN_W - 7 * CARD_W - 6 * 20) / 2
  local topY, tabY = 60, 220

  -- Create main piles
  stock = Pile:new("stock", margin, topY)
  waste = Pile:new("waste", margin + CARD_W + 20, topY)
  discard = {}
  table.insert(piles, stock)
  table.insert(piles, waste)

  -- Create foundation piles
  for i = 1, 4 do
    local f = Pile:new("foundation", margin + (3 + i) * (CARD_W + 20), topY)
    table.insert(foundations, f)
    table.insert(piles, f)
  end

  -- Create tableau piles
  for i = 1, 7 do
    local t = Pile:new("tableau", margin + (i - 1) * (CARD_W + 20), tabY)
    table.insert(tableaus, t)
    table.insert(piles, t)
  end

  -- Create and shuffle deck
  local deck = {}
  for _, s in ipairs(SUITS) do
    for r = 1, 13 do
      table.insert(deck, Card:new(s, r, images[s][r]))
    end
  end
  shuffle(deck)

  -- Deal to tableau
  for i, t in ipairs(tableaus) do
    for j = 1, i do
      local c = table.remove(deck)
      t:add(c)
      c.x = t.x
      c.y = t.y + (j - 1) * (j == i and TABLEAU_GAP_FACEUP or TABLEAU_GAP_FACEDOWN)
      if j == i then c.faceUp = true end
    end
  end

  -- Remaining cards to stock
  for _, c in ipairs(deck) do
    stock:add(c)
    c.x, c.y = stock.x, stock.y
  end
end

---------------------------------------------------------------------------
-- LOVE LOAD
---------------------------------------------------------------------------

function love.load()
  love.window.setMode(SCREEN_W, SCREEN_H, {resizable = false})
  love.math.setRandomSeed(os.time())
  load_images()
  hudFont = love.graphics.newFont(HUD_FONT_SIZE)
  btnNewGame.x, btnNewGame.y = SCREEN_W - btnNewGame.w - 30, 20
  new_game()
end

---------------------------------------------------------------------------
-- INPUT
---------------------------------------------------------------------------

-- Checks if a point is over a pile's top rectangle
local function over_head(p, x, y)
  return x >= p.x and x <= p.x + CARD_W and y >= p.y and y <= p.y + CARD_H
end

-- Checks if a point is within a pile’s vertical range
local function over_pile(p, x, y)
  if x < p.x or x > p.x + CARD_W then return false end
  if p.kind == "tableau" then
    local bottom = (#p.cards == 0) and (p.y + CARD_H) or (p.cards[#p.cards].y + CARD_H)
    return y >= p.y and y <= bottom
  else
    return y >= p.y and y <= p.y + CARD_H
  end
end

-- Finds the card under the given coordinates
local function card_at(x, y)
  for i = #piles, 1, -1 do
    local p = piles[i]
    local stack = (p.kind == "tableau" or p.kind == "waste") and p.cards or {p:top()}
    for j = #stack, 1, -1 do
      local c = stack[j]
      if c and c.faceUp and x >= c.x and x <= c.x + CARD_W and y >= c.y and y <= c.y + CARD_H then
        return c
      end
    end
  end
end

-- Checks if the "New Game" button was clicked
local function click_new(x, y)
  return x >= btnNewGame.x and x <= btnNewGame.x + btnNewGame.w
     and y >= btnNewGame.y and y <= btnNewGame.y + btnNewGame.h
end

-- Handles mouse press logic
function love.mousepressed(x, y, b)
  if b ~= 1 then return end
  if click_new(x, y) then new_game(); return end

  -- Clicking stock to draw or reset
  if over_head(stock, x, y) then
    if stock:isEmpty() then
      for i = #waste.cards, 1, -1 do
        local c = table.remove(waste.cards)
        c.faceUp = false
        stock:add(c)
        c.x, c.y = stock.x, stock.y
      end
      for i = #discard, 1, -1 do
        local c = table.remove(discard)
        c.faceUp = false
        stock:add(c)
        c.x, c.y = stock.x, stock.y
      end
    else
      for i = #waste.cards, 1, -1 do table.insert(discard, table.remove(waste.cards)) end
      for i = 1, math.min(3, #stock.cards) do
        local c = table.remove(stock.cards)
        c.faceUp = true
        waste:add(c)
      end
      layout_waste()
    end
    moveCount = moveCount + 1
    return
  end

  local c = card_at(x, y)
  if not c then return end
  if c.pile.kind == "waste" and c ~= c.pile:top() then return end
  if c.pile.kind == "foundation" or not c.faceUp then return end

  -- Start dragging
  dragging = {
    cards = c.pile:remove_from(c),
    dx = x - c.x,
    dy = y - c.y,
    origin = c.pile
  }
  if dragging.origin.kind == "tableau" then layout_tableau(dragging.origin)
  else layout_waste() end
end

-- Updates position of dragged cards
function love.mousemoved(x, y, dx, dy)
  if not dragging then return end
  for i, card in ipairs(dragging.cards) do
    card.x = x - dragging.dx
    card.y = y - dragging.dy + (i - 1) * TABLEAU_GAP_FACEUP
  end
end

-- Tries to place a card or card stack on a valid pile
local function try_place(stack, dest)
  local first = stack[1]
  if dest.kind == "tableau" then
    if can_tab(first, dest:top()) then
      for _, c in ipairs(stack) do dest:add(c) end
      layout_tableau(dest)
      return true
    end
  elseif dest.kind == "foundation" and #stack == 1 then
    if can_found(first, dest:top()) then
      dest:add(first)
      first.x, first.y = dest.x, dest.y
      return true
    end
  end
  return false
end

-- Handles mouse release and drop logic
function love.mousereleased(x, y, b)
  if b ~= 1 or not dragging then return end
  local placed = false
  for _, p in ipairs(piles) do
    if over_pile(p, x, y) and try_place(dragging.cards, p) then
      placed = true
      moveCount = moveCount + 1
      break
    end
  end

  if not placed then
    for _, c in ipairs(dragging.cards) do dragging.origin:add(c) end
  end

  if dragging.origin.kind == "tableau" then layout_tableau(dragging.origin)
  else layout_waste() end

  if dragging.origin.kind == "tableau" and not dragging.origin:isEmpty() then
    local t = dragging.origin:top()
    if not t.faceUp then t.faceUp = true end
  end
  dragging = nil
end

---------------------------------------------------------------------------
-- DRAW
---------------------------------------------------------------------------

function love.draw()
  -- Background and piles
  love.graphics.setBackgroundColor(0.11, 0.43, 0.07)
  for _, p in ipairs(piles) do p:draw() end
  if dragging then for _, c in ipairs(dragging.cards) do c:draw() end end

  -- HUD
  love.graphics.setFont(hudFont)
  local t = math.floor(love.timer.getTime() - startTime)
  local mins, secs = math.floor(t / 60), t % 60
  local hud = string.format("Time %02d:%02d   Moves %d", mins, secs, moveCount)
  love.graphics.setColor(1, 1, 1)
  love.graphics.print(hud, (SCREEN_W - hudFont:getWidth(hud)) / 2, 25)

  -- New Game Button
  love.graphics.setColor(0.2, 0.2, 0.2, 0.8)
  love.graphics.rectangle("fill", btnNewGame.x, btnNewGame.y, btnNewGame.w, btnNewGame.h, 6, 6)
  love.graphics.setColor(1, 1, 1)
  love.graphics.printf("New Game", btnNewGame.x, btnNewGame.y + 10, btnNewGame.w, "center")

  -- Win condition
  local win = true
  for _, f in ipairs(foundations) do
    if #f.cards < 13 then win = false break end
  end
  if win then
    love.graphics.setColor(1, 1, 0)
    love.graphics.printf("YOU WIN!", 0, SCREEN_H / 2 - 40, SCREEN_W, "center", 0, 2, 2)
  end
end
