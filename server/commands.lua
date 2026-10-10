--- Player and staff commands.
-- @author dop42

local Commands = {}
TS.Commands = Commands

local function settings()
	return TS.Util.Settings()
end

local REFUSALS = {
	busy = { 'warning', 'busy' },
	too_fast = { 'warning', 'too_fast' },
	too_soon = { 'info', 'too_soon' },
	bad_username = { 'error', 'bad_username' },
	already_claimed = { 'info', 'already_claimed' },
	not_found = { 'info', 'not_found' },
	not_configured = { 'error', 'not_configured' },
	server_not_found = { 'error', 'not_configured' },
	api_unavailable = { 'error', 'api_unavailable' },
}

--- Tells a player how their claim went.
function Commands.Answer(playerId, result)
	if result.ok then
		TS.Notify.Send(playerId, 'success', 'claimed')
		return
	end
	local refusal = REFUSALS[result.error]
	if not refusal then return end
	local bounds = settings().USERNAME or {}
	TS.Notify.Send(playerId, refusal[1], refusal[2], {
		url = TS.Util.VoteUrl(playerId),
		minutes = result.detail,
		seconds = result.detail,
		min = bounds.MIN_LENGTH or 2,
		max = bounds.MAX_LENGTH or 32,
	})
end

local function onVote(source, args)
	local playerId = TS.Util.PlayerId(source)
	if not playerId then return print('vote: run it in game') end
	local username = args[1]
	if username == '' then username = nil end
	TS.Notify.Send(playerId, 'info', 'checking')
	TS.Claims.Request(playerId, { username = username }, function(result)
		Commands.Answer(playerId, result)
	end)
end

local function onStats(source)
	local playerId = TS.Util.PlayerId(source)
	if not playerId then return print('vote.stats: run it in game') end
	local locale = TS.Util.Locale(playerId)
	local license = TS.Identity.License(playerId)
	local record = license and TS.Storage.GetVoter(license)
	if not record then
		return TS.Notify.Send(playerId, 'info', 'stats_none', { url = TS.Util.VoteUrl(playerId) })
	end
	local now = TS.Util.Now()
	local minutes = TS.Claims.MinutesLeft(record, now)
	local monthly = record.month == TS.Util.Month(now) and record.monthly or 0
	local streak = (record.day and TS.Util.Day(now) - record.day <= 1) and record.streak or 0
	TS.Notify.Send(playerId, 'info', 'stats', {
		total = record.total,
		monthly = monthly,
		streak = streak,
		next = minutes > 0 and TS.Text(locale, 'stats_next_in', { minutes = minutes })
			or TS.Text(locale, 'stats_next_now'),
	})
end

local function onTop(source, args)
	local playerId = TS.Util.PlayerId(source)
	local locale = TS.Util.Locale(playerId)
	local kind = args[1] == 'last' and 'lastMonth' or 'current'
	local result = TS.Util.Await(function(done) TS.Api.Ranking(kind, done) end)
	if not result or not result.ok then
		return TS.Notify.Send(playerId, 'error', 'api_unavailable')
	end
	if #result.value == 0 then return TS.Notify.Send(playerId, 'info', 'top_empty') end
	local lines = { TS.Text(locale, 'top_header') }
	local size = math.tointeger(tonumber(settings().RANKING and settings().RANKING.SIZE)) or 10
	for rank = 1, math.min(size, #result.value) do
		local row = result.value[rank]
		lines[#lines + 1] = TS.Text(locale, 'top_row', { rank = rank, name = row.name, votes = row.votes })
	end
	TS.Notify.Lines(playerId, lines)
end

local function reply(source, text)
	local playerId = TS.Util.PlayerId(source)
	if playerId then
		Open77.chat.send(playerId, { author = 'topserveurs', text = text, color = { 0, 200, 255 } })
	else
		print(text)
	end
end

local function onStatus(source)
	local token = TS.Util.Token()
	local load = TS.Api.Load()
	reply(source, ('%s %s · token %s · methods %s · auto %s · http %d running, %d queued'):format(
		TS.NAME, TS.VERSION, token and 'set' or 'MISSING',
		table.concat(TS.Util.Methods(settings().METHODS), ','),
		(settings().AUTO or {}).ENABLED and 'on' or 'off', load.inFlight, load.queued))
	if not token then return end
	local result = TS.Util.Await(function(done) TS.Api.Server(done) end)
	if not result then return reply(source, 'api: no answer in time') end
	if not result.ok then
		return reply(source, ('api: %s (%s)'):format(tostring(result.error), tostring(result.detail or '')))
	end
	local server = result.value
	reply(source, ('api: ok · %s · %s votes this month'):format(
		tostring(server.name or server.title or server.slug or '?'),
		tostring(server.votes or server.monthly_votes or server.votes_count or '?')))
end

local function onTest(source, args)
	local value = args[1]
	if value == nil or value == '' then
		return reply(source, ('usage: /%s <playerId|pseudo>'):format(settings().COMMANDS.TEST.NAME))
	end
	local target = TS.Util.PlayerId(value)
	if target and not Open77.players.name(target) then target = nil end
	local vote = TS.Votes.Dispatch({
		source = 'test',
		method = 'test',
		playerId = target,
		playername = not target and value or nil,
		test = true,
	})
	reply(source, ('test vote raised for %s (player %s, would be vote #%d) -- not counted'):format(
		tostring(vote.playername), target and tostring(target) or 'offline', vote.total))
end

local function onReset(source, args)
	local value = args[1]
	local target = TS.Util.PlayerId(value)
	local license = target and Open77.players.name(target) and TS.Identity.License(target)
	if not license and type(value) == 'string' and value:match('^[%x%-]+$') and #value >= 16 then
		license = value
	end
	if not license then
		return reply(source, ('usage: /%s <playerId|licence>'):format(settings().COMMANDS.RESET.NAME))
	end
	local removed = TS.Storage.ResetVoter(license)
	Open77.log.info(('ledger reset for %s by %s'):format(license, tostring(source)))
	reply(source, removed and 'voter reset' or 'nothing to reset')
end

local HANDLERS = {
	VOTE = onVote,
	STATS = onStats,
	TOP = onTop,
	STATUS = onStatus,
	TEST = onTest,
	RESET = onReset,
}

--- Registers every configured command once.
function Commands.Register()
	for key, handler in pairs(HANDLERS) do
		local spec = (settings().COMMANDS or {})[key]
		local wanted = spec and spec.ENABLED ~= false and (key ~= 'TOP' or (settings().RANKING or {}).ENABLED)
		if wanted and type(spec.NAME) == 'string' and spec.NAME ~= '' then
			RegisterCommand(spec.NAME, function(source, args, raw)
				CreateThread(function()
					local ok, why = pcall(handler, source, args or {}, raw)
					if not ok then Open77.log.error(('/%s raised: %s'):format(spec.NAME, tostring(why))) end
				end)
			end, spec.RESTRICTED == true)
		end
	end
end
