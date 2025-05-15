-- constants.lua
local constants = {}

-- Card suits and color definitions
constants.SUITS = { "clubs", "diamonds", "hearts", "spades" }
constants.RED_SUITS = { diamonds = true, hearts = true }

-- Spacing between cards in piles
constants.SPACING = {
  tableauFaceUp   = 32,
  tableauFaceDown = 12,
  wasteFanX       = 20,
}

-- Screen and HUD settings
constants.SCREEN_W      = 1280
constants.SCREEN_H      = 720
constants.HUD_FONT_SIZE = 22

return constants