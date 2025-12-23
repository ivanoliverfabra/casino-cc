local baseUrl = "https://p.reconnected.cc/raw/"

local libraryFiles = {
	{ path = "gameLib/currency.lua", id = "VaiUlSmhm" },
	{ path = "gameLib/deck.lua", id = "HdroKcLfY" },
	{ path = "gameLib/renderer.lua", id = "vhbtjMfOa" },
	{
		path = "gameLib/shrekbox.lua",
		id = "https://codeberg.org/ShreksHellraiser/shrekbox/raw/commit/fea1b8c82a1f73284c9e92b3cac63ee1f5e9e1e2/shrekbox.lua",
	},
	{ path = "gameLib/ui.lua", id = "MWErGEScu" },
}

local presets = {
	blackjack = {
		{ path = "gameLib/games/blackjack.lua", id = "EcNnsaScY" },
		{ path = "blackjack.lua", id = "dALYoZirF" },
	},
}

local function isUrl(path)
	return path:match("^https?://") ~= nil
end

local function getDir(path)
	return path:match("(.*/)") or ""
end

local function download(url)
	local resp, err = http.get(url)
	if not resp then
		return nil, err
	end
	local content = resp.readAll()
	resp.close()
	return content
end

local function installFile(file)
	local url = isUrl(file.id) and file.id or (baseUrl .. file.id)
	print("Downloading " .. file.path)

	local body, err = download(url)
	if not body then
		printError("Failed to fetch " .. file.path .. ": " .. tostring(err))
		return false
	end

	local dir = getDir(file.path)
	if dir ~= "" and not fs.exists(dir) then
		fs.makeDir(dir)
	end

	local f = fs.open(file.path, "w")
	f.write(body)
	f.close()
	return true
end

local args = { ... }
local selectedPreset = args[1]

if not selectedPreset then
	print("Available Presets:")
	for k, v in pairs(presets) do
		print(" - " .. k)
	end
	write("Select preset: ")
	selectedPreset = read()
end

local files = presets[selectedPreset]
for k, v in pairs(libraryFiles) do
	table.insert(files, v)
end

if not files then
	printError("Preset not found: " .. tostring(selectedPreset))
	return
end

print("Installing " .. selectedPreset .. "...")
local count = 0
for _, file in ipairs(files) do
	if file.id ~= "" then
		if installFile(file) then
			count = count + 1
		end
	else
		printError("Skipping " .. file.path .. " (No ID)")
	end
	sleep(0.1)
end

print("Installed " .. count .. "/" .. #files .. " files.")
