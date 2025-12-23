local bank = require("gameLib.bank")
local ui = require("gameLib.ui")
local shrekbox = require("gameLib.shrekbox")

-- === CONFIGURATION ===
-- Ensure you have 'set allow_http true' in ComputerCraft config
local BANK_URL = "http://localhost:3000" -- Use your host IP if not using a tunnel
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

local w, h = monitor.getSize()
local win = window.create(monitor, 1, 1, w, h)
local box = shrekbox.new(win)

-- === SETUP ===
bank.setup(BANK_URL, BANK_KEY)

local layers = {
	ui = ui.new(box.add_text_layer(150, "ui_layer")),
}

-- === STATE MANAGEMENT ===
local state = "IDLE" -- IDLE, MENU, DEPOSIT, WITHDRAW
local currentUser = nil -- { username, balance }
local inputAmount = 0
local message = ""

-- === API HELPERS ===
local function loginUser(username)
	message = "Connecting..."
	-- Try to get existing user
	local ok, data = bank.getUser(username)

	if not ok then
		-- If user not found (404), try creating them
		if data == "User not found" or data == "Resource not found" then
			message = "Creating Account..."
			ok, data = bank.createUser(username)
		end
	end

	if ok then
		currentUser = {
			username = data.username or username, -- Fallback if API doesn't return username
			balance = data.balance,
		}
		state = "MENU"
		message = ""
	else
		state = "IDLE"
		-- Show error on idle screen briefly?
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

-- === KEYPAD LOGIC ===
local function appendInput(digit)
	local newVal = (inputAmount * 10) + digit
	if newVal < 10000000 then -- Visual cap
		inputAmount = newVal
	end
end

-- === UI RENDERER ===
local function drawCentered(y, text, fg, bg)
	local x = math.floor((w - #text) / 2)
	layers.ui:addLabel(x, y, text, fg, bg)
end

local function drawKeypad(cx, cy, onConfirm)
	local btnW, btnH = 5, 3
	local gap = 1
	local startX = cx - math.floor((3 * btnW + 2 * gap) / 2)
	local startY = cy

	local grid = { { 1, 2, 3 }, { 4, 5, 6 }, { 7, 8, 9 } }

	for r, row in ipairs(grid) do
		for c, val in ipairs(row) do
			local bx = startX + (c - 1) * (btnW + gap)
			local by = startY + (r - 1) * (btnH + gap)
			layers.ui:addButton(bx, by, btnW, btnH, tostring(val), colors.gray, colors.white, function()
				appendInput(val)
			end)
		end
	end

	local by = startY + 3 * (btnH + gap)
	-- Zero
	layers.ui:addButton(startX + (btnW + gap), by, btnW, btnH, "0", colors.gray, colors.white, function()
		appendInput(0)
	end)
	-- Clear
	layers.ui:addButton(startX, by, btnW, btnH, "C", colors.red, colors.white, function()
		inputAmount = 0
	end)
	-- Confirm
	layers.ui:addButton(startX + 2 * (btnW + gap), by, btnW, btnH, "OK", colors.green, colors.white, onConfirm)
end

local function updateUI()
	layers.ui.layer.clear()
	layers.ui:clear()
	box.fill(colors.black)

	if state == "IDLE" then
		drawCentered(h / 2 - 2, "WELCOME TO THE CASINO", colors.yellow, colors.black)
		drawCentered(h / 2, "CLICK BLOCK TO LOGIN", colors.white, colors.black)
		if message ~= "" then
			drawCentered(h / 2 + 4, message, colors.lightGray, colors.black)
		end
	elseif state == "MENU" then
		layers.ui:addLabel(2, 2, "USER: " .. currentUser.username, colors.white, colors.black)
		drawCentered(4, "BALANCE", colors.lightGray, colors.black)
		drawCentered(6, "$" .. tostring(currentUser.balance), colors.yellow, colors.black)

		if message ~= "" then
			drawCentered(8, message, colors.red, colors.black)
		end

		local btnW = 14
		local cx = math.floor(w / 2 - btnW / 2)

		layers.ui:addButton(cx, 12, btnW, 3, "DEPOSIT", colors.green, colors.white, function()
			state = "DEPOSIT"
			inputAmount = 0
			message = ""
		end)

		layers.ui:addButton(cx, 16, btnW, 3, "WITHDRAW", colors.orange, colors.black, function()
			state = "WITHDRAW"
			inputAmount = 0
			message = ""
		end)

		layers.ui:addButton(cx, 22, btnW, 3, "LOGOUT", colors.red, colors.white, function()
			state = "IDLE"
			currentUser = nil
			message = ""
		end)
	elseif state == "DEPOSIT" or state == "WITHDRAW" then
		local title = state == "DEPOSIT" and "DEPOSIT AMOUNT" or "WITHDRAW AMOUNT"
		drawCentered(3, title, colors.white, colors.black)

		local col = state == "DEPOSIT" and colors.green or colors.orange
		drawCentered(5, "$" .. tostring(inputAmount), col, colors.black)

		if message ~= "" then
			drawCentered(7, message, colors.red, colors.black)
		end

		drawKeypad(math.floor(w / 2), 9, function()
			if inputAmount <= 0 then
				return
			end
			message = "Processing..."
			updateUI() -- Force render

			local success, err
			if state == "DEPOSIT" then
				success, err = bank.deposit(currentUser.username, inputAmount)
			else
				success, err = bank.withdraw(currentUser.username, inputAmount)
			end

			if success then
				refreshBalance()
				state = "MENU"
				message = "Success!"
			else
				message = "Error: " .. tostring(err.message or err)
			end
		end)

		layers.ui:addButton(2, h - 4, 8, 3, "BACK", colors.red, colors.white, function()
			state = "MENU"
			message = ""
		end)
	end

	layers.ui:render()
	box.render()
end

-- === EVENT LOOPS ===
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
