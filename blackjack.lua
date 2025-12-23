local bank = require("gameLib.bank")
local blackjack = require("gameLib.games.blackjack")
local renderer = require("gameLib.renderer")
local ui = require("gameLib.ui")
local shrekbox = require("gameLib.shrekbox")
local config = require("gameLib.config")

-- === CONFIGURATION ===
local DEFAULT_SETTINGS = {
	bank = {
		url = "http://localhost:3000",
		key = "sk_casino_super_secret_key",
	},
	peripherals = {
		monitor_scale = 0.5,
	},
	colors = {
		bg = colors.black,
		text = colors.white,
		accent = colors.yellow,
		subtext = colors.lightGray,
		error = colors.red,
		success = colors.green,
		button = colors.gray,
		button_text = colors.white,
	},
}

local cfg = config.load("blackjack_config.json", DEFAULT_SETTINGS)

-- === PERIPHERALS ===
local detector = peripheral.find("playerDetector")
if not detector then
	error("Player Detector not found!")
end

local monitor = peripheral.find("monitor")
if not monitor then
	error("Monitor not found!")
end
monitor.setTextScale(cfg.peripherals.monitor_scale)

-- === SETUP ===
local w, h = monitor.getSize()
local win = window.create(monitor, 1, 1, w, h)
local box = shrekbox.new(win)

bank.setup(cfg.bank.url, cfg.bank.key)

-- Visual Constants
local CARD_W = 11
local STACK_O = 3
local GAP_O = 12

-- Helper for centering math
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

-- === STATE ===
local state = "IDLE" -- IDLE, BETTING, PLAYING, GAMEOVER
local currentUser = nil -- { username, balance }
local game
local currentBet = 0
local message = ""
local processing = false

-- === BANK HELPERS ===

local function loginUser(username)
	message = "Connecting..."
	local ok, data = bank.getUser(username)

	if not ok then
		if data == "User not found" or data == "Resource not found" then
			message = "Creating Account..."
			ok, data = bank.createUser(username)
		end
	end

	if ok then
		currentUser = { username = data.username or username, balance = data.balance }
		state = "BETTING"
		message = ""
		currentBet = 0
	else
		state = "IDLE"
	end
end

local function refreshBalance()
	if not currentUser then
		return
	end
	local ok, data = bank.getUser(currentUser.username)
	if ok then
		currentUser.balance = data.balance
	end
end

-- === GAME LOGIC ===

local function startNewGame()
	if processing then
		return
	end

	if currentBet <= 0 then
		message = "Enter a bet!"
		return
	end

	processing = true
	message = "Processing..."

	-- Attempt Withdraw
	local success, err = bank.withdraw(currentUser.username, currentBet)

	if success then
		refreshBalance()
		game = blackjack.newGame(currentBet)
		state = "PLAYING"
		message = ""
	else
		message = "Bank Error: " .. tostring(err.message or err)
	end
	processing = false
end

local function attemptDouble()
	if processing then
		return
	end
	local hand = game:getActiveHand()
	local amt = hand.bet

	processing = true
	local success, err = bank.withdraw(currentUser.username, amt)

	if success then
		refreshBalance()
		game:doubleDown()
	else
		-- Flash error briefly?
	end
	processing = false
end

local function attemptSplit()
	if processing then
		return
	end
	local hand = game:getActiveHand()
	local amt = hand.bet

	processing = true
	local success, err = bank.withdraw(currentUser.username, amt)

	if success then
		refreshBalance()
		game:split()
	else
		-- Flash error
	end
	processing = false
end

local function handlePayouts()
	local totalWin = 0
	for _, hand in ipairs(game.playerHands) do
		totalWin = totalWin + game:calculatePayout(hand)
	end

	if totalWin > 0 then
		local success = bank.deposit(currentUser.username, totalWin)
		if success then
			refreshBalance()
		end
	end
end

-- === UI HELPERS ===

local function drawCenteredText(y, text, fg, bg)
	local x = math.floor((w - #text) / 2)
	layers.ui:addLabel(x, y, text, fg, bg)
end

local function appendBet(digit)
	local newVal = (currentBet * 10) + digit
	if newVal <= currentUser.balance then
		currentBet = newVal
	else
		currentBet = currentUser.balance
	end
end

-- === MAIN UI RENDERER ===

local function updateUI(revealDealer)
	-- Clear Graphics
	for _, l in ipairs(layers.cards) do
		l.pixel.clear()
		l.text.clear()
	end
	layers.ui.layer.clear()
	layers.ui:clear()
	box.fill(cfg.colors.bg)

	-- === IDLE SCREEN ===
	if state == "IDLE" then
		drawCenteredText(h / 2 - 2, "BLACKJACK", cfg.colors.accent, cfg.colors.bg)
		drawCenteredText(h / 2, "CLICK BLOCK TO PLAY", cfg.colors.text, cfg.colors.bg)
		if message ~= "" then
			drawCenteredText(h / 2 + 4, message, cfg.colors.subtext, cfg.colors.bg)
		end
		layers.ui:render()
		box.render()
		return
	end

	-- === SHARED HUD (Balance) ===
	layers.ui:addLabel(2, 1, "USER: " .. currentUser.username, cfg.colors.text, cfg.colors.bg)
	local balText = "BAL: $" .. currentUser.balance
	layers.ui:addLabel(w - #balText - 1, 1, balText, cfg.colors.accent, cfg.colors.bg)

	-- === BETTING SCREEN ===
	if state == "BETTING" then
		local cx = math.floor(w / 2)
		local cy = math.floor(h / 2) - 4

		drawCenteredText(cy - 8, "PLACE YOUR BET", cfg.colors.subtext, cfg.colors.bg)

		local betCol = currentBet > 0 and cfg.colors.accent or cfg.colors.subtext
		drawCenteredText(cy - 6, "$" .. tostring(currentBet), betCol, cfg.colors.bg)

		if message ~= "" then
			drawCenteredText(cy - 10, message, cfg.colors.error, cfg.colors.bg)
		end

		-- Keypad
		local btnW, btnH = 5, 3
		local gap = 1
		local startX = cx - math.floor((3 * btnW + 2 * gap) / 2)
		local startY = cy - 3

		local grid = { { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 } }

		for r, row in ipairs(grid) do
			for c, val in ipairs(row) do
				local bx = startX + (c - 1) * (btnW + gap)
				local by = startY + (r - 1) * (btnH + gap)
				layers.ui:addButton(
					bx,
					by,
					btnW,
					btnH,
					tostring(val),
					cfg.colors.button,
					cfg.colors.button_text,
					function()
						appendBet(val)
					end
				)
			end
		end

		local by = startY + 3 * (btnH + gap)
		layers.ui:addButton(startX, by, btnW, btnH, "C", cfg.colors.error, cfg.colors.button_text, function()
			currentBet = 0
		end)
		layers.ui:addButton(
			startX + (btnW + gap),
			by,
			btnW,
			btnH,
			"0",
			cfg.colors.button,
			cfg.colors.button_text,
			function()
				appendBet(0)
			end
		)
		layers.ui:addButton(
			startX + 2 * (btnW + gap),
			by,
			btnW,
			btnH,
			"MAX",
			colors.orange,
			cfg.colors.button_text,
			function()
				currentBet = currentUser.balance
			end
		)

		if currentBet > 0 then
			local dealW = (btnW * 3) + (gap * 2)
			layers.ui:addButton(
				startX,
				by + btnH + gap,
				dealW,
				3,
				"DEAL CARDS",
				cfg.colors.success,
				cfg.colors.button_text,
				startNewGame
			)
		end

		layers.ui:addButton(2, h - 4, 8, 3, "LOGOUT", cfg.colors.error, cfg.colors.button_text, function()
			state = "IDLE"
			currentUser = nil
		end)

	-- === GAMEPLAY SCREEN ===
	elseif state == "PLAYING" or state == "GAMEOVER" then
		-- Dealer
		local dY = 6
		local dWidth = getHandWidth(#game.dealerHand.cards, false)
		local dX = math.floor((w - dWidth) / 2)

		renderer.drawHand(layers.cards, dX, dY, game.dealerHand, {
			hideFirst = not revealDealer,
			overlay = false,
			layerOffset = 0,
		})

		if state == "GAMEOVER" then
			drawCenteredText(dY + 13, "DEALER: " .. game.dealerHand:getValue(), cfg.colors.subtext, cfg.colors.bg)
		end

		-- Players
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
			local lblColor = (not revealDealer and game.activeHandIndex == i) and cfg.colors.accent
				or cfg.colors.subtext

			if hand.status == "busted" then
				valStr = "BUST"
				lblColor = cfg.colors.error
			elseif hand.status == "blackjack" then
				valStr = "BLACKJACK!"
				lblColor = cfg.colors.accent
			end

			local lblX = math.floor(centerX - (#valStr / 2))
			layers.ui:addLabel(lblX, pY + 13, valStr, lblColor, cfg.colors.bg)

			currentX = currentX + handW + handSpacing
			cardUsage = cardUsage + #hand.cards
		end

		-- Controls
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

			layers.ui:addButton(bX, btnY, bW, bH, "HIT", cfg.colors.button, cfg.colors.button_text, function()
				game:hit()
			end)
			bX = bX + bW + 1
			layers.ui:addButton(bX, btnY, bW, bH, "STAND", cfg.colors.button, cfg.colors.button_text, function()
				game:stand()
			end)
			bX = bX + bW + 1

			if game:canDouble() then
				local canAfford = currentUser.balance >= game:getActiveHand().bet
				local col = canAfford and cfg.colors.button or colors.gray

				layers.ui:addButton(bX, btnY, bW, bH, "DOUBLE", col, cfg.colors.button_text, function()
					if canAfford then
						attemptDouble()
					end
				end)
				bX = bX + bW + 1
			end

			if game:canSplit() then
				local canAfford = currentUser.balance >= game:getActiveHand().bet
				local col = canAfford and cfg.colors.button or colors.gray

				layers.ui:addButton(bX, btnY, bW, bH, "SPLIT", col, cfg.colors.button_text, function()
					if canAfford then
						attemptSplit()
					end
				end)
			end
		else
			drawCenteredText(btnY - 1, "ROUND OVER", cfg.colors.subtext, cfg.colors.bg)
			layers.ui:addButton(
				math.floor((w - 14) / 2),
				btnY,
				14,
				3,
				"NEXT ROUND",
				cfg.colors.success,
				cfg.colors.button_text,
				function()
					state = "BETTING"
					if currentBet > currentUser.balance then
						currentBet = currentUser.balance
					end
				end
			)
		end
	end

	layers.ui:render()
	box.render()
end

-- === LOOPS ===

local function loopClicks()
	while true do
		local event, username = os.pullEvent("playerClick")
		if state == "IDLE" then
			loginUser(username)
		end
	end
end

local function loopUI()
	while true do
		local reveal = (state == "GAMEOVER")
		updateUI(reveal)

		if game and game.isGameOver and state == "PLAYING" then
			state = "GAMEOVER"
			handlePayouts()
			-- Render again to show game over state
			updateUI(true)
		end

		local ev = { os.pullEvent() }
		if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
			layers.ui:handleEvent(ev[1], ev[2], ev[3], ev[4])
		elseif ev[1] == "key" then
			if state == "PLAYING" and not processing then
				if ev[2] == keys.h then
					game:hit()
				elseif ev[2] == keys.s then
					game:stand()
				end
			elseif state == "BETTING" then
				if ev[2] >= keys.zero and ev[2] <= keys.nine then
					appendBet(ev[2] - keys.zero)
				elseif ev[2] == keys.backspace then
					currentBet = math.floor(currentBet / 10)
				elseif ev[2] == keys.enter and currentBet > 0 then
					startNewGame()
				end
			elseif state == "GAMEOVER" and ev[2] == keys.enter then
				state = "BETTING"
				if currentBet > currentUser.balance then
					currentBet = currentUser.balance
				end
			end
		end
	end
end

parallel.waitForAny(loopClicks, loopUI)
