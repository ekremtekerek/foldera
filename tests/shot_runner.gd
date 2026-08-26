extends Node
## Gorsel dogrulama surucusu.  godot --path . -- shots
##
## Ozel bir MainLoop (--script) kullanmiyoruz: o durumda Godot autoload'lari
## hic kaydetmiyor ve Sfx/SaveData derleme aninda bulunamiyor. Bunun yerine
## oyunun kendi icinden, sadece hata ayiklama derlemesinde calisiyor.

const OUT := "D:/Projects/foldera/shots/"

var main: Node
var board: BoardView


func _ready() -> void:
	main = get_parent()
	SaveData.total_folds = 0      # ogretici ipucunu her kosuda yeniden gorelim
	SaveData.consent = "limited"  # riza ekrani ana akisi bloklamasin
	# Oyun kareleri temiz olsun; ogretici kartlarin kendi kareleri sonda
	# dogrudan olusturuluyor, `seen` onlari etkilemiyor.
	SaveData.seen = {"lock": true, "wild": true, "stars": true, "tools": true}
	DirAccess.make_dir_recursive_absolute(OUT)
	_run()


func _run() -> void:
	await _drain_modals()
	await _wait(30)
	await _shot("01_baslik")

	main.level = 1
	main._start_level()
	board = main.board
	await _wait(150)
	await _shot("02_seviye1")
	print("  ipucu dugumu: ", board._gesture != null, "  hamle: ", board.hint())

	main.level = 20
	main._start_level()
	await _wait(80)
	await _shot("03_seviye20")
	print("  vp=", main.get_viewport_rect().size, " cs=", board.cs, " base=", main._base, " off=", board.board_offset)

	# katlamayi yarida yakala -- kagit neredeyse dik, en dramatik an
	_grab(0, 0, Vector2(1, 0))
	board._set_t(0.42)
	await _wait(2)
	await _shot("04_katlama_ortasi")

	board._set_t(0.80)
	await _wait(2)
	await _shot("05_katlama_sonu")

	board._cancel(false)
	await _wait(40)

	main.level = 40
	main._start_level()
	await _wait(80)
	await _shot("06_seviye40")

	# gecersiz katlama on izlemesi: kirmizi carpilar gorunmeli
	var bad := _find_invalid()
	if not bad.is_empty():
		_grab(bad[0], bad[1], bad[2])
		board._set_t(0.28)
		await _wait(2)
		await _shot("07_gecersiz_onizleme")
		board._cancel(false)
		await _wait(40)

	# gercek bir hamleyi sonuna kadar oynat -- konfeti, golge, oturma
	main.level = 28
	main._start_level()
	await _wait(80)
	var mv: Array = board.hint()
	if not mv.is_empty():
		_grab_crease(mv[0], mv[1])
		board._set_t(0.55)
		await _wait(2)
		await _shot("08_gercek_hamle")
		board._release()
		await _wait(26)
		await _shot("09_patlama")
		await _wait(70)
		await _shot("10_oturmus")

	main._on_solved(3)
	await _wait(150)
	await _shot("11_kazandin")

	await _extra_screens()
	await _language_screens()
	print("SHOTS OK")
	get_tree().quit()


## Kare saymak yaniltici: pencere vsync olmadan cok hizli donuyor, 150 kare
## 2.5 saniye degil ~0.3 saniye ediyor ve zamanlayiciya bagli animasyonlar
## (ogretici ipucu, yildiz acilisi) henuz baslamamis oluyor. Gercek zaman bekle.
func _wait(frames_at_60: int) -> void:
	await get_tree().create_timer(float(frames_at_60) / 60.0).timeout


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + name + ".png")
	print("  -> ", name)


func _grab(cx: int, cy: int, dir: Vector2) -> void:
	var p: Vector2 = board.board_offset + board._cell_center(cx, cy)
	board._press(p)
	board._motion(p + dir * board.cs * 0.6)


func _grab_crease(axis: int, g: int) -> void:
	if axis == 0:
		_grab(g - 1, int(board.model.h / 2), Vector2(1, 0))
	else:
		_grab(int(board.model.w / 2), g - 1, Vector2(0, 1))


func _find_invalid() -> Array:
	for c in board.model.creases():
		var r: Dictionary = board.model.fold(c[0], c[1], 0)
		if r.ok:
			continue
		if c[0] == 0:
			return [c[1] - 1, int(board.model.h / 2), Vector2(1, 0)]
		return [int(board.model.w / 2), c[1] - 1, Vector2(0, 1)]
	return []


# ---------------------------------------------------------- para kazanma ve
#                                                             rehber ekranlari

func _extra_screens() -> void:
	await _drain_modals()
	await _wait(10)

	var cs := ConsentScreen.new()
	main._present_modal(cs)
	await _wait(40)
	await _shot("12_riza")
	cs.queue_free()
	await _wait(10)

	for key in ["lock", "wild", "stars", "tools"]:
		var card := TeachCard.make(key)
		main._present_modal(card)
		await _wait(45)
		await _shot("13_ogretici_%s" % key)
		card.dismiss()
		await _wait(10)

	# ipucu bitmis durumu
	SaveData.hints.day = SaveData.today()
	SaveData.hints.purchased = 0
	SaveData.hints.free_left = 0
	main.level = 12
	main._start_level()
	await _wait(70)
	await _drain_modals()

	var stub := Ads.provider as StubAdProvider
	if stub != null:
		stub.instant = false
		stub.force_fill = true
		stub.preload_all()
	await _wait(100)          # stub yukleme gecikmesi

	main._on_hint()
	await _wait(40)
	await _shot("14_ipucu_teklifi")

	var offer := _find("offer_card")
	if offer != null:
		offer.choose("ad")
		await _wait(50)
		await _shot("15_odullu_reklam")
		var ov := _find_in(get_tree().root, "fake_ad_overlay")
		if ov != null:
			ov._finish(false)
		await _wait(20)

	await _drain_modals()
	main._show_no_ads_offer()
	await _wait(40)
	await _shot("16_reklamsiz_teklifi")
	await _drain_modals()
	await _wait(10)


func _find(type_name: String) -> Node:
	return _find_in(main._root, type_name)


func _find_in(node: Node, type_name: String) -> Node:
	for c in node.get_children():
		if c.get_script() != null:
			var p: String = c.get_script().resource_path
			if p.get_file().get_basename() == type_name:
				return c
		var hit := _find_in(c, type_name)
		if hit != null:
			return hit
	return null

## Ogretici kartlar SIRAYLA cikiyor: birini kapatinca digeri aciliyor.
## Tek bir kapatma yetmez, hepsi bitene kadar donmek gerek.
func _drain_modals() -> void:
	for i in 8:
		var any := false
		for t in ["teach_card", "offer_card", "consent_screen"]:
			var m := _find(t)
			if m == null:
				continue
			any = true
			if m.has_method("dismiss"):
				m.dismiss()
			elif m.has_method("choose"):
				m.choose("dismiss")
			else:
				m.queue_free()
		await _wait(12)
		if not any:
			return


## Dil kontrolu. Almanca ve Rusca metinleri Ingilizce'nin %30-40 uzunu,
## Vietnamca ise aksan isaretleri yuzunden satir yuksekligi farkli. Uc dilde
## de tasma / kirpilma olmamali.
func _language_screens() -> void:
	for code in ["de", "ru", "vi"]:
		TranslationServer.set_locale(code)
		# Alt cubuk etiketleri bir kez olusturuluyor; dil testinde elle tazele.
		main._btn_undo.label = Loc.t("BTN_UNDO")
		main._btn_restart.label = Loc.t("BTN_RESTART")
		main._btn_hint.label = Loc.t("BTN_HINT")
		for b in [main._btn_undo, main._btn_restart, main._btn_hint]:
			b.queue_redraw()

		main.level = 12
		main._start_level()
		await _wait(70)
		await _drain_modals()
		await _shot("17_dil_%s_oyun" % code)

		var card := OfferCard.make(Loc.t("HINT_EMPTY_TITLE"), Loc.t("HINT_EMPTY_BODY"), [
			{"id": "ad", "label": Loc.t("BTN_WATCH_AD"), "primary": true,
				"note": Loc.t("TOAST_HINTS_ADDED")},
			{"id": "buy", "label": Loc.f("HINT_BUY_PACK", [Store.price_of("hints_10")])},
			{"id": "dismiss", "label": Loc.t("BTN_CLOSE")},
		])
		main._present_modal(card)
		await _wait(40)
		await _shot("18_dil_%s_teklif" % code)
		card.choose("dismiss")
		await _wait(15)

		var tc := TeachCard.make("lock")
		main._present_modal(tc)
		await _wait(45)
		await _shot("19_dil_%s_ogretici" % code)
		tc.dismiss()
		await _wait(15)

	var lc := LanguageCard.new()
	main._present_modal(lc)
	await _wait(45)
	await _shot("20_dil_secimi")
	lc.choose("")
	await _wait(15)
	TranslationServer.set_locale("tr")
