--- Player messages through toasts or chat.
-- @author dop42

local Notify = {}
TS.Notify = Notify

local KIND = { success = 'success', error = 'error', info = 'info', warning = 'warning' }

local function settings()
	return TS.Util.Settings().NOTIFY or {}
end

--- Sends one line, already written, to one player.
function Notify.Raw(playerId, kind, text)
	local id = TS.Util.PlayerId(playerId)
	if not id then
		print(text)
		return
	end
	if settings().TOAST then
		local sent, reason = Open77.notifications.send(id, {
			type = KIND[kind] or 'info',
			title = TS.Text(TS.Util.Locale(id), 'title'),
			message = text,
			durationMs = math.tointeger(tonumber(settings().TOAST_MS)) or 7000,
		})
		if not sent then TS.Util.Debug('toast refused: ' .. tostring(reason)) end
	end
	if settings().CHAT then
		Open77.chat.send(id, { author = TS.Text(TS.Util.Locale(id), 'title'), text = text, color = { 0, 200, 255 } })
	end
end

--- Sends one localised line to one player (or prints it for the console).
function Notify.Send(playerId, kind, key, params)
	local id = TS.Util.PlayerId(playerId)
	Notify.Raw(id, kind, TS.Text(TS.Util.Locale(id), key, params))
end

--- Sends several chat lines to one player, in order.
function Notify.Lines(playerId, lines)
	local id = TS.Util.PlayerId(playerId)
	for _, line in ipairs(lines) do
		if id then
			Open77.chat.send(id, { author = TS.Text(TS.Util.Locale(id), 'title'), text = line, color = { 0, 200, 255 } })
			Wait(0)
		else
			print(line)
		end
	end
end
