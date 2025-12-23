--- @diagnostic disable: missing-fields

--- @class Coin
--- @field mod_id string
--- @field value number
--- @field name string

--- @class CurrencyItem
--- @field coin Coin
--- @field count number

--- @class Wallet
--- @field balance number
--- @field add fun(self: Wallet, amount: number): number
--- @field remove fun(self: Wallet, amount: number): boolean
--- @field get fun(self: Wallet): number
--- @field getFormatted fun(self: Wallet): string

local api = {}

--- @type Coin[]
local COINS = {
	{ mod_id = "numismatics:sun", value = 4096, name = "Iridium Coin" },
	{ mod_id = "numismatics:crown", value = 512, name = "Gold Coin" },
	{ mod_id = "numismatics:cog", value = 64, name = "Brass Coin" },
	{ mod_id = "numismatics:sprocket", value = 16, name = "Iron Coin" },
	{ mod_id = "numismatics:bevel", value = 8, name = "Zinc Coin" },
	{ mod_id = "numismatics:spur", value = 1, name = "Copper Coin" },
}

api.COINS = COINS

--- @param itemId string
--- @return number
function api.getValue(itemId)
	for _, coin in ipairs(COINS) do
		if coin.mod_id == itemId then
			return coin.value
		end
	end
	return 0
end

--- @param amount number
--- @return CurrencyItem[]
function api.breakdown(amount)
	local result = {}
	local remaining = amount

	table.sort(COINS, function(a, b)
		return a.value > b.value
	end)

	for _, coin in ipairs(COINS) do
		if remaining >= coin.value then
			local count = math.floor(remaining / coin.value)
			if count > 0 then
				table.insert(result, {
					coin = coin,
					count = count,
				})
				remaining = remaining % coin.value
			end
		end
	end

	return result
end

--- @param amount number
--- @return string
function api.format(amount)
	if amount == 0 then
		return "0 Copper Coins"
	end

	local parts = api.breakdown(amount)
	local strParts = {}

	for _, item in ipairs(parts) do
		table.insert(strParts, item.count .. " " .. item.coin.name)
	end

	return table.concat(strParts, ", ")
end

--- @param requestedAmount number
--- @param availableCounts table<string, number>
--- @return table<string, number>, number
function api.planDispense(requestedAmount, availableCounts)
	local plan = {}
	local remainingReq = requestedAmount
	local totalDispenseValue = 0

	local sortedCoins = {}
	for _, c in ipairs(COINS) do
		table.insert(sortedCoins, c)
	end
	table.sort(sortedCoins, function(a, b)
		return a.value > b.value
	end)

	for _, coin in ipairs(sortedCoins) do
		if remainingReq >= coin.value then
			local inStock = availableCounts[coin.mod_id] or 0
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

	return plan, totalDispenseValue
end

--- @param initialBalance number?
--- @return Wallet
function api.newWallet(initialBalance)
	--- @type Wallet
	local wallet = {
		balance = initialBalance or 0,
	}

	function wallet:add(amount)
		self.balance = self.balance + amount
		return self.balance
	end

	function wallet:remove(amount)
		if self.balance >= amount then
			self.balance = self.balance - amount
			return true
		end
		return false
	end

	function wallet:get()
		return self.balance
	end

	function wallet:getFormatted()
		return api.format(self.balance)
	end

	return wallet
end

return api
