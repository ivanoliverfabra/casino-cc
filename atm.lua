local bank = require("gameLib.bank")
local ui = require("gameLib.ui")
local shrekbox = require("gameLib.shrekbox")
local currency = require("gameLib.currency")

-- === CONFIGURATION ===
local BANK_URL = "http://localhost:3000"
local BANK_KEY = "sk_casino_super_secret_key"

-- === PERIPHERALS ===
local detector = peripheral.find("playerDetector")
if not detector then
	error("Player Detector not found!")
end

local monitor = peripheral.find("monitor")
if not monitor then
	error("Monitor not found!")
end
monitor.setTextScale(0.5)

-- Inventory Setup
-- 'buffer': The chest the player accesses
-- 'vault': The secure storage (connect via modem)
local buffer = peripheral.wrap("top") -- Adjust side (top, bottom, left, right)
local vault = peripheral.wrap("back") -- Adjust side or use name "minecraft:chest_5"

if not buffer then
	error("Buffer chest not found (top)!")
end
if not vault then
	error("Vault chest not found (back/modem)!")
end

-- === DISPLAY SETUP ===
local w, h = monitor.getSize()
local win = window.create(monitor, 1, 1, w, h)
local box = shrekbox.new(win)
bank.setup(BANK_URL, BANK_KEY)

local layers = {
	ui = ui.new(box.add_text_layer(150, "ui_layer")),
}

-- === STATE ===
local state = "IDLE"
local currentUser = nil
local message = ""
local processing = false

-- === PHYSICAL ITEM LOGIC ===

-- Moves items from Buffer -> Vault and returns total value found
local function processPhysicalDeposit()
	local totalValue = 0
	local itemsMoved = 0

	-- Scan buffer chest
	for slot, item in pairs(buffer.list()) do
		local val = currency.getValue(item.name)
		if val > 0 then
			-- It's a valid coin
			local pushed = buffer.pushItems(peripheral.getName(vault), slot)
			if pushed > 0 then
				totalValue = totalValue + (val * pushed)
				itemsMoved = itemsMoved + pushed
			end
		else
			-- Optional: Eject invalid items? For now we just ignore them
		end
	end

	return totalValue, itemsMoved
end

-- Moves items from Vault -> Buffer based on amount
local function processPhysicalWithdraw(amount)
	-- 1. Calculate what items we need
	local coinsNeeded = currency.breakdown(amount)
	local movedValue = 0

	-- 2. Find and move them from vault
	for _, need in ipairs(coinsNeeded) do
		local remainingCount = need.count

		-- Scan vault for this specific item
		for slot, item in pairs(vault.list()) do
			if item.name == need.coin.mod_id then
				local limit = math.min(item.count, remainingCount)
				local pushed = vault.pushItems(peripheral.getName(buffer), slot, limit)

				remainingCount = remainingCount - pushed
				movedValue = movedValue + (pushed * need.coin.value)

				if remainingCount <= 0 then
					break
				end
			end
		end

		if remainingCount > 0 then
			return false, "Vault low on " .. need.coin.name
		end
	end

	return true, movedValue
end

-- === AUTH HELPER ===
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
		currentUser = {
			username = data.username or username,
			balance = data.balance,
		}
		state = "MENU"
		message = ""
	else
		state = "IDLE"
		print("Login Error: " .. tostring(data))
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

-- === UI RENDERER ===
local function drawCentered(y, text, fg, bg)
	local x = math.floor((w - #text) / 2)
	layers.ui:addLabel(x, y, text, fg, bg)
end

local function updateUI()
	layers.ui.layer.clear()
	layers.ui:clear()
	box.fill(colors.black)

	if state == "IDLE" then
		drawCentered(h / 2 - 2, "CASINO ATM", colors.yellow, colors.black)
		drawCentered(h / 2, "CLICK BLOCK TO LOGIN", colors.white, colors.black)
		if message ~= "" then
			drawCentered(h / 2 + 4, message, colors.red, colors.black)
		end
	elseif state == "MENU" then
		layers.ui:addLabel(2, 2, "USER: " .. currentUser.username, colors.white, colors.black)
		drawCentered(4, "BALANCE", colors.lightGray, colors.black)
		drawCentered(6, "$" .. tostring(currentUser.balance), colors.yellow, colors.black)

		if message ~= "" then
			drawCentered(8, message, colors.cyan, colors.black)
		end

		local btnW = 18
		local cx = math.floor(w / 2 - btnW / 2)

		layers.ui:addButton(cx, 11, btnW, 3, "DEPOSIT ALL", colors.green, colors.white, function()
			if processing then
				return
			end
			processing = true
			message = "Scanning items..."
			updateUI() -- Update screen immediately

			local val, count = processPhysicalDeposit()

			if val > 0 then
				local success, err = bank.deposit(currentUser.username, val)
				if success then
					refreshBalance()
					message = "Deposited $" .. val
				else
					message = "API Error: " .. tostring(err)
					-- Ideally move items back here, but simplified for now
				end
			else
				message = "No valid coins found."
			end
			processing = false
		end)

		layers.ui:addButton(cx, 15, btnW, 3, "WITHDRAW...", colors.orange, colors.black, function()
			state = "WITHDRAW"
			message = ""
		end)

		layers.ui:addButton(cx, 21, btnW, 3, "LOGOUT", colors.red, colors.white, function()
			state = "IDLE"
			currentUser = nil
			message = ""
		end)
	elseif state == "WITHDRAW" then
		drawCentered(3, "Select Amount", colors.white, colors.black)
		if message ~= "" then
			drawCentered(5, message, colors.red, colors.black)
		end

		local amounts = { 10, 50, 100, 500, 1000, 5000 }

		-- Grid for amounts
		local startX = 3
		local startY = 7
		local btnW = 10
		local gap = 1

		for i, amt in ipairs(amounts) do
			local col = (i - 1) % 2
			local row = math.floor((i - 1) / 2)

			local x = math.floor(w / 2) + (col == 0 and -(btnW + 1) or 1)
			local y = startY + (row * 4)

			layers.ui:addButton(x, y, btnW, 3, "$" .. amt, colors.gray, colors.white, function()
				if processing then
					return
				end
				processing = true
				message = "Dispensing..."
				updateUI()

				-- 1. Check API Balance first
				if currentUser.balance < amt then
					message = "Insufficient funds!"
					processing = false
					return
				end

				-- 2. Try moving items
				local moved, valOrErr = processPhysicalWithdraw(amt)

				if moved then
					-- 3. Deduct from Bank
					local success, apiErr = bank.withdraw(currentUser.username, amt)
					if success then
						refreshBalance()
						state = "MENU"
						message = "Withdrawn $" .. amt
					else
						message = "API Error: " .. tostring(apiErr)
						-- Items dispensed but API failed.
						-- In real world, log this critical error.
					end
				else
					message = "ATM Empty: " .. tostring(valOrErr)
				end
				processing = false
			end)
		end

		layers.ui:addButton(2, h - 4, 8, 3, "BACK", colors.red, colors.white, function()
			state = "MENU"
			message = ""
		end)
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
		updateUI()
		local ev = { os.pullEvent() }
		if ev[1] == "mouse_click" or ev[1] == "monitor_touch" then
			layers.ui:handleEvent(ev[1], ev[2], ev[3], ev[4])
		end
	end
end

parallel.waitForAny(loopClicks, loopUI)
