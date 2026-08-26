class_name LogoMark
extends Control
##
## Oyunun isareti: kosesi katlanmis bir kagit sayfasi, uzerinde birbirine
## kavusan iki es. Mekanigi tek bakista, tek kelime kullanmadan anlatiyor.
##
## Sayfa hafifce nefes aliyor ve dongu her seferinde patlamayla bitiyor --
## baslik ekraninda duran bir logo yerine, oyunun ne oldugunu GOSTEREN bir
## demo. Ayni yuzey recetesi (Surface) kullanildigi icin oyunun icindeki
## taslarla birebir ayni malzemeden gorunuyor.

var t := 0.0

## Katlanan kose, kagidin OLMADIGI yer -- oraya zemin rengi basiliyor. Logo
## baska bir zemine konursa (magaza afisi, uygulama ikonu) o zeminin rengi
## disaridan verilmeli, yoksa kosede yanlis renkte bir ucgen kalir.
var cut_color: Color = Palette.BG_TOP


func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)
	set_process(true)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var s := minf(size.x, size.y) * 0.40
	var float_y := sin(t * 1.1) * s * 0.035
	var sheet := Rect2(c - Vector2(s, s) + Vector2(0, float_y), Vector2(s, s) * 2.0)
	var radius := s * 0.28

	Surface.shadow(self, sheet, radius, Color(0.30, 0.22, 0.14, 0.22), s * 0.55,
		Vector2(0, s * 0.22))
	Surface.shadow(self, sheet, radius, Color(0.26, 0.18, 0.10, 0.18), s * 0.16,
		Vector2(0, s * 0.06))
	Surface.fill_gradient(self, sheet, radius,
		Palette.PAPER.lightened(0.05), Palette.PAPER.darkened(0.07))
	Surface.rim(self, sheet.grow(-1.0), radius, Color(1, 1, 1, 0.6), 2.0)

	_draw_pair(sheet, s)
	_draw_folded_corner(sheet, s)


## Dongu: sagdaki es sabit, soldaki uzerine katlaniyor, kavusunca patliyor.
func _draw_pair(sheet: Rect2, s: float) -> void:
	var phase := fmod(t * 0.42, 1.0)
	var travel := smoothstep(0.10, 0.62, phase)
	var pop := smoothstep(0.62, 0.80, phase)
	var mid := sheet.position + sheet.size * 0.5 + Vector2(0, s * 0.16)
	var chip := s * 0.25
	var col: Color = Palette.COLORS[0]

	if pop < 1.0:
		var fade := 1.0 - pop
		var right := mid + Vector2(s * 0.40, 0)
		var left := mid + Vector2(-s * 0.40, 0)
		var moving := left.lerp(right, travel)
		var shrink := 1.0 - pop * 0.55
		_chip(right, chip * shrink, Color(col, fade))
		_chip(moving, chip * shrink * (1.0 - 0.12 * sin(travel * PI)), Color(col.lightened(0.10), fade))

	if pop > 0.0 and pop < 1.0:
		var ring := Color(col, (1.0 - pop) * 0.8)
		draw_arc(mid, lerpf(chip * 0.6, chip * 2.4, pop), 0, TAU, 32, ring,
			maxf(2.0, s * 0.05) * (1.0 - pop), true)


func _chip(at: Vector2, r: float, col: Color) -> void:
	if col.a <= 0.01 or r <= 0.5:
		return
	var rect := Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0)
	Surface.shadow(self, rect, r * 0.55, Color(0.25, 0.18, 0.10, 0.22 * col.a),
		r * 0.8, Vector2(0, r * 0.28))
	Surface.fill(self, Rect2(rect.position + Vector2(0, r * 0.22), rect.size), r * 0.55,
		Color(col.darkened(0.30), col.a))
	Surface.fill_gradient(self, rect, r * 0.55,
		Color(col.lightened(0.18), col.a), Color(col.darkened(0.05), col.a))


## Katlanmis ust-sag kose.
##
## Kose `tr`, a-b kat cizgisine gore aynalandiginda tam olarak (tr.x-f, tr.y+f)
## noktasina duser. Flap ucgenini bu noktayla cizmek, katlamanin GERCEKTEN
## nereye indigini gosteriyor -- goz bunu dogruluyor, "sus" gibi durmuyor.
func _draw_folded_corner(sheet: Rect2, s: float) -> void:
	var f := s * 0.78
	var tr := Vector2(sheet.end.x, sheet.position.y)
	var a := tr + Vector2(-f, 0)
	var b := tr + Vector2(0, f)
	var landed := tr + Vector2(-f, f)

	# 1) kagit o kosede YOK -- zemin rengiyle kesiyoruz
	draw_colored_polygon(PackedVector2Array([a, tr, b]), cut_color)

	# 2) flap'in sayfaya dusen golgesi
	var off := Vector2(-s * 0.04, s * 0.05)
	draw_colored_polygon(PackedVector2Array([a + off, b + off, landed + off]),
		Color(0.30, 0.22, 0.14, 0.18))

	# 3) katlanan parca: kagidin ARKA yuzu, isik ondan kaciyor
	var back := PackedVector2Array([a, b, landed])
	var edge := Palette.PAPER_EDGE
	draw_polygon(back, PackedColorArray([
		edge.lightened(0.10), edge.lightened(0.10), edge.darkened(0.14),
	]))

	# 4) kat cizgisi -- keskin kenar
	draw_line(a, b, edge.darkened(0.34), maxf(2.0, s * 0.035), true)
