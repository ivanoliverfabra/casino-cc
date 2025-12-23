--- @class BankAPI
local api = {}

local CONFIG = {
	url = "https://bankapi.olivr.cc/",
	key = "",
}

--- Initialize the bank client
--- @param url string The base URL of your API (e.g. "http://myserver:3000")
--- @param privateKey string|nil The admin private key (Required for deposit/withdraw)
function api.setup(url, privateKey)
	-- Remove trailing slash if present
	CONFIG.url = url:gsub("/$", "")
	CONFIG.key = privateKey
end

--- Helper for HTTP requests
local function request(method, endpoint, body, requireAuth)
	local headers = {
		["Content-Type"] = "application/json",
	}

	if requireAuth then
		if not CONFIG.key or CONFIG.key == "" then
			return false, "No Private Key configured"
		end
		headers["Authorization"] = "Bearer " .. CONFIG.key
	end

	local url = CONFIG.url .. endpoint
	local bodyStr = body and textutils.serializeJSON(body) or nil

	-- CC's http.post handles both POST and custom bodies, http.get is for GET
	local response, err, errResponse

	if method == "GET" then
		response, err, errResponse = http.get(url, headers)
	elseif method == "POST" then
		response, err, errResponse = http.post(url, bodyStr, headers)
	end

	-- Handle network failure (server down, invalid URL)
	if not response then
		-- Try to read error body if available (e.g. 404/400/500 from API)
		if errResponse then
			local raw = errResponse.readAll()
			errResponse.close()
			local data = textutils.unserializeJSON(raw)
			if data and data.error then
				return false, data.error
			end
		end
		return false, err or "Connection failed"
	end

	local raw = response.readAll()
	response.close()

	local data = textutils.unserializeJSON(raw)
	return true, data
end

--- Creates a new anonymous user
--- @return boolean success
--- @return table|string data User object ({uuid, balance}) or error message
function api.createUser()
	return request("POST", "/users", nil, false)
end

--- Gets a user's profile and balance
--- @param uuid string
--- @return boolean success
--- @return table|string data User object or error message
function api.getUser(uuid)
	return request("GET", "/users/" .. uuid, nil, false)
end

--- Gets transaction history
--- @param uuid string
--- @return boolean success
--- @return table|string data Array of transactions or error message
function api.getHistory(uuid)
	return request("GET", "/users/" .. uuid .. "/history", nil, false)
end

--- Deposits money into a user's account (Admin Only)
--- @param uuid string
--- @param amount number
--- @return boolean success
--- @return table|string data Updated user object or error message
function api.deposit(uuid, amount)
	return request("POST", "/admin/users/" .. uuid .. "/deposit", { amount = amount }, true)
end

--- Withdraws money from a user's account (Admin Only)
--- @param uuid string
--- @param amount number
--- @return boolean success
--- @return table|string data Updated user object or error message
function api.withdraw(uuid, amount)
	return request("POST", "/admin/users/" .. uuid .. "/withdraw", { amount = amount }, true)
end

return api
