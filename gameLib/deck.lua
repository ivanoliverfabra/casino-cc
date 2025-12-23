--- @alias CardRank "2"|"3"|"4"|"5"|"6"|"7"|"8"|"9"|"10"|"Jack"|"Queen"|"King"|"Ace"

--- @class Suit
--- @field name string
--- @field symbol string

--- @class Card
--- @field suit Suit
--- @field rank CardRank

local api = {}

local SUITS = {
	{ name = "Hearts", symbol = string.char(3) },
	{ name = "Diamonds", symbol = string.char(4) },
	{ name = "Clubs", symbol = string.char(5) },
	{ name = "Spades", symbol = string.char(6) },
}

local RANKS = {
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
	"10",
	"Jack",
	"Queen",
	"King",
	"Ace",
}

--- @class Deck
--- @field cards Card[]
local Deck = {}
Deck.__index = Deck

function api.newDeck()
	local self = setmetatable({}, Deck)
	self.cards = {}
	for _, suit in ipairs(SUITS) do
		for _, rank in ipairs(RANKS) do
			table.insert(self.cards, { suit = suit, rank = rank })
		end
	end
	return self
end

function Deck:shuffle()
	math.randomseed(os.epoch("utc") + os.getComputerID())

	for i = 1, 5 do
		math.random()
	end

	for i = #self.cards, 2, -1 do
		local j = math.random(i)
		self.cards[i], self.cards[j] = self.cards[j], self.cards[i]
	end
	return self
end

function Deck:draw()
	return table.remove(self.cards)
end

function Deck:count()
	return #self.cards
end

--- @class Hand
--- @field cards Card[]
local Hand = {}
Hand.__index = Hand

function api.newHand()
	return setmetatable({ cards = {} }, Hand)
end

function Hand:addCard(card)
	if card then
		table.insert(self.cards, card)
	end
end

return api
