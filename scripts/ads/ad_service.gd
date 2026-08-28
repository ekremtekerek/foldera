extends Node
##
## Reklam servisi (autoload: Ads). Oyun kodunun tanidigi TEK reklam arayuzu.
##
## Iki isi ayri tutuyor:
##   * NE ZAMAN gosterilir  -> AdPolicy (saf mantik, test edilebilir)
##   * NASIL gosterilir     -> AdProvider (AdMob / stub)
##
## Bu ayrim sayesinde frekans tavanlarini gercek SDK olmadan test edebiliyoruz,
## ve reklam agi degistirmek politikaya hic dokunmuyor.

signal rewarded_earned(placement: String)
signal interstitial_closed()
signal offer_no_ads()

var provider: AdProvider
var busy := false

var _last_ad_msec := 0
var _last_reward_msec := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	provider = AdMobAdProvider.new() if AdMobAdProvider.is_available() else StubAdProvider.new()
	add_child(provider)
	# Hangi saglayicinin secildigi logcat'te GORUNSUN. Bu satir olmadigi icin
	# cihazda sahte saglayicinin calistigi uzun sure fark edilmedi: oyun
	# sorunsuz gorunuyor, yalnizca AdMob panosu bos kaliyordu.
	print("[ads] saglayici: ", provider.provider_name(),
		"  PoingGodotAdMob kayitli mi: ", Engine.has_singleton("PoingGodotAdMob"))
	provider.initialize(SaveData.consent)
	# Ilk reklamlar ilk 10 seviyeden once gosterilmiyor; yine de erken yukle ki
	# 11. seviyede bekleme olmasin.
	_last_ad_msec = Time.get_ticks_msec()


func using_stub() -> bool:
	return provider != null and provider.provider_name() == "stub"


func _seconds_since(msec: int) -> float:
	if msec <= 0:
		return 99999.0
	return float(Time.get_ticks_msec() - msec) / 1000.0


## Seviye bitiminde cagrilir. Politika izin veriyorsa gecis reklami gosterir.
## Her durumda doner -- cagiran taraf akisi buna gore surdurebilir.
func maybe_show_interstitial(level: int) -> bool:
	if busy or provider == null:
		return false
	var allowed := AdPolicy.should_show_interstitial({
		"level": level,
		"levels_since_ad": SaveData.levels_since_ad,
		"seconds_since_ad": _seconds_since(_last_ad_msec),
		"seconds_since_reward": _seconds_since(_last_reward_msec),
		"ads_removed": SaveData.ads_removed,
	})
	if not allowed:
		return false
	if not provider.is_interstitial_ready():
		Track.log_event("ad_not_ready", {"kind": "interstitial", "level": level})
		return false

	busy = true
	Track.log_event("ad_show", {"kind": "interstitial", "level": level})
	var shown: bool = await provider.show_interstitial()
	busy = false

	if shown:
		_last_ad_msec = Time.get_ticks_msec()
		SaveData.levels_since_ad = 0
		SaveData.interstitials_shown += 1
		SaveData.save_data()
		Track.log_event("ad_shown", {"kind": "interstitial", "level": level})
		interstitial_closed.emit()
		if AdPolicy.should_offer_no_ads(SaveData.interstitials_shown, SaveData.ads_removed,
				SaveData.no_ads_offered):
			SaveData.no_ads_offered = true
			SaveData.save_data()
			offer_no_ads.emit()
	else:
		Track.log_event("ad_failed", {"kind": "interstitial", "level": level})
	return shown


## Odullu reklam. true donerse odul HAK EDILMISTIR ve cagiran taraf odulu
## vermek zorundadir.
func show_rewarded(placement: String) -> bool:
	if busy or provider == null:
		return false
	if not provider.is_rewarded_ready():
		Track.log_event("ad_not_ready", {"kind": "rewarded", "placement": placement})
		return false

	busy = true
	Track.log_event("ad_show", {"kind": "rewarded", "placement": placement})
	var earned: bool = await provider.show_rewarded()
	busy = false

	if earned:
		_last_reward_msec = Time.get_ticks_msec()
		Track.log_event("rewarded_earned", {"placement": placement})
		rewarded_earned.emit(placement)
	else:
		Track.log_event("rewarded_abandoned", {"placement": placement})
	return earned


func rewarded_ready() -> bool:
	return provider != null and provider.is_rewarded_ready()


##
## Odullu reklam SUNULABILIR mi -- su anda yuklu olup olmamasindan bagimsiz.
##
## Teklif kartlari once `rewarded_ready()` soruyordu ve reklam o an yuklu
## degilse "reklam izle" secenegini HIC gostermiyordu. Oyuncunun gordugu sey
## ipuclari bitince cikan, icinde hicbir cikis yolu olmayan bir kart oldu --
## oyun bozuk gorunuyor. Oysa yeni bir uygulamada doluluk gecikmesi normal.
##
## Artik secenek her zaman gosteriliyor; hazir degilse KISA BIR SURE
## bekleniyor ve olmazsa oyuncuya durum soyleniyor. Sessizlik en kotu cevap.
func rewarded_possible() -> bool:
	return provider != null and not using_stub() and not SaveData.ads_removed


## Reklam hazir olana kadar bekler. Yukleme dongusu zaten arka planda
## `RELOAD_DELAY` araliklariyla donuyor; burada yalnizca onu bekliyoruz.
func await_rewarded(timeout: float = 8.0) -> bool:
	if provider == null:
		return false
	var gecen := 0.0
	while gecen < timeout:
		if provider.is_rewarded_ready():
			return true
		await get_tree().create_timer(0.25).timeout
		gecen += 0.25
	Track.log_event("ad_wait_timeout", {
		"kind": "rewarded",
		"hata": provider.son_hata,
		"basarisiz": provider.basarisiz,
	})
	return false
