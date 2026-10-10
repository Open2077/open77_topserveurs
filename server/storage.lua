--- Voter ledger and short-lived marks, stored in Open77.kvp.
-- @author dop42

local Storage = {}
TS.Storage = Storage

local function readJson(key)
	local raw = Open77.kvp.get(key)
	if type(raw) ~= 'string' or raw == '' then return nil end
	local read, value = pcall(json.decode, raw)
	if not read or type(value) ~= 'table' then
		Open77.log.warn(('storage: %s does not decode, ignored'):format(key))
		return nil
	end
	return value
end

local function writeJson(key, value)
	local ok, reason = Open77.kvp.set(key, json.encode(value))
	if not ok then Open77.log.error(('storage: %s not written: %s'):format(key, tostring(reason))) end
	return ok == true
end

--- A voter's record, or nil when they never voted here.
-- @return table|nil
function Storage.GetVoter(license)
	if type(license) ~= 'string' then return nil end
	local record = readJson('voter:' .. license)
	if not record then return nil end
	record.total = math.tointeger(tonumber(record.total)) or 0
	record.last = math.tointeger(tonumber(record.last))
	record.streak = math.tointeger(tonumber(record.streak)) or 0
	record.monthly = math.tointeger(tonumber(record.monthly)) or 0
	return record
end

--- The record a paid vote at `now` leaves, from the one before it.
-- @return table
function Storage.Advance(record, now)
	record = record or {}
	local day = TS.Util.Day(now)
	local month = TS.Util.Month(now)
	local total = (tonumber(record.total) or 0) + 1
	local previousDay = tonumber(record.day)

	local streak
	if previousDay == day then
		streak = math.max(tonumber(record.streak) or 1, 1)
	elseif previousDay == day - 1 then
		streak = (tonumber(record.streak) or 0) + 1
	else
		streak = 1
	end

	local monthly = (record.month == month) and ((tonumber(record.monthly) or 0) + 1) or 1

	return {
		total = math.tointeger(total) or total,
		last = now,
		streak = math.tointeger(streak) or streak,
		day = day,
		month = month,
		monthly = math.tointeger(monthly) or monthly,
	}
end

--- Counts a paid vote and answers the new record.
-- @return table
function Storage.RecordVote(license, now)
	local record = Storage.Advance(Storage.GetVoter(license), now)
	writeJson('voter:' .. license, record)
	return record
end

--- Forgets a voter.
function Storage.ResetVoter(license)
	return Open77.kvp.delete('voter:' .. license) == true
end

--- Marks an address's vote as paid until `untilUnix`.
-- @return boolean
function Storage.ClaimAddress(address, now, untilUnix)
	local key = 'ip:' .. address
	local current = math.tointeger(tonumber(Open77.kvp.get(key)))
	if current and current > now then return false end
	Open77.kvp.set(key, math.floor(untilUnix))
	return true
end

--- Whether this webhook delivery (pseudo, date) is the first one.
-- @return boolean
function Storage.FirstDelivery(playername, date, now)
	local key = ('hook:%s|%s'):format(tostring(playername):lower():sub(1, 100), tostring(date))
	return Open77.kvp.setIfAbsent(key, math.floor(now)) == true
end

--- Removes expired address marks and day-old webhook deliveries.
function Storage.Sweep(now)
	local removed = 0
	for _, row in ipairs(Open77.kvp.find('ip:', 4096) or {}) do
		local untilUnix = math.tointeger(tonumber(row.value))
		if not untilUnix or untilUnix <= now then
			Open77.kvp.delete(row.key)
			removed = removed + 1
		end
	end
	for _, row in ipairs(Open77.kvp.find('hook:', 4096) or {}) do
		local at = math.tointeger(tonumber(row.value))
		if not at or now - at > 86400 then
			Open77.kvp.delete(row.key)
			removed = removed + 1
		end
	end
	return removed
end
