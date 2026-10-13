## What and why

<!-- What this changes and the problem it solves. Link the issue: Fixes #123 -->

## Kind of change

- [ ] Bug fix
- [ ] Vote detection (webhook, claims, auto-check)
- [ ] Exports, events or commands
- [ ] Locales or messages
- [ ] Docs / examples only

## Checklist

- [ ] Tested on an Open77 server: startup line, `/topserveurs.status`, and `/topserveurs.test` or the
      Top-Serveurs test button.
- [ ] One vote is still raised exactly once (claimed before it is raised, repeated deliveries dropped).
- [ ] The token never reaches the console, a log or a client, `DEBUG = true` included.
- [ ] Nothing new is sent to clients from `config/server.lua`; `topserveurs:client:vote` still omits
      `license` and `steamId`.
- [ ] Every new option has its switch in `config/server.lua` and is documented in the README.
- [ ] New player text exists in both `locales/en.lua` and `locales/fr.lua`.
- [ ] `open77.lua` declares exactly the permissions the new code needs.
- [ ] Exports still answer `{ ok = true, value }` or `{ ok = false, error }`.

## Upgrade notes for server owners

<!-- New config keys, permissions, ACL entries or http hosts to add? Write "None" if a drop-in
     replacement of the folder is enough. -->
