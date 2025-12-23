local api = {}

--- Helper to deeply merge defaults into the loaded config
--- This ensures that if the config file is missing new keys, they are added from defaults.
local function mergeDefaults(loaded, defaults)
	if type(loaded) ~= "table" then
		return defaults
	end
	for k, v in pairs(defaults) do
		if loaded[k] == nil then
			loaded[k] = v
		elseif type(v) == "table" and type(loaded[k]) == "table" then
			mergeDefaults(loaded[k], v)
		end
	end
	return loaded
end

--- Load configuration from a file
--- @param path string The filename (e.g. "blackjack_config.json")
--- @param defaults table The default values to use if file doesn't exist
--- @return table The configuration table
function api.load(path, defaults)
	if not fs.exists(path) then
		-- File doesn't exist, create it with defaults
		api.save(path, defaults)
		return defaults
	end

	local f = fs.open(path, "r")
	local content = f.readAll()
	f.close()

	local data = textutils.unserializeJSON(content)

	-- If file is corrupt or empty, return defaults
	if not data then
		return defaults
	end

	-- Merge in case the defaults have updated keys that the file lacks
	local merged = mergeDefaults(data, defaults)

	-- Save back to update the file with any new keys
	api.save(path, merged)

	return merged
end

--- Save configuration to a file
--- @param path string
--- @param data table
function api.save(path, data)
	local f = fs.open(path, "w")
	f.write(textutils.serializeJSON(data))
	f.close()
end

return api
