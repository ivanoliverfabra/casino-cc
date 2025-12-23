local BASE_URL = "https://raw.githubusercontent.com/ivanoliverfabra/casino-cc/refs/heads/main/"

local commonFiles = {
	"gameLib/currency.lua",
	"gameLib/shrekbox.lua",
	"gameLib/ui.lua",
	"gameLib/bank.lua",
}

local presets = {
	blackjack = {
		"gameLib/games/blackjack.lua",
		"gameLib/deck.lua",
		"gameLib/renderer.lua",
		"blackjack.lua",
	},
	atm = {
		"atm.lua",
	},
}

local function getDir(path)
	return path:match("(.*/)") or ""
end

local function download(url)
	print("Downloading " .. url)
	local resp, err = http.get(url)
	if not resp then
		return nil, err
	end
	local content = resp.readAll()
	resp.close()
	return content
end

local function install(path)
	local url = BASE_URL .. path

	-- Support for absolute URLs if specific libraries need to be pulled from elsewhere
	if path:match("^https?://") then
		url = path
		-- Extract filename from URL for local saving if strictly a URL is passed (edge case)
		-- But assuming the list contains relative paths based on the prompt
		path = path:match(".*/(.*)")
	end

	local content, err = download(url)
	if not content then
		printError("Failed: " .. tostring(err))
		return false
	end

	local dir = getDir(path)
	if dir ~= "" and not fs.exists(dir) then
		fs.makeDir(dir)
	end

	local f = fs.open(path, "w")
	f.write(content)
	f.close()
	return true
end

local args = { ... }
local selected = args[1]

if not selected then
	print("Available presets:")
	for k in pairs(presets) do
		print(" - " .. k)
	end
	write("Select preset: ")
	selected = read()
end

local files = presets[selected]
if not files then
	printError("Invalid preset.")
	return
end

-- Combine common files and preset files
local installList = {}
for _, v in ipairs(commonFiles) do
	table.insert(installList, v)
end
for _, v in ipairs(files) do
	table.insert(installList, v)
end

local count = 0
for _, path in ipairs(installList) do
	if install(path) then
		count = count + 1
	end
	sleep(0.1)
end

print("Installed " .. count .. "/" .. #installList .. " files.")
