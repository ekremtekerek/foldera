extends Node
##
## Magaza tanitim videosu icin oynanis kaydi.
##
##   godot --path . --write-movie D:/Temp/foldera-video/en.avi --fixed-fps 60 -- reel en
##
## Godot Movie Maker kipinde zamani SABIT ADIMLA ilerletiyor: kayit gercek
## zamandan cok daha yavas surse de videodaki tempo burada yazdigimiz sureyle
## birebir ayni cikiyor. Bu yuzden beklemeler saniye cinsinden ve guvenilir.
##
## Oynanis SAHTE DEGIL. Her katlama gercek jest yoluyla yapiliyor -- bas,
## surukle, birak -- ve oyun normal akisini isletiyor (ses, konfeti, yildiz,
## kazanma karti). Videoda gorunen sey oyunun kendisi.
##

## Kisa, artan zorluk: sade tahta -> mandal ve joker -> kalabalik 6x6.
const LEVELS := [6, 12, 40, 54]

const HOLD_BOARD := 1.15    ## tahtayi okumak icin duraklama
const HOLD_AFTER_FOLD := 0.45
const HOLD_WIN := 2.5
const HOLD_TITLE := 2.4
const SWIPE_FRAMES := 26

var main: Node
var board: BoardView


func _ready() -> void:
	# Kayit 9:16 olmali. Godot pencereyi acilista masaustu yuksekligine
	# kirpiyor (720x1061 kaliyor); Movie Maker ilk KAREDE boyutu sabitledigi
	# icin duzeltmeyi burada, ilk kare cizilmeden yapiyoruz.
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(720, 1280))
	main = get_parent()
	# Tanitimda ogretici kartlari, riza ekrani, parmak animasyonu ve reklam yok.
	SaveData.total_folds = 99
	SaveData.consent = "limited"
	SaveData.ads_removed = true
	SaveData.seen = {"lock": true, "wild": true, "stars": true, "tools": true}
	_run()


func _run() -> void:
	TranslationServer.set_locale(_lang())
	_relabel()
	await _sec(0.35)
	await _drain_modals()

	main._show_title()
	await _sec(HOLD_TITLE)

	for level in LEVELS:
		await _play(level)

	main._show_title()
	await _sec(HOLD_TITLE + 0.6)
	print("REEL OK")
	get_tree().quit()


func _play(level: int) -> void:
	main.level = level
	main._start_level()
	board = main.board
	await _sec(HOLD_BOARD)

	# Ipucunun onerdigi hamleyi oynuyoruz: cozum her zaman PAR uzunlugunda
	# bitiyor, yani video her seferinde uc yildizla kapaniyor.
	var guard := 0
	while not board.model.is_solved() and guard < 12:
		guard += 1
		var mv: Array = board.hint()
		if mv.is_empty():
			break
		await _swipe(mv[0], mv[1])
		await board.fold_committed
		await _sec(HOLD_AFTER_FOLD)

	await _sec(HOLD_WIN)


##
## Parmak, kat cizgisinin hemen yanindaki kareden tutup karsiya suruklüyor.
## Hareket yavas baslayip hizlaniyor (smoothstep) -- sabit hizli surukleme
## robot gibi duruyor, bu insan eli gibi.
##
## Birakma noktasi kasten TAM katlanmadan once (0.85): kalan yolu oyunun kendi
## yaslanma animasyonu tamamliyor ve kagit "sak" diye oturuyor.
##
func _swipe(axis: int, g: int) -> void:
	var cell := Vector2i(g - 1, int(board.model.h / 2)) if axis == 0 \
		else Vector2i(int(board.model.w / 2), g - 1)
	var dir := Vector2(1, 0) if axis == 0 else Vector2(0, 1)
	var p: Vector2 = board.board_offset + board._cell_center(cell.x, cell.y)
	board._press(p)
	for i in SWIPE_FRAMES:
		var k := float(i + 1) / float(SWIPE_FRAMES)
		board._motion(p + dir * board.cs * 0.85 * (k * k * (3.0 - 2.0 * k)))
		await get_tree().process_frame
	board._release()


# ---------------------------------------------------------------- altyapi

func _sec(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _lang() -> String:
	for a in OS.get_cmdline_user_args():
		if a.length() == 2 and Loc.NATIVE_NAME.has(a):
			return a
	return "en"


## Alt cubuk ve kazanma paneli etiketleri acilista bir kez kuruluyor; oyunda
## dil degisince sahne bastan yukleniyor, burada yuklemiyoruz.
func _relabel() -> void:
	main._btn_undo.label = Loc.t("BTN_UNDO")
	main._btn_restart.label = Loc.t("BTN_RESTART")
	main._btn_hint.label = Loc.t("BTN_HINT")
	for b in [main._btn_undo, main._btn_restart, main._btn_hint]:
		b.queue_redraw()
	for pair in [["WinNext", "BTN_CONTINUE"], ["WinReplay", "BTN_REPLAY"]]:
		var w = main._win.find_child(pair[0], true, false)
		if w != null:
			w.caption = Loc.t(pair[1])
			w.queue_redraw()


func _drain_modals() -> void:
	for i in 8:
		var any := false
		for t in ["teach_card", "offer_card", "consent_screen", "language_card"]:
			var m := _find_in(main._root, t)
			if m == null:
				continue
			any = true
			if m.has_method("dismiss"):
				m.dismiss()
			elif m.has_method("choose"):
				m.choose("dismiss")
			else:
				m.queue_free()
		if not any:
			return
		await _sec(0.25)


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
