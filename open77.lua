--- Top-Serveurs vote connector for Open77.
-- @author dop42
--
-- http.request                 Top-Serveurs API and trusted-IP list
-- http.serve                   real-time vote webhook
-- network.events               notifications and the client vote event
-- players.identity.sensitive   the `ip` method only
-- players.locale.read          answering in the player's language

resource "open77_topserveurs"
version "1.0.0"
open77_version ">=0.0.1"
auto_start true

permissions {
	"http.request",
	"http.serve",
	"network.events",
	"players.identity.sensitive",
	"players.locale.read",
}

shared_script "shared/main.lua"

server_script "config/server.lua"

server_script "locales/en.lua"
server_script "locales/fr.lua"

server_script "server/util.lua"
server_script "server/identity.lua"
server_script "server/storage.lua"
server_script "server/api.lua"
server_script "server/notify.lua"
server_script "server/votes.lua"
server_script "server/claims.lua"
server_script "server/webhook.lua"
server_script "server/commands.lua"
server_script "server/exports.lua"
server_script "server/main.lua"

server_script "example.lua"
client_script "example_client.lua"
