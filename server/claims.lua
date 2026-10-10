--- Finds a player's vote through each configured method.
-- @author dop42

local Claims = {}
TS.Claims = Claims

local busy = {}
local lastCommandMs = {}

local function settings()
	return TS.Util.Settings()
end

--- Whether a typed pseudo may be sent.
-- @return boolean
function Claims.ValidUsername(name)
	if type(name) ~= 'string' then return false end
	local bounds = settings().USERNAME or {}
	local min = math.tointeger(tonumber(bounds.MIN_LENGTH)) or 2
	local max = math.tointeger(tonumber(bounds.MAX_LENGTH)) or 32
	return #name >= min and #name <= max and name:match('^[%w%._%-]+$') ~= nil
end

local Methods = {}

function Methods.steam(who, reply)
	if not who.steamId then return reply('skip') end
	TS.Api.ClaimSteam(who.steamId, function(result)
		if not result.ok and result.error == 'steam_unknown' then return reply('not_found') end
		reply(result.ok and result.value or result)
	end)
end

function Methods.username(who, reply)
	local name = who.username
	if not name and (settings().USERNAME or {}).USE_DISPLAY_NAME then name = who.name end
	if not Claims.ValidUsername(name) then return reply('skip') end
	TS.Api.ClaimUsername(name, function(result)
		reply(result.ok and result.value or result)
	end)
end

function Methods.ip(who, reply)
	local address = TS.Identity.Address(who.playerId)
	if not address then return reply('skip') end
	TS.Api.CheckIp(address, function(result)
		if not result.ok then return reply(result) end
		if not result.value.voted then return reply('not_found') end
		local now = TS.Util.Now()
		local minutes = math.max(1, result.value.duration or settings().COOLDOWN.VOTE_INTERVAL_MINUTES or 120)
		reply(TS.Storage.ClaimAddress(address, now, now + minutes * 60) and 'claimable' or 'claimed')
	end)
end

Claims.Methods = Methods

--- The order methods are tried in for one request.
local function methodOrder(options)
	local base = options.methods or TS.Util.Methods(settings().METHODS)
	if not options.username or not (settings().METHODS or {}).USERNAME then return base end
	local order = { 'username' }
	for _, method in ipairs(base) do
		if method ~= 'username' then order[#order + 1] = method end
	end
	return order
end

--- Minutes left before a voter may be paid again, or 0.
-- @return integer
function Claims.MinutesLeft(record, now)
	if not record or not record.last then return 0 end
	local interval = (tonumber(settings().COOLDOWN and settings().COOLDOWN.VOTE_INTERVAL_MINUTES) or 120) * 60
	local left = record.last + interval - now
	if left <= 0 then return 0 end
	return math.max(1, math.ceil(left / 60))
end

--- Looks for a player's vote and dispatches it.
-- @param options table `{ username?, auto?, methods? }`
-- @param done function receives `Ok(vote)` or a refusal
function Claims.Request(playerId, options, done)
	options = options or {}
	done = done or function() end
	local id = TS.Util.PlayerId(playerId)
	if not id then return done(TS.Err('invalid_player')) end
	local license = TS.Identity.License(id)
	if not license then return done(TS.Err('no_identity')) end
	if busy[id] then return done(TS.Err('busy')) end

	if not options.auto then
		local cooldownMs = (tonumber(settings().COOLDOWN and settings().COOLDOWN.COMMAND_SECONDS) or 15) * 1000
		local nowMs = GetGameTimer()
		local previous = lastCommandMs[id]
		if previous and nowMs - previous < cooldownMs then
			return done(TS.Err('too_fast', math.ceil((cooldownMs - (nowMs - previous)) / 1000)))
		end
		lastCommandMs[id] = nowMs
	end

	if options.username ~= nil and not Claims.ValidUsername(options.username) then
		return done(TS.Err('bad_username'))
	end

	local minutes = Claims.MinutesLeft(TS.Storage.GetVoter(license), TS.Util.Now())
	if minutes > 0 then return done(TS.Err('too_soon', minutes)) end

	if not TS.Util.Token() then return done(TS.Err('not_configured')) end

	local who = {
		playerId = id,
		license = license,
		steamId = TS.Identity.Steam64(id),
		name = TS.Identity.Name(id),
		username = options.username,
	}
	local order = methodOrder(options)
	if #order == 0 then return done(TS.Err('not_found')) end
	local sawClaimed, apiError = false, nil
	busy[id] = true

	local function finish(result)
		busy[id] = nil
		done(result)
	end

	local step
	step = function(index)
		local method = order[index]
		if not method then
			if sawClaimed then return finish(TS.Err('already_claimed')) end
			if apiError then return finish(apiError) end
			return finish(TS.Err('not_found'))
		end
		local runner = Methods[method]
		if not runner then
			return step(index + 1)
		end
		runner(who, function(answer)
			if answer == 'claimable' then
				local online = Open77.players.name(id) ~= nil
				local sent, vote = pcall(TS.Votes.Dispatch, {
					source = 'claim',
					method = method,
					playerId = online and id or nil,
					license = license,
					playername = who.username or who.name,
				})
				if not sent then
					Open77.log.error('dispatching a claimed vote raised: ' .. tostring(vote))
					return finish(TS.Err('api_unavailable', vote))
				end
				return finish(TS.Ok(vote))
			elseif answer == 'claimed' then
				sawClaimed = true
			elseif type(answer) == 'table' and not answer.ok then
				if answer.error == 'server_not_found' or answer.error == 'not_configured' then
					return finish(answer)
				end
				apiError = TS.Err('api_unavailable', answer.error)
			end
			step(index + 1)
		end)
	end
	step(1)
end

--- Forgets a departed player's in-memory state.
function Claims.Forget(playerId)
	busy[playerId] = nil
	lastCommandMs[playerId] = nil
end
