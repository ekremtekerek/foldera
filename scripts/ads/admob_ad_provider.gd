class_name AdMobAdProvider
extends AdProvider
##
## Gercek AdMob saglayicisi (poing-studios/godot-admob-plugin v5).
##
## Eklentinin API'si GERI CAGRI tabanli; oyun kodumuz ise await ediyor.
## Kopruyu `Waiter` kuruyor: her gosterim icin tek atislik bir sinyal.
##
## Uc savunma var, ucu de gercek cihazlarda yasanan sorunlardan:
##
##   1. WATCHDOG. Reklam SDK'si bazen hicbir geri cagriyi tetiklemiyor
##      (ag kopmasi, uygulamanin arka plana atilmasi). Zaman asimi olmasa
##      `await` sonsuza kadar askida kalir ve OYUN KILITLENIR.
##   2. TEK SEFERLIK COZUM. Ayni gosterimde hem "kapandi" hem "gosterilemedi"
##      gelebiliyor; ikinci emit await'i bozar.
##   3. ODUL SADECE on_user_earned_reward ILE. Reklamin kapanmasi tek basina
##      odul anlamina GELMEZ; kullanici erken kapatmis olabilir.
##
## CANLI REKLAM BIRIMI ACIK IZIN ISTER: yalnizca "liveads" ozellik etiketi
## tasiyan derleme gercek birimleri yukler. Hata ayiklama, ic test ve normal
## release derlemelerinin hepsi Google'in test birimini kullanir. Ayrimi
## burada, tek yerde yapiyoruz -- unutulacak bir adim birakmiyoruz.

const TEST_INTERSTITIAL := "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED := "ca-app-pub-3940256099942544/5224354917"

## AdMob hesabindaki gercek birimler (yayinci ca-app-pub-6484682017091395).
## Uygulama kimligi kodda degil, `admob/general/android/app_id` proje ayarinda;
## eklenti onu AndroidManifest icine yaziyor.
const LIVE_INTERSTITIAL := "ca-app-pub-6484682017091395/6004825044"
const LIVE_REWARDED := "ca-app-pub-6484682017091395/3223960483"

## Gosterim zaman asimi. Reklam bu sure icinde kapanmazsa oyun devam eder.
const SHOW_TIMEOUT := 90.0
const RELOAD_DELAY := 3.0

## Gercek reklam birimleri YALNIZCA "liveads" ozellik etiketi tasiyan derlemede
## yuklenir -- yani "Android AAB (yayin)" on ayarinda. Etiket yoksa Google'in
## test birimi kullanilir.
##
## YON KASTEN BOYLE. Eskiden kural "hata ayiklama degilse canli" idi; bu, ic
## teste giden RELEASE derlemesine canli birim koyuyordu. Kendi reklamina
## tiklamak AdMob politikasi ihlali ve hesap askiya alma sebebi -- ustelik
## sessizce olur, hicbir uyari vermez.
##
## Simdi hata yonu tersine dondu: etiketi koymayi unutursan uretimde TEST
## reklami cikar. Gelir sifir olur ama zarar vermez ve ilk raporda fark
## edilir. Guvenli tarafa dusen varsayilan bu.
var _live := OS.has_feature("liveads") and not OS.is_debug_build()
var interstitial_id := LIVE_INTERSTITIAL if _live else TEST_INTERSTITIAL
var rewarded_id := LIVE_REWARDED if _live else TEST_REWARDED

var _interstitial: InterstitialAd = null
var _rewarded: RewardedAd = null
var _inter_loader: InterstitialAdLoader = null
var _rew_loader: RewardedAdLoader = null
var _consent: ConsentInformation = null
var _initialized := false


## Tek atislik sonuc kanali: geri cagri tabanli SDK ile await eden oyun kodu
## arasindaki kopru. Ikinci kez cozulemez.
class Waiter extends RefCounted:
	signal done(result: bool)
	var _resolved := false

	func resolve(value: bool) -> void:
		if _resolved:
			return
		_resolved = true
		done.emit(value)


static func is_available() -> bool:
	# Eklenti yalnizca Android/iOS'ta gercek bir singleton'a baglaniyor.
	# Masaustunde siniflar var ama cagrilar sessizce bos doner.
	return OS.has_feature("mobile") and ResourceLoader.exists("res://addons/admob/plugin.cfg")


func provider_name() -> String:
	return "admob"


func initialize(consent_mode: String) -> void:
	super.initialize(consent_mode)
	if not is_available():
		push_warning("AdMob eklentisi/platformu yok -- bu saglayici secilmemeliydi.")
		return
	_inter_loader = InterstitialAdLoader.new()
	_rew_loader = RewardedAdLoader.new()
	_request_consent()


# ------------------------------------------------------------------ riza

##
## Once UMP riza akisi, SONRA SDK baslatma.
##
## Sira onemli: AB/Birlesik Krallik'ta riza alinmadan reklam istegi atmak
## politika ihlali. UMP cogu ulkede "gerekli degil" dondugu icin akis
## kendiliginden ilerliyor.
##
## Riza adimi HER TURLU SDK baslatmaya devam ediyor: hata durumunda oyuncuyu
## reklamsiz birakmak yerine kisisellestirilmemis reklam gostermek dogru olan.
func _request_consent() -> void:
	_consent = ConsentInformation.new()
	_consent.update(
		ConsentRequestParameters.new(),
		func() -> void:
			if _consent.get_is_consent_form_available():
				_load_consent_form()
			else:
				_init_sdk(),
		func(form_error: FormError) -> void:
			push_warning("UMP riza guncellemesi basarisiz: %s" % form_error.message)
			_init_sdk()
	)


func _load_consent_form() -> void:
	UserMessagingPlatform.load_consent_form(
		func(form: ConsentForm) -> void:
			form.show(func(_err: FormError) -> void: _init_sdk()),
		func(form_error: FormError) -> void:
			push_warning("UMP formu yuklenemedi: %s" % form_error.message)
			_init_sdk()
	)


func _init_sdk() -> void:
	if _initialized:
		return
	_initialized = true
	# Hangi birimlerin yuklendigi logcat'te acikca gorunsun: yanlis kipte
	# yayina cikmak sessizce olmasin.
	print("[ads] birim kipi: ", "CANLI" if _live else "TEST", "  interstitial=", interstitial_id)
	var on_init := OnInitializationCompleteListener.new()
	on_init.on_initialization_complete = func(_status: InitializationStatus) -> void:
		preload_all()
	MobileAds.set_request_configuration(RequestConfiguration.new())
	MobileAds.initialize(on_init)


# ------------------------------------------------------------------ yukleme

func preload_all() -> void:
	_load_interstitial()
	_load_rewarded()


func _load_interstitial() -> void:
	if _inter_loader == null:
		return
	var cb := InterstitialAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial = ad
		state_changed.emit()
	cb.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_interstitial = null
		state_changed.emit()
		_retry(_load_interstitial, "gecis", error.message)
	_inter_loader.load(interstitial_id, AdRequest.new(), cb)


func _load_rewarded() -> void:
	if _rew_loader == null:
		return
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded = ad
		state_changed.emit()
	cb.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_rewarded = null
		state_changed.emit()
		_retry(_load_rewarded, "odullu", error.message)
	_rew_loader.load(rewarded_id, AdRequest.new(), cb)


## Doluluk yoksa hemen tekrar denemek istegi bosa harcar ve pil yakar;
## kisa bir bekleme koyuyoruz.
func _retry(fn: Callable, kind: String, message: String) -> void:
	if not is_inside_tree():
		return
	print("[admob] %s reklam yuklenemedi (%s), %s sn sonra tekrar" % [kind, message, RELOAD_DELAY])
	await get_tree().create_timer(RELOAD_DELAY).timeout
	fn.call()


# ------------------------------------------------------------------ gosterim

func is_interstitial_ready() -> bool:
	return _interstitial != null


func is_rewarded_ready() -> bool:
	return _rewarded != null


func show_interstitial() -> bool:
	var ad := _interstitial
	if ad == null:
		return false
	_interstitial = null            # ayni reklam iki kez gosterilemez
	var w := Waiter.new()
	var cb := FullScreenContentCallback.new()
	cb.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_load_interstitial()
		w.resolve(true)
	cb.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		push_warning("Gecis reklami gosterilemedi: %s" % error.message)
		ad.destroy()
		_load_interstitial()
		w.resolve(false)
	ad.full_screen_content_callback = cb
	ad.show()
	_arm_watchdog(w)
	return await w.done


func show_rewarded() -> bool:
	var ad := _rewarded
	if ad == null:
		return false
	_rewarded = null
	var w := Waiter.new()
	# GDScript lambda'lari degeri KOPYALAYARAK yakaliyor; degistirilebilir bir
	# kutu gerektigi icin tek elemanli dizi kullaniyoruz.
	var earned := [false]

	var cb := FullScreenContentCallback.new()
	cb.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_load_rewarded()
		w.resolve(earned[0])
	cb.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		push_warning("Odullu reklam gosterilemedi: %s" % error.message)
		ad.destroy()
		_load_rewarded()
		w.resolve(false)
	ad.full_screen_content_callback = cb

	var reward := OnUserEarnedRewardListener.new()
	reward.on_user_earned_reward = func(_item: RewardedItem) -> void:
		earned[0] = true
	ad.show(reward)
	_arm_watchdog(w)
	return await w.done


## SDK hicbir geri cagri tetiklemezse oyunu kurtarir.
func _arm_watchdog(w: Waiter) -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(SHOW_TIMEOUT).timeout
	if is_instance_valid(w):
		w.resolve(false)
