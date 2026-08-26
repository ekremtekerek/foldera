class_name StarRow
extends Control
##
## Yildiz siralari. `reveal` 0..3 arasi SUREKLI bir deger -- tween ile
## artirildiginda yildizlar tek tek, hafif asip geri oturarak doluyor.
##
## Yildizin kendisi de degradeli ve golgeli: duz sari bir cokgen, kartin geri
## kalanindaki malzemeyle uyusmuyor ve odul anini ucuzlatiyor.

var reveal := 0.0 : set = _set_reveal
var star_size := 36.0


func _set_reveal(v: float) -> void:
	reveal = v
	queue_redraw()


func _draw() -> void:
	var step := star_size * 2.55
	var x0 := (size.x - step * 2.0) * 0.5
	for i in 3:
		var p := Vector2(x0 + step * float(i), size.y * 0.5)
		var k := clampf(reveal - float(i), 0.0, 1.0)
		_empty(p)
		if k > 0.03:
			# 1.0'i gecip geri oturur -- odulun "yerine oturma" hissi
			var bump := 1.0 + 0.32 * sin(clampf(k, 0.0, 1.0) * PI)
			_filled(p, k * bump, k)


func _points(at: Vector2, scale_k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in Palette.shape_points(Palette.SHAPE_STAR, star_size):
		out.append(at + v * scale_k)
	return out


func _empty(at: Vector2) -> void:
	draw_colored_polygon(_points(at + Vector2(0, 2.0), 1.0), Color(1, 1, 1, 0.55))
	draw_colored_polygon(_points(at, 1.0), Color(Palette.INK.r, Palette.INK.g, Palette.INK.b, 0.10))


func _filled(at: Vector2, scale_k: float, alpha: float) -> void:
	var gold: Color = Palette.COLORS[2]
	draw_colored_polygon(_points(at + Vector2(0, star_size * 0.16), scale_k),
		Color(0.30, 0.20, 0.06, 0.22 * alpha))
	draw_colored_polygon(_points(at + Vector2(0, star_size * 0.07), scale_k),
		Color(gold.darkened(0.34), alpha))

	# govde degradesi
	var pts := _points(at, scale_k)
	var cols := Surface.vertical_colors(pts, gold.lightened(0.22), gold.darkened(0.04),
		at.y - star_size * scale_k, at.y + star_size * scale_k)
	for j in cols.size():
		cols[j] = Color(cols[j], alpha)
	draw_polygon(pts, cols)

	# ust parlaklik
	draw_colored_polygon(_points(at - Vector2(0, star_size * 0.30), scale_k * 0.42),
		Color(1, 1, 1, 0.28 * alpha))
