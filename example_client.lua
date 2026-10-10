--- opx_infinity example: shows the voter's streak with an opx toast.
-- @author dop42

--- Shows a toast for a streak of two days or more.
local function showStreak(vote)
	local streak = tonumber(vote.streak) or 0
	if streak < 2 then return end
	local message = vote.locale == 'en'
		and ('%d days in a row, keep it up!'):format(streak)
		or ('%d jours d’affilée, continue !'):format(streak)
	local pending = Open77.exports.call('opx_infinity', 'ShowToast', {
		kind = 'info',
		title = 'Top-Serveurs',
		message = message,
		durationMs = 5000,
	})
	if pending then pending:await() end
end

RegisterNetEvent('topserveurs:client:vote', function(vote)
	if type(vote) ~= 'table' or vote.test then return end
	CreateThread(function() showStreak(vote) end)
end)
