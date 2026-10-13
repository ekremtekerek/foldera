extends Node
##
## Magaza gorsellerini uretir:  godot --path . -- store
##
## Ekran goruntuleri SAHTE degil: her kare gercekten oynanan oyundan, o dilin
## arayuzuyle aliniyor, sonra afis cercevesine 1:1 basiliyor. Boylece magazada
## gorulen sey indirilen seyle birebir ayni.
##
## Cikti: store/<dil>/01..06.png (1080x1920), store/<dil>/feature.png (1024x500),
## store/icons/* ve store/LISTING.md
##

const OUT := "D:/Projects/foldera/store/"
const POSTER := preload("res://tools/store_poster.gd")
const COPY := preload("res://tools/store_copy.gd")

##
## APP STORE OLCULERI.
##
##   godot --path . -- store ios        13 dil, iPhone 6.1"
##   godot --path . -- store ipad       13 dil, 13 inclik iPad
##   godot --path . -- store ios en tr  secili diller
##
## Apple iPhone icin 1179x2556 ya da 1206x2622 kabul ediyor; buyuk olani
## seciliyor, tek set butun modern iPhone'lari karsiliyor.
##
## iPAD SETI ZORUNLU, istege bagli degil: Godot'nun iOS disa aktariminda
## cihaz ailesi secenegi yok, uretilen Xcode projesi EVRENSEL. Paket
## iPad'i de hedefledigi icin App Store Connect "Add for Review"da 13
## inclik iPad goruntusu olmadan gecmiyor (Arcera'da tam olarak bu
## satirla reddetti).
const IOS_W := 1206
const IOS_H := 2622
const IPAD_W := 2048
const IPAD_H := 2732

## App Store afisleri depoya degil, gecici dizine yaziliyor: 13 dil x 6
## kare x iki cihaz = 156 dosya, ~60 MB. Depoda isi yok.
const IOS_OUT := "D:/Temp/foldera-store"

##
## URUN SAYFASI BASLIGI: 5244x2950 PNG, dil basina bir dosya.
##
##   godot --path . -- store header        (13 dil)
##   godot --path . -- store header en tr
##   node tools/appstore_header.mjs        (yukler)
##
## Tek dosya IKI yere gidiyor -- urun sayfasinin basligi ve arama
## sonucu gorseli -- cunku Apple bu olcuyu "universalAsset" sayiyor.
## Yerlesim ve guvenli alan hesabi store_poster.gd `_draw_header()`
## icinde.
const PROMO_OUT := "D:/Temp/foldera-promo"
const BASLIK_W := 5244
const BASLIK_H := 2950

## Play, ulkeye gore o dilin sayfasini gosterir. Turkiye -> tr, digerleri
## kendi dilinde, geri kalan her yer -> en (varsayilan sayfa).
const ALL_LOCALES := ["en", "tr", "es", "pt", "de", "fr", "it", "ru", "pl", "nl", "id", "vi", "uk"]

## Tam kosu bu makinede 10 dakikayi asabiliyor; "-- store half1 / half2" ile
## ikiye bolunebiliyor. LISTING.md her zaman 13 dilin hepsini yaziyor.
var LOCALES: Array = ALL_LOCALES

var main: Node
var board: BoardView

var _shot_vp: SubViewport
var _shot_poster
var _feat_vp: SubViewport
var _feat_poster

## App Store kipi. `_ipad` tek basina anlamsiz; `_ios` ile birlikte isliyor.
var _ios := false
var _ipad := false
## Urun sayfasi basligi (5244x2950). Oteki kiplerden bagimsiz.
var _baslik := false


func _ready() -> void:
	main = get_parent()
	# Kareler temiz olsun: ogretici kartlari, riza ekrani ve parmak animasyonu
	# magaza gorselinde oyunu anlatmiyor, kapatiyor.
	SaveData.total_folds = 99
	SaveData.consent = "limited"
	SaveData.seen = {"lock": true, "wild": true, "stars": true, "tools": true}
	_ios = OS.get_cmdline_user_args().has("ios")
	_ipad = OS.get_cmdline_user_args().has("ipad")
	_baslik = OS.get_cmdline_user_args().has("header")
	if _ipad:
		_ios = true
	LOCALES = _pick_locales()
	DirAccess.make_dir_recursive_absolute(OUT)
	_run()


## Afis olcusu: Play 1080x1920, App Store cihaza gore.
func _afis_olcu() -> Vector2i:
	if _ipad:
		return Vector2i(IPAD_W, IPAD_H)
	if _ios:
		return Vector2i(IOS_W, IOS_H)
	return Vector2i(1080, 1920)


func _afis_yol(code: String, i: int) -> String:
	if _ios:
		var onek := "ipad-" if _ipad else "ios-"
		return "%s/%s%s/%02d.jpg" % [IOS_OUT, onek, code, i + 1]
	return "%s%s/%02d.png" % [OUT, code, i + 1]


func _run() -> void:
	# Kare 9:16 olmali (Play telefon orani). Pencere masaustu yuksekligine
	# sikisiyorsa oyun daha kisa render ediyor; afis o zaman gerilmesin diye
	# kart olculeri YAKALANAN goruntunun oranindan turetiliyor.
	DisplayServer.window_set_position(Vector2i(0, 0))
	DisplayServer.window_set_size(Vector2i(720, 1280))
	await _wait(30)
	print("  oyun karesi: ", get_viewport().get_visible_rect().size)

	if _baslik:
		await _basliklar()
		print("STORE OK  ->  ", PROMO_OUT)
		get_tree().quit()
		return

	var olcu := _afis_olcu()
	_shot_vp = _make_vp(olcu.x, olcu.y, false)
	_shot_poster = _shot_vp.get_child(0)

	# Ozellik grafigi, simgeler ve LISTING.md YALNIZCA Play icin. App
	# Store'da karsiliklari yok; uretmek hem bos zaman hem de depodaki
	# Play ciktilarini gereksiz yere yeniden yazmak olurdu.
	if not _ios:
		_feat_vp = _make_vp(1024, 500, false)
		_feat_poster = _feat_vp.get_child(0)
		# Katlanan kosenin altina zemin rengi basiliyor; ozellik grafiginin
		# zemini degrade oldugu icin logonun bulundugu YUKSEKLIKTEKI renk
		# veriliyor, yoksa kosede acik bir ucgen kaliyor.
		_add_logo(_feat_poster, Rect2(700, 106, 288, 288),
			Palette.BG_TOP.lerp(Palette.BG_BOTTOM, 0.42))

		if OS.get_cmdline_user_args().has("plate"):
			await _plates()
			print("STORE OK  ->  ", OUT)
			get_tree().quit()
			return

		await _icons()

		# Yalnizca ikonlar istendiyse burada duruluyor: afisler on uc dil
		# oynandigi icin dakikalar suruyor, ikonlar saniyeler.
		if OS.get_cmdline_user_args().has("icons"):
			print("STORE OK  ->  ", OUT)
			get_tree().quit()
			return

	for code in LOCALES:
		_set_lang(code)
		DirAccess.make_dir_recursive_absolute(
			_afis_yol(code, 0).get_base_dir())
		var texts: Array = COPY.SHOTS[code]
		for i in texts.size():
			await _stage(i)
			var tex := await _capture_game()
			_shot_poster.mode = "shot"
			_shot_poster.headline = texts[i].h
			_shot_poster.sub = texts[i].s
			_shot_poster.shot = tex
			_shot_poster.shot_rect = _fit_card(tex.get_size(), olcu)
			await _save(_shot_vp, _shot_poster, _afis_yol(code, i))
			await _clear_stage()

		if not _ios:
			_feat_poster.mode = "feature"
			_feat_poster.sub = COPY.FEATURE[code]
			await _save(_feat_vp, _feat_poster, "%s%s/feature.png" % [OUT, code])
		print("  %s tamam" % code)

	if not _ios:
		_write_listing()
	print("STORE OK  ->  ", IOS_OUT if _ios else OUT)
	get_tree().quit()


# ------------------------------------------------------------------ sahneler

##
## Her kare, basligin ANLATTIGI seyi gosteren bir oyun durumu:
##   0 mekanik      -> kagit yari katlanmis, en aciklayici an
##   1 ozgunluk     -> katlama basliyor, hedef hayaletleri gorunur
##   2 cikmaz yok   -> mandalli, kalabalik tahta (en "zor" gorunen kare)
##   3 icerik       -> temiz orta seviye tahtasi
##   4 uc yildiz    -> kazanma ekrani
##   5 baskisizlik  -> patlama sonrasi oturmus, sakin tahta
##
func _stage(i: int) -> void:
	match i:
		0:
			main.level = 47
			main._start_level()
			await _wait(70)
			_grab_best(0)
			board._set_t(0.20)
			await _wait(2)
		1:
			main.level = 54
			main._start_level()
			await _wait(70)
			_grab_best(0)
			board._set_t(0.12)
			await _wait(2)
		2:
			main.level = 59
			main._start_level()
			await _wait(70)
		3:
			main.level = 51
			main._start_level()
			await _wait(70)
		4:
			main.level = 16
			main._start_level()
			await _wait(50)
			main._on_solved(3)
			await _wait(160)
		5:
			main.level = 42
			main._start_level()
			await _wait(60)
			if _grab_best(0):
				board._release()
				await _wait(120)


func _clear_stage() -> void:
	board = main.board
	if board != null and board._dragging:
		board._cancel(false)
	await _wait(20)
##
## Afiste EN IYI GORUNEN katlamayi secer -- ipucununkini degil. Kriterler:
##   * dikey kat cizgisi tercih edilir: kanat yana acilinca katlama okunuyor,
##     yatayda ust kenara sikisip cizim hatasi gibi duruyor
##   * cok patlama -> cok yesil halka -> mekanik tek karede anlasiliyor
##   * kat cizgisi ortaya yakin -> kanat genis, kagit gercekten katlanmis duruyor
##
func _grab_best(axis_pref: int) -> bool:
	board = main.board
	var pick: Array = []
	var best := -9999
	for c in board.model.creases():
		for side in 2:
			var r: Dictionary = board.model.fold(c[0], c[1], side)
			if not r.ok:
				continue
			var n: int = board.model.w if c[0] == 0 else board.model.h
			var sc := int((r.pops as Array).size()) * 10
			sc += 100 if c[0] == axis_pref else 0
			sc -= absi(c[1] - int(n / 2)) * 4
			if sc > best:
				best = sc
				pick = [c[0], c[1], side]
	if pick.is_empty():
		return false
	var axis: int = pick[0]
	var g: int = pick[1]
	var side: int = pick[2]
	var cell := Vector2i.ZERO
	var dir := Vector2.ZERO
	if axis == 0:
		cell = Vector2i((g - 1) if side == 0 else g, int(board.model.h / 2))
		dir = Vector2(1, 0) if side == 0 else Vector2(-1, 0)
	else:
		cell = Vector2i(int(board.model.w / 2), (g - 1) if side == 0 else g)
		dir = Vector2(0, 1) if side == 0 else Vector2(0, -1)
	var p: Vector2 = board.board_offset + board._cell_center(cell.x, cell.y)
	board._press(p)
	board._motion(p + dir * board.cs * 0.6)
	return true


# -------------------------------------------------------------------- ikonlar

##
## Uygulama ikonu. Su an APK Godot'un varsayilan robot ikonuyla cikiyordu --
## magazadaki en onemli tek gorsel bu, oyunla alakasi olmayan bir simge
## indirmeyi dogrudan dusurur.
##
func _icons() -> void:
	DirAccess.make_dir_recursive_absolute(OUT + "icons")
	var bg: Color = POSTER.ICON_BG

	# Play magaza ikonu (512) ve eski usul baslatici ikonu (192)
	var vp := _make_vp(512, 512, false)
	var p = vp.get_child(0)
	p.mode = "icon"
	await _save(vp, p, OUT + "icon-512.png")
	await _save_scaled(vp, p, OUT + "icons/launcher-192.png", 192)

	# Uyarlanabilir ikon: on katman SAYDAM zeminde ve guvenli alanda (%66)
	# durmali, yoksa cihaz maskeleri kosesini kirpar.
	var fg := _make_vp(432, 432, true)
	var fp = fg.get_child(0)
	fp.mode = "icon_fg"
	await _save(fg, fp, OUT + "icons/adaptive-foreground-432.png")

	var bgv := _make_vp(432, 432, false)
	var bp = bgv.get_child(0)
	bp.mode = "icon_bg"
	await _save(bgv, bp, OUT + "icons/adaptive-background-432.png")

	var mv := _make_vp(432, 432, true)
	var mp = mv.get_child(0)
	mp.mode = "icon_mono"
	await _save(mv, mp, OUT + "icons/adaptive-monochrome-432.png")

	#
	# APP STORE IKONU: 1024x1024 ve ALFA KANALI OLMAMALI.
	#
	# Saydam pikseli olan ikon yuklemede "Invalid large app icon" ile geri
	# donuyor. "icon" kipi zemini opak basiyor, o yuzden saydam olmayan
	# bir SubViewport yetiyor.
	#
	# `store/` degil `brand/` altinda duruyor: bu dosya magaza ciktisi
	# degil, DERLEME GIRDISI -- Godot'nun iOS disa aktarimi onu okuyup
	# uygulama ikonu setini uretiyor.
	#
	DirAccess.make_dir_recursive_absolute("D:/Projects/foldera/brand")
	var ios := _make_vp(1024, 1024, false)
	var ip = ios.get_child(0)
	ip.mode = "icon"
	await _save_opak(ios, ip, "D:/Projects/foldera/brand/ios-icon-1024.png")
	print("  ikonlar tamam")


# ---------------------------------------------------------------- altyapi

func _make_vp(w: int, h: int, transparent: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, h)
	vp.transparent_bg = transparent
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var p = POSTER.new()
	p.size = Vector2(w, h)
	vp.add_child(p)
	return vp


## Logo isareti gercek bilesenin kendisi -- afisteki kagit, oyundaki kagitla
## ayni golge ve degrade recetesinden geciyor. Animasyonu durduruyoruz ve
## esleri kavusmadan HEMEN once yakalayan bir faz seciyoruz.
func _add_logo(parent, rect: Rect2, cut: Color) -> void:
	var logo := LogoMark.new()
	logo.position = rect.position
	logo.size = rect.size
	logo.custom_minimum_size = rect.size
	logo.cut_color = cut
	logo.t = 0.55
	parent.add_child(logo)
	logo.set_process(false)


##
## Uzantiya gore kaydediyor. Play afisleri PNG (kayipsiz, depoda duruyor,
## Play zaten PNG bekliyor); App Store afisleri JPEG.
##
## NEDEN JPEG: 13 dil x 6 kare x iki cihaz = 156 dosya. PNG olarak
## ~2,5 MB, JPEG olarak ~350 KB. Apple ikisini de kabul ediyor ve
## yukleme bu farki dakikalarla olcuyor. Kalite 0.92: 2622 pikselde
## gozle fark yok.
func _save(vp: SubViewport, p, path: String) -> void:
	p.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	if path.get_extension().to_lower() == "jpg":
		img.save_jpg(path, 0.92)
	else:
		img.save_png(path)


##
## ALFA KANALI OLMADAN kaydeder.
##
## `transparent_bg = false` olan bir SubViewport'un dokusunda da alfa
## kanali VAR -- her piksel opak ama kanal duruyor ve `save_png` RGBA
## yaziyor. Apple bunu "Invalid large app icon" ile reddediyor; hatanin
## ortaya ciktigi yer on bes dakikalik bir derlemenin SONU.
##
## `FORMAT_RGB8`a cevirmek kanali tamamen dusuruyor (ffprobe: rgb24).
func _save_opak(vp: SubViewport, p, path: String) -> void:
	p.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(path)


func _save_scaled(vp: SubViewport, p, path: String, px: int) -> void:
	p.queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(px, px, Image.INTERPOLATE_LANCZOS)
	img.save_png(path)


func _capture_game() -> Texture2D:
	await RenderingServer.frame_post_draw
	return ImageTexture.create_from_image(get_viewport().get_texture().get_image())


func _wait(frames_at_60: int) -> void:
	await get_tree().create_timer(float(frames_at_60) / 60.0).timeout


func _set_lang(code: String) -> void:
	TranslationServer.set_locale(code)
	# Alt cubuk etiketleri bir kez olusturuluyor; dil degisince elle tazele.
	main._btn_undo.label = Loc.t("BTN_UNDO")
	main._btn_restart.label = Loc.t("BTN_RESTART")
	main._btn_hint.label = Loc.t("BTN_HINT")
	# Kazanma panelindeki dugmeler acilista bir kez kuruluyor. Oyunda dil
	# degisince sahne bastan yukleniyor (main._show_language_picker), burada
	# yuklemiyoruz -- bu yuzden metinlerini elle tazelemek gerekiyor, yoksa
	# Ingilizce afiste Turkce "DEVAM" dugmesi kaliyor.
	_relabel("WinNext", "BTN_CONTINUE")
	_relabel("WinReplay", "BTN_REPLAY")
	for b in [main._btn_undo, main._btn_restart, main._btn_hint]:
		b.queue_redraw()


##
## URUN SAYFASI BASLIKLARI -- dil basina bir 5244x2950 PNG.
##
## Oyun karesi olarak SIFIRINCI sahne kullaniliyor: kagit yari katlanmis,
## yani tek karede "jest tahtanin tamamini oynatiyor" okunuyor. Basligin
## metni de ayni sahnenin metni (COPY.SHOTS[dil][0]), boylece gorsel ile
## cumle ayni seyi soyluyor.
##
func _basliklar() -> void:
	var vp := _make_vp(BASLIK_W, BASLIK_H, false)
	var p = vp.get_child(0)
	p.mode = "header"
	for code in LOCALES:
		_set_lang(code)
		var dizin := "%s/%s" % [PROMO_OUT, code]
		DirAccess.make_dir_recursive_absolute(dizin)
		await _stage(0)
		var tex := await _capture_game()
		var metin: Dictionary = COPY.SHOTS[code][0]
		p.headline = metin.h
		p.sub = metin.s
		p.shot = tex
		# Alfa kanali olmadan: varlik kutuphanesi saydam pikselli gorseli
		# islerken kenarlarda koyu bir hale birakiyor ve dosya da bos yere
		# buyuyor. Ayni gerekce ikonda da var (_save_opak).
		await _save_opak(vp, p, "%s/appstore-header-5244x2950.png" % dizin)
		await _clear_stage()
		print("  %s tamam" % code)


# -------------------------------------------------------------- magaza metni

func _write_listing() -> void:
	var out := PackedStringArray()
	out.append("# FOLDERA — Play Console metinleri")
	out.append("")
	out.append("`tools/store_shots.gd` tarafindan uretildi. Her dil icin: baslik")
	out.append("(<=30 karakter), kisa aciklama (<=80) ve tam aciklama.")
	out.append("")
	out.append("Gorseller: `store/<dil>/01..06.png` (1080x1920, telefon ve tablet")
	out.append("yuvalarinin ikisine de uyar) ve `store/<dil>/feature.png` (1024x500).")
	out.append("Uygulama ikonu: `store/icon-512.png`.")
	out.append("")
	for code in ALL_LOCALES:
		var e: Dictionary = COPY.LISTING[code]
		out.append("---")
		out.append("")
		out.append("## %s" % code)
		out.append("")
		out.append("**Baslik** (%d/30)" % (e.title as String).length())
		out.append("```")
		out.append(e.title)
		out.append("```")
		out.append("")
		out.append("**Kisa aciklama** (%d/80)" % (e.short as String).length())
		out.append("```")
		out.append(e.short)
		out.append("```")
		out.append("")
		out.append("**Tam aciklama**")
		out.append("```")
		out.append(e.full)
		out.append("```")
		out.append("")
	var f := FileAccess.open(OUT + "LISTING.md", FileAccess.WRITE)
	if f == null:
		push_error("LISTING.md yazilamadi")
		return
	f.store_string("\n".join(out) + "\n")
	f.close()


##
## Oyun karesini afise ORANI BOZULMADAN yerlestirir. Kart alta sabitleniyor
## (baslik uzunlugu degisse de cerceveleme ayni duruyor) ve metin blogu icin
## ust tarafta her zaman yer birakiliyor.
##
##
## Oyun kartinin afis icindeki yeri.
##
## Sayilar 1080x1920 icin ayarlanmisti; App Store baska olculer istedigi
## icin ORAN olarak yazildilar. 1080x1920'de sonuc bit bit ayni kaliyor
## (0.718518*1080 = 776, 0.951041*1920 = 1826, 0.253125*1920 = 486).
##
## iPad afisi cok daha genis (2048x2732, oran 0.75): orada kart genisligi
## degil, metne ayrilan YUKSEKLIK baglayici oluyor ve asagidaki kisma
## kendiliginden devreye giriyor.
func _fit_card(tex: Vector2, afis: Vector2i) -> Rect2:
	var pw := float(afis.x)
	var ph := float(afis.y)
	var max_w := pw * 0.718518
	var bottom := ph * 0.951041
	# METNE AYRILAN YER GENISLIKLE OLCULUYOR, YUKSEKLIKLE DEGIL.
	#
	# Yazi boyutlari `store_poster.gd` icindeki `_k()` ile, yani afisin
	# GENISLIGIYLE buyuyor. Bu payi yukseklikle hesaplamak iPad'de
	# (2048x2732 -- genis ve basik) metni buyutup ona ayrilan yeri
	# daraltiyordu: alt baslik kartin altinda kaliyordu.
	# 0.45 * 1080 = 486, yani 1080x1920'de eski sayiyla birebir ayni.
	var text_room := pw * 0.45
	var w := max_w
	var h := w * tex.y / tex.x
	if bottom - h < text_room:
		h = bottom - text_room
		w = h * tex.x / tex.y
	return Rect2(round((pw - w) * 0.5), round(bottom - h), round(w), round(h))


func _relabel(node_name: String, key: String) -> void:
	var b = main._win.find_child(node_name, true, false)
	if b == null:
		push_warning("Magaza afisi: %s bulunamadi" % node_name)
		return
	b.caption = Loc.t(key)
	b.queue_redraw()


## Argumanlarda gecen dil kodlari secimi daraltiyor
## ("-- store ios en tr"); hicbiri yoksa half1/half2, o da yoksa hepsi.
func _pick_locales() -> Array:
	var a := OS.get_cmdline_user_args()
	var secili: Array = []
	for kod in ALL_LOCALES:
		if a.has(kod):
			secili.append(kod)
	if not secili.is_empty():
		return secili
	if a.has("half1"):
		return ALL_LOCALES.slice(0, 7)
	if a.has("half2"):
		return ALL_LOCALES.slice(7)
	return ALL_LOCALES


##
## Tanitim videosunun yatay cercevesi -- her dil icin bir plaka. Oynanis
## gerekmedigi icin saniyeler suruyor:  godot --path . -- store plate
##
func _plates() -> void:
	var vp := _make_vp(1920, 1080, false)
	var p = vp.get_child(0)
	p.mode = "reel_bg"
	for code in ALL_LOCALES:
		DirAccess.make_dir_recursive_absolute(OUT + code)
		p.sub = COPY.FEATURE[code]
		var s: Array = COPY.SHOTS[code]
		# Afislerdeki 3., 4. ve 5. baslik = en guclu uc iddia
		p.bullets = PackedStringArray([
			(s[2].h as String).replace("\n", " "),
			(s[3].h as String).replace("\n", " "),
			(s[4].h as String).replace("\n", " "),
		])
		await _save(vp, p, "%s%s/reel-plate.png" % [OUT, code])
	print("  plakalar tamam")
