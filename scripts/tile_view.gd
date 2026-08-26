class_name TileView
extends Node2D
##
## Tek bir tas. Merkezi kendi origin'inde -> olcek/dondurme animasyonlari
## dogal merkezden calisir.
##
## Tas boyali bir kare degil, KALINLIGI OLAN BIR PUL: altinda daha koyu bir
## govde katmani, ustunde tek isik kaynagindan gelen degrade ve parlaklik,
## altinda iki katmanli golge var. Duz dolgu ile arasindaki fark, oyunun
## "vektor cizim" mi yoksa "nesne" mi gorundugunu belirleyen sey.

var code := 0
var cs := 100.0
var glow := 0.0
var glow_color: Color = Palette.GOOD
var conflict := false

var _shape := -1
var _size := 0.0
var _radius := 0.0
var _depth := 0.0


func setup(tile_code: int, cell_size: float) -> void:
	code = tile_code
	cs = cell_size
	_size = cs * 0.86
	_radius = cs * 0.26
	_depth = cs * 0.075
	_shape = Palette.shape_for(code)
	queue_redraw()


func set_glow(amount: float, col: Color) -> void:
	glow = amount
	glow_color = col
	queue_redraw()


func _draw() -> void:
	if code == Tiles.EMPTY:
		return
	var s := _size
	# Govde kalinligin yarisi kadar yukarida durur ki pul + golgesi birlikte
	# tam olarak hucrenin ortasina otursun.
	var rect := Rect2(-s * 0.5, -s * 0.5 - _depth * 0.5, s, s)
	Surface.chip(self, rect, _radius, Palette.body(code), _depth, 0.0,
		0.35 if Tiles.kind(code) == Tiles.K_WILD else 0.6)

	var mid := rect.position + rect.size * 0.5
	var r := s * 0.25
	match _shape:
		-1: _draw_lock(mid, s)
		-2: _draw_wild(mid, s, r)
		_: _draw_symbol(mid, r)

	if glow > 0.001:
		_draw_marker(rect)


## Sembol once koyu bir golge, sonra sicak beyaz olarak ciziliyor: dogrudan
## beyaz sekil govdenin uzerine yapistirilmis gibi duruyor.
func _draw_symbol(at: Vector2, r: float) -> void:
	var pts := Palette.shape_points(_shape, r)
	var shade := PackedVector2Array()
	for v in pts:
		shade.append(at + v + Vector2(0, r * 0.11))
	draw_colored_polygon(shade, Color(0, 0, 0, 0.13))
	var face := PackedVector2Array()
	for v in pts:
		face.append(at + v)
	draw_colored_polygon(face, Palette.face(code))


## Mandal: cakili tas. Asla temizlenemez, uzerine hicbir sey katlanamaz.
func _draw_lock(at: Vector2, s: float) -> void:
	var c := s * 0.29
	for p in [Vector2(-c, -c), Vector2(c, -c), Vector2(-c, c), Vector2(c, c)]:
		draw_circle(at + p + Vector2(0, s * 0.012), s * 0.030, Color(0, 0, 0, 0.22))
		draw_circle(at + p, s * 0.048, Color(1, 1, 1, 0.16))
	draw_circle(at + Vector2(0, s * 0.02), s * 0.20, Color(0, 0, 0, 0.25))
	draw_circle(at, s * 0.20, Palette.LOCK_FACE)
	draw_circle(at, s * 0.20, Color(0, 0, 0, 0.20), false, maxf(1.5, cs * 0.016), true)
	draw_circle(at + Vector2(-s * 0.06, -s * 0.06), s * 0.06, Color(1, 1, 1, 0.45))


## Joker: her renkle patlar. Dort kollu isilti.
func _draw_wild(at: Vector2, s: float, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		var rad := r * 1.32 if i % 2 == 0 else r * 0.30
		var a := -PI / 2.0 + TAU * float(i) / 8.0
		pts.append(Vector2(cos(a), sin(a)) * rad)
	var shade := PackedVector2Array()
	for v in pts:
		shade.append(at + v + Vector2(0, r * 0.10))
	draw_colored_polygon(shade, Color(0.35, 0.30, 0.55, 0.18))
	var face := PackedVector2Array()
	for v in pts:
		face.append(at + v)
	draw_colored_polygon(face, Palette.WILD_FACE)
	draw_arc(at, r * 1.55, 0, TAU, 36, Color(Palette.WILD_FACE, 0.30), maxf(1.5, cs * 0.018), true)


## On izleme isareti: yesil = patlayacak, kirmizi = katlama reddedilecek.
## Halka tasin KENARINI takip ediyor, cember degil -- boylece komsu hucrelere
## tasmiyor ve hangi tasa ait oldugu net kaliyor.
func _draw_marker(rect: Rect2) -> void:
	var gc := glow_color
	gc.a = glow * 0.95
	var pad := cs * 0.035
	var r2 := Rect2(rect.position - Vector2(pad, pad), rect.size + Vector2(pad, pad) * 2.0)
	Surface.rim(self, r2, _radius + pad, gc, maxf(2.5, cs * 0.045))
	if conflict:
		var mid := rect.position + rect.size * 0.5
		var d := rect.size.x * 0.19
		var w := maxf(2.5, cs * 0.05)
		draw_line(mid + Vector2(-d, -d), mid + Vector2(d, d), Color(0, 0, 0, 0.20), w + 3.0, true)
		draw_line(mid + Vector2(d, -d), mid + Vector2(-d, d), Color(0, 0, 0, 0.20), w + 3.0, true)
		draw_line(mid + Vector2(-d, -d), mid + Vector2(d, d), gc, w, true)
		draw_line(mid + Vector2(d, -d), mid + Vector2(-d, d), gc, w, true)
