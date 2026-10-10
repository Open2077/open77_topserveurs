--- Startup, join and leave handlers, sweeps and reminders.
-- @author dop42

local function settings()
	return TS.Util.Settings()
end

local joinedAt = {}
local remindedAt = {}

local function claimSilently(playerId)
	local methods = TS.Util.Methods({ STEAM = (settings().AUTO or {}).STEAM, IP = (settings().AUTO or {}).IP })
	if #methods == 0 then return end
	TS.Claims.Request(playerId, { auto = true, methods = methods }, function(result)
		if result.ok then TS.Commands.Answer(playerId, result) end
	end)
end

local function remind(playerId)
	local license = TS.Identity.License(playerId)
	if not license then return end
	if TS.Claims.MinutesLeft(TS.Storage.GetVoter(license), TS.Util.Now()) > 0 then return end
	remindedAt[playerId] = GetGameTimer()
	TS.Notify.Send(playerId, 'info', 'reminder', { url = TS.Util.VoteUrl(playerId) })
end

local function sweep()
	local auto = settings().AUTO or {}
	local spacing = math.max(0, math.tointeger(tonumber(auto.SPACING_MS)) or 750)
	for _, playerId in ipairs(Open77.players.all() or {}) do
		local id = TS.Util.PlayerId(playerId)
		if id and Open77.players.name(id) then
			local license = TS.Identity.License(id)
			if license and TS.Claims.MinutesLeft(TS.Storage.GetVoter(license), TS.Util.Now()) == 0 then
				claimSilently(id)
				Wait(spacing)
			end
		end
	end
end

local function remindAll()
	local reminder = settings().REMINDER or {}
	local intervalMs = (tonumber(reminder.INTERVAL_MINUTES) or 30) * 60000
	local now = GetGameTimer()
	for _, playerId in ipairs(Open77.players.all() or {}) do
		local id = TS.Util.PlayerId(playerId)
		if id and Open77.players.name(id) then
			local last = remindedAt[id] or joinedAt[id] or 0
			if now - last >= intervalMs then remind(id) end
		end
	end
end

local function every(name, minutes, fn)
	CreateThread(function()
		while true do
			Wait(math.max(1, tonumber(minutes()) or 5) * 60000)
			local ok, why = pcall(fn)
			if not ok then Open77.log.error(('%s raised: %s'):format(name, tostring(why))) end
		end
	end)
end

local function onPlayerReady(playerId)
	local id = TS.Util.PlayerId(playerId)
	if not id then return end
	joinedAt[id] = GetGameTimer()

	CreateThread(function()
		local auto = settings().AUTO or {}
		local reminder = settings().REMINDER or {}
		local claimDelay = math.max(0, tonumber(auto.JOIN_DELAY_SECONDS) or 20)

		Wait(claimDelay * 1000)
		if not Open77.players.name(id) then return end
		if auto.ENABLED and auto.ON_JOIN then claimSilently(id) end

		if reminder.ENABLED and reminder.ON_JOIN then
			Wait(math.max(0, (tonumber(reminder.JOIN_DELAY_SECONDS) or 60) - claimDelay) * 1000)
			if Open77.players.name(id) then remind(id) end
		end
	end)
end

local function onPlayerDisconnected(playerId)
	local id = TS.Util.PlayerId(playerId)
	if not id then return end
	joinedAt[id] = nil
	remindedAt[id] = nil
	TS.Claims.Forget(id)
end

local function banner()
	local token = TS.Util.Token()
	if not token then
		Open77.log.warn('no vote token: set TOKEN in config/server.lua or the ' ..
			tostring(settings().TOKEN_CONVAR) .. ' convar in server.jsonc. /vote answers not_configured.')
	end
	Open77.log.info(('%s %s up -- token %s, methods %s, auto-claim %s, webhook %s'):format(
		TS.NAME, TS.VERSION, token and 'set' or 'missing', table.concat(TS.Util.Methods(settings().METHODS), ','),
		(settings().AUTO or {}).ENABLED and 'on' or 'off', TS.Webhook.Route() or 'off'))
end

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName ~= TS.NAME then return end
	math.randomseed(math.floor(Open77.time.unix() * 1000) % 2147483647)

	TS.Commands.Register()
	TS.Webhook.Start()
	banner()

	AddEventHandler('onPlayerReady', onPlayerReady)
	AddEventHandler('onPlayerDisconnected', onPlayerDisconnected)

	if (settings().AUTO or {}).ENABLED then
		every('sweep', function() return (settings().AUTO or {}).INTERVAL_MINUTES end, sweep)
	end
	if (settings().REMINDER or {}).ENABLED then
		every('reminder', function() return 1 end, remindAll)
	end
	every('housekeeping', function() return 60 end, function()
		local removed = TS.Storage.Sweep(TS.Util.Now())
		if removed > 0 then TS.Util.Debug(('%d expired marks removed'):format(removed)) end
	end)

	for _, playerId in ipairs(Open77.players.all() or {}) do
		local id = TS.Util.PlayerId(playerId)
		if id then joinedAt[id] = GetGameTimer() end
	end

	TriggerEvent(TS.Event.READY, { version = TS.VERSION, webhook = TS.Webhook.Route() })
end)
