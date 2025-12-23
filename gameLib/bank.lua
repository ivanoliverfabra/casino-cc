--- @class BankAPI
local api = {}

local CONFIG = {
	url = "http://localhost:3000",
	key = "",
}

--- Initialize the bank client
function api.setup(url, privateKey)
	CONFIG.url = url:gsub("/$", "")
	CONFIG.key = privateKey
end

local function request(method, endpoint, body, requireAuth)
	local headers = { ["Content-Type"] = "application/json" }

	if requireAuth then
		if not CONFIG.key or CONFIG.key == "" then
			return false, "No Private Key configured"
		end
		headers["Authorization"] = "Bearer " .. CONFIG.key
	end

	local url = CONFIG.url .. endpoint
	local bodyStr = body and textutils.serializeJSON(body) or ""

	local response, err, errResponse
	if method == "GET" then
		response, err, errResponse = http.get(url, headers)
	elseif method == "POST" then
		response, err, errResponse = http.post(url, bodyStr, headers)
	end

	if not response then
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
	return true, textutils.unserializeJSON(raw)
end

--- Creates a new user (Auto-resolves UUID on backend)
--- @param username string Minecraft Username
function api.createUser(username)
	-- FIX: Send username in body
	return request("POST", "/users", { username = username }, false)
end

function api.getUser(username)
	return request("GET", "/users/" .. username, nil, false)
end

function api.getHistory(username)
	return request("GET", "/users/" .. username .. "/history", nil, false)
end

function api.deposit(username, amount)
	return request("POST", "/admin/users/" .. username .. "/deposit", { amount = amount }, true)
end

function api.withdraw(username, amount)
	return request("POST", "/admin/users/" .. username .. "/withdraw", { amount = amount }, true)
end

return api
