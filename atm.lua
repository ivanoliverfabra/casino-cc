local bank = require("gameLib.bank")
local ui = require("gameLib.ui")
local shrekbox = require("gameLib.shrekbox")
local currency = require("gameLib.currency")
local config = require("gameLib.config")

local DEFAULT_SETTINGS = {
	bank = {
		url = "http://localhost:3000",
		key = "sk_casino_super_secret_key",
	},
	peripherals = {
		buffer_chest = "top", -- Where player puts items
		vault_chest = "back", -- Secure storage
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

local cfg = config.load("atm_config.json", DEFAULT_SETTINGS)

local detector = peripheral.find("playerDetector")
if not detector then
	error("Player Detector not found!")
end

local monitor = peripheral.find("monitor")
if not monitor then
	error("Monitor not found!")
end
monitor.setTextScale(cfg.peripherals.monitor_scale)

local buffer = peripheral.wrap(cfg.peripherals.buffer_chest)
if not buffer then
	error("Buffer chest not found at '" .. cfg.peripherals.buffer_chest .. "'")
end

local vault = peripheral.wrap(cfg.peripherals.vault_chest)
if not vault then
	error("Vault chest not found at '" .. cfg.peripherals.vault_chest .. "'")
end

local w, h = monitor.getSize()
local win = window.create(monitor, 1, 1, w, h)
local box = shrekbox.new(win)

bank.setup(cfg.bank.url, cfg.bank.key)

local layers = {
	ui = ui.new(box.add_text_layer(150, "ui_layer")),
}

local state = "IDLE"
local currentUser = nil
local message = ""
local processing = false

local function getVaultCounts()
	local counts = {}
	for _, item in pairs(vault.list()) do
		counts[item.name] = (counts[item.name] or 0) + item.count
	end
	return counts
end

local function processPhysicalDeposit()
	local totalValue = 0
	local itemsMoved = 0

	for slot, item in pairs(buffer.list()) do
		local val = currency.getValue(item.name)
		if val > 0 then
			local pushed = buffer.pushItems(peripheral.getName(vault), slot)
			if pushed > 0 then
				totalValue = totalValue + (val * pushed)
				itemsMoved = itemsMoved + pushed
			end
		end
	end
	return totalValue, itemsMoved
end

local function processPhysicalWithdraw(requestedAmount)
	local vaultCounts = getVaultCounts()

	local sortedCoins = {}
	for _, c in ipairs(currency.COINS) do
		table.insert(sortedCoins, c)
	end
	table.sort(sortedCoins, function(a, b)
		return a.value > b.value
	end)

	local plan = {}
	local remainingReq = requestedAmount
	local totalDispenseValue = 0

	for _, coin in ipairs(sortedCoins) do
		if remainingReq >= coin.value then
			local inStock = vaultCounts[coin.mod_id] or 0
			if inStock > 0 then
				local needed = math.floor(remainingReq / coin.value)
				local take = math.min(needed, inStock)

				if take > 0 then
					plan[coin.mod_id] = take
					remainingReq = remainingReq - (take * coin.value)
					totalDispenseValue = totalDispenseValue + (take * coin.value)
				end
			end
		end
	end

	if totalDispenseValue == 0 then
		return false, 0
	end

	for coinId, countToMove in pairs(plan) do
		local needed = countToMove
		for slot, item in pairs(vault.list()) do
			if item.name == coinId then
				local limit = math.min(item.count, needed)
				local pushed = vault.pushItems(peripheral.getName(buffer), slot, limit)
				needed = needed - pushed
				if needed <= 0 then
					break
				end
			end
		end
	end

	return true, totalDispenseValue
end

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
		state = "MENU"
		message = ""
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

local function drawCentered(y, text, fg, bg)
	local x = math.floor((w - #text) / 2)
	layers.ui:addLabel(x, y, text, fg, bg)
end

local function updateUI()
	layers.ui.layer.clear()
	layers.ui:clear()
	box.fill(cfg.colors.bg)

	if state == "IDLE" then
		drawCentered(h / 2 - 2, "CASINO ATM", cfg.colors.accent, cfg.colors.bg)
		drawCentered(h / 2, "CLICK BLOCK TO LOGIN", cfg.colors.text, cfg.colors.bg)
		if message ~= "" then
			drawCentered(h / 2 + 4, message, cfg.colors.subtext, cfg.colors.bg)
		end
	elseif state == "MENU" then
		layers.ui:addLabel(2, 2, "USER: " .. currentUser.username, cfg.colors.text, cfg.colors.bg)

		drawCentered(4, "BALANCE", cfg.colors.subtext, cfg.colors.bg)
		drawCentered(6, "$" .. tostring(currentUser.balance), cfg.colors.accent, cfg.colors.bg)

		if message ~= "" then
			drawCentered(8, message, cfg.colors.text, cfg.colors.bg)
		end

		local btnW = 18
		local cx = math.floor(w / 2 - btnW / 2)

		layers.ui:addButton(cx, 11, btnW, 3, "DEPOSIT ALL", cfg.colors.success, cfg.colors.button_text, function()
			if processing then
				return
			end
			processing = true
			message = "Scanning..."
			updateUI()

			local val, _ = processPhysicalDeposit()
			if val > 0 then
				local success, err = bank.deposit(currentUser.username, val)
				if success then
					refreshBalance()
					message = "Deposited $" .. val
				else
					message = "API Error: " .. tostring(err.message or err)
				end
			else
				message = "No valid coins found."
			end
			processing = false
		end)

		layers.ui:addButton(cx, 15, btnW, 3, "WITHDRAW", colors.orange, cfg.colors.button_text, function()
			state = "WITHDRAW"
			message = ""
		end)

		layers.ui:addButton(cx, 21, btnW, 3, "LOGOUT", cfg.colors.error, cfg.colors.button_text, function()
			state = "IDLE"
			currentUser = nil
			message = ""
		end)
	elseif state == "WITHDRAW" then
		drawCentered(3, "Select Amount", cfg.colors.text, cfg.colors.bg)
		if message ~= "" then
			drawCentered(5, message, cfg.colors.subtext, cfg.colors.bg)
		end

		local amounts = { 8, 32, 64, 256, 512, 4096 }

		local startX = 3
		local startY = 7
		local btnW = 10

		for i, amt in ipairs(amounts) do
			local col = (i - 1) % 2
			local row = math.floor((i - 1) / 2)
			local x = math.floor(w / 2) + (col == 0 and -(btnW + 1) or 1)
			local y = startY + (row * 4)

			local canAfford = currentUser.balance >= amt

			local bCol = canAfford and cfg.colors.button or colors.lightGray
			local tCol = canAfford and cfg.colors.button_text or colors.gray

			layers.ui:addButton(x, y, btnW, 3, "$" .. amt, bCol, tCol, function()
				if not canAfford or processing then
					return
				end

				processing = true
				message = "Checking stock..."
				updateUI()

				local success, dispensedAmount = processPhysicalWithdraw(amt)

				if success and dispensedAmount > 0 then
					local apiSuccess, apiErr = bank.withdraw(currentUser.username, dispensedAmount)

					if apiSuccess then
						refreshBalance()
						state = "MENU"
						if dispensedAmount < amt then
							message = "ATM Low. Dispensed $" .. dispensedAmount
						else
							message = "Withdrawn $" .. dispensedAmount
						end
					else
						message = "API Error: " .. tostring(apiErr)
					end
				else
					message = "ATM Empty."
				end
				processing = false
			end)
		end

		layers.ui:addButton(2, h - 4, 8, 3, "BACK", cfg.colors.error, cfg.colors.button_text, function()
			state = "MENU"
			message = ""
		end)
	end

	layers.ui:render()
	box.render()
end

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
		updateUI()
		local ev = { os.pullEvent() }
		if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
			layers.ui:handleEvent(ev[1], ev[2], ev[3], ev[4])
		end
	end
end

parallel.waitForAny(loopClicks, loopUI)
