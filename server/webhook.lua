--- Real-time votes pushed by Top-Serveurs (vote plugin v3).
-- @author dop42

local Webhook = {}
TS.Webhook = Webhook

local trusted = {}
local route = nil

local function settings()
	return TS.Util.Settings().WEBHOOK or {}
end

local function setTrusted(list)
	local set = {}
	for _, address in ipairs(list or {}) do
		if type(address) == 'string' and address ~= '' then set[address] = true end
	end
	trusted = set
end

--- Reads the published list of Top-Serveurs' sending addresses.
function Webhook.RefreshTrusted()
	local url = settings().TRUSTED_IP_URL
	if type(url) ~= 'string' or url == '' then return end
	PerformHttpRequest(url, function(status, body, _, err)
		if status ~= 200 then
			Open77.log.warn(('trusted-ip list not read (%s): keeping the configured addresses')
				:format(status == 0 and tostring(err) or tostring(status)))
			return
		end
		local read, data = pcall(json.decode, body or '')
		if not read or type(data) ~= 'table' or type(data.list) ~= 'table' or #data.list == 0 then
			Open77.log.warn('trusted-ip list unreadable: keeping the configured addresses')
			return
		end
		setTrusted(data.list)
		TS.Util.Debug(('trusted-ip list: %d addresses'):format(#data.list))
	end, 'GET')
end

--- The address the request really came from.
local function senderOf(req)
	local direct = TS.Identity.AddressOf(req.remoteAddress)
	local proxy = settings().PROXY or {}
	if direct and TS.Util.Set(proxy.ADDRESSES)[direct] then
		local header = req.headers and req.headers[proxy.HEADER or 'X-Forwarded-For']
		local first = type(header) == 'string' and header:match('^%s*([^,]+)')
		return TS.Identity.AddressOf(first)
	end
	return direct
end

local function sameToken(a, b)
	if type(a) ~= 'string' or type(b) ~= 'string' or #a ~= #b then return false end
	local diff = 0
	for index = 1, #a do
		if a:byte(index) ~= b:byte(index) then diff = diff + 1 end
	end
	return diff == 0
end

--- Judges one vote payload.
-- @return string|nil the reason it is refused, or nil when it is good
function Webhook.Validate(payload, token)
	if not sameToken(payload.Token, token) then return 'Wrong vote token' end
	local name = payload.Playername
	if type(name) ~= 'string' or name == '' or #name > 100 or name:find('[%c]') then
		return 'Invalid playername'
	end
	local date = payload.Date
	if type(date) ~= 'string' or not date:match('^%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d$') then
		return 'Invalid date'
	end
	return nil
end

--- The connected player whose display name is this pseudo, ignoring case.
-- @return integer|nil
function Webhook.FindPlayer(playername)
	local wanted = tostring(playername):lower()
	for _, playerId in ipairs(Open77.players.all() or {}) do
		local id = TS.Util.PlayerId(playerId)
		local name = id and Open77.players.name(id)
		if name and name:lower() == wanted then return id end
	end
	return nil
end

local function deliver(playername, date)
	local playerId = Webhook.FindPlayer(playername)
	if playerId then
		local license = TS.Identity.License(playerId)
		if license and TS.Claims.MinutesLeft(TS.Storage.GetVoter(license), TS.Util.Now()) > 0 then
			TS.Util.Debug(('webhook vote for %s skipped: already paid this interval'):format(playername))
			return
		end
	end
	TS.Votes.Dispatch({
		source = 'webhook',
		method = 'webhook',
		playerId = playerId,
		playername = playername,
		date = date
	})
	if playerId then TS.Notify.Send(playerId, 'success', 'claimed') end
end

local function onVote(payload)
	local playername, date = payload.Playername, payload.Date
	if not TS.Storage.FirstDelivery(playername, date, TS.Util.Now()) then
		TS.Util.Debug(('webhook vote for %s at %s delivered twice, dropped'):format(playername, date))
		return
	end
	if settings().CLAIM == false then return deliver(playername, date) end

	TS.Api.ClaimUsername(playername, function(result)
		if result.ok and result.value == 'claimed' then
			TS.Util.Debug(('webhook vote for %s already claimed (by /vote), silent'):format(playername))
			return
		end
		if not result.ok then
			TS.Util.Debug(('webhook claim for %s: %s, raised anyway'):format(playername, tostring(result.error)))
		end
		deliver(playername, date)
	end)
end

local function handle(req, res)
	if req.method ~= 'POST' then return res.text(405, 'Method not allowed') end
	local sender = senderOf(req)
	if not sender or not trusted[sender] then
		Open77.log.warn('webhook: refused a request from an untrusted address')
		return res.text(400, 'Receiving a vote from an untrusted IP')
	end

	local read, payload = pcall(json.decode, req.body or '')
	if not read or type(payload) ~= 'table' then return res.text(400, 'Invalid JSON') end

	if payload.Action == 'test' then
		Open77.log.info('webhook: connectivity test from Top-Serveurs -- the link works')
		return res.text(200, 'test-success')
	elseif payload.Action == 'refresh_ip' then
		Webhook.RefreshTrusted()
		return res.text(200, 'success')
	elseif payload.Action ~= 'vote' then
		return res.text(400, 'No action match the current payload')
	end

	local token = TS.Util.Token()
	if not token then return res.text(400, 'Vote token not configured') end
	local refused = Webhook.Validate(payload, token)
	if refused then
		Open77.log.warn('webhook: vote refused: ' .. refused)
		return res.text(400, refused)
	end

	res.text(200, 'success')
	CreateThread(function()
		local ok, why = pcall(onVote, payload)
		if not ok then Open77.log.error('webhook vote raised: ' .. tostring(why)) end
	end)
end

--- Starts listening.
function Webhook.Start()
	if not settings().ENABLED then return nil end
	setTrusted(settings().TRUSTED_IPS)
	Webhook.RefreshTrusted()
	local served, reason = Open77.http.listen('/', function(req, res)
		local ok, why = pcall(handle, req, res)
		if not ok then
			Open77.log.error('webhook raised: ' .. tostring(why))
			pcall(res.text, 500, 'error')
		end
	end)
	if not served then
		Open77.log.warn(('webhook off (%s): enable "httpHandlers" in server.jsonc for real-time votes; ' ..
			'/vote and the auto-claim still work'):format(tostring(reason)))
		return nil
	end
	route = served
	Open77.log.info('webhook listening on ' .. tostring(route) ..
		' -- give Top-Serveurs this address (plugin de vote v3) and press its test button')
	return route
end

--- The public route, or nil.
function Webhook.Route()
	return route
end
