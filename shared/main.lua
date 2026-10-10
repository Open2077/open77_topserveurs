--- Shared namespace, event names and result helpers.
-- @author dop42

TS = {
	NAME = GetCurrentResourceName(),
	VERSION = '1.0.0',
	Config = {},
	Locales = {},
}

--- Server bus events (`VOTE`, `READY`) and the voter's client event.
TS.Event = {
	VOTE = 'topserveurs:vote',
	CLIENT_VOTE = 'topserveurs:client:vote',
	READY = 'topserveurs:ready',
}

--- A success.
-- @return table `{ ok = true, value = value }`
function TS.Ok(value)
	return { ok = true, value = value }
end

--- A refusal with a code a caller can branch on.
-- @param error string a stable code, never a sentence
-- @param detail any optional context for the log
-- @return table `{ ok = false, error = error, detail = detail }`
function TS.Err(error, detail)
	return { ok = false, error = error, detail = detail }
end
