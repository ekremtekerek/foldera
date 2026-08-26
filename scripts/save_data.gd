extends Node
##
## Tamamen yerel ilerleme. Sunucu, hesap, internet yok.
##
## DIKKAT: `ads_removed` su an yalnizca burada tutuluyor ve bu dosya
## duzenlenebilir. Yayindan once satin alma dogrulamasi SUNUCUDA yapilmali.

const PATH := "user://foldera.cfg"

var unlocked := 1
var stars := {}              # level(int) -> yildiz(int)
var total_folds := 0
var perfect_runs := 0

var hints := HintWallet.new()
var ads_removed := false
var no_ads_offered := false
var consent := ""            # "" | "personalized" | "limited"
var lang := ""               # "" = telefonun dili
var interstitials_shown := 0
var levels_since_ad := 0
var seen := {}               # gorulmus ogretici kartlari
var install_unix := 0


func _ready() -> void:
	load_data()


func load_data() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		install_unix = int(Time.get_unix_time_from_system())
		hints.refresh(today())
		return
	unlocked = int(cf.get_value("progress", "unlocked", 1))
	var raw: Dictionary = cf.get_value("progress", "stars", {})
	stars = {}
	for k in raw:
		stars[int(k)] = int(raw[k])
	total_folds = int(cf.get_value("stats", "total_folds", 0))
	perfect_runs = int(cf.get_value("stats", "perfect_runs", 0))
	install_unix = int(cf.get_value("stats", "install_unix", Time.get_unix_time_from_system()))

	hints.from_dict(cf.get_value("econ", "hints", {}))
	ads_removed = bool(cf.get_value("econ", "ads_removed", false))
	no_ads_offered = bool(cf.get_value("econ", "no_ads_offered", false))
	interstitials_shown = int(cf.get_value("econ", "interstitials_shown", 0))
	levels_since_ad = int(cf.get_value("econ", "levels_since_ad", 0))
	consent = str(cf.get_value("privacy", "consent", ""))
	lang = str(cf.get_value("settings", "lang", ""))
	seen = cf.get_value("tutorial", "seen", {})

	Sfx.sfx_on = bool(cf.get_value("settings", "sfx", true))
	Sfx.music_on = bool(cf.get_value("settings", "music", true))
	hints.refresh(today())


func save_data() -> void:
	var cf := ConfigFile.new()
	cf.set_value("progress", "unlocked", unlocked)
	cf.set_value("progress", "stars", stars)
	cf.set_value("stats", "total_folds", total_folds)
	cf.set_value("stats", "perfect_runs", perfect_runs)
	cf.set_value("stats", "install_unix", install_unix)
	cf.set_value("econ", "hints", hints.to_dict())
	cf.set_value("econ", "ads_removed", ads_removed)
	cf.set_value("econ", "no_ads_offered", no_ads_offered)
	cf.set_value("econ", "interstitials_shown", interstitials_shown)
	cf.set_value("econ", "levels_since_ad", levels_since_ad)
	cf.set_value("privacy", "consent", consent)
	cf.set_value("settings", "lang", lang)
	cf.set_value("tutorial", "seen", seen)
	cf.set_value("settings", "sfx", Sfx.sfx_on)
	cf.set_value("settings", "music", Sfx.music_on)
	cf.save(PATH)


func today() -> String:
	return Time.get_date_string_from_system()


## Gun degistiyse bedava ipucu kontenjanini yeniler.
func refresh_hints() -> bool:
	var reset := hints.refresh(today())
	if reset:
		save_data()
	return reset


func record(level: int, star: int) -> void:
	var best := int(stars.get(level, 0))
	if star > best:
		stars[level] = star
	if star >= 3 and best < 3:
		perfect_runs += 1
	unlocked = maxi(unlocked, level + 1)
	levels_since_ad += 1
	save_data()


func stars_of(level: int) -> int:
	return int(stars.get(level, 0))


func total_stars() -> int:
	var n := 0
	for k in stars:
		n += int(stars[k])
	return n


func has_seen(key: String) -> bool:
	return bool(seen.get(key, false))


func mark_seen(key: String) -> void:
	seen[key] = true
	save_data()
