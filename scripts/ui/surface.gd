class_name Surface
##
## Tum arayuzun paylastigi cizim temeli. Taslar, dugmeler ve kartlar AYNI
## receteyi kullaniyor -- gorsel butunluk buradan geliyor.
##
## "Duz 2B" gorunumunu kiran uc sey, onem sirasiyla:
##
##   1. IKI KATMANLI GOLGE. Tek gölge her zaman ya cok sert ya cok bulanik
##      olur. Gercekte iki gölge vardir: genis/yumusak ortam golgesi (nesnenin
##      yerden yuksekligi) ve dar/koyu temas golgesi (nesnenin oturdugu yer).
##   2. KALINLIK. Nesnenin altinda daha koyu bir govde katmani -- taslar boyali
##      kare degil, kalinligi olan pul gibi duruyor.
##   3. DEGRADE + PARLAKLIK. Ustten gelen tek bir isik kaynagi: govde yukaridan
##      asagi koyulasiyor, ust kenarda ince bir parlaklik var.
##
## Godot'un StyleBoxFlat'i degrade yapamiyor; bu yuzden govdeyi kose yuvarlatilmis
## bir COKGEN olarak cizip her kosesine y'ye gore renk veriyoruz. draw_polygon
## aradaki degeri kendisi yumusatiyor.

const CORNER_SEGMENTS := 6


## Kose yuvarlatilmis dikdortgen cokgeni.
static func rounded_rect(rect: Rect2, radius: float, seg := CORNER_SEGMENTS) -> PackedVector2Array:
	var r := minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var pts := PackedVector2Array()
	if r <= 0.5:
		return PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y),
		])
	var arcs := [
		[Vector2(rect.end.x - r, rect.position.y + r), -PI * 0.5, 0.0],
		[Vector2(rect.end.x - r, rect.end.y - r), 0.0, PI * 0.5],
		[Vector2(rect.position.x + r, rect.end.y - r), PI * 0.5, PI],
		[Vector2(rect.position.x + r, rect.position.y + r), PI, PI * 1.5],
	]
	# Yaricap yuksekligin/genisligin tam yarisina kirpildiginda komsu yaylarin
	# uc noktalari CAKISIYOR. Ust uste binen kose draw_polygon ucgenlemesini
	# bozuyor ("Invalid polygon data") ve dugme hic cizilmiyor. Bu yuzden
	# noktalari eklerken tekrarlari eliyoruz.
	for a in arcs:
		var c: Vector2 = a[0]
		for i in seg + 1:
			var ang: float = lerpf(a[1], a[2], float(i) / float(seg))
			var p := c + Vector2(cos(ang), sin(ang)) * r
			if pts.size() > 0 and pts[pts.size() - 1].distance_squared_to(p) < 0.01:
				continue
			pts.append(p)
	if pts.size() > 2 and pts[0].distance_squared_to(pts[pts.size() - 1]) < 0.01:
		pts.remove_at(pts.size() - 1)
	return pts


## Her kose noktasina y konumuna gore renk atar -> dikey degrade.
static func vertical_colors(pts: PackedVector2Array, top: Color, bottom: Color,
		y0: float, y1: float) -> PackedColorArray:
	var cols := PackedColorArray()
	var span := maxf(1.0, y1 - y0)
	for p in pts:
		cols.append(top.lerp(bottom, clampf((p.y - y0) / span, 0.0, 1.0)))
	return cols


static func fill_gradient(ci: CanvasItem, rect: Rect2, radius: float,
		top: Color, bottom: Color) -> void:
	var pts := rounded_rect(rect, radius)
	ci.draw_polygon(pts, vertical_colors(pts, top, bottom, rect.position.y, rect.end.y))


static func fill(ci: CanvasItem, rect: Rect2, radius: float, col: Color) -> void:
	ci.draw_colored_polygon(rounded_rect(rect, radius), col)


## Yumusak golge. StyleBoxFlat'in golgesi gercek bir bulaniklik uyguluyor;
## kendi cizdigimiz cokgenle bunu yapamayiz, o yuzden golge icin ondan
## yararlaniyoruz.
static func shadow(ci: CanvasItem, rect: Rect2, radius: float, col: Color,
		blur: float, offset: Vector2) -> void:
	if col.a <= 0.002 or blur <= 0.0:
		return
	var box := StyleBoxFlat.new()
	box.bg_color = Color(col.r, col.g, col.b, 0.0)
	var r := int(minf(radius, minf(rect.size.x, rect.size.y) * 0.5))
	box.corner_radius_top_left = r
	box.corner_radius_top_right = r
	box.corner_radius_bottom_left = r
	box.corner_radius_bottom_right = r
	box.shadow_color = col
	box.shadow_size = int(blur)
	box.shadow_offset = offset
	ci.draw_style_box(box, rect)


##
## Oyunun temel gorsel birimi: kalinligi, degradesi ve iki katmanli golgesi
## olan yuvarlak kose "pul". Tas da dugme de kart da bunu kullaniyor.
##
##   depth  : kalinlik (piksel). 0 -> duz yuzey (kartlar), >0 -> nesne
##   press  : 0..1, basili olma orani. Pul asagi iner ve kalinligi azalir --
##            gercek bir tusa basma hissi.
##   gloss  : ust parlakligin gucu
##
static func chip(ci: CanvasItem, rect: Rect2, radius: float, base: Color,
		depth: float, press := 0.0, gloss := 0.5, shadow_scale := 1.0) -> void:
	var sink := depth * press
	var body := Rect2(rect.position + Vector2(0, sink), rect.size)
	var thickness := maxf(0.0, depth - sink)

	# 1) ortam golgesi -- genis ve soluk, nesnenin yerden yuksekligini anlatir
	if shadow_scale > 0.0:
		var lift := 1.0 - press * 0.65
		shadow(ci, body, radius, Color(0.30, 0.22, 0.14, 0.22 * shadow_scale * lift),
			depth * 2.6 + 8.0, Vector2(0, depth * 0.9 + 4.0) * lift)
		# 2) temas golgesi -- dar ve koyu, nesnenin oturdugu yeri anlatir
		shadow(ci, body, radius, Color(0.26, 0.18, 0.10, 0.26 * shadow_scale),
			depth * 0.9 + 3.0, Vector2(0, depth * 0.30 + 1.5))

	# 3) kalinlik: govdenin altinda daha koyu bir katman
	if thickness > 0.5:
		var side := base.darkened(0.30)
		side.s = minf(1.0, side.s * 1.10)
		fill(ci, Rect2(body.position + Vector2(0, thickness), body.size), radius, side)

	# 4) govde degradesi -- ustten gelen tek isik kaynagi
	fill_gradient(ci, body, radius, base.lightened(0.16), base.darkened(0.06))

	# 5) ust parlaklik: govdenin ust bandinda, kenarlardan iceri cekilmis
	if gloss > 0.01:
		var inset := radius * 0.45
		var gr := Rect2(
			body.position + Vector2(inset, inset * 0.55),
			Vector2(body.size.x - inset * 2.0, body.size.y * 0.40))
		if gr.size.x > 1.0 and gr.size.y > 1.0:
			var pts := rounded_rect(gr, radius * 0.7)
			var hi := Color(1, 1, 1, 0.36 * gloss)
			ci.draw_polygon(pts, vertical_colors(pts, hi, Color(1, 1, 1, 0.0),
				gr.position.y, gr.end.y))


## Kart / panel yuzeyi: kalinliksiz ama katmanli golgeli, hafif degradeli.
static func panel(ci: CanvasItem, rect: Rect2, radius: float, base: Color,
		elevation := 1.0) -> void:
	shadow(ci, rect, radius, Color(0.28, 0.20, 0.12, 0.20 * elevation),
		34.0 * elevation, Vector2(0, 16.0 * elevation))
	shadow(ci, rect, radius, Color(0.26, 0.18, 0.10, 0.14 * elevation),
		10.0 * elevation, Vector2(0, 4.0 * elevation))
	fill_gradient(ci, rect, radius, base.lightened(0.035), base.darkened(0.035))


## Ince ic kenar cizgisi -- yuzeyin kenarini keskinlestirir, "yumusak plastik"
## gorunumunu engeller.
static func rim(ci: CanvasItem, rect: Rect2, radius: float, col: Color, width := 2.0) -> void:
	var pts := rounded_rect(rect, radius)
	pts.append(pts[0])
	ci.draw_polyline(pts, col, width, true)
