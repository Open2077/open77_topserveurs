--- Server helpers: settings, token, text, calendar, waiting.
-- @author dop42

local Util = {}
TS.Util = Util

--- The server settings, read at the point of use so a reload picks them up.
-- @return table
function Util.Settings()
	return TS.Config.SERVER or {}
end

--- One journal line when DEBUG is on.
function Util.Debug(message)
	if Util.Settings().DEBUG then Open77.log.info('[debug] ' .. tostring(message)) end
end

--- The vote token: the convar when it is set, else the config value.
-- @return string|nil
function Util.Token()
	local settings = Util.Settings()
	local fromConvar = ''
	if type(settings.TOKEN_CONVAR) == 'string' and settings.TOKEN_CONVAR ~= '' then
		local read, value = pcall(GetConvar, settings.TOKEN_CONVAR, '')
		if read and type(value) == 'string' then fromConvar = value end
	end
	local token = fromConvar ~= '' and fromConvar or settings.TOKEN
	if type(token) ~= 'string' then return nil end
	token = token:match('^%s*(.-)%s*$')
	if token == '' then return nil end
	return token
end

--- Wall-clock seconds, whole.
function Util.Now()
	return math.floor(Open77.time.unix())
end

--- A player id from a host event or a command, or nil.
-- @return integer|nil
function Util.PlayerId(value)
	local id = math.tointeger(tonumber(value))
	if not id or id < 1 then return nil end
	return id
end

--- Percent-encodes a query value.
function Util.UrlEncode(value)
	return (tostring(value):gsub('[^%w%-%._~]', function(char)
		return ('%%%02X'):format(char:byte())
	end))
end

local function civil(days)
	local z = days + 719468
	local era = (z >= 0 and z or z - 146096) // 146097
	local doe = z - era * 146097
	local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
	local y = yoe + era * 400
	local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
	local mp = (5 * doy + 2) // 153
	local d = doy - (153 * mp + 2) // 5 + 1
	local m = mp < 10 and mp + 3 or mp - 9
	if m <= 2 then y = y + 1 end
	return y, m, d
end

--- The server's day number for a unix time, shifted by UTC_OFFSET_HOURS.
-- @return integer
function Util.Day(unix)
	local offset = (tonumber(Util.Settings().UTC_OFFSET_HOURS) or 0) * 3600
	return (math.floor(unix) + math.floor(offset)) // 86400
end

--- The server's month for a unix time, as 'YYYY-MM'.
-- @return string
function Util.Month(unix)
	local y, m = civil(Util.Day(unix))
	return ('%04d-%02d'):format(y, m)
end

--- 'YYYY-MM-DD HH:MM:SS' in server time, the shape the webhook's Date has.
-- @return string
function Util.DateTime(unix)
	local offset = math.floor((tonumber(Util.Settings().UTC_OFFSET_HOURS) or 0) * 3600)
	local shifted = math.floor(unix) + offset
	local y, m, d = civil(shifted // 86400)
	local seconds = shifted % 86400
	return ('%04d-%02d-%02d %02d:%02d:%02d'):format(y, m, d, seconds // 3600, seconds % 3600 // 60, seconds % 60)
end

--- The language to answer a player in: 'fr' or 'en'.
-- @return string
function Util.Locale(playerId)
	local fallback = Util.Settings().DEFAULT_LOCALE
	if not TS.Locales[fallback] then fallback = 'fr' end
	local id = Util.PlayerId(playerId)
	if not id then return fallback end
	local read, locale = pcall(Open77.players.locale, id)
	if not read or type(locale) ~= 'table' or type(locale.code) ~= 'string' then return fallback end
	local language = locale.code:sub(1, 2):lower()
	return TS.Locales[language] and language or fallback
end

--- A localised line with `{placeholders}` filled from params.
-- @param locale string 'fr' | 'en'
-- @return string
function TS.Text(locale, key, params)
	local strings = TS.Locales[locale] or TS.Locales.fr or {}
	local text = strings[key] or (TS.Locales.en or {})[key] or key
	if type(params) == 'table' then
		text = text:gsub('{(%w+)}', function(name)
			local value = params[name]
			if value == nil then return '{' .. name .. '}' end
			return tostring(value)
		end)
	end
	return text
end

--- The vote page for a player, with their name filled in where it asks.
function Util.VoteUrl(playerId)
	local url = tostring(Util.Settings().VOTE_URL or '')
	if url:find('{name}', 1, true) then
		local id = Util.PlayerId(playerId)
		local name = id and Open77.players.name(id) or ''
		url = url:gsub('{name}', function() return Util.UrlEncode(name) end)
	end
	return url
end

--- Runs `start(done)` and waits for `done(value)` to be called.
-- @param timeoutMs number gives up and answers nil past this
function Util.Await(start, timeoutMs)
	local finished, answer = false, nil
	start(function(value)
		if finished then return end
		finished, answer = true, value
	end)
	local deadline = GetGameTimer() + (timeoutMs or 30000)
	while not finished and GetGameTimer() < deadline do Wait(50) end
	return answer
end

--- The enabled methods of a `{ STEAM, USERNAME, IP }` table, in trying order.
-- @return table list of 'steam' | 'username' | 'ip'
function Util.Methods(flags)
	local list = {}
	flags = flags or {}
	if flags.STEAM then list[#list + 1] = 'steam' end
	if flags.USERNAME then list[#list + 1] = 'username' end
	if flags.IP then list[#list + 1] = 'ip' end
	return list
end

--- Copies a list of strings into a set.
function Util.Set(list)
	local set = {}
	if type(list) == 'table' then
		for _, value in ipairs(list) do set[value] = true end
	end
	return set
end
