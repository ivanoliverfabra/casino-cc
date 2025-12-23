local deck = require("gameLib.deck")

--- @class BlackjackHand : Hand
--- @field bet number
--- @field status "playing" | "stood" | "busted" | "blackjack"
--- @field getValue fun(self: BlackjackHand): number

local function createBlackjackHand(bet, status)
  local hand = deck.newHand()
  local bjHand = hand --[[@as BlackjackHand]]
  bjHand.bet = bet or 0
  bjHand.status = status or "playing"

  function bjHand:getValue()
    local total = 0
    local aces = 0

    for _, card in ipairs(self.cards) do
      if card.rank == "Ace" then
        aces = aces + 1
        total = total + 11
      elseif
        card.rank == "King" or card.rank == "Queen" or card.rank == "Jack"
      then
        total = total + 10
      else
        total = total + (tonumber(card.rank) or 0)
      end
    end

    while total > 21 and aces > 0 do
      total = total - 10
      aces = aces - 1
    end

    return total
  end

  return bjHand
end

--- @class BlackjackGame
--- @field deck Deck
--- @field dealerHand BlackjackHand
--- @field playerHands BlackjackHand[]
--- @field activeHandIndex number
--- @field isGameOver boolean
local Blackjack = {}
Blackjack.__index = Blackjack

local api = {}

--- @param bet number
--- @return BlackjackGame
function api.newGame(bet)
  local self = setmetatable({}, Blackjack)
  self.deck = deck.newDeck():shuffle()
  self.dealerHand = createBlackjackHand(0, "playing")

  local firstHand = createBlackjackHand(bet, "playing")

  self.playerHands = { firstHand }
  self.activeHandIndex = 1
  self.isGameOver = false

  self.dealerHand:addCard(self.deck:draw())
  firstHand:addCard(self.deck:draw())
  self.dealerHand:addCard(self.deck:draw())
  firstHand:addCard(self.deck:draw())

  if firstHand:getValue() == 21 then
    firstHand.status = "blackjack"
    self:checkGameStatus()
  end

  return self
end

function Blackjack:getActiveHand()
  return self.playerHands[self.activeHandIndex]
end

function Blackjack:hit()
  local hand = self:getActiveHand()
  if not hand or hand.status ~= "playing" then
    return
  end

  hand:addCard(self.deck:draw())

  if hand:getValue() > 21 then
    hand.status = "busted"
    self:nextHand()
  end
end

function Blackjack:stand()
  local hand = self:getActiveHand()
  if not hand or hand.status ~= "playing" then
    return
  end

  hand.status = "stood"
  self:nextHand()
end

function Blackjack:canDouble()
  local hand = self:getActiveHand()
  return hand and #hand.cards == 2 and hand.status == "playing"
end

function Blackjack:doubleDown()
  if not self:canDouble() then
    return
  end
  local hand = self:getActiveHand()

  hand.bet = hand.bet * 2
  hand:addCard(self.deck:draw())

  if hand:getValue() > 21 then
    hand.status = "busted"
  else
    hand.status = "stood"
  end

  self:nextHand()
end

function Blackjack:canSplit()
  local hand = self:getActiveHand()
  if not hand or #hand.cards ~= 2 or hand.status ~= "playing" then
    return false
  end
  return hand.cards[1].rank == hand.cards[2].rank
end

function Blackjack:split()
  if not self:canSplit() then
    return
  end
  local hand = self:getActiveHand()

  local newHand = createBlackjackHand(hand.bet, "playing")

  local card = table.remove(hand.cards)
  newHand:addCard(card)

  hand:addCard(self.deck:draw())
  newHand:addCard(self.deck:draw())

  table.insert(self.playerHands, self.activeHandIndex + 1, newHand)
end

function Blackjack:nextHand()
  if self.activeHandIndex < #self.playerHands then
    self.activeHandIndex = self.activeHandIndex + 1
    if self:getActiveHand():getValue() == 21 then
      self:getActiveHand().status = "blackjack"
      self:nextHand()
    end
  else
    self:dealerTurn()
  end
end

function Blackjack:dealerTurn()
  self.activeHandIndex = #self.playerHands + 1

  local allBusted = true
  for _, hand in ipairs(self.playerHands) do
    if hand.status ~= "busted" then
      allBusted = false
      break
    end
  end

  if not allBusted then
    while self.dealerHand:getValue() < 17 do
      self.dealerHand:addCard(self.deck:draw())
    end
  end

  local dVal = self.dealerHand:getValue()
  if dVal > 21 then
    self.dealerHand.status = "busted"
  elseif dVal == 21 and #self.dealerHand.cards == 2 then
    self.dealerHand.status = "blackjack"
  else
    self.dealerHand.status = "stood"
  end

  self.isGameOver = true
end

function Blackjack:checkGameStatus()
  local allFinished = true
  for _, hand in ipairs(self.playerHands) do
    if hand.status == "playing" then
      allFinished = false
      break
    end
  end
  if allFinished then
    self:dealerTurn()
  end
end

function Blackjack:calculatePayout(hand)
  local dVal = self.dealerHand:getValue()
  local pVal = hand:getValue()

  if hand.status == "busted" then
    return 0
  end
  if hand.status == "blackjack" then
    if self.dealerHand.status == "blackjack" then
      return hand.bet
    end
    return hand.bet * 2.5
  end

  if self.dealerHand.status == "busted" then
    return hand.bet * 2
  end
  if self.dealerHand.status == "blackjack" then
    return 0
  end

  if pVal > dVal then
    return hand.bet * 2
  elseif pVal == dVal then
    return hand.bet
  else
    return 0
  end
end

return api