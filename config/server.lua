--- Server settings. Server only: holds the vote token.
-- @author dop42

TS.Config.SERVER = {
	-- Vote token: Top-Serveurs > your server > Gérer > « Token de votes ».
	TOKEN = '',
	-- Convar read for the token (server.jsonc `convars`); wins over TOKEN when set.
	TOKEN_CONVAR = 'topserveurs_token',

	-- Your vote page; `{name}` is replaced by the player's Open77 display name.
	VOTE_URL = 'https://top-serveurs.net/cyberpunk-2077/vote/mon-serveur',
	-- Top-Serveurs API root; its host must be in `http.allowedHosts`.
	API_URL = 'https://api.top-serveurs.net/v1',
	-- Language for players whose game is neither in French nor in English: 'fr' or 'en'.
	DEFAULT_LOCALE = 'fr',

	-- Real-time votes pushed by Top-Serveurs to `/open77_topserveurs/`.
	WEBHOOK = {
		-- Listen for votes; needs `httpHandlers` enabled in server.jsonc.
		ENABLED = true,
		-- Where Top-Serveurs publishes the addresses it sends votes from.
		TRUSTED_IP_URL = 'https://top-games.net/trusted-ip.json',
		-- Addresses used until that list is read, or when it cannot be.
		TRUSTED_IPS = { '188.165.45.67', '188.165.46.57' },
		-- Behind a reverse proxy: where the real sender address is read.
		PROXY = {
			-- The proxy's own addresses, e.g. { '127.0.0.1' }. Empty: no proxy.
			ADDRESSES = {},
			-- The header the proxy writes the sender's address in.
			HEADER = 'X-Forwarded-For',
		},
		-- Claim the pseudo at Top-Serveurs first, so `/vote` cannot count it again.
		CLAIM = true,
	},

	-- How `/vote` finds a vote, tried in this order.
	METHODS = {
		-- The voter logged in with Steam on the vote page. Most reliable.
		STEAM = true,
		-- The pseudo typed on the vote page (`/vote <pseudo>`).
		USERNAME = true,
		-- The player's address. Weakest; needs `players.identity.sensitive`.
		IP = true,
	},

	USERNAME = {
		-- `/vote` without a pseudo tries the player's Open77 display name.
		USE_DISPLAY_NAME = true,
		-- Shortest pseudo accepted.
		MIN_LENGTH = 2,
		-- Longest pseudo accepted.
		MAX_LENGTH = 32,
	},

	COOLDOWN = {
		-- Seconds between two `/vote` from the same player.
		COMMAND_SECONDS = 15,
		-- How often Top-Serveurs lets one person vote; no new check before it.
		VOTE_INTERVAL_MINUTES = 120,
	},

	-- Silent vote check, without the player typing anything.
	AUTO = {
		-- Run the automatic check.
		ENABLED = true,
		-- Check once shortly after a player joins.
		ON_JOIN = true,
		-- Seconds after joining before that first check.
		JOIN_DELAY_SECONDS = 20,
		-- Minutes between two checks of every connected player.
		INTERVAL_MINUTES = 5,
		-- Check by Steam account.
		STEAM = true,
		-- Check by address.
		IP = false,
		-- Milliseconds between two players in one check, to spare the API.
		SPACING_MS = 750,
	},

	-- "You can vote again" message.
	REMINDER = {
		-- Send reminders.
		ENABLED = true,
		-- Remind once shortly after a player joins.
		ON_JOIN = true,
		-- Seconds after joining before that reminder.
		JOIN_DELAY_SECONDS = 60,
		-- Minutes between two reminders to the same player.
		INTERVAL_MINUTES = 30,
	},

	-- How this resource talks to players.
	NOTIFY = {
		-- Toasts through open77_notifications.
		TOAST = true,
		-- Chat lines through open77_chat.
		CHAT = false,
		-- How long a toast stays on screen, in milliseconds.
		TOAST_MS = 7000,
	},

	-- Monthly top voters, read from Top-Serveurs.
	RANKING = {
		-- Enable `/vote.top` and the `GetRanking` export.
		ENABLED = false,
		-- How many voters `/vote.top` lists.
		SIZE = 10,
		-- Seconds a ranking is kept before asking the API again.
		CACHE_SECONDS = 300,
	},

	-- Send `topserveurs:client:vote` to the voter's client.
	CLIENT_EVENT = true,
	-- The server's offset from UTC in hours, for the daily streak and the month.
	UTC_OFFSET_HOURS = 1,

	HTTP = {
		-- API requests running at once; the host refuses more than 16.
		MAX_IN_FLIGHT = 8,
	},

	-- ENABLED registers the command, NAME is what players type, RESTRICTED
	-- requires `command.<NAME>` in acl.jsonc.
	COMMANDS = {
		-- Looks for the player's vote.
		VOTE = { ENABLED = true, NAME = 'vote', RESTRICTED = false },
		-- The player's vote stats.
		STATS = { ENABLED = true, NAME = 'vote.stats', RESTRICTED = false },
		-- Monthly top voters; also needs RANKING.ENABLED.
		TOP = { ENABLED = true, NAME = 'vote.top', RESTRICTED = false },
		-- Staff: configuration and a token check against the API.
		STATUS = { ENABLED = true, NAME = 'topserveurs.status', RESTRICTED = true },
		-- Staff: raises a test vote, nothing counted.
		TEST = { ENABLED = true, NAME = 'topserveurs.test', RESTRICTED = true },
		-- Staff: clears a player's vote stats.
		RESET = { ENABLED = true, NAME = 'topserveurs.reset', RESTRICTED = true },
	},

	EXPORTS = {
		-- Publish the server exports to other resources.
		ENABLED = true,
		-- Resources allowed to call `ClaimVote`, e.g. { my_resource = true }.
		WRITERS = {},
	},

	-- Log every API request and its answer. The token is never printed.
	DEBUG = false,
}
