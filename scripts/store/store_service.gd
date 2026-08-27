extends Node
##
## Uygulama ici satin alma (autoload: Store). Reklam katmaniyla ayni desen:
## oyun kodu urun kimliklerini taniyor, odeme saglayicisini tanimiyor.
##
## GERCEK BILLING BAGLI (godot-google-play-billing 3.3.0, Play Billing 9.1.0).
## Eklenti yalnizca Android'de ve Play'den kurulmus derlemede calisiyor;
## masaustunde ve testlerde eski sahte akis devrede kaliyor ki gelistirme
## durmasin. Hangisinin calistigini `using_stub()` soyluyor.
##
## TUKETILEBILIR ile TEK SEFERLIK arasindaki fark kritik:
##   * `no_ads` TEK SEFERLIK. PURCHASED gorulunce hemen veriliyor (islem
##     etkisiz-tekrarlanabilir: bir bayrak set ediliyor), sonra ONAYLANIYOR.
##     Uc gun icinde onaylanmayan satin almayi Google GERI ODUYOR ve iptal
##     ediyor -- yani acknowledge unutulursa para geri gider.
##   * `hints_*` TUKETILEBILIR. Urun YALNIZCA tuketim basarili donunce
##     veriliyor. Boylece cift verme imkansiz: tuketim basarisizsa satin alma
##     Play'de "sahip olunan" kalir ve bir sonraki query_purchases tekrar dener.
##
## HALA EKSIK: dogrulama sunucuda yapilmiyor. `SaveData.ads_removed` kok
## erisimi olan bir cihazda duzenlenebilir. Dusuk bedelli bir oyun icin
## kabul edilebilir ama gercek koruma sunucu tarafi dogrulamadir.

signal purchased(product_id: String)
signal purchase_failed(product_id: String, reason: String)

## Urun tanimlari. Basliklar ceviri ANAHTARI olarak duruyor, metin olarak
## degil: dil calisma aninda degisebiliyor.
##
## `price_fallback` yalnizca fiyat Play'den HENUZ gelmediginde gorunuyor
## (baglanti kurulmadan, cevrimdisi, ya da sahte saglayicida). Gercek fiyat
## kullanicinin ulkesine gore yerellesmis olarak Play'den GELIR.
const PRODUCTS := {
	"no_ads": {
		"title_key": "IAP_NOADS_TITLE",
		"desc_key": "NOADS_BODY",
		"price_fallback": "₺149,00",
		"kind": "non_consumable",
	},
	"hints_10": {
		"title_key": "IAP_HINTS10_TITLE",
		"desc_key": "IAP_HINTS_DESC",
		"price_fallback": "₺29,00",
		"kind": "consumable",
		"hints": 10,
	},
	"hints_30": {
		"title_key": "IAP_HINTS30_TITLE",
		"desc_key": "IAP_HINTS30_DESC",
		"price_fallback": "₺69,00",
		"kind": "consumable",
		"hints": 30,
	},
}

var busy := false

var _billing: Object = null          ## BillingClient (yalnizca Android)
var _ready_to_buy := false           ## urun ayrintilari geldi mi
var _prices := {}                    ## urun -> Play'den gelen yerellesmis fiyat
var _pending := {}                   ## satin alma jetonu -> urun kimligi
var _flow: Object = null             ## suren satin almanin bekleyicisi


## Tek atislik sonuc kanali -- reklam katmanindakiyle ayni desen.
class Waiter extends RefCounted:
	signal done(ok: bool)
	var _resolved := false

	func resolve(value: bool) -> void:
		if _resolved:
			return
		_resolved = true
		done.emit(value)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_try_start_billing()


## Eklenti yoksa (masaustu, editor, testler) sessizce sahte akisa dusuyoruz.
func _try_start_billing() -> void:
	if not Engine.has_singleton("GodotGooglePlayBilling"):
		print("[iap] eklenti yok -- sahte saglayici")
		return
	var script := load("res://addons/GodotGooglePlayBilling/BillingClient.gd")
	if script == null:
		push_warning("[iap] BillingClient.gd yuklenemedi")
		return
	_billing = script.new()
	_billing.connected.connect(_on_connected)
	_billing.disconnected.connect(func() -> void: _ready_to_buy = false)
	_billing.connect_error.connect(func(code: int, msg: String) -> void:
		push_warning("[iap] baglanti hatasi %d: %s" % [code, msg]))
	_billing.query_product_details_response.connect(_on_products)
	_billing.query_purchases_response.connect(_on_purchases_queried)
	_billing.on_purchase_updated.connect(_on_purchase_updated)
	_billing.consume_purchase_response.connect(_on_consumed)
	_billing.acknowledge_purchase_response.connect(_on_acknowledged)
	_billing.start_connection()
	print("[iap] gercek Billing baglaniyor")


func using_stub() -> bool:
	return _billing == null


## Kararin kendisi SAF: dogrudan test edilebilsin diye ayri duruyor.
## `OS.has_feature` headless kosuda taklit edilemiyor, bu imza edilebiliyor.
static func offers_allowed(stub: bool, production: bool) -> bool:
	return not stub or not production


## Sahte odeme akisi UYGULAMA MAGAZASINA CIKAMAZ: uretim derlemesinde
## ("liveads") sahte magaza hicbir teklif SUNMUYOR. Billing baglandiginda
## `using_stub()` false doner ve bu kapi kendiliginden acilir.
func offers_enabled() -> bool:
	return offers_allowed(using_stub(), OS.has_feature("liveads"))


func is_owned(product_id: String) -> bool:
	if product_id == "no_ads":
		return SaveData.ads_removed
	return false


func title_of(product_id: String) -> String:
	return Loc.t(str(PRODUCTS.get(product_id, {}).get("title_key", product_id)))


func desc_of(product_id: String) -> String:
	return Loc.t(str(PRODUCTS.get(product_id, {}).get("desc_key", "")))


## Play'den gelen yerellesmis fiyat; henuz gelmediyse yedek metin.
func price_of(product_id: String) -> String:
	if _prices.has(product_id):
		return str(_prices[product_id])
	return str(PRODUCTS.get(product_id, {}).get("price_fallback", "-"))


# --------------------------------------------------------------- satin alma

func purchase(product_id: String) -> bool:
	if busy or not PRODUCTS.has(product_id):
		return false
	if is_owned(product_id):
		return true
	busy = true
	Track.log_event("iap_start", {"product": product_id})
	# GDScript uclu operator icinde coroutine cagrisina izin vermiyor:
	# her await ayri satirda durmali.
	var ok := false
	if _billing != null:
		ok = await _buy_real(product_id)
	else:
		ok = await _buy_stub(product_id)
	busy = false

	if not ok:
		Track.log_event("iap_cancel", {"product": product_id})
		purchase_failed.emit(product_id, "cancelled")
		return false

	Track.log_event("iap_purchase", {"product": product_id, "price": price_of(product_id)})
	purchased.emit(product_id)
	return true


## Play akisi. `purchase()` yalnizca akisin BASLATILDIGINI dondurur; sonuc
## `on_purchase_updated` sinyaliyle gelir, o yuzden burada bekliyoruz.
func _buy_real(product_id: String) -> bool:
	if not _ready_to_buy:
		push_warning("[iap] urun ayrintilari henuz gelmedi")
		purchase_failed.emit(product_id, "not_ready")
		return false
	_flow = Waiter.new()
	var launch: Dictionary = _billing.purchase(product_id)
	if int(launch.get("response_code", -1)) != 0:
		push_warning("[iap] akis baslatilamadi: %s" % str(launch.get("debug_message", "")))
		_flow = null
		return false
	# Kullanici odeme ekraninda takilirsa oyun sonsuza kadar askida kalmasin.
	var guard := get_tree().create_timer(300.0)
	guard.timeout.connect(func() -> void:
		if _flow != null:
			_flow.resolve(false))
	var result: bool = await _flow.done
	_flow = null
	return result


## Sahte odeme onayi -- yalnizca eklentinin olmadigi derlemelerde.
func _buy_stub(product_id: String) -> bool:
	var dlg := ConfirmationDialog.new()
	dlg.title = Loc.t("IAP_TEST_TITLE")
	dlg.dialog_text = "%s\n%s\n\n%s\n\n%s" % [
		title_of(product_id), price_of(product_id), desc_of(product_id),
		Loc.t("IAP_TEST_BODY"),
	]
	dlg.ok_button_text = Loc.t("BTN_BUY")
	dlg.cancel_button_text = Loc.t("BTN_CANCEL")
	get_tree().root.add_child(dlg)
	dlg.popup_centered()

	var result := false
	var done := false
	dlg.confirmed.connect(func() -> void:
		result = true
		done = true)
	dlg.canceled.connect(func() -> void: done = true)
	while not done:
		await get_tree().process_frame
	dlg.queue_free()
	if result:
		_grant(product_id)
	return result


## Satin alimlari geri yukle. Google bu akisi ZORUNLU tutuyor: cihaz degistiren
## ya da uygulamayi silip kuran kullanici "reklamsiz"i geri alabilmeli.
func restore() -> void:
	Track.log_event("iap_restore")
	if _billing == null:
		return
	_billing.query_purchases(0)   # ProductType.INAPP


# ------------------------------------------------------------ geri cagrilar

func _on_connected() -> void:
	var ids := PackedStringArray(PRODUCTS.keys())
	_billing.query_product_details(ids, 0)   # ProductType.INAPP
	# Acilista sessiz geri yukleme: cihaz degistiren kullanici hicbir sey
	# yapmadan reklamsiz haline kavusuyor.
	_billing.query_purchases(0)


## Fiyatlar Play'den geliyor. Alan adlari Billing kutuphanesinin ProductDetails
## yapisindan tureiyor; surumler arasinda degisebildigi icin birkac olasiligi
## deniyoruz ve bulamazsak yedek fiyata dusuyoruz -- fiyatin yanlis gorunmesi
## teklifi hic gosterememekten daha kotu olurdu.
func _on_products(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) != 0:
		push_warning("[iap] urun sorgusu basarisiz: %s" % str(res.get("debug_message", "")))
		return
	for p in res.get("product_details", []):
		var id := str(p.get("product_id", p.get("productId", "")))
		if id == "":
			continue
		var offer: Dictionary = p.get("one_time_purchase_offer_details",
			p.get("oneTimePurchaseOfferDetails", {}))
		var price := str(offer.get("formatted_price", offer.get("formattedPrice", "")))
		if price != "":
			_prices[id] = price
	_ready_to_buy = true
	print("[iap] fiyatlar hazir: ", _prices)


func _on_purchases_queried(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) != 0:
		return
	for p in res.get("purchases", []):
		_process_purchase(p)


func _on_purchase_updated(res: Dictionary) -> void:
	var code := int(res.get("response_code", -1))
	if code != 0:
		# 1 = USER_CANCELED. Kullanici vazgectiyse uyari basmiyoruz.
		if code != 1:
			push_warning("[iap] satin alma hatasi %d: %s" % [code, str(res.get("debug_message", ""))])
		if _flow != null:
			_flow.resolve(false)
		return
	for p in res.get("purchases", []):
		_process_purchase(p)


## Tek satin alma kaydini isle. Hem yeni satin almada hem geri yuklemede ayni
## yoldan geciyoruz, boylece kural tek yerde duruyor.
func _process_purchase(p: Dictionary) -> void:
	# PENDING satin alma HENUZ ODENMEMISTIR. Urunu burada vermek onu bedava
	# dagitmak olur; odeme tamamlaninca Play yeniden haber veriyor.
	if int(p.get("purchase_state", 0)) != 1:   # 1 = PURCHASED
		return
	var ids: Array = p.get("product_ids", [])
	var token := str(p.get("purchase_token", ""))
	for raw_id in ids:
		var id := str(raw_id)
		if not PRODUCTS.has(id):
			continue
		if str(PRODUCTS[id].get("kind", "")) == "consumable":
			# Urun tuketim BASARILI donunce veriliyor -- cift verme olmasin.
			_pending[token] = id
			_billing.consume_purchase(token)
		else:
			_grant(id)          # bayrak set etmek etkisiz-tekrarlanabilir
			if not bool(p.get("is_acknowledged", false)):
				_billing.acknowledge_purchase(token)
			if _flow != null:
				_flow.resolve(true)


func _on_consumed(res: Dictionary) -> void:
	var token := str(res.get("token", ""))
	var id := str(_pending.get(token, ""))
	_pending.erase(token)
	if int(res.get("response_code", -1)) != 0:
		push_warning("[iap] tuketim basarisiz: %s" % str(res.get("debug_message", "")))
		if _flow != null:
			_flow.resolve(false)
		return
	if id != "":
		_grant(id)
	if _flow != null:
		_flow.resolve(true)


func _on_acknowledged(res: Dictionary) -> void:
	if int(res.get("response_code", -1)) != 0:
		# Onaylanmayan satin almayi Google uc gun sonra GERI ODUYOR. Bir
		# sonraki acilistaki query_purchases tekrar deneyecek.
		push_warning("[iap] onaylama basarisiz: %s" % str(res.get("debug_message", "")))


func _grant(product_id: String) -> void:
	var p: Dictionary = PRODUCTS[product_id]
	if product_id == "no_ads":
		SaveData.ads_removed = true
	if p.has("hints"):
		SaveData.hints.grant(int(p.hints))
	SaveData.save_data()
