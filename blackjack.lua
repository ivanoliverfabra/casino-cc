local currency = require("gameLib.currency")
local blackjack = require("gameLib.games.blackjack")
local renderer = require("gameLib.renderer")
local ui = require("gameLib.ui")
local shrekbox = require("gameLib.shrekbox")

local monitor = peripheral.find("monitor")
if not monitor then
	error("No monitor peripheral found")
end
monitor.setTextScale(0.5)
local w, h = monitor.getSize()
local win = window.create(monitor, 1, 1, w, h)
local box = shrekbox.new(win)

-- CONSTANTS
local CARD_W = 11
local STACK_O = 3
local GAP_O = 12
local BG_COLOR = colors.black
local ACCENT_COLOR = colors.yellow
local BUTTON_GRAY = colors.gray
local BUTTON_TEXT = colors.white

-- Helper to calculate the width of a hand for centering math
local function getHandWidth(count, isOverlay)
	if count == 0 then
		return 0
	end
	local offset = isOverlay and STACK_O or GAP_O
	return CARD_W + (count - 1) * offset
end

local layers = {
	ui = ui.new(box.add_text_layer(150, "ui_layer")),
	cards = {},
}

for i = 1, 30 do
	layers.cards[i] = {
		pixel = box.add_pixel_layer(i * 2, "c_body_" .. i),
		text = box.add_text_layer(i * 2 + 1, "c_txt_" .. i),
	}
end

local wallet = currency.newWallet(1000)
local game
local state = "BETTING"
local currentBet = 0

-- Helper to draw centered text easily
local function drawCenteredText(y, text, fg, bg)
	local x = math.floor((w - #text) / 2)
	layers.ui:addLabel(x, y, text, fg, bg)
end

local function startNewGame()
	if currentBet > 0 and wallet:remove(currentBet) then
		game = blackjack.newGame(currentBet)
		state = "PLAYING"
	end
end

local function handlePayouts()
	for _, hand in ipairs(game.playerHands) do
		local payout = game:calculatePayout(hand)
		wallet:add(payout)
	end
end

-- Keypad Logic
local function appendBet(digit)
	local newVal = (currentBet * 10) + digit
	-- Cap at wallet balance
	if newVal <= wallet:get() then
		currentBet = newVal
	else
		currentBet = wallet:get()
	end
end

local function updateUI(revealDealer)
	-- Clear Graphics
	for _, l in ipairs(layers.cards) do
		l.pixel.clear()
		l.text.clear()
	end
	layers.ui.layer.clear()
	layers.ui:clear()
	box.fill(BG_COLOR)

	-- Top Bar
	layers.ui:addLabel(2, 1, "BALANCE: " .. wallet:get(), ACCENT_COLOR, BG_COLOR)

	if state == "BETTING" then
		local cx = math.floor(w / 2)
		local cy = math.floor(h / 2)

		-- Display current bet large
		local title = "PLACE YOUR BET"
		drawCenteredText(cy - 8, title, colors.lightGray, BG_COLOR)

		local betStr = tostring(currentBet)
		-- If bet is 0, show it in gray, otherwise cyan
		local betCol = currentBet > 0 and colors.cyan or colors.gray
		drawCenteredText(cy - 6, betStr .. " COINS", betCol, BG_COLOR)

		-- === KEYPAD RENDER ===
		local btnW, btnH = 5, 3
		local gap = 1

		-- Grid configuration
		local startX = cx - math.floor((3 * btnW + 2 * gap) / 2)
		local startY = cy - 3

		local grid = {
			{ 1, 2, 3 },
			{ 4, 5, 6 },
			{ 7, 8, 9 },
		}

		-- Draw 1-9
		for r, row in ipairs(grid) do
			for c, val in ipairs(row) do
				local bx = startX + (c - 1) * (btnW + gap)
				local by = startY + (r - 1) * (btnH + gap)
				layers.ui:addButton(bx, by, btnW, btnH, tostring(val), BUTTON_GRAY, BUTTON_TEXT, function()
					appendBet(val)
				end)
			end
		end

		-- Draw Bottom Row (C, 0, MAX)
		local by = startY + 3 * (btnH + gap)
		-- Clear
		layers.ui:addButton(startX, by, btnW, btnH, "CLR", colors.red, colors.white, function()
			currentBet = 0
		end)
		-- Zero
		layers.ui:addButton(startX + (btnW + gap), by, btnW, btnH, "0", BUTTON_GRAY, BUTTON_TEXT, function()
			appendBet(0)
		end)
		-- Max
		layers.ui:addButton(startX + 2 * (btnW + gap), by, btnW, btnH, "MAX", colors.orange, colors.black, function()
			currentBet = wallet:get()
		end)

		-- Draw Big Deal Button below keypad
		if currentBet > 0 then
			local dealW = (btnW * 3) + (gap * 2)
			layers.ui:addButton(
				startX,
				by + btnH + gap,
				dealW,
				3,
				"DEAL CARDS",
				colors.white,
				colors.black,
				startNewGame
			)
		end
	elseif state == "PLAYING" or state == "GAMEOVER" then
		-- === DEALER RENDER ===
		local dY = 6
		local dWidth = getHandWidth(#game.dealerHand.cards, false)
		local dX = math.floor((w - dWidth) / 2)

		renderer.drawHand(layers.cards, dX, dY, game.dealerHand, {
			hideFirst = not revealDealer,
			overlay = false,
			layerOffset = 0,
		})

		if state == "GAMEOVER" then
			local dValStr = "DEALER: " .. game.dealerHand:getValue()
			drawCenteredText(dY + 13, dValStr, colors.lightGray, BG_COLOR)
		end

		-- === PLAYER RENDER ===
		local pY = 23
		local totalHands = #game.playerHands
		local handSpacing = 15

		local totalGroupWidth = 0
		for _, h in ipairs(game.playerHands) do
			totalGroupWidth = totalGroupWidth + getHandWidth(#h.cards, false)
		end
		totalGroupWidth = totalGroupWidth + ((totalHands - 1) * handSpacing)

		local startX = math.floor((w - totalGroupWidth) / 2)
		local currentX = startX
		local cardUsage = #game.dealerHand.cards

		for i, hand in ipairs(game.playerHands) do
			renderer.drawHand(layers.cards, currentX, pY, hand, {
				hideFirst = false,
				overlay = false,
				layerOffset = cardUsage,
			})

			local handW = getHandWidth(#hand.cards, false)
			local centerX = math.floor(currentX + (handW / 2))

			local valStr = "VAL: " .. hand:getValue()
			local lblColor = (not revealDealer and game.activeHandIndex == i) and ACCENT_COLOR or colors.gray

			if hand.status == "busted" then
				valStr = "BUST"
				lblColor = colors.red
			elseif hand.status == "blackjack" then
				valStr = "BLACKJACK!"
				lblColor = ACCENT_COLOR
			end

			local lblX = math.floor(centerX - (#valStr / 2))
			layers.ui:addLabel(lblX, pY + 13, valStr, lblColor, BG_COLOR)

			currentX = currentX + handW + handSpacing
			cardUsage = cardUsage + #hand.cards
		end

		-- === CONTROLS ===
		local btnY = h - 4
		if state == "PLAYING" then
			local bW, bH = 8, 3
			local btnCount = 2
			if game:canDouble() then
				btnCount = btnCount + 1
			end
			if game:canSplit() then
				btnCount = btnCount + 1
			end

			local totalBtnW = (btnCount * bW) + (btnCount - 1)
			local bX = math.floor((w - totalBtnW) / 2)

			layers.ui:addButton(bX, btnY, bW, bH, "HIT", BUTTON_GRAY, BUTTON_TEXT, function()
				game:hit()
			end)
			bX = bX + bW + 1
			layers.ui:addButton(bX, btnY, bW, bH, "STAND", BUTTON_GRAY, BUTTON_TEXT, function()
				game:stand()
			end)
			bX = bX + bW + 1

			if game:canDouble() then
				layers.ui:addButton(bX, btnY, bW, bH, "DOUBLE", BUTTON_GRAY, BUTTON_TEXT, function()
					if wallet:remove(game:getActiveHand().bet) then
						game:doubleDown()
					end
				end)
				bX = bX + bW + 1
			end

			if game:canSplit() then
				layers.ui:addButton(bX, btnY, bW, bH, "SPLIT", BUTTON_GRAY, BUTTON_TEXT, function()
					if wallet:remove(game:getActiveHand().bet) then
						game:split()
					end
				end)
			end
		else
			local msg = "ROUND OVER"
			drawCenteredText(btnY - 1, msg, colors.lightGray, BG_COLOR)
			layers.ui:addButton(
				math.floor((w - 14) / 2),
				btnY,
				14,
				3,
				"NEXT ROUND",
				colors.white,
				colors.black,
				function()
					state = "BETTING"
					currentBet = 0 -- Reset bet for next round
				end
			)
		end
	end

	layers.ui:render()
	box.render()
end

while true do
	local reveal = (state == "GAMEOVER")
	updateUI(reveal)

	if game and game.isGameOver and state == "PLAYING" then
		state = "GAMEOVER"
		handlePayouts()
		updateUI(true)
	end

	local ev = { os.pullEvent() }
	if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
		layers.ui:handleEvent(ev[1], ev[2], ev[3], ev[4])
	elseif ev[1] == "key" then
		if state == "PLAYING" then
			if ev[2] == keys.h then
				game:hit()
			elseif ev[2] == keys.s then
				game:stand()
			elseif ev[2] == keys.d then
				if game:canDouble() and wallet:remove(game:getActiveHand().bet) then
					game:doubleDown()
				end
			end
		elseif state == "GAMEOVER" and ev[2] == keys.enter then
			state = "BETTING"
			currentBet = 0
		elseif state == "BETTING" then
			-- Physical keyboard support for betting
			if ev[2] >= keys.zero and ev[2] <= keys.nine then
				appendBet(ev[2] - keys.zero)
			elseif ev[2] == keys.backspace then
				currentBet = math.floor(currentBet / 10)
			elseif ev[2] == keys.enter and currentBet > 0 then
				startNewGame()
			end
		end
	end
end
