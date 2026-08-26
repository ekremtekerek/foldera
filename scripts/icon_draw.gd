class_name IconDraw
##
## Kucuk vektor ikon kutuphanesi. Tek bir PNG bile yok -- her ikon cizgiyle
## ciziliyor, boylece her ekran yogunlugunda keskin ve renk temaya uyumlu.
## Tum ikonlar (0,0) merkezli ve `s` yaricapina gore olceklenir.
##

const UNDO := 0
const RESTART := 1
const HINT := 2
const SOUND_ON := 3
const SOUND_OFF := 4
const BACK := 5
const GRID := 6
const CLOSE := 7


static func paint(ci: CanvasItem, icon: int, s: float, col: Color) -> void:
	var w := maxf(2.0, s * 0.17)
	match icon:
		UNDO: _arrow_arc(ci, s, col, w, true)
		RESTART: _arrow_arc(ci, s, col, w, false)
		HINT: _bulb(ci, s, col, w)
		SOUND_ON: _speaker(ci, s, col, w, true)
		SOUND_OFF: _speaker(ci, s, col, w, false)
		BACK: _chevron(ci, s, col, w)
		GRID: _grid(ci, s, col)
		CLOSE: _close(ci, s, col, w)


## Geri al (aynalanmis) ve yeniden basla ayni yayi paylasir; ok ucu yayin
## BITIS noktasinda ve tegetsel -- hareket yonunu tek bakista okutuyor.
static func _arrow_arc(ci: CanvasItem, s: float, col: Color, w: float, mirror: bool) -> void:
	var r := s * 0.60
	var a0 := deg_to_rad(-28.0)
	var a1 := deg_to_rad(262.0)
	var n := 44
	var pts := PackedVector2Array()
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		pts.append(_flip(Vector2(cos(a), sin(a)) * r, mirror))
	ci.draw_polyline(pts, col, w, true)

	var radial := Vector2(cos(a1), sin(a1))
	var tang := Vector2(-sin(a1), cos(a1))
	var tip := radial * r
	var h := s * 0.46
	ci.draw_colored_polygon(PackedVector2Array([
		_flip(tip + tang * h * 0.62, mirror),
		_flip(tip - tang * h * 0.32 + radial * h * 0.52, mirror),
		_flip(tip - tang * h * 0.32 - radial * h * 0.52, mirror),
	]), col)


static func _flip(p: Vector2, mirror: bool) -> Vector2:
	return Vector2(-p.x, p.y) if mirror else p


static func _bulb(ci: CanvasItem, s: float, col: Color, w: float) -> void:
	var r := s * 0.42
	ci.draw_arc(Vector2(0, -s * 0.12), r, 0, TAU, 32, col, w, true)
	ci.draw_line(Vector2(-r * 0.55, s * 0.34), Vector2(r * 0.55, s * 0.34), col, w, true)
	ci.draw_line(Vector2(-r * 0.34, s * 0.60), Vector2(r * 0.34, s * 0.60), col, w, true)
	for i in 3:
		var a := deg_to_rad(-150.0 + 60.0 * float(i))
		var d := Vector2(cos(a), sin(a))
		ci.draw_line(d * (r + s * 0.16), d * (r + s * 0.40), col, w * 0.8, true)


static func _speaker(ci: CanvasItem, s: float, col: Color, w: float, on: bool) -> void:
	var body := PackedVector2Array([
		Vector2(-s * 0.62, -s * 0.22), Vector2(-s * 0.30, -s * 0.22),
		Vector2(0.02, -s * 0.60), Vector2(0.02, s * 0.60),
		Vector2(-s * 0.30, s * 0.22), Vector2(-s * 0.62, s * 0.22),
	])
	ci.draw_colored_polygon(body, col)
	if on:
		ci.draw_arc(Vector2(0.05, 0), s * 0.34, deg_to_rad(-55), deg_to_rad(55), 18, col, w * 0.85, true)
		ci.draw_arc(Vector2(0.05, 0), s * 0.60, deg_to_rad(-50), deg_to_rad(50), 22, col, w * 0.85, true)
	else:
		var d := s * 0.26
		var o := Vector2(s * 0.44, 0)
		ci.draw_line(o + Vector2(-d, -d), o + Vector2(d, d), col, w * 0.9, true)
		ci.draw_line(o + Vector2(d, -d), o + Vector2(-d, d), col, w * 0.9, true)


static func _chevron(ci: CanvasItem, s: float, col: Color, w: float) -> void:
	ci.draw_polyline(PackedVector2Array([
		Vector2(s * 0.28, -s * 0.55), Vector2(-s * 0.24, 0), Vector2(s * 0.28, s * 0.55),
	]), col, w, true)


static func _grid(ci: CanvasItem, s: float, col: Color) -> void:
	var d := s * 0.30
	var q := s * 0.22
	for p in [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, d), Vector2(d, d)]:
		ci.draw_rect(Rect2(p - Vector2(q, q) * 0.5, Vector2(q, q)), col, true)


static func _close(ci: CanvasItem, s: float, col: Color, w: float) -> void:
	var d := s * 0.42
	ci.draw_line(Vector2(-d, -d), Vector2(d, d), col, w, true)
	ci.draw_line(Vector2(d, -d), Vector2(-d, d), col, w, true)
