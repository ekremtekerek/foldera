class_name PaperSheet
extends Node2D
##
## Kagit yuzeyi. Duz beyaz bir dikdortgen degil: hafif degrade, iki katmanli
## golge ve ince bir ic kenar isigi var -- masanin uzerinde DURAN bir sayfa
## gibi gorunmesi icin gerekli olan uc sey.
##
## Kat cizgileri (gutter) cok soluk cizilir; oyuncunun nereden katlayabilecegini
## gormesi icin sart. Daha once KATLANMIS kenarlar keskin ve koyu, kesilmis
## kenarlar yumusak: kagidin gecmisi yuzeyinde kaliyor.

var rect := Rect2()
var cs := 100.0
var cols := 1
var rows := 1
var folded := {}          # "l" | "r" | "t" | "b"  ->  true
var grid_alpha := 0.05
var elevated := false     # kanat parcasi: daha guclu golge
var shadow_k := 1.0       # 0 = tam profilden bakiliyor, golge kaybolur


func refresh(r: Rect2, cell: float, c: int, ro: int) -> void:
	rect = r
	cs = cell
	cols = c
	rows = ro
	queue_redraw()


func _draw() -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var radius := cs * 0.13

	if shadow_k > 0.01:
		var e := (1.6 if elevated else 1.0) * shadow_k
		Surface.shadow(self, rect, radius, Color(0.30, 0.22, 0.14, 0.16 * e),
			cs * 0.42 * e, Vector2(0, cs * 0.14 * e))
		Surface.shadow(self, rect, radius, Color(0.26, 0.18, 0.10, 0.16 * e),
			cs * 0.10 * e, Vector2(0, cs * 0.035 * e))

	Surface.fill_gradient(self, rect, radius,
		Palette.PAPER.lightened(0.04), Palette.PAPER.darkened(0.055))

	# ic kat cizgileri
	var g := Palette.INK
	g.a = grid_alpha
	var x := rect.position.x + cs
	while x < rect.position.x + rect.size.x - 0.5:
		draw_line(Vector2(x, rect.position.y + cs * 0.12),
			Vector2(x, rect.end.y - cs * 0.12), g, maxf(1.0, cs * 0.012), true)
		x += cs
	var y := rect.position.y + cs
	while y < rect.position.y + rect.size.y - 0.5:
		draw_line(Vector2(rect.position.x + cs * 0.12, y),
			Vector2(rect.end.x - cs * 0.12, y), g, maxf(1.0, cs * 0.012), true)
		y += cs

	# ust kenarda ince ic isik -- sayfanin kenarini keskinlestirir
	Surface.rim(self, rect.grow(-1.0), radius, Color(1, 1, 1, 0.55), 2.0)

	# katlanmis kenarlar: keskin cizgi + ic golge seridi
	_folded_edges(radius)


func _folded_edges(radius: float) -> void:
	var cw := maxf(2.0, cs * 0.030)
	var line := Palette.PAPER_EDGE.darkened(0.30)
	var band := Color(0.34, 0.25, 0.15, 0.09)
	var inset := cs * 0.07
	var w := cs * 0.20
	if folded.get("l", false):
		Surface.fill(self, Rect2(rect.position.x, rect.position.y, w, rect.size.y), radius, band)
		draw_line(rect.position + Vector2(0, inset), Vector2(rect.position.x, rect.end.y - inset), line, cw, true)
	if folded.get("r", false):
		Surface.fill(self, Rect2(rect.end.x - w, rect.position.y, w, rect.size.y), radius, band)
		draw_line(Vector2(rect.end.x, rect.position.y + inset), rect.end - Vector2(0, inset), line, cw, true)
	if folded.get("t", false):
		Surface.fill(self, Rect2(rect.position.x, rect.position.y, rect.size.x, w), radius, band)
		draw_line(rect.position + Vector2(inset, 0), Vector2(rect.end.x - inset, rect.position.y), line, cw, true)
	if folded.get("b", false):
		Surface.fill(self, Rect2(rect.position.x, rect.end.y - w, rect.size.x, w), radius, band)
		draw_line(Vector2(rect.position.x + inset, rect.end.y), rect.end - Vector2(inset, 0), line, cw, true)
