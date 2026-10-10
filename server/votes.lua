--- Counts an accepted vote and raises the vote events.
-- @author dop42

local Votes = {}
TS.Votes = Votes

local function settings()
	return TS.Util.Settings()
end

local function clientView(vote)
	return {
		source = vote.source,
		method = vote.method,
		playername = vote.playername,
		date = vote.date,
		total = vote.total,
		streak = vote.streak,
		monthly = vote.monthly,
		first = vote.first,
		test = vote.test,
		locale = vote.locale,
	}
end

--- Builds, counts and raises one vote.
-- @param input table `{ source, method, playerId?, playername?, date?, test? }`
-- @return table the vote, as listeners receive it
function Votes.Dispatch(input)
	local now = TS.Util.Now()
	local playerId = TS.Util.PlayerId(input.playerId)
	if playerId and not Open77.players.name(playerId) then playerId = nil end

	local license = playerId and TS.Identity.License(playerId) or input.license
	local record
	if license and not input.test then
		record = TS.Storage.RecordVote(license, now)
	else
		record = TS.Storage.Advance(license and TS.Storage.GetVoter(license) or nil, now)
	end

	local name = playerId and TS.Identity.Name(playerId) or nil
	local vote = {
		source = input.source,
		method = input.method,
		playerId = playerId,
		playername = input.playername or name,
		date = input.date or TS.Util.DateTime(now),
		name = name,
		license = license,
		steamId = playerId and TS.Identity.Steam64(playerId) or nil,
		total = record.total,
		streak = record.streak,
		monthly = record.monthly,
		first = record.total == 1,
		votedAt = now,
		locale = TS.Util.Locale(playerId),
		test = input.test == true,
	}

	Open77.log.info(('vote: %s via %s, player %s, total %d%s'):format(
		vote.source, vote.method, playerId and tostring(playerId) or 'offline',
		vote.total, vote.test and ' (test, not counted)' or ''))

	local sent, reason = TriggerEvent(TS.Event.VOTE, vote)
	if sent == false then Open77.log.warn('topserveurs:vote not raised: ' .. tostring(reason)) end

	if playerId and settings().CLIENT_EVENT ~= false then
		TriggerClientEvent(TS.Event.CLIENT_VOTE, playerId, clientView(vote))
	end
	return vote
end
