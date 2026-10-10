--- Top-Serveurs API client (https://api.top-serveurs.net/documentation).
-- @author dop42

local Api = {}
TS.Api = Api

local queue = {}
local inFlight = 0
local rankingCache = {}

local function settings()
	return TS.Util.Settings()
end

local function maxInFlight()
	return math.max(1, math.min(16, math.tointeger(tonumber(settings().HTTP and settings().HTTP.MAX_IN_FLIGHT)) or 8))
end

local function pump()
	while inFlight < maxInFlight() and #queue > 0 do
		local job = table.remove(queue, 1)
		inFlight = inFlight + 1
		local finished = false
		local function finish(status, body, headers, err)
			if finished then return end
			finished = true
			inFlight = inFlight - 1
			local ok, why = pcall(job.callback, status, body, headers, err)
			if not ok then Open77.log.error('api: callback raised: ' .. tostring(why)) end
			pump()
		end
		local accepted, reason = PerformHttpRequest(job.url, finish, 'GET', nil, {
			['Accept'] = 'application/json',
			['User-Agent'] = ('%s/%s (Open77)'):format(TS.NAME, TS.VERSION),
		})
		if not accepted then finish(0, nil, nil, reason or 'request_refused') end
	end
end

local function redact(text, token)
	if not token or token == '' then return text end
	local escaped = token:gsub('%p', '%%%0')
	return (text:gsub(escaped, '<token>'))
end

--- Builds a URL from a path (with `:token`) and a query table.
local function buildUrl(path, query, token)
	local base = tostring(settings().API_URL or 'https://api.top-serveurs.net/v1'):gsub('/+$', '')
	local url = base .. path:gsub(':token', function() return TS.Util.UrlEncode(token) end)
	local parts = {}
	if query then
		local keys = {}
		for key in pairs(query) do keys[#keys + 1] = key end
		table.sort(keys)
		for _, key in ipairs(keys) do
			local value = query[key] == ':token' and token or query[key]
			parts[#parts + 1] = TS.Util.UrlEncode(key) .. '=' .. TS.Util.UrlEncode(value)
		end
	end
	if #parts > 0 then url = url .. '?' .. table.concat(parts, '&') end
	return url
end

--- Turns one exchange into a Result.
-- @return table `Ok(data)` or a refusal
function Api.Interpret(status, body, err)
	status = tonumber(status) or 0
	if status == 0 then return TS.Err('api_unavailable', err) end

	local data
	if type(body) == 'string' and body ~= '' then
		local read, decoded = pcall(json.decode, body)
		if read and type(decoded) == 'table' then data = decoded end
	end
	if not data then
		if status >= 500 or status == 429 then return TS.Err('api_unavailable', status) end
		return TS.Err('bad_answer', status)
	end

	if data.success == true then return TS.Ok(data) end

	local code = math.tointeger(tonumber(data.code)) or status
	local message = tostring(data.message or ''):lower()
	if code == 404 and (message:find('serveur', 1, true) or message:find('server', 1, true)) then
		return TS.Err('server_not_found', data.message)
	end
	if message:find('steam', 1, true) then return TS.Err('steam_unknown', data.message) end
	if code == 404 then return TS.Err('not_found', data.message) end
	if message:find('param', 1, true) or code == 400 or code == 422 then
		return TS.Err('wrong_params', data.message)
	end
	if code >= 500 or code == 429 then return TS.Err('api_unavailable', code) end
	return TS.Err('refused', data.message or code)
end

--- Queues one GET.
local function get(path, query, callback)
	local token = TS.Util.Token()
	if not token then
		callback(TS.Err('not_configured'))
		return
	end
	local url = buildUrl(path, query, token)
	TS.Util.Debug('GET ' .. redact(url, TS.Util.UrlEncode(token)))
	queue[#queue + 1] = {
		url = url,
		callback = function(status, body, _, err)
			local result = Api.Interpret(status, body, err)
			TS.Util.Debug(('-> %s %s'):format(tostring(status),
				result.ok and 'ok' or (tostring(result.error) .. ' ' .. tostring(result.detail or ''))))
			if not result.ok and result.error == 'server_not_found' then
				Open77.log.error('Top-Serveurs does not know this token: check TOKEN / the ' ..
					tostring(settings().TOKEN_CONVAR) .. ' convar')
			end
			callback(result)
		end,
	}
	pump()
end

local CLAIMED = { [0] = 'not_found', [1] = 'claimable', [2] = 'claimed' }

local function claimAnswer(callback)
	return function(result)
		if not result.ok then
			if result.error == 'not_found' then return callback(TS.Ok('not_found')) end
			return callback(result)
		end
		local state = CLAIMED[math.tointeger(tonumber(result.value.claimed)) or -1]
		if not state then return callback(TS.Err('bad_answer', result.value.claimed)) end
		callback(TS.Ok(state))
	end
end

--- Claims a vote cast by a Steam account (decimal SteamID64).
function Api.ClaimSteam(steam64, callback)
	get('/votes/claim-steam', {
		server_token = ':token', steam_id = steam64, standard_http_code = '1',
	}, claimAnswer(callback))
end

--- Claims a vote cast under a pseudo.
function Api.ClaimUsername(playername, callback)
	get('/votes/claim-username', {
		server_token = ':token', playername = playername,
	}, claimAnswer(callback))
end

--- Whether an address voted in the last two hours: `Ok({ voted, duration })`.
function Api.CheckIp(address, callback)
	get('/votes/check-ip', { server_token = ':token', ip = address }, function(result)
		if not result.ok then
			if result.error == 'not_found' then return callback(TS.Ok({ voted = false })) end
			return callback(result)
		end
		local duration = math.tointeger(tonumber(result.value.duration))
		callback(TS.Ok({ voted = true, duration = duration }))
	end)
end

--- The server as Top-Serveurs knows it: `Ok(server table)`.
function Api.Server(callback)
	get('/servers/:token', nil, function(result)
		if not result.ok then return callback(result) end
		callback(TS.Ok(type(result.value.server) == 'table' and result.value.server or {}))
	end)
end

--- The monthly ranking ('current' or 'lastMonth'), cached: `Ok({ { name, votes } })`.
function Api.Ranking(kind, callback)
	kind = kind == 'lastMonth' and 'lastMonth' or 'current'
	local now = TS.Util.Now()
	local cached = rankingCache[kind]
	local ttl = tonumber(settings().RANKING and settings().RANKING.CACHE_SECONDS) or 300
	if cached and now - cached.at < ttl then return callback(TS.Ok(cached.list)) end

	get('/servers/:token/players-ranking', { type = kind }, function(result)
		if not result.ok then return callback(result) end
		local list = {}
		local rows = result.value.players
		if type(rows) == 'table' then
			for _, row in ipairs(rows) do
				if type(row) == 'table' then
					local name = row.playername or row.pseudo or row.username or row.name
					local votes = tonumber(row.votes or row.vote or row.count or row.total)
					if name ~= nil then
						list[#list + 1] = { name = tostring(name), votes = math.tointeger(votes) or votes or 0 }
					end
				end
			end
		end
		rankingCache[kind] = { at = now, list = list }
		callback(TS.Ok(list))
	end)
end

--- Requests waiting and running, for /topserveurs.status.
function Api.Load()
	return { queued = #queue, inFlight = inFlight }
end
