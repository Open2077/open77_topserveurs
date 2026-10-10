--- opx_infinity example: pays a vote in eddies, a bank bonus and an item.
-- @author dop42
--
-- Needs `EXPORTS.WRITERS = { open77_topserveurs = true }` in opx_infinity's
-- config/server.lua. Votes received offline are paid on character load.

local OPX = 'opx_infinity'

local Config = {
	Cash = 500,
	Bank = 2500,
	BankEvery = 10,
	Item = 'water',
	ItemChance = 0,
	Offline = true,
}

--- Calls an opx_infinity export and waits for its `{ ok, value | error }`.
-- @return boolean, string|nil
local function opx(export, ...)
	local pending, reason = Open77.exports.call(OPX, export, ...)
	if not pending then return false, reason end
	local answer = pending:await()
	if type(answer) ~= 'table' then return false, 'no_answer' end
	return answer.ok == true, answer.error
end

--- Pays one vote to a player whose character is loaded.
-- @return boolean false when opx refuses
local function pay(playerId, vote)
	local paid, why = opx('AddMoney', playerId, 'EDDIES', Config.Cash, 'vote')
	if not paid then
		print(('[vote] AddMoney refused for %d: %s'):format(playerId, tostring(why)))
		return false
	end

	local lines = { ('+%d eddies'):format(Config.Cash) }
	if Config.BankEvery > 0 and (vote.total or 0) > 0 and vote.total % Config.BankEvery == 0 then
		if opx('AddMoney', playerId, 'BANK', Config.Bank, 'vote_bonus') then
			lines[#lines + 1] = ('+%d bank'):format(Config.Bank)
		end
	end
	if Config.ItemChance > 0 and math.random(Config.ItemChance) == 1 then
		if opx('AddItem', playerId, Config.Item, 1) then
			lines[#lines + 1] = '+1 ' .. Config.Item
		end
	end

	local thanks = vote.locale == 'en' and 'Thanks for voting!' or 'Merci pour ton vote !'
	opx('Notify', playerId, thanks .. ' ' .. table.concat(lines, ' · '), 'success', 6000)
	return true
end

--- The KVP keys an offline vote waits under.
local function offlineKeys(license, playername)
	local keys = {}
	if license then keys[#keys + 1] = 'offline:license:' .. license end
	if playername and playername ~= '' then keys[#keys + 1] = 'offline:name:' .. playername:lower() end
	return keys
end

local function keep(vote)
	local key = offlineKeys(vote.license, vote.license == nil and vote.playername or nil)[1]
	if key then Open77.kvp.increment(key, 1) end
end

AddEventHandler('topserveurs:vote', function(vote)
	if vote.test then
		print(('[vote] test vote for %s, nothing given'):format(tostring(vote.playername)))
		return
	end
	CreateThread(function()
		if vote.playerId and pay(vote.playerId, vote) then return end
		if Config.Offline then keep(vote) end
	end)
end)

AddEventHandler('opx:on:character:loaded', function(source)
	local playerId = tonumber(source)
	if not Config.Offline or not playerId or playerId < 1 then return end
	CreateThread(function()
		local ids = Open77.players.identifiers(playerId) or {}
		local keys = offlineKeys(ids.license or ids.userId, Open77.players.name(playerId))
		for _, key in ipairs(keys) do
			local count = math.tointeger(tonumber(Open77.kvp.get(key))) or 0
			for _ = 1, count do
				if not pay(playerId, { total = 0 }) then break end
				count = count - 1
			end
			if count > 0 then Open77.kvp.set(key, count) else Open77.kvp.delete(key) end
		end
	end)
end)
