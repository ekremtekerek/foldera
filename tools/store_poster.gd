extends Control
##
## Magaza gorsellerinin cizimi. Oyunun kendi yuzey recetesini (Surface),
## paletini ve yazi tipini kullaniyor -- afis ile oyunun ekrani ayni
## malzemeden cikiyor, magaza sayfasi ile uygulama arasinda kopukluk olmuyor.
##
## Dort mod:
##   shot    1080x1920  ekran goruntusu afisi (baslik + cerceveli oyun ekrani)
##   feature 1024x500   Play one cikan ozellik grafigi
##   icon    kare       uygulama ikonu (dolu zemin)
##   fg/bg/mono         Android uyarlanabilir ikon katmanlari
##
## ASO notu: yazi KUCUK kucuk resimde okunmali. Bu yuzden baslik en fazla iki
## satir, taban 82 px ve sigmazsa 54 pikselden asagi inmiyor -- inmesi gerekiyorsa
## metin zaten cok uzundur.

const ICON_BG := Color("f2ead9")

var mode := "shot"
var headline := ""
var sub := ""
var brand := "FOLDERA"
var shot: Texture2D = null
var shot_rect := Rect2(180, 544, 720, 1280)

## Tanitim videosu plakasi: solda marka ve maddeler, sagda videonun oturacagi
## yer. Video ffmpeg ile TAM bu dikdortgene bindiriliyor.
var bullets := PackedStringArray()
var video_rect := Rect2(1218, 40, 562, 1000)


func _draw() -> void:
	match mode:
		"shot": _draw_shot()
		"feature": _draw_feature()
		"header": _draw_header()
		"reel_bg": _draw_reel_plate()
		"icon":
			draw_rect(Rect2(Vector2.ZERO, size), ICON_BG)
			_icon_mark(ICON_BG, 0.70)
		"icon_bg": draw_rect(Rect2(Vector2.ZERO, size), ICON_BG)
		# On katman saydam zeminde ve guvenli alanda (%66) kalmali; cihaz
		# maskeleri disini kirpiyor.
		"icon_fg": _icon_mark(ICON_BG, 0.56)
		"icon_mono": _draw_mono()
		_: pass


# --------------------------------------------------------------- ortak parcalar

func _gradient_bg() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_polygon(
		PackedVector2Array([r.position, Vector2(r.end.x, 0), r.end, Vector2(0, r.end.y)]),
		PackedColorArray([Palette.BG_TOP, Palette.BG_TOP, Palette.BG_BOTTOM, Palette.BG_BOTTOM]))


## Sag ust kosede buyuk, cok soluk bir kat izi. Marka isaretini tekrarlamadan
## "bu oyun katlamayla ilgili" diyor.
func _fold_motif(scale := 0.58) -> void:
	var s := size.x * scale
	var tr := Vector2(size.x, 0.0)
	draw_colored_polygon(
		PackedVector2Array([tr + Vector2(-s, 0), tr, tr + Vector2(0, s)]),
		Color(1, 1, 1, 0.30))
	draw_line(tr + Vector2(-s, 0), tr + Vector2(0, s),
		Color(0.84, 0.78, 0.68, 0.45), 3.0, true)


## Kucuk marka isareti: kose yuvarlatilmis sayfa, katlanmis kosesi ve iki es.
## icon.svg ile ayni kompozisyon -- kucuk boyutta net kalsin diye sade.
func _mini_mark(at: Vector2, s: float) -> void:
	var sheet := Rect2(at, Vector2(s, s))
	Surface.fill(self, sheet, s * 0.22, Palette.PAPER)
	var f := s * 0.40
	var tr := Vector2(sheet.end.x, sheet.position.y)
	draw_colored_polygon(
		PackedVector2Array([tr + Vector2(-f, 0), tr, tr + Vector2(0, f)]), Palette.BG_TOP)
	draw_colored_polygon(
		PackedVector2Array([tr + Vector2(-f, 0), tr + Vector2(0, f), tr + Vector2(-f, f)]),
		Palette.PAPER_EDGE)
	draw_line(tr + Vector2(-f, 0), tr + Vector2(0, f), Palette.PAPER_EDGE.darkened(0.3), 2.0, true)
	var r := s * 0.15
	var cy := sheet.position.y + s * 0.68
	draw_circle(Vector2(sheet.position.x + s * 0.31, cy), r, Palette.ACCENT)
	draw_circle(Vector2(sheet.position.x + s * 0.66, cy), r, Palette.ACCENT)


func _rule(center_x: float, y: float, w: float) -> void:
	Surface.fill(self, Rect2(center_x - w * 0.5, y, w, 9.0), 4.5, Palette.ACCENT)


## Satirlarin en genisini verilen genislige sigdiran yazi boyutu.
static func fit(f: Font, lines: PackedStringArray, max_w: float, hi: int, lo: int) -> int:
	var s := hi
	while s > lo:
		var widest := 0.0
		for l in lines:
			widest = maxf(widest, f.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x)
		if widest <= max_w:
			break
		s -= 2
	return s


func _line(f: Font, text: String, baseline: float, px: int, col: Color) -> void:
	draw_string(f, Vector2(0, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, px, col)


# ------------------------------------------------------------ ekran goruntusu

##
## OLCEK KATSAYISI. Afisin butun sayilari 1080 piksel genislige gore
## ayarlandi. App Store ayni tasarimi BASKA genisliklerde istiyor --
## iPhone 6.1" 1206, 13 inclik iPad 2048 -- ve sayilar sabit kalirsa
## iPad afisinde yazi, kenar bosluklari ve golgeler kanvasa gore
## kuculup tasarimi dagitiyor.
##
## 1080'de k = 1.0, yani Play gorselleri bit bit ayni kaliyor.
func _k() -> float:
	return size.x / 1080.0


func _draw_shot() -> void:
	_gradient_bg()
	_fold_motif(0.52)

	var k := _k()
	var pad := 92.0 * k
	var avail := size.x - pad * 2.0
	var head := UiTheme.font(UiTheme.HEAVY)
	var body := UiTheme.font(UiTheme.BODY)

	var lines := headline.split("\n")
	var hs := fit(head, lines, avail, int(82.0 * k), int(54.0 * k))
	var ss := fit(body, PackedStringArray([sub]), avail, int(40.0 * k), int(28.0 * k))
	var lh := float(hs) * 1.16

	var marka_px := int(34.0 * k)
	var isaret := 46.0 * k

	# Metin blogu, kartin ustundeki bosluga DIKEY ORTALANIYOR. Boylece baslik
	# bir satir da olsa iki satir da olsa cerceveleme ayni duruyor.
	var block := isaret + 34.0 * k + 9.0 * k + 30.0 * k \
		+ lh * lines.size() + 30.0 * k + float(ss)
	var top := (shot_rect.position.y - block) * 0.5
	var y := top

	# Marka satiri olculerek ortalaniyor; "FOLDERA" genisligini varsaymak
	# yazi tipi degisince satiri kaydirirdi.
	var bw := head.get_string_size(brand, HORIZONTAL_ALIGNMENT_LEFT, -1, marka_px).x
	var bx := (size.x - (isaret + 16.0 * k + bw)) * 0.5
	_mini_mark(Vector2(bx, y), isaret)
	draw_string(head, Vector2(bx + 62.0 * k, y + 37.0 * k), brand,
		HORIZONTAL_ALIGNMENT_LEFT, -1, marka_px, Palette.INK_SOFT)
	y += isaret + 34.0 * k

	_rule(size.x * 0.5, y, 92.0 * k)
	y += 9.0 * k + 30.0 * k

	for l in lines:
		y += lh
		_line(head, l, y - lh * 0.24, hs, Palette.INK)
	y += 30.0 * k + float(ss)
	_line(body, sub, y, ss, Palette.INK_SOFT)

	_device_card()


## Oyun ekrani, kalinligi ve iki katmanli golgesi olan bir kart olarak.
## Play afisinde doku 1:1 basiliyor (720x1280). App Store afislerinde
## kart daha genis oldugu icin doku buyutuluyor; oran korundugu surece
## germe olmuyor, yalnizca hafif yumusama var.
## `olcek` verilmezse kanvas genisliginden turetiliyor. Urun sayfasi
## basligi bunu ELLE veriyor: orada kanvas 5244 piksel ama kart yalnizca
## 1153, yani kanvastan turetilen katsayi yuvarlatmayi ve golgeyi karta
## gore devasa yapiyor.
func _device_card(olcek := -1.0) -> void:
	var k := _k() if olcek < 0.0 else olcek
	var radius := 46.0 * k
	Surface.shadow(self, shot_rect, radius, Color(0.30, 0.22, 0.14, 0.26),
		90.0 * k, Vector2(0, 34.0 * k))
	Surface.shadow(self, shot_rect, radius, Color(0.26, 0.18, 0.10, 0.18),
		24.0 * k, Vector2(0, 8.0 * k))
	if shot == null:
		Surface.fill(self, shot_rect, radius, Palette.PAPER)
		return
	var pts := Surface.rounded_rect(shot_rect, radius)
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append((p - shot_rect.position) / shot_rect.size)
	draw_colored_polygon(pts, Color.WHITE, uvs, shot)
	Surface.rim(self, shot_rect.grow(-1.5 * k), radius, Color(1, 1, 1, 0.55), 3.0 * k)


# ------------------------------------------------------------ ozellik grafigi

func _draw_feature() -> void:
	_gradient_bg()
	# Kose motifi burada YOK: logonun kendi katlanmis kosesi zaten var, ikisi
	# ust uste gelince cizgiler birbirini kesiyor ve grafik dagiliyor.

	var head := UiTheme.font(UiTheme.HEAVY)
	var body := UiTheme.font(UiTheme.BODY)
	var left := 84.0
	var text_w := 600.0

	_rule(left + 44.0, 150.0, 88.0)
	var ws := fit(head, PackedStringArray([brand]), text_w, 96, 60)
	draw_string(head, Vector2(left, 268.0), brand, HORIZONTAL_ALIGNMENT_LEFT, -1, ws, Palette.INK)
	var ts := fit(body, PackedStringArray([sub]), text_w, 38, 24)
	draw_string(body, Vector2(left, 330.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ts,
		Palette.INK_SOFT)


# ------------------------------------------------------- tanitim videosu plakasi

##
## 1920x1080 yatay cerceve. Play, tanitim videosunu YouTube oynaticisinda
## gosteriyor ve yatay oneriyor; oyun ise dikey. Bu plaka aradaki farki
## kapatiyor: dikey oynanis sagda bir kagit kartin uzerinde, sol taraf markaya
## ve uc iddiaya kaliyor.
##
func _draw_reel_plate() -> void:
	_gradient_bg()
	_fold_motif(0.22)

	var head := UiTheme.font(UiTheme.HEAVY)
	var body := UiTheme.font(UiTheme.BODY)
	var left := 150.0
	var tw := 900.0

	_rule(left + 46.0, 300.0, 92.0)
	var ws := fit(head, PackedStringArray([brand]), tw, 132, 80)
	draw_string(head, Vector2(left, 456.0), brand, HORIZONTAL_ALIGNMENT_LEFT, -1, ws, Palette.INK)
	var ts := fit(body, PackedStringArray([sub]), tw, 46, 28)
	draw_string(body, Vector2(left, 528.0), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ts,
		Palette.INK_SOFT)

	var y := 672.0
	for b in bullets:
		draw_circle(Vector2(left + 11.0, y - 12.0), 9.0, Palette.ACCENT)
		var bs := fit(body, PackedStringArray([b]), tw - 46.0, 38, 24)
		draw_string(body, Vector2(left + 42.0, y), b, HORIZONTAL_ALIGNMENT_LEFT, -1, bs,
			Palette.INK)
		y += 76.0

	# Videonun oturacagi yer. Golge ve kagit zemin BURADA ciziliyor; video
	# ustune bindirildiginde kenarlarda golge disarida kaliyor, kart gercekten
	# masaya konmus gibi duruyor.
	# Video kare koseli bindigi icin plakadaki kart ondan 12 piksel BUYUK
	# ciziliyor: disi yuvarlak, ici kare -- ekrani ceviren bir cerceve gibi
	# duruyor. Ayni boyutta cizilseydi yuvarlatma videonun altinda kalirdi.
	var bezel := video_rect.grow(12.0)
	Surface.shadow(self, bezel, 34.0, Color(0.30, 0.22, 0.14, 0.28), 80.0, Vector2(0, 30))
	Surface.shadow(self, bezel, 34.0, Color(0.26, 0.18, 0.10, 0.18), 22.0, Vector2(0, 8))
	Surface.fill_gradient(self, bezel, 34.0, Palette.PAPER.lightened(0.04), Palette.PAPER_EDGE.lightened(0.35))


#
# ------------------------------------------------- urun sayfasi basligi
#
## App Store urun sayfasinin en ustundeki gorsel ve arama sonuclarinda
## uygulamanin yaninda cikan gorsel. TEK DOSYA IKI YERE gidiyor: Apple'in
## referans verisinde 5244x2950 PNG "universalAsset" ve uyumlu yerlesimler
## hem PRODUCT_PAGE_HEADER_ASSET hem APP_STORE_SEARCH_RESULTS_ASSET.
##
## SAYILAR BURADA SABIT, oran bagimli degil -- cunku Apple bu varligi
## YALNIZCA 5244x2950 kabul ediyor. Olcek katsayisi yazmak, hic
## kullanilmayacak bir esneklik icin okunmasi zor bir fonksiyon birakirdi.
##
## GUVENLI ALAN. Apple bu kareyi baska oranlara KIRPIYOR:
##   21:9 -> ustten ve alttan (kalan yukseklik 5244*9/21 = 2247)
##   3:2  -> yanlardan        (kalan genislik  2950*3/2  = 4425)
## Ikisinin kesisimi x 409..4835, y 351..2599. Butun icerik bu
## dikdortgenin icinde duruyor; disina tasan bir sey bazi yerlesimlerde
## kesiliyor ve bunu magazada gormeden once fark etmek mumkun olmuyor.
const H_GUVENLI := Rect2(409, 351, 4426, 2248)

func _draw_header() -> void:
	_gradient_bg()
	_fold_motif(0.30)

	var head := UiTheme.font(UiTheme.HEAVY)
	var body := UiTheme.font(UiTheme.BODY)

	# Kart sagda, guvenli alanin icinde ve dikey ortali.
	var kart_h := 2050.0
	var kart_w := kart_h * 720.0 / 1280.0
	shot_rect = Rect2(round(3430.0), round((size.y - kart_h) * 0.5),
		round(kart_w), round(kart_h))

	# Metin solda; kartla arasinda nefes payi birakiliyor.
	var sol := 760.0
	var tw := shot_rect.position.x - sol - 300.0

	var satirlar := headline.split("\n")
	var hs := fit(head, satirlar, tw, 230, 140)
	var ss := fit(body, PackedStringArray([sub]), tw, 92, 60)
	var lh := float(hs) * 1.16

	var isaret := 130.0
	var marka_px := 96
	var blok := isaret + 96.0 + 26.0 + 86.0 + lh * satirlar.size() + 86.0 + float(ss)
	var y := size.y * 0.5 - blok * 0.5

	_mini_mark(Vector2(sol, y), isaret)
	draw_string(head, Vector2(sol + isaret + 44.0, y + isaret * 0.78), brand,
		HORIZONTAL_ALIGNMENT_LEFT, -1, marka_px, Palette.INK_SOFT)
	y += isaret + 96.0

	# `_rule` ortadan hizaliyor; sola yaslamak icin merkezi elle veriyoruz.
	_rule(sol + 130.0, y, 260.0)
	y += 26.0 + 86.0

	for l in satirlar:
		y += lh
		draw_string(head, Vector2(sol, y - lh * 0.24), l,
			HORIZONTAL_ALIGNMENT_LEFT, -1, hs, Palette.INK)
	y += 86.0 + float(ss)
	draw_string(body, Vector2(sol, y), sub,
		HORIZONTAL_ALIGNMENT_LEFT, -1, ss, Palette.INK_SOFT)

	# Olcek KARTIN genisliginden: 1080'lik afiste kart 776 piksel ve
	# katsayi 1.0 idi; burada kart 1153, yani ~1.49.
	_device_card(shot_rect.size.x / 776.0)


# ----------------------------------------------------------------- ikonlar

##
## Ikon, LogoMark ile DEGIL burada elle ciziliyor. Sebep: LogoMark baslik
## ekrani icin ayarlandi -- yumusak degradeler, dusuk kontrast. Ikon boyutunda
## (bazen 48 piksel) katlanmis kose zeminle kaynasip kayboluyor, kare bir
## centik gibi duruyordu. Burada flap belirgin sekilde koyu ve kat cizgisi
## kalin: 48 pikselde de "katlanmis kagit" okunuyor.
##
func _icon_mark(cut: Color, scale: float) -> void:
	var side := size.x * scale
	var sheet := Rect2((size - Vector2(side, side)) * 0.5, Vector2(side, side))
	var radius := side * 0.20

	Surface.shadow(self, sheet, radius, Color(0.30, 0.22, 0.14, 0.20),
		side * 0.15, Vector2(0, side * 0.05))
	Surface.fill_gradient(self, sheet, radius,
		Palette.PAPER.lightened(0.04), Palette.PAPER.darkened(0.07))

	# Katlanmis ust-sag kose.
	#
	# LogoMark kagidi o kosede GERCEKTEN kesip zemini gosteriyor -- baslik
	# ekraninda dogru duruyor ama ikon boyutunda zeminle ayni renkteki ucgen
	# "kare bir delik" gibi okunuyordu. Burada kose kesilmiyor: sayfanin kendi
	# ucgeni daha koyu bir tonla boyaniyor. 48 pikselde bile katlanmis kagit
	# olarak okunuyor.
	#
	# Ucgenin ucu sayfanin YUVARLATILMIS kosesini takip ediyor; sivri koseye
	# gitseydi yuvarlamayi tasip disari sarkardi.
	var f := side * 0.36
	var tr := Vector2(sheet.end.x, sheet.position.y)
	var a := tr + Vector2(-f, 0)
	var b := tr + Vector2(0, f)
	var corner := Surface.rounded_rect(sheet, radius)
	var flap := PackedVector2Array([a])
	for i in Surface.CORNER_SEGMENTS + 1:
		flap.append(corner[i])
	flap.append(b)
	draw_colored_polygon(flap, Palette.PAPER_EDGE)
	# kat cizgisi + hemen altinda ince ic golge: kagit gercekten kivrilmis olsun
	draw_line(a + Vector2(2, 2), b + Vector2(2, 2),
		Color(0.30, 0.22, 0.14, 0.13), maxf(3.0, side * 0.034), true)
	draw_line(a, b, Palette.PAPER_EDGE.darkened(0.30), maxf(2.0, side * 0.022), true)

	# kavusmak uzere olan iki es -- oyunun tek cumlesi
	var r := side * 0.145
	var cy := sheet.position.y + side * 0.66
	for dx in [-1.0, 1.0]:
		var at := Vector2(sheet.get_center().x + dx * side * 0.195, cy)
		Surface.chip(self, Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0),
			r * 0.42, Palette.ACCENT, r * 0.26, 0.0, 0.45, 0.8)


## Tek renkli (temali) ikon: Android bunu tek renge boyar, o yuzden ici dolu
## bir sayfa okunmaz olurdu. Onun yerine sayfanin KONTURU + iki es nokta.
##
func _draw_mono() -> void:
	var c := size * 0.5
	var s := size.x * 0.31
	var sheet := Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0)
	var w := s * 0.16
	var f := s * 0.78
	var tr := Vector2(sheet.end.x, sheet.position.y)

	var outline := PackedVector2Array([
		sheet.position, tr + Vector2(-f, 0), tr + Vector2(0, f),
		Vector2(sheet.end.x, sheet.end.y), Vector2(sheet.position.x, sheet.end.y),
	])
	outline.append(outline[0])
	draw_polyline(outline, Color.WHITE, w, true)
	var r := s * 0.24
	var cy := c.y + s * 0.42
	draw_circle(Vector2(c.x - s * 0.40, cy), r, Color.WHITE)
	draw_circle(Vector2(c.x + s * 0.40, cy), r, Color.WHITE)
