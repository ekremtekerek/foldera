class_name AdPolicy
##
## Gecis reklami ne zaman gosterilir. "Dengeli" model:
##
##   Seviye 1-10      hic reklam yok. Aliskanlik olusmadan reklam gostermek
##                    D1 retention'i en cok dusuren tek hamle.
##   Seviye 11+       her 3 seviyede bir
##   En az 90 saniye  ard arda hizli biten kolay seviyeler reklam yagmuruna
##                    donusmesin diye zaman tabanli ikinci bir tavan
##   Odullu sonrasi   oyuncu az once GONULLU reklam izlediyse hemen ustune
##                    zorunlu reklam bindirme -- en cok sinir bozan kalip bu
##   Reklamsiz IAP    tamamen kapatir (odullu reklamlar acik kalir)
##
## Saf mantik: dugum yok, zaman kaynagi disaridan verilir -> test edilebilir.

const FIRST_FREE_LEVELS := 10
const EVERY_N_LEVELS := 3
const MIN_GAP_SECONDS := 90.0
const REWARD_COOLDOWN_SECONDS := 45.0


static func should_show_interstitial(state: Dictionary) -> bool:
	if bool(state.get("ads_removed", false)):
		return false
	if int(state.get("level", 1)) <= FIRST_FREE_LEVELS:
		return false
	if int(state.get("levels_since_ad", 0)) < EVERY_N_LEVELS:
		return false
	if float(state.get("seconds_since_ad", 0.0)) < MIN_GAP_SECONDS:
		return false
	if float(state.get("seconds_since_reward", 9999.0)) < REWARD_COOLDOWN_SECONDS:
		return false
	return true


## Reklamsiz teklifini bir kere one cikarmak icin: kacinci gecis reklamindan
## sonra teklif gosterilsin.
const OFFER_AFTER_INTERSTITIALS := 5


static func should_offer_no_ads(interstitials_shown: int, ads_removed: bool, already_offered: bool) -> bool:
	if ads_removed or already_offered:
		return false
	return interstitials_shown >= OFFER_AFTER_INTERSTITIALS
