extends Node
## Uctan uca dayaniklilik testi.  godot --path . -- soak
##
## Mantik testleri modeli dogruluyor; bu test GORUNUM ve AKIS yolunu doverek
## calisiyor: gercek surukleme jestleri, tween zincirleri, ogretici kartlar,
## ipucu ekonomisi, odullu reklam ve gecis reklami kapilari.
##
## Amac: hicbir seviyede kilitlenme, hicbir calisma zamani hatasi, her
## seviyenin gercekten bitmesi ve ekonominin sizdirmamasi.

const LEVELS := 25
const STEP_TIMEOUT := 8.0

var main: Node
var board: BoardView
var fails := 0
var checks := 0
var solved_flag := false


func _ready() -> void:
	main = get_parent()
	SaveData.total_folds = 999          # jest ogreticisi araya girmesin
	SaveData.consent = "limited"        # riza ekranini gec
	SaveData.no_ads_offered = true      # reklamsiz teklifi testleri bolmesin
	SaveData.ads_removed = false
	SaveData.seen = {}                  # ogretici kartlar GERCEKTEN cikacak
	Sfx.sfx_on = false
	Sfx.music_on = false
	Track.enabled = false               # 25 seviyelik olay gurultusu olmasin
	_run()


func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("  HATA: ", msg)


func _run() -> void:
	await get_tree().create_timer(0.4).timeout
	board = main.board
	board.solved.connect(func(_m: int) -> void: solved_flag = true)
	_dismiss_modals()

	var stub := Ads.provider as StubAdProvider
	check(stub != null, "AdMob eklentisi yokken stub saglayici secildi")
	if stub != null:
		stub.instant = true
		stub.force_fill = true
		stub.preload_all()

	for level in range(1, LEVELS + 1):
		await _play_level(level)

	await _test_undo_and_restart()
	await _test_teach_cards()
	await _test_hint_economy()
	await _test_ad_gating()
	await _test_next_level_flow()
	await _test_touch_drag()

	print("\n%d kontrol, %d hata" % [checks, fails])
	print("SOAK OK" if fails == 0 else "SOAK FAILED")
	get_tree().quit(1 if fails > 0 else 0)


# ------------------------------------------------------------------ oynanis

func _play_level(level: int) -> void:
	solved_flag = false
	main.level = level
	main._start_level()
	await _settled()

	var par: int = board.par
	var guard := par + 3
	while not solved_flag and guard > 0:
		var mv: Array = board.hint()
		if mv.is_empty():
			check(false, "seviye %d: cozucu hamle bulamadi (%d hamle sonra)" % [level, board.moves])
			break
		await _do_fold(mv[0], mv[1])
		guard -= 1

	check(solved_flag, "seviye %d bitirilebildi" % level)
	if solved_flag:
		check(board.moves == par, "seviye %d %d hamlede bitti (par %d)" % [level, board.moves, par])
	_dismiss_modals()


## Verilen kat cizgisini uretecek gercek bir surukleme jesti oynar.
func _do_fold(axis: int, g: int) -> void:
	var cell := Vector2i(g - 1, board.model.h / 2) if axis == 0 else Vector2i(board.model.w / 2, g - 1)
	var dir := Vector2(1.0, 0.0) if axis == 0 else Vector2(0.0, 1.0)
	var p: Vector2 = board.board_offset + board._cell_center(cell.x, cell.y)
	board._press(p)
	board._motion(p + dir * board.cs * 0.4)      # ekseni kilitler, kanadi kurar
	check(board._locked, "jest kat cizgisine cevrildi (axis %d, g %d)" % [axis, g])
	board._motion(p + dir * (board._need + 20.0))
	board._release()
	await _settled()


## Katlama zinciri bitene kadar bekler; bu sirada acilan ogretici kartlari
## kapatir (kartlar oyunu duraklattigi icin aksi halde test kilitlenir).
func _settled() -> void:
	await get_tree().create_timer(0.15).timeout
	var t := 0.0
	while not board.interactive and not solved_flag and t < STEP_TIMEOUT:
		_dismiss_modals()
		await get_tree().create_timer(0.05).timeout
		t += 0.05
	check(t < STEP_TIMEOUT, "animasyon zinciri %s sn icinde tamamlandi" % STEP_TIMEOUT)


# ------------------------------------------------------------------ modallar

func _find_modal(type_name: String) -> Node:
	return _scan(main._root, type_name)


func _scan(node: Node, type_name: String) -> Node:
	for c in node.get_children():
		if c.get_class() == "Control" and c.get_script() != null:
			var path: String = c.get_script().resource_path
			if path.get_file().get_basename() == type_name:
				return c
		var hit := _scan(c, type_name)
		if hit != null:
			return hit
	return null


func _dismiss_modals() -> void:
	for t in ["teach_card", "offer_card", "consent_screen"]:
		var m := _find_modal(t)
		if m == null:
			continue
		if m.has_method("dismiss"):
			m.dismiss()
		elif m.has_method("choose"):
			m.choose("dismiss")
		else:
			m.queue_free()


# ------------------------------------------------------------------ testler

func _test_undo_and_restart() -> void:
	print("- geri al / yeniden basla")
	solved_flag = false
	main.level = 12
	main._start_level()
	await _settled()

	var before: String = board.model.key()
	check(not board.can_undo(), "seviye basinda geri al kapali")

	var mv: Array = board.hint()
	await _do_fold(mv[0], mv[1])
	check(board.can_undo(), "katlamadan sonra geri al acik")
	check(board.model.key() != before, "katlama tahtayi degistirdi")
	check(board.moves == 1, "hamle sayaci arti bir")

	board.undo()
	await get_tree().create_timer(0.2).timeout
	check(board.model.key() == before, "geri al tahtayi tam geri getirdi")
	check(board.moves == 0, "geri al hamle sayacini da geri aldi")
	check(not board.can_undo(), "geri al yiginini tuketti")

	await _do_fold(mv[0], mv[1])
	board.restart()
	await _settled()
	check(board.model.key() == before, "yeniden basla ilk tahtayi geri getirdi")
	check(board.moves == 0, "yeniden basla hamle sayacini sifirladi")

	print("- gecersiz katlama")
	var bad := _find_invalid()
	if bad.is_empty():
		return
	var key_before: String = board.model.key()
	var moves_before: int = board.moves
	var cell: Vector2i = bad[0]
	var dir: Vector2 = bad[1]
	var p: Vector2 = board.board_offset + board._cell_center(cell.x, cell.y)
	board._press(p)
	board._motion(p + dir * board.cs * 0.4)
	board._motion(p + dir * (board._need + 20.0))
	board._release()
	await _settled()
	check(board.model.key() == key_before, "gecersiz katlama tahtayi degistirmedi")
	check(board.moves == moves_before, "gecersiz katlama hamle saymadi")
	check(board.interactive, "gecersiz katlamadan sonra kontrol geri geldi")


## Ogretici kartlar YALNIZCA bir kez cikmali, yoksa oyuncu her seviyede
## ayni kapatma islemini yapmak zorunda kalir.
func _test_teach_cards() -> void:
	print("- ogretici kartlar")
	for key in ["lock", "wild", "stars", "tools"]:
		SaveData.seen.erase(key)
		var card := TeachCard.make(key)
		main._present_modal(card)
		await get_tree().create_timer(0.1).timeout
		var found := _find_modal("teach_card")
		check(found != null, "%s karti olusturulup gosterilebiliyor" % key)
		if found:
			found.dismiss()
			await get_tree().create_timer(0.1).timeout
		check(_find_modal("teach_card") == null, "%s karti kapandi" % key)

	# ayni kart iki kez gosterilmemeli
	SaveData.seen = {}
	var lv := LevelGen.generate(14)
	var has_lock := false
	for code in (lv.board as BoardModel).cells:
		if Tiles.kind(code) == Tiles.K_LOCK:
			has_lock = true
	if has_lock:
		main.level = 14
		main._start_level()
		await get_tree().create_timer(0.35).timeout
		check(_find_modal("teach_card") != null, "mandal ilk kez gorulunce kart cikar")
		_dismiss_modals()
		await _settled()
		check(SaveData.has_seen("lock"), "kart kapaninca gorulmus isaretlenir")

		main._start_level()
		await get_tree().create_timer(0.35).timeout
		check(_find_modal("teach_card") == null, "ayni kart ikinci kez cikmaz")
		await _settled()


func _test_hint_economy() -> void:
	print("- ipucu ekonomisi")
	var stub := Ads.provider as StubAdProvider
	if stub == null:
		return
	stub.instant = true
	stub.force_fill = true
	stub.preload_all()
	check(Ads.rewarded_ready(), "odullu reklam hazir")

	# Cuzdani TAM sifirla: `purchased` bilerek gunluk yenilemeden etkilenmiyor,
	# yani onceki kosumdan kalan bakiye buraya sizar ve testi yaniltir.
	SaveData.hints.day = ""
	SaveData.hints.purchased = 0
	SaveData.refresh_hints()
	check(SaveData.hints.free_left == HintWallet.DAILY_FREE, "gun basi kontenjan yuklendi")
	check(SaveData.hints.purchased == 0, "test temiz cuzdanla basliyor")

	solved_flag = false
	main.level = 8
	main._start_level()
	await _settled()

	for i in HintWallet.DAILY_FREE:
		var before := SaveData.hints.total()
		main._on_hint()
		await get_tree().create_timer(0.08).timeout
		check(SaveData.hints.total() == before - 1, "ipucu bir azaldi (%d)" % i)

	check(SaveData.hints.total() == 0, "kontenjan tukendi")
	check(main._btn_hint.badge == 0, "rozet sifiri gosteriyor")

	main._on_hint()
	await get_tree().create_timer(0.2).timeout
	var offer := _find_modal("offer_card")
	check(offer != null, "ipucu bitince teklif karti acilir")
	if offer != null:
		offer.choose("ad")
		await get_tree().create_timer(0.3).timeout
		check(SaveData.hints.total() == 3, "odullu reklam +3 ipucu verdi")

	# vazgecilen odullu reklam ODUL VERMEMELI
	stub.force_fill = true
	stub.preload_all()
	var before_abandon := SaveData.hints.total()
	main._on_hint()
	await get_tree().create_timer(0.08).timeout
	check(SaveData.hints.total() == before_abandon - 1, "bakiye varken reklam sorulmadan harcanir")
	_dismiss_modals()


func _test_ad_gating() -> void:
	print("- gecis reklami kapilari")
	var stub := Ads.provider as StubAdProvider
	if stub == null:
		return
	stub.instant = true
	stub.force_fill = true
	stub.preload_all()

	Ads._last_ad_msec = 0          # 0 = "hic gosterilmedi"; 1 degil, cunku motor
	                               # daha 90 sn calismamis olabilir ve zaman tavani kapali kalir
	Ads._last_reward_msec = 0
	SaveData.ads_removed = false
	SaveData.levels_since_ad = 99

	var early: bool = await Ads.maybe_show_interstitial(3)
	check(not early, "ilk 10 seviyede gecis reklami cikmaz")

	Ads._last_ad_msec = 0
	SaveData.ads_removed = true
	var paid: bool = await Ads.maybe_show_interstitial(50)
	check(not paid, "reklamsiz satin alma gecis reklamini kapatir")

	SaveData.ads_removed = false
	SaveData.levels_since_ad = 99
	Ads._last_ad_msec = 0
	var shown: bool = await Ads.maybe_show_interstitial(50)
	check(shown, "kosullar saglaninca gecis reklami gosterilir")
	check(SaveData.levels_since_ad == 0, "gosterimden sonra seviye sayaci sifirlanir")

	var immediately: bool = await Ads.maybe_show_interstitial(51)
	check(not immediately, "hemen ardindan ikinci reklam cikmaz")
	_dismiss_modals()


func _find_invalid() -> Array:
	for c in board.model.creases():
		if board.model.fold(c[0], c[1], 0).ok:
			continue
		if c[0] == 0:
			return [Vector2i(c[1] - 1, board.model.h / 2), Vector2(1.0, 0.0)]
		return [Vector2i(board.model.w / 2, c[1] - 1), Vector2(0.0, 1.0)]
	return []


## DEVAM dugmesi para kazanmanin ana yolu: once gecis reklami, sonra seviye.
## Reklam basarisiz olsa veya atlansa bile oyun MUTLAKA ilerlemeli.
func _test_next_level_flow() -> void:
	print("- DEVAM akisi")
	SaveData.ads_removed = true          # once reklamsiz yol
	main.level = 7
	main._start_level()
	await _settled()
	main._next_level()
	await get_tree().create_timer(0.5).timeout
	check(main.level == 8, "DEVAM sonraki seviyeye gecirir")
	await _settled()
	check(board.model != null and board.interactive, "sonraki seviye oynanabilir durumda")

	# simdi reklamli yol: reklam gosterilse de akis takilmamali
	SaveData.ads_removed = false
	SaveData.levels_since_ad = 99
	Ads._last_ad_msec = 0
	Ads._last_reward_msec = 0
	var before_level: int = main.level
	main._next_level()
	await get_tree().create_timer(0.6).timeout
	check(main.level == before_level + 1, "reklam gosterilse de seviye ilerler")
	await _settled()
	check(board.interactive, "reklamdan sonra kontrol oyuncuya geri doner")
	_dismiss_modals()


## DOKUNMATIK surukleme. Telefonda "tutup cekme" calismiyordu: kod yalnizca
## fare olaylarini isliyordu ve Godot'un fare taklidine guveniyordu.
##
## Burada gercek InputEventScreenTouch/Drag olaylari uretip sisteme
## gonderiyoruz -- cihaz olmadan dokunmatik yolunu test etmenin tek yolu bu.
func _test_touch_drag() -> void:
	print("- dokunmatik surukleme")
	solved_flag = false
	main.level = 6
	main._start_level()
	await _settled()

	var mv: Array = board.hint()
	if mv.is_empty():
		check(false, "dokunma testi icin hamle bulunamadi")
		return
	var axis: int = mv[0]
	var g: int = mv[1]
	var cell := Vector2i(g - 1, board.model.h / 2) if axis == 0 else Vector2i(board.model.w / 2, g - 1)
	var dir := Vector2(1.0, 0.0) if axis == 0 else Vector2(0.0, 1.0)

	# Yerel koordinatlari EKRAN koordinatina ceviriyoruz: dokunma olaylari
	# viewport uzayinda geliyor.
	var xform := board.get_global_transform_with_canvas()
	var start_local: Vector2 = board.board_offset + board._cell_center(cell.x, cell.y)
	var before: String = board.model.key()
	var moves_before: int = board.moves

	# Tahtanin girdiye acik oldugundan emin ol: erken gonderilen dokunma
	# dusuyor ve jesti taklit fare olayi sahipleniyor.
	while not board.interactive:
		await get_tree().create_timer(0.05).timeout

	_touch(xform * start_local, true)
	await get_tree().create_timer(0.08).timeout
	check(board._dragging, "dokunma tahtayi tuttu")
	check(board._pointer != board.POINTER_NONE, "jesti bir isaretci sahiplendi")

	# Taklit fare olayi AYNI jesti ikinci kez islememeli: parmak zaten
	# tahtayi tutuyor, ikinci bir basma baslangic karesini kaydirmamali.
	var cell_before: Vector2i = board._cell
	var em := InputEventMouseButton.new()
	em.button_index = MOUSE_BUTTON_LEFT
	em.pressed = true
	em.position = xform * (start_local + Vector2(board.cs, board.cs))
	Input.parse_input_event(em)
	await get_tree().create_timer(0.06).timeout
	check(board._cell == cell_before, "ikinci basma jesti kacirmadi")

	_drag(xform * (start_local + dir * board.cs * 0.45))
	await get_tree().create_timer(0.08).timeout
	check(board._locked, "surukleme kat cizgisini belirledi")

	_drag(xform * (start_local + dir * (board._need + 30.0)))
	await get_tree().create_timer(0.08).timeout

	_touch(xform * (start_local + dir * (board._need + 30.0)), false)
	await _settled()

	check(board._pointer == board.POINTER_NONE, "birakma isaretci sahipligini birakti")
	check(board.moves == moves_before + 1, "dokunmatik surukleme katlamayi tamamladi")
	check(board.model.key() != before, "tahta gercekten degisti")


func _touch(at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.pressed = pressed
	e.position = at
	Input.parse_input_event(e)


func _drag(at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = 0
	e.position = at
	Input.parse_input_event(e)
