# Open77 Top-Serveurs

`open77_topserveurs` is the official [Top-Serveurs](https://top-serveurs.net) vote addon
for Open77. It receives votes in real time, verifies them through the Top-Serveurs API,
keeps per-player vote stats, and raises an event for every vote. What a vote is worth is
yours to write: the bundled examples pay it with
[opx_infinity](https://github.com/opx77-framework/opx_infinity).

> [!NOTE]
> The resource gives nothing by itself and depends on no framework. Replace
> `example.lua` and `example_client.lua` with your own code, or listen to
> `topserveurs:vote` from another resource.

## Install

```sh
git clone https://github.com/Open2077/open77_topserveurs.git resources/open77_topserveurs
```

The directory must stay named `open77_topserveurs`. Then, in `server.jsonc`:

```jsonc
"resources": { "load": [ /* ... */ "open77_topserveurs" ] },

// Top-Serveurs > your server > Gérer > "Token de votes"
"convars": { "topserveurs_token": "YOUR_TOKEN" },

// Outbound calls to the API and the trusted-IP list (required)
"http": { "enabled": true, "allowedHosts": ["api.top-serveurs.net", "top-games.net"] },

// Real-time votes (recommended)
"httpHandlers": { "enabled": true, "listenUrl": "http://0.0.0.0:11781" }
```

Set `VOTE_URL` in `config/server.lua`, then `refresh` and `ensure open77_topserveurs` in
the server console. A healthy start logs:

```text
open77_topserveurs 1.0.0 up -- token set, methods steam,username,ip, auto-claim on, webhook /open77_topserveurs/
```

On Top-Serveurs, in your server's management page, enable **Plugin de vote v3** with
`http://SERVER_IP:11781/open77_topserveurs/` and press its test button: the console logs
`connectivity test from Top-Serveurs -- the link works`. The listener speaks plain HTTP;
behind a reverse proxy, fill `WEBHOOK.PROXY`.

With the opx_infinity examples, admit the resource in `opx_infinity/config/server.lua`:
`EXPORTS = { WRITERS = { open77_topserveurs = true } }`.

Staff commands need `command.topserveurs.status`, `command.topserveurs.test` and
`command.topserveurs.reset` in `acl.jsonc`.

## How a vote arrives

| Way | When | Identifies the player by |
|---|---|---|
| Webhook | the moment someone votes, pushed by Top-Serveurs | the pseudo typed on the vote page |
| `/vote [pseudo]` | when the player asks | Steam, then pseudo, then IP (`METHODS`) |
| Auto-check | on join, then every 5 minutes, silently | Steam, optionally IP (`AUTO`) |

A webhook request counts only from Top-Serveurs' published addresses and with the token.
A vote is claimed at Top-Serveurs before it is raised, repeated deliveries are dropped,
and nothing is checked again for `VOTE_INTERVAL_MINUTES` after a vote, so one vote is
never raised twice.

## Events

| Side | Event | Arguments |
|---|---|---|
| server | `topserveurs:vote` | `vote` |
| server | `topserveurs:ready` | `{ version, webhook }` |
| client | `topserveurs:client:vote` | `vote` without `license` and `steamId`, to the voter only |

`vote` carries `source` (`webhook`, `claim`, `test`), `method` (`webhook`, `steam`,
`username`, `ip`, `test`), `playerId` (nil when offline), `playername`, `date`, `name`,
`license`, `steamId`, `total`, `streak`, `monthly`, `first`, `votedAt`, `locale` and `test`.

```lua
AddEventHandler('topserveurs:vote', function(vote)
    if vote.test or not vote.playerId then return end
    local pending = Open77.exports.call('opx_infinity', 'AddMoney', vote.playerId, 'EDDIES', 500, 'vote')
    if pending then pending:await() end
end)
```

## Exports

| Export | Answer |
|---|---|
| `GetVoter(playerId \| licence)` | `{ total, last, streak, monthly, month, minutesLeft }` |
| `CanVote(playerId \| licence)` | `true` when the vote interval has passed |
| `GetVoteUrl(playerId?)` | the vote page |
| `GetRanking('current' \| 'lastMonth')` | `{ { name, votes }, ... }`, or `ranking_disabled` |
| `ClaimVote(playerId, pseudo?)` | the vote found, or a refusal code (`EXPORTS.WRITERS` only) |
| `GetStatus()` | `{ version, tokenSet, webhook, methods }` |

Every export answers `{ ok = true, value }` or `{ ok = false, error }`; `EXPORTS.ENABLED = false` publishes none. `GetRanking` and
`ClaimVote` wait on the API: call them with `Open77.exports.call(...):await()`.

## Commands

| Command | Access | Effect |
|---|---|---|
| `/vote [pseudo]` | everyone | looks for the player's vote |
| `/vote.stats` | everyone | total, this month, streak, next vote |
| `/vote.top [last]` | everyone | this month's (or last month's) top voters, when `RANKING.ENABLED` |
| `/topserveurs.status` | ACL | configuration and a token check against the API |
| `/topserveurs.test <id\|pseudo>` | ACL | raises a test vote (`vote.test`), nothing counted |
| `/topserveurs.reset <id\|licence>` | ACL | clears a player's stats |

## Structure

| Path | Responsibility |
|---|---|
| `open77.lua` | Manifest, scripts and permissions. |
| `config/server.lua` | Token, webhook, methods, timings, messages, commands, each feature with its `ENABLED` switch. Server only. |
| `locales/` | Player text in English and French. |
| `server/webhook.lua` | Real-time votes pushed by Top-Serveurs. |
| `server/claims.lua` | `/vote` and the auto-check through Steam, pseudo and IP. |
| `server/api.lua` | Top-Serveurs API client. |
| `server/votes.lua` | Counts a vote and raises the events. |
| `server/storage.lua` | Vote stats in the resource's KVP. |
| `server/commands.lua`, `server/exports.lua` | Commands and exports. |
| `example.lua`, `example_client.lua` | opx_infinity reward examples. |

## Things worth knowing

- **Steam is the most reliable method**: the voter logs in with Steam on the vote page and
  their Steam account is linked to their Open77 account. The IP method is the weakest
  (shared addresses, IPv4 against IPv6) and the only one needing
  `players.identity.sensitive`; set `METHODS.IP = false` and drop the permission if unused.
- **Stats live in the resource's KVP** (`data/`), capped at 4,096 entries: a few thousand
  voters.
- **The token never reaches the console**, even with `DEBUG = true`. `config/server.lua`
  is a server script and is never downloaded by clients.

## Documentation

- [Open77 docs](https://open2077.net/docs)
- [Resource setup](https://open2077.net/docs/resource-runtime)
- [Top-Serveurs API](https://api.top-serveurs.net/documentation)

## License

MIT — see [`LICENSE`](LICENSE).
