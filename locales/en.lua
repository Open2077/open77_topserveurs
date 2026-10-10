--- English player text. Same keys as fr.lua.
-- @author dop42

TS.Locales.en = {
	title = 'Top-Serveurs',

	checking = 'Looking for your vote…',
	claimed = 'Thanks for voting! Your vote has been counted.',
	already_claimed = 'That vote was already rewarded. You can vote again later: {url}',
	not_found = 'No vote found in the last 2 hours. Vote on {url} then type /vote (or /vote <pseudo>).',
	too_soon = 'You were already rewarded. Next vote in {minutes} min.',
	too_fast = 'Wait {seconds} s before trying again.',
	busy = 'Your vote is already being checked.',
	bad_username = 'Invalid pseudo: {min} to {max} characters, letters, digits, . _ - only.',
	not_configured = 'Voting is not set up on this server. Tell an admin.',
	api_unavailable = 'Top-Serveurs is not answering right now. Try again in a few minutes.',

	reminder = 'You can vote for the server! {url} then type /vote.',

	stats = 'Votes: {total} · this month: {monthly} · streak: {streak} d · {next}',
	stats_next_now = 'you can vote now',
	stats_next_in = 'next vote in {minutes} min',
	stats_none = 'You have never voted yet. {url}',

	top_header = 'Top voters this month:',
	top_row = '#{rank} {name} — {votes} votes',
	top_empty = 'No votes this month yet.',
}
