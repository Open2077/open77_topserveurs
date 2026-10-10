--- Server exports for other resources.
-- @author dop42

if (TS.Util.Settings().EXPORTS or {}).ENABLED == false then return end

local function writer()
	local caller = GetInvokingResource()
	local allowed = (TS.Util.Settings().EXPORTS or {}).WRITERS or {}
	if caller and (allowed[caller] or allowed['*']) then return true end
	Open77.log.warn(('export write refused to %s: add it to EXPORTS.WRITERS in config/server.lua')
		:format(tostring(caller)))
	return false
end

local function guard(fn)
	return function(...)
		local ok, answer = pcall(fn, ...)
		if not ok then
			Open77.log.error('export raised: ' .. tostring(answer))
			return TS.Err('internal')
		end
		return answer
	end
end

local function licenseOf(target)
	local playerId = TS.Util.PlayerId(target)
	if playerId and Open77.players.name(playerId) then return TS.Identity.License(playerId) end
	if type(target) == 'string' and target:match('^[%x%-]+$') and #target >= 16 then return target end
	return nil
end

--- `GetVoter(playerId | licence)`: the player's vote stats, or `not_found`.
exports('GetVoter', guard(function(target)
	local license = licenseOf(target)
	if not license then return TS.Err('invalid_target') end
	local record = TS.Storage.GetVoter(license)
	if not record then return TS.Err('not_found') end
	local now = TS.Util.Now()
	return TS.Ok({
		total = record.total,
		last = record.last,
		streak = record.streak,
		monthly = record.month == TS.Util.Month(now) and record.monthly or 0,
		month = record.month,
		minutesLeft = TS.Claims.MinutesLeft(record, now),
	})
end))

--- `CanVote(playerId | licence)` -> true when the vote interval has passed.
exports('CanVote', guard(function(target)
	local license = licenseOf(target)
	if not license then return TS.Err('invalid_target') end
	return TS.Ok(TS.Claims.MinutesLeft(TS.Storage.GetVoter(license), TS.Util.Now()) == 0)
end))

--- `GetVoteUrl(playerId?)` -> the vote page.
exports('GetVoteUrl', guard(function(playerId)
	return TS.Ok(TS.Util.VoteUrl(playerId))
end))

--- `GetRanking('current' | 'lastMonth')` -> list of `{ name, votes }`.
exports('GetRanking', guard(function(kind)
	if not (TS.Util.Settings().RANKING or {}).ENABLED then return TS.Err('ranking_disabled') end
	local result = TS.Util.Await(function(done) TS.Api.Ranking(kind, done) end)
	return result or TS.Err('api_unavailable')
end))

--- `ClaimVote(playerId, username?)`: the vote found, or a refusal code. Awaits.
exports('ClaimVote', guard(function(playerId, username)
	if not writer() then return TS.Err('caller_denied') end
	local result = TS.Util.Await(function(done)
		TS.Claims.Request(playerId, { username = username }, done)
	end)
	return result or TS.Err('api_unavailable')
end))

--- `GetStatus()` -> `{ version, tokenSet, webhook = route|nil, methods }`.
exports('GetStatus', guard(function()
	return TS.Ok({
		version = TS.VERSION,
		tokenSet = TS.Util.Token() ~= nil,
		webhook = TS.Webhook.Route(),
		methods = TS.Util.Methods(TS.Util.Settings().METHODS),
	})
end))
