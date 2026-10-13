extends Node
##
## APP STORE ONIZLEME VIDEOSU icin oynanis kaydi.
##
##   bash tools/video_ios.sh [dil ...]
##
## NEDEN reel_runner.gd DEGIL. Iki kayit iki ayri sey icin:
##
##   reel_runner.gd  -> Play / reklam. 9:16, dort bolum, ~40 saniye.
##   video_runner.gd -> App Store onizlemesi. 886:1920 orani, iki bolum,
##                      15-30 saniye.
##
## Apple SURE SINIRINI yuklemede denetliyor: 15 saniyeden kisa ya da 30
## saniyeden uzun onizleme reddediliyor. Tanitim kaydini kirparak bu
## araliga sokmak bolumu ortasindan kesiyordu; ayri bir kurgu yazmak
## hem suresi tutan hem de son karesi kazanma animasyonuna denk gelen
## bir video veriyor.
##
## CERCEVE DE FARKLI ve bu goruntuyu degistiriyor. Onizleme 886x1920,
## yani 9:16'dan belirgin daha uzun. Kayit cozunurlugunu `video_ios.sh`
## gecici bir `override.cfg` ile 720x1560 yapiyor (ayni oran, taban
## genisligi 720 kalarak). Bu yuzden burada PENCERE BOYUTU
## KURULMUYOR -- reel_runner.gd'deki `window_set_size` cagrisinin
## karsiligi burada yok, olsaydi override'i ezip kaydi 9:16'ya
## dondururdu.
##
## Oynanis SAHTE DEGIL: her katlama gercek jest yoluyla yapiliyor --
## bas, surukle, birak -- ve oyun normal akisini isletiyor. Videoda
## gorunen sey oyunun kendisi.
##

##
## IKI BOLUM, ikisi de oyunun vaadini gosteriyor:
##
##   12 -> sade tahta. Tek jestin BUTUN tahtayi aynaladigi burada
##         birinci bakista anlasiliyor; kalabalik bir tahtada ayni
##         hareket karmasa gibi gorunuyor.
##   40 -> mandal ve joker. "Yeni kurallar geliyor" mesaji, oyunun
##         ilk dakikadan ibaret olmadigini soyleyen tek kare.
##
## Ucuncu bolum eklenince sure 30 saniyeyi asiyor.
const LEVELS := [12, 40]

## Sureler reel'inkinden kisa: onizlemede okuyucu zaten oyunu
## tanimiyor, ama 30 saniye tavani her seyden once geliyor.
const HOLD_BOARD := 0.95        ## tahtayi okumak icin duraklama
const HOLD_AFTER_FOLD := 0.38
const HOLD_WIN := 2.2
const HOLD_TITLE := 1.6
const HOLD_SON := 1.8
const SWIPE_FRAMES := 26

var main: Node
var board: BoardView


func _ready() -> void:
	main = get_parent()
	# Onizlemede ogretici kartlari, riza ekrani, parmak animasyonu ve
	# reklam yok -- hicbiri oyunun kendisi degil.
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
	await _sec(HOLD_SON)
	print("VIDEO OK")
	get_tree().quit()


func _play(level: int) -> void:
	main.level = level
	main._start_level()
	board = main.board
	await _sec(HOLD_BOARD)

	# Ipucunun onerdigi hamleyi oynuyoruz: cozum her zaman PAR
	# uzunlugunda bitiyor, yani video her seferinde uc yildizla
	# kapaniyor. Onizlemede kaybeden bir oynanis gostermek istemiyoruz.
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
## Parmak, kat cizgisinin hemen yanindaki kareden tutup karsiya
## suruklüyor. Hareket yavas baslayip hizlaniyor (smoothstep) -- sabit
## hizli surukleme robot gibi duruyor, bu insan eli gibi.
##
## Birakma noktasi kasten TAM katlanmadan once (0.85): kalan yolu oyunun
## kendi yaslanma animasyonu tamamliyor ve kagit "sak" diye oturuyor.
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


## Alt cubuk ve kazanma paneli etiketleri acilista bir kez kuruluyor;
## oyunda dil degisince sahne bastan yukleniyor, burada yuklemiyoruz.
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
