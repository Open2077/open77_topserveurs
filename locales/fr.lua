--- French player text. Same keys as en.lua.
-- @author dop42

TS.Locales.fr = {
	title = 'Top-Serveurs',

	checking = 'Recherche de ton vote…',
	claimed = 'Merci pour ton vote ! Il a bien été pris en compte.',
	already_claimed = 'Ce vote a déjà été récompensé. Tu pourras revoter plus tard : {url}',
	not_found = 'Aucun vote trouvé ces 2 dernières heures. Vote sur {url} puis tape /vote (ou /vote <pseudo>).',
	too_soon = 'Tu as déjà été récompensé. Prochain vote possible dans {minutes} min.',
	too_fast = 'Patiente {seconds} s avant de réessayer.',
	busy = 'Ton vote est déjà en cours de vérification.',
	bad_username = 'Pseudo invalide : {min} à {max} caractères, lettres, chiffres, . _ - uniquement.',
	not_configured = "Le vote n'est pas configuré sur ce serveur. Préviens un admin.",
	api_unavailable = 'Top-Serveurs ne répond pas pour le moment. Réessaie dans quelques minutes.',

	reminder = 'Tu peux voter pour le serveur ! {url} puis tape /vote.',

	stats = 'Votes : {total} · ce mois : {monthly} · série : {streak} j · {next}',
	stats_next_now = 'tu peux voter maintenant',
	stats_next_in = 'prochain vote dans {minutes} min',
	stats_none = "Tu n'as encore jamais voté. {url}",

	top_header = 'Meilleurs voteurs du mois :',
	top_row = '#{rank} {name} — {votes} votes',
	top_empty = 'Aucun vote ce mois-ci pour le moment.',
}
