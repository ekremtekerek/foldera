extends Node
##
## Uygulama ici satin alma (autoload: Store). Reklam katmaniyla ayni desen:
## oyun kodu urun kimliklerini taniyor, odeme saglayicisini tanimiyor.
##
## DURUM: GERCEK BILLING HENUZ BAGLI DEGIL. `using_stub()` true donuyor;
## `_do_purchase()` yalnizca bir onay kutusu gosterip urunu BEDAVA veriyor.
## Kutu 13 dilde "TEST satin almasi, ucret alinmaz" yaziyor, yani kullaniciyi
## yaniltmiyor -- ama uretime bu haliyle cikamaz.
##
## Bu yuzden `offers_enabled()` kapisi var: uretim derlemesinde ("liveads")
## sahte magaza hicbir teklif SUNMUYOR. Kapi test ediliyor (t_store_gate).
##
## Billing baglanirken degisecek olanlar: `using_stub()`, `_do_purchase()`,
## `restore()` ve `price_of()`. Cagri noktalari ayni kalacak.
##
## HALA YAPILMASI GEREKEN iki sey:
##   * Satin alma dogrulamasi SUNUCUDA yapilmali. Istemcide `ads_removed`
##     bayragini set etmek tek basina guvenli degil (yerel dosya duzenlenebilir).
##   * "Satin alimlari geri yukle" akisi olmali; Google bunu zorunlu tutuyor.

signal purchased(product_id: String)
signal purchase_failed(product_id: String, reason: String)

## Urun tanimlari. Basliklar ceviri ANAHTARI olarak duruyor, metin olarak
## degil: dil calisma aninda degisebiliyor.
##
## `price_fallback` yalnizca sahte saglayici icin. Gercek Billing baglaninca
## fiyat Google Play'den GELIR ve kullanicinin ulkesine gore yerellesmis
## olarak doner ("$4.99", "₺149,00", "R$ 19,90"...). Fiyati kodda tutmak
## kuresel yayinda her zaman yanlis olur.
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func using_stub() -> bool:
	return true      # gercek Billing baglaninca false donecek


## Sahte odeme akisi UYGULAMA MAGAZASINA CIKAMAZ.
##
## Gercek Billing baglanana kadar satin alma teklifleri yalnizca test
## derlemelerinde gorunur; uretim derlemesi ("liveads" etiketi) hicbir teklif
## SUNMAZ. Reklamdaki kuralin aynisi, ayni yonde: unutmak zararsiz tarafa
## dusuyor.
##
## Neden gizlemek yetiyor: reklam kaldirma ve ipucu paketi ek ozellikler --
## oyun onlarsiz eksiksiz oynaniyor. Odemesini alamayacagimiz bir seyi fiyat
## etiketiyle gostermek ise magaza politikasi sorunu.
##
## Billing baglandiginda `using_stub()` false donecek ve bu kapi kendiliginden
## acilacak; burada ayrica bir sey silmek gerekmiyor.
## Kararin kendisi SAF: dogrudan test edilebilsin diye ayri duruyor.
## `OS.has_feature` headless kosuda taklit edilemiyor, bu imza edilebiliyor.
static func offers_allowed(stub: bool, production: bool) -> bool:
	return not stub or not production


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


func price_of(product_id: String) -> String:
	# TODO(billing): gercek fiyat Google Play sorgusundan gelmeli.
	return str(PRODUCTS.get(product_id, {}).get("price_fallback", "-"))


func purchase(product_id: String) -> bool:
	if busy or not PRODUCTS.has(product_id):
		return false
	if is_owned(product_id):
		return true
	busy = true
	Track.log_event("iap_start", {"product": product_id})
	var ok: bool = await _do_purchase(product_id)
	busy = false

	if not ok:
		Track.log_event("iap_cancel", {"product": product_id})
		purchase_failed.emit(product_id, "cancelled")
		return false

	_grant(product_id)
	Track.log_event("iap_purchase", {"product": product_id, "price": price_of(product_id)})
	purchased.emit(product_id)
	return true


func _grant(product_id: String) -> void:
	var p: Dictionary = PRODUCTS[product_id]
	if product_id == "no_ads":
		SaveData.ads_removed = true
	if p.has("hints"):
		SaveData.hints.grant(int(p.hints))
	SaveData.save_data()


## Sahte odeme onayi. Gercek Billing burada Google'in odeme sayfasini acacak.
func _do_purchase(product_id: String) -> bool:
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
	return result


func restore() -> void:
	# TODO(billing): Google Play sorgulanip sahip olunan non-consumable urunler
	# geri yuklenecek. Magaza incelemesinde bu akis ARANIYOR.
	Track.log_event("iap_restore")
