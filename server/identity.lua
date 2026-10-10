--- Player identity: licence, SteamID64, address, name.
-- @author dop42

local Identity = {}
TS.Identity = Identity

local function identifiers(playerId)
	local read, ids = pcall(Open77.players.identifiers, playerId)
	if not read or type(ids) ~= 'table' then return nil end
	return ids
end

--- The permanent account id the ledger is keyed by, or nil.
-- @return string|nil
function Identity.License(playerId)
	local ids = identifiers(playerId)
	if not ids then return nil end
	local license = ids.license or ids.userId or ids.open77
	if type(license) ~= 'string' or license == '' then return nil end
	return license
end

--- Converts the host's hexadecimal SteamID to the decimal SteamID64 string.
-- @return string|nil
function Identity.SteamHexToDecimal(value)
	if type(value) ~= 'string' then return nil end
	value = value:lower():gsub('^steam:', ''):gsub('^0x', '')
	if value:match('^7656%d%d%d%d%d%d%d%d%d%d%d%d%d$') then return value end
	if not value:match('^%x+$') or #value > 16 then return nil end
	local number = tonumber(value, 16)
	if not number or number <= 0 then return nil end
	return ('%d'):format(number)
end

--- The decimal SteamID64 of a linked Steam account, or nil.
-- @return string|nil
function Identity.Steam64(playerId)
	local ids = identifiers(playerId)
	return ids and Identity.SteamHexToDecimal(ids.steam) or nil
end

--- The bare address out of 'ip', 'ip:port', '[v6]:port' or '::ffff:ip'.
-- @return string|nil
function Identity.AddressOf(value)
	if type(value) ~= 'string' or value == '' then return nil end
	value = value:match('^%s*(.-)%s*$')
	local bracketed = value:match('^%[([%x:%.]+)%]')
	if bracketed then value = bracketed end
	local mapped = value:lower():match('^::ffff:(%d+%.%d+%.%d+%.%d+)$')
	if mapped then return mapped end
	local v4 = value:match('^(%d+%.%d+%.%d+%.%d+)')
	if v4 then return v4 end
	if value:match('^[%x:]+$') then return value:lower() end
	return nil
end

--- The address a player connects from, or nil and a reason.
-- @return string|nil, string|nil
function Identity.Address(playerId)
	local read, endpoint, reason = pcall(Open77.players.endpoint, playerId)
	if not read then return nil, 'ip_unavailable' end
	if not endpoint then return nil, reason or 'ip_unavailable' end
	local address = Identity.AddressOf(endpoint)
	if not address then return nil, 'ip_unavailable' end
	return address
end

--- The Open77 display name, or an empty string.
function Identity.Name(playerId)
	return Open77.players.name(playerId) or ''
end
